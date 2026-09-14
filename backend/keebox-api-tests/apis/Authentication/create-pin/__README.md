# Create Registration PIN

`POST {{base_url}}/api/auth/register/create-pin`

## Overview

Creates the lock PIN and completes a Keebox registration after successful OTP
verification. This public registration endpoint does not use an authorization
header. It accepts the existing registration challenge ID and the lock PIN,
and only proceeds when the challenge has the `OTP_VERIFIED` status.

First send the Register request and complete the Verify Registration OTP
request. Keep the same `registration_id` in the global environment, then set
the global `pin` variable to the lock PIN you want to create. A successful
request hashes the PIN, creates the permanent user, generates and encrypts the
user's KBKey, and advances the registration challenge to `COMPLETED`.

A successful request returns `201 Created`. Its response data contains the user
ID, first name, last name, email address, plaintext KBKey, access token, refresh
token, completed status, and confirmation message. The plaintext KBKey is
returned for the client to present and preserve; the backend stores only its
encrypted form.

An unknown, expired, already completed, or otherwise invalid registration
state returns `409 Conflict`. Missing or malformed request fields return
`422 Unprocessable Entity`. All responses use the common Keebox API response
envelope.
