const response = rq.response.json();
const data = response?.data;

if (
  rq.response.code === 200 &&
  response?.success === true &&
  response.error === null &&
  data?.status === "completed" &&
  typeof data.reset_id === "string" &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(data.reset_id)
) {
  rq.globals.set("reset_id", data.reset_id);
}
