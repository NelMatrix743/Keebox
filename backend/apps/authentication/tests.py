from uuid import UUID
from typing import Self

from django.apps import AppConfig, apps
from django.conf import settings
from django.core.exceptions import FieldDoesNotExist
from django.test import TestCase

from apps.authentication.models import User



class UserModelTests(TestCase):

    def test_authentication_app_and_user_model_are_configured(
        self: Self,
    ) -> None:
        """
        Verify Django uses the authentication app and its custom user model.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the authentication configuration is invalid.
        """
        app_config: AppConfig = apps.get_app_config("authentication")

        self.assertEqual(app_config.name, "apps.authentication")
        self.assertIn("apps.authentication", settings.INSTALLED_APPS)
        self.assertEqual(settings.AUTH_USER_MODEL, "authentication.User")

    def test_user_uses_email_as_its_login_identifier(
        self: Self,
    ) -> None:
        """
        Verify the custom user authenticates by a unique normalized email.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the email authentication contract is invalid.
        """
        self.assertEqual(User.USERNAME_FIELD, "email")
        self.assertEqual(User.REQUIRED_FIELDS, ["first_name", "last_name"])
        self.assertTrue(User._meta.get_field("email").unique)

        with self.assertRaises(FieldDoesNotExist):
            User._meta.get_field("username")

    def test_user_manager_normalizes_email_and_hashes_password(
        self: Self,
    ) -> None:
        """
        Verify user creation normalizes email and never stores a raw password.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when user creation handles credentials incorrectly.
        """
        user: User = User.objects.create_user(
            email="  Nelson@Example.COM  ",
            password="correct horse battery staple",
            first_name="Nelson",
            last_name="Matrix",
        )

        self.assertEqual(user.email, "nelson@example.com")
        self.assertNotEqual(user.password, "correct horse battery staple")
        self.assertTrue(user.check_password("correct horse battery staple"))

    def test_user_manager_validates_required_credentials(self: Self) -> None:
        """
        Verify the user manager rejects missing account credentials.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when incomplete credentials are accepted.
        """
        with self.assertRaisesMessage(ValueError, "email address is required"):
            User.objects.create_user(email="", password="valid-password")

        with self.assertRaisesMessage(ValueError, "password is required"):
            User.objects.create_user(email="nelson@example.com", password="")

    def test_user_manager_creates_privileged_superuser(self: Self) -> None:
        """
        Verify superuser creation applies and validates administrative flags.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when superuser privileges are configured incorrectly.
        """
        user: User = User.objects.create_superuser(
            email="admin@example.com",
            password="valid-password",
            first_name="Keebox",
            last_name="Admin",
        )

        self.assertTrue(user.is_staff)
        self.assertTrue(user.is_superuser)

        with self.assertRaisesMessage(ValueError, "is_staff=True"):
            User.objects.create_superuser(
                email="invalid@example.com",
                password="valid-password",
                is_staff=False,
            )
