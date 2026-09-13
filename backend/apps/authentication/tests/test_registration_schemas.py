from datetime import datetime, timedelta
from typing import Self, cast
from uuid import UUID, uuid4

from django.test import SimpleTestCase
from django.utils import timezone
from pydantic import ValidationError

from apps.authentication.schemas import (
    RegistrationRequest,
    RegistrationStartedResponse,
)
from apps.core.choices import RegistrationStatus
from apps.core.response import ErrorData, ErrorResponse, APIResponse, SuccessResponse



class RegistrationSchemaTests(SimpleTestCase):
    def test_registration_request_normalizes_and_validates_input(
        self: Self,
    ) -> None:
        """
        Verify valid registration input is normalized for the service layer.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when valid input is rejected or not normalized.
        """
        request: RegistrationRequest = RegistrationRequest.model_validate(
            {
                "first_name": "  Nelson  ",
                "last_name": "  Ubochiegbu  ",
                "email": "  Nelson@Example.COM  ",
                "password": "correct horse battery staple",
            },
        )

        self.assertEqual(request.first_name, "Nelson")
        self.assertEqual(request.last_name, "Ubochiegbu")
        self.assertEqual(str(request.email), "Nelson@example.com")
        self.assertEqual(request.password, "correct horse battery staple")

    def test_registration_request_rejects_invalid_registration_data(
        self: Self,
    ) -> None:
        """
        Verify invalid names, emails, and weak passwords are rejected.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when invalid registration input is accepted.
        """
        invalid_payloads: tuple[dict[str, str], ...] = (
            {
                "first_name": "  ",
                "last_name": "Ubochiegbu",
                "email": "nelson@example.com",
                "password": "correct horse battery staple",
            },
            {
                "first_name": "Nelson",
                "last_name": "Ubochiegbu",
                "email": "not-an-email",
                "password": "correct horse battery staple",
            },
            {
                "first_name": "Nelson",
                "last_name": "Ubochiegbu",
                "email": "nelson@example.com",
                "password": "12345678",
            },
        )

        for payload in invalid_payloads:
            with self.subTest(payload=payload), self.assertRaises(ValidationError):
                RegistrationRequest.model_validate(payload)

    def test_registration_started_response_serializes_the_safe_envelope(
        self: Self,
    ) -> None:
        """
        Verify registration-start data serializes through the success envelope.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the response contract is not preserved.
        """
        current_time: datetime = timezone.now()
        registration_id: UUID = uuid4()
        response: SuccessResponse[RegistrationStartedResponse] = (
            SuccessResponse[RegistrationStartedResponse].model_validate(
                APIResponse.success(
                    {
                        "registration_id": registration_id,
                        "status": RegistrationStatus.OTP_PENDING,
                        "expires_at": current_time + timedelta(minutes=30),
                        "otp_expires_at": current_time + timedelta(minutes=5),
                        "resend_available_at": current_time + timedelta(minutes=1),
                        "message": (
                            "Registration started. Check your email for the "
                            "verification code."
                        ),
                    },
                ),
            )
        )
        serialized_response: dict[str, object] = response.model_dump(mode="json")
        serialized_data: dict[str, object] = cast(
            dict[str, object],
            serialized_response["data"],
        )

        self.assertTrue(serialized_response["success"])
        self.assertEqual(
            serialized_data["registration_id"],
            str(registration_id),
        )
        self.assertIsNone(serialized_response["error"])
        self.assertIsNone(serialized_response["meta"])

    def test_api_error_response_serializes_structured_error_details(
        self: Self,
    ) -> None:
        """
        Verify API errors serialize through the standard error envelope.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when structured error serialization fails.
        """
        error_data: ErrorData = ErrorData(
            code="registration_email_conflict",
            message="An account already uses this email address.",
        )
        response: ErrorResponse[ErrorData] = ErrorResponse[
            ErrorData
        ].model_validate(APIResponse.error(error_data.model_dump()))

        self.assertFalse(response.success)
        self.assertIsNone(response.data)
        self.assertEqual(response.error, error_data)
        self.assertIsNone(response.meta)
