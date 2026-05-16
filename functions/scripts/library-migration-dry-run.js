const admin = require("firebase-admin");

const DEFAULT_SAMPLE_LIMIT = 25;

async function runDryRun({
  db,
  sampleLimit = DEFAULT_SAMPLE_LIMIT,
  logger = null,
} = {}) {
  const firestore = db || getFirestore();
  const report = newReport(sampleLimit);
  const songsSnapshot = await firestore.collectionGroup("songs").get();

  for (const doc of songsSnapshot.docs) {
    report.counts.totalSongsScanned += 1;
    try {
      await inspectSongDoc({ db: firestore, doc, report });
    } catch (error) {
      report.counts.failedReadsOrParses += 1;
      pushSample(report, report.failed, {
        path: doc.ref.path,
        error: error.message || String(error),
      });
    }
  }

  report.generatedAt = new Date().toISOString();
  if (logger) {
    logger(JSON.stringify(report, null, 2));
  }
  return report;
}

async function inspectSongDoc({ db, doc, report }) {
  const data = doc.data();
  if (!data || typeof data !== "object") {
    throw new Error("Song document data is not an object.");
  }

  if (isV2LinkedSong(data)) {
    report.counts.alreadyV2Skipped += 1;
    pushSample(report, report.alreadyV2Skipped, { path: doc.ref.path });
    return;
  }

  report.counts.totalLegacySongsScanned += 1;
  const owner = ownerFromPath(doc.ref.path);
  const externalIds = externalIdsFromSong(data);
  if (externalIds.length === 0) {
    report.counts.standaloneNoExternalId += 1;
    pushSample(report, report.standaloneNoExternalId, sampleSong(doc, data, owner));
    return;
  }

  for (const externalId of externalIds) {
    const matches = await findCanonicalMatches(db, externalId);
    if (matches.length === 1) {
      report.counts.exactExternalIdLinkedCandidates += 1;
      pushSample(report, report.exactExternalIdLinkedCandidates, {
        ...sampleSong(doc, data, owner),
        matchedBy: externalId.field,
        matchedValue: externalId.value,
        canonicalSongId: matches[0].id,
        canonicalRevision: matches[0].canonicalRevision,
      });
      return;
    }

    if (matches.length > 1) {
      report.counts.ambiguousMatches += 1;
      pushSample(report, report.ambiguousMatches, {
        ...sampleSong(doc, data, owner),
        matchedBy: externalId.field,
        matchedValue: externalId.value,
        canonicalSongIds: matches.map((match) => match.id),
      });
      return;
    }
  }

  report.counts.unmatchedExternalId += 1;
  pushSample(report, report.unmatchedExternalId, {
    ...sampleSong(doc, data, owner),
    externalIds,
  });
}

function getFirestore() {
  if (!admin.apps.length) {
    admin.initializeApp();
  }
  return admin.firestore();
}

function newReport(sampleLimit) {
  return {
    mode: "dry-run",
    writesEnabled: false,
    sampleLimit,
    generatedAt: null,
    counts: {
      totalSongsScanned: 0,
      totalLegacySongsScanned: 0,
      exactExternalIdLinkedCandidates: 0,
      alreadyV2Skipped: 0,
      standaloneNoExternalId: 0,
      ambiguousMatches: 0,
      unmatchedExternalId: 0,
      failedReadsOrParses: 0,
    },
    exactExternalIdLinkedCandidates: [],
    alreadyV2Skipped: [],
    standaloneNoExternalId: [],
    ambiguousMatches: [],
    unmatchedExternalId: [],
    failed: [],
  };
}

function isV2LinkedSong(data) {
  return data.schemaVersion === 2 &&
    typeof data.canonicalSongId === "string" &&
    data.canonicalSongId.length > 0;
}

function externalIdsFromSong(data) {
  return [
    {
      field: "musicBrainzId",
      value: cleanString(data.musicbrainzId || data.musicBrainzId),
    },
    { field: "isrc", value: cleanString(data.isrc) },
    { field: "spotifyId", value: cleanString(data.spotifyId) },
  ].filter((item) => item.value);
}

async function findCanonicalMatches(db, externalId) {
  const snapshot = await db
    .collection("canonical_songs")
    .where(externalId.field, "==", externalId.value)
    .get();

  return snapshot.docs.map((doc) => ({
    id: doc.id,
    canonicalRevision: doc.data().canonicalRevision || 1,
  }));
}

function ownerFromPath(path) {
  const segments = path.split("/");
  if (segments.length >= 4 && segments[0] === "users" && segments[2] === "songs") {
    return { ownerType: "user", ownerId: segments[1] };
  }
  if (segments.length >= 4 && segments[0] === "bands" && segments[2] === "songs") {
    return { ownerType: "band", ownerId: segments[1] };
  }
  return { ownerType: "unknown", ownerId: null };
}

function sampleSong(doc, data, owner) {
  return {
    path: doc.ref.path,
    ownerType: owner.ownerType,
    ownerId: owner.ownerId,
    songId: data.id || doc.id,
    title: data.title || null,
    artist: data.artist || null,
  };
}

function pushSample(report, samples, value) {
  if (samples.length < report.sampleLimit) {
    samples.push(value);
  }
}

function cleanString(value) {
  return typeof value === "string" ? value.trim() : "";
}

if (require.main === module) {
  runDryRun({ logger: console.log }).catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = {
  runDryRun,
  externalIdsFromSong,
  isV2LinkedSong,
  ownerFromPath,
};
