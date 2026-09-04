from django.db import models as md



class RegistrationStatus(md.TextChoices):
    """Define the permitted states of a Keebox registration challenge."""

    OTP_PENDING: tuple[str, str] = "otp_pending", "OTP pending"
    OTP_VERIFIED: tuple[str, str] = "otp_verified", "OTP verified"
    COMPLETED: tuple[str, str] = "completed", "Completed"
    EXPIRED: tuple[str, str] = "expired", "Expired"
    CANCELLED: tuple[str, str] = "cancelled", "Cancelled"
