from datetime import timedelta
from typing import Any, Self
from unittest.mock import Mock, patch

from django.http import HttpRequest, HttpResponse
from django.test import TestCase, override_settings
from django.utils import timezone
from ninja_jwt.exceptions import InvalidToken

from apps.authentication.auth import VersionedJWTAuth
from apps.authentication.models import OTPVerification, ResetChallenge, User
from apps.authentication.routes import Routes
from apps.authentication.services.token_services import TokenService
from apps.core.choices import OTPStatus, ResetStatus, ResetType
from apps.core.constants import OTP_RESEND_COOLDOWN
from apps.core.key_utils import encrypt_kbkey, generate_kbkey
from apps.core.pin import encrypt_lock_pin, verify_lock_pin



@override_settings(
    KEEBOX_MASTER_KEY="KMK-ICEiIyQlJicoKSorLC0uLz-AxMjM0NTY3ODk6Ozw9Pj8",
    KEEBOX_PIN_PEPPER="test-pin-pepper",
)
class ResetFlowIntegrationTests(TestCase):
    def setUp(self: Self) -> None:
        """
        Prepare an account and capture delivered reset OTP codes.

        Args:
            self: Current test case instance.

        Returns:
            None: This setup method does not return a value.

        Raises:
            ValueError: Raised when test key or PIN material is invalid.
        """
        kbkey: str = generate_kbkey()
        encrypted_kbkey: bytes
        kbkey_nonce: bytes
        kbkey_encryption_version: int
        (
            encrypted_kbkey,
            kbkey_nonce,
            kbkey_encryption_version,
        ) = encrypt_kbkey(
            kbkey,
            "KMK-ICEiIyQlJicoKSorLC0uLz-AxMjM0NTY3ODk6Ozw9Pj8",
        )
        self.user: User = User.objects.create_user(
            email="ada@example.com",
            password="original strong password 5821",
            first_name="Ada",
            last_name="Lovelace",
            pin_hash=encrypt_lock_pin("123456"),
            encrypted_kbkey=encrypted_kbkey,
            kbkey_nonce=kbkey_nonce,
            kbkey_encryption_version=kbkey_encryption_version,
        )
        email_patcher: Any = patch(
            "apps.authentication.services.reset_services.EmailDeliveryService",
        )
        code_patcher: Any = patch(
            "apps.authentication.services.reset_services.generate_otp_code",
            side_effect=["048291", "193847"],
        )
        self.email_delivery_service: Mock = email_patcher.start()
        self.generate_otp: Mock = code_patcher.start()
        self.addCleanup(email_patcher.stop)
        self.addCleanup(code_patcher.stop)

    def _post(self: Self, route: str, payload: dict[str, str]) -> HttpResponse:
        """
        Submit one JSON request to an authentication endpoint.

        Args:
            self: Current test case instance.
            route: Authentication route path after the API prefix.
            payload: Request body submitted by the client.

        Returns:
            HTTP response from the selected endpoint.

        Raises:
            None.
        """
        return self.client.post(
            f"/api/auth{route}",
            data=payload,
            content_type="application/json",
        )

    def test_password_reset_flow_revokes_old_session_and_allows_new_login(
        self: Self,
    ) -> None:
        """
        Verify password recovery from request through a fresh successful login.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a stage of password recovery fails.
        """
        old_access: str
        old_refresh: str
        old_access, old_refresh = TokenService.issue_tokens(self.user)

        started: HttpResponse = self._post(
            Routes.Reset.PASSWORD,
            {"email": self.user.email},
        )
        started_data: dict[str, Any] = started.json()["data"]
        reset_id: str = started_data["reset_id"]
        delivered_code: str = (
            self.email_delivery_service.return_value.send_otp_email.call_args.kwargs[
                "otp_code"
            ]
        )
        verified: HttpResponse = self._post(
            Routes.Reset.VERIFY_OTP,
            {"reset_id": reset_id, "otp_code": delivered_code},
        )
        completed: HttpResponse = self._post(
            Routes.Reset.PASSWORD_COMPLETE,
            {
                "reset_id": reset_id,
                "new_password": "replacement strong password 7349",
            },
        )
        challenge: ResetChallenge = ResetChallenge.objects.get(pk=reset_id)
        otp: OTPVerification = OTPVerification.objects.get(
            reset_challenge=challenge,
        )
        self.user.refresh_from_db()

        self.assertEqual(started.status_code, 200)
        self.assertEqual(verified.status_code, 200)
        self.assertEqual(completed.status_code, 200)
        self.assertEqual(challenge.reset_type, ResetType.PASSWORD)
        self.assertEqual(challenge.status, ResetStatus.COMPLETED)
        self.assertEqual(otp.status, OTPStatus.CONSUMED)
        self.assertTrue(self.user.check_password("replacement strong password 7349"))
        self.assertTrue(verify_lock_pin("123456", self.user.pin_hash))
        self.assertEqual(self.user.token_version, 1)
        self.assertNotIn("access_token", completed.json()["data"])
        self.email_delivery_service.return_value.send_otp_email.assert_called_once_with(
            recipient_email=self.user.email,
            recipient_full_name="Ada Lovelace",
            otp_code=delivered_code,
            expiration_minutes=5,
            tag="password-reset-otp",
        )
        with self.assertRaises(InvalidToken):
            VersionedJWTAuth().authenticate(HttpRequest(), old_access)
        with self.assertRaises(InvalidToken):
            TokenService.refresh_access_token(old_refresh)

        old_login: HttpResponse = self._post(
            Routes.Login.BASE,
            {"email": self.user.email, "password": "original strong password 5821"},
        )
        new_login: HttpResponse = self._post(
            Routes.Login.BASE,
            {"email": self.user.email, "password": "replacement strong password 7349"},
        )
        login_completed: HttpResponse = self._post(
            Routes.Login.VERIFY_PIN,
            {
                "login_challenge_id": new_login.json()["data"]["login_challenge_id"],
                "pin": "123456",
            },
        )

        self.assertEqual(old_login.status_code, 401)
        self.assertEqual(new_login.status_code, 200)
        self.assertEqual(login_completed.status_code, 200)
        self.assertIn("access_token", login_completed.json()["data"])

    def test_pin_reset_flow_replaces_otp_unlocks_account_and_allows_login(
        self: Self,
    ) -> None:
        """
        Verify PIN recovery through resend, verification, and fresh login.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a stage of PIN recovery fails.
        """
        old_access: str
        old_refresh: str
        old_access, old_refresh = TokenService.issue_tokens(self.user)
        self.user.pin_failed_attempts = 5
        self.user.pin_locked_until = timezone.now() + timedelta(hours=24)
        self.user.save(update_fields=["pin_failed_attempts", "pin_locked_until"])

        started: HttpResponse = self._post(
            Routes.Reset.PIN,
            {"email": self.user.email},
        )
        reset_id: str = started.json()["data"]["reset_id"]
        old_code: str = (
            self.email_delivery_service.return_value.send_otp_email.call_args.kwargs[
                "otp_code"
            ]
        )
        old_otp: OTPVerification = OTPVerification.objects.get(
            reset_challenge_id=reset_id,
        )
        old_otp.last_sent_at = timezone.now() - OTP_RESEND_COOLDOWN - timedelta(
            seconds=1,
        )
        old_otp.save(update_fields=["last_sent_at"])

        resent: HttpResponse = self._post(
            Routes.Reset.RESEND_OTP,
            {"reset_id": reset_id},
        )
        new_code: str = (
            self.email_delivery_service.return_value.send_otp_email.call_args.kwargs[
                "otp_code"
            ]
        )
        superseded: HttpResponse = self._post(
            Routes.Reset.VERIFY_OTP,
            {"reset_id": reset_id, "otp_code": old_code},
        )
        verified: HttpResponse = self._post(
            Routes.Reset.VERIFY_OTP,
            {"reset_id": reset_id, "otp_code": new_code},
        )
        completed: HttpResponse = self._post(
            Routes.Reset.PIN_COMPLETE,
            {"reset_id": reset_id, "new_pin": "654321"},
        )
        challenge: ResetChallenge = ResetChallenge.objects.get(pk=reset_id)
        old_otp.refresh_from_db()
        self.user.refresh_from_db()

        self.assertEqual(started.status_code, 200)
        self.assertEqual(resent.status_code, 200)
        self.assertEqual(resent.json()["data"]["reset_id"], reset_id)
        self.assertEqual(superseded.status_code, 400)
        self.assertEqual(verified.status_code, 200)
        self.assertEqual(completed.status_code, 200)
        self.assertEqual(challenge.reset_type, ResetType.PIN)
        self.assertEqual(challenge.status, ResetStatus.COMPLETED)
        self.assertEqual(challenge.resend_count, 1)
        self.assertEqual(old_otp.status, OTPStatus.EXPIRED)
        self.assertTrue(verify_lock_pin("654321", self.user.pin_hash))
        self.assertFalse(verify_lock_pin("123456", self.user.pin_hash))
        self.assertTrue(self.user.check_password("original strong password 5821"))
        self.assertEqual(self.user.pin_failed_attempts, 0)
        self.assertIsNone(self.user.pin_locked_until)
        self.assertEqual(self.user.token_version, 1)
        self.assertNotIn("access_token", completed.json()["data"])
        self.assertEqual(
            self.email_delivery_service.return_value.send_otp_email.call_count,
            2,
        )
        with self.assertRaises(InvalidToken):
            VersionedJWTAuth().authenticate(HttpRequest(), old_access)
        with self.assertRaises(InvalidToken):
            TokenService.refresh_access_token(old_refresh)

        new_login: HttpResponse = self._post(
            Routes.Login.BASE,
            {"email": self.user.email, "password": "original strong password 5821"},
        )
        login_completed: HttpResponse = self._post(
            Routes.Login.VERIFY_PIN,
            {
                "login_challenge_id": new_login.json()["data"]["login_challenge_id"],
                "pin": "654321",
            },
        )

        self.assertEqual(new_login.status_code, 200)
        self.assertEqual(login_completed.status_code, 200)
        self.assertIn("access_token", login_completed.json()["data"])
