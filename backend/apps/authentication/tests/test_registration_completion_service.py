from datetime import timedelta
from typing import Self
from unittest.mock import patch
from uuid import uuid4

from django.test import TestCase, override_settings
from django.utils import timezone

from apps.authentication.exceptions import InvalidRegistrationStateError
from apps.authentication.models import RegistrationChallenge, User
from apps.authentication.services.registration_services import RegistrationService
from apps.core.choices import RegistrationStatus
from apps.core.key_utils import decrypt_kbkey, validate_kbkey
from apps.core.pin import verify_lock_pin



@override_settings(
    KEEBOX_MASTER_KEY="KMK-ICEiIyQlJicoKSorLC0uLz-AxMjM0NTY3ODk6Ozw9Pj8",
    KEEBOX_PIN_PEPPER="test-pin-pepper",
)
class RegistrationCompletionServiceTests(TestCase):
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
            ValueError: Raised when the test credentials are invalid.
        """
        challenge: RegistrationChallenge = RegistrationChallenge(
            first_name="Nelson",
            last_name="Ubochiegbu",
            email="nelmatrix155@gmail.com",
            status=RegistrationStatus.OTP_VERIFIED,
        )
        challenge.set_password("correct horse battery staple")
        challenge.save()
        return challenge

    def test_complete_registration_creates_a_permanent_user(self: Self) -> None:
        """
        Verify an OTP-verified challenge and PIN create one usable user account.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the created user has incorrect data.
        """
        challenge: RegistrationChallenge = (
            self._create_otp_verified_registration()
        )
        password_hash: str = challenge.password_hash

        user: User
        kbkey: str
        user, kbkey = RegistrationService.complete_registration(
            challenge.id,
            "123456",
        )

        challenge.refresh_from_db()
        user.refresh_from_db()
        self.assertEqual(User.objects.count(), 1)
        self.assertEqual(user.first_name, challenge.first_name)
        self.assertEqual(user.last_name, challenge.last_name)
        self.assertEqual(user.email, challenge.email)
        self.assertEqual(user.password, password_hash)
        self.assertTrue(user.check_password("correct horse battery staple"))
        self.assertIsNotNone(user.pin_hash)
        self.assertTrue(verify_lock_pin("123456", user.pin_hash))
        self.assertTrue(validate_kbkey(kbkey))
        self.assertIsNotNone(user.encrypted_kbkey)
        self.assertIsNotNone(user.kbkey_nonce)
        self.assertEqual(
            decrypt_kbkey(
                user.encrypted_kbkey,
                user.kbkey_nonce,
                "KMK-ICEiIyQlJicoKSorLC0uLz-AxMjM0NTY3ODk6Ozw9Pj8",
                user.kbkey_encryption_version,
            ),
            kbkey,
        )
        self.assertEqual(challenge.status, RegistrationStatus.COMPLETED)
        self.assertIsNotNone(challenge.completed_at)

        with self.assertRaises(InvalidRegistrationStateError):
            RegistrationService.complete_registration(challenge.id, "123456")

        self.assertEqual(User.objects.count(), 1)

    def test_complete_registration_rejects_invalid_challenge_states(
        self: Self,
    ) -> None:
        """
        Verify only an OTP-verified registration can create a user.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an invalid registration state is accepted.
        """
        invalid_statuses: tuple[RegistrationStatus, ...] = (
            RegistrationStatus.OTP_PENDING,
            RegistrationStatus.CANCELLED,
            RegistrationStatus.EXPIRED,
        )

        for status in invalid_statuses:
            with self.subTest(status=status):
                challenge: RegistrationChallenge = (
                    self._create_otp_verified_registration()
                )
                challenge.status = status
                challenge.email = f"{status}@example.com"
                challenge.save(update_fields=["status", "email", "updated_at"])

                with self.assertRaises(InvalidRegistrationStateError):
                    RegistrationService.complete_registration(
                        challenge.id,
                        "123456",
                    )

        self.assertFalse(User.objects.exists())

    def test_complete_registration_rejects_expired_and_missing_challenges(
        self: Self,
    ) -> None:
        """
        Verify completion rejects elapsed and unavailable registrations.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an unusable registration creates a user.
        """
        challenge: RegistrationChallenge = (
            self._create_otp_verified_registration()
        )
        challenge.expires_at = timezone.now() - timedelta(microseconds=1)
        challenge.save(update_fields=["expires_at", "updated_at"])

        with self.assertRaises(InvalidRegistrationStateError):
            RegistrationService.complete_registration(challenge.id, "123456")

        with self.assertRaises(InvalidRegistrationStateError):
            RegistrationService.complete_registration(uuid4(), "123456")

        self.assertFalse(User.objects.exists())

    def test_complete_registration_rolls_back_user_creation_on_failure(
        self: Self,
    ) -> None:
        """
        Verify a failed challenge update rolls back permanent user creation.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when registration completion is not atomic.
        """
        challenge: RegistrationChallenge = (
            self._create_otp_verified_registration()
        )

        with (
            patch.object(
                RegistrationChallenge,
                "save",
                side_effect=RuntimeError("simulated persistence failure"),
            ),
            self.assertRaises(RuntimeError),
        ):
            RegistrationService.complete_registration(challenge.id, "123456")

        challenge.refresh_from_db()
        self.assertEqual(
            challenge.status,
            RegistrationStatus.OTP_VERIFIED,
        )
        self.assertIsNone(challenge.completed_at)
        self.assertFalse(User.objects.exists())

    def test_complete_registration_requires_a_lock_pin(self: Self) -> None:
        """
        Verify a permanent user cannot be created without a lock PIN.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when registration completes without a PIN.
        """
        challenge: RegistrationChallenge = (
            self._create_otp_verified_registration()
        )

        with self.assertRaises(ValueError):
            RegistrationService.complete_registration(challenge.id, "")

        challenge.refresh_from_db()
        self.assertEqual(
            challenge.status,
            RegistrationStatus.OTP_VERIFIED,
        )
        self.assertIsNone(challenge.completed_at)
        self.assertFalse(User.objects.exists())
