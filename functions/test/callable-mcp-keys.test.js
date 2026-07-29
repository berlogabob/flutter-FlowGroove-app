const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const functionsTestFactory = require("firebase-functions-test");

const projectId = "repsync-app-callable-test";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || projectId;
process.env.FIREBASE_CONFIG =
  process.env.FIREBASE_CONFIG || JSON.stringify({ projectId });

const functionsTest = functionsTestFactory({ projectId });
const keys = require("../src/mcp/keys");
const db = admin.firestore();

const req = (data, uid, token) => (uid ? { data, auth: { uid, token: token || {} } } : { data });

async function clear() {
  for (const c of ["apiKeys", "users"]) {
    const snap = await db.collection(c).get();
    await Promise.all(snap.docs.map((d) => d.ref.delete()));
  }
}

describe("MCP api-key callables", function () {
  this.timeout(20000);
  beforeEach(clear);
  after(async () => {
    await clear();
    functionsTest.cleanup();
  });

  it("rejects unauthenticated", async () => {
    const fn = functionsTest.wrap(keys.createApiKey);
    await assert.rejects(() => fn(req({})), (e) => e.code === "unauthenticated");
  });

  it("blocks demo users", async () => {
    await db.collection("users").doc("demo1").set({ accessRole: "demo" });
    const fn = functionsTest.wrap(keys.createApiKey);
    await assert.rejects(
      () => fn(req({}, "demo1")),
      (e) => e.code === "failed-precondition",
    );
  });

  it("mints a token once and stores only its hash", async () => {
    const fn = functionsTest.wrap(keys.createApiKey);
    const r = await fn(req({ scope: "write", label: "cli" }, "u1"));
    assert.match(r.token, /^fg_/);
    assert.equal(r.scope, "write");

    const doc = await db.collection("apiKeys").doc(keys._hashToken(r.token)).get();
    assert.ok(doc.exists);
    assert.equal(doc.data().uid, "u1");
    assert.equal(doc.data().token, undefined); // plaintext never stored
    assert.match(doc.data().prefix, /^fg_/);
  });

  it("lists metadata (no token) and revokes", async () => {
    const create = functionsTest.wrap(keys.createApiKey);
    const list = functionsTest.wrap(keys.listApiKeys);
    const revoke = functionsTest.wrap(keys.revokeApiKey);

    const r = await create(req({}, "u1"));
    let out = await list(req({}, "u1"));
    assert.equal(out.keys.length, 1);
    assert.equal(out.keys[0].token, undefined);

    await revoke(req({ id: r.id }, "u1"));
    out = await list(req({}, "u1"));
    assert.equal(out.keys.length, 0);
  });

  it("won't revoke another user's key", async () => {
    const create = functionsTest.wrap(keys.createApiKey);
    const revoke = functionsTest.wrap(keys.revokeApiKey);
    const r = await create(req({}, "u1"));
    await revoke(req({ id: r.id }, "u2")); // different user — no-op
    const doc = await db.collection("apiKeys").doc(r.id).get();
    assert.ok(doc.exists);
  });
});
