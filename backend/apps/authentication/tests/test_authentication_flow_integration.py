from typing import Any, Self
from unittest.mock import Mock, patch
from uuid import UUID

from django.test import TestCase, override_settings
from ninja_jwt.exceptions import InvalidToken
from ninja_jwt.tokens import AccessToken, RefreshToken

from apps.authentication.auth import VersionedJWTAuth
from apps.authentication.models import LoginChallenge, RegistrationChallenge, User
from apps.authentication.routes import Routes
from apps.authentication.services.token_services import TokenService
from apps.core.choices import LoginStatus, RegistrationStatus



@override_settings(
    KEEBOX_MASTER_KEY="KMK-ICEiIyQlJicoKSorLC0uLz-AxMjM0NTY3ODk6Ozw9Pj8",
    KEEBOX_PIN_PEPPER="test-pin-pepper",
)
class AuthenticationFlowIntegrationTests(TestCase):
    @patch("apps.authentication.api.EmailDeliveryService")
    @patch(
        "apps.authentication.services.registration_services.generate_otp_code",
        return_value="482913",
    )
    def test_registered_user_can_complete_a_subsequent_login(
        self: Self,
        generate_otp: Mock,
        email_delivery_service: Mock,
    ) -> None:
        """
        Verify registration and a subsequent login return one user and KBKey.

        Args:
            self: Current test case instance.
            generate_otp: Mocked secure OTP generator with a known delivery code.
            email_delivery_service: Mocked external email delivery boundary.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the end-to-end authentication flow fails.
        """
        email_delivery_service.return_value.send_otp_email.return_value = (
            "brevo-message-id"
        )

        registration_response: Any = self.client.post(
            f"/api/auth{Routes.Registration.BASE}",
            data={
                "first_name": "Nelson",
                "last_name": "Ubochiegbu",
                "email": "nelson@example.com",
                "password": "correct horse battery staple",
            },
            content_type="application/json",
        )
        registration_body: dict[str, Any] = registration_response.json()
        registration_id: UUID = UUID(registration_body["data"]["registration_id"])

        otp_response: Any = self.client.post(
            f"/api/auth{Routes.Registration.VERIFY_OTP}",
            data={
                "registration_id": str(registration_id),
                "otp_code": "482913",
            },
            content_type="application/json",
        )

        registration_completion_response: Any = self.client.post(
            f"/api/auth{Routes.Registration.CREATE_PIN}",
            data={
                "registration_id": str(registration_id),
                "pin": "123456",
            },
            content_type="application/json",
        )
        registration_completion_body: dict[str, Any] = (
            registration_completion_response.json()
        )
        registration_completion_data: dict[str, Any] = (
            registration_completion_body["data"]
        )

        login_response: Any = self.client.post(
            f"/api/auth{Routes.Login.BASE}",
            data={
                "email": "nelson@example.com",
                "password": "correct horse battery staple",
            },
            content_type="application/json",
        )
        login_body: dict[str, Any] = login_response.json()
        login_challenge_id: UUID = UUID(login_body["data"]["login_challenge_id"])

        login_completion_response: Any = self.client.post(
            f"/api/auth{Routes.Login.VERIFY_PIN}",
            data={
                "login_challenge_id": str(login_challenge_id),
                "pin": "123456",
            },
            content_type="application/json",
        )
        login_completion_body: dict[str, Any] = login_completion_response.json()
        login_completion_data: dict[str, Any] = login_completion_body["data"]
        user: User = User.objects.get(email="nelson@example.com")
        registration_challenge: RegistrationChallenge = (
            RegistrationChallenge.objects.get(pk=registration_id)
        )
        login_challenge: LoginChallenge = LoginChallenge.objects.get(
            pk=login_challenge_id,
        )
        registration_refresh_token: RefreshToken = RefreshToken(
            registration_completion_data["refresh_token"],
        )
        login_refresh_token: RefreshToken = RefreshToken(
            login_completion_data["refresh_token"],
        )
        login_access_token: AccessToken = AccessToken(
            login_completion_data["access_token"],
        )

        self.assertEqual(registration_response.status_code, 201)
        self.assertEqual(otp_response.status_code, 200)
        self.assertEqual(registration_completion_response.status_code, 201)
        self.assertEqual(login_response.status_code, 200)
        self.assertEqual(login_completion_response.status_code, 200)
        self.assertEqual(registration_challenge.status, RegistrationStatus.COMPLETED)
        self.assertEqual(login_challenge.status, LoginStatus.COMPLETED)
        self.assertEqual(registration_completion_data["user_id"], str(user.id))
        self.assertEqual(login_completion_data["user_id"], str(user.id))
        self.assertEqual(
            login_completion_data["kbkey"],
            registration_completion_data["kbkey"],
        )
        self.assertEqual(str(registration_refresh_token["user_id"]), str(user.id))
        self.assertEqual(str(login_refresh_token["user_id"]), str(user.id))
        self.assertEqual(str(login_access_token["user_id"]), str(user.id))
        self.assertEqual(user.token_version, 1)
        self.assertEqual(registration_refresh_token["token_version"], 0)
        self.assertEqual(login_refresh_token["token_version"], 1)
        self.assertEqual(login_access_token["token_version"], 1)
        with self.assertRaises(InvalidToken):
            VersionedJWTAuth().authenticate(
                registration_completion_response.wsgi_request,
                registration_completion_data["access_token"],
            )
        with self.assertRaises(InvalidToken):
            TokenService.refresh_access_token(
                registration_completion_data["refresh_token"],
            )
        self.assertEqual(
            VersionedJWTAuth().authenticate(
                login_completion_response.wsgi_request,
                login_completion_data["access_token"],
            ),
            user,
        )
        self.assertEqual(User.objects.count(), 1)
        self.assertEqual(LoginChallenge.objects.count(), 1)
        generate_otp.assert_called_once_with()
        email_delivery_service.return_value.send_otp_email.assert_called_once_with(
            recipient_email="nelson@example.com",
            recipient_full_name="Nelson Ubochiegbu",
            otp_code="482913",
            expiration_minutes=5,
        )
