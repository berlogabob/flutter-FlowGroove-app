const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const functionsTestFactory = require("firebase-functions-test");

const projectId = "repsync-app-callable-test";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || projectId;
process.env.FIREBASE_CONFIG =
  process.env.FIREBASE_CONFIG || JSON.stringify({ projectId });

const functionsTest = functionsTestFactory({ projectId });
const { makeDeleteAccount } = require("../src/account");
const db = admin.firestore();

// Build a gen-2 CallableRequest ({ data, auth }); omit auth for unauthenticated.
const req = (uid, token) => (uid ? { auth: { uid, token: token || {} } } : {});

function build() {
  const deletedUsers = [];
  const deletedFiles = [];
  const deletedPrefixes = [];
  const fakeAuth = { deleteUser: async (uid) => deletedUsers.push(uid) };
  const fakeBucket = {
    name: "test-bucket",
    file: (p) => ({
      delete: async () => deletedFiles.push(p),
    }),
    deleteFiles: async ({ prefix }) => deletedPrefixes.push(prefix),
  };
  return {
    fn: functionsTest.wrap(
      makeDeleteAccount({ getAuth: () => fakeAuth, getBucket: () => fakeBucket }),
    ),
    deletedUsers,
    deletedFiles,
    deletedPrefixes,
  };
}

async function clearAll() {
  for (const c of ["users", "bands"]) {
    const snap = await db.collection(c).get();
    await Promise.all(snap.docs.map((d) => db.recursiveDelete(d.ref)));
  }
}

describe("deleteAccount callable", function () {
  this.timeout(20000);
  beforeEach(clearAll);
  after(async () => {
    await clearAll();
    functionsTest.cleanup();
  });

  it("rejects unauthenticated callers", async () => {
    const { fn } = build();
    await assert.rejects(() => fn(req()), (e) => e.code === "unauthenticated");
  });

  it("rejects demo accounts", async () => {
    await db.collection("users").doc("demo1").set({ accessRole: "demo" });
    const { fn } = build();
    await assert.rejects(
      () => fn(req("demo1")),
      (e) => e.code === "failed-precondition",
    );
  });

  it("deletes user data, profile picture and the auth account", async () => {
    await db.collection("users").doc("u1").set({ name: "A" });
    await db.collection("users").doc("u1").collection("songs").doc("s1").set({ t: 1 });
    await db.collection("users").doc("u1").collection("setlists").doc("l1").set({ t: 1 });
    const { fn, deletedUsers, deletedFiles, deletedPrefixes } = build();

    const result = await fn(req("u1"));
    assert.deepEqual(result, { ok: true });

    const userDoc = await db.collection("users").doc("u1").get();
    assert.equal(userDoc.exists, false);
    const songs = await db.collection("users").doc("u1").collection("songs").get();
    assert.equal(songs.empty, true);
    assert.deepEqual(deletedUsers, ["u1"]);
    assert.deepEqual(deletedFiles, ["profile_pictures/u1.jpg"]);
  });

  it("wipes the audio notes, which nobody could read once the account is gone", async () => {
    await db.collection("users").doc("u1").set({ name: "A" });
    const { fn, deletedPrefixes } = build();

    await fn(req("u1"));

    // Only the personal prefix — band audio survives its members leaving.
    assert.deepEqual(deletedPrefixes, ["lab_audio/user/u1/"]);
  });

  it("dissolves a band where the leaver was the only member", async () => {
    await db.collection("bands").doc("b1").set({
      members: [{ uid: "u1", role: "admin" }],
      memberUids: ["u1"],
      adminUids: ["u1"],
    });
    await db.collection("bands").doc("b1").collection("songs").doc("s1").set({ t: 1 });
    await db.collection("users").doc("u1").set({ name: "A" });
    const { fn } = build();

    await fn(req("u1"));

    const band = await db.collection("bands").doc("b1").get();
    assert.equal(band.exists, false);
    const bandSongs = await db.collection("bands").doc("b1").collection("songs").get();
    assert.equal(bandSongs.empty, true);
  });

  it("removes the leaver and promotes a remaining member when no admin is left", async () => {
    await db.collection("bands").doc("b2").set({
      members: [
        { uid: "u1", role: "admin" },
        { uid: "u2", role: "editor" },
      ],
      memberUids: ["u1", "u2"],
      adminUids: ["u1"],
      editorUids: ["u2"],
    });
    await db.collection("users").doc("u1").set({ name: "A" });
    const { fn } = build();

    await fn(req("u1"));

    const band = (await db.collection("bands").doc("b2").get()).data();
    assert.deepEqual(band.memberUids, ["u2"]);
    assert.deepEqual(band.adminUids, ["u2"]); // promoted
    assert.equal(band.members.length, 1);
    assert.equal(band.members[0].uid, "u2");
    assert.equal(band.members[0].role, "admin");
  });

  it("keeps an existing admin and just drops the leaver", async () => {
    await db.collection("bands").doc("b3").set({
      members: [
        { uid: "u1", role: "editor" },
        { uid: "u2", role: "admin" },
      ],
      memberUids: ["u1", "u2"],
      adminUids: ["u2"],
      editorUids: ["u1"],
    });
    await db.collection("users").doc("u1").set({ name: "A" });
    const { fn } = build();

    await fn(req("u1"));

    const band = (await db.collection("bands").doc("b3").get()).data();
    assert.deepEqual(band.memberUids, ["u2"]);
    assert.deepEqual(band.adminUids, ["u2"]);
    assert.equal(band.members.length, 1);
  });
});
