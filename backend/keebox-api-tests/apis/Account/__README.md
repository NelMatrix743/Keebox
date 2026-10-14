# Account

Authenticated account requests outside the `/api/auth` route prefix.

This collection sends `Authorization: Bearer {{access_token}}`. Set the global
`access_token` from a completed registration or login. Authentication's Refresh
request updates that same variable after successful renewal, so Account requests
can use the renewed access token without another manual copy.

The `me` request retrieves the current account's public profile from `GET /api/me`.
Account and authentication requests share the existing `base_url` variable.
