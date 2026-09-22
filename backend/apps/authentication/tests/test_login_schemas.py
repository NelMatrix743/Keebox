from datetime import datetime, timedelta
from typing import Self, cast
from uuid import UUID, uuid4

from django.test import SimpleTestCase
from django.utils import timezone
from pydantic import ValidationError

from apps.authentication.schemas import (
    LoginPINVerificationRequest,
    LoginRequest,
    LoginStartedResponse,
)
from apps.core.choices import LoginStatus
from apps.core.response import APIResponse, SuccessResponse



class LoginSchemaTests(SimpleTestCase):
    def test_login_request_normalizes_valid_credentials(self: Self) -> None:
        """
        Verify valid login credentials are normalized for the service layer.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when valid login data is rejected or changed.
        """
        request: LoginRequest = LoginRequest.model_validate(
            {
                "email": "  Nelson@Example.COM  ",
                "password": "correct horse battery staple",
            },
        )

        self.assertEqual(str(request.email), "Nelson@example.com")
        self.assertEqual(request.password, "correct horse battery staple")

    def test_login_request_rejects_malformed_credentials(self: Self) -> None:
        """
        Verify malformed login credentials and unexpected data are rejected.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when malformed login data is accepted.
        """
        invalid_payloads: tuple[dict[str, object], ...] = (
            {
                "email": "not-an-email",
                "password": "correct horse battery staple",
            },
            {
                "email": "nelson@example.com",
                "password": "",
            },
            {
                "email": "nelson@example.com",
                "password": 123456,
            },
            {
                "email": "nelson@example.com",
                "password": "correct horse battery staple",
                "unexpected": "value",
            },
        )

        for payload in invalid_payloads:
            with self.subTest(payload=payload), self.assertRaises(ValidationError):
                LoginRequest.model_validate(payload)
