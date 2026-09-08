from datetime import datetime, timedelta
from typing import Self
from unittest.mock import patch
from uuid import UUID, uuid4

from django.apps import AppConfig, apps
from django.conf import settings
from django.contrib.auth.hashers import identify_hasher
from django.core.exceptions import FieldDoesNotExist
from django.db import IntegrityError, transaction
from django.test import SimpleTestCase, TestCase
from django.utils import timezone

from apps.authentication.exceptions import (
    ConsumedOTPError,
    ExpiredOTPError,
    InvalidOTPError,
    InvalidRegistrationStateError,
    LockedOTPError,
    OTPResendCooldownError,
    OTPResendLimitError,
    OTPServiceError,
)
from apps.authentication.models import OTPVerification, RegistrationChallenge, User
from apps.authentication.services import (
    generate_otp_code,
    issue_registration_otp,
    resend_registration_otp,
    verify_registration_otp,
)
from apps.core.choices import OTPStatus, RegistrationStatus
from apps.core.constants import (
    OTP_CODE_LENGTH,
    OTP_MAX_ATTEMPTS,
    OTP_MAX_RESENDS,
    OTP_RESEND_COOLDOWN,
    REGISTRATION_CHALLENGE_TTL,
)



class OTPCodeGenerationTests(SimpleTestCase):
    def test_generate_otp_code_returns_six_secure_numeric_characters(
        self: Self,
    ) -> None:
        """
        Verify OTP generation uses secure randomness and preserves leading zeroes.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when generated OTP formatting is invalid.
        """
        with patch(
            "apps.authentication.services.secrets.randbelow",
            return_value=42,
        ) as mocked_randbelow:
            otp_code: str = generate_otp_code()

        self.assertEqual(otp_code, "000042")
        self.assertEqual(len(otp_code), OTP_CODE_LENGTH)
        self.assertTrue(otp_code.isdigit())
        mocked_randbelow.assert_called_once_with(10**OTP_CODE_LENGTH)


