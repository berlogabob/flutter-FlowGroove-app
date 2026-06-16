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

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error(
    "Refusing to run migration dry-run tests without FIRESTORE_EMULATOR_HOST. " +
      "Use `npm run test:migration:dry-run` so Firebase starts the emulator.",
  );
}

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
    await seedCanonical("canonical-normalized", {
      title: "Normalized Song",
      artist: "Review Artist",
      normalizedTitle: "normalized song",
      normalizedArtist: "review artist",
    });

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
    await seedUserSong("user-1", "normalized-review", {
      title: "Normalized Song!",
      artist: "Review Artist",
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
      totalSongsScanned: 7,
      totalLegacySongsScanned: 6,
      exactExternalIdLinkedCandidates: 2,
      normalizedReviewCandidates: 1,
      alreadyV2Skipped: 1,
      standaloneNoExternalId: 1,
      unknownOwnerSongs: 0,
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
    await seedCanonical("canonical-normalized", {
      title: "Private, Quoted Song",
      artist: "Me",
      normalizedTitle: "private quoted song",
      normalizedArtist: "me",
    });
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
    const normalizedCsv = await fs.readFile(
      path.join(csvDir, "normalized-review-candidates.csv"),
      "utf8",
    );
    const standaloneCsv = await fs.readFile(
      path.join(csvDir, "standalone-no-external-id.csv"),
      "utf8",
    );

    assert.equal(writtenReport.writesEnabled, false);
    assert.equal(writtenReport.counts.exactExternalIdLinkedCandidates, 1);
    assert.equal(writtenReport.fullCsvRows, undefined);
    assert.equal(writtenReport.csvExports.rowSource, "full-review-manifest");
    assert.match(exactCsv, /path,ownerType,ownerId,songId,title,artist/);
    assert.match(exactCsv, /users\/user-1\/songs\/legacy-mb/);
    assert.match(ambiguousCsv, /canonical-ambiguous-a/);
    assert.match(ambiguousCsv, /canonical-ambiguous-b/);
    assert.match(normalizedCsv, /"Private, Quoted Song"/);
    assert.match(normalizedCsv, /canonical-normalized/);
    assert.match(standaloneCsv, /^path,ownerType,ownerId/m);
  });

  it("classifies conflicting external-id matches as ambiguous", async () => {
    await seedCanonical("canonical-mb", { musicBrainzId: "mb-conflict" });
    await seedCanonical("canonical-spotify", { spotifyId: "spotify-conflict" });
    await seedUserSong("user-1", "conflicting", {
      title: "Conflicting Song",
      artist: "Artist",
      musicBrainzId: "mb-conflict",
      spotifyId: "spotify-conflict",
    });

    const report = await runDryRun({ db, sampleLimit: 10 });

    assert.equal(report.counts.exactExternalIdLinkedCandidates, 0);
    assert.equal(report.counts.ambiguousMatches, 1);
    assert.deepEqual(report.ambiguousMatches[0].canonicalSongIds, [
      "canonical-mb",
      "canonical-spotify",
    ]);
    assert.equal(
      report.ambiguousMatches[0].matchedBy,
      "musicBrainzId|spotifyId",
    );
  });

  it("normalizes external IDs before matching canonical songs", async () => {
    await seedCanonical("canonical-mb", {
      musicBrainzId: "550e8400-e29b-41d4-a716-446655440000",
    });
    await seedCanonical("canonical-isrc", { isrc: "USRC17607839" });
    await seedCanonical("canonical-spotify", {
      spotifyId: "4uLU6hMCjMI75M1A2tKUQC",
    });
    await seedUserSong("user-1", "mb-normalized", {
      title: "MusicBrainz Normalized",
      artist: "Artist",
      musicbrainzId: "  550E8400-E29B-41D4-A716-446655440000  ",
    });
    await seedUserSong("user-1", "isrc-normalized", {
      title: "ISRC Normalized",
      artist: "Artist",
      isrc: " us-rc1-76-07839 ",
    });
    await seedUserSong("user-1", "spotify-url", {
      title: "Spotify URL",
      artist: "Artist",
      spotifyId: "https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC?si=abc",
    });
    await seedUserSong("user-1", "spotify-uri", {
      title: "Spotify URI",
      artist: "Artist",
      spotifyId: " spotify:track:4uLU6hMCjMI75M1A2tKUQC ",
    });

    const report = await runDryRun({ db, sampleLimit: 10 });

    assert.equal(report.counts.exactExternalIdLinkedCandidates, 4);
    assert.deepEqual(
      report.exactExternalIdLinkedCandidates
        .map((item) => item.canonicalSongId)
        .sort(),
      [
        "canonical-isrc",
        "canonical-mb",
        "canonical-spotify",
        "canonical-spotify",
      ],
    );
    assert.match(
      report.exactExternalIdLinkedCandidates.find((item) => {
        return item.canonicalSongId === "canonical-isrc";
      }).matchedValue,
      /USRC17607839/,
    );
  });

  it("separates unknown owner song paths from migration candidates", async () => {
    await seedCanonical("canonical-mb", { musicBrainzId: "mb-unknown-owner" });
    await db
      .collection("shared_libraries")
      .doc("shared-1")
      .collection("songs")
      .doc("unknown-owner")
      .set(song("unknown-owner", {
        title: "Unknown Owner",
        artist: "Artist",
        musicBrainzId: "mb-unknown-owner",
      }));

    const report = await runDryRun({ db, sampleLimit: 10 });

    assert.equal(report.counts.unknownOwnerSongs, 1);
    assert.equal(report.counts.exactExternalIdLinkedCandidates, 0);
    assert.equal(report.unknownOwnerSongs[0].ownerType, "unknown");
    assert.equal(
      report.unknownOwnerSongs[0].path,
      "shared_libraries/shared-1/songs/unknown-owner",
    );
  });

  it("keeps JSON samples bounded while writing full CSV manifests", async () => {
    await seedUserSong("user-1", "standalone-1", {
      title: "Standalone One",
      artist: "Me",
    });
    await seedUserSong("user-1", "standalone-2", {
      title: "Standalone Two",
      artist: "Me",
    });
    await seedUserSong("user-1", "standalone-3", {
      title: "Standalone Three",
      artist: "Me",
    });

    const outputDir = await fs.mkdtemp(
      path.join(os.tmpdir(), "library-migration-dry-run-"),
    );
    const out = path.join(outputDir, "report.json");
    const csvDir = path.join(outputDir, "csv");
    const report = await runDryRun({ db, sampleLimit: 1 });

    await writeReportFiles({ report, out, csvDir });

    const writtenReport = JSON.parse(await fs.readFile(out, "utf8"));
    const standaloneCsv = await fs.readFile(
      path.join(csvDir, "standalone-no-external-id.csv"),
      "utf8",
    );

    assert.equal(writtenReport.standaloneNoExternalId.length, 1);
    assert.equal(writtenReport.counts.standaloneNoExternalId, 3);
    assert.equal(writtenReport.samplesTruncated.standaloneNoExternalId, true);
    assert.equal(writtenReport.fullCsvRows, undefined);
    assert.equal(
      standaloneCsv.trim().split("\n").filter((line) => {
        return line.includes("users/user-1/songs/standalone-");
      }).length,
      3,
    );
  });

  it("writes full unmatched and failed CSV exports", async () => {
    await seedUserSong("user-1", "unmatched-1", {
      title: "Unmatched One",
      artist: "Artist",
      isrc: "USRC17607839",
    });
    await seedUserSong("user-1", "unmatched-2", {
      title: "Unmatched Two",
      artist: "Artist",
      spotifyId: "spotify-missing",
    });
    const report = await runDryRun({ db, sampleLimit: 1 });
    const fakeReport = await runDryRun({
      db: failingDb("broken/path/songs/broken-song"),
      sampleLimit: 1,
    });
    report.counts.failedReadsOrParses += fakeReport.counts.failedReadsOrParses;
    report.failed.push(...fakeReport.failed);
    report.fullCsvRows.failed.push(...fakeReport.fullCsvRows.failed);

    const outputDir = await fs.mkdtemp(
      path.join(os.tmpdir(), "library-migration-dry-run-"),
    );
    const csvDir = path.join(outputDir, "csv");
    await writeReportFiles({ report, csvDir });

    const unmatchedCsv = await fs.readFile(
      path.join(csvDir, "unmatched-external-id.csv"),
      "utf8",
    );
    const failedCsv = await fs.readFile(path.join(csvDir, "failed.csv"), "utf8");

    assert.equal(report.unmatchedExternalId.length, 1);
    assert.equal(report.counts.unmatchedExternalId, 2);
    assert.match(unmatchedCsv, /users\/user-1\/songs\/unmatched-1/);
    assert.match(unmatchedCsv, /users\/user-1\/songs\/unmatched-2/);
    assert.match(failedCsv, /broken\/path\/songs\/broken-song/);
    assert.match(failedCsv, /boom/);
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
    title: values.title || id,
    artist: values.artist || "Artist",
    normalizedTitle: values.normalizedTitle || id,
    normalizedArtist: values.normalizedArtist || "artist",
    schemaVersion: 1,
    canonicalRevision: 1,
    source: "manual",
    status: "active",
    musicBrainzId: values.musicBrainzId
      ? values.musicBrainzId.trim().toLowerCase()
      : null,
    isrc: values.isrc
      ? values.isrc.replace(/[^a-z0-9]/gi, "").toUpperCase()
      : null,
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
  await deleteQuery(await db.collection("shared_libraries").get());
}

async function deleteQuery(snapshot) {
  await Promise.all(snapshot.docs.map((doc) => doc.ref.delete()));
}

function failingDb(docPath) {
  return {
    collectionGroup() {
      return {
        async get() {
          return {
            docs: [
              {
                id: "broken-song",
                ref: { path: docPath },
                data() {
                  throw new Error("boom");
                },
              },
            ],
          };
        },
      };
    },
  };
}
