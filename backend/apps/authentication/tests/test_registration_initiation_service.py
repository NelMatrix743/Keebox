from typing import Self
from unittest.mock import patch

from django.test import TestCase

from apps.authentication.exceptions import RegistrationEmailConflictError
from apps.authentication.models import OTPVerification, RegistrationChallenge, User
from apps.authentication.registration_services import RegistrationService
from apps.core.choices import RegistrationStatus



class RegistrationInitiationServiceTests(TestCase):
    def test_ensure_email_available_returns_a_normalized_available_email(
        self: Self,
    ) -> None:
        """
        Verify an available registration email is normalized for later use.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an available email is rejected or malformed.
        """
        normalized_email: str = RegistrationService.ensure_email_available(
            "  Nelson@Example.COM  ",
        )

        self.assertEqual(normalized_email, "nelson@example.com")

    def test_ensure_email_available_rejects_an_existing_user_email(
        self: Self,
    ) -> None:
        """
        Verify registration cannot start for an existing permanent account.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an existing account email is accepted.
        """
        User.objects.create_user(
            email="nelson@example.com",
            password="correct horse battery staple",
            first_name="Nelson",
            last_name="Ubochiegbu",
        )

        with self.assertRaises(RegistrationEmailConflictError):
            RegistrationService.ensure_email_available(
                "  Nelson@Example.COM  ",
            )

    def test_ensure_email_available_rejects_an_empty_email(self: Self) -> None:
        """
        Verify registration email availability requires an email address.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an empty registration email is accepted.
        """
        with self.assertRaisesMessage(ValueError, "email address is required"):
            RegistrationService.ensure_email_available("  ")

    def test_start_registration_creates_challenge_and_initial_otp(
        self: Self,
    ) -> None:
        """
        Verify registration initiation persists protected data and an initial OTP.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when registration initiation is incomplete.
        """
        with patch(
            "apps.authentication.registration_services.generate_otp_code",
            return_value="012345",
        ):
            challenge, otp_verification, raw_code = (
                RegistrationService.start_registration(
                    first_name="Nelson",
                    last_name="Ubochiegbu",
                    email="  Nelson@Example.COM  ",
                    raw_password="correct horse battery staple",
                )
            )

        self.assertEqual(challenge.first_name, "Nelson")
        self.assertEqual(challenge.last_name, "Ubochiegbu")
        self.assertEqual(challenge.email, "nelson@example.com")
        self.assertNotEqual(
            challenge.password_hash,
            "correct horse battery staple",
        )
        self.assertTrue(challenge.check_password("correct horse battery staple"))
        self.assertEqual(challenge.status, RegistrationStatus.OTP_PENDING)
        self.assertEqual(otp_verification.registration_challenge, challenge)
        self.assertEqual(otp_verification.email, challenge.email)
        self.assertTrue(otp_verification.verify_otp_code(raw_code))
        self.assertEqual(raw_code, "012345")
        self.assertEqual(RegistrationChallenge.objects.count(), 1)
        self.assertEqual(OTPVerification.objects.count(), 1)

    def test_start_registration_allows_repeated_unregistered_email_attempts(
        self: Self,
    ) -> None:
        """
        Verify an unregistered email can own separate registration attempts.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a repeated pending attempt is rejected.
        """
        first_challenge, _, _ = RegistrationService.start_registration(
            first_name="Nelson",
            last_name="Ubochiegbu",
            email="nelson@example.com",
            raw_password="first valid password",
        )
        second_challenge, _, _ = RegistrationService.start_registration(
            first_name="Nelson",
            last_name="Ubochiegbu",
            email="NELSON@example.com",
            raw_password="second valid password",
        )

        self.assertNotEqual(first_challenge.id, second_challenge.id)
        self.assertEqual(RegistrationChallenge.objects.count(), 2)
        self.assertEqual(OTPVerification.objects.count(), 2)

    def test_start_registration_rejects_an_existing_account(self: Self) -> None:
        """
        Verify registration initiation stops when the email owns an account.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a conflicting registration is persisted.
        """
        User.objects.create_user(
            email="nelson@example.com",
            password="correct horse battery staple",
            first_name="Nelson",
            last_name="Ubochiegbu",
        )

        with self.assertRaises(RegistrationEmailConflictError):
            RegistrationService.start_registration(
                first_name="Nelson",
                last_name="Ubochiegbu",
                email="nelson@example.com",
                raw_password="another valid password",
            )

        self.assertFalse(RegistrationChallenge.objects.exists())
        self.assertFalse(OTPVerification.objects.exists())

    def test_start_registration_rolls_back_when_initial_otp_issuance_fails(
        self: Self,
    ) -> None:
        """
        Verify an OTP issuance failure removes the incomplete registration attempt.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when failed initiation leaves persisted data.
        """
        with (
            patch.object(
                RegistrationService,
                "issue_registration_otp",
                side_effect=RuntimeError("simulated OTP issuance failure"),
            ),
            self.assertRaises(RuntimeError),
        ):
            RegistrationService.start_registration(
                first_name="Nelson",
                last_name="Ubochiegbu",
                email="nelson@example.com",
                raw_password="correct horse battery staple",
            )

        self.assertFalse(RegistrationChallenge.objects.exists())
        self.assertFalse(OTPVerification.objects.exists())
