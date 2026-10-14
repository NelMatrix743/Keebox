from typing import Self

from django.http import HttpResponse
from django.test import TestCase

from apps.authentication.models import User
from apps.authentication.services.token_services import TokenService
from apps.core.routes import Routes



class CurrentUserAccountStateTests(TestCase):
    def setUp(self: Self) -> None:
        """
        Create an account and access token for database-backed retrieval checks.

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
        self.access_token, _ = TokenService.issue_tokens(self.user)

    def _get_current_user(self: Self, access_token: str) -> HttpResponse:
        """
        Retrieve public account data using the submitted access token.

        Args:
            self: Current test case instance.
            access_token: Signed access token identifying the requested account.

        Returns:
            HTTP response from the current-user endpoint.

        Raises:
            None.
        """
        return self.client.get(
            f"/api{Routes.CurrentUser.BASE}",
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )

    def test_current_user_reads_updated_values_from_the_database(self: Self) -> None:
        """
        Verify an existing token retrieves account changes made after token issuance.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when retrieval returns outdated profile values.
        """
        User.objects.filter(pk=self.user.id).update(
            first_name="Grace",
            last_name="Hopper",
            email="grace@example.com",
        )

        response: HttpResponse = self._get_current_user(self.access_token)

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json()["data"],
            {
                "user_id": str(self.user.id),
                "first_name": "Grace",
                "last_name": "Hopper",
                "email": "grace@example.com",
            },
        )
