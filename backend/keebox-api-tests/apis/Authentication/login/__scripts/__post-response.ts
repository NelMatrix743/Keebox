const response = rq.response.json();
const data = response?.data;

if (
  rq.response.code === 200 &&
  response?.success === true &&
  response.error === null &&
  data?.status === "password_verified" &&
  typeof data.login_challenge_id === "string" &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(data.login_challenge_id)
) {
  rq.globals.set("login_challenge_id", data.login_challenge_id);
}
