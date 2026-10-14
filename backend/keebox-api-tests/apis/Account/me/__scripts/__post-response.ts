rq.test("Current user returns a supported status code", () => {
  rq.expect(rq.response.code).to.be.oneOf([200, 401]);
});

if (rq.response.code === 200) {
  rq.test("Current user returns only the approved public profile", () => {
    const body = rq.response.json();
    rq.expect(body).to.have.all.keys("success", "data", "error", "meta");
    rq.expect(body.success).to.equal(true);
    rq.expect(body.error).to.equal(null);
    rq.expect(body.meta).to.equal(null);
    rq.expect(body.data).to.have.all.keys("user_id", "first_name", "last_name", "email");
    rq.expect(body.data.user_id).to.be.a("string").and.match(
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i,
    );
    rq.expect(body.data.first_name).to.be.a("string");
    rq.expect(body.data.last_name).to.be.a("string");
    rq.expect(body.data.email).to.be.a("string").and.not.empty;
  });
}

if (rq.response.code === 401) {
  rq.test("Current user returns the agreed authentication error envelope", () => {
    const body = rq.response.json();
    rq.expect(body).to.have.all.keys("success", "data", "error", "meta");
    rq.expect(body.success).to.equal(false);
    rq.expect(body.data).to.equal(null);
    rq.expect(body.meta).to.equal(null);
    rq.expect(body.error).to.have.all.keys("code", "message", "details");
    rq.expect(body.error.code).to.be.oneOf(["authentication_required", "invalid_session"]);
    rq.expect(body.error.message).to.equal(
      body.error.code === "authentication_required"
        ? "Authentication is required."
        : "The session is no longer valid.",
    );
    rq.expect(body.error.details).to.equal(null);
  });
}
