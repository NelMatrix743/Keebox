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
