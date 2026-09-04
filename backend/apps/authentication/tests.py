from datetime import datetime, timedelta
from typing import Self
from uuid import UUID

from django.apps import AppConfig, apps
from django.conf import settings
from django.contrib.auth.hashers import identify_hasher
from django.core.exceptions import FieldDoesNotExist
from django.test import TestCase
from django.utils import timezone

from apps.authentication.models import OTPVerification, RegistrationChallenge, User
from apps.core.choices import OTPStatus, RegistrationStatus
from apps.core.constants import OTP_TTL, REGISTRATION_CHALLENGE_TTL



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

    def test_user_has_keebox_security_fields(self: Self) -> None:
        """
        Verify every user can store the server PIN and protected KBKey metadata.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a required Keebox security field is missing.
        """
        user = User(
            email="nelson@example.com",
            first_name="Nelson",
            last_name="Matrix",
            pin_hash="encoded-pin-hash",
            encrypted_kbkey=b"encrypted-kbkey",
            kbkey_nonce=b"twelve-bytes",
        )

        self.assertIsInstance(user.id, UUID)
        self.assertEqual(user.pin_hash, "encoded-pin-hash")
        self.assertEqual(user.pin_version, 0)
        self.assertEqual(user.encrypted_kbkey, b"encrypted-kbkey")
        self.assertEqual(user.kbkey_nonce, b"twelve-bytes")
        self.assertEqual(user.kbkey_encryption_version, 1)


class RegistrationChallengeModelTests(TestCase):
    def test_registration_challenge_stores_protected_registration_data(
        self: Self,
    ) -> None:
        """
        Verify a pending registration normalizes and protects its credentials.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when registration data is stored incorrectly.
        """
        challenge: RegistrationChallenge = RegistrationChallenge(
            first_name="Nelson",
            last_name="Ubochiegbu",
            email="  Nelmatrix155@gmail.COM  ",
        )
        challenge.set_password("correct horse battery staple")
        challenge.save()

        self.assertIsInstance(challenge.id, UUID)
        self.assertEqual(challenge.email, "nelmatrix155@gmail.com")
        self.assertTrue(RegistrationChallenge._meta.get_field("email").unique)
        self.assertNotEqual(challenge.password_hash, "correct horse battery staple")
        identify_hasher(challenge.password_hash)
        self.assertTrue(challenge.check_password("correct horse battery staple"))
        self.assertFalse(challenge.check_password("incorrect password"))

    def test_registration_challenge_rejects_missing_credentials(
        self: Self,
    ) -> None:
        """
        Verify a pending registration rejects missing email and password values.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when incomplete credentials are accepted.
        """
        challenge: RegistrationChallenge = RegistrationChallenge(
            first_name="Nelson",
            last_name="Ubochiegbu",
            email="",
        )

        with self.assertRaisesMessage(ValueError, "email address is required"):
            challenge.save()

        with self.assertRaisesMessage(ValueError, "password is required"):
            challenge.set_password("")

    def test_registration_challenge_starts_pending_and_expires_from_constant(
        self: Self,
    ) -> None:
        """
        Verify a new registration has the initial state and fixed lifetime.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when registration defaults are invalid.
        """
        creation_started: datetime = timezone.now()
        challenge: RegistrationChallenge = RegistrationChallenge(
            first_name="Nelson",
            last_name="Ubochiegbu",
            email="nelmatrix155@gmail.com",
        )

        self.assertEqual(challenge.status, RegistrationStatus.OTP_PENDING)
        self.assertIsNone(challenge.completed_at)
        self.assertAlmostEqual(
            challenge.expires_at,
            creation_started + REGISTRATION_CHALLENGE_TTL,
            delta=timedelta(seconds=1),
        )


class OTPVerificationModelTests(TestCase):
    def test_registration_challenge_owns_multiple_otp_verifications(
        self: Self,
    ) -> None:
        """
        Verify a registration challenge owns multiple cascading OTP records.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when OTP ownership is configured incorrectly.
        """
        challenge: RegistrationChallenge = RegistrationChallenge(
            first_name="Nelson",
            last_name="Ubochiegbu",
            email="nelmatrix155@gmail.com",
        )
        challenge.set_password("correct horse battery staple")
        challenge.save()

        first_otp: OTPVerification = OTPVerification.objects.create(
            registration_challenge=challenge,
            email=challenge.email,
            code_hash="first-code-hash",
        )
        second_otp: OTPVerification = OTPVerification.objects.create(
            registration_challenge=challenge,
            email=challenge.email,
            code_hash="second-code-hash",
        )

        self.assertIsInstance(first_otp.id, UUID)
        self.assertEqual(first_otp.registration_challenge_id, challenge.id)
        self.assertEqual(second_otp.registration_challenge_id, challenge.id)
        self.assertEqual(challenge.otp_verifications.count(), 2)

        challenge.delete()

        self.assertFalse(OTPVerification.objects.exists())
