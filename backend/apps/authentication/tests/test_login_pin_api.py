from datetime import timedelta
from typing import Any, Self

from django.test import TestCase, override_settings
from django.utils import timezone
from ninja_jwt.tokens import AccessToken, RefreshToken

from apps.authentication.models import LoginChallenge, User
from apps.core.choices import LoginStatus
from apps.core.key_utils import encrypt_kbkey, generate_kbkey
from apps.core.pin import encrypt_lock_pin



@override_settings(
    KEEBOX_MASTER_KEY="KMK-ICEiIyQlJicoKSorLC0uLz-AxMjM0NTY3ODk6Ozw9Pj8",
    KEEBOX_PIN_PEPPER="test-pin-pepper",
)
class LoginPINAPITests(TestCase):
    def _create_user(self: Self) -> tuple[User, str]:
        """
        Create a user with a protected lock PIN and KBKey.

        Args:
            self: Current test case instance.

        Returns:
            The persisted user and their plaintext KBKey.

        Raises:
            ValueError: Raised when test key material cannot be protected.
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
        user: User = User.objects.create_user(
            email="nelson@example.com",
            password="correct horse battery staple",
            first_name="Nelson",
            last_name="Ubochiegbu",
            pin_hash=encrypt_lock_pin("123456"),
            encrypted_kbkey=encrypted_kbkey,
            kbkey_nonce=kbkey_nonce,
            kbkey_encryption_version=kbkey_encryption_version,
        )
        return user, kbkey

    def _create_login_challenge(self: Self) -> tuple[LoginChallenge, str]:
        """
        Create a password-verified login challenge with recoverable key material.

        Args:
            self: Current test case instance.

        Returns:
            The persisted login challenge and its expected plaintext KBKey.

        Raises:
            ValueError: Raised when the test user cannot be created.
        """
        user: User
        kbkey: str
        user, kbkey = self._create_user()
        return LoginChallenge.objects.create(user=user), kbkey

    def _verify_pin(self: Self, login_challenge_id: str, pin: str) -> Any:
        """
        Submit a lock PIN to the login PIN-verification endpoint.

        Args:
            self: Current test case instance.
            login_challenge_id: Identifier of the login challenge to complete.
            pin: Lock PIN value to submit.

        Returns:
            The HTTP response returned by the endpoint.

        Raises:
            None.
        """
        return self.client.post(
            "/api/auth/login/verify-pin",
            data={
                "login_challenge_id": login_challenge_id,
                "pin": pin,
            },
            content_type="application/json",
        )

    def test_login_pin_verification_returns_the_authenticated_user(
        self: Self,
    ) -> None:
        """
        Verify a correct PIN completes login and returns tokens with the KBKey.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when successful login completion is incomplete.
        """
        login_challenge: LoginChallenge
        expected_kbkey: str
        login_challenge, expected_kbkey = self._create_login_challenge()

        response: Any = self._verify_pin(str(login_challenge.id), "123456")
        response_body: dict[str, Any] = response.json()
        response_data: dict[str, Any] = response_body["data"]
        refresh_token: RefreshToken = RefreshToken(response_data["refresh_token"])
        access_token: AccessToken = AccessToken(response_data["access_token"])

        login_challenge.refresh_from_db()
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response_body["success"])
        self.assertEqual(response_data["user_id"], str(login_challenge.user_id))
        self.assertEqual(response_data["kbkey"], expected_kbkey)
        self.assertEqual(response_data["status"], "completed")
        self.assertEqual(login_challenge.status, LoginStatus.COMPLETED)
        self.assertEqual(str(refresh_token["user_id"]), str(login_challenge.user_id))
        self.assertEqual(str(access_token["user_id"]), str(login_challenge.user_id))

    def test_login_pin_verification_rejects_an_invalid_pin(self: Self) -> None:
        """
        Verify an invalid PIN returns a safe error without authentication tokens.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an invalid PIN appears authenticated.
        """
        login_challenge: LoginChallenge
        _expected_kbkey: str
        login_challenge, _expected_kbkey = self._create_login_challenge()

        response: Any = self._verify_pin(str(login_challenge.id), "654321")
        response_body: dict[str, Any] = response.json()

        self.assertEqual(response.status_code, 400)
        self.assertFalse(response_body["success"])
        self.assertIsNone(response_body["data"])
        self.assertEqual(response_body["error"]["code"], "invalid_login_pin")
        self.assertNotIn("access_token", str(response_body))

    def test_login_pin_verification_locks_after_the_fifth_invalid_pin(
        self: Self,
    ) -> None:
        """
        Verify the fifth invalid PIN locks the login and account for twenty-four hours.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the PIN attempt limit is not enforced.
        """
        login_challenge: LoginChallenge
        _expected_kbkey: str
        login_challenge, _expected_kbkey = self._create_login_challenge()

        for _ in range(4):
            response: Any = self._verify_pin(str(login_challenge.id), "654321")
            self.assertEqual(response.status_code, 400)

        response = self._verify_pin(str(login_challenge.id), "654321")
        response_body: dict[str, Any] = response.json()

        login_challenge.refresh_from_db()
        user: User = User.objects.get(pk=login_challenge.user_id)
        self.assertEqual(response.status_code, 423)
        self.assertEqual(response_body["error"]["code"], "login_pin_attempt_limit")
        self.assertEqual(login_challenge.status, LoginStatus.LOCKED)
        self.assertIsNotNone(user.pin_locked_until)
        self.assertGreater(user.pin_locked_until, timezone.now() + timedelta(hours=23))
