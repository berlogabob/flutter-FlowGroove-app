const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const admin = require("firebase-admin");
const {
  parseArgs,
  runDryRun,
  writeReportFiles,
} = require("../scripts/library-migration-dry-run");

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

  it("writes JSON and review CSV artifacts", async () => {
    await seedCanonical("canonical-mb", { musicBrainzId: "mb-1" });
    await seedCanonical("canonical-ambiguous-a", { isrc: "isrc-ambiguous" });
    await seedCanonical("canonical-ambiguous-b", { isrc: "isrc-ambiguous" });
    await seedUserSong("user-1", "legacy-mb", {
      title: "MusicBrainz Song",
      artist: "Artist",
      musicbrainzId: "mb-1",
    });
    await seedUserSong("user-1", "ambiguous", {
      title: "Ambiguous Song",
      artist: "Artist",
      isrc: "isrc-ambiguous",
    });
    await seedUserSong("user-1", "standalone", {
      title: "Private, Quoted Song",
      artist: "Me",
    });

    const outputDir = await fs.mkdtemp(
      path.join(os.tmpdir(), "library-migration-dry-run-"),
    );
    const out = path.join(outputDir, "report.json");
    const csvDir = path.join(outputDir, "csv");
    const report = await runDryRun({ db, sampleLimit: 50 });

    await writeReportFiles({ report, out, csvDir });

    const writtenReport = JSON.parse(await fs.readFile(out, "utf8"));
    const exactCsv = await fs.readFile(
      path.join(csvDir, "exact-candidates.csv"),
      "utf8",
    );
    const ambiguousCsv = await fs.readFile(
      path.join(csvDir, "ambiguous-matches.csv"),
      "utf8",
    );
    const standaloneCsv = await fs.readFile(
      path.join(csvDir, "standalone-no-external-id.csv"),
      "utf8",
    );

    assert.equal(writtenReport.writesEnabled, false);
    assert.equal(writtenReport.counts.exactExternalIdLinkedCandidates, 1);
    assert.match(exactCsv, /path,ownerType,ownerId,songId,title,artist/);
    assert.match(exactCsv, /users\/user-1\/songs\/legacy-mb/);
    assert.match(ambiguousCsv, /canonical-ambiguous-a/);
    assert.match(ambiguousCsv, /canonical-ambiguous-b/);
    assert.match(standaloneCsv, /"Private, Quoted Song"/);
  });

  it("parses dry-run CLI options", () => {
    assert.deepEqual(
      parseArgs([
        "--out",
        "report.json",
        "--csv-dir",
        "review",
        "--sample-limit",
        "100",
      ]),
      {
        out: "report.json",
        csvDir: "review",
        sampleLimit: 100,
      },
    );
    assert.throws(
      () => parseArgs(["--sample-limit", "-1"]),
      /non-negative integer/,
    );
    assert.throws(() => parseArgs(["--out"]), /requires a value/);
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
