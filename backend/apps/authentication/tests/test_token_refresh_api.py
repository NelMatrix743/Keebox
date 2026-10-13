from datetime import timedelta
from typing import Any, Self

from django.http import HttpRequest, HttpResponse
from django.test import TestCase
from ninja_jwt.tokens import AccessToken, RefreshToken

from apps.authentication.auth import VersionedJWTAuth
from apps.authentication.models import User
from apps.authentication.routes import Routes
from apps.authentication.services.token_services import TokenService



class TokenRefreshAPITests(TestCase):
    def setUp(self: Self) -> None:
        """
        Create an account with a current access and refresh token pair.

        Args:
            self: Current test case instance.

        Returns:
            None: This setup method does not return a value.

        Raises:
            None.
        """
        self.user: User = User.objects.create_user(
            email="ada@example.com",
            password="correct horse battery staple",
            first_name="Ada",
            last_name="Lovelace",
        )
        self.access_token: str
        self.refresh_token: str
        self.access_token, self.refresh_token = TokenService.issue_tokens(self.user)

    def _post_refresh(self: Self, payload: dict[str, object]) -> HttpResponse:
        """
        Submit a refresh request without an authorization header.

        Args:
            self: Current test case instance.
            payload: Refresh request data submitted as JSON.

        Returns:
            HTTP response from the refresh endpoint.

        Raises:
            None.
        """
        return self.client.post(
            f"/api/auth{Routes.Refresh.BASE}",
            data=payload,
            content_type="application/json",
        )

    def test_refresh_returns_usable_access_without_authorization_header(
        self: Self,
    ) -> None:
        """
        Verify a current refresh token renews access through the success envelope.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when renewal fails or changes the active session.
        """
        original_refresh: dict[str, Any] = dict(RefreshToken(self.refresh_token).payload)
        response: HttpResponse = self._post_refresh({"refresh_token": self.refresh_token})
        body: dict[str, Any] = response.json()

        self.assertEqual(response.status_code, 200)
        self.assertTrue(body["success"])
        self.assertIsNone(body["error"])
        self.assertIsNone(body["meta"])
        self.assertEqual(set(body["data"]), {"access_token"})
        access: AccessToken = AccessToken(body["data"]["access_token"])
        self.assertEqual(access["user_id"], str(self.user.id))
        self.assertEqual(access["token_version"], 0)
        self.assertEqual(
            VersionedJWTAuth().authenticate(HttpRequest(), body["data"]["access_token"]),
            self.user,
        )
        self.assertEqual(RefreshToken(self.refresh_token).payload, original_refresh)
        self.user.refresh_from_db()
        self.assertEqual(self.user.token_version, 0)

    def test_invalid_tokens_return_a_consistent_unauthorized_error(self: Self) -> None:
        """
        Verify invalid, wrong-type, and expired tokens return the agreed failure.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an unusable token renews access.
        """
        expired: RefreshToken = RefreshToken(self.refresh_token)
        expired.set_exp(lifetime=timedelta(seconds=-1))
        for token in ("not-a-jwt", " ", self.access_token, str(expired)):
            with self.subTest(token_type=token[:12]):
                response: HttpResponse = self._post_refresh({"refresh_token": token})

                self.assertEqual(response.status_code, 401)
                self.assertEqual(
                    response.json(),
                    {
                        "success": False,
                        "data": None,
                        "error": {
                            "code": "invalid_refresh_token",
                            "message": "The refresh token is invalid or no longer usable.",
                            "details": None,
                        },
                        "meta": None,
                    },
                )

    def test_superseded_session_cannot_refresh(self: Self) -> None:
        """
        Verify the endpoint rejects refresh tokens from an older session version.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a superseded session renews access.
        """
        self.user.token_version += 1
        self.user.save(update_fields=["token_version"])

        response: HttpResponse = self._post_refresh({"refresh_token": self.refresh_token})

        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.json()["error"]["code"], "invalid_refresh_token")
        self.user.refresh_from_db()
        self.assertEqual(self.user.token_version, 1)
