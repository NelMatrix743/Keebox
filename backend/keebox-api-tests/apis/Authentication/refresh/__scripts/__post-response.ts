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

if (rq.response.code === 401) {
  rq.test("Invalid refresh tokens return the agreed unauthorized envelope", () => {
    rq.expect(refreshResponse).to.have.all.keys("success", "data", "error", "meta");
    rq.expect(refreshResponse.success).to.equal(false);
    rq.expect(refreshResponse.data).to.equal(null);
    rq.expect(refreshResponse.meta).to.equal(null);
    rq.expect(refreshResponse.error).to.have.all.keys("code", "message", "details");
    rq.expect(refreshResponse.error.code).to.equal("invalid_refresh_token");
    rq.expect(refreshResponse.error.message).to.equal(
      "The refresh token is invalid or no longer usable.",
    );
    rq.expect(refreshResponse.error.details).to.equal(null);
  });
}

if (rq.response.code === 422) {
  rq.test("Malformed refresh requests return the validation error envelope", () => {
    rq.expect(refreshResponse).to.have.all.keys("success", "data", "error", "meta");
    rq.expect(refreshResponse.success).to.equal(false);
    rq.expect(refreshResponse.data).to.equal(null);
    rq.expect(refreshResponse.meta).to.equal(null);
    rq.expect(refreshResponse.error).to.have.all.keys("code", "message", "details");
    rq.expect(refreshResponse.error.code).to.equal("validation_error");
    rq.expect(refreshResponse.error.message).to.equal("The request contains invalid data.");
    rq.expect(refreshResponse.error.details).to.be.an("array").and.not.empty;
  });
}
