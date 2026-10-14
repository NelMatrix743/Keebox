from datetime import datetime, timedelta, timezone
from typing import Any, Self
from unittest.mock import Mock, patch

from django.http import HttpResponse
from django.test import TestCase, override_settings
from freezegun import freeze_time
from ninja_jwt.tokens import AccessToken

from apps.authentication.models import User
from apps.authentication.routes import Routes
from apps.core.key_utils import encrypt_kbkey, generate_kbkey
from apps.core.pin import encrypt_lock_pin
from apps.core.routes import Routes as CoreRoutes



@override_settings(
    KEEBOX_MASTER_KEY="KMK-ICEiIyQlJicoKSorLC0uLz-AxMjM0NTY3ODk6Ozw9Pj8",
    KEEBOX_PIN_PEPPER="test-pin-pepper",
)
class CurrentUserIntegrationTests(TestCase):
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

    def _get_current_user(self: Self, access_token: str) -> HttpResponse:
        """
        Retrieve the current user's public profile with a session access token.

        Args:
            self: Current test case instance.
            access_token: Signed access token used to authenticate the request.

        Returns:
            HTTP response from the current-user endpoint.

        Raises:
            None.
        """
        return self.client.get(
            f"/api{CoreRoutes.CurrentUser.BASE}",
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )

    def test_refreshed_access_retrieves_current_user_after_original_access_expires(
        self: Self,
    ) -> None:
        """
        Verify login, access expiry, and refresh lead to usable current-user retrieval.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when renewed access cannot retrieve public data.
        """
        issued_at: datetime = datetime(2026, 10, 14, 12, tzinfo=timezone.utc)
        with freeze_time(issued_at):
            session: dict[str, Any] = self._login()

        with freeze_time(issued_at + AccessToken.lifetime + timedelta(seconds=1)):
            expired: HttpResponse = self._get_current_user(session["access_token"])
            self.assertEqual(expired.status_code, 401)
            self.assertEqual(expired.json()["error"]["code"], "invalid_session")
            refreshed: HttpResponse = self._post(
                Routes.Refresh.BASE,
                {"refresh_token": session["refresh_token"]},
            )
            self.assertEqual(refreshed.status_code, 200)
            response: HttpResponse = self._get_current_user(
                refreshed.json()["data"]["access_token"],
            )

            self.assertEqual(response.status_code, 200)
            self.assertEqual(
                response.json()["data"],
                {
                    "user_id": str(self.user.id),
                    "first_name": "Ada",
                    "last_name": "Lovelace",
                    "email": "ada@example.com",
                },
            )

    def test_logout_prevents_current_user_retrieval(self: Self) -> None:
        """
        Verify logging out immediately revokes access to the current-user endpoint.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a logged-out session still retrieves data.
        """
        session: dict[str, Any] = self._login()
        before: HttpResponse = self._get_current_user(session["access_token"])
        self.assertEqual(before.status_code, 200)
        logged_out: HttpResponse = self._post(
            Routes.Logout.BASE,
            {},
            access_token=session["access_token"],
        )
        self.assertEqual(logged_out.status_code, 200)

        after: HttpResponse = self._get_current_user(session["access_token"])

        self.assertEqual(after.status_code, 401)
        self.assertEqual(after.json()["error"]["code"], "invalid_session")
        self.assertIsNone(after.json()["data"])

