const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const functionsTestFactory = require("firebase-functions-test");

const projectId = "repsync-app-callable-test";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || projectId;
process.env.FIREBASE_CONFIG = process.env.FIREBASE_CONFIG ||
  JSON.stringify({ projectId });

const functionsTest = functionsTestFactory({ projectId });
const canonical = require("../src/canonical");
const wrappedEnsureCanonicalSong = functionsTest.wrap(
  canonical.ensureCanonicalSong,
);
const db = admin.firestore();

describe("ensureCanonicalSong callable", function () {
  this.timeout(20000);

  after(async () => {
    await clearCanonicalSongs();
    functionsTest.cleanup();
  });

  beforeEach(async () => {
    await clearCanonicalSongs();
  });

  it("rejects unauthenticated callers", async () => {
    await assert.rejects(
      () => wrappedEnsureCanonicalSong({ title: "Song", artist: "Artist" }),
      (error) => error.code === "unauthenticated",
    );
  });

  it("rejects demo users", async () => {
    await assert.rejects(
      () => wrappedEnsureCanonicalSong(
        { title: "Song", artist: "Artist" },
        authContext("demo-user", { demo: true }),
      ),
      (error) => error.code === "failed-precondition",
    );
  });

  it("looks up exact external ids in MusicBrainz, ISRC, then Spotify order", async () => {
    await seedCanonicalSong("canonical-mb", {
      musicBrainzId: "mb-1",
      canonicalRevision: 3,
    });
    await seedCanonicalSong("canonical-isrc", {
      isrc: "isrc-1",
      canonicalRevision: 4,
    });
    await seedCanonicalSong("canonical-spotify", {
      spotifyId: "spotify-1",
      canonicalRevision: 5,
    });

    assert.deepEqual(
      await callEnsure({
        title: "Different",
        artist: "Different",
        musicBrainzId: "mb-1",
        isrc: "isrc-1",
        spotifyId: "spotify-1",
      }),
      { canonicalSongId: "canonical-mb", canonicalRevision: 3 },
    );
    assert.deepEqual(
      await callEnsure({ title: "Different", artist: "Different", isrc: "isrc-1" }),
      { canonicalSongId: "canonical-isrc", canonicalRevision: 4 },
    );
    assert.deepEqual(
      await callEnsure({
        title: "Different",
        artist: "Different",
        spotifyId: "spotify-1",
      }),
      { canonicalSongId: "canonical-spotify", canonicalRevision: 5 },
    );
  });

  it("falls back to normalized title and artist lookup", async () => {
    await seedCanonicalSong("canonical-normalized", {
      title: "Bohemian Rhapsody",
      artist: "Queen",
      normalizedTitle: "bohemian rhapsody",
      normalizedArtist: "queen",
      canonicalRevision: 8,
    });

    const result = await callEnsure({
      title: "  Bohemian Rhapsody!!! ",
      artist: " Queen ",
    });

    assert.deepEqual(result, {
      canonicalSongId: "canonical-normalized",
      canonicalRevision: 8,
    });
    assert.equal(await canonicalSongCount(), 1);
  });

  it("creates a canonical song with Dart-compatible schema defaults", async () => {
    const result = await callEnsure({
      title: "  New Song! ",
      artist: " New Artist ",
      musicBrainzId: "mb-new",
      album: "First Album",
      durationMs: 123456,
    });

    assert.equal(result.canonicalRevision, 1);
    assert.ok(result.canonicalSongId);

    const created = await db
      .collection("canonical_songs")
      .doc(result.canonicalSongId)
      .get();
    assert.equal(created.exists, true);
    assert.deepEqual(created.data(), {
      id: result.canonicalSongId,
      title: "New Song!",
      artist: "New Artist",
      artists: ["New Artist"],
      album: "First Album",
      releaseYear: null,
      durationMs: 123456,
      isrc: null,
      spotifyId: null,
      musicBrainzId: "mb-new",
      musicBrainzWorkId: null,
      iswc: null,
      normalizedTitle: "new song",
      normalizedArtist: "new artist",
      genres: [],
      disambiguation: null,
      schemaVersion: 1,
      canonicalRevision: 1,
      source: "musicbrainz",
      status: "active",
      createdBy: "user-1",
      baseKey: null,
      baseBpm: null,
      baseSections: [],
      baseAccentBeats: 4,
      baseRegularBeats: 1,
      baseBeatModes: [],
      baseLinks: [],
      createdAt: created.data().createdAt,
      updatedAt: created.data().updatedAt,
    });
  });
});

function authContext(uid, token = {}) {
  return { auth: { uid, token } };
}

function callEnsure(payload) {
  return wrappedEnsureCanonicalSong(payload, authContext("user-1"));
}

async function seedCanonicalSong(id, values = {}) {
  await db.collection("canonical_songs").doc(id).set({
    id,
    title: values.title || "Song",
    artist: values.artist || "Artist",
    artists: [values.artist || "Artist"],
    album: null,
    durationMs: null,
    musicBrainzId: values.musicBrainzId || null,
    isrc: values.isrc || null,
    spotifyId: values.spotifyId || null,
    normalizedTitle: values.normalizedTitle || "song",
    normalizedArtist: values.normalizedArtist || "artist",
    schemaVersion: 1,
    canonicalRevision: values.canonicalRevision || 1,
    source: "manual",
    status: "active",
    createdBy: "seed",
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

async function canonicalSongCount() {
  const snapshot = await db.collection("canonical_songs").get();
  return snapshot.size;
}
