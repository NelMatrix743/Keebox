import logging
from dataclasses import dataclass
from datetime import datetime
from uuid import UUID, uuid4

from django.db import transaction
from django.utils import timezone

from apps.authentication.exceptions import (
    ExpiredOTPError,
    InvalidResetChallengeError,
    LockedOTPError,
    OTPResendCooldownError,
    OTPResendLimitError,
    OTPServiceError,
)
from apps.authentication.models import OTPVerification, ResetChallenge, User
from apps.authentication.otp import generate_otp_code
from apps.core.choices import OTPStatus, ResetStatus, ResetType
from apps.core.constants import OTP_MAX_RESENDS, OTP_RESEND_COOLDOWN, OTP_TTL
from apps.core.email import EmailDeliveryService
from apps.core.exceptions import EmailDeliveryError



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
    def _cancel_challenge(challenge: ResetChallenge) -> None:
        """
        Cancel one reset challenge and invalidate all its pending OTPs.

        Args:
            challenge: Reset challenge that must no longer continue.

        Returns:
            None: The challenge and pending OTP state are persisted.

        Raises:
            None.
        """
        current_time: datetime = timezone.now()
        OTPVerification.objects.filter(
            reset_challenge=challenge,
            status=OTPStatus.PENDING,
        ).update(status=OTPStatus.EXPIRED, updated_at=current_time)
        challenge.status = ResetStatus.CANCELLED
        challenge.save(update_fields=["status", "updated_at"])

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
        otp_verification: OTPVerification
        raw_code: str
        otp_verification, raw_code = ResetService._create_otp(challenge)
        return challenge, otp_verification, raw_code

    @staticmethod
    def _create_otp(challenge: ResetChallenge) -> tuple[OTPVerification, str]:
        """
        Create a protected OTP record for an existing reset challenge.

        Args:
            challenge: Reset challenge receiving the new verification code.

        Returns:
            Persisted OTP verification and its raw code for email delivery.

        Raises:
            ValueError: Raised if OTP generation produces an empty code.
        """
        raw_code: str = generate_otp_code()
        otp_verification: OTPVerification = OTPVerification(
            reset_challenge=challenge,
            email=challenge.user.email,
        )
        otp_verification.hash_and_set_otp_code(raw_code)
        otp_verification.save()
        return otp_verification, raw_code

    @staticmethod
    def _get_locked_pending_challenge(reset_id: UUID) -> ResetChallenge:
        """
        Lock an account before loading its pending reset challenge.

        Args:
            reset_id: Identifier of the reset challenge to resend.

        Returns:
            Locked reset challenge in the OTP-pending state.

        Raises:
            InvalidResetChallengeError: Raised when the challenge or user is
                missing or the challenge cannot resend an OTP.
        """
        try:
            challenge_owner_id: UUID = ResetChallenge.objects.values_list(
                "user_id",
                flat=True,
            ).get(pk=reset_id)
            User.objects.select_for_update().get(pk=challenge_owner_id)
            challenge: ResetChallenge = (
                ResetChallenge.objects.select_for_update()
                .select_related("user")
                .get(pk=reset_id)
            )
        except (ResetChallenge.DoesNotExist, User.DoesNotExist) as exception:
            raise InvalidResetChallengeError(
                "The reset challenge is unavailable.",
            ) from exception

        if challenge.status != ResetStatus.OTP_PENDING:
            raise InvalidResetChallengeError(
                "The reset challenge cannot resend an OTP.",
            )
        return challenge

    @staticmethod
    def _get_locked_current_otp(challenge: ResetChallenge) -> OTPVerification:
        """
        Retrieve the newest OTP issued for a pending reset challenge.

        Args:
            challenge: Reset challenge whose OTP must be inspected.

        Returns:
            Locked most recently issued OTP verification.

        Raises:
            InvalidResetChallengeError: Raised when the challenge has no OTP.
        """
        current_otp: OTPVerification | None = (
            OTPVerification.objects.select_for_update()
            .filter(reset_challenge=challenge)
            .order_by("-created_at", "-id")
            .first()
        )
        if current_otp is None:
            raise InvalidResetChallengeError(
                "The reset challenge has no OTP to resend.",
            )
        return current_otp

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

    @staticmethod
    def start_reset(email: str, reset_type: ResetType) -> ResetStartResult:
        """
        Start credential recovery without disclosing whether the email exists.

        Args:
            email: Submitted account email address.
            reset_type: Password or lock-PIN recovery purpose.

        Returns:
            Public reset identifier and timing, including for unknown emails.

        Raises:
            ValueError: Raised when the email or reset type is invalid.
        """
        normalized_email: str = User.objects.normalize_email(email.strip()).casefold()
        if not normalized_email or reset_type not in ResetType.values:
            raise ValueError("The reset request is invalid.")

        current_time: datetime = timezone.now()
        decoy_result: ResetStartResult = ResetStartResult(
            reset_id=uuid4(),
            otp_expires_at=current_time + OTP_TTL,
            resend_available_at=current_time + OTP_RESEND_COOLDOWN,
        )

        with transaction.atomic():
            try:
                user: User = User.objects.select_for_update().get(
                    email=normalized_email,
                )
            except User.DoesNotExist:
                return decoy_result

            ResetService._cancel_existing_challenges(user, reset_type)
            challenge: ResetChallenge
            otp_verification: OTPVerification
            raw_code: str
            challenge, otp_verification, raw_code = (
                ResetService._create_challenge_and_otp(user, reset_type)
            )

        ResetService._deliver_otp(user, reset_type, raw_code)
        return ResetStartResult(
            reset_id=challenge.id,
            otp_expires_at=otp_verification.expires_at,
            resend_available_at=otp_verification.last_sent_at + OTP_RESEND_COOLDOWN,
        )

    @staticmethod
    def resend_reset_otp(reset_id: UUID) -> ResetStartResult:
        """
        Replace the current OTP while keeping its reset challenge identifier.

        Args:
            reset_id: Identifier of the pending credential reset challenge.

        Returns:
            The unchanged reset identifier and replacement OTP timing.

        Raises:
            InvalidResetChallengeError: Raised when the challenge or its OTP
                is unavailable for resending.
            ExpiredOTPError: Raised after cancelling a reset with an expired OTP.
            LockedOTPError: Raised after cancelling a reset with a locked OTP.
            OTPResendLimitError: Raised after cancelling a reset that exhausted
                its resend allowance.
            OTPResendCooldownError: Raised while the resend cooldown is active.
            ValueError: Raised if OTP generation produces an empty code.
        """
        pending_error: OTPServiceError | None = None
        replacement_otp: OTPVerification | None = None
        raw_code: str = ""

        with transaction.atomic():
            challenge: ResetChallenge = ResetService._get_locked_pending_challenge(
                reset_id,
            )
            current_otp: OTPVerification = ResetService._get_locked_current_otp(
                challenge,
            )

            if current_otp.status == OTPStatus.EXPIRED or current_otp.is_expired():
                ResetService._cancel_challenge(challenge)
                pending_error = ExpiredOTPError("The reset OTP has expired.")
            elif current_otp.status == OTPStatus.LOCKED:
                ResetService._cancel_challenge(challenge)
                pending_error = LockedOTPError("The reset OTP is locked.")
            elif current_otp.status != OTPStatus.PENDING:
                raise InvalidResetChallengeError(
                    "The reset OTP cannot be resent.",
                )
            elif challenge.resend_count >= OTP_MAX_RESENDS:
                ResetService._cancel_challenge(challenge)
                pending_error = OTPResendLimitError(
                    "The reset challenge reached its OTP resend limit.",
                )
            elif timezone.now() < current_otp.last_sent_at + OTP_RESEND_COOLDOWN:
                raise OTPResendCooldownError(
                    "The reset OTP resend cooldown has not elapsed.",
                )
            else:
                current_otp.status = OTPStatus.EXPIRED
                current_otp.save(update_fields=["status", "updated_at"])
                challenge.resend_count += 1
                challenge.save(update_fields=["resend_count", "updated_at"])
                replacement_otp, raw_code = ResetService._create_otp(challenge)

        if pending_error is not None:
            raise pending_error
        if replacement_otp is None:
            raise InvalidResetChallengeError(
                "The replacement reset OTP could not be created.",
            )

        ResetService._deliver_otp(challenge.user, ResetType(challenge.reset_type), raw_code)
        return ResetStartResult(
            reset_id=challenge.id,
            otp_expires_at=replacement_otp.expires_at,
            resend_available_at=replacement_otp.last_sent_at + OTP_RESEND_COOLDOWN,
        )
