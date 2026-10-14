# Authentication

Contains the Keebox account authentication endpoints.

This collection covers account registration, email OTP verification and
resending, PIN creation, login, PIN verification, account recovery, and token
management. Public registration endpoints do not require authentication.

Registration begins with the user's first name, last name, email address, and
password. The backend creates a temporary registration challenge, generates an
OTP, and delivers the code through Brevo. JWT credentials and the user's KBKey
are not returned at this stage.

Register reads `first_name` and `last_name` from the matching global variables.
Set those values before starting registration. Successful registration completion,
login completion, and Account → me update both names from the returned account data.

## Register

`POST {{base_url}}/api/auth/register`

### Overview

Initiates the first stage of Keebox account registration. It accepts the
prospective user's identity and account credentials, validates them, and starts
a temporary email-verification workflow. A successful request creates a
registration challenge and an OTP verification record, then sends the OTP to
the supplied email address through Brevo.

This endpoint does not create the permanent user account, issue authentication
tokens, create the account PIN, or return the user's KBKey. Those operations are
performed only after the email address has been verified and the remaining
registration stages have completed.

Starts a new Keebox registration. The endpoint validates the submitted account
details, creates a registration challenge with a 30-minute lifetime, creates a
six-digit OTP with a five-minute lifetime, and emails the OTP to the submitted
address.

The response contains the registration challenge ID, registration status,
challenge expiration, OTP expiration, resend availability time, and a safe
user-facing message. It never returns the raw password or OTP code.

An email already assigned to a permanent user returns `409 Conflict`. Invalid
request fields return `422 Unprocessable Entity`. A Brevo delivery failure
returns `503 Service Unavailable`. All responses use the common Keebox API
response envelope.

Before sending the request, replace the example email address with an inbox you
can access so you can retrieve the OTP. Repeated pending registration attempts
are allowed until a permanent user owns the email address.

## Account reset

Password and lock-PIN recovery each begin with an email-only request. Both use
the same reset OTP resend and verification requests, then have separate
completion requests. No reset request requires an authorization header.

Set `email` to the account's address. After starting a reset, its post-response
script saves `data.reset_id` into the global `reset_id` variable. Copy the emailed
six-digit code into `otp_code`.
Use `new_password` or `new_pin` only for the corresponding completion request.
The OTP lasts five minutes; the resend cooldown is 60 seconds. Once the OTP is
verified, complete the reset within ten minutes. Completion revokes existing
sessions and does not return new tokens, so sign in again afterward.

An unknown email receives the same successful start response shape, but no
email is sent and its returned reset ID cannot be verified. Do not infer
account existence from the start response.

## Logout

Completing login automatically saves `data.access_token` into the global
`access_token` secret variable.
Send the Logout request to end that session. Its bearer access token is
required; logout invalidates both the access and refresh tokens. Sign in again
to obtain a new token pair.

## Automatic response capture

Each endpoint owns its script under Scripts → Post-response:

- Register, Verify OTP, and Resend OTP save `registration_id`.
- Login saves `login_challenge_id` for Verify Login PIN.
- Create PIN and Verify Login PIN save `user_id`, `access_token`, `refresh_token`,
  `first_name`, `last_name`, and `KBKEY` from the returned `kbkey` field.
- Reset initiation, resend, verification, and completion save `reset_id`.
- Refresh saves the renewed `access_token` while preserving `refresh_token`.
- Account → me saves `user_id`, `first_name`, and `last_name`, preserving tokens.

Scripts update the existing global variables only on successful responses with
the expected status and usable returned values. Errors and incomplete responses
leave previously saved values unchanged. Avoid conflicting token or identifier
overrides in other scopes when using these global variables.

Email OTPs remain manual inputs. Password and PIN inputs are not copied from
responses; after resetting either credential, update the corresponding login
input yourself. Logout returns no reusable identifiers or tokens, so it has no
capture script and preserves the saved values for revocation testing.

Local capture regression checks can be run from the repository root with
`node --test scripts/requestly_variable_capture.test.cjs`. These checks use
synthetic responses and do not send API requests or emails.
