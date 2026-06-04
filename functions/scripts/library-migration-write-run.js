const admin = require("firebase-admin");
const crypto = require("node:crypto");
const fs = require("node:fs/promises");
const path = require("node:path");
const {
  classifyExternalIdMatches,
  externalIdsFromSong,
  isV2LinkedSong,
  ownerFromPath,
} = require("./library-migration-dry-run");

const DEFAULT_MAX_REPORT_AGE_HOURS = 24;
const MIGRATION_AUTHOR_ID = "migration:library-v2";
const MIGRATION_MESSAGE = "Migrate legacy song to linked library song";

async function runWriteRun({
  db,
  inputReport,
  inputPath = null,
  out = null,
  limit = null,
  execute = false,
  maxReportAgeHours = DEFAULT_MAX_REPORT_AGE_HOURS,
  now = new Date(),
  logger = null,
} = {}) {
  if (!inputReport || typeof inputReport !== "object") {
    throw new Error("A dry-run input report is required.");
  }
  assertFreshReport(inputReport, maxReportAgeHours, now);
  assertExactCandidatesUntruncated(inputReport);

  const firestore = db || getFirestore();
  const exactCandidates = Array.isArray(
    inputReport.exactExternalIdLinkedCandidates,
  )
    ? inputReport.exactExternalIdLinkedCandidates
    : [];
  const report = newWriteReport({
    execute,
    inputPath,
    limit,
    maxReportAgeHours,
    sourceGeneratedAt: inputReport.generatedAt || null,
  });
  report.counts.exactCandidatesRead = exactCandidates.length;
  report.counts.nonExactCandidatesSkipped = nonExactCandidateCount(inputReport);

  const candidates = typeof limit === "number"
    ? exactCandidates.slice(0, limit)
    : exactCandidates;
  report.counts.notProcessedDueToLimit = Math.max(
    exactCandidates.length - candidates.length,
    0,
  );

  for (const candidate of candidates) {
    const result = await processCandidate({
      db: firestore,
      candidate,
      execute,
      now,
    });
    recordResult(report, result);
  }

  report.generatedAt = new Date().toISOString();
  if (out) {
    await writeJsonFile(out, report);
  }
  if (logger) {
    logger(JSON.stringify(report, null, 2));
  }
  return report;
}

async function processCandidate({ db, candidate, execute, now }) {
  if (!candidate || typeof candidate !== "object" || !candidate.path) {
    return skipped("malformedCandidate", candidate, "Candidate is malformed.");
  }

  const owner = ownerFromPath(candidate.path);
  if (owner.ownerType === "unknown") {
    return skipped("ownerMismatch", candidate, "Unsupported song owner path.");
  }
  if (
    candidate.ownerType &&
    candidate.ownerType !== owner.ownerType
  ) {
    return skipped("ownerMismatch", candidate, "Candidate ownerType changed.");
  }
  if (candidate.ownerId && candidate.ownerId !== owner.ownerId) {
    return skipped("ownerMismatch", candidate, "Candidate ownerId changed.");
  }

  try {
    let outcome;
    const docRef = db.doc(candidate.path);
    await db.runTransaction(async (transaction) => {
      const doc = await transaction.get(docRef);
      outcome = await buildMigrationOutcome({
        db,
        transaction,
        doc,
        candidate,
        owner,
        now,
      });

      if (execute && outcome.status === "convert") {
        transaction.set(docRef, outcome.librarySong);
        transaction.set(
          docRef.collection("commits").doc(outcome.commit.id),
          outcome.commit,
        );
      }
    });

    if (!outcome) {
      return failed(candidate, "Migration transaction produced no result.");
    }
    if (outcome.status !== "convert") {
      return outcome;
    }
    return {
      type: execute ? "converted" : "validatedOnly",
      candidate,
      path: candidate.path,
      canonicalSongId: candidate.canonicalSongId,
      commitId: outcome.commit.id,
    };
  } catch (error) {
    return failed(candidate, error.message || String(error));
  }
}

