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

