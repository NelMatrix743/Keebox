import uuid
from typing import Any, ClassVar, Self

from django.contrib.auth.models import AbstractUser
from django.db import models as md



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
