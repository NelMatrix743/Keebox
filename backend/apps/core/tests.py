from datetime import timedelta
from typing import Self

from django.test import SimpleTestCase

from apps.core.choices import OTPStatus, RegistrationStatus
from apps.core.constants import (
    OTP_CODE_LENGTH,
    OTP_MAX_ATTEMPTS,
    OTP_MAX_RESENDS,
    OTP_RESEND_COOLDOWN,
    OTP_TTL,
    REGISTRATION_CHALLENGE_TTL,
)
from apps.core.response import APIResponse



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


class OTPStatusTests(SimpleTestCase):
    def test_otp_status_defines_the_verification_lifecycle(
        self: Self,
    ) -> None:
        """
        Verify OTP statuses expose the required stored values and labels.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the OTP status contract changes.
        """
        self.assertEqual(
            OTPStatus.choices,
            [
                ("pending", "Pending"),
                ("consumed", "Consumed"),
                ("expired", "Expired"),
                ("locked", "Locked"),
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

    def test_otp_policy_constants_define_verification_limits(
        self: Self,
    ) -> None:
        """
        Verify the OTP lifetime, cooldown, attempt, and resend limits.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an OTP policy constant changes.
        """
        self.assertIsInstance(OTP_CODE_LENGTH, int)
        self.assertEqual(OTP_CODE_LENGTH, 6)
        self.assertEqual(OTP_TTL, timedelta(minutes=5))
        self.assertEqual(OTP_RESEND_COOLDOWN, timedelta(seconds=60))
        self.assertEqual(OTP_MAX_ATTEMPTS, 5)
        self.assertEqual(OTP_MAX_RESENDS, 3)


class APIResponseTests(SimpleTestCase):
    def test_success_returns_data_without_an_error(self: Self) -> None:
        """
        Verify a successful response preserves its dynamic response data.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the success envelope is incorrect.
        """
        response_data: dict[str, object] = {
            "registration_id": "a9d6f654-11e5-4b52-9006-d86c1f15fdb2",
            "status": "otp_pending",
        }
        response_meta: dict[str, str] = {
            "request_id": "abc-123",
        }

        response: dict[str, object] = APIResponse.success(
            response_data,
            response_meta,
        )

        self.assertEqual(
            response,
            {
                "success": True,
                "data": response_data,
                "error": None,
                "meta": response_meta,
            },
        )
