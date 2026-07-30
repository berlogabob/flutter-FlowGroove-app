const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const functionsTestFactory = require("firebase-functions-test");

const projectId = "repsync-app-callable-test";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || projectId;
process.env.FIREBASE_CONFIG = process.env.FIREBASE_CONFIG ||
  JSON.stringify({ projectId });

const functionsTest = functionsTestFactory({ projectId });
const canonical = require("../src/canonical");
const wrappedUpdateCanonicalSong = functionsTest.wrap(canonical.updateCanonicalSong);
const db = admin.firestore();

describe("updateCanonicalSong callable", function () {
  this.timeout(20000);

  after(async () => {
    await clearUsers();
    await clearCanonicalSongs();
    functionsTest.cleanup();
  });

  beforeEach(async () => {
    await clearUsers();
    await clearCanonicalSongs();
  });

  it("rejects unauthenticated callers", async () => {
    await assert.rejects(
      () => wrappedUpdateCanonicalSong({ data: { canonicalSongId: "c1", fields: {} } }),
      (error) => error.code === "unauthenticated",
    );
  });

  it("rejects demo users", async () => {
    await db.collection("users").doc("demo-user").set({ accessRole: "demo" });
    await assert.rejects(
      () => wrappedUpdateCanonicalSong({
        data: { canonicalSongId: "c1", fields: { album: "X" } },
        auth: { uid: "demo-user", token: {} },
      }),
      (error) => error.code === "failed-precondition",
    );
  });

  it("requires a canonicalSongId", async () => {
    await assert.rejects(
      () => call({ fields: { album: "X" } }),
      (error) => error.code === "invalid-argument",
    );
  });

  it("rejects an unknown canonical song", async () => {
    await assert.rejects(
      () => call({ canonicalSongId: "nope", fields: { album: "X" } }),
      (error) => error.code === "not-found",
    );
  });

  it("fills blanks and bumps canonicalRevision", async () => {
    await seed("c1", { createdBy: "user-1", canonicalRevision: 1 });

    const result = await call({
      canonicalSongId: "c1",
      fields: {
        album: "Second Helping",
        releaseYear: 1974,
        isrc: "USMC17446153",
        iswc: "T-070.076.790-3",
        musicBrainzWorkId: "work-1",
      },
    });

    assert.equal(result.canonicalRevision, 2);
    assert.deepEqual(result.updated.sort(), [
      "album", "isrc", "iswc", "musicBrainzWorkId", "releaseYear",
    ]);

    const data = (await db.collection("canonical_songs").doc("c1").get()).data();
    assert.equal(data.album, "Second Helping");
    assert.equal(data.releaseYear, 1974);
    assert.equal(data.isrc, "USMC17446153");
    assert.equal(data.canonicalRevision, 2);
    // Untouched fields survive the merge.
    assert.equal(data.title, "Song");
    assert.equal(data.createdBy, "user-1");
  });

  it("does not bump the revision when nothing changed", async () => {
    await seed("c1", { createdBy: "user-1", canonicalRevision: 7, album: "Kept" });

    const result = await call({ canonicalSongId: "c1", fields: { album: "Kept" } });

    assert.equal(result.canonicalRevision, 7);
    assert.deepEqual(result.updated, []);
    const data = (await db.collection("canonical_songs").doc("c1").get()).data();
    assert.equal(data.canonicalRevision, 7);
  });

  it("keeps an existing value for a non-creator and warns", async () => {
    await seed("c1", { createdBy: "someone-else", album: "Apocalypse Now" });

    const result = await call({
      canonicalSongId: "c1",
      fields: { album: "The Doors" },
      overwrite: true,
    });

    assert.deepEqual(result.updated, []);
    assert.ok(result.warnings.some((w) => /overwrite requires being the creator/.test(w)));
    const data = (await db.collection("canonical_songs").doc("c1").get()).data();
    assert.equal(data.album, "Apocalypse Now");
  });

  it("lets the creator overwrite a wrong value", async () => {
    await seed("c1", { createdBy: "user-1", album: "Apocalypse Now" });

    const result = await call({
      canonicalSongId: "c1",
      fields: { album: "The Doors" },
      overwrite: true,
    });

    assert.deepEqual(result.updated, ["album"]);
    const data = (await db.collection("canonical_songs").doc("c1").get()).data();
    assert.equal(data.album, "The Doors");
  });

  it("still fills blanks for a non-creator", async () => {
    await seed("c1", { createdBy: "someone-else" });

    const result = await call({ canonicalSongId: "c1", fields: { releaseYear: 1967 } });

    assert.deepEqual(result.updated, ["releaseYear"]);
    const data = (await db.collection("canonical_songs").doc("c1").get()).data();
    assert.equal(data.releaseYear, 1967);
  });

  it("never writes title, artist or status", async () => {
    await seed("c1", { createdBy: "user-1" });

    const result = await call({
      canonicalSongId: "c1",
      fields: { title: "Hacked", artist: "Hacked", status: "hidden" },
      overwrite: true,
    });

    assert.deepEqual(result.updated, []);
    const data = (await db.collection("canonical_songs").doc("c1").get()).data();
    assert.equal(data.title, "Song");
    assert.equal(data.artist, "Artist");
    assert.equal(data.status, "active");
  });
});

function call(payload) {
  return wrappedUpdateCanonicalSong({
    data: payload,
    auth: { uid: "user-1", token: {} },
  });
}

async function seed(id, values = {}) {
  await db.collection("canonical_songs").doc(id).set({
    id,
    title: values.title || "Song",
    artist: values.artist || "Artist",
    artists: [values.artist || "Artist"],
    album: values.album || null,
    releaseYear: values.releaseYear || null,
    durationMs: null,
    isrc: null,
    spotifyId: null,
    musicBrainzId: values.musicBrainzId || null,
    musicBrainzWorkId: null,
    iswc: null,
    normalizedTitle: values.normalizedTitle || "song",
    normalizedArtist: values.normalizedArtist || "artist",
    genres: [],
    disambiguation: null,
    schemaVersion: 1,
    canonicalRevision: values.canonicalRevision || 1,
    source: "manual",
    status: values.status || "active",
    createdBy: values.createdBy || "seed",
    baseKey: null,
    baseBpm: null,
    baseSections: [],
    baseAccentBeats: 4,
    baseRegularBeats: 1,
    baseBeatModes: [],
    baseLinks: [],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function clearCanonicalSongs() {
  const snapshot = await db.collection("canonical_songs").get();
  await Promise.all(snapshot.docs.map((doc) => doc.ref.delete()));
}

async function clearUsers() {
  const snapshot = await db.collection("users").get();
  await Promise.all(snapshot.docs.map((doc) => doc.ref.delete()));
}
