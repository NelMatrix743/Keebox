from datetime import timedelta
from typing import Self

from django.db import IntegrityError, transaction
from django.test import TestCase
from django.utils import timezone

from apps.authentication.models import OTPVerification, RegistrationChallenge, ResetChallenge, User
from apps.core.choices import ResetStatus, ResetType
from apps.core.constants import RESET_CHALLENGE_COMPLETION_TTL



class ResetChallengeModelTests(TestCase):
    def _create_user(self: Self) -> User:
        """
        Create an account eligible for credential reset.

        Args:
            self: Current test case instance.

        Returns:
            The persisted Keebox user.

        Raises:
            ValueError: Raised when the account credentials are invalid.
        """
        return User.objects.create_user(
            email="nelson@example.com",
            password="correct horse battery staple",
            first_name="Nelson",
            last_name="Ubochiegbu",
        )

    def test_otp_can_belong_to_either_registration_or_reset(self: Self) -> None:
        """
        Verify both workflows can persist OTPs with their own challenge owner.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when either workflow cannot own an OTP.
        """
        user: User = self._create_user()
        reset: ResetChallenge = ResetChallenge.objects.create(
            user=user,
            reset_type=ResetType.PASSWORD,
        )
        registration: RegistrationChallenge = RegistrationChallenge(
            first_name="Other",
            last_name="Person",
            email="other@example.com",
        )
        registration.set_password("another secure password")
        registration.save()

        reset_otp: OTPVerification = OTPVerification.objects.create(
            reset_challenge=reset,
            email=user.email,
            code_hash="reset-code-hash",
        )
        registration_otp: OTPVerification = OTPVerification.objects.create(
            registration_challenge=registration,
            email=registration.email,
            code_hash="registration-code-hash",
        )

        self.assertEqual(reset_otp.reset_challenge, reset)
        self.assertIsNone(reset_otp.registration_challenge)
        self.assertEqual(registration_otp.registration_challenge, registration)
        self.assertIsNone(registration_otp.reset_challenge)
        self.assertEqual(reset.otp_verifications.count(), 1)
        self.assertEqual(registration.otp_verifications.count(), 1)
