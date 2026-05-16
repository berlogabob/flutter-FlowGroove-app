const admin = require("firebase-admin");
const fs = require("node:fs/promises");
const path = require("node:path");

const DEFAULT_SAMPLE_LIMIT = 25;
const CSV_EXPORTS = [
  [
    "exact-candidates.csv",
    "exactExternalIdLinkedCandidates",
    [
      "path",
      "ownerType",
      "ownerId",
      "songId",
      "title",
      "artist",
      "matchedBy",
      "matchedValue",
      "canonicalSongId",
      "canonicalRevision",
    ],
  ],
  [
    "ambiguous-matches.csv",
    "ambiguousMatches",
    [
      "path",
      "ownerType",
      "ownerId",
      "songId",
      "title",
      "artist",
      "matchedBy",
      "matchedValue",
      "canonicalSongIds",
    ],
  ],
  [
    "unmatched-external-id.csv",
    "unmatchedExternalId",
    [
      "path",
      "ownerType",
      "ownerId",
      "songId",
      "title",
      "artist",
      "externalIds",
    ],
  ],
  [
    "standalone-no-external-id.csv",
    "standaloneNoExternalId",
    ["path", "ownerType", "ownerId", "songId", "title", "artist"],
  ],
  ["failed.csv", "failed", ["path", "error"]],
];

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

async function writeReportFiles({ report, out, csvDir }) {
  if (out) {
    await fs.mkdir(path.dirname(path.resolve(out)), { recursive: true });
    await fs.writeFile(out, `${JSON.stringify(report, null, 2)}\n`);
  }

  if (csvDir) {
    await fs.mkdir(csvDir, { recursive: true });
    await Promise.all(
      CSV_EXPORTS.map(([fileName, key, fields]) => {
        return fs.writeFile(
          path.join(csvDir, fileName),
          toCsv(report[key], fields),
        );
      }),
    );
  }
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
    pushSample(
      report,
      report.standaloneNoExternalId,
      sampleSong(doc, data, owner),
    );
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
  if (
    segments.length >= 4 &&
    segments[0] === "users" &&
    segments[2] === "songs"
  ) {
    return { ownerType: "user", ownerId: segments[1] };
  }
  if (
    segments.length >= 4 &&
    segments[0] === "bands" &&
    segments[2] === "songs"
  ) {
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
  const options = parseArgs(process.argv.slice(2));
  runDryRun({
    sampleLimit: options.sampleLimit,
    logger: options.out ? null : console.log,
  })
    .then(async (report) => {
      await writeReportFiles({
        report,
        out: options.out,
        csvDir: options.csvDir,
      });
      if (options.out) {
        console.log(`Wrote migration dry-run report to ${options.out}`);
      }
      if (options.csvDir) {
        console.log(`Wrote migration review CSVs to ${options.csvDir}`);
      }
    })
    .catch((error) => {
      console.error(error);
      process.exitCode = 1;
    });
}

module.exports = {
  runDryRun,
  parseArgs,
  toCsv,
  writeReportFiles,
  externalIdsFromSong,
  isV2LinkedSong,
  ownerFromPath,
};

function parseArgs(args) {
  const options = {
    out: null,
    csvDir: null,
    sampleLimit: DEFAULT_SAMPLE_LIMIT,
  };

  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];
    const next = args[i + 1];
    if (arg === "--out") {
      options.out = requireValue(arg, next);
      i += 1;
    } else if (arg === "--csv-dir") {
      options.csvDir = requireValue(arg, next);
      i += 1;
    } else if (arg === "--sample-limit") {
      options.sampleLimit = parseSampleLimit(requireValue(arg, next));
      i += 1;
    } else if (arg === "--help" || arg === "-h") {
      printHelp();
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return options;
}

function requireValue(name, value) {
  if (!value || value.startsWith("--")) {
    throw new Error(`${name} requires a value.`);
  }
  return value;
}

function parseSampleLimit(value) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed) || parsed < 0) {
    throw new Error("--sample-limit must be a non-negative integer.");
  }
  return parsed;
}

function printHelp() {
  console.log(`Usage: node scripts/library-migration-dry-run.js [options]

Options:
  --out <path>            Write the JSON report to a file instead of stdout.
  --csv-dir <path>        Write review CSV files into a directory.
  --sample-limit <count>  Max rows per report category. Default: ${DEFAULT_SAMPLE_LIMIT}.
  --help                  Show this help.
`);
}

function toCsv(rows, fields) {
  const lines = [fields.join(",")];
  for (const row of rows) {
    lines.push(
      fields.map((field) => csvEscape(csvValue(row[field]))).join(","),
    );
  }
  return `${lines.join("\n")}\n`;
}

function csvValue(value) {
  if (value == null) return "";
  if (Array.isArray(value) || typeof value === "object") {
    return JSON.stringify(value);
  }
  return String(value);
}

function csvEscape(value) {
  if (/[",\n\r]/.test(value)) {
    return `"${value.replaceAll('"', '""')}"`;
  }
  return value;
}
