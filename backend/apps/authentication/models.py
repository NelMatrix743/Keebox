from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any, ClassVar, Self

from django.contrib.auth.base_user import BaseUserManager
from django.contrib.auth.hashers import check_password, make_password
from django.contrib.auth.models import AbstractUser
from django.db import models as md
from django.utils import timezone

from apps.core.choices import OTPStatus, RegistrationStatus
from apps.core.constants import OTP_TTL, REGISTRATION_CHALLENGE_TTL



def registration_challenge_expiration() -> datetime:
    """
    Calculate the fixed expiration time for a new registration challenge.

    Args:
        None.

    Returns:
        The server timestamp thirty minutes after challenge creation.

    Raises:
        None.
    """
    return timezone.now() + REGISTRATION_CHALLENGE_TTL


def otp_verification_expiration() -> datetime:
    """
    Calculate the fixed expiration time for a new OTP verification.

    Args:
        None.

    Returns:
        The server timestamp five minutes after OTP creation.

    Raises:
        None.
    """
    return timezone.now() + OTP_TTL


class UserManager(BaseUserManager):
    """Create Keebox users whose email address is their login identifier."""

    use_in_migrations: bool = True

    def _create_user(
        self: Self,
        email: str,
        password: str,
        **extra_fields: Any,
    ) -> User:
        """
        Create and persist a Keebox user with normalized credentials.

        Args:
            email:
                Email address used as the account login identifier.
            password:
                Raw account password to hash before persistence.
            **extra_fields:
                Additional custom user model field values.

        Returns:
            The newly persisted Keebox user.

        Raises:
            ValueError: Raised when the email address or password is
            missing.
        """
        if not email:
            raise ValueError("The email address is required.")
        if not password:
            raise ValueError("The password is required.")

        normalized_email: str = self.normalize_email(email.strip()).casefold()
        user: User = self.model(email=normalized_email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_user(
        self: Self,
        email: str,
        password: str,
        **extra_fields: Any,
    ) -> User:
        """
        Create and persist a regular Keebox user.

        Args:
            email:
                Email address used as the account login identifier.
            password:
                Raw account password to hash before persistence.
            **extra_fields:
                Additional custom user model field values.

        Returns:
            The newly persisted regular user.

        Raises:
            ValueError: Raised when required credentials are missing.
        """
        extra_fields.setdefault("is_staff", False)
        extra_fields.setdefault("is_superuser", False)
        return self._create_user(email, password, **extra_fields)

    def create_superuser(
        self: Self,
        email: str,
        password: str,
        **extra_fields: Any,
    ) -> User:
        """
        Create and persist a Keebox administrative user.

        Args:
            email:
                Email address used as the administrator login identifier.
            password:
                Raw administrator password to hash before persistence.
            **extra_fields:
                Additional custom user model field values.

        Returns:
            The newly persisted administrative user.

        Raises:
            ValueError: Raised when credentials or privilege flags are
            invalid.
        """
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)

        if extra_fields.get("is_staff") is not True:
            raise ValueError("A superuser must have is_staff=True.")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("A superuser must have is_superuser=True.")

        return self._create_user(email, password, **extra_fields)


class User(AbstractUser):
    """Represent a complete Keebox user account and its protected key material."""

    id: md.UUIDField = md.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    first_name: md.CharField = md.CharField(max_length=150)
    last_name: md.CharField = md.CharField(max_length=150)
    username: None = None

    email: md.EmailField = md.EmailField(unique=True)

    pin_hash: md.CharField = md.CharField(max_length=255, null=True, blank=True)
    pin_version: md.PositiveIntegerField = md.PositiveIntegerField(default=0)

    encrypted_kbkey: md.BinaryField = md.BinaryField(null=True, blank=True)
    kbkey_nonce: md.BinaryField = md.BinaryField(max_length=12, null=True, blank=True)
    kbkey_encryption_version: md.PositiveSmallIntegerField = md.PositiveSmallIntegerField(
        default=1,
    )

    USERNAME_FIELD: str = "email"
    REQUIRED_FIELDS: ClassVar[list[str]] = ["first_name", "last_name"]

    objects: UserManager = UserManager()

    class Meta(AbstractUser.Meta):
        db_table: str = "keebox_users"
        ordering: ClassVar[list[str]] = ["-date_joined"]



