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
const { joinBand, updateBandMember } = require("../src/bands");
const { createTelegramLinkToken, consumeTelegramLinkToken } =
  require("../src/telegram/linkToken");
const { runTool } = require("../src/mcp/tools");
const db = admin.firestore();

const join = functionsTest.wrap(joinBand);
const update = functionsTest.wrap(updateBandMember);
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

  for (const action of ["setRole", "remove"]) {
    it(`rejects a role-only admin attempting ${action}`, async () => {
      await db.collection("bands").doc("b1").update({
        members: [{ uid: "own", role: "admin" }, { uid: "target", role: "viewer" }],
        memberUids: ["own", "target"], adminUids: ["target"],
      });
      await assert.rejects(call(update, "own", {
        bandId: "b1", targetUid: "target", action, role: "editor",
      }), { code: "permission-denied" });
    });
  }

  it("allows an effective array admin to change a target role", async () => {
    await db.collection("bands").doc("b1").update({
      members: [{ uid: "own", role: "member" }, { uid: "target", role: "viewer" }],
      memberUids: ["own", "target"],
    });
    await call(update, "own", {
      bandId: "b1", targetUid: "target", action: "setRole", role: "editor",
    });
    const band = (await db.collection("bands").doc("b1").get()).data();
    assert.equal(band.members.find((m) => m.uid === "target").role, "editor");
    assert.deepEqual(band.adminUids, ["own"]);
    assert.deepEqual(band.editorUids, ["target"]);
  });

  it("preserves unrelated array grants across music edits, leaves and invite joins", async () => {
    const ref = db.collection("bands").doc("b1");
    await ref.update({
      members: [
        { uid: "own", role: "admin" },
        { uid: "legacy", role: "viewer" },
        { uid: "leaver", role: "viewer" },
      ],
      memberUids: ["own", "legacy", "leaver"], editorUids: ["legacy"],
    });
    await call(update, "own", {
      bandId: "b1", targetUid: "legacy", action: "setMusicRoles", musicRoles: ["bass"],
    });
    assert.deepEqual((await ref.get()).data().editorUids, ["legacy"]);
    await call(update, "leaver", { bandId: "b1", targetUid: "leaver", action: "remove" });
    assert.deepEqual((await ref.get()).data().editorUids, ["legacy"]);
    assert.deepEqual((await ref.get()).data().memberUids, ["own", "legacy"]);
    const joined = await call(join, "outsider", { code: "ABC123" });
    assert.equal(joined.alreadyMember, false);
    assert.deepEqual((await ref.get()).data().editorUids, ["legacy", "outsider"]);
    const repeated = await call(join, "outsider", { code: "ABC123" });
    assert.equal(repeated.alreadyMember, true);
    assert.deepEqual((await ref.get()).data().editorUids, ["legacy", "outsider"]);
    assert.deepEqual((await ref.get()).data().memberUids, ["own", "legacy", "outsider"]);
    assert.deepEqual((await ref.get()).data().adminUids, ["own"]);
  });

  for (const action of ["setRole", "remove"]) {
    it(`protects the last effective admin from ${action}`, async () => {
      await db.collection("bands").doc("b1").update({
        members: [{ uid: "own", role: "admin" }, { uid: "legacy", role: "admin" }],
        memberUids: ["own", "legacy"],
      });
      await assert.rejects(call(update, "own", {
        bandId: "b1", targetUid: "own", action, role: "viewer",
      }), { code: "failed-precondition" });
    });
  }

  it("an existing invite join restores only the joining member's grants", async () => {
    const ref = db.collection("bands").doc("b1");
    await ref.update({
      members: [{ uid: "own", role: "admin" }, { uid: "legacy", role: "viewer" }],
      memberUids: ["legacy"], adminUids: [], editorUids: ["legacy"],
    });
    const out = await call(join, "own", { code: "ABC123" });
    assert.equal(out.alreadyMember, true);
    const band = (await ref.get()).data();
    assert.equal(band.members.length, 2);
    assert.deepEqual(band.memberUids, ["legacy", "own"]);
    assert.deepEqual(band.adminUids, ["own"]);
    assert.deepEqual(band.editorUids, ["legacy"]);
  });

  for (const action of ["setRole", "remove"]) {
    it(`protects an array-only last admin from ${action}`, async () => {
      await db.collection("bands").doc("b1").update({
        members: [{ uid: "own", role: "member" }, { uid: "legacy", role: "admin" }],
        memberUids: ["own", "legacy"],
      });
      await assert.rejects(call(update, "own", {
        bandId: "b1", targetUid: "own", action, role: "viewer",
      }), { code: "failed-precondition" });
    });
  }

  it("uses role defaults only for missing or invalid array fields", async () => {
    const ref = db.collection("bands").doc("b1");
    await ref.set({
      inviteCode: "ABC123",
      members: [{ uid: "own", role: "admin" }, { uid: "legacy", role: "viewer" }],
      adminUids: ["own"], editorUids: null,
    });
    await call(join, "outsider", { code: "ABC123" });
    const band = (await ref.get()).data();
    assert.deepEqual(band.memberUids, ["own", "legacy", "outsider"]);
    assert.deepEqual(band.adminUids, ["own"]);
    assert.deepEqual(band.editorUids, ["outsider"]);
  });

  it("still dissolves the band when its last member leaves", async () => {
    await call(update, "own", { bandId: "b1", targetUid: "own", action: "remove" });
    assert.equal((await db.collection("bands").doc("b1").get()).exists, false);
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

describe("audit fixes round 2", function () {
  this.timeout(20000);
  const { makeImportGoogleAvatar } = require("../src/avatars");
  it("google avatar import refuses non-Google hosts (SSRF)", async () => {
    const fn = functionsTest.wrap(makeImportGoogleAvatar({
      getAuth: () => ({ getUser: async () => ({ providerData: [], photoURL: "http://127.0.0.1:8080/x" }) }),
      fetchImpl: async () => { throw new Error("must not fetch"); },
      getBucket: () => ({}),
    }));
    await assert.rejects(call(fn, "u1", {}), /not allowed/);
  });
});

describe("api key lifecycle", function () {
  this.timeout(20000);
  it("deleteAccount revokes the user's API keys", async () => {
    const { makeDeleteAccount } = require("../src/account");
    await db.collection("users").doc("kuser").set({ accessRole: "member" });
    await db.collection("apiKeys").doc("h1").set({ uid: "kuser", scope: "read" });
    const fn = functionsTest.wrap(makeDeleteAccount({
      getAuth: () => ({ deleteUser: async () => {} }),
      getBucket: () => ({ name: "b", file: () => ({ delete: async () => {} }), deleteFiles: async () => {} }),
    }));
    await call(fn, "kuser", {});
    assert.equal((await db.collection("apiKeys").doc("h1").get()).exists, false);
  });
});
