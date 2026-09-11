from datetime import timedelta
from importlib import reload
from typing import Self, cast
from types import ModuleType
from unittest.mock import Mock, patch

from brevo import Brevo
from brevo.core.api_error import ApiError
from brevo.transactional_emails import (
    SendTransacEmailRequestSender,
    SendTransacEmailRequestToItem,
    SendTransacEmailResponse,
)
from django.test import SimpleTestCase, override_settings

from apps.core.choices import OTPStatus, RegistrationStatus
from apps.core.constants import (
    OTP_CODE_LENGTH,
    OTP_MAX_ATTEMPTS,
    OTP_MAX_RESENDS,
    OTP_RESEND_COOLDOWN,
    OTP_TTL,
    REGISTRATION_CHALLENGE_TTL,
)
from apps.core.email import EmailDeliveryService
from apps.core.exceptions import EmailDeliveryError
from apps.core.response import APIResponse
from config import settings as project_settings



class RegistrationStatusTests(SimpleTestCase):
    def test_registration_status_defines_the_registration_lifecycle(
        self: Self,
    ) -> None:
        """
        Verify registration statuses expose the required stored values and labels.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the registration status contract changes.
        """
        self.assertEqual(
            RegistrationStatus.choices,
            [
                ("otp_pending", "OTP pending"),
                ("otp_verified", "OTP verified"),
                ("completed", "Completed"),
                ("expired", "Expired"),
                ("cancelled", "Cancelled"),
            ],
        )


class OTPStatusTests(SimpleTestCase):
    def test_otp_status_defines_the_verification_lifecycle(
        self: Self,
    ) -> None:
        """
        Verify OTP statuses expose the required stored values and labels.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the OTP status contract changes.
        """
        self.assertEqual(
            OTPStatus.choices,
            [
                ("pending", "Pending"),
                ("consumed", "Consumed"),
                ("expired", "Expired"),
                ("locked", "Locked"),
            ],
        )


class AuthenticationConstantTests(SimpleTestCase):
    def test_registration_challenge_ttl_is_thirty_minutes(
        self: Self,
    ) -> None:
        """
        Verify pending registrations expire after exactly thirty minutes.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the registration lifetime changes.
        """
        self.assertEqual(REGISTRATION_CHALLENGE_TTL, timedelta(minutes=30))

    def test_otp_policy_constants_define_verification_limits(
        self: Self,
    ) -> None:
        """
        Verify the OTP lifetime, cooldown, attempt, and resend limits.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an OTP policy constant changes.
        """
        self.assertIsInstance(OTP_CODE_LENGTH, int)
        self.assertEqual(OTP_CODE_LENGTH, 6)
        self.assertEqual(OTP_TTL, timedelta(minutes=5))
        self.assertEqual(OTP_RESEND_COOLDOWN, timedelta(seconds=60))
        self.assertEqual(OTP_MAX_ATTEMPTS, 5)
        self.assertEqual(OTP_MAX_RESENDS, 3)


class APIResponseTests(SimpleTestCase):
    def test_success_returns_data_without_an_error(self: Self) -> None:
        """
        Verify a successful response preserves its dynamic response data.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the success envelope is incorrect.
        """
        response_data: dict[str, object] = {
            "registration_id": "a9d6f654-11e5-4b52-9006-d86c1f15fdb2",
            "status": "otp_pending",
        }
        response_meta: dict[str, str] = {
            "request_id": "abc-123",
        }

        response: dict[str, object] = APIResponse.success(
            response_data,
            response_meta,
        )

        self.assertEqual(
            response,
            {
                "success": True,
                "data": response_data,
                "error": None,
                "meta": response_meta,
            },
        )

    def test_error_returns_error_details_without_data(self: Self) -> None:
        """
        Verify an error response preserves its dynamic error details.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the error envelope is incorrect.
        """
        error_details: dict[str, str] = {
            "code": "registration_email_conflict",
            "detail": "An account already uses this email address.",
        }
        response_meta: dict[str, str] = {
            "request_id": "abc-123",
        }

        response: dict[str, object] = APIResponse.error(
            error_details,
            response_meta,
        )

        self.assertEqual(
            response,
            {
                "success": False,
                "data": None,
                "error": error_details,
                "meta": response_meta,
            },
        )


