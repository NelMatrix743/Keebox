from datetime import timedelta
from typing import Self
from unittest.mock import patch
from uuid import uuid4

from django.test import TestCase
from django.utils import timezone

from apps.authentication.exceptions import (
    ConsumedOTPError,
    ExpiredOTPError,
    InvalidOTPError,
    InvalidRegistrationStateError,
    LockedOTPError,
)
from apps.authentication.models import OTPVerification, RegistrationChallenge, User
from apps.authentication.services.registration_services import RegistrationService
from apps.core.choices import OTPStatus, RegistrationStatus
from apps.core.constants import OTP_MAX_ATTEMPTS



class OTPVerificationServiceTests(TestCase):
    def _create_registration_with_otp(
        self: Self,
    ) -> tuple[RegistrationChallenge, OTPVerification]:
        """
        Create a pending registration with one active OTP verification.

        Args:
            self: Current test case instance.

        Returns:
            The persisted registration challenge and active OTP verification.

        Raises:
            ValueError: Raised when the test credentials or OTP are invalid.
        """
        challenge: RegistrationChallenge = RegistrationChallenge(
            first_name="Nelson",
            last_name="Ubochiegbu",
            email="nelmatrix155@gmail.com",
        )
        challenge.set_password("correct horse battery staple")
        challenge.save()
        otp_verification: OTPVerification = OTPVerification(
            registration_challenge=challenge,
            email=challenge.email,
        )
        otp_verification.hash_and_set_otp_code("123456")
        otp_verification.save()
        return challenge, otp_verification

    def test_verify_registration_otp_consumes_a_valid_code(self: Self) -> None:
        """
        Verify a valid code consumes its OTP and advances the registration.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when successful verification state is invalid.
        """
        challenge, otp_verification = self._create_registration_with_otp()

        verified_otp: OTPVerification = RegistrationService.verify_registration_otp(
            challenge.id,
            "123456",
        )

        challenge.refresh_from_db()
        verified_otp.refresh_from_db()
        self.assertEqual(verified_otp, otp_verification)
        self.assertEqual(verified_otp.status, OTPStatus.CONSUMED)
        self.assertIsNotNone(verified_otp.consumed_at)
        self.assertEqual(verified_otp.attempt_count, 0)
        self.assertEqual(
            challenge.status,
            RegistrationStatus.OTP_VERIFIED,
        )
        self.assertFalse(User.objects.exists())

    def test_verify_registration_otp_counts_an_invalid_code(self: Self) -> None:
        """
        Verify an incorrect code consumes one attempt without changing workflow state.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a failed attempt is not persisted correctly.
        """
        challenge, otp_verification = self._create_registration_with_otp()

        with self.assertRaises(InvalidOTPError):
            RegistrationService.verify_registration_otp(challenge.id, "654321")

        challenge.refresh_from_db()
        otp_verification.refresh_from_db()
        self.assertEqual(otp_verification.attempt_count, 1)
        self.assertEqual(otp_verification.status, OTPStatus.PENDING)
        self.assertEqual(challenge.status, RegistrationStatus.OTP_PENDING)

    def test_verify_registration_otp_locks_the_final_failed_attempt(
        self: Self,
    ) -> None:
        """
        Verify the final permitted failed attempt locks the OTP verification.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the attempt limit does not lock the OTP.
        """
        challenge, otp_verification = self._create_registration_with_otp()
        otp_verification.attempt_count = OTP_MAX_ATTEMPTS - 1
        otp_verification.save(update_fields=["attempt_count", "updated_at"])

        with self.assertRaises(LockedOTPError):
            RegistrationService.verify_registration_otp(challenge.id, "654321")

        otp_verification.refresh_from_db()
        self.assertEqual(otp_verification.attempt_count, OTP_MAX_ATTEMPTS)
        self.assertEqual(otp_verification.status, OTPStatus.LOCKED)

    def test_verify_registration_otp_expires_an_elapsed_otp(self: Self) -> None:
        """
        Verify an elapsed OTP is marked expired before rejection.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when elapsed OTP state is not persisted.
        """
        challenge, otp_verification = self._create_registration_with_otp()
        otp_verification.expires_at = timezone.now() - timedelta(microseconds=1)
        otp_verification.save(update_fields=["expires_at", "updated_at"])

        with self.assertRaises(ExpiredOTPError):
            RegistrationService.verify_registration_otp(challenge.id, "123456")

        otp_verification.refresh_from_db()
        self.assertEqual(otp_verification.status, OTPStatus.EXPIRED)
        self.assertEqual(otp_verification.attempt_count, 0)

    def test_verify_registration_otp_rejects_consumed_and_locked_codes(
        self: Self,
    ) -> None:
        """
        Verify consumed and locked OTP records cannot be verified again.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a terminal OTP state is accepted.
        """
        challenge, otp_verification = self._create_registration_with_otp()
        otp_verification.status = OTPStatus.CONSUMED
        otp_verification.consumed_at = timezone.now()
        otp_verification.save(
            update_fields=["status", "consumed_at", "updated_at"],
        )

        with self.assertRaises(ConsumedOTPError):
            RegistrationService.verify_registration_otp(challenge.id, "123456")

        otp_verification.status = OTPStatus.LOCKED
        otp_verification.consumed_at = None
        otp_verification.save(
            update_fields=["status", "consumed_at", "updated_at"],
        )

        with self.assertRaises(LockedOTPError):
            RegistrationService.verify_registration_otp(challenge.id, "123456")

    def test_verify_registration_otp_requires_an_active_registration_and_otp(
        self: Self,
    ) -> None:
        """
        Verify OTP verification requires an active registration and issued code.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an invalid verification owner is accepted.
        """
        challenge, otp_verification = self._create_registration_with_otp()
        challenge.status = RegistrationStatus.CANCELLED
        challenge.save(update_fields=["status", "updated_at"])

        with self.assertRaises(InvalidRegistrationStateError):
            RegistrationService.verify_registration_otp(challenge.id, "123456")

        empty_challenge: RegistrationChallenge = RegistrationChallenge(
            first_name="Keebox",
            last_name="User",
            email="new@example.com",
        )
        empty_challenge.set_password("correct horse battery staple")
        empty_challenge.save()

        with self.assertRaises(InvalidRegistrationStateError):
            RegistrationService.verify_registration_otp(
                empty_challenge.id,
                "123456",
            )

        with self.assertRaises(InvalidRegistrationStateError):
            RegistrationService.verify_registration_otp(uuid4(), "123456")

        otp_verification.refresh_from_db()
        self.assertEqual(otp_verification.status, OTPStatus.PENDING)

    def test_verify_registration_otp_rolls_back_success_state_on_failure(
        self: Self,
    ) -> None:
        """
        Verify a failed registration update restores the active OTP state.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when successful verification is not atomic.
        """
        challenge, otp_verification = self._create_registration_with_otp()

        with (
            patch.object(
                RegistrationChallenge,
                "save",
                side_effect=RuntimeError("simulated persistence failure"),
            ),
            self.assertRaises(RuntimeError),
        ):
            RegistrationService.verify_registration_otp(challenge.id, "123456")

        challenge.refresh_from_db()
        otp_verification.refresh_from_db()
        self.assertEqual(challenge.status, RegistrationStatus.OTP_PENDING)
        self.assertEqual(otp_verification.status, OTPStatus.PENDING)
        self.assertIsNone(otp_verification.consumed_at)
