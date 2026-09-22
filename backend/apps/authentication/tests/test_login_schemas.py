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

