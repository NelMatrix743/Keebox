from datetime import datetime, timedelta
from typing import Any, Self
from unittest.mock import Mock, patch
from uuid import uuid4

from django.http import HttpResponse
from django.test import TestCase
from django.utils import timezone

from apps.authentication.models import OTPVerification, ResetChallenge, User
from apps.authentication.routes import Routes
from apps.authentication.services.reset_services import ResetService, ResetStartResult
from apps.core.choices import OTPStatus, ResetStatus, ResetType
from apps.core.constants import OTP_MAX_ATTEMPTS, RESET_CHALLENGE_COMPLETION_TTL



class ResetOTPVerificationAPITests(TestCase):
    def setUp(self: Self) -> None:
        """
        Create an account and isolate OTP generation and email delivery.

        Args:
            self: Current test case instance.

        Returns:
            None: This setup method does not return a value.

        Raises:
            None.
        """
        self.user: User = User.objects.create_user(
            email="ada@example.com",
            password="original strong password 5821",
            first_name="Ada",
            last_name="Lovelace",
        )
        email_patcher: Any = patch(
            "apps.authentication.services.reset_services.EmailDeliveryService",
        )
        code_patcher: Any = patch(
            "apps.authentication.services.reset_services.generate_otp_code",
            return_value="048291",
        )
        self.email_delivery_service: Mock = email_patcher.start()
        self.generate_otp: Mock = code_patcher.start()
        self.addCleanup(email_patcher.stop)
        self.addCleanup(code_patcher.stop)

    def _start_reset(self: Self, reset_type: ResetType) -> ResetChallenge:
        """
        Start a reset challenge for the chosen credential type.

        Args:
            self: Current test case instance.
            reset_type: Password or PIN recovery purpose.

        Returns:
            The pending reset challenge.

        Raises:
            ValueError: Raised when the reset request is invalid.
        """
        started: ResetStartResult = ResetService.start_reset(
            self.user.email,
            reset_type,
        )
        return ResetChallenge.objects.get(pk=started.reset_id)

    def _post_verification(self: Self, reset_id: str, otp_code: str) -> HttpResponse:
        """
        Submit one reset OTP verification request through the API.

        Args:
            self: Current test case instance.
            reset_id: Reset challenge identifier sent by the client.
            otp_code: Six-digit verification code sent by the client.

        Returns:
            HTTP response from the verification endpoint.

        Raises:
            None.
        """
        return self.client.post(
            f"/api/auth{Routes.Reset.VERIFY_OTP}",
            data={"reset_id": reset_id, "otp_code": otp_code},
            content_type="application/json",
        )
