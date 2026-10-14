# Account

Authenticated account requests outside the `/api/auth` route prefix.

This collection sends `Authorization: Bearer {{access_token}}`. Completing
registration or login automatically saves the global `access_token` through
that endpoint's post-response script. Authentication's Refresh request updates
the same variable after successful renewal, so Account requests use the new token.

The `me` request retrieves the current account's public profile from `GET /api/me`.
Account and authentication requests share the existing `base_url` variable.

Successful account retrieval updates the global `user_id`, `first_name`, and
`last_name` from the current profile. Register reads those same name variables
as inputs; change them before registering another account if needed.
