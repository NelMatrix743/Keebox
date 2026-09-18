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

    def test_encrypt_and_verify_lock_pin_round_trip(self: Self) -> None:
        """
        Verify a correctly encrypted lock PIN can be verified successfully.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a valid PIN does not verify.
        """
        encoded_pin: str = encrypt_lock_pin("123456")

        self.assertTrue(verify_lock_pin("123456", encoded_pin))

    def test_verify_lock_pin_rejects_an_incorrect_pin(self: Self) -> None:
        """
        Verify an incorrect lock PIN does not pass verification.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an incorrect PIN is accepted.
        """
        encoded_pin: str = encrypt_lock_pin("123456")

        self.assertFalse(verify_lock_pin("654321", encoded_pin))

    def test_encrypt_lock_pin_uses_a_unique_salt(self: Self) -> None:
        """
        Verify repeated encryption does not produce identical verifiers.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a random salt is not used.
        """
        first_encoded_pin: str = encrypt_lock_pin("123456")
        second_encoded_pin: str = encrypt_lock_pin("123456")

        self.assertNotEqual(first_encoded_pin, second_encoded_pin)
