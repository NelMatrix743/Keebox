from datetime import timedelta
from typing import Any, Self
from unittest.mock import Mock, patch

from django.http import HttpRequest, HttpResponse
from django.test import TestCase, override_settings
from django.utils import timezone
from ninja_jwt.exceptions import InvalidToken

from apps.authentication.auth import VersionedJWTAuth
from apps.authentication.models import OTPVerification, ResetChallenge, User
from apps.authentication.routes import Routes
from apps.authentication.services.token_services import TokenService
from apps.core.choices import OTPStatus, ResetStatus, ResetType
from apps.core.constants import OTP_RESEND_COOLDOWN
from apps.core.key_utils import encrypt_kbkey, generate_kbkey
from apps.core.pin import encrypt_lock_pin, verify_lock_pin



@override_settings(
    KEEBOX_MASTER_KEY="KMK-ICEiIyQlJicoKSorLC0uLz-AxMjM0NTY3ODk6Ozw9Pj8",
    KEEBOX_PIN_PEPPER="test-pin-pepper",
)
class ResetFlowIntegrationTests(TestCase):
    def setUp(self: Self) -> None:
        """
        Prepare an account and capture delivered reset OTP codes.

        Args:
            self: Current test case instance.

        Returns:
            None: This setup method does not return a value.

        Raises:
            ValueError: Raised when test key or PIN material is invalid.
        """
        kbkey: str = generate_kbkey()
        encrypted_kbkey: bytes
        kbkey_nonce: bytes
        kbkey_encryption_version: int
        (
            encrypted_kbkey,
            kbkey_nonce,
            kbkey_encryption_version,
        ) = encrypt_kbkey(
            kbkey,
            "KMK-ICEiIyQlJicoKSorLC0uLz-AxMjM0NTY3ODk6Ozw9Pj8",
        )
        self.user: User = User.objects.create_user(
            email="ada@example.com",
            password="original strong password 5821",
            first_name="Ada",
            last_name="Lovelace",
            pin_hash=encrypt_lock_pin("123456"),
            encrypted_kbkey=encrypted_kbkey,
            kbkey_nonce=kbkey_nonce,
            kbkey_encryption_version=kbkey_encryption_version,
        )
        email_patcher: Any = patch(
            "apps.authentication.services.reset_services.EmailDeliveryService",
        )
        code_patcher: Any = patch(
            "apps.authentication.services.reset_services.generate_otp_code",
            side_effect=["048291", "193847"],
        )
        self.email_delivery_service: Mock = email_patcher.start()
        self.generate_otp: Mock = code_patcher.start()
        self.addCleanup(email_patcher.stop)
        self.addCleanup(code_patcher.stop)

    def _post(self: Self, route: str, payload: dict[str, str]) -> HttpResponse:
        """
        Submit one JSON request to an authentication endpoint.

        Args:
            self: Current test case instance.
            route: Authentication route path after the API prefix.
            payload: Request body submitted by the client.

        Returns:
            HTTP response from the selected endpoint.

        Raises:
            None.
        """
        return self.client.post(
            f"/api/auth{route}",
            data=payload,
            content_type="application/json",
        )
