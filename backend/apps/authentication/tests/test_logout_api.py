from typing import Any, Self

from django.http import HttpRequest, HttpResponse
from django.test import TestCase
from ninja_jwt.exceptions import InvalidToken

from apps.authentication.auth import VersionedJWTAuth
from apps.authentication.models import User
from apps.authentication.routes import Routes
from apps.authentication.services.token_services import TokenService



class LogoutAPITests(TestCase):
    def setUp(self: Self) -> None:
        """
        Create an account and an active access and refresh token pair.

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
        self.access_token: str
        self.refresh_token: str
        self.access_token, self.refresh_token = TokenService.issue_tokens(self.user)

    def _post_logout(self: Self, access_token: str | None) -> HttpResponse:
        """
        Submit logout with an optional bearer access token.

        Args:
            self: Current test case instance.
            access_token: Signed access token, or None for no credentials.

        Returns:
            HTTP response from the logout endpoint.

        Raises:
            None.
        """
        if access_token is None:
            return self.client.post(f"/api/auth{Routes.Logout.BASE}")
        return self.client.post(
            f"/api/auth{Routes.Logout.BASE}",
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )

    def test_logout_invalidates_access_and_refresh_tokens(self: Self) -> None:
        """
        Verify an authenticated logout ends the active session.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when tokens remain valid after logout.
        """
        response: HttpResponse = self._post_logout(self.access_token)
        body: dict[str, Any] = response.json()
        self.user.refresh_from_db()

        self.assertEqual(response.status_code, 200)
        self.assertTrue(body["success"])
        self.assertIsNone(body["error"])
        self.assertIsNone(body["meta"])
        self.assertEqual(body["data"]["status"], "logged_out")
        self.assertEqual(self.user.token_version, 1)
        with self.assertRaises(InvalidToken):
            VersionedJWTAuth().authenticate(HttpRequest(), self.access_token)
        with self.assertRaises(InvalidToken):
            TokenService.refresh_access_token(self.refresh_token)

    def test_missing_or_reused_access_token_cannot_log_out_again(
        self: Self,
    ) -> None:
        """
        Verify logout requires a current authenticated session.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an unauthorized request changes state.
        """
        missing: HttpResponse = self._post_logout(None)
        first: HttpResponse = self._post_logout(self.access_token)
        repeated: HttpResponse = self._post_logout(self.access_token)
        self.user.refresh_from_db()

        self.assertEqual(missing.status_code, 401)
        self.assertEqual(
            missing.json()["error"]["code"],
            "authentication_required",
        )
        self.assertEqual(first.status_code, 200)
        self.assertEqual(repeated.status_code, 401)
        self.assertEqual(repeated.json()["error"]["code"], "invalid_session")
        self.assertEqual(self.user.token_version, 1)
