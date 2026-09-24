from datetime import timedelta
from typing import Self
from unittest.mock import Mock, patch
from uuid import uuid4

from django.test import TestCase
from django.utils import timezone

from apps.authentication.exceptions import (
    InvalidResetChallengeError,
    ExpiredOTPError,
    LockedOTPError,
    OTPResendCooldownError,
    OTPResendLimitError,
)
from apps.authentication.models import OTPVerification, ResetChallenge, User
from apps.authentication.services.reset_services import ResetService, ResetStartResult
from apps.core.choices import OTPStatus, ResetStatus, ResetType
from apps.core.constants import OTP_MAX_RESENDS, OTP_RESEND_COOLDOWN



class ResetResendServiceTests(TestCase):
    def setUp(self: Self) -> None:
        """
        Create an account available for reset OTP resend tests.

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

    @patch("apps.authentication.services.reset_services.EmailDeliveryService")
    @patch(
        "apps.authentication.services.reset_services.generate_otp_code",
        side_effect=["048291", "193847"],
    )
    def test_resend_replaces_the_otp_without_changing_the_challenge_id(
        self: Self,
        generate_otp: Mock,
        email_delivery_service: Mock,
    ) -> None:
        """
        Verify a permitted resend creates and delivers one replacement OTP.

        Args:
            self: Current test case instance.
            generate_otp: Mocked secure OTP generator.
            email_delivery_service: Mocked external email boundary.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the old or new OTP state is incorrect.
        """
        started: ResetStartResult = ResetService.start_reset(
            self.user.email,
            ResetType.PASSWORD,
        )
        old_otp: OTPVerification = OTPVerification.objects.get(
            reset_challenge_id=started.reset_id,
        )
        old_otp.last_sent_at = timezone.now() - OTP_RESEND_COOLDOWN - timedelta(
            seconds=1,
        )
        old_otp.save(update_fields=["last_sent_at"])

        resent: ResetStartResult = ResetService.resend_reset_otp(started.reset_id)
        challenge: ResetChallenge = ResetChallenge.objects.get(pk=started.reset_id)
        new_otp: OTPVerification = (
            OTPVerification.objects.filter(reset_challenge=challenge)
            .exclude(pk=old_otp.pk)
            .get()
        )
        old_otp.refresh_from_db()

        self.assertEqual(resent.reset_id, started.reset_id)
        self.assertEqual(challenge.status, ResetStatus.OTP_PENDING)
        self.assertEqual(challenge.resend_count, 1)
        self.assertEqual(old_otp.status, OTPStatus.EXPIRED)
        self.assertEqual(new_otp.status, OTPStatus.PENDING)
        self.assertTrue(new_otp.verify_otp_code("193847"))
        self.assertEqual(resent.otp_expires_at, new_otp.expires_at)
        self.assertEqual(
            resent.resend_available_at,
            new_otp.last_sent_at + OTP_RESEND_COOLDOWN,
        )
        self.assertEqual(generate_otp.call_count, 2)
        self.assertEqual(
            email_delivery_service.return_value.send_otp_email.call_args.kwargs[
                "otp_code"
            ],
            "193847",
        )
        self.assertEqual(
            email_delivery_service.return_value.send_otp_email.call_count,
            2,
        )

    @patch("apps.authentication.services.reset_services.EmailDeliveryService")
    @patch(
        "apps.authentication.services.reset_services.generate_otp_code",
        return_value="048291",
    )
    def test_resend_before_cooldown_does_not_issue_or_deliver_another_otp(
        self: Self,
        generate_otp: Mock,
        email_delivery_service: Mock,
    ) -> None:
        """
        Verify the resend cooldown prevents a second OTP from being issued.

        Args:
            self: Current test case instance.
            generate_otp: Mocked secure OTP generator.
            email_delivery_service: Mocked external email boundary.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a premature resend changes state.
        """
        started: ResetStartResult = ResetService.start_reset(
            self.user.email,
            ResetType.PASSWORD,
        )

        with self.assertRaises(OTPResendCooldownError):
            ResetService.resend_reset_otp(started.reset_id)

        challenge: ResetChallenge = ResetChallenge.objects.get(pk=started.reset_id)
        self.assertEqual(challenge.resend_count, 0)
        self.assertEqual(OTPVerification.objects.count(), 1)
        generate_otp.assert_called_once_with()
        self.assertEqual(
            email_delivery_service.return_value.send_otp_email.call_count,
            1,
        )
