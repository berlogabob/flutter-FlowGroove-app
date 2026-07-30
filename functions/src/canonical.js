const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("node:crypto");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const duplicateCanonicalMessage = "Duplicate canonical song matches found.";

function cleanString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function optionalString(value) {
  const cleaned = cleanString(value);
  return cleaned.length > 0 ? cleaned : null;
}

// Unicode-aware: an ASCII-only filter normalized every Cyrillic title AND artist
// to "", so all of them collapsed onto one canonical id (and the app then showed
// the first such song's title/artist for every one of them).
function normalize(value) {
  return cleanString(value)
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s]/gu, "")
    .replace(/\s+/g, " ")
    .trim();
}

function sourceFor({ musicBrainzId, isrc, spotifyId }) {
  if (musicBrainzId) return "musicbrainz";
  if (spotifyId) return "spotify";
  if (isrc) return "isrc";
  return "manual";
}

function canonicalResult(doc) {
  const data = doc.data() || {};
  return {
    canonicalSongId: doc.id,
    canonicalRevision: data.canonicalRevision || 1,
  };
}

function duplicateCanonicalError() {
  return new functions.https.HttpsError(
    "failed-precondition",
    duplicateCanonicalMessage,
  );
}

async function isDemoUser(uid, token) {
  if (token.demo === true) return true;

  const userDoc = await db.collection("users").doc(uid).get();
  return userDoc.exists && userDoc.data().accessRole === "demo";
}

function isActive(doc) {
  return ((doc.data() || {}).status || "active") === "active";
}

// Status-filtered in memory rather than with a second where() clause: that would
// need a composite index per external-id field, and the result set here is
// always tiny.
async function findByExternalId(field, value) {
  if (!value) return null;
  const snapshot = await db
    .collection("canonical_songs")
    .where(field, "==", value)
    .limit(5)
    .get();
  // A merged or hidden canonical must neither win a lookup nor make an
  // otherwise-unambiguous match look ambiguous. Prod hit exactly this: an
  // orphaned pre-Unicode-fix artifact shared MBID edf8d9b5 with the real
  // "День рождения" canonical, so every ensureCanonicalSong for that recording
  // failed with "Duplicate canonical song matches found."
  const live = snapshot.docs.filter(isActive);
  if (live.length > 1) throw duplicateCanonicalError();
  return live[0] || null;
}

function canonicalSongIdFor(normalizedTitle, normalizedArtist) {
  const hash = crypto
    .createHash("sha256")
    .update(`${normalizedTitle}\n${normalizedArtist}`)
    .digest("hex")
    .slice(0, 32);
  return `normalized_${hash}`;
}

// These used to be hardcoded null/[] and were not accepted as input at all, so
// every canonical was born empty and — with no update path in existence — could
// never be filled in. The doc shape is unchanged; the defaults just moved from
// literals to parameters.
function canonicalSongData({
  docRef,
  title,
  artist,
  album,
  durationMs,
  isrc,
  spotifyId,
  musicBrainzId,
  musicBrainzWorkId = null,
  iswc = null,
  releaseYear = null,
  genres = [],
  disambiguation = null,
  baseKey = null,
  baseBpm = null,
  normalizedTitle,
  normalizedArtist,
  uid,
}) {
  const now = admin.firestore.FieldValue.serverTimestamp();
  return {
    id: docRef.id,
    title,
    artist,
    artists: [artist],
    album,
    releaseYear,
    durationMs,
    isrc,
    spotifyId,
    musicBrainzId,
    musicBrainzWorkId,
    iswc,
    normalizedTitle,
    normalizedArtist,
    genres,
    disambiguation,
    schemaVersion: 1,
    canonicalRevision: 1,
    source: sourceFor({ musicBrainzId, isrc, spotifyId }),
    status: "active",
    createdBy: uid,
    baseKey,
    baseBpm,
    baseSections: [],
    baseAccentBeats: 4,
    baseRegularBeats: 1,
    baseBeatModes: [],
    baseLinks: [],
    createdAt: now,
    updatedAt: now,
  };
}

// Fields updateCanonicalSong may touch. title/artist are deliberately absent:
// they drive normalizedTitle/normalizedArtist, which in turn drive the document
// id, so editing them here would desync the doc from its own id. Renaming is a
// merge operation, not an update.
const UPDATABLE_STRING_FIELDS = [
  "album", "isrc", "spotifyId", "musicBrainzId", "musicBrainzWorkId",
  "iswc", "disambiguation", "baseKey",
];
const UPDATABLE_INT_FIELDS = {
  releaseYear: { min: 1000, max: new Date().getFullYear() + 1 },
  durationMs: { min: 1, max: 24 * 60 * 60 * 1000 },
  baseBpm: { min: 20, max: 400 },
};

