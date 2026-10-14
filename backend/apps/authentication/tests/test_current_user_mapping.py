from typing import Self
from uuid import UUID

from django.test import SimpleTestCase

from apps.authentication.models import User
from apps.authentication.schemas import CurrentUserResponse



class CurrentUserMappingTests(SimpleTestCase):
    def test_from_user_maps_only_public_account_data(self: Self) -> None:
        """
        Verify a user with protected credentials maps only to approved public fields.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when public data is incorrect or secrets are exposed.
        """
        user: User = User(
            id=UUID("550e8400-e29b-41d4-a716-446655440000"),
            first_name="Ada",
            last_name="Lovelace",
            email="ada@example.com",
            password="protected-password",
            pin_hash="protected-pin",
            pin_version=1,
            encrypted_kbkey=b"protected-kbkey",
            kbkey_nonce=b"nonce-value!",
            kbkey_encryption_version=1,
            token_version=3,
        )

        response: CurrentUserResponse = CurrentUserResponse.from_user(user)

        self.assertEqual(
            response.model_dump(mode="json"),
            {
                "user_id": str(user.id),
                "first_name": "Ada",
                "last_name": "Lovelace",
                "email": "ada@example.com",
            },
        )
        self.assertEqual(user.password, "protected-password")
        self.assertEqual(user.pin_hash, "protected-pin")
        self.assertEqual(user.token_version, 3)

    def test_from_user_uses_the_supplied_accounts_current_values(self: Self) -> None:
        """
        Verify each mapping reflects current account values without caching old data.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when changed account values are not reflected.
        """
        user: User = User(
            first_name="Ada",
            last_name="Lovelace",
            email="ada@example.com",
        )
        previous: CurrentUserResponse = CurrentUserResponse.from_user(user)
        user.first_name = "Grace"
        user.last_name = "Hopper"
        user.email = "grace@example.com"

        current: CurrentUserResponse = CurrentUserResponse.from_user(user)

        self.assertEqual(current.user_id, user.id)
        self.assertEqual(current.first_name, "Grace")
        self.assertEqual(current.last_name, "Hopper")
        self.assertEqual(current.email, "grace@example.com")
        self.assertEqual(previous.first_name, "Ada")
        self.assertEqual(previous.last_name, "Lovelace")
        self.assertEqual(previous.email, "ada@example.com")
