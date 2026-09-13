# Verify Registration OTP

`POST {{base_url}}/api/auth/register/verify-otp`

## Overview

Verifies the current six-digit OTP for a pending Keebox registration. A valid
code is consumed and advances the registration challenge from `OTP_PENDING` to
`OTP_VERIFIED`. This endpoint does not create the permanent user account; the
user must still create a lock PIN to complete registration.

First send the Register request. Copy the returned `data.registration_id` into
the global `registration_id` variable, then copy the OTP delivered by email
into the global `otp_code` variable. Both values are inserted into this
request body automatically.

A successful request returns `200 OK` with the registration ID, the
`otp_verified` status, and a message directing the client to PIN creation.
Invalid codes return `400 Bad Request`, invalid or previously consumed
registrations return `409 Conflict`, expired codes return `410 Gone`, locked
codes return `423 Locked`, and malformed request fields return
`422 Unprocessable Entity`. All responses use the common Keebox API response
envelope.
