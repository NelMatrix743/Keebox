from typing import Self
from unittest.mock import patch
from uuid import uuid4

from django.test import TestCase
from django.utils import timezone

from apps.authentication.exceptions import (
    InvalidRegistrationStateError,
    OTPResendCooldownError,
    OTPResendLimitError,
)
from apps.authentication.models import OTPVerification, RegistrationChallenge
from apps.authentication.registration_services import RegistrationService
from apps.core.choices import OTPStatus, RegistrationStatus
from apps.core.constants import OTP_MAX_RESENDS, OTP_RESEND_COOLDOWN



class OTPResendServiceTests(TestCase):
    def _create_registration_with_otp(
        self: Self,
    ) -> tuple[RegistrationChallenge, OTPVerification]:
        """
        Create a pending registration with an OTP eligible for replacement.

        Args:
            self: Current test case instance.

        Returns:
            The persisted registration challenge and its current OTP.

        Raises:
            ValueError: Raised when the test credentials are invalid.
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
            last_sent_at=timezone.now() - OTP_RESEND_COOLDOWN,
        )
        otp_verification.hash_and_set_otp_code("111111")
        otp_verification.save()
        return challenge, otp_verification

    def test_resend_registration_otp_creates_a_replacement(self: Self) -> None:
        """
        Verify a resend expires the old OTP and creates a protected replacement.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when replacement OTP issuance is incorrect.
        """
        challenge, previous_otp = self._create_registration_with_otp()

        with patch(
            "apps.authentication.registration_services.generate_otp_code",
            return_value="222222",
        ):
            replacement_otp, raw_code = RegistrationService.resend_registration_otp(
                challenge.id,
            )

        challenge.refresh_from_db()
        previous_otp.refresh_from_db()
        self.assertEqual(challenge.resend_count, 1)
        self.assertEqual(previous_otp.status, OTPStatus.EXPIRED)
        self.assertEqual(replacement_otp.status, OTPStatus.PENDING)
        self.assertTrue(replacement_otp.verify_otp_code(raw_code))
        self.assertEqual(raw_code, "222222")
        self.assertEqual(challenge.otp_verifications.count(), 2)

    def test_resend_registration_otp_enforces_the_cooldown(self: Self) -> None:
        """
        Verify a replacement cannot be issued before the cooldown elapses.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an early resend changes persisted state.
        """
        challenge, current_otp = self._create_registration_with_otp()
        current_otp.last_sent_at = timezone.now()
        current_otp.save(update_fields=["last_sent_at", "updated_at"])

        with self.assertRaises(OTPResendCooldownError):
            RegistrationService.resend_registration_otp(challenge.id)

        challenge.refresh_from_db()
        current_otp.refresh_from_db()
        self.assertEqual(challenge.resend_count, 0)
        self.assertEqual(current_otp.status, OTPStatus.PENDING)
        self.assertEqual(challenge.otp_verifications.count(), 1)

    def test_resend_registration_otp_invalidates_challenge_at_limit(
        self: Self,
    ) -> None:
        """
        Verify exceeding the resend allowance cancels the registration workflow.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a resend-limit challenge remains active.
        """
        challenge, current_otp = self._create_registration_with_otp()
        challenge.resend_count = OTP_MAX_RESENDS
        challenge.save(update_fields=["resend_count", "updated_at"])

        with self.assertRaises(OTPResendLimitError):
            RegistrationService.resend_registration_otp(challenge.id)

        challenge.refresh_from_db()
        current_otp.refresh_from_db()
        self.assertEqual(challenge.status, RegistrationStatus.CANCELLED)
        self.assertEqual(current_otp.status, OTPStatus.EXPIRED)
        self.assertEqual(challenge.otp_verifications.count(), 1)

    def test_resend_registration_otp_requires_an_active_registration_and_otp(
        self: Self,
    ) -> None:
        """
        Verify resending requires a pending registration with an issued OTP.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an invalid resend request is accepted.
        """
        challenge, current_otp = self._create_registration_with_otp()
        challenge.status = RegistrationStatus.OTP_VERIFIED
        challenge.save(update_fields=["status", "updated_at"])

        with self.assertRaises(InvalidRegistrationStateError):
            RegistrationService.resend_registration_otp(challenge.id)

        empty_challenge: RegistrationChallenge = RegistrationChallenge(
            first_name="Keebox",
            last_name="User",
            email="new@example.com",
        )
        empty_challenge.set_password("correct horse battery staple")
        empty_challenge.save()

        with self.assertRaises(InvalidRegistrationStateError):
            RegistrationService.resend_registration_otp(empty_challenge.id)

        with self.assertRaises(InvalidRegistrationStateError):
            RegistrationService.resend_registration_otp(uuid4())

        current_otp.refresh_from_db()
        self.assertEqual(current_otp.status, OTPStatus.PENDING)
