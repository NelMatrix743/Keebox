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
