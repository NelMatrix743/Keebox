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

