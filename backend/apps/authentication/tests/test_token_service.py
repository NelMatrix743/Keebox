from typing import Self

from django.http import HttpRequest
from django.test import TestCase
from ninja_jwt.exceptions import InvalidToken
from ninja_jwt.tokens import AccessToken, RefreshToken

from apps.authentication.auth import VersionedJWTAuth
from apps.authentication.models import User
from apps.authentication.services.token_services import TokenService



class TokenServiceTests(TestCase):
    def setUp(self: Self) -> None:
        """
        Create an account for token issuance and session-version checks.

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

    def test_issued_access_and_refresh_tokens_carry_the_current_version(
        self: Self,
    ) -> None:
        """
        Verify both issued token types identify the current login generation.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a token has a missing or wrong version.
        """
        access_raw: str
        refresh_raw: str
        access_raw, refresh_raw = TokenService.issue_tokens(self.user)
        access: AccessToken = AccessToken(access_raw)
        refresh: RefreshToken = RefreshToken(refresh_raw)

        self.assertEqual(access["token_version"], 0)
        self.assertEqual(refresh["token_version"], 0)
        self.assertEqual(str(access["user_id"]), str(self.user.id))
        self.assertEqual(str(refresh["user_id"]), str(self.user.id))