async function buildMigrationOutcome({
  db,
  transaction,
  doc,
  candidate,
  owner,
  now,
}) {
  if (!doc.exists) {
    return skipped("docMissing", candidate, "Song document no longer exists.");
  }

  const data = doc.data();
  if (!data || typeof data !== "object") {
    return skipped("malformedCandidate", candidate, "Song data is malformed.");
  }
  if (isV2LinkedSong(data)) {
    return skipped("alreadyV2Skipped", candidate, "Song is already v2.");
  }
  if (typeof data.id === "string" && data.id.length > 0 && data.id !== doc.id) {
    return skipped(
      "idMismatch",
      candidate,
      `Song data id ${data.id} does not match document id ${doc.id}.`,
    );
  }

  const externalMatch = await classifyExternalIdMatches(
    db,
    externalIdsFromSong(data),
  );
  if (
    externalMatch.status !== "exact" ||
    externalMatch.canonicalSong.id !== candidate.canonicalSongId
  ) {
    return skipped(
      "canonicalMismatch",
      candidate,
      "Current external IDs no longer match the dry-run canonical song.",
    );
  }
  if (
    candidate.canonicalRevision != null &&
    externalMatch.canonicalSong.canonicalRevision !== candidate.canonicalRevision
  ) {
    return skipped(
      "canonicalRevisionMismatch",
      candidate,
      "Canonical revision changed since the dry-run report.",
    );
  }

  const canonicalRef = db
    .collection("canonical_songs")
    .doc(candidate.canonicalSongId);
  const canonicalDoc = await transaction.get(canonicalRef);
  if (!canonicalDoc.exists) {
    return skipped("canonicalMissing", candidate, "Canonical song is missing.");
  }

  const canonical = { id: canonicalDoc.id, ...canonicalDoc.data() };
  const baseRevision = numberOrDefault(canonical.canonicalRevision, 1);
  const commitId = deterministicId("migration", candidate.path, canonical.id);
  const clientMutationId = deterministicId(
    "library-v2",
    candidate.path,
    canonical.id,
  );
  const nowIso = now.toISOString();
  const createdAt = dateToIso(data.createdAt) || nowIso;
  const delta = computeDelta({ canonical, song: data });
  const materialized = materializedSong({
    data,
    docId: doc.id,
    owner,
    canonical,
    baseRevision,
    commitId,
    nowIso,
  });
  const librarySong = {
    id: doc.id,
    schemaVersion: 2,
    canonicalSongId: canonical.id,
    ownerType: owner.ownerType,
    ownerId: owner.ownerId,
    baseRevision,
    delta,
    materialized,
    latestCommitId: commitId,
    createdAt,
    updatedAt: nowIso,
    deletedAt: null,
  };
  const commit = {
    id: commitId,
    parentCommitId: null,
    canonicalSongId: canonical.id,
    baseRevision,
    delta,
    operation: "create",
    authorId: MIGRATION_AUTHOR_ID,
    message: MIGRATION_MESSAGE,
    createdAt: nowIso,
    clientMutationId,
  };

  return { status: "convert", librarySong, commit };
}

function computeDelta({ canonical, song }) {
  const delta = {};

  if (nullable(song.ourKey) !== nullable(canonical.baseKey)) {
    delta.ourKey = nullable(song.ourKey);
  }
  if (nullableNumber(song.ourBPM) !== nullableNumber(canonical.baseBpm)) {
    delta.ourBPM = nullableNumber(song.ourBPM);
  }
  if (typeof song.notes === "string" && song.notes.length > 0) {
    delta.notes = song.notes;
  }
  if (Array.isArray(song.tags) && song.tags.length > 0) {
    delta.tags = song.tags;
  }
  if (!jsonEqual(arrayOrEmpty(song.links), arrayOrEmpty(canonical.baseLinks))) {
    delta.links = arrayOrEmpty(song.links);
  }
  if (
    !jsonEqual(arrayOrEmpty(song.sections), arrayOrEmpty(canonical.baseSections))
  ) {
    delta.sections = arrayOrEmpty(song.sections);
  }
  if (
    numberOrDefault(song.accentBeats, 4) !==
    numberOrDefault(canonical.baseAccentBeats, 4)
  ) {
    delta.accentBeats = numberOrDefault(song.accentBeats, 4);
  }
  if (
    numberOrDefault(song.regularBeats, 1) !==
    numberOrDefault(canonical.baseRegularBeats, 1)
  ) {
    delta.regularBeats = numberOrDefault(song.regularBeats, 1);
  }
  if (
    !jsonEqual(
      arrayOrEmpty(song.beatModes),
      arrayOrEmpty(canonical.baseBeatModes),
    )
  ) {
    delta.beatModes = arrayOrEmpty(song.beatModes);
  }

  return dropUndefined(delta);
}

