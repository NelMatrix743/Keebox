from datetime import timedelta
from typing import Self
from unittest.mock import Mock, patch

from django.test import TestCase

from apps.authentication.models import OTPVerification, ResetChallenge, User
from apps.authentication.services.reset_services import ResetService, ResetStartResult
from apps.core.choices import OTPStatus, ResetStatus, ResetType
from apps.core.constants import OTP_RESEND_COOLDOWN, OTP_TTL
from apps.core.exceptions import EmailDeliveryError



class ResetStartServiceTests(TestCase):
    def setUp(self: Self) -> None:
        """
        Create the account used for password and PIN reset initiation tests.

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
        return_value="048291",
    )
    def test_known_email_creates_and_delivers_a_protected_reset_otp(
        self: Self,
        generate_otp: Mock,
        email_delivery_service: Mock,
    ) -> None:
        """
        Verify a password reset stores a hashed OTP and emails the account.

        Args:
            self: Current test case instance.
            generate_otp: Mocked secure OTP generator.
            email_delivery_service: Mocked external email delivery boundary.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the challenge or delivery is incorrect.
        """
        started: ResetStartResult = ResetService.start_reset(
            email="  ADA@example.com  ",
            reset_type=ResetType.PASSWORD,
        )
        challenge: ResetChallenge = ResetChallenge.objects.get(pk=started.reset_id)
        otp: OTPVerification = OTPVerification.objects.get(
            reset_challenge=challenge,
        )

        self.assertEqual(challenge.user_id, self.user.id)
        self.assertEqual(challenge.reset_type, ResetType.PASSWORD)
        self.assertEqual(challenge.status, ResetStatus.OTP_PENDING)
        self.assertEqual(otp.status, OTPStatus.PENDING)
        self.assertNotEqual(otp.code_hash, "048291")
        self.assertTrue(otp.verify_otp_code("048291"))
        self.assertEqual(started.otp_expires_at, otp.expires_at)
        self.assertEqual(
            started.resend_available_at,
            otp.last_sent_at + OTP_RESEND_COOLDOWN,
        )
        self.assertLess(
            abs((otp.expires_at - otp.last_sent_at) - OTP_TTL),
            timedelta(seconds=1),
        )
        generate_otp.assert_called_once_with()
        email_delivery_service.return_value.send_otp_email.assert_called_once_with(
            recipient_email="ada@example.com",
            recipient_full_name="Ada Lovelace",
            otp_code="048291",
            expiration_minutes=5,
            tag="password-reset-otp",
        )

    @patch("apps.authentication.services.reset_services.EmailDeliveryService")
    def test_unknown_email_gets_a_decoy_identifier_without_email(
        self: Self,
        email_delivery_service: Mock,
    ) -> None:
        """
        Verify an unknown email receives the same result shape without storage.

        Args:
            self: Current test case instance.
            email_delivery_service: Mocked external email delivery boundary.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an unknown address reveals account state.
        """
        started = ResetService.start_reset(
            email="missing@example.com",
            reset_type=ResetType.PASSWORD,
        )

        self.assertIsNotNone(started.reset_id)
        self.assertIsNotNone(started.otp_expires_at)
        self.assertIsNotNone(started.resend_available_at)
        self.assertFalse(ResetChallenge.objects.filter(pk=started.reset_id).exists())
        self.assertEqual(ResetChallenge.objects.count(), 0)
        self.assertEqual(OTPVerification.objects.count(), 0)
        email_delivery_service.assert_not_called()

    @patch("apps.authentication.services.reset_services.EmailDeliveryService")
    @patch(
        "apps.authentication.services.reset_services.generate_otp_code",
        return_value="048291",
    )
    def test_new_reset_cancels_the_prior_same_type_and_its_pending_otp(
        self: Self,
        generate_otp: Mock,
        email_delivery_service: Mock,
    ) -> None:
        """
        Verify a replacement challenge invalidates the older password flow.

        Args:
            self: Current test case instance.
            generate_otp: Mocked secure OTP generator.
            email_delivery_service: Mocked external email delivery boundary.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when old challenge state remains active.
        """
        first = ResetService.start_reset(
            email=self.user.email,
            reset_type=ResetType.PASSWORD,
        )
        old_challenge: ResetChallenge = ResetChallenge.objects.get(pk=first.reset_id)
        old_otp: OTPVerification = OTPVerification.objects.get(
            reset_challenge=old_challenge,
        )

        second = ResetService.start_reset(
            email=self.user.email,
            reset_type=ResetType.PASSWORD,
        )
        old_challenge.refresh_from_db()
        old_otp.refresh_from_db()

        self.assertNotEqual(first.reset_id, second.reset_id)
        self.assertEqual(old_challenge.status, ResetStatus.CANCELLED)
        self.assertEqual(old_otp.status, OTPStatus.EXPIRED)
        self.assertEqual(
            ResetChallenge.objects.get(pk=second.reset_id).status,
            ResetStatus.OTP_PENDING,
        )
        self.assertEqual(email_delivery_service.return_value.send_otp_email.call_count, 2)

    @patch("apps.authentication.services.reset_services.EmailDeliveryService")
    @patch(
        "apps.authentication.services.reset_services.generate_otp_code",
        return_value="048291",
    )
    def test_password_and_pin_resets_can_coexist(
        self: Self,
        generate_otp: Mock,
        email_delivery_service: Mock,
    ) -> None:
        """
        Verify starting a PIN reset does not cancel a password reset.

        Args:
            self: Current test case instance.
            generate_otp: Mocked secure OTP generator.
            email_delivery_service: Mocked external email delivery boundary.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when independent reset types interfere.
        """
        password_reset = ResetService.start_reset(
            email=self.user.email,
            reset_type=ResetType.PASSWORD,
        )
        pin_reset = ResetService.start_reset(
            email=self.user.email,
            reset_type=ResetType.PIN,
        )

        self.assertEqual(
            ResetChallenge.objects.get(pk=password_reset.reset_id).status,
            ResetStatus.OTP_PENDING,
        )
        self.assertEqual(
            ResetChallenge.objects.get(pk=pin_reset.reset_id).status,
            ResetStatus.OTP_PENDING,
        )
        self.assertNotEqual(password_reset.reset_id, pin_reset.reset_id)
        self.assertEqual(
            email_delivery_service.return_value.send_otp_email.call_args.kwargs[
                "tag"
            ],
            "pin-reset-otp",
        )
