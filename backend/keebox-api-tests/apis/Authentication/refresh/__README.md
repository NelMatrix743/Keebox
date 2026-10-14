# Refresh Access Token

`POST {{base_url}}/api/auth/refresh`

Renew the access token for the current session, including when its previous
access token has expired. The refresh token is supplied in the JSON body;
no authorization header is required. This request uses the Authentication
collection's existing public authentication configuration.

Completing registration or login automatically saves `data.refresh_token` into
the global `refresh_token` variable through that endpoint's post-response script.
Send this request with `base_url` pointing to the running backend. A successful
response returns `200` with
`data.access_token` inside the standard Keebox response envelope.

The post-response script saves a valid successful result to the global
`access_token` variable for protected requests such as Logout. It preserves
the existing `refresh_token`; refresh does not rotate that token, extend its
expiration, or change the active session version. Use the global token variables
without overriding them in another variable scope to use this saved value.

Malformed, expired, or revoked refresh tokens return `401` with
`invalid_refresh_token`. Logout, a completed replacement login, password reset,
and PIN reset revoke the previous session. Missing, empty, or non-string request
values return the standard `422` validation-error envelope.

Response checks cover the successful result and the `401` and `422` error
contracts. Error responses leave the saved token variables unchanged. To inspect
failure behavior, temporarily replace the token in the request body with an
invalid string, remove the field, or submit an empty string, then restore the
variable reference afterward.
