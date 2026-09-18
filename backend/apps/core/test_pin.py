from typing import Self

from django.test import SimpleTestCase, override_settings

from apps.core.pin import encrypt_lock_pin, verify_lock_pin



@override_settings(KEEBOX_PIN_PEPPER="test-pin-pepper")
class LockPINSecurityTests(SimpleTestCase):
    def test_encrypt_lock_pin_returns_an_argon2id_verifier(self: Self) -> None:
        """
        Verify lock PIN encryption returns a non-reversible Argon2id verifier.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the verifier is not an Argon2id hash.
        """
        encoded_pin: str = encrypt_lock_pin("123456")

        self.assertTrue(encoded_pin.startswith("$argon2id$"))
        self.assertNotEqual(encoded_pin, "123456")
        self.assertNotIn("test-pin-pepper", encoded_pin)

 