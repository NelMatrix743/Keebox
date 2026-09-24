from datetime import timedelta
from typing import Any, Self
from unittest.mock import Mock, patch
from uuid import uuid4

from django.http import HttpRequest, HttpResponse
from django.test import TestCase
from django.utils import timezone
from ninja_jwt.exceptions import InvalidToken

from apps.authentication.auth import VersionedJWTAuth
from apps.authentication.models import ResetChallenge, User
from apps.authentication.routes import Routes
from apps.authentication.services.reset_services import ResetService, ResetStartResult
from apps.authentication.services.token_services import TokenService
from apps.core.choices import ResetStatus, ResetType



class PasswordResetCompletionAPITests(TestCase):
    def setUp(self: Self) -> None:
        """
        Create an account and isolate reset OTP delivery.

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

    def _verified_challenge(self: Self, reset_type: ResetType) -> ResetChallenge:
        """
        Prepare an OTP-verified reset for the selected credential type.

        Args:
            self: Current test case instance.
            reset_type: Password or PIN reset type to prepare.

        Returns:
            The verified reset challenge.

        Raises:
            InvalidResetChallengeError: Raised if OTP verification fails.
        """
        started: ResetStartResult = ResetService.start_reset(
            self.user.email,
            reset_type,
        )
        return ResetService.verify_reset_otp(started.reset_id, "048291")

    def _post_completion(self: Self, reset_id: str, password: str) -> HttpResponse:
        """
        Submit a password reset completion request through the API.

        Args:
            self: Current test case instance.
            reset_id: Reset challenge identifier sent by the client.
            password: New account password sent by the client.

        Returns:
            HTTP response from the completion endpoint.

        Raises:
            None.
        """
        return self.client.post(
            f"/api/auth{Routes.Reset.PASSWORD_COMPLETE}",
            data={"reset_id": reset_id, "new_password": password},
            content_type="application/json",
        )
