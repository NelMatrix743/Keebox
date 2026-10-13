import base64
import json
from datetime import datetime, timedelta, timezone
from typing import Self

from django.http import HttpRequest
from django.test import TestCase
from freezegun import freeze_time
from ninja_jwt.exceptions import InvalidToken
from ninja_jwt.tokens import AccessToken, RefreshToken

from apps.authentication.auth import VersionedJWTAuth
from apps.authentication.models import User
from apps.authentication.services.token_services import TokenService



class TokenServiceTests(TestCase):
    def test_refresh_renews_expired_access_without_changing_the_session(
        self: Self,
    ) -> None:
        """
        Verify repeated renewal issues current access tokens without extending refresh.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when renewal changes or invalidates the session.
        """
        issued_at: datetime = datetime(2026, 10, 13, 12, tzinfo=timezone.utc)
        with freeze_time(issued_at):
            original_access: str
            refresh_raw: str
            original_access, refresh_raw = TokenService.issue_tokens(self.user)
            refresh: RefreshToken = RefreshToken(refresh_raw)
            refresh_payload: dict[str, object] = dict(refresh.payload)

        renewed_at: datetime = issued_at + AccessToken.lifetime + timedelta(seconds=1)
        for renewal_time in (renewed_at, renewed_at + timedelta(seconds=1)):
            with self.subTest(renewal_time=renewal_time), freeze_time(renewal_time):
                with self.assertRaises(InvalidToken):
                    VersionedJWTAuth().authenticate(HttpRequest(), original_access)
                renewed_raw: str = TokenService.refresh_access_token(refresh_raw)
                renewed: AccessToken = AccessToken(renewed_raw)

                self.assertEqual(renewed["iat"], int(renewal_time.timestamp()))
                self.assertEqual(
                    renewed["exp"],
                    int((renewal_time + AccessToken.lifetime).timestamp()),
                )
                self.assertEqual(renewed["user_id"], str(self.user.id))
                self.assertEqual(renewed["token_version"], self.user.token_version)
                self.assertEqual(
                    VersionedJWTAuth().authenticate(HttpRequest(), renewed_raw),
                    self.user,
                )
                self.assertEqual(RefreshToken(refresh_raw).payload, refresh_payload)

        self.user.refresh_from_db()
        self.assertEqual(self.user.token_version, 0)

    def test_refresh_rejects_malformed_wrong_type_expired_and_tampered_tokens(
        self: Self,
    ) -> None:
        """
        Verify access renewal requires an authentic unexpired refresh token.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an invalid token renews access.
        """
        access_raw: str
        refresh_raw: str
        access_raw, refresh_raw = TokenService.issue_tokens(self.user)
        expired: RefreshToken = RefreshToken(refresh_raw)
        expired.set_exp(lifetime=timedelta(seconds=-1))
        missing_expiry: RefreshToken = RefreshToken(refresh_raw)
        del missing_expiry["exp"]
        header: str
        _original_payload: str
        signature: str
        header, _original_payload, signature = refresh_raw.split(".")
        tampered_payload: dict[str, object] = dict(RefreshToken(refresh_raw).payload)
        tampered_payload["token_version"] = 99
        encoded_payload: str = base64.urlsafe_b64encode(
            json.dumps(tampered_payload).encode("utf-8"),
        ).decode("ascii").rstrip("=")
        tampered: str = f"{header}.{encoded_payload}.{signature}"
        invalid_tokens: tuple[str, ...] = (
            "", " ", "not-a-jwt", access_raw, str(expired), str(missing_expiry),
            tampered,
        )

        for token in invalid_tokens:
            with self.subTest(token_type=token[:12]), self.assertRaises(InvalidToken):
                TokenService.refresh_access_token(token)

    def test_refresh_rejects_missing_or_malformed_user_claims(self: Self) -> None:
        """
        Verify signed refresh tokens must identify an existing UUID account.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a malformed user claim renews access.
        """
        invalid_user_ids: tuple[object, ...] = (None, "not-a-uuid", "", 123, [])
        for user_id in invalid_user_ids:
            with self.subTest(user_id=user_id):
                refresh: RefreshToken = RefreshToken.for_user(self.user)
                refresh["token_version"] = self.user.token_version
                refresh["user_id"] = user_id
                with self.assertRaises(InvalidToken):
                    TokenService.refresh_access_token(str(refresh))

        del refresh["user_id"]
        with self.assertRaises(InvalidToken):
            TokenService.refresh_access_token(str(refresh))

    def test_refresh_rejects_malformed_session_versions(self: Self) -> None:
        """
        Verify session versions require an integer matching the account's version.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a malformed session version is accepted.
        """
        invalid_versions: tuple[object, ...] = (None, False, True, "0", 0.0, [])
        for version in invalid_versions:
            with self.subTest(version=version):
                refresh: RefreshToken = RefreshToken.for_user(self.user)
                refresh["token_version"] = version
                with self.assertRaises(InvalidToken):
                    TokenService.refresh_access_token(str(refresh))

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

    def test_refresh_rejects_a_missing_or_inactive_account(self: Self) -> None:
        """
        Verify token renewal requires an existing active account.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a disabled or deleted account refreshes.
        """
        refresh_raw: str
        _, refresh_raw = TokenService.issue_tokens(self.user)
        self.user.is_active = False
        self.user.save(update_fields=["is_active"])
        with self.assertRaises(InvalidToken):
            TokenService.refresh_access_token(refresh_raw)

        self.user.delete()
        with self.assertRaises(InvalidToken):
            TokenService.refresh_access_token(refresh_raw)
