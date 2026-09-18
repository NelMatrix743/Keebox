import hashlib
import hmac

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError, VerifyMismatchError
from django.conf import settings



_PIN_HASHER: PasswordHasher = PasswordHasher(
    time_cost=3,
    memory_cost=65536,
    parallelism=4,
    hash_len=32,
    salt_len=16,
)


def _get_pin_pepper() -> str:
    """
    Retrieve the configured server-side PIN pepper.

    Args:
        None.

    Returns:
        The configured PIN pepper.

    Raises:
        ValueError: Raised when the PIN pepper is missing or empty.
    """
    pin_pepper: str = str(
        getattr(settings, "KEEBOX_PIN_PEPPER", ""),
    ).strip()
    if not pin_pepper:
        raise ValueError("The Keebox PIN pepper is not configured.")
    return pin_pepper


def _pepper_pin(pin: str, pin_pepper: str) -> str:
    """
    Derive peppered PIN material before Argon2id hashing.

    Args:
        pin: Raw lock PIN submitted by the user.
        pin_pepper: Server-side secret used to protect the PIN search space.

    Returns:
        Hexadecimal HMAC-SHA256 output used as Argon2id input.

    Raises:
        None.
    """
    return hmac.new(
        key=pin_pepper.encode("utf-8"),
        msg=pin.encode("utf-8"),
        digestmod=hashlib.sha256,
    ).hexdigest()


def encrypt_lock_pin(pin: str) -> str:
    """
    Create a salted Argon2id verifier for a lock PIN.

    Args:
        pin: Raw lock PIN submitted by the user.

    Returns:
        An encoded Argon2id verifier containing its salt and parameters.

    Raises:
        ValueError: Raised when the PIN or server-side PIN pepper is empty.
    """
    if not pin:
        raise ValueError("The lock PIN is required.")

    pin_pepper: str = _get_pin_pepper()
    peppered_pin: str = _pepper_pin(pin, pin_pepper)
    return _PIN_HASHER.hash(peppered_pin)


def verify_lock_pin(pin: str, encoded_pin: str) -> bool:
    """
    Verify a raw lock PIN against an encoded Argon2id verifier.

    Args:
        pin: Raw lock PIN submitted by the user.
        encoded_pin: Stored Argon2id verifier for the lock PIN.

    Returns:
        True when the PIN matches; otherwise False.

    Raises:
        ValueError: Raised when the server-side PIN pepper is empty.
    """
    if not pin or not encoded_pin:
        return False

    pin_pepper: str = _get_pin_pepper()
    peppered_pin: str = _pepper_pin(pin, pin_pepper)
    try:
        return _PIN_HASHER.verify(encoded_pin, peppered_pin)
    except (InvalidHashError, VerificationError, VerifyMismatchError):
        return False
