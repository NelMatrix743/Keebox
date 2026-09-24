from typing import Self
from unittest.mock import Mock

from django.test import SimpleTestCase, override_settings

from apps.core.email import EmailDeliveryService



@override_settings(
    BREVO_API_KEY="test-key",
    BREVO_SENDER_EMAIL="sender@example.com",
    BREVO_SENDER_NAME="Keebox",
    BREVO_OTP_TEMPLATE_ID=123,
)
class EmailDeliveryTests(SimpleTestCase):
    def test_reset_otp_delivery_uses_its_reset_tag(self: Self) -> None:
        """
        Verify reset OTP emails are tagged for their recovery workflow.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the Brevo request has the wrong tag.
        """
        client: Mock = Mock()
        client.transactional_emails.send_transac_email.return_value.message_id = (
            "brevo-message-id"
        )

        message_id: str = EmailDeliveryService(client=client).send_otp_email(
            recipient_email="ada@example.com",
            recipient_full_name="Ada Lovelace",
            otp_code="048291",
            expiration_minutes=5,
            tag="password-reset-otp",
        )

        self.assertEqual(message_id, "brevo-message-id")
        request = client.transactional_emails.send_transac_email.call_args.kwargs
        self.assertEqual(request["tags"], ["password-reset-otp"])
