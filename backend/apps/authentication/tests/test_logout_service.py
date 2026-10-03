from typing import Self

from django.test import TestCase
from ninja_jwt.exceptions import InvalidToken

from apps.authentication.models import User
from apps.authentication.services.token_services import TokenService



class LogoutServiceTests(TestCase):
    def setUp(self: Self) -> None:
        """
        Create an account with a current session version.

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

    def test_logout_revokes_the_current_session(self: Self) -> None:
        """
        Verify logout advances the version used by issued tokens.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when logout leaves the session active.
        """
        TokenService.revoke_current_session(
            user_id=self.user.id,
            expected_token_version=0,
        )

        self.user.refresh_from_db()
        self.assertEqual(self.user.token_version, 1)