class OTPIssuanceServiceTests(TestCase):
    def _create_registration_challenge(self: Self) -> RegistrationChallenge:
        """
        Create a persisted pending registration for OTP issuance tests.

        Args:
            self: Current test case instance.

        Returns:
            A persisted pending registration challenge.

        Raises:
            ValueError: Raised when the test credentials are invalid.
        """
        challenge: RegistrationChallenge = RegistrationChallenge(
            first_name="Nelson",
            last_name="Ubochiegbu",
            email="nelmatrix155@gmail.com",
        )
        challenge.set_password("correct horse battery staple")
        challenge.save()
        return challenge

    def test_issue_registration_otp_hashes_and_returns_the_raw_code(
        self: Self,
    ) -> None:
        """
        Verify initial OTP issuance persists only the protected code.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when OTP issuance stores incorrect data.
        """
        challenge: RegistrationChallenge = self._create_registration_challenge()

        with patch(
            "apps.authentication.services.generate_otp_code",
            return_value="012345",
        ):
            otp_verification, raw_code = issue_registration_otp(challenge.id)

        self.assertEqual(raw_code, "012345")
        self.assertNotEqual(otp_verification.code_hash, raw_code)
        self.assertTrue(otp_verification.verify_otp_code(raw_code))
        self.assertEqual(otp_verification.registration_challenge, challenge)
        self.assertEqual(otp_verification.email, challenge.email)
        self.assertEqual(otp_verification.status, OTPStatus.PENDING)
        self.assertEqual(OTPVerification.objects.count(), 1)

    def test_issue_registration_otp_expires_older_pending_records(
        self: Self,
    ) -> None:
        """
        Verify issuance preserves history while invalidating older pending OTPs.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an older pending OTP remains active.
        """
        challenge: RegistrationChallenge = self._create_registration_challenge()
        previous_otp: OTPVerification = OTPVerification(
            registration_challenge=challenge,
            email=challenge.email,
        )
        previous_otp.hash_and_set_otp_code("111111")
        previous_otp.save()

        with patch(
            "apps.authentication.services.generate_otp_code",
            return_value="222222",
        ):
            current_otp, raw_code = issue_registration_otp(challenge.id)

        previous_otp.refresh_from_db()
        self.assertEqual(previous_otp.status, OTPStatus.EXPIRED)
        self.assertEqual(current_otp.status, OTPStatus.PENDING)
        self.assertEqual(raw_code, "222222")
        self.assertEqual(challenge.otp_verifications.count(), 2)

    def test_issue_registration_otp_rejects_an_invalid_registration_state(
        self: Self,
    ) -> None:
        """
        Verify OTP issuance requires a pending registration challenge.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an invalid registration state is accepted.
        """
        challenge: RegistrationChallenge = self._create_registration_challenge()
        challenge.status = RegistrationStatus.OTP_VERIFIED
        challenge.save(update_fields=["status", "updated_at"])

        with self.assertRaises(InvalidRegistrationStateError):
            issue_registration_otp(challenge.id)

        self.assertFalse(OTPVerification.objects.exists())

    def test_issue_registration_otp_rejects_expired_or_missing_registration(
        self: Self,
    ) -> None:
        """
        Verify OTP issuance rejects expired and unknown registrations.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when unusable registration ownership is accepted.
        """
        challenge: RegistrationChallenge = self._create_registration_challenge()
        challenge.expires_at = timezone.now() - timedelta(microseconds=1)
        challenge.save(update_fields=["expires_at", "updated_at"])

        with self.assertRaises(InvalidRegistrationStateError):
            issue_registration_otp(challenge.id)

        with self.assertRaises(InvalidRegistrationStateError):
            issue_registration_otp(uuid4())

    def test_issue_registration_otp_rolls_back_previous_invalidation(
        self: Self,
    ) -> None:
        """
        Verify failed OTP creation restores the previously pending OTP.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when issuance changes are not atomic.
        """
        challenge: RegistrationChallenge = self._create_registration_challenge()
        previous_otp: OTPVerification = OTPVerification(
            registration_challenge=challenge,
            email=challenge.email,
        )
        previous_otp.hash_and_set_otp_code("111111")
        previous_otp.save()

        with (
            patch(
                "apps.authentication.services.generate_otp_code",
                return_value="222222",
            ),
            patch.object(
                OTPVerification,
                "save",
                side_effect=RuntimeError("simulated persistence failure"),
            ),
            self.assertRaises(RuntimeError),
        ):
            issue_registration_otp(challenge.id)

        previous_otp.refresh_from_db()
        self.assertEqual(previous_otp.status, OTPStatus.PENDING)
        self.assertEqual(challenge.otp_verifications.count(), 1)

