const admin = require("firebase-admin");
const fs = require("node:fs/promises");
const path = require("node:path");

const DEFAULT_SAMPLE_LIMIT = 25;
const CSV_EXPORTS = [
  [
    "unknown-owner-songs.csv",
    "unknownOwnerSongs",
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
    "normalized-review-candidates.csv",
    "normalizedReviewCandidates",
    [
      "path",
      "ownerType",
      "ownerId",
      "songId",
      "title",
      "artist",
      "normalizedTitle",
      "normalizedArtist",
      "canonicalSongId",
      "canonicalRevision",
    ],
  ],
  [
    "standalone-no-external-id.csv",
    "standaloneNoExternalId",
    ["path", "ownerType", "ownerId", "songId", "title", "artist"],
  ],
  ["failed.csv", "failed", ["path", "error"]],
];
const SAMPLE_KEYS = [
  "exactExternalIdLinkedCandidates",
  "normalizedReviewCandidates",
  "alreadyV2Skipped",
  "standaloneNoExternalId",
  "unknownOwnerSongs",
  "ambiguousMatches",
  "unmatchedExternalId",
  "failed",
];
const COUNT_BY_SAMPLE_KEY = {
  exactExternalIdLinkedCandidates: "exactExternalIdLinkedCandidates",
  normalizedReviewCandidates: "normalizedReviewCandidates",
  alreadyV2Skipped: "alreadyV2Skipped",
  standaloneNoExternalId: "standaloneNoExternalId",
  unknownOwnerSongs: "unknownOwnerSongs",
  ambiguousMatches: "ambiguousMatches",
  unmatchedExternalId: "unmatchedExternalId",
  failed: "failedReadsOrParses",
};

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
      addReviewRow(report, "failed", {
        path: doc.ref.path,
        error: error.message || String(error),
      });
    }
  }

  report.generatedAt = new Date().toISOString();
  refreshSampleSummary(report);
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
        const rows = report.fullCsvRows?.[key] || report[key];
        return fs.writeFile(
          path.join(csvDir, fileName),
          toCsv(rows, fields),
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
  const song = sampleSong(doc, data, owner);

  if (owner.ownerType === "unknown") {
    report.counts.unknownOwnerSongs += 1;
    addReviewRow(report, "unknownOwnerSongs", {
      ...song,
      externalIds,
    });
    return;
  }

  const externalIdMatch = await classifyExternalIdMatches(db, externalIds);
  if (externalIdMatch.status === "exact") {
    report.counts.exactExternalIdLinkedCandidates += 1;
    addReviewRow(report, "exactExternalIdLinkedCandidates", {
      ...song,
      matchedBy: externalIdMatch.matchedBy,
      matchedValue: externalIdMatch.matchedValue,
      canonicalSongId: externalIdMatch.canonicalSong.id,
      canonicalRevision: externalIdMatch.canonicalSong.canonicalRevision,
    });
    return;
  }

  if (externalIdMatch.status === "ambiguous") {
    report.counts.ambiguousMatches += 1;
    addReviewRow(report, "ambiguousMatches", {
      ...song,
      matchedBy: externalIdMatch.matchedBy,
      matchedValue: externalIdMatch.matchedValue,
      canonicalSongIds: externalIdMatch.canonicalSongIds,
    });
    return;
  }

  const normalizedMatch = await findNormalizedMatches(db, data);
  if (normalizedMatch.matches.length === 1) {
    report.counts.normalizedReviewCandidates += 1;
    addReviewRow(report, "normalizedReviewCandidates", {
      ...song,
      normalizedTitle: normalizedMatch.normalizedTitle,
      normalizedArtist: normalizedMatch.normalizedArtist,
      canonicalSongId: normalizedMatch.matches[0].id,
      canonicalRevision: normalizedMatch.matches[0].canonicalRevision,
    });
    return;
  }

  if (normalizedMatch.matches.length > 1) {
    report.counts.ambiguousMatches += 1;
    addReviewRow(report, "ambiguousMatches", {
      ...song,
      matchedBy: "normalizedTitleArtist",
      matchedValue: `${normalizedMatch.normalizedTitle}|${normalizedMatch.normalizedArtist}`,
      canonicalSongIds: normalizedMatch.matches.map((match) => match.id),
    });
    return;
  }

  if (externalIds.length === 0) {
    report.counts.standaloneNoExternalId += 1;
    addReviewRow(report, "standaloneNoExternalId", song);
    return;
  }

  report.counts.unmatchedExternalId += 1;
  addReviewRow(report, "unmatchedExternalId", {
    ...song,
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
  const report = {
    mode: "dry-run",
    writesEnabled: false,
    sampleLimit,
    generatedAt: null,
    counts: {
      totalSongsScanned: 0,
      totalLegacySongsScanned: 0,
      exactExternalIdLinkedCandidates: 0,
      normalizedReviewCandidates: 0,
      alreadyV2Skipped: 0,
      standaloneNoExternalId: 0,
      unknownOwnerSongs: 0,
      ambiguousMatches: 0,
      unmatchedExternalId: 0,
      failedReadsOrParses: 0,
    },
    csvExports: {
      rowSource: "full-review-manifest",
      sampleLimitApplies: false,
    },
    sampledRowCounts: {},
    samplesTruncated: {},
    exactExternalIdLinkedCandidates: [],
    normalizedReviewCandidates: [],
    alreadyV2Skipped: [],
    standaloneNoExternalId: [],
    unknownOwnerSongs: [],
    ambiguousMatches: [],
    unmatchedExternalId: [],
    failed: [],
  };
  Object.defineProperty(report, "fullCsvRows", {
    value: Object.fromEntries(CSV_EXPORTS.map(([, key]) => [key, []])),
    enumerable: false,
  });
  refreshSampleSummary(report);
  return report;
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
      value: normalizeMusicBrainzId(data.musicbrainzId || data.musicBrainzId),
    },
    { field: "isrc", value: normalizeIsrc(data.isrc) },
    { field: "spotifyId", value: normalizeSpotifyId(data.spotifyId) },
  ].filter((item) => item.value);
}

