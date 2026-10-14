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
