const response = rq.response.json();
const data = response?.data;

if (
  rq.response.code === 201 &&
  response?.success === true &&
  response.error === null &&
  data?.status === "completed" &&
  typeof data.first_name === "string" &&
  typeof data.last_name === "string" &&
  typeof data.user_id === "string" &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(data.user_id) &&
  typeof data.access_token === "string" &&
  data.access_token.length > 0 &&
  typeof data.refresh_token === "string" &&
  data.refresh_token.length > 0 &&
  typeof data.kbkey === "string" &&
  data.kbkey.length > 0
) {
  rq.globals.set("user_id", data.user_id);
  rq.globals.set("first_name", data.first_name);
  rq.globals.set("last_name", data.last_name);
  rq.globals.set("access_token", data.access_token);
  rq.globals.set("refresh_token", data.refresh_token);
  rq.globals.set("KBKEY", data.kbkey);
}
