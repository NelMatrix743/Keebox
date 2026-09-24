from typing import Self

from brevo import Brevo
from brevo.core.api_error import ApiError
from brevo.transactional_emails import (
    SendTransacEmailRequestSender,
    SendTransacEmailRequestToItem,
    SendTransacEmailResponse,
)
from django.conf import settings

from apps.core.exceptions import EmailDeliveryError



class EmailDeliveryService:
    """Deliver Keebox transactional emails through Brevo."""

    def __init__(self: Self, client: Brevo | None = None) -> None:
        """
        Initialize the email delivery service with a Brevo client.

        Args:
            self: Current email delivery service instance.
            client: Optional preconfigured Brevo client.

        Returns:
            None: This method does not return a value.

        Raises:
            EmailDeliveryError: Raised when the Brevo API key is not configured.
        """
        if client is None and not settings.BREVO_API_KEY:
            raise EmailDeliveryError("The Brevo API key is not configured.")

        self._client: Brevo = client or Brevo(
            api_key=settings.BREVO_API_KEY,
            timeout=settings.BREVO_REQUEST_TIMEOUT_SECONDS,
        )

    def send_otp_email(
        self: Self,
        recipient_email: str,
        recipient_full_name: str,
        otp_code: str,
        expiration_minutes: int,
        tag: str = "registration-otp",
    ) -> str:
        """
        Submit an OTP email to Brevo using the configured template.

        Args:
            self: Current email delivery service instance.
            recipient_email: Email address that will receive the OTP.
            recipient_full_name: Full name displayed for the recipient.
            otp_code: One-time password included in the email template.
            expiration_minutes: Number of minutes before the OTP expires.
            tag: Brevo tag identifying the OTP delivery workflow.

        Returns:
            Brevo message identifier assigned to the submitted email.

        Raises:
            EmailDeliveryError: Raised when configuration or delivery fails.
        """
        template_id: int | None = settings.BREVO_OTP_TEMPLATE_ID
        if not settings.BREVO_SENDER_EMAIL:
            raise EmailDeliveryError("The Brevo sender email is not configured.")
        if template_id is None:
            raise EmailDeliveryError("The Brevo OTP template ID is not configured.")

        try:
            response: SendTransacEmailResponse = (
                self._client.transactional_emails.send_transac_email(
                    sender=SendTransacEmailRequestSender(
                        email=settings.BREVO_SENDER_EMAIL,
                        name=settings.BREVO_SENDER_NAME,
                    ),
                    to=[
                        SendTransacEmailRequestToItem(
                            email=recipient_email,
                            name=recipient_full_name,
                        ),
                    ],
                    template_id=template_id,
                    params={
                        "full_name": recipient_full_name,
                        "otp_code": otp_code,
                        "expiration_minutes": expiration_minutes,
                    },
                    tags=[tag],
                )
            )
        except ApiError as exception:
            raise EmailDeliveryError(
                "Brevo could not submit the OTP email for delivery.",
            ) from exception

        if response.message_id is None:
            raise EmailDeliveryError(
                "Brevo did not return a message ID for the OTP email.",
            )
        return response.message_id
