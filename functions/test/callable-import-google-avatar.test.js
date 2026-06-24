const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const functionsTestFactory = require("firebase-functions-test");

const projectId = "repsync-app-callable-test";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || projectId;
process.env.FIREBASE_CONFIG = process.env.FIREBASE_CONFIG ||
  JSON.stringify({ projectId });

const functionsTest = functionsTestFactory({ projectId });
const { makeImportGoogleAvatar } = require("../src/avatars");
const db = admin.firestore();

function buildSubject(overrides = {}) {
  const saved = [];
  const fakeBucket = {
    name: "test-bucket",
    file: () => ({
      save: async (buf, opts) => { saved.push({ buf, opts }); },
    }),
  };
  const fakeAuth = {
    getUser: overrides.getUser ||
      (async () => ({
        providerData: [
          { providerId: "google.com", photoURL: "https://google/photo.jpg" },
        ],
      })),
  };
  const fn = makeImportGoogleAvatar({
    getAuth: () => overrides.auth || fakeAuth,
    getBucket: () => overrides.bucket || fakeBucket,
    fetchImpl: overrides.fetchImpl ||
      (async () => ({ ok: true, arrayBuffer: async () => new ArrayBuffer(4) })),
  });
  return { fn: functionsTest.wrap(fn), saved };
}

async function clearUsers() {
  const snap = await db.collection("users").get();
  await Promise.all(snap.docs.map((d) => d.ref.delete()));
}

describe("importGoogleAvatar callable", function () {
  this.timeout(20000);
  beforeEach(clearUsers);
  after(async () => { await clearUsers(); functionsTest.cleanup(); });

  it("rejects unauthenticated callers", async () => {
    const { fn } = buildSubject();
    await assert.rejects(() => fn({}),
      (e) => e.code === "unauthenticated");
  });

  it("fails when the user has no Google photo", async () => {
    const { fn } = buildSubject({
      getUser: async () => ({ providerData: [], photoURL: null }),
    });
    await assert.rejects(
      () => fn({ auth: { uid: "u1" } }),
      (e) => e.code === "not-found",
    );
  });

  it("mirrors the photo and updates the user doc", async () => {
    const { fn, saved } = buildSubject();
    const result = await fn({ auth: { uid: "u1" } });

    assert.equal(saved.length, 1);
    assert.match(result.photoURL, /firebasestorage\.googleapis\.com/);
    const doc = await db.collection("users").doc("u1").get();
    assert.equal(doc.data().photoSource, "google");
    assert.equal(doc.data().photoURL, result.photoURL);
  });
});
