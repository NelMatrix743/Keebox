from typing import Final



class Routes:
	"""Authentication-related route definitions"""

	class Registration:
		"""Registration-related routes."""

		BASE: Final[str] = "/register"

		VERIFY_OTP: Final[str] = BASE + "/verify-otp"
		RESEND_OTP: Final[str] = BASE + "/resend-otp"
		CREATE_PIN: Final[str] = BASE + "/create-pin"

	
	class Login:
		"""Login-related routes"""

		BASE: Final[str] = "/login"

		VERIFY_PIN: Final[str] = BASE + "/verify-pin"


	class Reset:
		"""Account reset routes"""

		BASE: Final[str] = "/reset"

		PASSWORD: Final[str] = BASE + "/password"
		PIN: Final[str] = BASE + "/pin"

		VERIFY_OTP: Final[str] = BASE + "/verify-otp"


	class UpdatePin:
		"""PIN update routes"""

		BASE: Final[str] = "/update-pin"

		VERIFY_OTP: Final[str] = BASE + "/verify-otp"
		RESEND_OTP: Final[str] = BASE + "/resend-otp"
		SET_NEW_PIN: Final[str] = BASE + "/set-new-pin"