async function classifyExternalIdMatches(db, externalIds) {
  const results = [];

  for (const externalId of externalIds) {
    results.push({
      externalId,
      matches: await findCanonicalMatches(db, externalId),
    });
  }

  const matchedResults = results.filter((result) => result.matches.length > 0);
  if (matchedResults.length === 0) {
    return { status: "none" };
  }

  const duplicateMatch = matchedResults.some((result) => {
    return result.matches.length > 1;
  });
  const canonicalById = new Map();
  for (const result of matchedResults) {
    for (const match of result.matches) {
      canonicalById.set(match.id, match);
    }
  }

  if (duplicateMatch || canonicalById.size !== 1) {
    return {
      status: "ambiguous",
      matchedBy: matchedResults
        .map((result) => result.externalId.field)
        .join("|"),
      matchedValue: matchedResults
        .map((result) => {
          return `${result.externalId.field}=${result.externalId.value}`;
        })
        .join("|"),
      canonicalSongIds: [...canonicalById.keys()].sort(),
    };
  }

  return {
    status: "exact",
    matchedBy: matchedResults
      .map((result) => result.externalId.field)
      .join("|"),
    matchedValue: matchedResults
      .map((result) => {
        return `${result.externalId.field}=${result.externalId.value}`;
      })
      .join("|"),
    canonicalSong: [...canonicalById.values()][0],
  };
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

async function findNormalizedMatches(db, data) {
  const normalizedTitle = cleanString(data.normalizedTitle) ||
    normalizeForReview(data.title);
  const normalizedArtist = cleanString(data.normalizedArtist) ||
    normalizeForReview(data.artist);

  if (!normalizedTitle || !normalizedArtist) {
    return { normalizedTitle, normalizedArtist, matches: [] };
  }

  const snapshot = await db
    .collection("canonical_songs")
    .where("normalizedTitle", "==", normalizedTitle)
    .where("normalizedArtist", "==", normalizedArtist)
    .get();

  return {
    normalizedTitle,
    normalizedArtist,
    matches: snapshot.docs.map((doc) => ({
      id: doc.id,
      canonicalRevision: doc.data().canonicalRevision || 1,
    })),
  };
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

function addReviewRow(report, key, value) {
  pushSample(report, report[key], value);
  if (report.fullCsvRows?.[key]) {
    report.fullCsvRows[key].push(value);
  }
}

function refreshSampleSummary(report) {
  for (const key of SAMPLE_KEYS) {
    const countKey = COUNT_BY_SAMPLE_KEY[key];
    const total = report.counts[countKey] || 0;
    report.sampledRowCounts[key] = report[key].length;
    report.samplesTruncated[key] = report[key].length < total;
  }
}

function cleanString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function normalizeMusicBrainzId(value) {
  return cleanString(value).toLowerCase();
}

function normalizeIsrc(value) {
  return cleanString(value).replace(/[^a-z0-9]/gi, "").toUpperCase();
}

function normalizeSpotifyId(value) {
  const cleaned = cleanString(value);
  if (!cleaned) return "";

  const uriMatch = cleaned.match(/^spotify:track:([^:?/#]+)/i);
  if (uriMatch) return uriMatch[1].trim();

  if (/^https?:\/\//i.test(cleaned)) {
    try {
      const url = new URL(cleaned);
      const segments = url.pathname.split("/").filter(Boolean);
      const trackIndex = segments.findIndex((segment) => {
        return segment.toLowerCase() === "track";
      });
      if (trackIndex >= 0 && segments[trackIndex + 1]) {
        return segments[trackIndex + 1].trim();
      }
    } catch {
      return cleaned;
    }
  }

  return cleaned.replace(/[?#].*$/, "").trim();
}

function normalizeForReview(value) {
  return cleanString(value)
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, "")
    .replace(/\s+/g, " ")
    .trim();
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
  classifyExternalIdMatches,
  externalIdsFromSong,
  findNormalizedMatches,
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
  --sample-limit <count>  Max sample rows per JSON report category. CSV exports are full manifests. Default: ${DEFAULT_SAMPLE_LIMIT}.
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
