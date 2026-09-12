from typing import Self
from unittest.mock import patch

from django.test import SimpleTestCase

from apps.authentication.otp import generate_otp_code
from apps.core.constants import OTP_CODE_LENGTH



class OTPCodeGenerationTests(SimpleTestCase):
    def test_generate_otp_code_returns_six_secure_numeric_characters(
        self: Self,
    ) -> None:
        """
        Verify OTP generation uses secure randomness and preserves leading zeroes.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when generated OTP formatting is invalid.
        """
        with patch(
            "apps.authentication.otp.secrets.randbelow",
            return_value=42,
        ) as mocked_randbelow:
            otp_code: str = generate_otp_code()

        self.assertEqual(otp_code, "000042")
        self.assertEqual(len(otp_code), OTP_CODE_LENGTH)
        self.assertTrue(otp_code.isdigit())
        mocked_randbelow.assert_called_once_with(10**OTP_CODE_LENGTH)
