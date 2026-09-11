from datetime import timedelta
from typing import Self
from unittest.mock import patch
from uuid import uuid4

from django.test import TestCase
from django.utils import timezone

from apps.authentication.exceptions import InvalidRegistrationStateError
from apps.authentication.models import OTPVerification, RegistrationChallenge
from apps.authentication.registration_services import RegistrationService
from apps.core.choices import OTPStatus, RegistrationStatus



class OTPIssuanceServiceTests(TestCase):
    def _create_registration_challenge(self: Self) -> RegistrationChallenge:
        """
        Create a persisted pending registration for OTP issuance tests.

        Args:
            self: Current test case instance.

        Returns:
            A persisted pending registration challenge.

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

    def test_issue_registration_otp_hashes_and_returns_the_raw_code(
        self: Self,
    ) -> None:
        """
        Verify initial OTP issuance persists only the protected code.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when OTP issuance stores incorrect data.
        """
        challenge: RegistrationChallenge = self._create_registration_challenge()

        with patch(
            "apps.authentication.registration_services.generate_otp_code",
            return_value="012345",
        ):
            otp_verification, raw_code = RegistrationService.issue_registration_otp(
                challenge.id,
            )

        self.assertEqual(raw_code, "012345")
        self.assertNotEqual(otp_verification.code_hash, raw_code)
        self.assertTrue(otp_verification.verify_otp_code(raw_code))
        self.assertEqual(otp_verification.registration_challenge, challenge)
        self.assertEqual(otp_verification.email, challenge.email)
        self.assertEqual(otp_verification.status, OTPStatus.PENDING)
        self.assertEqual(OTPVerification.objects.count(), 1)

    def test_issue_registration_otp_expires_older_pending_records(
        self: Self,
    ) -> None:
        """
        Verify issuance preserves history while invalidating older pending OTPs.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an older pending OTP remains active.
        """
        challenge: RegistrationChallenge = self._create_registration_challenge()
        previous_otp: OTPVerification = OTPVerification(
            registration_challenge=challenge,
            email=challenge.email,
        )
        previous_otp.hash_and_set_otp_code("111111")
        previous_otp.save()

        with patch(
            "apps.authentication.registration_services.generate_otp_code",
            return_value="222222",
        ):
            current_otp, raw_code = RegistrationService.issue_registration_otp(
                challenge.id,
            )

        previous_otp.refresh_from_db()
        self.assertEqual(previous_otp.status, OTPStatus.EXPIRED)
        self.assertEqual(current_otp.status, OTPStatus.PENDING)
        self.assertEqual(raw_code, "222222")
        self.assertEqual(challenge.otp_verifications.count(), 2)

    def test_issue_registration_otp_rejects_an_invalid_registration_state(
        self: Self,
    ) -> None:
        """
        Verify OTP issuance requires a pending registration challenge.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an invalid registration state is accepted.
        """
        challenge: RegistrationChallenge = self._create_registration_challenge()
        challenge.status = RegistrationStatus.OTP_VERIFIED
        challenge.save(update_fields=["status", "updated_at"])

        with self.assertRaises(InvalidRegistrationStateError):
            RegistrationService.issue_registration_otp(challenge.id)

        self.assertFalse(OTPVerification.objects.exists())

    def test_issue_registration_otp_rejects_expired_or_missing_registration(
        self: Self,
    ) -> None:
        """
        Verify OTP issuance rejects expired and unknown registrations.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when unusable registration ownership is accepted.
        """
        challenge: RegistrationChallenge = self._create_registration_challenge()
        challenge.expires_at = timezone.now() - timedelta(microseconds=1)
        challenge.save(update_fields=["expires_at", "updated_at"])

        with self.assertRaises(InvalidRegistrationStateError):
            RegistrationService.issue_registration_otp(challenge.id)

        with self.assertRaises(InvalidRegistrationStateError):
            RegistrationService.issue_registration_otp(uuid4())

    def test_issue_registration_otp_rolls_back_previous_invalidation(
        self: Self,
    ) -> None:
        """
        Verify failed OTP creation restores the previously pending OTP.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when issuance changes are not atomic.
        """
        challenge: RegistrationChallenge = self._create_registration_challenge()
        previous_otp: OTPVerification = OTPVerification(
            registration_challenge=challenge,
            email=challenge.email,
        )
        previous_otp.hash_and_set_otp_code("111111")
        previous_otp.save()

        with (
            patch(
                "apps.authentication.registration_services.generate_otp_code",
                return_value="222222",
            ),
            patch.object(
                OTPVerification,
                "save",
                side_effect=RuntimeError("simulated persistence failure"),
            ),
            self.assertRaises(RuntimeError),
        ):
            RegistrationService.issue_registration_otp(challenge.id)

        previous_otp.refresh_from_db()
        self.assertEqual(previous_otp.status, OTPStatus.PENDING)
        self.assertEqual(challenge.otp_verifications.count(), 1)
