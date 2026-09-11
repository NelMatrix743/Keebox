from datetime import datetime, timedelta
from typing import Self
from unittest.mock import patch
from uuid import UUID

from django.contrib.auth.hashers import identify_hasher
from django.core.exceptions import FieldDoesNotExist
from django.db import IntegrityError, transaction
from django.test import TestCase
from django.utils import timezone

from apps.authentication.models import OTPVerification, RegistrationChallenge
from apps.core.choices import OTPStatus
from apps.core.constants import OTP_MAX_ATTEMPTS, OTP_MAX_RESENDS



class OTPVerificationModelTests(TestCase):
    def _create_registration_challenge(self: Self) -> RegistrationChallenge:
        """
        Create a persisted registration challenge for OTP model tests.

        Args:
            self: Current test case instance.

        Returns:
            A persisted registration challenge with protected credentials.

        Raises:
            ValueError: Raised when the test credentials are invalid.
        """
        challenge: RegistrationChallenge = RegistrationChallenge(
            first_name="Nelson",
            last_name="Ubochiegbu",
            email="nelmatrix155@gmail.com",
        )
        challenge.set_password("correct horse battery staple")
        challenge.save()
        return challenge

    def test_otp_verification_hashes_and_checks_codes(self: Self) -> None:
        """
        Verify OTP codes are hashed and can be checked without raw persistence.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when OTP code protection behaves incorrectly.
        """
        otp_verification: OTPVerification = OTPVerification(
            email="nelmatrix155@gmail.com",
        )

        otp_verification.hash_and_set_otp_code("123456")

        self.assertNotEqual(otp_verification.code_hash, "123456")
        identify_hasher(otp_verification.code_hash)
        self.assertTrue(otp_verification.verify_otp_code("123456"))
        self.assertFalse(otp_verification.verify_otp_code("654321"))

        with self.assertRaisesMessage(ValueError, "OTP code is required"):
            otp_verification.hash_and_set_otp_code("")

    def test_otp_verification_reports_expiration_and_consumption(
        self: Self,
    ) -> None:
        """
        Verify OTP expiration and consumption state checks.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when OTP state is evaluated incorrectly.
        """
        current_time: datetime = timezone.now()
        otp_verification: OTPVerification = OTPVerification(
            email="nelmatrix155@gmail.com",
            expires_at=current_time,
        )

        with patch(
            "apps.authentication.models.timezone.now",
            return_value=current_time,
        ):
            self.assertTrue(otp_verification.is_expired())

            otp_verification.expires_at = current_time + timedelta(microseconds=1)
            self.assertFalse(otp_verification.is_expired())

        self.assertFalse(otp_verification.is_consumed())
        otp_verification.status = OTPStatus.CONSUMED
        self.assertTrue(otp_verification.is_consumed())

        otp_verification.status = OTPStatus.PENDING
        otp_verification.consumed_at = current_time
        self.assertTrue(otp_verification.is_consumed())

    def test_otp_verification_allows_only_active_attempts(self: Self) -> None:
        """
        Verify attempts require pending, unexpired, below-limit OTP state.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an unusable OTP permits verification.
        """
        current_time: datetime = timezone.now()
        otp_verification: OTPVerification = OTPVerification(
            email="nelmatrix155@gmail.com",
            expires_at=current_time + timedelta(minutes=1),
        )

        with patch(
            "apps.authentication.models.timezone.now",
            return_value=current_time,
        ):
            self.assertTrue(otp_verification.can_attempt_verification())

            otp_verification.attempt_count = OTP_MAX_ATTEMPTS
            self.assertFalse(otp_verification.can_attempt_verification())

            otp_verification.attempt_count = 0
            otp_verification.status = OTPStatus.CONSUMED
            self.assertFalse(otp_verification.can_attempt_verification())

            otp_verification.status = OTPStatus.PENDING
            otp_verification.expires_at = current_time
            self.assertFalse(otp_verification.can_attempt_verification())

    def test_otp_verification_rejects_attempt_count_above_limit(
        self: Self,
    ) -> None:
        """
        Verify the database rejects OTP attempt counts above the limit.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an excessive attempt count is accepted.
        """
        challenge: RegistrationChallenge = self._create_registration_challenge()

        with self.assertRaises(IntegrityError), transaction.atomic():
            OTPVerification.objects.create(
                registration_challenge=challenge,
                email=challenge.email,
                code_hash="encoded-code-hash",
                attempt_count=OTP_MAX_ATTEMPTS + 1,
            )

    def test_registration_challenge_rejects_resend_count_above_limit(
        self: Self,
    ) -> None:
        """
        Verify the database rejects registration resend counts above the limit.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an excessive resend count is accepted.
        """
        challenge: RegistrationChallenge = self._create_registration_challenge()

        with self.assertRaises(IntegrityError), transaction.atomic():
            challenge.resend_count = OTP_MAX_RESENDS + 1
            challenge.save(update_fields=["resend_count"])

    def test_otp_verification_does_not_own_registration_resend_count(
        self: Self,
    ) -> None:
        """
        Verify individual OTP records do not track registration resends.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the OTP model owns a resend counter.
        """
        with self.assertRaises(FieldDoesNotExist):
            OTPVerification._meta.get_field("resend_count")

    def test_otp_verification_requires_consumed_state_consistency(
        self: Self,
    ) -> None:
        """
        Verify consumed status and timestamp must always agree.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an inconsistent consumed state is accepted.
        """
        challenge: RegistrationChallenge = self._create_registration_challenge()

        with self.assertRaises(IntegrityError), transaction.atomic():
            OTPVerification.objects.create(
                registration_challenge=challenge,
                email=challenge.email,
                code_hash="encoded-code-hash",
                status=OTPStatus.CONSUMED,
            )

        with self.assertRaises(IntegrityError), transaction.atomic():
            OTPVerification.objects.create(
                registration_challenge=challenge,
                email=challenge.email,
                code_hash="encoded-code-hash",
                consumed_at=timezone.now(),
            )

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
