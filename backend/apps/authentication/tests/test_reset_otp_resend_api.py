from datetime import timedelta
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
from apps.core.constants import OTP_MAX_RESENDS, OTP_RESEND_COOLDOWN



class ResetOTPResendAPITests(TestCase):
    def setUp(self: Self) -> None:
        """
        Create an account and isolate reset OTP email delivery.

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
        self.email_delivery_service: Mock = email_patcher.start()
        self.addCleanup(email_patcher.stop)

    def _start_reset(self: Self, reset_type: ResetType) -> tuple[ResetChallenge, OTPVerification]:
        """
        Start a password or PIN reset with one pending OTP.

        Args:
            self: Current test case instance.
            reset_type: Credential being recovered.

        Returns:
            The pending reset challenge and its current OTP.

        Raises:
            ValueError: Raised if the reset cannot be initialized.
        """
        started: ResetStartResult = ResetService.start_reset(
            self.user.email,
            reset_type,
        )
        challenge: ResetChallenge = ResetChallenge.objects.get(pk=started.reset_id)
        otp: OTPVerification = OTPVerification.objects.get(reset_challenge=challenge)
        return challenge, otp

    def _post_resend(self: Self, reset_id: str) -> HttpResponse:
        """
        Submit a reset OTP resend request through the public API.

        Args:
            self: Current test case instance.
            reset_id: Reset identifier sent by the client.

        Returns:
            HTTP response from the reset resend endpoint.

        Raises:
            None.
        """
        return self.client.post(
            f"/api/auth{Routes.Reset.RESEND_OTP}",
            data={"reset_id": reset_id},
            content_type="application/json",
        )