function isEmptyValue(value) {
  if (value === null || value === undefined) return true;
  if (typeof value === "string") return value.trim().length === 0;
  if (Array.isArray(value)) return value.length === 0;
  return false;
}

/**
 * Work out what an update should actually write.
 *
 * Pure, so the same validation serves the callable (auth-checked, for app and
 * agent traffic) and one-off admin-SDK repair scripts, which bypass rules
 * entirely. Default behaviour is fill-only: a value already present is left
 * alone unless `overwrite` is set. Without that, any authenticated user could
 * quietly rewrite a canonical shared by every band.
 *
 * @returns {{changes: object, warnings: string[]}}
 */
function canonicalUpdatePatch(existing, patch, { overwrite = false } = {}) {
  const current = existing || {};
  const input = patch || {};
  const changes = {};
  const warnings = [];

  const consider = (field, value) => {
    if (isEmptyValue(value)) return;
    const existingValue = current[field];
    // Identical value is a no-op, not a conflict — no warning, no revision bump.
    if (JSON.stringify(existingValue ?? null) === JSON.stringify(value)) return;
    if (!isEmptyValue(existingValue) && !overwrite) {
      warnings.push(`${field} already set — kept existing value`);
      return;
    }
    changes[field] = value;
  };

  for (const [field, value] of Object.entries(input)) {
    if (UPDATABLE_STRING_FIELDS.includes(field)) {
      const cleaned = optionalString(value);
      if (cleaned === null && !isEmptyValue(value)) {
        warnings.push(`${field} must be a string — ignored`);
        continue;
      }
      consider(field, cleaned);
    } else if (UPDATABLE_INT_FIELDS[field]) {
      const { min, max } = UPDATABLE_INT_FIELDS[field];
      const num = Number(value);
      if (!Number.isFinite(num) || num < min || num > max) {
        warnings.push(`${field} must be a number between ${min} and ${max} — ignored`);
        continue;
      }
      consider(field, Math.round(num));
    } else if (field === "genres") {
      if (!Array.isArray(value)) {
        warnings.push("genres must be an array — ignored");
        continue;
      }
      const cleaned = value.map(cleanString).filter((g) => g.length > 0);
      consider("genres", cleaned);
    } else if (field === "title" || field === "artist") {
      warnings.push(`${field} defines the canonical id and cannot be updated here`);
    } else {
      warnings.push(`ignored unknown field: ${field}`);
    }
  }

  return { changes, warnings };
}

/**
 * The validated canonical update path firestore.rules has always pointed at
 * ("Use Cloud Functions with validation for imports/updates") but which was
 * never written — which is why canonicals created without an album kept it
 * forever and canonicalRevision was frozen at 1 across the whole catalog.
 */
exports.updateCanonicalSong = functions.https.onCall(async (request) => {
  const data = request.data || {};
  const context = { auth: request.auth };
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Request must be authenticated.",
    );
  }
  if (await isDemoUser(context.auth.uid, context.auth.token || {})) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Demo users are not allowed to update canonical songs.",
    );
  }

  const canonicalSongId = cleanString(data.canonicalSongId);
  if (!canonicalSongId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "canonicalSongId is required.",
    );
  }

  const ref = db.collection("canonical_songs").doc(canonicalSongId);

  return db.runTransaction(async (transaction) => {
    const doc = await transaction.get(ref);
    if (!doc.exists) {
      throw new functions.https.HttpsError("not-found", "Canonical song not found.");
    }
    const existing = doc.data() || {};

    // Overwriting an existing value is limited to whoever created the canonical.
    // Anyone authenticated may fill blanks, which is the common, safe case.
    const requestedOverwrite = data.overwrite === true;
    const mayOverwrite = requestedOverwrite &&
      existing.createdBy === context.auth.uid;
    const { changes, warnings } = canonicalUpdatePatch(
      existing,
      data.fields || {},
      { overwrite: mayOverwrite },
    );
    if (requestedOverwrite && !mayOverwrite) {
      warnings.push("overwrite requires being the creator of this canonical song");
    }

    if (Object.keys(changes).length === 0) {
      return {
        canonicalSongId,
        canonicalRevision: existing.canonicalRevision || 1,
        updated: [],
        warnings,
      };
    }

    const canonicalRevision = (existing.canonicalRevision || 1) + 1;
    transaction.set(ref, {
      ...changes,
      canonicalRevision,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return {
      canonicalSongId,
      canonicalRevision,
      updated: Object.keys(changes),
      warnings,
    };
  });
});

