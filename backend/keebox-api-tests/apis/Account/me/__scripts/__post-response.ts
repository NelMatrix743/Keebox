rq.test("Current user returns a supported status code", () => {
  rq.expect(rq.response.code).to.be.oneOf([200, 401]);
});
