# Complete Lock-PIN Reset

`POST {{base_url}}/api/auth/reset/pin/complete`

After verifying a lock-PIN reset OTP, set `new_pin` to the desired new PIN and
submit the same `reset_id`. This endpoint accepts only an `otp_verified` PIN
reset within its ten-minute completion window. It replaces the protected PIN,
clears the PIN lockout and failed-attempt count, marks the reset completed,
and invalidates older access and refresh tokens. The response has no new
tokens; sign in again using the existing password and new PIN.

A missing, wrong-type, pending, or already-completed challenge returns `409`.
An expired completion window returns `410`. Empty PIN input returns `422`.
No password or authorization header is required.
