// api_proxy is a CORS shim for public no-auth APIs. The critical property is
// that it only forwards to allowlisted hosts — it must never become an open
// proxy. Plain (req, res) handler, so no firebase-functions-test needed.

const assert = require("node:assert/strict");
const { makeApiProxy } = require("../src/api_proxy");

function fakeRes() {
  const res = {
    statusCode: null,
    body: null,
    headers: {},
    set(k, v) { this.headers[k] = v; return this; },
    status(code) { this.statusCode = code; return this; },
    json(obj) { this.body = obj; return this; },
    send(b) { this.body = b; return this; },
  };
  return res;
}

describe("api_proxy allowlist", () => {
  it("forwards to an allowlisted host", async () => {
    let fetched = null;
    const proxy = makeApiProxy({
      fetchImpl: async (url) => {
        fetched = url;
        return { status: 200, text: async () => '{"ok":true}' };
      },
    });
    const res = fakeRes();
    await proxy(
      { method: "GET", query: { url: "https://api.deezer.com/search?q=x" } },
      res,
    );
    assert.equal(fetched, "https://api.deezer.com/search?q=x");
    assert.equal(res.statusCode, 200);
    assert.equal(res.body, '{"ok":true}');
  });

  it("rejects a non-allowlisted host with 403 and never fetches", async () => {
    let fetchCalled = false;
    const proxy = makeApiProxy({
      fetchImpl: async () => { fetchCalled = true; return { status: 200, text: async () => "" }; },
    });
    const res = fakeRes();
    await proxy(
      { method: "GET", query: { url: "https://evil.example.com/steal" } },
      res,
    );
    assert.equal(res.statusCode, 403);
    assert.equal(fetchCalled, false);
  });

  it("rejects a missing url with 400", async () => {
    const proxy = makeApiProxy({ fetchImpl: async () => ({ status: 200, text: async () => "" }) });
    const res = fakeRes();
    await proxy({ method: "GET", query: {} }, res);
    assert.equal(res.statusCode, 400);
  });
});
