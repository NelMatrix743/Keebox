from datetime import timedelta
from typing import Literal



REGISTRATION_CHALLENGE_TTL: timedelta = timedelta(minutes=30)
RESET_CHALLENGE_COMPLETION_TTL: timedelta = timedelta(minutes=10)

AUTH_LOGIN_CHALLENGE_TTL: timedelta = timedelta(minutes=10)
AUTH_PIN_LOCKOUT_DURATION: timedelta = timedelta(hours=24)
AUTH_PIN_MAX_ATTEMPTS: int = 5

OTP_CODE_LENGTH: int = 6
OTP_TTL: timedelta = timedelta(minutes=5)
OTP_RESEND_COOLDOWN: timedelta = timedelta(seconds=60)
OTP_MAX_ATTEMPTS: int = 5
OTP_MAX_RESENDS: int = 3

KBKEY_PREFIX: Literal["KBK"] = "KBK"
KMKEY_PREFIX: Literal["KMK"] = "KMK"

KEEBOX_KEY_BYTE_LENGTH: int = 32
KEEBOX_KEY_ENCODED_LENGTH: int = 43
KEEBOX_KEY_FIRST_SEGMENT_LENGTH: int = 22
KEEBOX_KEY_SECOND_SEGMENT_LENGTH: int = 21
KEEBOX_KEY_FORMATTED_LENGTH: int = 48

KBKEY_NONCE_LENGTH: int = 12
KBKEY_AUTH_TAG_LENGTH: int = 16
KBKEY_ENCRYPTION_VERSION: int = 1

BASE64URL_ALPHABET: frozenset[str] = frozenset(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_",
)
