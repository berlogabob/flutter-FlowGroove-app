// Regression tests for the 2026-10-11 audit fixes: joinBand needs the invite
// code, Telegram linking needs a minted token, MCP writes block demo users.
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const functionsTestFactory = require("firebase-functions-test");

const projectId = "repsync-app-callable-test";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || projectId;
process.env.FIREBASE_CONFIG =
  process.env.FIREBASE_CONFIG || JSON.stringify({ projectId });

const functionsTest = functionsTestFactory({ projectId });
const { joinBand } = require("../src/bands");
const { createTelegramLinkToken, consumeTelegramLinkToken } =
  require("../src/telegram/linkToken");
const { runTool } = require("../src/mcp/tools");
const db = admin.firestore();

const join = functionsTest.wrap(joinBand);
const mint = functionsTest.wrap(createTelegramLinkToken);
const call = (fn, uid, data) => fn({ data, auth: { uid, token: {} } });

async function clearAll() {
  for (const c of ["users", "bands", "telegramLinkTokens"]) {
    const snap = await db.collection(c).get();
    await Promise.all(snap.docs.map((d) => db.recursiveDelete(d.ref)));
  }
}

describe("audit security fixes", function () {
  this.timeout(20000);
  beforeEach(async () => {
    await clearAll();
    await db.collection("users").doc("outsider").set({ accessRole: "member" });
    await db.collection("users").doc("demo1").set({ accessRole: "demo" });
    await db.collection("bands").doc("b1").set({
      name: "B", inviteCode: "ABC123", members: [{ uid: "own", role: "admin" }],
      memberUids: ["own"], adminUids: ["own"], editorUids: [],
    });
  });
  after(async () => { await clearAll(); functionsTest.cleanup(); });

  it("joinBand rejects a bare bandId", async () => {
    await assert.rejects(call(join, "outsider", { bandId: "b1" }), /invite code/i);
    assert.deepEqual((await db.collection("bands").doc("b1").get()).data().memberUids, ["own"]);
  });

  it("joinBand rejects a code that does not match the given bandId", async () => {
    await db.collection("bands").doc("b2").set({ inviteCode: "ZZZ999", members: [] });
    await assert.rejects(call(join, "outsider", { code: "ZZZ999", bandId: "b1" }), /does not match/i);
  });

  it("joinBand accepts the valid code", async () => {
    const out = await call(join, "outsider", { code: "abc123", bandId: "b1" });
    assert.equal(out.bandId, "b1");
    assert.ok((await db.collection("bands").doc("b1").get()).data().memberUids.includes("outsider"));
  });

  it("telegram link token is single-use, user-bound, and rejects raw uids", async () => {
    const { token } = await call(mint, "outsider", {});
    assert.equal(await consumeTelegramLinkToken("outsider"), null);
    assert.equal(await consumeTelegramLinkToken(token), "outsider");
    assert.equal(await consumeTelegramLinkToken(token), null);
  });

  it("telegram link token is refused for demo users", async () => {
    await assert.rejects(call(mint, "demo1", {}), /Demo/);
  });

  it("MCP write tools refuse demo accounts", async () => {
    const out = await runTool(db, "demo1", "write", "create_song", { title: "x" });
    assert.equal(out.status, 403);
  });
});
