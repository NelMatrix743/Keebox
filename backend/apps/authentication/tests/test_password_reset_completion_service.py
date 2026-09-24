from datetime import timedelta
from typing import Any, Self
from unittest.mock import Mock, patch
from uuid import uuid4

from django.http import HttpRequest
from django.test import TestCase
from django.utils import timezone
from ninja_jwt.exceptions import InvalidToken

from apps.authentication.auth import VersionedJWTAuth
from apps.authentication.exceptions import (
    ExpiredResetChallengeError,
    InvalidResetChallengeError,
)
from apps.authentication.models import ResetChallenge, User
from apps.authentication.services.reset_services import ResetService, ResetStartResult
from apps.authentication.services.token_services import TokenService
from apps.core.choices import ResetStatus, ResetType



class PasswordResetCompletionServiceTests(TestCase):
    def setUp(self: Self) -> None:
        """
        Create a user and isolate OTP generation and external email delivery.

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

    def _start_and_verify(self: Self, reset_type: ResetType) -> ResetChallenge:
        """
        Start a reset and verify its emailed OTP for a selected credential.

        Args:
            self: Current test case instance.
            reset_type: Password or PIN reset type to prepare.

        Returns:
            The persisted OTP-verified reset challenge.

        Raises:
            InvalidResetChallengeError: Raised if the prepared challenge fails.
        """
        started: ResetStartResult = ResetService.start_reset(
            email=self.user.email,
            reset_type=reset_type,
        )
        return ResetService.verify_reset_otp(started.reset_id, "048291")
