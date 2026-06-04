const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const { runDryRun } = require("../scripts/library-migration-dry-run");
const {
  parseArgs,
  runWriteRun,
} = require("../scripts/library-migration-write-run");

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error(
    "Refusing to run migration write-run tests without FIRESTORE_EMULATOR_HOST. " +
      "Use `npm run test:migration:write-run` so Firebase starts the emulator.",
  );
}

const projectId = "repsync-app-migration-write-test";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || projectId;
process.env.FIREBASE_CONFIG = process.env.FIREBASE_CONFIG ||
  JSON.stringify({ projectId });

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

const db = admin.firestore();

describe("library migration write run", function () {
  this.timeout(20000);

  beforeEach(async () => {
    await clearSeededData();
  });

  after(async () => {
    await clearSeededData();
  });

  it("validates exact candidates without writing when --execute is omitted", async () => {
    await seedCanonical("canonical-mb", { musicBrainzId: "mb-preview" });
    await seedUserSong("user-1", "legacy-preview", {
      title: "Preview Song",
      artist: "Artist",
      musicbrainzId: "mb-preview",
    });
    const dryRun = await runDryRun({ db, sampleLimit: 10 });

    const writeReport = await runWriteRun({ db, inputReport: dryRun });
    const songDoc = await db
      .collection("users")
      .doc("user-1")
      .collection("songs")
      .doc("legacy-preview")
      .get();
    const commits = await db.collectionGroup("commits").get();

    assert.equal(writeReport.writesEnabled, false);
    assert.equal(writeReport.counts.validatedOnly, 1);
    assert.equal(writeReport.counts.converted, 0);
    assert.equal(songDoc.data().schemaVersion, undefined);
    assert.equal(commits.size, 0);
  });

  it("converts exact candidates to v2 library songs and initial commits", async () => {
    await seedCanonical("canonical-mb", {
      musicBrainzId: "mb-convert",
      baseKey: "G",
      baseBpm: 120,
      baseAccentBeats: 4,
      baseRegularBeats: 1,
    });
    await seedUserSong("user-1", "legacy-convert", {
      title: "Legacy Title",
      artist: "Legacy Artist",
      musicbrainzId: "mb-convert",
      ourKey: "A",
      ourBPM: 124,
      notes: "Singer prefers this up a step.",
      tags: ["live"],
    });
    const dryRun = await runDryRun({ db, sampleLimit: 10 });

    const writeReport = await runWriteRun({
      db,
      inputReport: dryRun,
      execute: true,
      now: new Date("2026-06-04T12:00:00.000Z"),
    });
    const songDoc = await db
      .collection("users")
      .doc("user-1")
      .collection("songs")
      .doc("legacy-convert")
      .get();
    const data = songDoc.data();
    const commits = await songDoc.ref.collection("commits").get();
    const commitData = commits.docs[0].data();

    assert.equal(writeReport.counts.converted, 1);
    assert.equal(data.id, "legacy-convert");
    assert.equal(data.schemaVersion, 2);
    assert.equal(data.canonicalSongId, "canonical-mb");
    assert.equal(data.ownerType, "user");
    assert.equal(data.ownerId, "user-1");
    assert.equal(data.baseRevision, 1);
    assert.equal(data.delta.ourKey, "A");
    assert.equal(data.delta.ourBPM, 124);
    assert.equal(data.delta.notes, "Singer prefers this up a step.");
    assert.deepEqual(data.delta.tags, ["live"]);
    assert.equal(data.materialized.title, "Legacy Title");
    assert.equal(data.materialized.canonicalSongId, "canonical-mb");
    assert.equal(data.materialized.libraryBaseRevision, 1);
    assert.equal(data.latestCommitId, commitData.id);
    assert.equal(commits.size, 1);
    assert.equal(commitData.operation, "create");
    assert.equal(commitData.authorId, "migration:library-v2");
    assert.equal(commitData.canonicalSongId, "canonical-mb");
    assert.deepEqual(commitData.delta, data.delta);
  });

  it("sets band ownership metadata for band song conversions", async () => {
    await seedCanonical("canonical-band", { spotifyId: "spotify-band" });
    await seedBandSong("band-1", "legacy-band", {
      title: "Band Song",
      artist: "Artist",
      spotifyId: "spotify-band",
    });
    const dryRun = await runDryRun({ db, sampleLimit: 10 });

    await runWriteRun({ db, inputReport: dryRun, execute: true });
    const songDoc = await db
      .collection("bands")
      .doc("band-1")
      .collection("songs")
      .doc("legacy-band")
      .get();
    const data = songDoc.data();

    assert.equal(data.ownerType, "band");
    assert.equal(data.ownerId, "band-1");
    assert.equal(data.materialized.bandId, "band-1");
  });

  it("is idempotent when a candidate was already converted", async () => {
    await seedCanonical("canonical-mb", { musicBrainzId: "mb-idempotent" });
    await seedUserSong("user-1", "legacy-idempotent", {
      title: "Idempotent Song",
      artist: "Artist",
      musicbrainzId: "mb-idempotent",
    });
    const dryRun = await runDryRun({ db, sampleLimit: 10 });
    await runWriteRun({ db, inputReport: dryRun, execute: true });

    const secondReport = await runWriteRun({
      db,
      inputReport: dryRun,
      execute: true,
    });
    const commits = await db.collectionGroup("commits").get();

    assert.equal(secondReport.counts.alreadyV2Skipped, 1);
    assert.equal(secondReport.counts.converted, 0);
    assert.equal(commits.size, 1);
  });

  it("honors the batch limit and reports unprocessed exact candidates", async () => {
    await seedCanonical("canonical-one", { musicBrainzId: "mb-one" });
    await seedCanonical("canonical-two", { musicBrainzId: "mb-two" });
    await seedUserSong("user-1", "legacy-one", {
      title: "One",
      artist: "Artist",
      musicbrainzId: "mb-one",
    });
    await seedUserSong("user-1", "legacy-two", {
      title: "Two",
      artist: "Artist",
      musicbrainzId: "mb-two",
    });
    const dryRun = await runDryRun({ db, sampleLimit: 10 });

    const writeReport = await runWriteRun({
      db,
      inputReport: dryRun,
      limit: 1,
    });

    assert.equal(writeReport.counts.exactCandidatesRead, 2);
    assert.equal(writeReport.counts.validatedOnly, 1);
    assert.equal(writeReport.counts.notProcessedDueToLimit, 1);
  });

  it("rejects stale dry-run reports before validating candidates", async () => {
    await seedCanonical("canonical-mb", { musicBrainzId: "mb-stale" });
    await seedUserSong("user-1", "legacy-stale", {
      title: "Stale Song",
      artist: "Artist",
      musicbrainzId: "mb-stale",
    });
    const dryRun = await runDryRun({ db, sampleLimit: 10 });
    dryRun.generatedAt = "2026-06-01T00:00:00.000Z";

    await assert.rejects(
      () => runWriteRun({
        db,
        inputReport: dryRun,
        maxReportAgeHours: 24,
        now: new Date("2026-06-04T00:00:00.000Z"),
      }),
      /stale/,
    );
  });

  it("rejects truncated exact-candidate dry-run reports", async () => {
    await seedCanonical("canonical-one", { musicBrainzId: "mb-truncated-one" });
    await seedCanonical("canonical-two", { musicBrainzId: "mb-truncated-two" });
    await seedUserSong("user-1", "legacy-truncated-one", {
      title: "Truncated One",
      artist: "Artist",
      musicbrainzId: "mb-truncated-one",
    });
    await seedUserSong("user-1", "legacy-truncated-two", {
      title: "Truncated Two",
      artist: "Artist",
      musicbrainzId: "mb-truncated-two",
    });
    const dryRun = await runDryRun({ db, sampleLimit: 1 });

    await assert.rejects(
      () => runWriteRun({ db, inputReport: dryRun }),
      /exact candidates are truncated/,
    );

    assert.equal(dryRun.counts.exactExternalIdLinkedCandidates, 2);
    assert.equal(dryRun.samplesTruncated.exactExternalIdLinkedCandidates, true);
  });

  it("skips candidates when current external IDs no longer match", async () => {
    await seedCanonical("canonical-original", { musicBrainzId: "mb-original" });
    await seedCanonical("canonical-new", { musicBrainzId: "mb-new" });
    await seedUserSong("user-1", "legacy-changed", {
      title: "Changed Song",
      artist: "Artist",
      musicbrainzId: "mb-original",
    });
    const dryRun = await runDryRun({ db, sampleLimit: 10 });
    await seedUserSong("user-1", "legacy-changed", {
      title: "Changed Song",
      artist: "Artist",
      musicbrainzId: "mb-new",
    });

    const writeReport = await runWriteRun({
      db,
      inputReport: dryRun,
      execute: true,
    });
    const songDoc = await db
      .collection("users")
      .doc("user-1")
      .collection("songs")
      .doc("legacy-changed")
      .get();

    assert.equal(writeReport.counts.canonicalMismatch, 1);
    assert.equal(songDoc.data().schemaVersion, undefined);
  });

  it("skips legacy docs whose data id does not match the document id", async () => {
    await seedCanonical("canonical-mb", { musicBrainzId: "mb-id-mismatch" });
    await db
      .collection("users")
      .doc("user-1")
      .collection("songs")
      .doc("legacy-doc-id")
      .set(song("different-data-id", {
        title: "Mismatch Song",
        artist: "Artist",
        musicbrainzId: "mb-id-mismatch",
      }));
    const dryRun = await runDryRun({ db, sampleLimit: 10 });

    const writeReport = await runWriteRun({
      db,
      inputReport: dryRun,
      execute: true,
    });

    assert.equal(writeReport.counts.idMismatch, 1);
    assert.equal(writeReport.counts.converted, 0);
  });

  it("does not process normalized review or ambiguous candidates", async () => {
    const report = {
      mode: "dry-run",
      writesEnabled: false,
      generatedAt: new Date().toISOString(),
      exactExternalIdLinkedCandidates: [],
      normalizedReviewCandidates: [{ path: "users/user-1/songs/normalized" }],
      ambiguousMatches: [{ path: "users/user-1/songs/ambiguous" }],
    };

    const writeReport = await runWriteRun({ db, inputReport: report });

    assert.equal(writeReport.counts.nonExactCandidatesSkipped, 2);
    assert.equal(writeReport.counts.validatedOnly, 0);
    assert.equal(writeReport.counts.converted, 0);
  });

  it("parses write-run CLI options", () => {
    assert.deepEqual(
      parseArgs([
        "--input",
        "dry-run.json",
        "--out",
        "write.json",
        "--limit",
        "50",
        "--execute",
        "--project",
        "project-1",
        "--max-report-age-hours",
        "12.5",
      ]),
      {
        input: "dry-run.json",
        out: "write.json",
        limit: 50,
        execute: true,
        project: "project-1",
        maxReportAgeHours: 12.5,
      },
    );
    assert.throws(() => parseArgs(["--out", "x.json"]), /--input/);
    assert.deepEqual(
      parseArgs(["--input", "dry-run.json", "--out", "write.json"]),
      {
        input: "dry-run.json",
        out: "write.json",
        limit: null,
        execute: false,
        project: null,
        maxReportAgeHours: 24,
      },
    );
    assert.throws(
      () => parseArgs([
        "--input",
        "dry-run.json",
        "--out",
        "write.json",
        "--execute",
      ]),
      /--project is required/,
    );
    assert.throws(
      () => parseArgs(["--input", "x.json", "--out", "y.json", "--limit", "-1"]),
      /non-negative integer/,
    );
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
    canonicalRevision: values.canonicalRevision || 1,
    source: "manual",
    status: "active",
    baseKey: values.baseKey || null,
    baseBpm: values.baseBpm || null,
    baseSections: values.baseSections || [],
    baseAccentBeats: values.baseAccentBeats || 4,
    baseRegularBeats: values.baseRegularBeats || 1,
    baseBeatModes: values.baseBeatModes || [],
    baseLinks: values.baseLinks || [],
    musicBrainzId: values.musicBrainzId
      ? values.musicBrainzId.trim().toLowerCase()
      : null,
    musicBrainzWorkId: values.musicBrainzWorkId || null,
    isrc: values.isrc
      ? values.isrc.replace(/[^a-z0-9]/gi, "").toUpperCase()
      : null,
    spotifyId: values.spotifyId || null,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
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
    accentBeats: 4,
    regularBeats: 1,
    beatModes: [],
    links: [],
    sections: [],
    tags: [],
    ...values,
  };
}

async function clearSeededData() {
  await deleteQuery(await db.collectionGroup("commits").get());
  await deleteQuery(await db.collectionGroup("songs").get());
  await deleteQuery(await db.collection("canonical_songs").get());
  await deleteQuery(await db.collection("users").get());
  await deleteQuery(await db.collection("bands").get());
}

async function deleteQuery(snapshot) {
  await Promise.all(snapshot.docs.map((doc) => doc.ref.delete()));
}
