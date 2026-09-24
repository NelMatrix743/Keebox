# Start Password Reset

`POST {{base_url}}/api/auth/reset/password`

Submit `email` without an authorization header. The backend starts a password
reset challenge and emails a five-minute OTP when the account exists. The
response includes `reset_id`, OTP expiration, and resend availability. Copy
`data.reset_id` to the `reset_id` variable and the emailed code to `otp_code`.

The endpoint returns the same generic `200` success shape for unknown emails;
those addresses receive no email and their decoy IDs cannot continue. Malformed
email input returns `422`.
