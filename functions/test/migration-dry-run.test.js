const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const { runDryRun } = require("../scripts/library-migration-dry-run");

const projectId = "repsync-app-migration-test";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || projectId;
process.env.FIREBASE_CONFIG = process.env.FIREBASE_CONFIG ||
  JSON.stringify({ projectId });

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

const db = admin.firestore();

describe("library migration dry run", function () {
  this.timeout(20000);

  beforeEach(async () => {
    await clearSeededData();
  });

  after(async () => {
    await clearSeededData();
  });

  it("reports exact external-id candidates without writing migration data", async () => {
    await seedCanonical("canonical-mb", { musicBrainzId: "mb-1" });
    await seedCanonical("canonical-spotify", { spotifyId: "spotify-1" });
    await seedCanonical("canonical-ambiguous-a", { isrc: "isrc-ambiguous" });
    await seedCanonical("canonical-ambiguous-b", { isrc: "isrc-ambiguous" });

    await seedUserSong("user-1", "legacy-mb", {
      title: "MusicBrainz Song",
      artist: "Artist",
      musicbrainzId: "mb-1",
    });
    await seedBandSong("band-1", "legacy-spotify", {
      title: "Spotify Song",
      artist: "Artist",
      spotifyId: "spotify-1",
    });
    await seedUserSong("user-1", "standalone", {
      title: "Private Song",
      artist: "Me",
    });
    await seedUserSong("user-1", "ambiguous", {
      title: "Ambiguous Song",
      artist: "Artist",
      isrc: "isrc-ambiguous",
    });
    await seedUserSong("user-1", "unmatched", {
      title: "Unmatched Song",
      artist: "Artist",
      isrc: "isrc-missing",
    });
    await seedUserSong("user-1", "already-v2", {
      schemaVersion: 2,
      canonicalSongId: "canonical-mb",
      ownerType: "user",
      ownerId: "user-1",
      baseRevision: 1,
      delta: {},
      materialized: {
        id: "already-v2",
        title: "Linked",
        artist: "Artist",
      },
      latestCommitId: "commit-1",
    });

    const beforeDocs = await db.collectionGroup("songs").get();
    const report = await runDryRun({ db, sampleLimit: 10 });
    const afterDocs = await db.collectionGroup("songs").get();
    const commits = await db.collectionGroup("commits").get();

    assert.equal(afterDocs.size, beforeDocs.size);
    assert.equal(commits.size, 0);
    assert.deepEqual(report.counts, {
      totalSongsScanned: 6,
      totalLegacySongsScanned: 5,
      exactExternalIdLinkedCandidates: 2,
      alreadyV2Skipped: 1,
      standaloneNoExternalId: 1,
      ambiguousMatches: 1,
      unmatchedExternalId: 1,
      failedReadsOrParses: 0,
    });
    assert.equal(report.writesEnabled, false);
    assert.deepEqual(
      report.exactExternalIdLinkedCandidates.map((item) => ({
        path: item.path,
        matchedBy: item.matchedBy,
        canonicalSongId: item.canonicalSongId,
      })).sort((a, b) => a.path.localeCompare(b.path)),
      [
        {
          path: "bands/band-1/songs/legacy-spotify",
          matchedBy: "spotifyId",
          canonicalSongId: "canonical-spotify",
        },
        {
          path: "users/user-1/songs/legacy-mb",
          matchedBy: "musicBrainzId",
          canonicalSongId: "canonical-mb",
        },
      ],
    );
  });
});

async function seedCanonical(id, values) {
  await db.collection("canonical_songs").doc(id).set({
    id,
    title: id,
    artist: "Artist",
    normalizedTitle: id,
    normalizedArtist: "artist",
    schemaVersion: 1,
    canonicalRevision: 1,
    source: "manual",
    status: "active",
    musicBrainzId: values.musicBrainzId || null,
    isrc: values.isrc || null,
    spotifyId: values.spotifyId || null,
  });
}

async function seedUserSong(userId, songId, values) {
  await db
    .collection("users")
    .doc(userId)
    .collection("songs")
    .doc(songId)
    .set(song(songId, values));
}

async function seedBandSong(bandId, songId, values) {
  await db
    .collection("bands")
    .doc(bandId)
    .collection("songs")
    .doc(songId)
    .set(song(songId, values));
}

function song(id, values) {
  return {
    id,
    title: values.title || "Song",
    artist: values.artist || "Artist",
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    ...values,
  };
}

async function clearSeededData() {
  await deleteQuery(await db.collectionGroup("songs").get());
  await deleteQuery(await db.collectionGroup("commits").get());
  await deleteQuery(await db.collection("canonical_songs").get());
  await deleteQuery(await db.collection("users").get());
  await deleteQuery(await db.collection("bands").get());
}

async function deleteQuery(snapshot) {
  await Promise.all(snapshot.docs.map((doc) => doc.ref.delete()));
}
