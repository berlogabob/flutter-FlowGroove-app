const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const functionsTestFactory = require("firebase-functions-test");

const projectId = "repsync-app-callable-test";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || projectId;
process.env.FIREBASE_CONFIG =
  process.env.FIREBASE_CONFIG || JSON.stringify({ projectId });

const functionsTest = functionsTestFactory({ projectId });
const { makeSetBandAvatar, makeRemoveBandAvatar } = require("../src/band_avatar");
const db = admin.firestore();

const b64 = (s) => Buffer.from(s).toString("base64");

function buildSet() {
  const saved = [];
  const fakeBucket = {
    name: "test-bucket",
    file: () => ({ save: async (buf, opts) => saved.push({ buf, opts }) }),
  };
  return {
    fn: functionsTest.wrap(makeSetBandAvatar({ getBucket: () => fakeBucket })),
    saved,
  };
}

function buildRemove() {
  const deleted = [];
  const fakeBucket = {
    name: "test-bucket",
    file: (p) => ({ delete: async () => deleted.push(p) }),
  };
  return {
    fn: functionsTest.wrap(makeRemoveBandAvatar({ getBucket: () => fakeBucket })),
    deleted,
  };
}

async function clearBands() {
  const snap = await db.collection("bands").get();
  await Promise.all(snap.docs.map((d) => d.ref.delete()));
}

describe("setBandAvatar / removeBandAvatar callables", function () {
  this.timeout(20000);
  beforeEach(clearBands);
  after(async () => {
    await clearBands();
    functionsTest.cleanup();
  });

  it("rejects unauthenticated callers", async () => {
    const { fn } = buildSet();
    await assert.rejects(
      () => fn({ bandId: "b1", imageBase64: b64("x") }, {}),
      (e) => e.code === "unauthenticated",
    );
  });

  it("rejects a non-admin with permission-denied", async () => {
    await db.collection("bands").doc("b1").set({ adminUids: ["admin1"] });
    const { fn } = buildSet();
    await assert.rejects(
      () => fn({ bandId: "b1", imageBase64: b64("img") }, { auth: { uid: "nope" } }),
      (e) => e.code === "permission-denied",
    );
  });

  it("requires bandId and imageBase64", async () => {
    const { fn } = buildSet();
    await assert.rejects(
      () => fn({ bandId: "b1" }, { auth: { uid: "admin1" } }),
      (e) => e.code === "invalid-argument",
    );
  });

  it("uploads for a band admin and writes photoURL", async () => {
    await db.collection("bands").doc("b1").set({ adminUids: ["admin1"] });
    const { fn, saved } = buildSet();
    const result = await fn(
      { bandId: "b1", imageBase64: b64("imagedata") },
      { auth: { uid: "admin1" } },
    );
    assert.match(result.photoURL, /firebasestorage\.googleapis\.com/);
    assert.equal(saved.length, 1);
    const doc = await db.collection("bands").doc("b1").get();
    assert.equal(doc.data().photoURL, result.photoURL);
  });

  it("removeBandAvatar clears photoURL for an admin", async () => {
    await db.collection("bands").doc("b1").set({
      adminUids: ["admin1"],
      photoURL: "https://example.com/old",
    });
    const { fn } = buildRemove();
    const result = await fn({ bandId: "b1" }, { auth: { uid: "admin1" } });
    assert.deepEqual(result, { ok: true });
    const doc = await db.collection("bands").doc("b1").get();
    assert.equal(doc.data().photoURL, null);
  });
});
