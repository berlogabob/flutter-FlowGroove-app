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

  it("removes owned personal event grants, guest invites and shares on account deletion", async () => {
    const events = require("../src/events");
    await db.doc("users/u1").set({ name: "Owner" });
    await db.doc("users/u1/setlists/personal-event").set({ name: "Event" });
    await events.writeGrants({ ownerUid: "u1" }, "personal-event", [
      { id: "guest", uid: "u2", access: { eventInfo: "view" } },
    ]);
    await db.doc("eventShares/personal-share").set({ ownerUid: "u1" });
    await db.doc("eventShares/other-share").set({ ownerUid: "u2" });
    const { fn } = build();
    await fn(req("u1"));
    for (const path of ["users/u1/setlists/personal-event/grants/u2", "users/u2/eventInvites/personal-event", "eventShares/personal-share"]) {
      assert.equal((await db.doc(path).get()).exists, false, path);
    }
    assert.equal((await db.doc("eventShares/other-share").get()).exists, true);
    await db.doc("eventShares/other-share").delete();
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

  it("removes a role-only admin without replacing the effective admin", async () => {
    const ref = db.doc("bands/role-only-admin");
    await ref.set({
      members: [{ uid: "u1", role: "admin" }, { uid: "u2", role: "editor" }],
      memberUids: ["u1", "u2"],
      adminUids: ["u3"],
      editorUids: ["u2"],
    });
    const { fn } = build();

    await fn(req("u1"));

    const band = (await ref.get()).data();
    assert.deepEqual(band.members, [{ uid: "u2", role: "editor" }]);
    assert.deepEqual(band.adminUids, ["u3"]);
    assert.deepEqual(band.editorUids, ["u2"]);
  });

  it("promotes a remaining member when the sole array-only admin leaves", async () => {
    const ref = db.doc("bands/array-only-admin");
    await ref.set({
      members: [{ uid: "u2", role: "editor" }, { uid: "u3", role: "admin" }],
      memberUids: ["u2", "u3"],
      adminUids: ["u1"],
      editorUids: ["u2"],
    });
    const { fn } = build();

    await fn(req("u1"));

    const band = (await ref.get()).data();
    assert.deepEqual(band.adminUids, ["u2"]);
    assert.deepEqual(band.memberUids, ["u2", "u3"]);
    assert.deepEqual(band.editorUids, ["u2"]);
    assert.equal(band.members[0].role, "admin");
  });

  it("cleans dangling memberUids-only membership and preserves other grants", async () => {
    const ref = db.doc("bands/dangling-member");
    await ref.set({
      members: [{ uid: "u2", role: "viewer" }],
      memberUids: ["u1", "u2", "u3"],
      adminUids: ["u4"],
      editorUids: ["u1", "u5"],
    });
    const { fn } = build();

    await fn(req("u1"));

    const band = (await ref.get()).data();
    assert.deepEqual(band.members, [{ uid: "u2", role: "viewer" }]);
    assert.deepEqual(band.memberUids, ["u2", "u3"]);
    assert.deepEqual(band.adminUids, ["u4"]);
    assert.deepEqual(band.editorUids, ["u5"]);
  });

  it("finds editorUids-only membership without deleting unrelated array-only grants", async () => {
    const ref = db.doc("bands/array-only-grants");
    await ref.set({
      members: [],
      memberUids: ["u2"],
      adminUids: ["u3"],
      editorUids: ["u1", "u4"],
    });
    const { fn } = build();

    await fn(req("u1"));

    const band = (await ref.get()).data();
    assert.deepEqual(band.members, []);
    assert.deepEqual(band.memberUids, ["u2"]);
    assert.deepEqual(band.adminUids, ["u3"]);
    assert.deepEqual(band.editorUids, ["u4"]);
  });

  it("removes a roster member missing from memberUids via their editor grant", async () => {
    const ref = db.doc("bands/drifted-roster");
    await ref.set({
      members: [{ uid: "u1", role: "editor" }, { uid: "u2", role: "admin" }],
      memberUids: ["u2"],
      adminUids: ["u2"],
      editorUids: ["u1", "u3"],
    });
    const { fn } = build();

    await fn(req("u1"));

    const band = (await ref.get()).data();
    assert.deepEqual(band.members, [{ uid: "u2", role: "admin" }]);
    assert.deepEqual(band.memberUids, ["u2"]);
    assert.deepEqual(band.adminUids, ["u2"]);
    assert.deepEqual(band.editorUids, ["u3"]);
  });
});
