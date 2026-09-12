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

