# Complete Password Reset

`POST {{base_url}}/api/auth/reset/password/complete`

After verifying a password-reset OTP, set `new_password` to the desired new
password and submit the same `reset_id`. This endpoint accepts only an
`otp_verified` password reset within its ten-minute completion window. It
changes the password, marks the reset completed, and invalidates older access
and refresh tokens. The response has no new tokens; sign in again using the
new password and the existing lock PIN.

A missing, wrong-type, pending, or already-completed challenge returns `409`.
An expired completion window returns `410`. Password policy validation errors
return `422`. No authorization header is required.
