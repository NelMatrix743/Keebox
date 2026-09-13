from typing import Self
from uuid import UUID, uuid4

from django.test import SimpleTestCase
from pydantic import ValidationError

from apps.authentication.schemas import (
    RegistrationCompletedResponse,
    RegistrationVerificationRequest,
)
from apps.core.choices import RegistrationStatus
from apps.core.response import APIResponse, SuccessResponse



class RegistrationVerificationSchemaTests(SimpleTestCase):
    def test_verification_request_accepts_a_uuid_and_six_digit_otp(
        self: Self,
    ) -> None:
        """
        Verify valid OTP verification data preserves leading zeroes.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when valid verification data is rejected.
        """
        registration_id: UUID = uuid4()

        request: RegistrationVerificationRequest = (
            RegistrationVerificationRequest.model_validate(
                {
                    "registration_id": registration_id,
                    "otp_code": "048291",
                },
            )
        )

        self.assertEqual(request.registration_id, registration_id)
        self.assertEqual(request.otp_code, "048291")