class OTPResendServiceTests(TestCase):
    def _create_registration_with_otp(
        self: Self,
    ) -> tuple[RegistrationChallenge, OTPVerification]:
        """
        Create a pending registration with an OTP eligible for replacement.

        Args:
            self: Current test case instance.

        Returns:
            The persisted registration challenge and its current OTP.

        Raises:
            ValueError: Raised when the test credentials are invalid.
        """
        challenge: RegistrationChallenge = RegistrationChallenge(
            first_name="Nelson",
            last_name="Ubochiegbu",
            email="nelmatrix155@gmail.com",
        )
        challenge.set_password("correct horse battery staple")
        challenge.save()
        otp_verification: OTPVerification = OTPVerification(
            registration_challenge=challenge,
            email=challenge.email,
            last_sent_at=timezone.now() - OTP_RESEND_COOLDOWN,
        )
        otp_verification.hash_and_set_otp_code("111111")
        otp_verification.save()
        return challenge, otp_verification

    def test_resend_registration_otp_creates_a_replacement(self: Self) -> None:
        """
        Verify a resend expires the old OTP and creates a protected replacement.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when replacement OTP issuance is incorrect.
        """
        challenge, previous_otp = self._create_registration_with_otp()

        with patch(
            "apps.authentication.services.generate_otp_code",
            return_value="222222",
        ):
            replacement_otp, raw_code = resend_registration_otp(challenge.id)

        challenge.refresh_from_db()
        previous_otp.refresh_from_db()
        self.assertEqual(challenge.resend_count, 1)
        self.assertEqual(previous_otp.status, OTPStatus.EXPIRED)
        self.assertEqual(replacement_otp.status, OTPStatus.PENDING)
        self.assertTrue(replacement_otp.verify_otp_code(raw_code))
        self.assertEqual(raw_code, "222222")
        self.assertEqual(challenge.otp_verifications.count(), 2)

    def test_resend_registration_otp_enforces_the_cooldown(self: Self) -> None:
        """
        Verify a replacement cannot be issued before the cooldown elapses.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an early resend changes persisted state.
        """
        challenge, current_otp = self._create_registration_with_otp()
        current_otp.last_sent_at = timezone.now()
        current_otp.save(update_fields=["last_sent_at", "updated_at"])

        with self.assertRaises(OTPResendCooldownError):
            resend_registration_otp(challenge.id)

        challenge.refresh_from_db()
        current_otp.refresh_from_db()
        self.assertEqual(challenge.resend_count, 0)
        self.assertEqual(current_otp.status, OTPStatus.PENDING)
        self.assertEqual(challenge.otp_verifications.count(), 1)

    def test_resend_registration_otp_invalidates_challenge_at_limit(
        self: Self,
    ) -> None:
        """
        Verify exceeding the resend allowance cancels the registration workflow.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a resend-limit challenge remains active.
        """
        challenge, current_otp = self._create_registration_with_otp()
        challenge.resend_count = OTP_MAX_RESENDS
        challenge.save(update_fields=["resend_count", "updated_at"])

        with self.assertRaises(OTPResendLimitError):
            resend_registration_otp(challenge.id)

        challenge.refresh_from_db()
        current_otp.refresh_from_db()
        self.assertEqual(challenge.status, RegistrationStatus.CANCELLED)
        self.assertEqual(current_otp.status, OTPStatus.EXPIRED)
        self.assertEqual(challenge.otp_verifications.count(), 1)

    def test_resend_registration_otp_requires_an_active_registration_and_otp(
        self: Self,
    ) -> None:
        """
        Verify resending requires a pending registration with an issued OTP.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an invalid resend request is accepted.
        """
        challenge, current_otp = self._create_registration_with_otp()
        challenge.status = RegistrationStatus.OTP_VERIFIED
        challenge.save(update_fields=["status", "updated_at"])

        with self.assertRaises(InvalidRegistrationStateError):
            resend_registration_otp(challenge.id)

        empty_challenge: RegistrationChallenge = RegistrationChallenge(
            first_name="Keebox",
            last_name="User",
            email="new@example.com",
        )
        empty_challenge.set_password("correct horse battery staple")
        empty_challenge.save()

        with self.assertRaises(InvalidRegistrationStateError):
            resend_registration_otp(empty_challenge.id)

        with self.assertRaises(InvalidRegistrationStateError):
            resend_registration_otp(uuid4())

        current_otp.refresh_from_db()
        self.assertEqual(current_otp.status, OTPStatus.PENDING)