class BrevoSettingsTests(SimpleTestCase):
    def test_brevo_settings_load_typed_environment_values(self: Self) -> None:
        """
        Verify Brevo environment values are exposed with their expected types.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a Brevo setting is missing or mistyped.
        """
        environment_values: dict[str, str] = {
            "BREVO_API_KEY": "xkeysib-test",
            "BREVO_SENDER_EMAIL": "no-reply@keebox.dev",
            "BREVO_SENDER_NAME": "Keebox",
            "BREVO_REQUEST_TIMEOUT_SECONDS": "7.5",
            "BREVO_OTP_TEMPLATE_ID": "123",
        }

        with patch.dict("os.environ", environment_values):
            settings_module: ModuleType = reload(project_settings)

            self.assertEqual(settings_module.BREVO_API_KEY, "xkeysib-test")
            self.assertEqual(
                settings_module.BREVO_SENDER_EMAIL,
                "no-reply@keebox.dev",
            )
            self.assertEqual(settings_module.BREVO_SENDER_NAME, "Keebox")
            self.assertEqual(settings_module.BREVO_REQUEST_TIMEOUT_SECONDS, 7.5)
            self.assertEqual(settings_module.BREVO_OTP_TEMPLATE_ID, 123)

        reload(project_settings)


@override_settings(
    BREVO_API_KEY="xkeysib-test",
    BREVO_SENDER_EMAIL="no-reply@keebox.dev",
    BREVO_SENDER_NAME="Keebox",
    BREVO_REQUEST_TIMEOUT_SECONDS=10.0,
    BREVO_OTP_TEMPLATE_ID=123,
)
class EmailDeliveryServiceTests(SimpleTestCase):
    @patch("apps.core.email.Brevo")
    def test_service_configures_the_brevo_client(self: Self, brevo: Mock) -> None:
        """
        Verify the delivery service configures Brevo from Django settings.

        Args:
            self: Current test case instance.
            brevo: Mocked Brevo client class.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when Brevo receives incorrect configuration.
        """
        EmailDeliveryService()

        brevo.assert_called_once_with(
            api_key="xkeysib-test",
            timeout=10.0,
        )

    def test_send_otp_email_delivers_the_complete_template_payload(
        self: Self,
    ) -> None:
        """
        Verify OTP delivery includes recipient identity and verification data.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the Brevo payload is incomplete.
        """
        client: Mock = Mock()
        client.transactional_emails.send_transac_email.return_value = (
            SendTransacEmailResponse(message_id="brevo-message-id")
        )
        service: EmailDeliveryService = EmailDeliveryService(
            client=cast(Brevo, client),
        )

        message_id: str = service.send_otp_email(
            recipient_email="nelson@example.com",
            recipient_full_name="Nelson Ubochiegbu",
            otp_code="482913",
            expiration_minutes=5,
        )

        self.assertEqual(message_id, "brevo-message-id")
        call_arguments: dict[str, object] = (
            client.transactional_emails.send_transac_email.call_args.kwargs
        )
        sender: SendTransacEmailRequestSender = cast(
            SendTransacEmailRequestSender,
            call_arguments["sender"],
        )
        recipients: list[SendTransacEmailRequestToItem] = cast(
            list[SendTransacEmailRequestToItem],
            call_arguments["to"],
        )
        self.assertEqual(call_arguments["template_id"], 123)
        self.assertEqual(
            call_arguments["params"],
            {
                "full_name": "Nelson Ubochiegbu",
                "otp_code": "482913",
                "expiration_minutes": 5,
            },
        )
        self.assertEqual(call_arguments["tags"], ["registration-otp"])
        self.assertEqual(sender.email, "no-reply@keebox.dev")
        self.assertEqual(sender.name, "Keebox")
        self.assertEqual(recipients[0].email, "nelson@example.com")
        self.assertEqual(
            recipients[0].name,
            "Nelson Ubochiegbu",
        )

    def test_send_otp_email_translates_brevo_errors(self: Self) -> None:
        """
        Verify provider failures are translated into a Keebox delivery error.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a provider failure escapes untranslated.
        """
        client: Mock = Mock()
        client.transactional_emails.send_transac_email.side_effect = ApiError(
            status_code=500,
            body={"message": "Provider unavailable"},
        )
        service: EmailDeliveryService = EmailDeliveryService(
            client=cast(Brevo, client),
        )

        with self.assertRaises(EmailDeliveryError):
            service.send_otp_email(
                recipient_email="nelson@example.com",
                recipient_full_name="Nelson Ubochiegbu",
                otp_code="482913",
                expiration_minutes=5,
            )
