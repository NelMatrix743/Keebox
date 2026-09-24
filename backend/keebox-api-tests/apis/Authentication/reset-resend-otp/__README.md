# Resend Reset OTP

`POST {{base_url}}/api/auth/reset/resend-otp`

Use the `reset_id` from a pending password or lock-PIN reset. The 60-second
cooldown must have elapsed and the current OTP must still be valid. A successful
request expires the old code, emails a replacement five-minute code, and keeps
the same `reset_id`. Copy the new emailed code into `otp_code` before verifying.

An early resend returns `429`; reaching the three-resend limit also returns
`429` and cancels the reset. An expired code returns `410` and a locked code
returns `423`, both requiring a new reset. Invalid reset IDs or states return
`409`. No authorization header is required.
