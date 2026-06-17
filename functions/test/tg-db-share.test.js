const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const functionsTestFactory = require("firebase-functions-test");

const projectId = "repsync-app-callable-test";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || projectId;
process.env.FIREBASE_CONFIG =
  process.env.FIREBASE_CONFIG || JSON.stringify({ projectId });

const functionsTest = functionsTestFactory({ projectId });
const { makeShareToTelegram } = require("../src/telegram/share");
const db = admin.firestore();

function build() {
  const sent = [];
  const fn = functionsTest.wrap(
    makeShareToTelegram({
      getSend: () => async (telegramId, text) => sent.push({ telegramId, text }),
    }),
  );
  return { fn, sent };
}

async function clearUsers() {
  const snap = await db.collection("users").get();
  await Promise.all(snap.docs.map((d) => d.ref.delete()));
}

describe("shareToTelegram callable", function () {
  this.timeout(20000);
  beforeEach(clearUsers);
  after(async () => {
    await clearUsers();
    functionsTest.cleanup();
  });

  it("rejects unauthenticated callers", async () => {
    const { fn } = build();
    await assert.rejects(
      () => fn({ text: "hi" }, {}),
      (e) => e.code === "unauthenticated",
    );
  });

  it("rejects empty text", async () => {
    const { fn } = build();
    await assert.rejects(
      () => fn({ text: "   " }, { auth: { uid: "u1" } }),
      (e) => e.code === "invalid-argument",
    );
  });

  it("fails when the caller's Telegram is not linked", async () => {
    await db.collection("users").doc("u1").set({ displayName: "A" });
    const { fn } = build();
    await assert.rejects(
      () => fn({ text: "hi" }, { auth: { uid: "u1" } }),
      (e) => e.code === "failed-precondition",
    );
  });

  it("sends the text to the caller's linked chat", async () => {
    await db.collection("users").doc("u1").set({ telegramId: "123" });
    const { fn, sent } = build();
    const result = await fn({ text: "hello band" }, { auth: { uid: "u1" } });
    assert.deepEqual(result, { ok: true });
    assert.equal(sent.length, 1);
    assert.equal(sent[0].telegramId, "123");
    assert.equal(sent[0].text, "hello band");
  });
});
