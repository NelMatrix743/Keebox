from datetime import datetime
from uuid import UUID

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from apps.authentication.exceptions import (
    ConsumedOTPError,
    ExpiredOTPError,
    InvalidOTPError,
    InvalidRegistrationStateError,
    LockedOTPError,
    OTPResendCooldownError,
    OTPResendLimitError,
    OTPServiceError,
    RegistrationEmailConflictError,
)
from apps.authentication.models import OTPVerification, RegistrationChallenge, User
from apps.authentication.otp import generate_otp_code
from apps.core.choices import OTPStatus, RegistrationStatus
from apps.core.constants import (
    OTP_MAX_ATTEMPTS,
    OTP_MAX_RESENDS,
    OTP_RESEND_COOLDOWN,
)
from apps.core.key_utils import encrypt_kbkey, generate_kbkey
from apps.core.pin import encrypt_lock_pin



class RegistrationService:
    """Provide the application services for the Keebox registration workflow."""

    @staticmethod
    def _get_locked_registration_challenge(
        registration_challenge_id: UUID,
    ) -> RegistrationChallenge:
        """
        Retrieve and lock a registration challenge for a service operation.

        Args:
            registration_challenge_id: Identifier of the registration challenge.

        Returns:
            The locked registration challenge.

        Raises:
            InvalidRegistrationStateError: Raised when the registration is missing.
        """
        try:
            registration_challenge: RegistrationChallenge = (
                RegistrationChallenge.objects.select_for_update().get(
                    pk=registration_challenge_id,
                )
            )
        except RegistrationChallenge.DoesNotExist as exception:
            raise InvalidRegistrationStateError(
                "The registration challenge is unavailable.",
            ) from exception

        return registration_challenge

    @staticmethod
    def _validate_registration_challenge(
        registration_challenge: RegistrationChallenge,
        required_status: RegistrationStatus,
        operation: str,
    ) -> None:
        """
        Validate the lifecycle state of a registration challenge.

        Args:
            registration_challenge: Registration challenge being validated.
            required_status: Status required to perform the service operation.
            operation: Description of the operation for the error message.

        Returns:
            None: This method only validates registration state.

        Raises:
            InvalidRegistrationStateError: Raised when the challenge has an invalid
                status or has expired.
        """
        if (
            registration_challenge.status != required_status
            or registration_challenge.is_expired()
        ):
            raise InvalidRegistrationStateError(
                f"The registration challenge cannot {operation}.",
            )

    @staticmethod
    def _get_locked_latest_otp(
        registration_challenge: RegistrationChallenge,
        operation: str,
    ) -> OTPVerification:
        """
        Retrieve the most recently issued OTP for a registration challenge.

        Args:
            registration_challenge: Registration challenge that owns the OTP.
            operation: OTP operation being performed for the error message.

        Returns:
            The locked most recently issued OTP verification.

        Raises:
            InvalidRegistrationStateError: Raised when the registration has no OTP.
        """
        current_otp: OTPVerification | None = (
            OTPVerification.objects.select_for_update()
            .filter(registration_challenge=registration_challenge)
            .order_by("-created_at")
            .first()
        )
        if current_otp is None:
            raise InvalidRegistrationStateError(
                f"The registration challenge has no OTP to {operation}.",
            )

        return current_otp

    @staticmethod
    def _expire_pending_otps(
        registration_challenge: RegistrationChallenge,
    ) -> None:
        """
        Expire every pending OTP owned by a registration challenge.

        Args:
            registration_challenge: Registration challenge whose OTPs are expired.

        Returns:
            None: This method updates matching OTP records.

        Raises:
            None.
        """
        OTPVerification.objects.filter(
            registration_challenge=registration_challenge,
            status=OTPStatus.PENDING,
        ).update(status=OTPStatus.EXPIRED)

    @staticmethod
    def _create_otp(
        registration_challenge: RegistrationChallenge,
    ) -> tuple[OTPVerification, str]:
        """
        Generate, protect, and persist an OTP for a registration challenge.

        Args:
            registration_challenge: Registration challenge that owns the new OTP.

        Returns:
            The persisted OTP verification and raw code for immediate delivery.

        Raises:
            ValueError: Raised when the generated OTP code is empty.
        """
        raw_code: str = generate_otp_code()
        otp_verification: OTPVerification = OTPVerification(
            registration_challenge=registration_challenge,
            email=registration_challenge.email,
        )
        otp_verification.hash_and_set_otp_code(raw_code)
        otp_verification.save()
        return otp_verification, raw_code

    @staticmethod
    def _ensure_resend_cooldown_elapsed(
        current_otp: OTPVerification,
    ) -> None:
        """
        Ensure the current OTP has passed its resend cooldown.

        Args:
            current_otp: Most recently issued OTP verification.

        Returns:
            None: This method only validates the resend time.

        Raises:
            OTPResendCooldownError: Raised when the resend cooldown is still active.
        """
        resend_available_at: datetime = current_otp.last_sent_at + OTP_RESEND_COOLDOWN
        if timezone.now() < resend_available_at:
            raise OTPResendCooldownError(
                "The OTP resend cooldown has not elapsed.",
            )

    @staticmethod
    def _cancel_registration(
        registration_challenge: RegistrationChallenge,
    ) -> None:
        """
        Cancel a registration challenge and expire its pending OTPs.

        Args:
            registration_challenge: Registration challenge to invalidate.

        Returns:
            None: This method persists the invalidated registration state.

        Raises:
            None.
        """
        registration_challenge.status = RegistrationStatus.CANCELLED
        registration_challenge.save(update_fields=["status", "updated_at"])
        RegistrationService._expire_pending_otps(registration_challenge)

    @staticmethod
    def _get_terminal_otp_error(
        current_otp: OTPVerification,
    ) -> OTPServiceError | None:
        """
        Resolve and persist any terminal condition on an OTP verification.

        Args:
            current_otp: OTP verification being evaluated.

        Returns:
            A deferred error for a newly expired or locked OTP, otherwise None.

        Raises:
            ConsumedOTPError: Raised when the OTP was previously consumed.
            ExpiredOTPError: Raised when the OTP was previously marked expired.
            LockedOTPError: Raised when the OTP was previously marked locked.
        """
        if current_otp.is_consumed():
            raise ConsumedOTPError("The OTP has already been consumed.")
        if current_otp.status == OTPStatus.EXPIRED:
            raise ExpiredOTPError("The OTP has expired.")
        if current_otp.status == OTPStatus.LOCKED:
            raise LockedOTPError("The OTP is locked.")

        if current_otp.is_expired():
            current_otp.status = OTPStatus.EXPIRED
            current_otp.save(update_fields=["status", "updated_at"])
            return ExpiredOTPError("The OTP has expired.")

        if current_otp.attempt_count >= OTP_MAX_ATTEMPTS:
            current_otp.status = OTPStatus.LOCKED
            current_otp.save(update_fields=["status", "updated_at"])
            return LockedOTPError("The OTP is locked.")

        return None

    @staticmethod
    def _record_failed_otp_attempt(
        current_otp: OTPVerification,
    ) -> OTPServiceError:
        """
        Record an invalid OTP submission and apply the attempt limit.

        Args:
            current_otp: OTP verification receiving the failed attempt.

        Returns:
            The deferred invalid-code or locked-OTP error for the caller.

        Raises:
            None.
        """
        current_otp.attempt_count += 1
        if current_otp.attempt_count >= OTP_MAX_ATTEMPTS:
            current_otp.status = OTPStatus.LOCKED
            pending_error: OTPServiceError = LockedOTPError("The OTP is locked.")
        else:
            pending_error = InvalidOTPError("The OTP code is invalid.")

        current_otp.save(
            update_fields=["attempt_count", "status", "updated_at"],
        )
        return pending_error

    @staticmethod
    def _consume_otp(
        registration_challenge: RegistrationChallenge,
        current_otp: OTPVerification,
    ) -> None:
        """
        Consume an OTP and mark its registration as OTP verified.

        Args:
            registration_challenge: Registration challenge advanced by the OTP.
            current_otp: OTP verification that matched the submitted code.

        Returns:
            None: This method persists both successful state transitions.

        Raises:
            None.
        """
        current_otp.status = OTPStatus.CONSUMED
        current_otp.consumed_at = timezone.now()
        current_otp.save(
            update_fields=["status", "consumed_at", "updated_at"],
        )
        registration_challenge.status = RegistrationStatus.OTP_VERIFIED
        registration_challenge.save(update_fields=["status", "updated_at"])

    @staticmethod
    def _create_registration_challenge(
        first_name: str,
        last_name: str,
        normalized_email: str,
        raw_password: str,
    ) -> RegistrationChallenge:
        """
        Create a pending registration challenge with a protected password.

        Args:
            first_name: Given name submitted for the permanent account.
            last_name: Family name submitted for the permanent account.
            normalized_email: Canonical available registration email address.
            raw_password: Raw account password to protect for later completion.

        Returns:
            The persisted pending registration challenge.

        Raises:
            ValueError: Raised when the password is empty.
        """
        registration_challenge: RegistrationChallenge = RegistrationChallenge(
            first_name=first_name,
            last_name=last_name,
            email=normalized_email,
        )
        registration_challenge.set_password(raw_password)
        registration_challenge.save()
        return registration_challenge

    @staticmethod
    def _generate_protected_kbkey() -> tuple[str, bytes, bytes, int]:
        """
        Generate a KBKey and protect it with the configured Keebox master key.

        Args:
            None.

        Returns:
            The plaintext KBKey, ciphertext, nonce, and encryption version.

        Raises:
            ValueError: Raised when the configured Keebox master key is invalid.
        """
        kbkey: str = generate_kbkey()
        encrypted_kbkey: bytes
        kbkey_nonce: bytes
        kbkey_encryption_version: int
        (
            encrypted_kbkey,
            kbkey_nonce,
            kbkey_encryption_version,
        ) = encrypt_kbkey(kbkey, settings.KEEBOX_MASTER_KEY)
        return (
            kbkey,
            encrypted_kbkey,
            kbkey_nonce,
            kbkey_encryption_version,
        )

    @staticmethod
    def _create_user(
        registration_challenge: RegistrationChallenge,
        raw_pin: str,
    ) -> tuple[User, str]:
        """
        Create a permanent user from an OTP-verified registration.

        Args:
            registration_challenge: Registration data used for the user.
            raw_pin: Lock PIN to protect before storing it on the user.

        Returns:
            The persisted permanent user account and its plaintext KBKey.

        Raises:
            ValueError: Raised when the lock PIN is empty or the configured
                Keebox master key or PIN pepper is invalid.
        """
        if not raw_pin:
            raise ValueError("The lock PIN is required.")

        kbkey: str
        encrypted_kbkey: bytes
        kbkey_nonce: bytes
        kbkey_encryption_version: int
        (
            kbkey,
            encrypted_kbkey,
            kbkey_nonce,
            kbkey_encryption_version,
        ) = RegistrationService._generate_protected_kbkey()
        user: User = User(
            first_name=registration_challenge.first_name,
            last_name=registration_challenge.last_name,
            email=registration_challenge.email,
            password=registration_challenge.password_hash,
            pin_hash=encrypt_lock_pin(raw_pin),
            encrypted_kbkey=encrypted_kbkey,
            kbkey_nonce=kbkey_nonce,
            kbkey_encryption_version=kbkey_encryption_version,
        )
        user.save()
        return user, kbkey

    @staticmethod
    def _mark_registration_completed(
        registration_challenge: RegistrationChallenge,
    ) -> None:
        """
        Persist the completed state of a registration challenge.

        Args:
            registration_challenge: Registration challenge that created a user.

        Returns:
            None: This method persists the completed registration state.

        Raises:
            None.
        """
        registration_challenge.status = RegistrationStatus.COMPLETED
        registration_challenge.completed_at = timezone.now()
        registration_challenge.save(
            update_fields=["status", "completed_at", "updated_at"],
        )

    @staticmethod
    def ensure_email_available(email: str) -> str:
        """
        Ensure an email can be used to begin a new registration.

        Args:
            email: Email address submitted for registration.

        Returns:
            The normalized email address for subsequent registration operations.

        Raises:
            ValueError: Raised when the email address is empty.
            RegistrationEmailConflictError: Raised when a permanent user already
                owns the normalized email address.
        """
        if not email.strip():
            raise ValueError("The email address is required.")

        normalized_email: str = User.objects.normalize_email(
            email.strip()
        ).casefold()
        if User.objects.filter(email=normalized_email).exists():
            raise RegistrationEmailConflictError(
                "A user with this email address already exists.",
            )

        return normalized_email

    @staticmethod
    @transaction.atomic
    def start_registration(
        first_name: str,
        last_name: str,
        email: str,
        raw_password: str,
    ) -> tuple[RegistrationChallenge, OTPVerification, str]:
        """
        Begin a registration challenge and issue its initial OTP.

        Args:
            first_name: Given name submitted for the permanent account.
            last_name: Family name submitted for the permanent account.
            email: Email address submitted for registration.
            raw_password: Raw password submitted for the permanent account.

        Returns:
            The registration challenge, initial OTP record, and raw delivery code.

        Raises:
            ValueError: Raised when the email address or password is empty.
            RegistrationEmailConflictError: Raised when the email already belongs
                to a permanent user.
            InvalidRegistrationStateError: Raised when the initial OTP cannot be
                issued for the newly created challenge.
        """
        normalized_email: str = RegistrationService.ensure_email_available(email)
        registration_challenge: RegistrationChallenge = (
            RegistrationService._create_registration_challenge(
                first_name,
                last_name,
                normalized_email,
                raw_password,
            )
        )
        otp_verification: OTPVerification
        raw_code: str
        otp_verification, raw_code = RegistrationService.issue_registration_otp(
            registration_challenge.id,
        )
        return registration_challenge, otp_verification, raw_code

    @staticmethod
    @transaction.atomic
    def issue_registration_otp(
        registration_challenge_id: UUID,
    ) -> tuple[OTPVerification, str]:
        """
        Create a protected OTP verification for a pending registration.

        Args:
            registration_challenge_id: Identifier of the owning registration
                challenge.

        Returns:
            The persisted OTP verification and raw code for immediate delivery.

        Raises:
            InvalidRegistrationStateError: Raised when the registration cannot
                issue OTPs.
        """
        registration_challenge: RegistrationChallenge = (
            RegistrationService._get_locked_registration_challenge(
                registration_challenge_id,
            )
        )
        RegistrationService._validate_registration_challenge(
            registration_challenge,
            RegistrationStatus.OTP_PENDING,
            "issue an OTP",
        )
        RegistrationService._expire_pending_otps(registration_challenge)
        return RegistrationService._create_otp(registration_challenge)

    @staticmethod
    def resend_registration_otp(
        registration_challenge_id: UUID,
    ) -> tuple[OTPVerification, str]:
        """
        Replace the current OTP for an active registration challenge.

        Args:
            registration_challenge_id: Identifier of the owning registration
                challenge.

        Returns:
            The persisted replacement OTP and raw code for immediate delivery.

        Raises:
            InvalidRegistrationStateError: Raised when the registration or OTP is
                unavailable for resending.
            OTPResendCooldownError: Raised when the resend cooldown has not elapsed.
            OTPResendLimitError: Raised after cancelling a registration that has
                used its resend allowance.
        """
        resend_limit_reached: bool = False
        replacement_otp: OTPVerification | None = None
        raw_code: str = ""

        with transaction.atomic():
            registration_challenge: RegistrationChallenge = (
                RegistrationService._get_locked_registration_challenge(
                    registration_challenge_id,
                )
            )
            RegistrationService._validate_registration_challenge(
                registration_challenge,
                RegistrationStatus.OTP_PENDING,
                "resend an OTP",
            )
            current_otp: OTPVerification = (
                RegistrationService._get_locked_latest_otp(
                    registration_challenge,
                    "resend",
                )
            )

            if registration_challenge.resend_count >= OTP_MAX_RESENDS:
                RegistrationService._cancel_registration(registration_challenge)
                resend_limit_reached = True
            else:
                RegistrationService._ensure_resend_cooldown_elapsed(current_otp)
                RegistrationService._expire_pending_otps(registration_challenge)
                registration_challenge.resend_count += 1
                registration_challenge.save(
                    update_fields=["resend_count", "updated_at"],
                )
                replacement_otp, raw_code = RegistrationService._create_otp(
                    registration_challenge,
                )

        if resend_limit_reached:
            raise OTPResendLimitError(
                "The registration challenge reached its OTP resend limit.",
            )

        if replacement_otp is None:
            raise InvalidRegistrationStateError(
                "The replacement OTP could not be created.",
            )

        return replacement_otp, raw_code

    @staticmethod
    def verify_registration_otp(
        registration_challenge_id: UUID,
        raw_code: str,
    ) -> OTPVerification:
        """
        Verify the current OTP code for a pending registration challenge.

        Args:
            registration_challenge_id: Identifier of the owning registration
                challenge.
            raw_code: Raw OTP code submitted for verification.

        Returns:
            The consumed OTP verification after successful validation.

        Raises:
            InvalidRegistrationStateError: Raised when the registration or OTP is
                unavailable for verification.
            ConsumedOTPError: Raised when the current OTP was already consumed.
            ExpiredOTPError: Raised when the current OTP has expired.
            LockedOTPError: Raised when the current OTP is or becomes locked.
            InvalidOTPError: Raised when the submitted OTP code is incorrect.
        """
        pending_error: OTPServiceError | None = None
        verified_otp: OTPVerification | None = None

        with transaction.atomic():
            registration_challenge: RegistrationChallenge = (
                RegistrationService._get_locked_registration_challenge(
                    registration_challenge_id,
                )
            )
            RegistrationService._validate_registration_challenge(
                registration_challenge,
                RegistrationStatus.OTP_PENDING,
                "verify an OTP",
            )
            current_otp: OTPVerification = (
                RegistrationService._get_locked_latest_otp(
                    registration_challenge,
                    "verify",
                )
            )
            pending_error = RegistrationService._get_terminal_otp_error(
                current_otp,
            )

            if pending_error is None and not current_otp.verify_otp_code(raw_code):
                pending_error = RegistrationService._record_failed_otp_attempt(
                    current_otp,
                )
            elif pending_error is None:
                RegistrationService._consume_otp(
                    registration_challenge,
                    current_otp,
                )
                verified_otp = current_otp

        if pending_error is not None:
            raise pending_error

        if verified_otp is None:
            raise InvalidRegistrationStateError(
                "The OTP verification could not be completed.",
            )

        return verified_otp

    @staticmethod
    @transaction.atomic
    def complete_registration(
        registration_challenge_id: UUID,
        raw_pin: str,
    ) -> tuple[User, str]:
        """
        Complete an OTP-verified registration with a protected lock PIN.

        Args:
            registration_challenge_id: Identifier of the OTP-verified registration.
            raw_pin: Lock PIN to protect on the permanent account.

        Returns:
            The permanent user and plaintext KBKey created for the registration.

        Raises:
            InvalidRegistrationStateError: Raised when the registration is missing,
                expired, or not OTP-verified.
            ValueError: Raised when the lock PIN is empty or the configured
                Keebox master key or PIN pepper is invalid.
        """
        registration_challenge: RegistrationChallenge = (
            RegistrationService._get_locked_registration_challenge(
                registration_challenge_id,
            )
        )
        RegistrationService._validate_registration_challenge(
            registration_challenge,
            RegistrationStatus.OTP_VERIFIED,
            "be completed",
        )
        user: User
        kbkey: str
        user, kbkey = RegistrationService._create_user(
            registration_challenge,
            raw_pin,
        )
        RegistrationService._mark_registration_completed(registration_challenge)
        return user, kbkey
