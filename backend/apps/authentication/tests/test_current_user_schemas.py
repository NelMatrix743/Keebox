from typing import Self
from uuid import UUID

from django.test import SimpleTestCase

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