function materializedSong({
  data,
  docId,
  owner,
  canonical,
  baseRevision,
  commitId,
  nowIso,
}) {
  const materialized = {
    ...data,
    id: docId,
    canonicalSongId: canonical.id,
    libraryBaseRevision: baseRevision,
    latestCommitId: commitId,
    updatedAt: nowIso,
    isFromMusicBrainz: Boolean(canonical.musicBrainzId || canonical.musicBrainzWorkId),
  };
  if (owner.ownerType === "band" && !materialized.bandId) {
    materialized.bandId = owner.ownerId;
  }
  return dropUndefined(materialized);
}

function newWriteReport({
  execute,
  inputPath,
  limit,
  maxReportAgeHours,
  sourceGeneratedAt,
}) {
  return {
    mode: execute ? "write-run" : "write-preview",
    writesEnabled: execute,
    inputPath,
    limit,
    maxReportAgeHours,
    sourceGeneratedAt,
    generatedAt: null,
    counts: {
      exactCandidatesRead: 0,
      nonExactCandidatesSkipped: 0,
      notProcessedDueToLimit: 0,
      converted: 0,
      validatedOnly: 0,
      alreadyV2Skipped: 0,
      docMissing: 0,
      canonicalMissing: 0,
      canonicalMismatch: 0,
      canonicalRevisionMismatch: 0,
      ownerMismatch: 0,
      idMismatch: 0,
      malformedCandidate: 0,
      failed: 0,
    },
    converted: [],
    validatedOnly: [],
    skipped: [],
    failed: [],
  };
}

function recordResult(report, result) {
  if (result.type === "converted") {
    report.counts.converted += 1;
    report.converted.push(summaryRow(result));
    return;
  }
  if (result.type === "validatedOnly") {
    report.counts.validatedOnly += 1;
    report.validatedOnly.push(summaryRow(result));
    return;
  }
  if (result.type === "failed") {
    report.counts.failed += 1;
    report.failed.push(result);
    return;
  }

  report.counts[result.reason] += 1;
  report.skipped.push(result);
}

function skipped(reason, candidate, message) {
  return {
    type: "skipped",
    reason,
    path: candidate?.path || null,
    canonicalSongId: candidate?.canonicalSongId || null,
    message,
  };
}

function failed(candidate, error) {
  return {
    type: "failed",
    path: candidate?.path || null,
    canonicalSongId: candidate?.canonicalSongId || null,
    error,
  };
}

function summaryRow(result) {
  return {
    path: result.path,
    canonicalSongId: result.canonicalSongId,
    commitId: result.commitId,
  };
}

function nonExactCandidateCount(report) {
  return [
    "normalizedReviewCandidates",
    "ambiguousMatches",
    "unmatchedExternalId",
    "standaloneNoExternalId",
    "unknownOwnerSongs",
  ].reduce((count, key) => {
    return count + (Array.isArray(report[key]) ? report[key].length : 0);
  }, 0);
}

function assertFreshReport(report, maxReportAgeHours, now) {
  const generatedAt = Date.parse(report.generatedAt || "");
  if (!Number.isFinite(generatedAt)) {
    throw new Error("Dry-run report is missing a valid generatedAt timestamp.");
  }

  const ageMs = now.getTime() - generatedAt;
  const maxAgeMs = maxReportAgeHours * 60 * 60 * 1000;
  if (ageMs < 0) return;
  if (ageMs > maxAgeMs) {
    throw new Error(
      `Dry-run report is stale. Generate a fresh report within ${maxReportAgeHours} hours.`,
    );
  }
}

function assertExactCandidatesUntruncated(report) {
  if (report.samplesTruncated?.exactExternalIdLinkedCandidates === true) {
    throw new Error(
      "Dry-run exact candidates are truncated. Regenerate the dry-run with a higher --sample-limit before write-run preview or execution.",
    );
  }
}

function getFirestore(projectId = null) {
  if (!admin.apps.length) {
    admin.initializeApp(projectId ? { projectId } : undefined);
  }
  return admin.firestore();
}

async function readJsonFile(filePath) {
  return JSON.parse(await fs.readFile(filePath, "utf8"));
}

async function writeJsonFile(filePath, value) {
  await fs.mkdir(path.dirname(path.resolve(filePath)), { recursive: true });
  await fs.writeFile(filePath, `${JSON.stringify(value, null, 2)}\n`);
}

