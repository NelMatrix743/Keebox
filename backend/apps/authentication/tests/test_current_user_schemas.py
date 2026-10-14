from typing import Self
from uuid import UUID

from django.test import SimpleTestCase
from pydantic import ValidationError

from apps.authentication.schemas import CurrentUserResponse
from apps.core.response import APIResponse, SuccessResponse



class CurrentUserSchemaTests(SimpleTestCase):
    def test_current_user_serializes_through_the_success_envelope(self: Self) -> None:
        """
        Verify the current-user response serializes the four approved account fields.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the serialized account data is incorrect.
        """
        user_id: UUID = UUID("550e8400-e29b-41d4-a716-446655440000")
        data: CurrentUserResponse = CurrentUserResponse(
            user_id=user_id,
            first_name="Ada",
            last_name="Lovelace",
            email="ada@example.com",
        )
        response: SuccessResponse[CurrentUserResponse] = (
            SuccessResponse[CurrentUserResponse].model_validate(
                APIResponse.success(data.model_dump()),
            )
        )

        self.assertEqual(data.user_id, user_id)
        self.assertEqual(
            response.model_dump(mode="json"),
            {
                "success": True,
                "data": {
                    "user_id": str(user_id),
                    "first_name": "Ada",
                    "last_name": "Lovelace",
                    "email": "ada@example.com",
                },
                "error": None,
                "meta": None,
            },
        )

    def test_current_user_requires_all_account_fields(self: Self) -> None:
        """
        Verify incomplete account data cannot produce a current-user response.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a required account field is missing.
        """
        payload: dict[str, object] = {
            "user_id": "550e8400-e29b-41d4-a716-446655440000",
            "first_name": "Ada",
            "last_name": "Lovelace",
            "email": "ada@example.com",
        }
        for field in payload:
            incomplete: dict[str, object] = dict(payload)
            del incomplete[field]
            with self.subTest(field=field), self.assertRaises(ValidationError):
                CurrentUserResponse.model_validate(incomplete)

    def test_current_user_rejects_invalid_account_values(self: Self) -> None:
        """
        Verify identifiers, names, and email addresses meet their declared types.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when malformed account data is accepted.
        """
        payload: dict[str, object] = {
            "user_id": "550e8400-e29b-41d4-a716-446655440000",
            "first_name": "Ada",
            "last_name": "Lovelace",
            "email": "ada@example.com",
        }
        invalid_values: tuple[tuple[str, object], ...] = (
            ("user_id", "not-a-uuid"),
            ("user_id", None),
            ("first_name", 123),
            ("first_name", None),
            ("last_name", True),
            ("last_name", None),
            ("email", "not-an-email"),
            ("email", None),
        )
        for field, value in invalid_values:
            with (
                self.subTest(field=field, value=value),
                self.assertRaises(ValidationError),
            ):
                CurrentUserResponse.model_validate({**payload, field: value})