exports.canonicalUpdatePatch = canonicalUpdatePatch;
exports.canonicalSongIdFor = canonicalSongIdFor;
exports.normalize = normalize;

exports.ensureCanonicalSong = functions.https.onCall(async (request) => {
  const data = request.data || {};
  const context = { auth: request.auth };
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Request must be authenticated.",
    );
  }
  if (await isDemoUser(context.auth.uid, context.auth.token || {})) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Demo users are not allowed to create canonical songs.",
    );
  }

  const payload = data || {};
  const title = cleanString(payload.title);
  const artist = cleanString(payload.artist);
  const musicBrainzId = optionalString(payload.musicBrainzId);
  const isrc = optionalString(payload.isrc);
  const spotifyId = optionalString(payload.spotifyId);
  const album = optionalString(payload.album);
  const durationMs = payload.durationMs != null &&
    Number.isFinite(Number(payload.durationMs))
    ? Number(payload.durationMs)
    : null;

  // Validate the richer fields through the same whitelist the update path uses,
  // rather than duplicating range checks here. Only non-empty, valid values come
  // back, so canonicalSongData's defaults still apply to everything else.
  const { changes: richFields } = canonicalUpdatePatch({}, {
    musicBrainzWorkId: payload.musicBrainzWorkId,
    iswc: payload.iswc,
    releaseYear: payload.releaseYear,
    genres: payload.genres,
    disambiguation: payload.disambiguation,
    baseKey: payload.baseKey,
    baseBpm: payload.baseBpm,
  });

  const byMusicBrainz = await findByExternalId("musicBrainzId", musicBrainzId);
  if (byMusicBrainz) return canonicalResult(byMusicBrainz);

  const byIsrc = await findByExternalId("isrc", isrc);
  if (byIsrc) return canonicalResult(byIsrc);

  const bySpotify = await findByExternalId("spotifyId", spotifyId);
  if (bySpotify) return canonicalResult(bySpotify);

  if (!title || !artist) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Title and artist are required when no canonical match exists.",
    );
  }

  const normalizedTitle = normalize(title);
  const normalizedArtist = normalize(artist);

  // Root-cause guard. When normalize() returns "" the doc id degenerates to
  // sha256("\n") and every such song collapses onto one shared canonical — the
  // pre-Unicode-fix Cyrillic bug, whose orphaned artifact is still in prod as
  // normalized_01ba4719c80b6fe911b091a7c05124b6. Unicode-awareness fixed the
  // Cyrillic case, but a title of pure punctuation or emoji still normalizes to
  // "", so refuse rather than mint another collision magnet.
  if (!normalizedTitle || !normalizedArtist) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Title and artist must each contain at least one letter or digit.",
    );
  }

  return db.runTransaction(async (transaction) => {
    const normalizedQuery = db
      .collection("canonical_songs")
      .where("normalizedTitle", "==", normalizedTitle)
      .where("normalizedArtist", "==", normalizedArtist)
      .limit(5);
    const normalizedSnapshot = await transaction.get(normalizedQuery);
    const liveMatches = normalizedSnapshot.docs.filter(isActive);
    if (liveMatches.length > 1) throw duplicateCanonicalError();
    if (liveMatches.length === 1) {
      return canonicalResult(liveMatches[0]);
    }

    const docRef = db
      .collection("canonical_songs")
      .doc(canonicalSongIdFor(normalizedTitle, normalizedArtist));
    const existingDoc = await transaction.get(docRef);
    if (existingDoc.exists) {
      const existingData = existingDoc.data() || {};
      if (
        existingData.normalizedTitle !== normalizedTitle ||
        existingData.normalizedArtist !== normalizedArtist
      ) {
        throw duplicateCanonicalError();
      }
      return canonicalResult(existingDoc);
    }

    transaction.set(docRef, canonicalSongData({
      docRef,
      title,
      artist,
      album,
      durationMs,
      isrc,
      spotifyId,
      musicBrainzId,
      ...richFields,
      normalizedTitle,
      normalizedArtist,
      uid: context.auth.uid,
    }));

    return { canonicalSongId: docRef.id, canonicalRevision: 1 };
  });
});
