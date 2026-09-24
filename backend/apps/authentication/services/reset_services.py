import logging
from dataclasses import dataclass
from datetime import datetime
from uuid import UUID, uuid4

from django.db import transaction
from django.utils import timezone

from apps.core.choices import OTPStatus, ResetStatus, ResetType
from apps.core.constants import OTP_RESEND_COOLDOWN, OTP_TTL
from apps.core.email import EmailDeliveryService
from apps.core.exceptions import EmailDeliveryError
from apps.authentication.models import OTPVerification, ResetChallenge, User
from apps.authentication.otp import generate_otp_code



logger: logging.Logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class ResetStartResult:
    """Carry the public identifier and OTP timing for a reset initiation."""

    reset_id: UUID
    otp_expires_at: datetime
    resend_available_at: datetime


class ResetService:
    """Manage password and lock-PIN recovery challenges."""

    @staticmethod
    def _cancel_existing_challenges(user: User, reset_type: ResetType) -> None:
        """
        Cancel active challenges of one type and invalidate their pending OTPs.

        Args:
            user: Account whose prior reset attempts must be replaced.
            reset_type: Credential type whose active challenges are cancelled.

        Returns:
            None: Matching challenges and pending OTPs are updated in storage.

        Raises:
            None.
        """
        active_challenge_ids: list[UUID] = list(
            ResetChallenge.objects.select_for_update()
            .filter(
                user=user,
                reset_type=reset_type,
                status__in=[
                    ResetStatus.OTP_PENDING,
                    ResetStatus.OTP_VERIFIED
                ],
            )
            .values_list("id", flat=True),
        )
        if not active_challenge_ids:
            return

        current_time: datetime = timezone.now()
        OTPVerification.objects.filter(
            reset_challenge_id__in=active_challenge_ids,
            status=OTPStatus.PENDING,
        ).update(status=OTPStatus.EXPIRED, updated_at=current_time)
        (ResetChallenge
        .objects
        .filter(pk__in=active_challenge_ids)
        .update(
            status=ResetStatus.CANCELLED,
            updated_at=current_time,
        ))

    @staticmethod
    def _create_challenge_and_otp(
        user: User,
        reset_type: ResetType,
    ) -> tuple[ResetChallenge, OTPVerification, str]:
        """
        Create a reset challenge and its protected initial OTP.

        Args:
            user: Account whose credential may be reset.
            reset_type: Credential type selected for recovery.

        Returns:
            Persisted challenge, OTP verification, and raw code for delivery.

        Raises:
            ValueError: Raised if OTP generation produces an empty code.
        """
        challenge: ResetChallenge = ResetChallenge.objects.create(
            user=user,
            reset_type=reset_type,
        )
        raw_code: str = generate_otp_code()
        otp_verification: OTPVerification = OTPVerification(
            reset_challenge=challenge,
            email=user.email,
        )
        otp_verification.hash_and_set_otp_code(raw_code)
        otp_verification.save()
        return challenge, otp_verification, raw_code

    @staticmethod
    def _deliver_otp(user: User, reset_type: ResetType, raw_code: str) -> None:
        """
        Submit the reset OTP email without revealing delivery failures publicly.

        Args:
            user: Account receiving the verification code.
            reset_type: Credential type being recovered.
            raw_code: Fresh OTP to include in the email template.

        Returns:
            None: Delivery is submitted or its failure is logged.

        Raises:
            None: Email delivery failures are intentionally logged and hidden.
        """
        try:
            EmailDeliveryService().send_otp_email(
                recipient_email=user.email,
                recipient_full_name=f"{user.first_name} {user.last_name}".strip(),
                otp_code=raw_code,
                expiration_minutes=int(OTP_TTL.total_seconds() // 60),
                tag=f"{reset_type.value}-reset-otp",
            )
        except EmailDeliveryError:
            logger.exception("Could not deliver a Keebox reset OTP email.")
