# Verify Reset OTP

`POST {{base_url}}/api/auth/reset/verify-otp`

Use the `reset_id` from a password or lock-PIN reset and the current six-digit
code from the email. A successful request consumes the OTP, changes the reset
status to `otp_verified`, and returns `completion_expires_at`. Finish the
matching credential completion request before that ten-minute deadline.

An incorrect code returns `400` and counts toward the five-attempt limit. The
fifth incorrect attempt returns `423` and cancels the reset. An expired code
returns `410` and cancels the reset. A missing or already-used reset ID returns
`409`. No authorization header is required.
