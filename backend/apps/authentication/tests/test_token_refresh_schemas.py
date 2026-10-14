from typing import Self

from django.test import SimpleTestCase
from pydantic import ValidationError

from apps.authentication.schemas import TokenRefreshRequest, TokenRefreshResponse
from apps.core.response import APIResponse, SuccessResponse



class TokenRefreshSchemaTests(SimpleTestCase):
    def test_refresh_request_preserves_the_submitted_token(self: Self) -> None:
        """
        Verify the request passes the submitted refresh token to the service intact.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the refresh token is changed or rejected.
        """
        request: TokenRefreshRequest = TokenRefreshRequest.model_validate(
            {"refresh_token": "header.payload.signature"},
        )

        self.assertEqual(request.refresh_token, "header.payload.signature")

    def test_refresh_request_rejects_missing_empty_or_nonstring_tokens(
        self: Self,
    ) -> None:
        """
        Verify malformed refresh input is rejected before token validation.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when malformed refresh input is accepted.
        """
        invalid_payloads: tuple[dict[str, object], ...] = (
            {},
            {"refresh_token": ""},
            {"refresh_token": None},
            {"refresh_token": 123},
            {"refresh_token": True},
            {"refresh_token": []},
            {"refresh_token": {}},
            {"refresh_token": "token", "unexpected": "value"},
        )

        for payload in invalid_payloads:
            with self.subTest(payload=payload), self.assertRaises(ValidationError):
                TokenRefreshRequest.model_validate(payload)

    def test_refresh_response_serializes_only_the_new_access_token(
        self: Self,
    ) -> None:
        """
        Verify the refresh result serializes through the standard success envelope.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the refresh result has an invalid envelope.
        """
        data: TokenRefreshResponse = TokenRefreshResponse(access_token="new-access-token")
        response: SuccessResponse[TokenRefreshResponse] = (
            SuccessResponse[TokenRefreshResponse].model_validate(
                APIResponse.success(data.model_dump()),
            )
        )

        self.assertEqual(
            response.model_dump(mode="json"),
            {
                "success": True,
                "data": {"access_token": "new-access-token"},
                "error": None,
                "meta": None,
            },
        )

    def test_refresh_response_rejects_invalid_data(self: Self) -> None:
        """
        Verify the refresh response requires a nonempty access token without extras.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when invalid response data is accepted.
        """
        invalid_payloads: tuple[dict[str, object], ...] = (
            {},
            {"access_token": ""},
            {"access_token": None},
            {"access_token": 123},
            {"access_token": "token", "refresh_token": "unexpected-rotation"},
        )

        for payload in invalid_payloads:
            with self.subTest(payload=payload), self.assertRaises(ValidationError):
                TokenRefreshResponse.model_validate(payload)
