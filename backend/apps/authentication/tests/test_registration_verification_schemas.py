from typing import Self
from uuid import UUID, uuid4

from django.test import SimpleTestCase
from pydantic import ValidationError

from apps.authentication.schemas import (
    RegistrationCompletedResponse,
    RegistrationOTPVerifiedResponse,
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

    def test_otp_verified_response_serializes_through_the_envelope(
        self: Self,
    ) -> None:
        """
        Verify OTP verification returns the PIN-setup continuation data.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when OTP-verified serialization fails.
        """
        registration_id: UUID = uuid4()
        response: SuccessResponse[RegistrationOTPVerifiedResponse] = (
            SuccessResponse[RegistrationOTPVerifiedResponse].model_validate(
                APIResponse.success(
                    {
                        "registration_id": registration_id,
                        "status": RegistrationStatus.OTP_VERIFIED,
                        "message": (
                            "Email verified. Create your lock PIN to complete "
                            "registration."
                        ),
                    },
                ),
            )
        )
        serialized_response: dict[str, object] = response.model_dump(mode="json")

        self.assertEqual(
            serialized_response,
            {
                "success": True,
                "data": {
                    "registration_id": str(registration_id),
                    "status": "otp_verified",
                    "message": (
                        "Email verified. Create your lock PIN to complete "
                        "registration."
                    ),
                },
                "error": None,
                "meta": None,
            },
        )

    def test_otp_verified_response_rejects_unsafe_or_incomplete_data(
        self: Self,
    ) -> None:
        """
        Verify the OTP-verified response accepts only its public contract.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when unsafe OTP-verified data is accepted.
        """
        user_id: UUID = uuid4()
        registration_id: UUID = uuid4()
        invalid_payloads: tuple[dict[str, object], ...] = (
            {
                "registration_id": registration_id,
                "status": "completed",
                "message": "Email verified.",
            },
            {
                "user_id": user_id,
                "registration_id": registration_id,
                "status": "otp_verified",
                "message": "Email verified.",
            },
            {
                "status": "otp_verified",
                "message": "Email verified.",
            },
        )

        for payload in invalid_payloads:
            with self.subTest(payload=payload), self.assertRaises(ValidationError):
                RegistrationOTPVerifiedResponse.model_validate(payload)

    def test_completed_response_identifies_the_created_user(self: Self) -> None:
        """
        Verify final registration data identifies the newly created user.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when final response serialization fails.
        """
        user_id: UUID = uuid4()
        response: RegistrationCompletedResponse = (
            RegistrationCompletedResponse.model_validate(
                {
                    "user_id": user_id,
                    "status": RegistrationStatus.COMPLETED,
                    "message": "Registration completed successfully.",
                },
            )
        )

        self.assertEqual(
            response.model_dump(mode="json"),
            {
                "user_id": str(user_id),
                "status": "completed",
                "message": "Registration completed successfully.",
            },
        )
