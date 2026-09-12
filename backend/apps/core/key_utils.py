from base64 import b64decode, urlsafe_b64encode
from binascii import Error as BinasciiError
from secrets import token_bytes
from typing import Literal

from apps.core.constants import (
    BASE64URL_ALPHABET,
    KBKEY_PREFIX,
    KEEBOX_KEY_BYTE_LENGTH,
    KEEBOX_KEY_FIRST_SEGMENT_LENGTH,
    KEEBOX_KEY_FORMATTED_LENGTH,
    KMKEY_PREFIX,
)



type KeyPrefix = Literal["KBK", "KMK"]


def _encode_key_material(key_material: bytes) -> str:
    """
    Encode raw key material as canonical unpadded Base64url text.

    Args:
        key_material: Raw cryptographic bytes to encode.

    Returns:
        Canonical Base64url text without padding.

    Raises:
        None.
    """
    return urlsafe_b64encode(key_material).decode("ascii").rstrip("=")


def _generate_key(prefix: KeyPrefix) -> str:
    """
    Generate a formatted Keebox key for the requested key type.

    Args:
        prefix: Approved prefix identifying the generated key type.

    Returns:
        Formatted key containing 256 bits of random key material.

    Raises:
        None.
    """
    encoded_payload: str = _encode_key_material(
        token_bytes(KEEBOX_KEY_BYTE_LENGTH),
    )
    first_segment: str = encoded_payload[:KEEBOX_KEY_FIRST_SEGMENT_LENGTH]
    second_segment: str = encoded_payload[KEEBOX_KEY_FIRST_SEGMENT_LENGTH:]
    return f"{prefix}-{first_segment}-{second_segment}"


def _validate_key(value: str, expected_prefix: KeyPrefix) -> bool:
    """
    Validate a formatted Keebox key using fixed delimiter positions.

    Args:
        value: Formatted key value to validate.
        expected_prefix: Prefix required for the requested key type.

    Returns:
        True when the value is a canonical key of the expected type.

    Raises:
        None.
    """
    if len(value) != KEEBOX_KEY_FORMATTED_LENGTH:
        return False
    if value[:3] != expected_prefix:
        return False
    
    second_delimiter_index: int = 4 + KEEBOX_KEY_FIRST_SEGMENT_LENGTH
    if value[3] != "-" or value[second_delimiter_index] != "-":
        return False

    encoded_payload: str = (
        value[4:second_delimiter_index]
        + value[second_delimiter_index + 1:]
    )
    if not all(character in BASE64URL_ALPHABET for character in encoded_payload):
        return False

    try:
        decoded_key_material: bytes = b64decode(
            f"{encoded_payload}=",
            altchars=b"-_",
            validate=True,
        )
    except (BinasciiError, ValueError):
        return False

    return (
        len(decoded_key_material) == KEEBOX_KEY_BYTE_LENGTH
        and _encode_key_material(decoded_key_material) == encoded_payload
    )


def generate_kbkey() -> str:
    """
    Generate a formatted Keebox user key.

    Args:
        None.

    Returns:
        KBKey containing 256 bits of random key material.

    Raises:
        None.
    """
    return _generate_key(KBKEY_PREFIX)


def generate_kmkey() -> str:
    """
    Generate a formatted Keebox master key.

    Args:
        None.

    Returns:
        KMKey containing 256 bits of random key material.

    Raises:
        None.
    """
    return _generate_key(KMKEY_PREFIX)


def validate_kbkey(value: str) -> bool:
    """
    Determine whether a value is a valid formatted Keebox user key.

    Args:
        value: Formatted key value to validate.

    Returns:
        True when the value is a canonical KBKey.

    Raises:
        None.
    """
    return _validate_key(value, KBKEY_PREFIX)


def validate_kmkey(value: str) -> bool:
    """
    Determine whether a value is a valid formatted Keebox master key.

    Args:
        value: Formatted key value to validate.

    Returns:
        True when the value is a canonical KMKey.

    Raises:
        None.
    """
    return _validate_key(value, KMKEY_PREFIX)