class OTPVerificationServiceTests(TestCase):
    def _create_registration_with_otp(
        self: Self,
    ) -> tuple[RegistrationChallenge, OTPVerification]:
        """
        Create a pending registration with one active OTP verification.

        Args:
            self: Current test case instance.

        Returns:
            The persisted registration challenge and active OTP verification.

        Raises:
            ValueError: Raised when the test credentials or OTP are invalid.
        """
        challenge: RegistrationChallenge = RegistrationChallenge(
            first_name="Nelson",
            last_name="Ubochiegbu",
            email="nelmatrix155@gmail.com",
        )
        challenge.set_password("correct horse battery staple")
        challenge.save()
        otp_verification: OTPVerification = OTPVerification(
            registration_challenge=challenge,
            email=challenge.email,
        )
        otp_verification.hash_and_set_otp_code("123456")
        otp_verification.save()
        return challenge, otp_verification

    def test_verify_registration_otp_consumes_a_valid_code(self: Self) -> None:
        """
        Verify a valid code consumes its OTP and verifies the registration.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when successful verification state is invalid.
        """
        challenge, otp_verification = self._create_registration_with_otp()

        verified_otp: OTPVerification = verify_registration_otp(
            challenge.id,
            "123456",
        )

        challenge.refresh_from_db()
        verified_otp.refresh_from_db()
        self.assertEqual(verified_otp, otp_verification)
        self.assertEqual(verified_otp.status, OTPStatus.CONSUMED)
        self.assertIsNotNone(verified_otp.consumed_at)
        self.assertEqual(verified_otp.attempt_count, 0)
        self.assertEqual(challenge.status, RegistrationStatus.OTP_VERIFIED)

    def test_verify_registration_otp_counts_an_invalid_code(self: Self) -> None:
        """
        Verify an incorrect code consumes one attempt without changing workflow state.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a failed attempt is not persisted correctly.
        """
        challenge, otp_verification = self._create_registration_with_otp()

        with self.assertRaises(InvalidOTPError):
            verify_registration_otp(challenge.id, "654321")

        challenge.refresh_from_db()
        otp_verification.refresh_from_db()
        self.assertEqual(otp_verification.attempt_count, 1)
        self.assertEqual(otp_verification.status, OTPStatus.PENDING)
        self.assertEqual(challenge.status, RegistrationStatus.OTP_PENDING)

    def test_verify_registration_otp_locks_the_final_failed_attempt(
        self: Self,
    ) -> None:
        """
        Verify the final permitted failed attempt locks the OTP verification.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the attempt limit does not lock the OTP.
        """
        challenge, otp_verification = self._create_registration_with_otp()
        otp_verification.attempt_count = OTP_MAX_ATTEMPTS - 1
        otp_verification.save(update_fields=["attempt_count", "updated_at"])

        with self.assertRaises(LockedOTPError):
            verify_registration_otp(challenge.id, "654321")

        otp_verification.refresh_from_db()
        self.assertEqual(otp_verification.attempt_count, OTP_MAX_ATTEMPTS)
        self.assertEqual(otp_verification.status, OTPStatus.LOCKED)

class OTPServiceExceptionTests(SimpleTestCase):
    def test_otp_service_exceptions_share_a_common_base(self: Self) -> None:
        """
        Verify every OTP service failure can be handled through one base type.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an exception has the wrong inheritance.
        """
        exception_types: tuple[type[OTPServiceError], ...] = (
            InvalidOTPError,
            ExpiredOTPError,
            ConsumedOTPError,
            LockedOTPError,
            OTPResendCooldownError,
            OTPResendLimitError,
            InvalidRegistrationStateError,
        )

        self.assertTrue(
            all(
                issubclass(exception_type, OTPServiceError)
                for exception_type in exception_types
            ),
        )


