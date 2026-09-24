import logging
from dataclasses import dataclass
from datetime import datetime
from uuid import UUID, uuid4

from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import transaction
from django.utils import timezone

from apps.authentication.exceptions import (
    ConsumedOTPError,
    ExpiredResetChallengeError,
    ExpiredOTPError,
    InvalidOTPError,
    InvalidResetChallengeError,
    LockedOTPError,
    OTPResendCooldownError,
    OTPResendLimitError,
    OTPServiceError,
)
from apps.authentication.models import OTPVerification, ResetChallenge, User
from apps.authentication.otp import generate_otp_code
from apps.core.choices import OTPStatus, ResetStatus, ResetType
from apps.core.constants import (
    OTP_MAX_ATTEMPTS,
    OTP_MAX_RESENDS,
    OTP_RESEND_COOLDOWN,
    OTP_TTL,
    RESET_CHALLENGE_COMPLETION_TTL,
)
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
    def _get_locked_challenge(reset_id: UUID) -> ResetChallenge:
        """
        Lock an account before loading its reset challenge.

        Args:
            reset_id: Identifier of the reset challenge to load.

        Returns:
            Locked reset challenge and its associated account.

        Raises:
            InvalidResetChallengeError: Raised when the challenge or user is missing.
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

        return challenge

    @staticmethod
    def _get_locked_pending_challenge(reset_id: UUID) -> ResetChallenge:
        """
        Require an account reset that is still awaiting OTP verification.

        Args:
            reset_id: Identifier of the reset challenge to inspect.

        Returns:
            Locked reset challenge in the OTP-pending state.

        Raises:
            InvalidResetChallengeError: Raised when the challenge cannot
                accept another OTP operation.
        """
        challenge: ResetChallenge = ResetService._get_locked_challenge(reset_id)
        if challenge.status != ResetStatus.OTP_PENDING:
            raise InvalidResetChallengeError(
                "The reset challenge is not awaiting OTP verification.",
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
                "The reset challenge has no OTP to inspect.",
            )
        return current_otp

    @staticmethod
    def _get_terminal_otp_error(
        challenge: ResetChallenge,
        current_otp: OTPVerification,
    ) -> OTPServiceError | None:
        """
        Cancel a reset whose current OTP is already unusable.

        Args:
            challenge: Reset challenge owning the current OTP.
            current_otp: Most recently issued OTP verification.

        Returns:
            Deferred expiry or lock error, or None when verification may proceed.

        Raises:
            ConsumedOTPError: Raised when the OTP has already been used.
        """
        if current_otp.is_consumed():
            raise ConsumedOTPError("The reset OTP has already been consumed.")

        if current_otp.status == OTPStatus.EXPIRED or current_otp.is_expired():
            ResetService._cancel_challenge(challenge)
            return ExpiredOTPError("The reset OTP has expired.")

        if (
            current_otp.status == OTPStatus.LOCKED
            or current_otp.attempt_count >= OTP_MAX_ATTEMPTS
        ):
            if current_otp.status != OTPStatus.LOCKED:
                current_otp.status = OTPStatus.LOCKED
                current_otp.save(update_fields=["status", "updated_at"])
            ResetService._cancel_challenge(challenge)
            return LockedOTPError("The reset OTP is locked.")

        return None

    @staticmethod
    def _record_failed_otp_attempt(
        challenge: ResetChallenge,
        current_otp: OTPVerification,
    ) -> OTPServiceError:
        """
        Count a wrong code and cancel the reset when attempts are exhausted.

        Args:
            challenge: Reset challenge receiving the failed verification.
            current_otp: OTP verification whose attempt count is increased.

        Returns:
            Deferred invalid-code or locked-OTP error for the caller.

        Raises:
            None.
        """
        current_otp.attempt_count += 1
        if current_otp.attempt_count >= OTP_MAX_ATTEMPTS:
            current_otp.status = OTPStatus.LOCKED
            pending_error: OTPServiceError = LockedOTPError(
                "The reset OTP is locked.",
            )
        else:
            pending_error = InvalidOTPError("The reset OTP code is invalid.")

        current_otp.save(update_fields=["attempt_count", "status", "updated_at"])
        if current_otp.status == OTPStatus.LOCKED:
            ResetService._cancel_challenge(challenge)
        return pending_error

    @staticmethod
    def _consume_otp(
        challenge: ResetChallenge,
        current_otp: OTPVerification,
    ) -> None:
        """
        Consume a valid OTP and open the reset completion window.

        Args:
            challenge: Pending reset challenge advanced by verification.
            current_otp: OTP verification matched by the submitted code.

        Returns:
            None: Both successful state transitions are persisted.

        Raises:
            None.
        """
        verified_at: datetime = timezone.now()
        current_otp.status = OTPStatus.CONSUMED
        current_otp.consumed_at = verified_at
        current_otp.save(update_fields=["status", "consumed_at", "updated_at"])
        challenge.status = ResetStatus.OTP_VERIFIED
        challenge.verified_at = verified_at
        challenge.completion_expires_at = (
            verified_at + RESET_CHALLENGE_COMPLETION_TTL
        )
        challenge.save(
            update_fields=[
                "status",
                "verified_at",
                "completion_expires_at",
                "updated_at",
            ],
        )

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

    @staticmethod
    def verify_reset_otp(reset_id: UUID, raw_code: str) -> ResetChallenge:
        """
        Verify the newest reset OTP and start the completion deadline.

        Args:
            reset_id: Identifier of the pending credential reset challenge.
            raw_code: Six-digit OTP submitted from the reset email.

        Returns:
            The reset challenge advanced to the OTP-verified state.

        Raises:
            InvalidResetChallengeError: Raised when the reset or OTP is absent
                or the challenge is not awaiting OTP verification.
            ConsumedOTPError: Raised when the current OTP was already used.
            ExpiredOTPError: Raised after cancelling an expired OTP challenge.
            LockedOTPError: Raised after cancelling a locked OTP challenge.
            InvalidOTPError: Raised when the submitted OTP code is incorrect.
        """
        pending_error: OTPServiceError | None = None
        verified_challenge: ResetChallenge | None = None

        with transaction.atomic():
            challenge: ResetChallenge = ResetService._get_locked_pending_challenge(
                reset_id,
            )
            current_otp: OTPVerification = ResetService._get_locked_current_otp(
                challenge,
            )
            pending_error = ResetService._get_terminal_otp_error(
                challenge,
                current_otp,
            )

            if pending_error is None and not current_otp.verify_otp_code(raw_code):
                pending_error = ResetService._record_failed_otp_attempt(
                    challenge,
                    current_otp,
                )
            elif pending_error is None:
                ResetService._consume_otp(challenge, current_otp)
                verified_challenge = challenge

        if pending_error is not None:
            raise pending_error
        if verified_challenge is None:
            raise InvalidResetChallengeError(
                "The reset OTP verification could not be completed.",
            )
        return verified_challenge

    @staticmethod
    def complete_password_reset(reset_id: UUID, raw_password: str) -> ResetChallenge:
        """
        Replace a password after OTP verification and revoke older sessions.

        Args:
            reset_id: Identifier of the OTP-verified password reset challenge.
            raw_password: New password selected for the account.

        Returns:
            The reset challenge advanced to the completed state.

        Raises:
            InvalidResetChallengeError: Raised when the challenge is absent,
                not a password reset, or not ready for completion.
            ExpiredResetChallengeError: Raised after expiring a completion
                window that has elapsed.
            ValueError: Raised when the new password violates account policy.
        """
        pending_error: ExpiredResetChallengeError | None = None
        completed_challenge: ResetChallenge | None = None

        with transaction.atomic():
            challenge: ResetChallenge = ResetService._get_locked_challenge(reset_id)
            if (
                challenge.reset_type != ResetType.PASSWORD
                or challenge.status != ResetStatus.OTP_VERIFIED
                or challenge.verified_at is None
                or challenge.completion_expires_at is None
            ):
                raise InvalidResetChallengeError(
                    "The password reset cannot be completed.",
                )

            if challenge.is_expired():
                challenge.status = ResetStatus.EXPIRED
                challenge.save(update_fields=["status", "updated_at"])
                pending_error = ExpiredResetChallengeError(
                    "The password reset completion window has expired.",
                )
            else:
                user: User = challenge.user
                try:
                    validate_password(raw_password, user=user)
                except DjangoValidationError as exception:
                    raise ValueError(" ".join(exception.messages)) from exception

                user.set_password(raw_password)
                user.token_version += 1
                user.save(update_fields=["password", "token_version"])

                challenge.status = ResetStatus.COMPLETED
                challenge.completed_at = timezone.now()
                challenge.save(
                    update_fields=["status", "completed_at", "updated_at"],
                )
                completed_challenge = challenge

        if pending_error is not None:
            raise pending_error
        if completed_challenge is None:
            raise InvalidResetChallengeError(
                "The password reset could not be completed.",
            )
        return completed_challenge
