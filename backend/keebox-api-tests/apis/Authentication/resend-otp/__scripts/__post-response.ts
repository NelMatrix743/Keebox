const response = rq.response.json();
const data = response?.data;

if (
  rq.response.code === 200 &&
  response?.success === true &&
  response.error === null &&
  data?.status === "otp_pending" &&
  typeof data.registration_id === "string" &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(data.registration_id)
) {
  rq.globals.set("registration_id", data.registration_id);
}
