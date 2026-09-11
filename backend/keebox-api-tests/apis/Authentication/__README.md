# Authentication

Contains the Keebox account authentication endpoints.

This collection covers account registration, email OTP verification and
resending, PIN creation, login, PIN verification, account recovery, and token
management. Public registration endpoints do not require authentication.

Registration begins with the user's first name, last name, email address, and
password. The backend creates a temporary registration challenge, generates an
OTP, and delivers the code through Brevo. JWT credentials and the user's KBKey
are not returned at this stage.

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
