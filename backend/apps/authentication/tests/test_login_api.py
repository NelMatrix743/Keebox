from datetime import timedelta
from typing import Any, Self

from django.http import HttpResponse
from django.test import TestCase
from django.utils import timezone

from apps.authentication.models import LoginChallenge, User
from apps.core.choices import LoginStatus



class LoginAPITests(TestCase):
    def _create_user(self: Self) -> User:
        """
        Create a persisted user that can start a login challenge.

        Args:
            self: Current test case instance.

        Returns:
            The persisted user with valid login credentials.

        Raises:
            ValueError: Raised when the test credentials are invalid.
        """
        return User.objects.create_user(
            email="nelson@example.com",
            password="correct horse battery staple",
            first_name="Nelson",
            last_name="Ubochiegbu",
        )

    def _login_payload(self: Self, password: str) -> dict[str, str]:
        """
        Build a login request payload for the test account.

        Args:
            self: Current test case instance.
            password: Password value to submit with the login request.

        Returns:
            Login request data for the API client.

        Raises:
            None.
        """
        return {
            "email": "nelson@example.com",
            "password": password,
        }

    def test_login_starts_a_password_verified_challenge(self: Self) -> None:
        """
        Verify valid credentials start a pending lock-PIN login challenge.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a valid login cannot start its challenge.
        """
        user: User = self._create_user()

        response: HttpResponse = self.client.post(
            "/api/auth/login",
            data=self._login_payload("correct horse battery staple"),
            content_type="application/json",
        )
        response_body: dict[str, Any] = response.json()

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response_body["success"])
        self.assertEqual(response_body["data"]["status"], "password_verified")
        self.assertIsNone(response_body["error"])
        self.assertIsNone(response_body["meta"])
        login_challenge: LoginChallenge = LoginChallenge.objects.get(
            pk=response_body["data"]["login_challenge_id"],
        )
        self.assertEqual(login_challenge.user, user)
        self.assertEqual(login_challenge.status, LoginStatus.PASSWORD_VERIFIED)

    def test_login_returns_the_same_safe_response_for_invalid_credentials(
        self: Self,
    ) -> None:
        """
        Verify unknown emails and invalid passwords do not reveal account existence.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when invalid credentials leak account information.
        """
        self._create_user()
        invalid_requests: tuple[dict[str, str], ...] = (
            self._login_payload("incorrect password"),
            {
                "email": "unknown@example.com",
                "password": "correct horse battery staple",
            },
        )

        responses: list[dict[str, Any]] = []
        for payload in invalid_requests:
            response: HttpResponse = self.client.post(
                "/api/auth/login",
                data=payload,
                content_type="application/json",
            )
            response_body: dict[str, Any] = response.json()
            responses.append(response_body)

            self.assertEqual(response.status_code, 401)
            self.assertFalse(response_body["success"])
            self.assertIsNone(response_body["data"])
            self.assertEqual(
                response_body["error"]["code"],
                "invalid_login_credentials",
            )

        self.assertEqual(responses[0], responses[1])
        self.assertFalse(LoginChallenge.objects.exists())

    def test_login_rejects_an_account_with_an_active_pin_lock(self: Self) -> None:
        """
        Verify a temporarily locked account cannot begin another login challenge.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an active account lock is bypassed.
        """
        user: User = self._create_user()
        user.pin_failed_attempts = 5
        user.pin_locked_until = timezone.now() + timedelta(hours=24)
        user.save(update_fields=["pin_failed_attempts", "pin_locked_until"])

        response: HttpResponse = self.client.post(
            "/api/auth/login",
            data=self._login_payload("correct horse battery staple"),
            content_type="application/json",
        )
        response_body: dict[str, Any] = response.json()

        self.assertEqual(response.status_code, 423)
        self.assertFalse(response_body["success"])
        self.assertIsNone(response_body["data"])
        self.assertEqual(response_body["error"]["code"], "login_account_locked")
        self.assertFalse(LoginChallenge.objects.exists())
