from datetime import datetime, timedelta
from typing import Self
from uuid import UUID

from django.contrib.auth.hashers import identify_hasher
from django.test import TestCase
from django.utils import timezone

from apps.authentication.models import RegistrationChallenge
from apps.core.choices import RegistrationStatus
from apps.core.constants import REGISTRATION_CHALLENGE_TTL



class RegistrationChallengeModelTests(TestCase):
    def test_registration_challenge_allows_repeated_email_attempts(
        self: Self,
    ) -> None:
        """
        Verify one email address can own multiple registration attempts.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when repeated registration attempts are rejected.
        """
        for attempt_number in range(2):
            challenge: RegistrationChallenge = RegistrationChallenge(
                first_name="Nelson",
                last_name="Ubochiegbu",
                email="Nelmatrix155@gmail.com",
            )
            challenge.set_password(f"valid-password-{attempt_number}")
            challenge.save()

        self.assertEqual(
            RegistrationChallenge.objects.filter(
                email="nelmatrix155@gmail.com",
            ).count(),
            2,
        )

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
        self.assertEqual(challenge.resend_count, 0)
        self.assertIsNone(challenge.completed_at)
        self.assertAlmostEqual(
            challenge.expires_at,
            creation_started + REGISTRATION_CHALLENGE_TTL,
            delta=timedelta(seconds=1),
        )

