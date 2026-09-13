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

    def test_verification_request_rejects_malformed_data(self: Self) -> None:
        """
        Verify malformed identifiers, OTP values, and extra fields are rejected.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when malformed verification data is accepted.
        """
        registration_id: UUID = uuid4()
        malformed_payloads: tuple[dict[str, object], ...] = (
            {
                "registration_id": "not-a-uuid",
                "otp_code": "482913",
            },
            {
                "registration_id": registration_id,
                "otp_code": "48291",
            },
            {
                "registration_id": registration_id,
                "otp_code": "4829137",
            },
            {
                "registration_id": registration_id,
                "otp_code": "48A913",
            },
            {
                "registration_id": registration_id,
                "otp_code": "٤٨٢٩١٣",
            },
            {
                "registration_id": registration_id,
                "otp_code": 482913,
            },
            {
                "registration_id": registration_id,
                "otp_code": "482913",
                "unexpected": "value",
            },
            {
                "registration_id": registration_id,
            },
        )

        for payload in malformed_payloads:
            with self.subTest(payload=payload), self.assertRaises(ValidationError):
                RegistrationVerificationRequest.model_validate(payload)
