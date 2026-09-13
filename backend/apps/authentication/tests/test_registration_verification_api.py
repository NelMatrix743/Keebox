from datetime import timedelta
from typing import Any, Self
from uuid import uuid4

from django.test import TestCase
from django.utils import timezone

from apps.authentication.models import OTPVerification, RegistrationChallenge, User
from apps.core.choices import OTPStatus, RegistrationStatus



class RegistrationVerificationAPITests(TestCase):
    def _create_registration_with_otp(
        self: Self,
    ) -> tuple[RegistrationChallenge, OTPVerification]:
        """
        Create a pending registration with an active OTP.

        Args:
            self: Current test case instance.

        Returns:
            The persisted registration challenge and OTP verification.

        Raises:
            ValueError: Raised when the test password or OTP is invalid.
        """
        registration_challenge: RegistrationChallenge = RegistrationChallenge(
            first_name="Nelson",
            last_name="Ubochiegbu",
            email="nelson@example.com",
        )
        registration_challenge.set_password("correct horse battery staple")
        registration_challenge.save()
        otp_verification: OTPVerification = OTPVerification(
            registration_challenge=registration_challenge,
            email=registration_challenge.email,
        )
        otp_verification.hash_and_set_otp_code("482913")
        otp_verification.save()
        return registration_challenge, otp_verification

    def _verification_payload(
        self: Self,
        registration_challenge: RegistrationChallenge,
    ) -> dict[str, str]:
        """
        Build valid input for the registration OTP verification endpoint.

        Args:
            self: Current test case instance.
            registration_challenge: Registration challenge being verified.

        Returns:
            Valid registration OTP verification request data.

        Raises:
            None.
        """
        return {
            "registration_id": str(registration_challenge.id),
            "otp_code": "482913",
        }
