from datetime import UTC, datetime, timedelta
from typing import Self
from uuid import UUID, uuid4

from django.test import SimpleTestCase
from pydantic import ValidationError

from apps.authentication.schemas import (
    PasswordResetCompletionRequest,
    PINResetCompletionRequest,
    ResetCompletedResponse,
    ResetOTPResendRequest,
    ResetOTPResentResponse,
    ResetOTPVerificationRequest,
    ResetOTPVerifiedResponse,
    ResetStartedResponse,
    ResetStartRequest,
)
from apps.core.response import APIResponse, SuccessResponse



class ResetSchemaTests(SimpleTestCase):
    def test_start_request_normalizes_email_and_rejects_invalid_input(
        self: Self,
    ) -> None:
        """
        Verify both reset starts accept only a normalized email address.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when reset-start validation is incorrect.
        """
        request: ResetStartRequest = ResetStartRequest.model_validate(
            {"email": "  Ada@Example.com  "},
        )
        self.assertEqual(str(request.email), "Ada@example.com")

        invalid_payloads: tuple[dict[str, object], ...] = (
            {},
            {"email": "invalid-email"},
            {"email": "ada@example.com", "password": "unwanted"},
        )
        for payload in invalid_payloads:
            with self.subTest(payload=payload), self.assertRaises(ValidationError):
                ResetStartRequest.model_validate(payload)

    def test_start_and_resend_responses_share_a_safe_envelope(self: Self) -> None:
        """
        Verify reset initiation and resend data serialize without secrets.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when reset response data is invalid.
        """
        reset_id: UUID = uuid4()
        current_time: datetime = datetime(2026, 9, 23, 10, 0, tzinfo=UTC)
        data: dict[str, object] = {
            "reset_id": reset_id,
            "status": "otp_pending",
            "otp_expires_at": current_time + timedelta(minutes=5),
            "resend_available_at": current_time + timedelta(minutes=1),
            "message": "If an account exists, a verification code has been sent.",
        }

        for response_type in (ResetStartedResponse, ResetOTPResentResponse):
            with self.subTest(response_type=response_type):
                response = SuccessResponse[response_type].model_validate(
                    APIResponse.success(data),
                )
                serialized: dict[str, object] = response.model_dump(mode="json")
                self.assertEqual(serialized["success"], True)
                self.assertEqual(serialized["error"], None)
                self.assertEqual(
                    serialized["data"],
                    {
                        **data,
                        "reset_id": str(reset_id),
                        "otp_expires_at": "2026-09-23T10:05:00Z",
                        "resend_available_at": "2026-09-23T10:01:00Z",
                    },
                )
                with self.assertRaises(ValidationError):
                    response_type.model_validate({**data, "otp_code": "482913"})

    def test_resend_and_verify_requests_validate_the_identifier_and_otp(
        self: Self,
    ) -> None:
        """
        Verify reset OTP requests require a UUID and a six-digit code.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when reset OTP request validation fails.
        """
        reset_id: UUID = uuid4()
        resend: ResetOTPResendRequest = ResetOTPResendRequest.model_validate(
            {"reset_id": reset_id},
        )
        verification: ResetOTPVerificationRequest = (
            ResetOTPVerificationRequest.model_validate(
                {"reset_id": reset_id, "otp_code": "048291"},
            )
        )
        self.assertEqual(resend.reset_id, reset_id)
        self.assertEqual(verification.otp_code, "048291")

        invalid_payloads: tuple[dict[str, object], ...] = (
            {"reset_id": "not-a-uuid", "otp_code": "048291"},
            {"reset_id": reset_id, "otp_code": "48291"},
            {"reset_id": reset_id, "otp_code": "48A913"},
            {"reset_id": reset_id, "otp_code": 482913},
            {"reset_id": reset_id, "otp_code": "048291", "extra": True},
        )
        for payload in invalid_payloads:
            with self.subTest(payload=payload), self.assertRaises(ValidationError):
                ResetOTPVerificationRequest.model_validate(payload)

        with self.assertRaises(ValidationError):
            ResetOTPResendRequest.model_validate(
                {"reset_id": reset_id, "otp_code": "048291"},
            )

    def test_verified_response_exposes_the_completion_deadline(self: Self) -> None:
        """
        Verify a successful OTP check returns the limited completion window.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the verification response is incomplete.
        """
        reset_id: UUID = uuid4()
        response: SuccessResponse[ResetOTPVerifiedResponse] = (
            SuccessResponse[ResetOTPVerifiedResponse].model_validate(
                APIResponse.success(
                    {
                        "reset_id": reset_id,
                        "status": "otp_verified",
                        "completion_expires_at": datetime(
                            2026,
                            9,
                            23,
                            10,
                            10,
                            tzinfo=UTC,
                        ),
                        "message": "Verification complete. Set your new credential.",
                    },
                ),
            )
        )
        self.assertEqual(response.data.reset_id, reset_id)
        self.assertEqual(response.data.status, "otp_verified")
        self.assertEqual(
            response.model_dump(mode="json")["data"]["completion_expires_at"],
            "2026-09-23T10:10:00Z",
        )

    def test_completion_requests_validate_new_credentials_without_a_token(
        self: Self,
    ) -> None:
        """
        Verify credential completion accepts only the reset ID and new value.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when completion request validation is incorrect.
        """
        reset_id: UUID = uuid4()
        password_request: PasswordResetCompletionRequest = (
            PasswordResetCompletionRequest.model_validate(
                {
                    "reset_id": reset_id,
                    "new_password": "a sufficiently strong new password",
                },
            )
        )
        pin_request: PINResetCompletionRequest = (
            PINResetCompletionRequest.model_validate(
                {"reset_id": reset_id, "new_pin": "123456"},
            )
        )
        self.assertEqual(password_request.reset_id, reset_id)
        self.assertEqual(pin_request.new_pin, "123456")

        invalid_password_payloads: tuple[dict[str, object], ...] = (
            {"reset_id": reset_id, "new_password": ""},
            {"reset_id": reset_id, "new_password": "password"},
            {"reset_id": reset_id, "new_password": 123456},
            {
                "reset_id": reset_id,
                "new_password": "a sufficiently strong new password",
                "completion_token": "not-used",
            },
        )
        for payload in invalid_password_payloads:
            with self.subTest(payload=payload), self.assertRaises(ValidationError):
                PasswordResetCompletionRequest.model_validate(payload)

        for payload in (
            {"reset_id": reset_id, "new_pin": ""},
            {"reset_id": reset_id, "new_pin": 123456},
            {
                "reset_id": reset_id,
                "new_pin": "123456",
                "completion_token": "not-used",
            },
        ):
            with self.subTest(payload=payload), self.assertRaises(ValidationError):
                PINResetCompletionRequest.model_validate(payload)

    def test_completed_response_contains_no_login_tokens(self: Self) -> None:
        """
        Verify reset completion confirms success without logging the user in.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when reset completion exposes token data.
        """
        reset_id: UUID = uuid4()
        response: SuccessResponse[ResetCompletedResponse] = (
            SuccessResponse[ResetCompletedResponse].model_validate(
                APIResponse.success(
                    {
                        "reset_id": reset_id,
                        "status": "completed",
                        "message": "Credential reset completed. Sign in again.",
                    },
                ),
            )
        )
        self.assertEqual(response.data.status, "completed")
        self.assertNotIn("access_token", response.model_dump(mode="json")["data"])

        with self.assertRaises(ValidationError):
            ResetCompletedResponse.model_validate(
                {
                    "reset_id": reset_id,
                    "status": "completed",
                    "message": "Credential reset completed. Sign in again.",
                    "refresh_token": "not-allowed",
                },
            )
