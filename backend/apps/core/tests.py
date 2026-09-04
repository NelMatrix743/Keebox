from datetime import timedelta
from typing import Self

from django.test import SimpleTestCase

from apps.core.choices import RegistrationStatus
from apps.core.constants import REGISTRATION_CHALLENGE_TTL



class RegistrationStatusTests(SimpleTestCase):
    def test_registration_status_defines_the_registration_lifecycle(
        self: Self,
    ) -> None:
        """
        Verify registration statuses expose the required stored values and labels.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the registration status contract changes.
        """
        self.assertEqual(
            RegistrationStatus.choices,
            [
                ("otp_pending", "OTP pending"),
                ("otp_verified", "OTP verified"),
                ("completed", "Completed"),
                ("expired", "Expired"),
                ("cancelled", "Cancelled"),
            ],
        )


class AuthenticationConstantTests(SimpleTestCase):
    def test_registration_challenge_ttl_is_thirty_minutes(
        self: Self,
    ) -> None:
        """
        Verify pending registrations expire after exactly thirty minutes.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the registration lifetime changes.
        """
        self.assertEqual(REGISTRATION_CHALLENGE_TTL, timedelta(minutes=30))
