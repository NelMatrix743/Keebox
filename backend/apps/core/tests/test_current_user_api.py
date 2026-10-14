from typing import Any, Self

from django.http import HttpResponse
from django.test import TestCase

from apps.authentication.models import User
from apps.authentication.services.token_services import TokenService
from apps.core.routes import Routes



class CurrentUserAPITests(TestCase):
    def setUp(self: Self) -> None:
        """
        Create an account with protected fields and a current authentication session.

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
            pin_hash="protected-pin",
            encrypted_kbkey=b"protected-kbkey",
            kbkey_nonce=b"nonce-value!",
        )
        self.access_token: str
        self.refresh_token: str
        self.access_token, self.refresh_token = TokenService.issue_tokens(self.user)

    def _get_current_user(self: Self, token: str | None = None) -> HttpResponse:
        """
        Retrieve the current account with optional bearer credentials.

        Args:
            self: Current test case instance.
            token: Access token submitted in the authorization header, if provided.

        Returns:
            HTTP response from the current-user endpoint.

        Raises:
            None.
        """
        headers: dict[str, str] = {}
        if token is not None:
            headers["HTTP_AUTHORIZATION"] = f"Bearer {token}"
        return self.client.get(f"/api{Routes.CurrentUser.BASE}", **headers)

    def test_current_user_returns_only_the_authenticated_accounts_public_data(
        self: Self,
    ) -> None:
        """
        Verify authenticated retrieval exposes only the approved public account fields.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when account data is wrong or security fields leak.
        """
        response: HttpResponse = self._get_current_user(self.access_token)
        body: dict[str, Any] = response.json()

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            body,
            {
                "success": True,
                "data": {
                    "user_id": str(self.user.id),
                    "first_name": "Ada",
                    "last_name": "Lovelace",
                    "email": "ada@example.com",
                },
                "error": None,
                "meta": None,
            },
        )

    def test_current_user_requires_bearer_credentials(self: Self) -> None:
        """
        Verify anonymous requests receive the standard authentication-required error.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when unauthenticated requests expose account data.
        """
        response: HttpResponse = self._get_current_user()

        self.assertEqual(response.status_code, 401)
        self.assertEqual(
            response.json(),
            {
                "success": False,
                "data": None,
                "error": {
                    "code": "authentication_required",
                    "message": "Authentication is required.",
                    "details": None,
                },
                "meta": None,
            },
        )
