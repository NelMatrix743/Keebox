from datetime import UTC, datetime
from typing import Self
from uuid import UUID, uuid4

from django.test import SimpleTestCase
from pydantic import ValidationError

from apps.authentication.schemas import (
    RegistrationOTPResendRequest,
    RegistrationOTPResentResponse,
)
from apps.core.choices import RegistrationStatus
from apps.core.response import APIResponse, SuccessResponse



class RegistrationOTPResendSchemaTests(SimpleTestCase):
    def test_resend_request_accepts_a_registration_identifier(
        self: Self,
    ) -> None:
        """
        Verify a valid registration identifier is preserved by the request.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when valid resend data is rejected.
        """
        registration_id: UUID = uuid4()

        request: RegistrationOTPResendRequest = (
            RegistrationOTPResendRequest.model_validate(
                {"registration_id": registration_id},
            )
        )

        self.assertEqual(request.registration_id, registration_id)