class UserModelTests(TestCase):

    def test_authentication_models_define_database_metadata(
        self: Self,
    ) -> None:
        """
        Verify authentication models define tables, ordering, and uniqueness.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when model metadata is configured incorrectly.
        """
        self.assertEqual(User._meta.db_table, "keebox_users")
        self.assertEqual(User._meta.ordering, ["-date_joined"])
        self.assertTrue(User._meta.get_field("email").unique)

        self.assertEqual(
            RegistrationChallenge._meta.db_table,
            "auth_registration_challenge",
        )
        self.assertEqual(RegistrationChallenge._meta.ordering, ["-created_at"])
        self.assertFalse(RegistrationChallenge._meta.get_field("email").unique)
        self.assertNotIn(
            "unique_registration_challenge_email",
            {
                constraint.name
                for constraint in RegistrationChallenge._meta.constraints
            },
        )

        self.assertEqual(
            OTPVerification._meta.db_table,
            "otp_verifications",
        )
        self.assertEqual(OTPVerification._meta.ordering, ["-created_at"])

    def test_authentication_app_and_user_model_are_configured(
        self: Self,
    ) -> None:
        """
        Verify Django uses the authentication app and its custom user model.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the authentication configuration is invalid.
        """
        app_config: AppConfig = apps.get_app_config("authentication")

        self.assertEqual(app_config.name, "apps.authentication")
        self.assertIn("apps.authentication", settings.INSTALLED_APPS)
        self.assertEqual(settings.AUTH_USER_MODEL, "authentication.User")

    def test_user_uses_email_as_its_login_identifier(
        self: Self,
    ) -> None:
        """
        Verify the custom user authenticates by a unique normalized email.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the email authentication contract is invalid.
        """
        self.assertEqual(User.USERNAME_FIELD, "email")
        self.assertEqual(User.REQUIRED_FIELDS, ["first_name", "last_name"])
        self.assertTrue(User._meta.get_field("email").unique)

        with self.assertRaises(FieldDoesNotExist):
            User._meta.get_field("username")

    def test_user_manager_normalizes_email_and_hashes_password(
        self: Self,
    ) -> None:
        """
        Verify user creation normalizes email and never stores a raw password.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when user creation handles credentials incorrectly.
        """
        user: User = User.objects.create_user(
            email="  Nelson@Example.COM  ",
            password="correct horse battery staple",
            first_name="Nelson",
            last_name="Matrix",
        )

        self.assertEqual(user.email, "nelson@example.com")
        self.assertNotEqual(user.password, "correct horse battery staple")
        self.assertTrue(user.check_password("correct horse battery staple"))

    def test_user_manager_validates_required_credentials(self: Self) -> None:
        """
        Verify the user manager rejects missing account credentials.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when incomplete credentials are accepted.
        """
        with self.assertRaisesMessage(ValueError, "email address is required"):
            User.objects.create_user(email="", password="valid-password")

        with self.assertRaisesMessage(ValueError, "password is required"):
            User.objects.create_user(email="nelson@example.com", password="")

    def test_user_manager_creates_privileged_superuser(self: Self) -> None:
        """
        Verify superuser creation applies and validates administrative flags.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when superuser privileges are configured incorrectly.
        """
        user: User = User.objects.create_superuser(
            email="admin@example.com",
            password="valid-password",
            first_name="Keebox",
            last_name="Admin",
        )

        self.assertTrue(user.is_staff)
        self.assertTrue(user.is_superuser)

        with self.assertRaisesMessage(ValueError, "is_staff=True"):
            User.objects.create_superuser(
                email="invalid@example.com",
                password="valid-password",
                is_staff=False,
            )

    def test_user_has_keebox_security_fields(self: Self) -> None:
        """
        Verify every user can store the server PIN and protected KBKey metadata.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a required Keebox security field is missing.
        """
        user = User(
            email="nelson@example.com",
            first_name="Nelson",
            last_name="Matrix",
            pin_hash="encoded-pin-hash",
            encrypted_kbkey=b"encrypted-kbkey",
            kbkey_nonce=b"twelve-bytes",
        )

        self.assertIsInstance(user.id, UUID)
        self.assertEqual(user.pin_hash, "encoded-pin-hash")
        self.assertEqual(user.pin_version, 0)
        self.assertEqual(user.encrypted_kbkey, b"encrypted-kbkey")
        self.assertEqual(user.kbkey_nonce, b"twelve-bytes")
        self.assertEqual(user.kbkey_encryption_version, 1)


