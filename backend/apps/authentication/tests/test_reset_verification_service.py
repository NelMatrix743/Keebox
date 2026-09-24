from datetime import timedelta
from typing import Any, Self
from unittest.mock import Mock, patch
from uuid import uuid4

from django.test import TestCase
from django.utils import timezone

from apps.authentication.exceptions import (
    ExpiredOTPError,
    InvalidOTPError,
    InvalidResetChallengeError,
    LockedOTPError,
)
from apps.authentication.models import OTPVerification, ResetChallenge, User
from apps.authentication.services.reset_services import ResetService, ResetStartResult
from apps.core.choices import OTPStatus, ResetStatus, ResetType
from apps.core.constants import (
    OTP_MAX_ATTEMPTS,
    OTP_RESEND_COOLDOWN,
    RESET_CHALLENGE_COMPLETION_TTL,
)



class ResetVerificationServiceTests(TestCase):
    def setUp(self: Self) -> None:
        """
        Create an account and isolate OTP generation and email delivery.

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
        email_patcher: Any = patch(
            "apps.authentication.services.reset_services.EmailDeliveryService",
        )
        code_patcher: Any = patch(
            "apps.authentication.services.reset_services.generate_otp_code",
            return_value="048291",
        )
        self.email_delivery_service: Mock = email_patcher.start()
        self.generate_otp: Mock = code_patcher.start()
        self.addCleanup(email_patcher.stop)
        self.addCleanup(code_patcher.stop)

    def test_valid_otp_opens_the_ten_minute_completion_window(self: Self) -> None:
        """
        Verify a correct OTP is consumed and enables credential completion.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when successful verification persists bad state.
        """
        started: ResetStartResult = ResetService.start_reset(
            self.user.email,
            ResetType.PASSWORD,
        )

        verified: ResetChallenge = ResetService.verify_reset_otp(
            started.reset_id,
            "048291",
        )
        otp: OTPVerification = OTPVerification.objects.get(
            reset_challenge=verified,
        )
        self.user.refresh_from_db()

        self.assertEqual(verified.id, started.reset_id)
        self.assertEqual(verified.status, ResetStatus.OTP_VERIFIED)
        self.assertIsNotNone(verified.verified_at)
        self.assertEqual(
            verified.completion_expires_at,
            verified.verified_at + RESET_CHALLENGE_COMPLETION_TTL,
        )
        self.assertEqual(otp.status, OTPStatus.CONSUMED)
        self.assertEqual(otp.consumed_at, verified.verified_at)
        self.assertEqual(otp.attempt_count, 0)
        self.assertEqual(self.user.token_version, 0)
        self.assertTrue(self.user.check_password("correct horse battery staple"))

    def test_wrong_otp_records_an_attempt_without_advancing_the_reset(
        self: Self,
    ) -> None:
        """
        Verify an incorrect code leaves the reset pending until its limit.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an incorrect code advances the reset.
        """
        started: ResetStartResult = ResetService.start_reset(
            self.user.email,
            ResetType.PIN,
        )

        with self.assertRaises(InvalidOTPError):
            ResetService.verify_reset_otp(started.reset_id, "999999")

        challenge: ResetChallenge = ResetChallenge.objects.get(pk=started.reset_id)
        otp: OTPVerification = OTPVerification.objects.get(
            reset_challenge=challenge,
        )
        self.assertEqual(challenge.status, ResetStatus.OTP_PENDING)
        self.assertIsNone(challenge.verified_at)
        self.assertIsNone(challenge.completion_expires_at)
        self.assertEqual(otp.status, OTPStatus.PENDING)
        self.assertEqual(otp.attempt_count, 1)

    def test_fifth_wrong_otp_locks_the_code_and_cancels_the_reset(self: Self) -> None:
        """
        Verify the OTP attempt limit ends the reset without issuing a new code.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when attempts exceed the limit or continue.
        """
        started: ResetStartResult = ResetService.start_reset(
            self.user.email,
            ResetType.PASSWORD,
        )

        for _ in range(OTP_MAX_ATTEMPTS - 1):
            with self.assertRaises(InvalidOTPError):
                ResetService.verify_reset_otp(started.reset_id, "999999")
        with self.assertRaises(LockedOTPError):
            ResetService.verify_reset_otp(started.reset_id, "999999")

        challenge: ResetChallenge = ResetChallenge.objects.get(pk=started.reset_id)
        otp: OTPVerification = OTPVerification.objects.get(
            reset_challenge=challenge,
        )
        self.assertEqual(challenge.status, ResetStatus.CANCELLED)
        self.assertEqual(otp.status, OTPStatus.LOCKED)
        self.assertEqual(otp.attempt_count, OTP_MAX_ATTEMPTS)
        with self.assertRaises(InvalidResetChallengeError):
            ResetService.verify_reset_otp(started.reset_id, "048291")

    def test_expired_otp_cancels_the_reset(self: Self) -> None:
        """
        Verify an expired OTP ends the challenge before code comparison.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an expired challenge remains active.
        """
        started: ResetStartResult = ResetService.start_reset(
            self.user.email,
            ResetType.PASSWORD,
        )
        otp: OTPVerification = OTPVerification.objects.get(
            reset_challenge_id=started.reset_id,
        )
        otp.expires_at = timezone.now() - timedelta(seconds=1)
        otp.save(update_fields=["expires_at"])

        with self.assertRaises(ExpiredOTPError):
            ResetService.verify_reset_otp(started.reset_id, "048291")

        otp.refresh_from_db()
        self.assertEqual(otp.status, OTPStatus.EXPIRED)
        self.assertEqual(
            ResetChallenge.objects.get(pk=started.reset_id).status,
            ResetStatus.CANCELLED,
        )

    def test_only_the_latest_resend_code_can_verify_the_reset(self: Self) -> None:
        """
        Verify a replaced OTP cannot complete a reset after resending.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the superseded code remains usable.
        """
        self.generate_otp.side_effect = ["048291", "193847"]
        started: ResetStartResult = ResetService.start_reset(
            self.user.email,
            ResetType.PIN,
        )
        old_otp: OTPVerification = OTPVerification.objects.get(
            reset_challenge_id=started.reset_id,
        )
        old_otp.last_sent_at = (
            timezone.now() - OTP_RESEND_COOLDOWN - timedelta(seconds=1)
        )
        old_otp.save(update_fields=["last_sent_at"])
        ResetService.resend_reset_otp(started.reset_id)

        with self.assertRaises(InvalidOTPError):
            ResetService.verify_reset_otp(started.reset_id, "048291")
        verified: ResetChallenge = ResetService.verify_reset_otp(
            started.reset_id,
            "193847",
        )

        old_otp.refresh_from_db()
        self.assertEqual(old_otp.status, OTPStatus.EXPIRED)
        self.assertEqual(verified.status, ResetStatus.OTP_VERIFIED)
        self.assertEqual(
            OTPVerification.objects.get(
                reset_challenge=verified,
                status=OTPStatus.CONSUMED,
            ).attempt_count,
            1,
        )

    def test_missing_replaced_or_verified_challenge_cannot_verify_again(
        self: Self,
    ) -> None:
        """
        Verify only an active OTP-pending reset accepts verification.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an invalid reset challenge is accepted.
        """
        with self.assertRaises(InvalidResetChallengeError):
            ResetService.verify_reset_otp(uuid4(), "048291")

        first: ResetStartResult = ResetService.start_reset(
            self.user.email,
            ResetType.PASSWORD,
        )
        second: ResetStartResult = ResetService.start_reset(
            self.user.email,
            ResetType.PASSWORD,
        )
        with self.assertRaises(InvalidResetChallengeError):
            ResetService.verify_reset_otp(first.reset_id, "048291")

        ResetService.verify_reset_otp(second.reset_id, "048291")
        with self.assertRaises(InvalidResetChallengeError):
            ResetService.verify_reset_otp(second.reset_id, "048291")
