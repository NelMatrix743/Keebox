from unittest.mock import Mock, patch

from django.test import SimpleTestCase

from apps.core.key_utils import (
    generate_kbkey,
    generate_kmkey,
    validate_kbkey,
    validate_kmkey,
)



class KeeboxKeyGenerationTests(SimpleTestCase):
    @patch("apps.core.key_utils.token_bytes", return_value=bytes(range(32)))
    def test_generate_kbkey_returns_a_formatted_user_key(
        self,
        secure_random_bytes: Mock,
    ) -> None:
        """
        Verify KBKey generation preserves 256 random bits in the user format.

        Args:
            self: Current test case instance.
            secure_random_bytes: Mocked cryptographic random-byte generator.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the generated KBKey format is invalid.
        """
        key: str = generate_kbkey()

        self.assertEqual(len(key), 48)
        self.assertEqual(key[:4], "KBK-")
        self.assertEqual(key[26], "-")
        self.assertEqual(len(key[4:26]), 22)
        self.assertEqual(len(key[27:48]), 21)
        self.assertTrue(validate_kbkey(key))
        self.assertFalse(validate_kmkey(key))
        secure_random_bytes.assert_called_once_with(32)

    @patch("apps.core.key_utils.token_bytes", return_value=bytes(range(32)))
    def test_generate_kmkey_returns_a_formatted_master_key(
        self,
        secure_random_bytes: Mock,
    ) -> None:
        """
        Verify KMKey generation preserves 256 random bits in the master format.

        Args:
            self: Current test case instance.
            secure_random_bytes: Mocked cryptographic random-byte generator.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the generated KMKey format is invalid.
        """
        key: str = generate_kmkey()

        self.assertEqual(len(key), 48)
        self.assertEqual(key[:4], "KMK-")
        self.assertEqual(key[26], "-")
        self.assertEqual(len(key[4:26]), 22)
        self.assertEqual(len(key[27:48]), 21)
        self.assertTrue(validate_kmkey(key))
        self.assertFalse(validate_kbkey(key))
        secure_random_bytes.assert_called_once_with(32)


class KeeboxKeyValidationTests(SimpleTestCase):
    def test_validation_accepts_base64url_hyphens_inside_segments(self) -> None:
        """
        Verify payload hyphens are not mistaken for structural delimiters.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a valid Base64url payload is rejected.
        """
        payload: str = "-__7__v_-__7__v_-__7__v_-__7__v_-__7__v_-_8"
        key: str = f"KBK-{payload[:22]}-{payload[22:]}"

        self.assertTrue(validate_kbkey(key))
