# Current User

`GET {{base_url}}/api/me`

Retrieve the authenticated account's current public profile from the database.
The request has no body or query parameters and inherits the Account collection's
bearer authorization using `{{access_token}}`.

Complete registration or login; its post-response script saves `data.access_token`
into the global `access_token` variable. Set `base_url` to the running backend
and send this request.
A successful response returns `200` with `user_id`, `first_name`, `last_name`, and
`email` under `data`. Passwords, PIN information, KBKeys, encryption metadata, and
authentication tokens are excluded.

After an access token expires, send Authentication's Refresh request with the
current `refresh_token`. Its script updates the global `access_token`, which this
request then uses. Avoid a conflicting `access_token` override in another variable
scope if you want to use the global value saved by Refresh.

Missing authorization returns `401` with `authentication_required`. Invalid,
expired, revoked, and wrong-type tokens return `401` with `invalid_session`.
Inactive or deleted accounts are also rejected. Logout, a completed replacement
login, password reset, and PIN reset invalidate the previous session's access.

The post-response script saves a valid successful `data.user_id`, `data.first_name`,
and `data.last_name` into the corresponding global variables. Its checks validate
the status, the four-field public profile, and the agreed authentication-error
envelopes. It does not modify tokens or the email input. To inspect failure
behavior, temporarily disable the authorization header or use an invalid access
token, then restore inherited
authorization afterward.
