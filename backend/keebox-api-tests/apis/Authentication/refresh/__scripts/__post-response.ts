const refreshResponse = rq.response.json();

if (
  rq.response.code === 200 &&
  refreshResponse.success === true &&
  refreshResponse.error === null &&
  typeof refreshResponse.data?.access_token === "string" &&
  refreshResponse.data.access_token.length > 0
) {
  rq.globals.set("access_token", refreshResponse.data.access_token);
}

rq.test("Refresh returns a supported status code", () => {
  rq.expect(rq.response.code).to.be.oneOf([200, 401, 422]);
});
