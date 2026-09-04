from typing import Self

from django.test import SimpleTestCase

from apps.core.choices import RegistrationStatus



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