class RegistrationChallenge(md.Model):
    """Represent one incomplete Keebox account-registration process."""

    id: md.UUIDField = md.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    first_name: md.CharField = md.CharField(max_length=150)
    last_name: md.CharField = md.CharField(max_length=150)
    email: md.EmailField = md.EmailField()
    password_hash: md.CharField = md.CharField(max_length=128)

    status: md.CharField = md.CharField(
        max_length=20,
        choices=RegistrationStatus.choices,
        default=RegistrationStatus.OTP_PENDING,
    )
    expires_at: md.DateTimeField = md.DateTimeField(
        default=registration_challenge_expiration,
    )
    completed_at: md.DateTimeField = md.DateTimeField(null=True, blank=True)

    created_at: md.DateTimeField = md.DateTimeField(auto_now_add=True)
    updated_at: md.DateTimeField = md.DateTimeField(auto_now=True)

    def set_password(self: Self, raw_password: str) -> None:
        """
        Hash and assign the pending account password.

        Args:
            self: Current registration challenge instance.
            raw_password: Raw account password supplied during registration.

        Returns:
            None: This method updates the challenge in memory.

        Raises:
            ValueError: Raised when the password is empty.
        """
        if not raw_password:
            raise ValueError("The password is required.")

        self.password_hash = make_password(raw_password)

    def check_password(self: Self, raw_password: str) -> bool:
        """
        Compare a raw password with the stored registration password hash.

        Args:
            self: Current registration challenge instance.
            raw_password: Raw account password to verify.

        Returns:
            True when the password matches; otherwise, False.

        Raises:
            None.
        """
        return check_password(raw_password, self.password_hash)

    def is_expired(self: Self) -> bool:
        """
        Determine whether the registration challenge has reached its expiration.

        Args:
            self: Current registration challenge instance.

        Returns:
            True when the server time is at or beyond the expiration time.

        Raises:
            None.
        """
        return timezone.now() >= self.expires_at

    def save(self: Self, *args: Any, **kwargs: Any) -> None:
        """
        Normalize the registration email before persisting the challenge.

        Args:
            self: Current registration challenge instance.
            *args: Positional arguments forwarded to Django's model save method.
            **kwargs: Keyword arguments forwarded to Django's model save method.

        Returns:
            None: This method persists the challenge.

        Raises:
            ValueError: Raised when the email address is empty.
        """
        if not self.email:
            raise ValueError("The email address is required.")

        self.email = BaseUserManager.normalize_email(self.email.strip()).casefold()
        super().save(*args, **kwargs)

    class Meta:
        db_table: str = "auth_registration_challenge"
        ordering: ClassVar[list[str]] = ["-created_at"]



class OTPVerification(md.Model):
    """Represent one OTP verification attempt owned by an authentication challenge."""

    id: md.UUIDField = md.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    registration_challenge: md.ForeignKey = md.ForeignKey(
        RegistrationChallenge,
        on_delete=md.CASCADE,
        related_name="otp_verifications",
    )

    email: md.EmailField = md.EmailField()
    
    code_hash: md.CharField = md.CharField(max_length=128)

    status: md.CharField = md.CharField(
        max_length=20,
        choices=OTPStatus.choices,
        default=OTPStatus.PENDING,
    )

    attempt_count: md.PositiveSmallIntegerField = md.PositiveSmallIntegerField(default=0)
    resend_count: md.PositiveSmallIntegerField = md.PositiveSmallIntegerField(default=0)

    last_sent_at: md.DateTimeField = md.DateTimeField(default=timezone.now)
    expires_at: md.DateTimeField = md.DateTimeField(
        default=otp_verification_expiration,
    )
    consumed_at: md.DateTimeField = md.DateTimeField(null=True, blank=True)

    created_at: md.DateTimeField = md.DateTimeField(auto_now_add=True)
    updated_at: md.DateTimeField = md.DateTimeField(auto_now=True)

    class Meta:
        db_table: str = "otp_verifications"
        ordering: ClassVar[list[str]] = ["-created_at"]