function parseArgs(args) {
  const options = {
    input: null,
    out: null,
    limit: null,
    execute: false,
    project: null,
    maxReportAgeHours: DEFAULT_MAX_REPORT_AGE_HOURS,
  };

  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];
    const next = args[i + 1];
    if (arg === "--input") {
      options.input = requireValue(arg, next);
      i += 1;
    } else if (arg === "--out") {
      options.out = requireValue(arg, next);
      i += 1;
    } else if (arg === "--limit") {
      options.limit = parseNonNegativeInteger(requireValue(arg, next), arg);
      i += 1;
    } else if (arg === "--execute") {
      options.execute = true;
    } else if (arg === "--project") {
      options.project = requireValue(arg, next);
      i += 1;
    } else if (arg === "--max-report-age-hours") {
      options.maxReportAgeHours = parseNonNegativeNumber(
        requireValue(arg, next),
        arg,
      );
      i += 1;
    } else if (arg === "--help" || arg === "-h") {
      printHelp();
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }

  if (!options.input) {
    throw new Error("--input is required.");
  }
  if (!options.out) {
    throw new Error("--out is required.");
  }
  if (options.execute && !options.project) {
    throw new Error("--project is required when --execute is used.");
  }
  return options;
}

function requireValue(name, value) {
  if (!value || value.startsWith("--")) {
    throw new Error(`${name} requires a value.`);
  }
  return value;
}

function parseNonNegativeInteger(value, name) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed) || parsed < 0 || String(parsed) !== value) {
    throw new Error(`${name} must be a non-negative integer.`);
  }
  return parsed;
}

function parseNonNegativeNumber(value, name) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) {
    throw new Error(`${name} must be a non-negative number.`);
  }
  return parsed;
}

function printHelp() {
  console.log(`Usage: node scripts/library-migration-write-run.js --input <dry-run.json> --out <write-report.json> [options]

Options:
  --input <path>                 Required dry-run JSON report.
  --out <path>                   Required write/validation report path.
  --limit <count>                Max exact candidates to process.
  --execute                      Actually write Firestore changes. Omit for validation-only preview.
  --project <id>                 Firebase project id. Required with --execute.
  --max-report-age-hours <n>     Maximum accepted dry-run report age. Default: ${DEFAULT_MAX_REPORT_AGE_HOURS}.
  --help                         Show this help.
`);
}

function deterministicId(prefix, songPath, canonicalSongId) {
  const digest = crypto
    .createHash("sha256")
    .update(`${songPath}|${canonicalSongId}`)
    .digest("hex")
    .slice(0, 24);
  return `${prefix}-${digest}`;
}

function dateToIso(value) {
  if (!value) return null;
  if (value instanceof Date) return value.toISOString();
  if (typeof value === "string") {
    return Number.isFinite(Date.parse(value))
      ? new Date(value).toISOString()
      : null;
  }
  if (typeof value.toDate === "function") {
    return value.toDate().toISOString();
  }
  if (typeof value === "number") {
    return new Date(value).toISOString();
  }
  return null;
}

function dropUndefined(input) {
  return Object.fromEntries(
    Object.entries(input).filter(([, value]) => value !== undefined),
  );
}

function nullable(value) {
  return value === undefined ? null : value;
}

function nullableNumber(value) {
  if (value === undefined || value === null) return null;
  return Number(value);
}

function numberOrDefault(value, fallback) {
  if (value === undefined || value === null) return fallback;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function arrayOrEmpty(value) {
  return Array.isArray(value) ? value : [];
}

function jsonEqual(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

if (require.main === module) {
  let options;
  try {
    options = parseArgs(process.argv.slice(2));
  } catch (error) {
    console.error(error.message || String(error));
    process.exit(1);
  }

  readJsonFile(options.input)
    .then((inputReport) => {
      return runWriteRun({
        db: getFirestore(options.project),
        inputReport,
        inputPath: options.input,
        out: options.out,
        limit: options.limit,
        execute: options.execute,
        maxReportAgeHours: options.maxReportAgeHours,
      });
    })
    .then((report) => {
      console.log(
        `Wrote migration ${report.writesEnabled ? "write" : "preview"} report to ${options.out}`,
      );
    })
    .catch((error) => {
      console.error(error);
      process.exitCode = 1;
    });
}

module.exports = {
  runWriteRun,
  parseArgs,
  computeDelta,
  deterministicId,
  materializedSong,
};