class RegistrationChallengeModelTests(TestCase):
    def test_registration_challenge_allows_repeated_email_attempts(
        self: Self,
    ) -> None:
        """
        Verify one email address can own multiple registration attempts.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when repeated registration attempts are rejected.
        """
        for attempt_number in range(2):
            challenge: RegistrationChallenge = RegistrationChallenge(
                first_name="Nelson",
                last_name="Ubochiegbu",
                email="Nelmatrix155@gmail.com",
            )
            challenge.set_password(f"valid-password-{attempt_number}")
            challenge.save()

        self.assertEqual(
            RegistrationChallenge.objects.filter(
                email="nelmatrix155@gmail.com",
            ).count(),
            2,
        )

    def test_registration_challenge_stores_protected_registration_data(
        self: Self,
    ) -> None:
        """
        Verify a pending registration normalizes and protects its credentials.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when registration data is stored incorrectly.
        """
        challenge: RegistrationChallenge = RegistrationChallenge(
            first_name="Nelson",
            last_name="Ubochiegbu",
            email="  Nelmatrix155@gmail.COM  ",
        )
        challenge.set_password("correct horse battery staple")
        challenge.save()

        self.assertIsInstance(challenge.id, UUID)
        self.assertEqual(challenge.email, "nelmatrix155@gmail.com")
        self.assertNotEqual(challenge.password_hash, "correct horse battery staple")
        identify_hasher(challenge.password_hash)
        self.assertTrue(challenge.check_password("correct horse battery staple"))
        self.assertFalse(challenge.check_password("incorrect password"))

    def test_registration_challenge_rejects_missing_credentials(
        self: Self,
    ) -> None:
        """
        Verify a pending registration rejects missing email and password values.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when incomplete credentials are accepted.
        """
        challenge: RegistrationChallenge = RegistrationChallenge(
            first_name="Nelson",
            last_name="Ubochiegbu",
            email="",
        )

        with self.assertRaisesMessage(ValueError, "email address is required"):
            challenge.save()

        with self.assertRaisesMessage(ValueError, "password is required"):
            challenge.set_password("")

    def test_registration_challenge_starts_pending_and_expires_from_constant(
        self: Self,
    ) -> None:
        """
        Verify a new registration has the initial state and fixed lifetime.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when registration defaults are invalid.
        """
        creation_started: datetime = timezone.now()
        challenge: RegistrationChallenge = RegistrationChallenge(
            first_name="Nelson",
            last_name="Ubochiegbu",
            email="nelmatrix155@gmail.com",
        )

        self.assertEqual(challenge.status, RegistrationStatus.OTP_PENDING)
        self.assertEqual(challenge.resend_count, 0)
        self.assertIsNone(challenge.completed_at)
        self.assertAlmostEqual(
            challenge.expires_at,
            creation_started + REGISTRATION_CHALLENGE_TTL,
            delta=timedelta(seconds=1),
        )


