from typing import Self
from uuid import uuid4

from django.test import SimpleTestCase
from ninja import Schema
from pydantic import ValidationError

from apps.authentication.schemas import (
    LoginPINVerificationRequest,
    PINResetCompletionRequest,
    RegistrationCompletionRequest,
)



class PINRequestSchemaTests(SimpleTestCase):
    def test_pin_requests_require_exactly_five_ascii_digits(self: Self) -> None:
        """
        Verify registration, login, and reset enforce the same five-digit PIN policy.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a request accepts an invalid PIN.
        """
        contracts: tuple[tuple[type[Schema], str, str], ...] = (
            (RegistrationCompletionRequest, "registration_id", "pin"),
            (LoginPINVerificationRequest, "login_challenge_id", "pin"),
            (PINResetCompletionRequest, "reset_id", "new_pin"),
        )
        invalid_pins: tuple[object, ...] = (
            "",
            "1234",
            "123456",
            "abcde",
            "12a45",
            "１２３４５",
            "١٢٣٤٥",
            " 12345",
            "12345 ",
            "12345\n",
            "12 45",
            12345,
            None,
        )

        for schema, identifier_field, pin_field in contracts:
            payload: dict[str, object] = {identifier_field: uuid4()}
            for pin in ("00123", "00000", "12345"):
                with self.subTest(schema=schema.__name__, pin=pin):
                    request: Schema = schema.model_validate({**payload, pin_field: pin})
                    self.assertEqual(getattr(request, pin_field), pin)
            for pin in invalid_pins:
                with (
                    self.subTest(schema=schema.__name__, pin=pin),
                    self.assertRaises(ValidationError),
                ):
                    schema.model_validate({**payload, pin_field: pin})
