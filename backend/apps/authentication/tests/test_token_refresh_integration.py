from datetime import datetime, timedelta, timezone
from typing import Any, Self
from unittest.mock import Mock, patch

from django.http import HttpResponse
from django.test import TestCase, override_settings
from freezegun import freeze_time
from ninja_jwt.tokens import AccessToken, RefreshToken

from apps.authentication.models import User
from apps.authentication.routes import Routes
from apps.core.key_utils import encrypt_kbkey, generate_kbkey
from apps.core.pin import encrypt_lock_pin



@override_settings(
    KEEBOX_MASTER_KEY="KMK-ICEiIyQlJicoKSorLC0uLz-AxMjM0NTY3ODk6Ozw9Pj8",
    KEEBOX_PIN_PEPPER="test-pin-pepper",
)
class TokenRefreshIntegrationTests(TestCase):
    def setUp(self: Self) -> None:
        """
        Prepare a login-ready account and isolate external reset email delivery.

        Args:
            self: Current test case instance.

        Returns:
            None: This setup method does not return a value.

        Raises:
            ValueError: Raised when the test PIN or key material is invalid.
        """
        encrypted_kbkey: bytes
        kbkey_nonce: bytes
        kbkey_encryption_version: int
        encrypted_kbkey, kbkey_nonce, kbkey_encryption_version = encrypt_kbkey(
            generate_kbkey(),
            "KMK-ICEiIyQlJicoKSorLC0uLz-AxMjM0NTY3ODk6Ozw9Pj8",
        )
        self.user: User = User.objects.create_user(
            email="ada@example.com",
            password="correct horse battery staple",
            first_name="Ada",
            last_name="Lovelace",
            pin_hash=encrypt_lock_pin("00123"),
            encrypted_kbkey=encrypted_kbkey,
            kbkey_nonce=kbkey_nonce,
            kbkey_encryption_version=kbkey_encryption_version,
        )
        email_patcher: Any = patch(
            "apps.authentication.services.reset_services.EmailDeliveryService",
        )
        self.email_service: Mock = email_patcher.start()
        self.addCleanup(email_patcher.stop)

    def _post(
        self: Self,
        route: str,
        payload: dict[str, str],
        access_token: str | None = None,
    ) -> HttpResponse:
        """
        Submit an authentication API request with optional bearer credentials.

        Args:
            self: Current test case instance.
            route: Authentication route path after the API prefix.
            payload: JSON body sent to the endpoint.
            access_token: Optional token authenticating a protected request.

        Returns:
            HTTP response from the selected endpoint.

        Raises:
            None.
        """
        headers: dict[str, str] = {}
        if access_token is not None:
            headers["HTTP_AUTHORIZATION"] = f"Bearer {access_token}"
        return self.client.post(
            f"/api/auth{route}",
            data=payload,
            content_type="application/json",
            **headers,
        )

    def _login(
        self: Self,
        password: str = "correct horse battery staple",
        pin: str = "00123",
    ) -> dict[str, Any]:
        """
        Complete password and PIN authentication through the login endpoints.

        Args:
            self: Current test case instance.
            password: Account password submitted to begin login.
            pin: Lock PIN submitted to complete login.

        Returns:
            Completed authentication data containing the new session's tokens.

        Raises:
            AssertionError: Raised when either login stage fails.
        """
        started: HttpResponse = self._post(
            Routes.Login.BASE,
            {"email": self.user.email, "password": password},
        )
        self.assertEqual(started.status_code, 200)
        completed: HttpResponse = self._post(
            Routes.Login.VERIFY_PIN,
            {
                "login_challenge_id": started.json()["data"]["login_challenge_id"],
                "pin": pin,
            },
        )
        self.assertEqual(completed.status_code, 200)
        return completed.json()["data"]

    def _complete_reset(
        self: Self,
        start_route: str,
        complete_route: str,
        credential: dict[str, str],
    ) -> None:
        """
        Complete a credential reset using the OTP captured at the email boundary.

        Args:
            self: Current test case instance.
            start_route: Password or PIN reset initiation route.
            complete_route: Corresponding reset completion route.
            credential: Replacement password or PIN fields.

        Returns:
            None: The selected credential reset has completed successfully.

        Raises:
            AssertionError: Raised when a reset workflow stage fails.
        """
        started: HttpResponse = self._post(start_route, {"email": self.user.email})
        self.assertEqual(started.status_code, 200)
        reset_id: str = started.json()["data"]["reset_id"]
        otp_code: str = (
            self.email_service.return_value.send_otp_email.call_args.kwargs["otp_code"]
        )
        verified: HttpResponse = self._post(
            Routes.Reset.VERIFY_OTP,
            {"reset_id": reset_id, "otp_code": otp_code},
        )
        self.assertEqual(verified.status_code, 200)
        completed: HttpResponse = self._post(
            complete_route,
            {"reset_id": reset_id, **credential},
        )
        self.assertEqual(completed.status_code, 200)
        self.assertEqual(completed.json()["data"]["status"], "completed")

    def test_expired_access_can_be_refreshed_repeatedly_without_extending_refresh(
        self: Self,
    ) -> None:
        """
        Verify login tokens renew after access expiry and authorize protected API use.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when renewal expires or replaces the active session.
        """
        issued_at: datetime = datetime(2026, 10, 13, 12, tzinfo=timezone.utc)
        with freeze_time(issued_at):
            session: dict[str, Any] = self._login()
            refresh_payload: dict[str, Any] = dict(
                RefreshToken(session["refresh_token"]).payload,
            )

        renewed_at: datetime = issued_at + AccessToken.lifetime + timedelta(seconds=1)
        renewed_access: list[str] = []
        for renewal_time in (renewed_at, renewed_at + timedelta(seconds=1)):
            with self.subTest(renewal_time=renewal_time), freeze_time(renewal_time):
                expired: HttpResponse = self._post(
                    Routes.Logout.BASE,
                    {},
                    access_token=session["access_token"],
                )
                self.assertEqual(expired.status_code, 401)
                refreshed: HttpResponse = self._post(
                    Routes.Refresh.BASE,
                    {"refresh_token": session["refresh_token"]},
                )
                self.assertEqual(refreshed.status_code, 200)
                access_raw: str = refreshed.json()["data"]["access_token"]
                access: AccessToken = AccessToken(access_raw)
                renewed_access.append(access_raw)
                self.assertEqual(access["iat"], int(renewal_time.timestamp()))
                self.assertEqual(access["token_version"], 1)
                self.assertEqual(
                    RefreshToken(session["refresh_token"]).payload,
                    refresh_payload,
                )
                self.user.refresh_from_db()
                self.assertEqual(self.user.token_version, 1)

        self.assertNotEqual(renewed_access[0], renewed_access[1])
        with freeze_time(renewed_at + timedelta(seconds=1)):
            accepted: HttpResponse = self._post(
                Routes.Logout.BASE,
                {},
                access_token=renewed_access[-1],
            )
            self.assertEqual(accepted.status_code, 200)
