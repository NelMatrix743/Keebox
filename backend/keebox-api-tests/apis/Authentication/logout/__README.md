# Logout

`POST {{base_url}}/api/auth/logout`

After completing login, copy `data.access_token` into the `access_token`
secret variable. Send this request with bearer authentication and no body.
The server ends the active session by invalidating both its access and refresh
tokens. A successful response has status `logged_out` and returns no new tokens.

Missing, invalid, or already revoked access tokens return `401`. Sign in again
to get a new token pair before calling protected endpoints.
