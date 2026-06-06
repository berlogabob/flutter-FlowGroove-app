const fs = require("node:fs");
const path = require("node:path");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");

const projectId = "repsync-app-rules-test";
const rules = fs.readFileSync(
  path.resolve(__dirname, "../../firestore.rules"),
  "utf8",
);

describe("library v2 Firestore rules", function () {
  this.timeout(20000);

  let testEnv;

  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId,
      firestore: { rules },
    });
  });

  after(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection("users").doc("user-1").set(userDoc("user-1"));
      await db.collection("users").doc("user-2").set(userDoc("user-2"));
      await db.collection("users").doc("admin-user").set(userDoc("admin-user"));
      await db.collection("users").doc("outsider").set(userDoc("outsider"));
      await db.collection("users").doc("demo-user").set({
        ...userDoc("demo-user"),
        accessRole: "demo",
      });
      await db.collection("canonical_songs").doc("canonical-1").set({
        id: "canonical-1",
        title: "Song",
        artist: "Artist",
        normalizedTitle: "song",
        normalizedArtist: "artist",
        schemaVersion: 1,
        canonicalRevision: 1,
        status: "active",
      });
      await db.collection("bands").doc("band-1").set({
        id: "band-1",
        name: "Band",
        memberUids: ["user-1", "user-2", "admin-user", "demo-user"],
        editorUids: ["user-1", "demo-user"],
        adminUids: ["admin-user"],
      });
      await db
        .collection("bands")
        .doc("band-1")
        .collection("setlists")
        .doc("setlist-1")
        .set(setlist("band-1", "setlist-1"));
    });
  });

  it("allows authenticated canonical reads and denies client writes", async () => {
    const userDb = authedDb("user-1");
    const anonDb = testEnv.unauthenticatedContext().firestore();

    await assertSucceeds(
      userDb.collection("canonical_songs").doc("canonical-1").get(),
    );
    await assertFails(
      anonDb.collection("canonical_songs").doc("canonical-1").get(),
    );
    await assertFails(
      userDb.collection("canonical_songs").doc("canonical-2").set({
        title: "Client Write",
        artist: "Blocked",
      }),
    );
  });

  it("allows owners to write minimally valid linked user songs and commits", async () => {
    const userDb = authedDb("user-1");
    const songRef = userDb
      .collection("users")
      .doc("user-1")
      .collection("songs")
      .doc("song-1");

    await assertSucceeds(songRef.set(librarySong("user", "user-1")));
    await assertSucceeds(
      songRef.collection("commits").doc("commit-1").set(commit("user-1")),
    );
    await assertFails(
      songRef.collection("commits").doc("commit-1").update({ operation: "x" }),
    );
  });

  it("rejects malformed linked user songs and commits", async () => {
    const userDb = authedDb("user-1");
    const songRef = userDb
      .collection("users")
      .doc("user-1")
      .collection("songs")
      .doc("song-1");

    await assertFails(
      songRef.set({
        ...librarySong("user", "user-1"),
        ownerId: "user-2",
      }),
    );
    await assertFails(
      songRef.collection("commits").doc("commit-1").set({
        ...commit("user-1"),
        operation: "rewrite",
      }),
    );
  });

  it("allows band editors to write linked band songs and commits", async () => {
    const editorDb = authedDb("user-1");
    const songRef = editorDb
      .collection("bands")
      .doc("band-1")
      .collection("songs")
      .doc("song-1");

    await assertSucceeds(songRef.set(librarySong("band", "band-1")));
    await assertSucceeds(
      songRef.collection("commits").doc("commit-1").set(commit("user-1")),
    );
  });

  it("denies band viewers and demo users from linked writes", async () => {
    const viewerDb = authedDb("user-2");
    const demoDb = authedDb("demo-user");

    await assertFails(
      viewerDb
        .collection("bands")
        .doc("band-1")
        .collection("songs")
        .doc("song-1")
        .set(librarySong("band", "band-1")),
    );
    await assertFails(
      demoDb
        .collection("users")
        .doc("demo-user")
        .collection("songs")
        .doc("song-1")
        .set(librarySong("user", "demo-user")),
    );
  });

  it("allows band members to read shared band setlists", async () => {
    const editorDb = authedDb("user-1");
    const viewerDb = authedDb("user-2");
    const outsiderDb = authedDb("outsider");

    await assertSucceeds(
      editorDb
        .collection("bands")
        .doc("band-1")
        .collection("setlists")
        .doc("setlist-1")
        .get(),
    );
    await assertSucceeds(
      viewerDb
        .collection("bands")
        .doc("band-1")
        .collection("setlists")
        .doc("setlist-1")
        .get(),
    );
    await assertFails(
      outsiderDb
        .collection("bands")
        .doc("band-1")
        .collection("setlists")
        .doc("setlist-1")
        .get(),
    );
  });

  it("allows band editors and admins to write shared band setlists", async () => {
    const editorDb = authedDb("user-1");
    const adminDb = authedDb("admin-user");

    await assertSucceeds(
      editorDb
        .collection("bands")
        .doc("band-1")
        .collection("setlists")
        .doc("setlist-2")
        .set(setlist("band-1", "setlist-2")),
    );
    await assertSucceeds(
      adminDb
        .collection("bands")
        .doc("band-1")
        .collection("setlists")
        .doc("setlist-1")
        .update({ name: "Updated Setlist" }),
    );
  });

  it("denies shared band setlist writes for viewers, outsiders, and demo users", async () => {
    const viewerDb = authedDb("user-2");
    const outsiderDb = authedDb("outsider");
    const demoDb = authedDb("demo-user");
    const editorDb = authedDb("user-1");

    await assertFails(
      viewerDb
        .collection("bands")
        .doc("band-1")
        .collection("setlists")
        .doc("setlist-2")
        .set(setlist("band-1", "setlist-2")),
    );
    await assertFails(
      outsiderDb
        .collection("bands")
        .doc("band-1")
        .collection("setlists")
        .doc("setlist-2")
        .set(setlist("band-1", "setlist-2")),
    );
    await assertFails(
      demoDb
        .collection("bands")
        .doc("band-1")
        .collection("setlists")
        .doc("setlist-2")
        .set(setlist("band-1", "setlist-2")),
    );
    await assertFails(
      editorDb
        .collection("bands")
        .doc("band-1")
        .collection("setlists")
        .doc("setlist-1")
        .delete(),
    );
  });

  it("allows only band admins to delete shared band setlists", async () => {
    const adminDb = authedDb("admin-user");

    await assertSucceeds(
      adminDb
        .collection("bands")
        .doc("band-1")
        .collection("setlists")
        .doc("setlist-1")
        .delete(),
    );
  });

  function authedDb(uid) {
    return testEnv.authenticatedContext(uid).firestore();
  }
});

function userDoc(uid) {
  return {
    uid,
    email: `${uid}@example.com`,
    accessRole: "member",
    bandIds: [],
    musicRoles: [],
    systemTags: [],
  };
}

function librarySong(ownerType, ownerId) {
  return {
    id: "song-1",
    schemaVersion: 2,
    canonicalSongId: "canonical-1",
    ownerType,
    ownerId,
    baseRevision: 1,
    delta: {},
    materialized: {
      id: "song-1",
      title: "Song",
      artist: "Artist",
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    },
    latestCommitId: "commit-1",
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
}

function commit(authorId) {
  return {
    id: "commit-1",
    parentCommitId: null,
    canonicalSongId: "canonical-1",
    baseRevision: 1,
    delta: {},
    operation: "create",
    authorId,
    message: "Create linked song",
    clientMutationId: "mutation-1",
    createdAt: new Date().toISOString(),
  };
}

function setlist(bandId, setlistId) {
  return {
    id: setlistId,
    bandId,
    name: "Gig Setlist",
    description: "Shared set",
    songIds: [],
    assignments: {},
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
}
