from base64 import b64decode
from typing import Self

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from django.test import SimpleTestCase

from apps.core.constants import (
    KBKEY_AUTH_TAG_LENGTH,
    KBKEY_ENCRYPTION_VERSION,
    KBKEY_NONCE_LENGTH,
)
from apps.core.exceptions import KeeboxKeyDecryptionError
from apps.core.key_utils import decrypt_kbkey, encrypt_kbkey



class KeeboxKeyEncryptionTests(SimpleTestCase):
    kbkey: str = "KBK-AAECAwQFBgcICQoLDA0ODx-AREhMUFRYXGBkaGxwdHh8"
    kmkey: str = "KMK-ICEiIyQlJicoKSorLC0uLz-AxMjM0NTY3ODk6Ozw9Pj8"
    alternate_kmkey: str = "KMK-QEFCQ0RFRkdISUpLTE1OT1-BRUlNUVVZXWFlaW1xdXl8"

    def test_encrypt_and_decrypt_kbkey_round_trip(self: Self) -> None:
        """
        Verify authenticated encryption preserves the complete formatted KBKey.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the KBKey cannot complete a round trip.
        """
        encrypted_kbkey, nonce, encryption_version = encrypt_kbkey(
            self.kbkey,
            self.kmkey,
        )

        decrypted_kbkey: str = decrypt_kbkey(
            encrypted_kbkey,
            nonce,
            self.kmkey,
            encryption_version,
        )

        self.assertEqual(decrypted_kbkey, self.kbkey)
        self.assertEqual(len(nonce), KBKEY_NONCE_LENGTH)
        self.assertEqual(encryption_version, KBKEY_ENCRYPTION_VERSION)
        self.assertEqual(
            len(encrypted_kbkey),
            len(self.kbkey.encode("utf-8")) + KBKEY_AUTH_TAG_LENGTH,
        )
        self.assertNotIn(self.kbkey.encode("utf-8"), encrypted_kbkey)

    def test_encrypt_kbkey_uses_a_unique_nonce(self: Self) -> None:
        """
        Verify repeated encryption produces distinct nonces and ciphertext.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an AES-GCM nonce is reused.
        """
        first_encrypted, first_nonce, _ = encrypt_kbkey(self.kbkey, self.kmkey)
        second_encrypted, second_nonce, _ = encrypt_kbkey(self.kbkey, self.kmkey)

        self.assertNotEqual(first_nonce, second_nonce)
        self.assertNotEqual(first_encrypted, second_encrypted)

    def test_encrypt_kbkey_rejects_malformed_keys(self: Self) -> None:
        """
        Verify encryption requires canonical KBKey and KMKey values.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when encryption accepts a malformed key.
        """
        invalid_pairs: tuple[tuple[str, str], ...] = (
            ("not-a-kbkey", self.kmkey),
            (self.kbkey, "not-a-kmkey"),
            (self.kmkey, self.kmkey),
            (self.kbkey, self.kbkey),
        )

        for kbkey, kmkey in invalid_pairs:
            with self.subTest(kbkey=kbkey, kmkey=kmkey), self.assertRaises(
                ValueError,
            ):
                encrypt_kbkey(kbkey, kmkey)

    def test_decrypt_kbkey_rejects_an_incorrect_master_key(self: Self) -> None:
        """
        Verify ciphertext cannot be opened with another valid KMKey.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an incorrect KMKey decrypts the KBKey.
        """
        encrypted_kbkey, nonce, encryption_version = encrypt_kbkey(
            self.kbkey,
            self.kmkey,
        )

        with self.assertRaises(KeeboxKeyDecryptionError):
            decrypt_kbkey(
                encrypted_kbkey,
                nonce,
                self.alternate_kmkey,
                encryption_version,
            )
