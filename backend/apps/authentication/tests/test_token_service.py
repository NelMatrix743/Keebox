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

    def test_authentication_rejects_an_access_token_from_an_older_login(
        self: Self,
    ) -> None:
        """
        Verify a newer login invalidates the previous access token.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a stale access token authenticates.
        """
        old_access: str
        old_access, _ = TokenService.issue_tokens(self.user)
        self.user.token_version += 1
        self.user.save(update_fields=["token_version"])
        new_access: str
        new_access, _ = TokenService.issue_tokens(self.user)
        authentication: VersionedJWTAuth = VersionedJWTAuth()

        with self.assertRaises(InvalidToken):
            authentication.authenticate(HttpRequest(), old_access)
        self.assertEqual(
            authentication.authenticate(HttpRequest(), new_access),
            self.user,
        )

    def test_refresh_rejects_an_older_or_unversioned_token(self: Self) -> None:
        """
        Verify an older login cannot mint new access tokens by refreshing.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an obsolete refresh token is accepted.
        """
        old_refresh: str
        _, old_refresh = TokenService.issue_tokens(self.user)
        unversioned_refresh: RefreshToken = RefreshToken.for_user(self.user)
        self.user.token_version += 1
        self.user.save(update_fields=["token_version"])
        new_refresh: str
        _, new_refresh = TokenService.issue_tokens(self.user)

        with self.assertRaises(InvalidToken):
            TokenService.refresh_access_token(old_refresh)
        with self.assertRaises(InvalidToken):
            TokenService.refresh_access_token(str(unversioned_refresh))
        refreshed_access: AccessToken = AccessToken(
            TokenService.refresh_access_token(new_refresh),
        )
        self.assertEqual(refreshed_access["token_version"], 1)
