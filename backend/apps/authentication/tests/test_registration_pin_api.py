from typing import Any, Self

from django.test import TestCase, override_settings
from ninja_jwt.tokens import AccessToken, RefreshToken

from apps.authentication.models import RegistrationChallenge, User
from apps.authentication.routes import Routes
from apps.core.choices import RegistrationStatus
from apps.core.key_utils import decrypt_kbkey, validate_kbkey
from apps.core.pin import verify_lock_pin



@override_settings(
    KEEBOX_MASTER_KEY="KMK-ICEiIyQlJicoKSorLC0uLz-AxMjM0NTY3ODk6Ozw9Pj8",
    KEEBOX_PIN_PEPPER="test-pin-pepper",
)
class RegistrationPINAPITests(TestCase):
    def _create_otp_verified_registration(
        self: Self,
    ) -> RegistrationChallenge:
        """
        Create a persisted registration challenge awaiting its lock PIN.

        Args:
            self: Current test case instance.

        Returns:
            The persisted OTP-verified registration challenge.

        Raises:
            ValueError: Raised when the test password is invalid.
        """
        registration_challenge: RegistrationChallenge = RegistrationChallenge(
            first_name="Nelson",
            last_name="Ubochiegbu",
            email="nelson@example.com",
            status=RegistrationStatus.OTP_VERIFIED,
        )
        registration_challenge.set_password("correct horse battery staple")
        registration_challenge.save()
        return registration_challenge

    def test_create_pin_completes_registration_and_authenticates_user(
        self: Self,
    ) -> None:
        """
        Verify PIN creation completes registration and returns account credentials.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when registration completion is incomplete.
        """
        registration_challenge: RegistrationChallenge = (
            self._create_otp_verified_registration()
        )

        response: Any = self.client.post(
            f"/api/auth{Routes.Registration.CREATE_PIN}",
            data={
                "registration_id": str(registration_challenge.id),
                "pin": "123456",
            },
            content_type="application/json",
        )
        response_body: dict[str, Any] = response.json()

        registration_challenge.refresh_from_db()
        user: User = User.objects.get(email=registration_challenge.email)
        response_data: dict[str, Any] = response_body["data"]
        refresh_token: RefreshToken = RefreshToken(response_data["refresh_token"])
        access_token: AccessToken = AccessToken(response_data["access_token"])

        self.assertEqual(response.status_code, 201)
        self.assertTrue(response_body["success"])
        self.assertIsNone(response_body["error"])
        self.assertIsNone(response_body["meta"])
        self.assertEqual(response_data["user_id"], str(user.id))
        self.assertEqual(response_data["first_name"], user.first_name)
        self.assertEqual(response_data["last_name"], user.last_name)
        self.assertEqual(response_data["email"], user.email)
        self.assertEqual(response_data["status"], "completed")
        self.assertTrue(validate_kbkey(response_data["kbkey"]))
        self.assertEqual(
            decrypt_kbkey(
                user.encrypted_kbkey,
                user.kbkey_nonce,
                "KMK-ICEiIyQlJicoKSorLC0uLz-AxMjM0NTY3ODk6Ozw9Pj8",
                user.kbkey_encryption_version,
            ),
            response_data["kbkey"],
        )
        self.assertTrue(verify_lock_pin("123456", user.pin_hash))
        self.assertTrue(user.check_password("correct horse battery staple"))
        self.assertEqual(
            str(refresh_token["user_id"]),
            str(user.id),
        )
        self.assertEqual(
            str(access_token["user_id"]),
            str(user.id),
        )
        self.assertEqual(
            registration_challenge.status,
            RegistrationStatus.COMPLETED,
        )
        self.assertIsNotNone(registration_challenge.completed_at)

    def test_create_pin_rejects_a_registration_that_is_not_otp_verified(
        self: Self,
    ) -> None:
        """
        Verify PIN creation cannot bypass successful OTP verification.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an unverified registration creates a user.
        """
        registration_challenge: RegistrationChallenge = (
            self._create_otp_verified_registration()
        )
        registration_challenge.status = RegistrationStatus.OTP_PENDING
        registration_challenge.save(update_fields=["status", "updated_at"])

        response: Any = self.client.post(
            f"/api/auth{Routes.Registration.CREATE_PIN}",
            data={
                "registration_id": str(registration_challenge.id),
                "pin": "123456",
            },
            content_type="application/json",
        )
        response_body: dict[str, Any] = response.json()

        registration_challenge.refresh_from_db()
        self.assertEqual(response.status_code, 409)
        self.assertFalse(response_body["success"])
        self.assertIsNone(response_body["data"])
        self.assertEqual(
            response_body["error"]["code"],
            "invalid_registration_state",
        )
        self.assertEqual(
            registration_challenge.status,
            RegistrationStatus.OTP_PENDING,
        )
        self.assertFalse(User.objects.exists())

    def test_create_pin_rejects_an_empty_pin(self: Self) -> None:
        """
        Verify registration cannot complete with an empty lock PIN.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an empty PIN creates a permanent user.
        """
        registration_challenge: RegistrationChallenge = (
            self._create_otp_verified_registration()
        )

        response: Any = self.client.post(
            f"/api/auth{Routes.Registration.CREATE_PIN}",
            data={
                "registration_id": str(registration_challenge.id),
                "pin": "",
            },
            content_type="application/json",
        )
        response_body: dict[str, Any] = response.json()

        registration_challenge.refresh_from_db()
        self.assertEqual(response.status_code, 422)
        self.assertFalse(response_body["success"])
        self.assertIsNone(response_body["data"])
        self.assertEqual(response_body["error"]["code"], "validation_error")
        self.assertEqual(
            registration_challenge.status,
            RegistrationStatus.OTP_VERIFIED,
        )
        self.assertFalse(User.objects.exists())
