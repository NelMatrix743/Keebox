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

    def test_login_started_response_serializes_the_pending_challenge(
        self: Self,
    ) -> None:
        """
        Verify login initiation serializes its challenge through the API envelope.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when login-start response data is incomplete.
        """
        current_time: datetime = timezone.now()
        login_challenge_id: UUID = uuid4()
        response: SuccessResponse[LoginStartedResponse] = (
            SuccessResponse[LoginStartedResponse].model_validate(
                APIResponse.success(
                    {
                        "login_challenge_id": login_challenge_id,
                        "status": LoginStatus.PASSWORD_VERIFIED,
                        "expires_at": current_time + timedelta(minutes=10),
                        "message": "Password verified. Enter your lock PIN.",
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
            serialized_data["login_challenge_id"],
            str(login_challenge_id),
        )
        self.assertEqual(
            serialized_data["status"],
            LoginStatus.PASSWORD_VERIFIED,
        )

    def test_login_pin_verification_request_validates_the_pin_challenge(
        self: Self,
    ) -> None:
        """
        Verify a PIN-verification request requires a UUID and nonempty PIN.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when valid or invalid PIN request data is mishandled.
        """
        login_challenge_id: UUID = uuid4()
        request: LoginPINVerificationRequest = (
            LoginPINVerificationRequest.model_validate(
                {
                    "login_challenge_id": login_challenge_id,
                    "pin": "123456",
                },
            )
        )

        self.assertEqual(request.login_challenge_id, login_challenge_id)
        self.assertEqual(request.pin, "123456")

        invalid_payloads: tuple[dict[str, object], ...] = (
            {
                "login_challenge_id": "not-a-uuid",
                "pin": "123456",
            },
            {
                "login_challenge_id": login_challenge_id,
                "pin": "",
            },
            {
                "login_challenge_id": login_challenge_id,
                "pin": 123456,
            },
            {
                "login_challenge_id": login_challenge_id,
                "pin": "123456",
                "unexpected": "value",
            },
        )

        for payload in invalid_payloads:
            with self.subTest(payload=payload), self.assertRaises(ValidationError):
                LoginPINVerificationRequest.model_validate(payload)
