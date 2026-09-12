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

    def test_validation_rejects_malformed_keys(self) -> None:
        """
        Verify malformed or noncanonical key representations are rejected.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an invalid key is accepted.
        """
        valid_key: str = (
            "KBK-AAECAwQFBgcICQoLDA0ODx-AREhMUFRYXGBkaGxwdHh8"
        )
        malformed_keys: tuple[str, ...] = (
            "",
            valid_key[1:],
            f"KMK{valid_key[3:]}",
            f"KBK_{valid_key[4:]}",
            f"{valid_key[:26]}_{valid_key[27:]}",
            f"{valid_key[:4]}+{valid_key[5:]}",
            f"{valid_key}=",
            f"{valid_key[:-1]}9",
        )

        for malformed_key in malformed_keys:
            with self.subTest(key=malformed_key):
                self.assertFalse(validate_kbkey(malformed_key))

    def test_validation_requires_the_expected_key_prefix(self) -> None:
        """
        Verify user and master validators do not accept the other key type.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when validation accepts the wrong prefix.
        """
        payload: str = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8"
        kbkey: str = f"KBK-{payload[:22]}-{payload[22:]}"
        kmkey: str = f"KMK-{payload[:22]}-{payload[22:]}"

        self.assertTrue(validate_kbkey(kbkey))
        self.assertFalse(validate_kbkey(kmkey))
        self.assertTrue(validate_kmkey(kmkey))
        self.assertFalse(validate_kmkey(kbkey))
