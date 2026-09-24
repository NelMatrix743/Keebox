from typing import Final



class Routes:
	"""Define route paths exposed by the authentication application."""

	class Registration:
		"""Define registration-related route paths."""

		BASE: Final[str] = "/register"

		VERIFY_OTP: Final[str] = BASE + "/verify-otp"
		RESEND_OTP: Final[str] = BASE + "/resend-otp"
		CREATE_PIN: Final[str] = BASE + "/create-pin"

	
	class Login:
		"""Define login-related route paths."""

		BASE: Final[str] = "/login"

		VERIFY_PIN: Final[str] = BASE + "/verify-pin"


	class Reset:
		"""Define account-reset route paths."""

		BASE: Final[str] = "/reset"

		VERIFY_OTP: Final[str] = BASE + "/verify-otp"
		RESEND_OTP: Final[str] = BASE + "/resend-otp"

		PASSWORD: Final[str] = BASE + "/password"
		PIN: Final[str] = BASE + "/pin"

		PASSWORD_COMPLETE: Final[str] = PASSWORD + "/complete"
		PIN_COMPLETE: Final[str]  = PIN + "/complete"


	class UpdatePin:
		"""Define lock-PIN update route paths."""

		BASE: Final[str] = "/update-pin"

		VERIFY_OTP: Final[str] = BASE + "/verify-otp"
		RESEND_OTP: Final[str] = BASE + "/resend-otp"
		SET_NEW_PIN: Final[str] = BASE + "/set-new-pin"
