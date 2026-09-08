import secrets

from apps.core.constants import OTP_CODE_LENGTH



def generate_otp_code() -> str:
    """
    Generate a cryptographically secure numeric OTP code.

    Args:
        None.

    Returns:
        A zero-padded numeric OTP code with the configured length.

    Raises:
        None.
    """
    upper_bound: int = 10**OTP_CODE_LENGTH
    random_value: int = secrets.randbelow(upper_bound)
    return f"{random_value:0{OTP_CODE_LENGTH}d}"

