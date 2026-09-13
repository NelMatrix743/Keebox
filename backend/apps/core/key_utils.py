from base64 import b64decode, urlsafe_b64encode
from binascii import Error as BinasciiError
from secrets import token_bytes
from typing import Literal

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from apps.core.constants import (
    BASE64URL_ALPHABET,
    KBKEY_ENCRYPTION_VERSION,
    KBKEY_NONCE_LENGTH,
    KBKEY_PREFIX,
    KEEBOX_KEY_BYTE_LENGTH,
    KEEBOX_KEY_FIRST_SEGMENT_LENGTH,
    KEEBOX_KEY_FORMATTED_LENGTH,
    KMKEY_PREFIX,
)
from apps.core.exceptions import KeeboxKeyDecryptionError



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


def _decode_key_material(value: str, expected_prefix: KeyPrefix) -> bytes:
    """
    Validate and decode a formatted Keebox key using fixed positions.

    Args:
        value: Formatted key value to validate.
        expected_prefix: Prefix required for the requested key type.

    Returns:
        The exact 32 bytes represented by the formatted key.

    Raises:
        ValueError: Raised when the value is not a canonical key.
    """
    if len(value) != KEEBOX_KEY_FORMATTED_LENGTH:
        raise ValueError("The Keebox key length is invalid.")
    if value[:3] != expected_prefix:
        raise ValueError("The Keebox key prefix is invalid.")

    second_delimiter_index: int = 4 + KEEBOX_KEY_FIRST_SEGMENT_LENGTH
    if value[3] != "-" or value[second_delimiter_index] != "-":
        raise ValueError("The Keebox key delimiters are invalid.")

    encoded_payload: str = (
        value[4:second_delimiter_index]
        + value[second_delimiter_index + 1:]
    )
    if not all(character in BASE64URL_ALPHABET for character in encoded_payload):
        raise ValueError("The Keebox key contains invalid characters.")

    try:
        decoded_key_material: bytes = b64decode(
            f"{encoded_payload}=",
            altchars=b"-_",
            validate=True,
        )
    except (BinasciiError, ValueError) as exception:
        raise ValueError("The Keebox key encoding is invalid.") from exception

    if len(decoded_key_material) != KEEBOX_KEY_BYTE_LENGTH:
        raise ValueError("The Keebox key material length is invalid.")
    if _encode_key_material(decoded_key_material) != encoded_payload:
        raise ValueError("The Keebox key encoding is not canonical.")

    return decoded_key_material


def _validate_key(value: str, expected_prefix: KeyPrefix) -> bool:
    """
    Determine whether a formatted Keebox key is canonical.

    Args:
        value: Formatted key value to validate.
        expected_prefix: Prefix required for the requested key type.

    Returns:
        True when the value is a canonical key of the expected type.

    Raises:
        None.
    """
    try:
        _decode_key_material(value, expected_prefix)
    except ValueError:
        return False
    return True


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


def encrypt_kbkey(kbkey: str, kmkey: str) -> tuple[bytes, bytes, int]:
    """
    Encrypt a formatted KBKey with the server KMKey using AES-256-GCM.

    Args:
        kbkey: Canonical formatted user key to encrypt.
        kmkey: Canonical formatted master key protecting the user key.

    Returns:
        The authenticated ciphertext, unique nonce, and encryption version.

    Raises:
        ValueError: Raised when the KBKey or KMKey is malformed.
    """
    _decode_key_material(kbkey, KBKEY_PREFIX)
    raw_kmkey: bytes = _decode_key_material(kmkey, KMKEY_PREFIX)
    nonce: bytes = token_bytes(KBKEY_NONCE_LENGTH)
    encrypted_kbkey: bytes = AESGCM(raw_kmkey).encrypt(
        nonce,
        kbkey.encode("utf-8"),
        None,
    )
    return encrypted_kbkey, nonce, KBKEY_ENCRYPTION_VERSION

