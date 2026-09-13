# Resend Registration OTP

`POST {{base_url}}/api/auth/register/resend-otp`

## Overview

Replaces the current OTP for an active Keebox registration challenge. The
registration must remain in the `OTP_PENDING` state, the 60-second resend
cooldown must have elapsed, and the registration must have remaining resend
attempts.

The request uses the global `registration_id` variable populated from the
Register response. A successful request expires the previous pending OTP,
creates a new five-minute OTP, increments the registration resend count, and
sends the new code to the registration email address through Brevo.

The response reports the new OTP expiration time, the next resend availability
time, and the remaining resend allowance. It never returns the raw OTP. Early
requests return `429 Too Many Requests`. Reaching the maximum of three resends
also returns `429 Too Many Requests` and cancels the registration. Invalid
registration states return `409 Conflict`, email delivery failures return
`503 Service Unavailable`, and malformed request data returns
`422 Unprocessable Entity`.
