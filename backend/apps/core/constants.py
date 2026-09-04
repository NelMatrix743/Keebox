from datetime import timedelta



REGISTRATION_CHALLENGE_TTL: timedelta = timedelta(minutes=30)

OTP_TTL: timedelta = timedelta(minutes=5)
OTP_RESEND_COOLDOWN: timedelta = timedelta(seconds=60)
OTP_MAX_ATTEMPTS: int = 5
OTP_MAX_RESENDS: int = 3
