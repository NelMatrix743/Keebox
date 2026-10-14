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

if (rq.response.code === 200) {
  rq.test("Refresh returns only the renewed access token in a success envelope", () => {
    rq.expect(refreshResponse).to.have.all.keys("success", "data", "error", "meta");
    rq.expect(refreshResponse.success).to.equal(true);
    rq.expect(refreshResponse.error).to.equal(null);
    rq.expect(refreshResponse.meta).to.equal(null);
    rq.expect(refreshResponse.data).to.have.all.keys("access_token");
    rq.expect(refreshResponse.data.access_token).to.be.a("string").and.not.empty;
  });
}
