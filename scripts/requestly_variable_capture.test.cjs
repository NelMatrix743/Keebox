const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const apiDirectory = path.resolve(__dirname, "../backend/keebox-api-tests/apis");
const identifier = "550e8400-e29b-41d4-a716-446655440000";
const initialValues = {
  first_name: "previous-first-name",
  last_name: "previous-last-name",
  registration_id: "previous-registration",
  login_challenge_id: "previous-login",
  reset_id: "previous-reset",
  user_id: "previous-user",
  access_token: "previous-access",
  refresh_token: "previous-refresh",
  KBKEY: "previous-key",
  otp_code: "manual-otp",
  password: "manual-password",
  pin: "manual-pin",
};
const challenges = [
  ["register", 201, "otp_pending", "registration_id"],
  ["verify-otp", 200, "otp_verified", "registration_id"],
  ["resend-otp", 200, "otp_pending", "registration_id"],
  ["login", 200, "password_verified", "login_challenge_id"],
  ["reset-password", 200, "otp_pending", "reset_id"],
  ["reset-pin", 200, "otp_pending", "reset_id"],
  ["reset-resend-otp", 200, "otp_pending", "reset_id"],
  ["reset-verify-otp", 200, "otp_verified", "reset_id"],
  ["reset-password-complete", 200, "completed", "reset_id"],
  ["reset-pin-complete", 200, "completed", "reset_id"],
];
const completions = [["create-pin", 201], ["verify-login-pin", 200]];
const authenticatedData = {
  first_name: "Ada",
  last_name: "Lovelace",
  user_id: identifier,
  access_token: "new-access",
  refresh_token: "new-refresh",
  kbkey: "KBK-test-key",
  status: "completed",
};

/**
 * Execute variable capture against synthetic responses without sending requests.
 * @param {string} requestPath Request directory relative to the API directory.
 * @param {number} status HTTP response status.
 * @param {object | null} body Synthetic response body.
 * @param {object} values Previously saved global values.
 * @returns {object} Global values after executing the capture script.
 */
function capture(requestPath, status, body, values = initialValues) {
  const globals = { ...values };
  const source = fs.readFileSync(
    path.join(apiDirectory, requestPath, "__scripts/__post-response.ts"),
    "utf8",
  );
  vm.runInNewContext(source, {
    rq: {
      response: { code: status, json: () => body },
      globals: { set: (key, value) => { globals[key] = value; } },
      test: () => {},
    },
  });
  return globals;
}

/**
 * Wrap synthetic response data in the standard success envelope.
 * @param {object} data Successful endpoint response data.
 * @returns {object} Successful Keebox response envelope.
 */
function success(data) {
  return { success: true, data, error: null, meta: null };
}

test("challenge endpoints save only their returned identifier", () => {
  for (const [request, status, state, field] of challenges) {
    const values = capture(
      "Authentication/" + request,
      status,
      success({ [field]: identifier, status: state }),
    );
    assert.deepEqual(values, { ...initialValues, [field]: identifier }, request);
  }
});

test("authentication completion saves the complete credential set", () => {
  for (const [request, status] of completions) {
    const values = capture("Authentication/" + request, status, success(authenticatedData));
    assert.deepEqual(values, {
      ...initialValues,
      user_id: identifier,
      access_token: "new-access",
      refresh_token: "new-refresh",
      KBKEY: "KBK-test-key",
      first_name: "Ada",
      last_name: "Lovelace",
    }, request);
  }
});

test("failed or malformed responses preserve saved variables", () => {
  const endpoints = challenges.map(([request, status, state, field]) => [
    request, status, { [field]: identifier, status: state }, [field],
  ]).concat(completions.map(([request, status]) => [
    request, status, authenticatedData, ["user_id", "access_token", "refresh_token", "kbkey"],
  ]));
  for (const [request, status, data, fields] of endpoints) {
    const invalid = [
      [401, success(data)],
      [503, { success: false, data: null, error: { code: "unavailable" }, meta: null }],
      [status, null],
      [status, {}],
      [status, { ...success(data), success: false }],
      [status, { ...success(data), error: { code: "unexpected" } }],
      [status, success({ ...data, status: "unexpected" })],
      [status, success(null)],
    ];
    for (const field of fields) {
      const missing = { ...data };
      delete missing[field];
      invalid.push([status, success(missing)]);
      invalid.push([status, success({ ...data, [field]: "" })]);
      invalid.push([status, success({ ...data, [field]: 123 })]);
    }
    const idField = fields.includes("user_id") ? "user_id" : fields[0];
    invalid.push([status, success({ ...data, [idField]: "not-a-uuid" })]);
    for (const [responseStatus, body] of invalid) {
      assert.deepEqual(
        capture("Authentication/" + request, responseStatus, body),
        initialValues,
        request,
      );
    }
  }
});

test("current user capture preserves the session and ignores failed responses", () => {
  const profile = { user_id: identifier, first_name: "Ada", last_name: "Lovelace", email: "ada@example.com" };
  assert.deepEqual(capture("Account/me", 200, success(profile)), {
    ...initialValues, user_id: identifier, first_name: "Ada", last_name: "Lovelace",
  });
  for (const [status, body] of [
    [401, { success: false, data: null, error: { code: "invalid_session" }, meta: null }],
    [200, success({ ...profile, user_id: "not-a-uuid" })],
    [200, success({ ...profile, user_id: "" })],
    [200, null],
  ]) {
    assert.deepEqual(capture("Account/me", status, body), initialValues);
  }
});

test("registration request reads names from the global variables", () => {
  const request = JSON.parse(fs.readFileSync(
    path.join(apiDirectory, "Authentication/register/__body.json"),
    "utf8",
  ));
  const variables = { first_name: "Grace", last_name: "Hopper", email: "grace@example.com", password: "manual-password" };
  const body = JSON.parse(request.raw.replace(/\{\{(\w+)\}\}/g, (match, name) => variables[name]));
  assert.equal(body.first_name, "Grace");
  assert.equal(body.last_name, "Hopper");
  assert.equal(body.email, "grace@example.com");
  assert.equal(body.password, "manual-password");
});