class OTPVerificationModelTests(TestCase):
    def _create_registration_challenge(self: Self) -> RegistrationChallenge:
        """
        Create a persisted registration challenge for OTP model tests.

        Args:
            self: Current test case instance.

        Returns:
            A persisted registration challenge with protected credentials.

        Raises:
            ValueError: Raised when the test credentials are invalid.
        """
        challenge: RegistrationChallenge = RegistrationChallenge(
            first_name="Nelson",
            last_name="Ubochiegbu",
            email="nelmatrix155@gmail.com",
        )
        challenge.set_password("correct horse battery staple")
        challenge.save()
        return challenge

    def test_otp_verification_hashes_and_checks_codes(self: Self) -> None:
        """
        Verify OTP codes are hashed and can be checked without raw persistence.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when OTP code protection behaves incorrectly.
        """
        otp_verification: OTPVerification = OTPVerification(
            email="nelmatrix155@gmail.com",
        )

        otp_verification.hash_and_set_otp_code("123456")

        self.assertNotEqual(otp_verification.code_hash, "123456")
        identify_hasher(otp_verification.code_hash)
        self.assertTrue(otp_verification.verify_otp_code("123456"))
        self.assertFalse(otp_verification.verify_otp_code("654321"))

        with self.assertRaisesMessage(ValueError, "OTP code is required"):
            otp_verification.hash_and_set_otp_code("")

    def test_otp_verification_reports_expiration_and_consumption(
        self: Self,
    ) -> None:
        """
        Verify OTP expiration and consumption state checks.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when OTP state is evaluated incorrectly.
        """
        current_time: datetime = timezone.now()
        otp_verification: OTPVerification = OTPVerification(
            email="nelmatrix155@gmail.com",
            expires_at=current_time,
        )

        with patch(
            "apps.authentication.models.timezone.now",
            return_value=current_time,
        ):
            self.assertTrue(otp_verification.is_expired())

            otp_verification.expires_at = current_time + timedelta(microseconds=1)
            self.assertFalse(otp_verification.is_expired())

        self.assertFalse(otp_verification.is_consumed())
        otp_verification.status = OTPStatus.CONSUMED
        self.assertTrue(otp_verification.is_consumed())

        otp_verification.status = OTPStatus.PENDING
        otp_verification.consumed_at = current_time
        self.assertTrue(otp_verification.is_consumed())

    def test_otp_verification_allows_only_active_attempts(self: Self) -> None:
        """
        Verify attempts require pending, unexpired, below-limit OTP state.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an unusable OTP permits verification.
        """
        current_time: datetime = timezone.now()
        otp_verification: OTPVerification = OTPVerification(
            email="nelmatrix155@gmail.com",
            expires_at=current_time + timedelta(minutes=1),
        )

        with patch(
            "apps.authentication.models.timezone.now",
            return_value=current_time,
        ):
            self.assertTrue(otp_verification.can_attempt_verification())

            otp_verification.attempt_count = OTP_MAX_ATTEMPTS
            self.assertFalse(otp_verification.can_attempt_verification())

            otp_verification.attempt_count = 0
            otp_verification.status = OTPStatus.CONSUMED
            self.assertFalse(otp_verification.can_attempt_verification())

            otp_verification.status = OTPStatus.PENDING
            otp_verification.expires_at = current_time
            self.assertFalse(otp_verification.can_attempt_verification())

    def test_otp_verification_rejects_attempt_count_above_limit(
        self: Self,
    ) -> None:
        """
        Verify the database rejects OTP attempt counts above the limit.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an excessive attempt count is accepted.
        """
        challenge: RegistrationChallenge = self._create_registration_challenge()

        with self.assertRaises(IntegrityError), transaction.atomic():
            OTPVerification.objects.create(
                registration_challenge=challenge,
                email=challenge.email,
                code_hash="encoded-code-hash",
                attempt_count=OTP_MAX_ATTEMPTS + 1,
            )

    def test_registration_challenge_rejects_resend_count_above_limit(
        self: Self,
    ) -> None:
        """
        Verify the database rejects registration resend counts above the limit.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an excessive resend count is accepted.
        """
        challenge: RegistrationChallenge = self._create_registration_challenge()

        with self.assertRaises(IntegrityError), transaction.atomic():
            challenge.resend_count = OTP_MAX_RESENDS + 1
            challenge.save(update_fields=["resend_count"])

    def test_otp_verification_does_not_own_registration_resend_count(
        self: Self,
    ) -> None:
        """
        Verify individual OTP records do not track registration resends.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the OTP model owns a resend counter.
        """
        with self.assertRaises(FieldDoesNotExist):
            OTPVerification._meta.get_field("resend_count")

    def test_otp_verification_requires_consumed_state_consistency(
        self: Self,
    ) -> None:
        """
        Verify consumed status and timestamp must always agree.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an inconsistent consumed state is accepted.
        """
        challenge: RegistrationChallenge = self._create_registration_challenge()

        with self.assertRaises(IntegrityError), transaction.atomic():
            OTPVerification.objects.create(
                registration_challenge=challenge,
                email=challenge.email,
                code_hash="encoded-code-hash",
                status=OTPStatus.CONSUMED,
            )

        with self.assertRaises(IntegrityError), transaction.atomic():
            OTPVerification.objects.create(
                registration_challenge=challenge,
                email=challenge.email,
                code_hash="encoded-code-hash",
                consumed_at=timezone.now(),
            )

    def test_registration_challenge_owns_multiple_otp_verifications(
        self: Self,
    ) -> None:
        """
        Verify a registration challenge owns multiple cascading OTP records.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when OTP ownership is configured incorrectly.
        """
        challenge: RegistrationChallenge = RegistrationChallenge(
            first_name="Nelson",
            last_name="Ubochiegbu",
            email="nelmatrix155@gmail.com",
        )
        challenge.set_password("correct horse battery staple")
        challenge.save()

        first_otp: OTPVerification = OTPVerification.objects.create(
            registration_challenge=challenge,
            email=challenge.email,
            code_hash="first-code-hash",
        )
        second_otp: OTPVerification = OTPVerification.objects.create(
            registration_challenge=challenge,
            email=challenge.email,
            code_hash="second-code-hash",
        )

        self.assertIsInstance(first_otp.id, UUID)
        self.assertEqual(first_otp.registration_challenge_id, challenge.id)
        self.assertEqual(second_otp.registration_challenge_id, challenge.id)
        self.assertEqual(challenge.otp_verifications.count(), 2)

        challenge.delete()

        self.assertFalse(OTPVerification.objects.exists())
