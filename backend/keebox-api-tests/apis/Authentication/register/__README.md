Starts the first stage of Keebox account registration.

Validates the user's first name, last name, email address, and password; creates a 30-minute registration challenge and a five-minute OTP; and sends the OTP to the supplied email address through Brevo.

A successful response returns the registration identifier, challenge status, registration expiration time, OTP expiration time, resend availability time, and a confirmation message. This endpoint does not create the permanent user, issue authentication tokens, return a KBKey, or expose the raw password or OTP.