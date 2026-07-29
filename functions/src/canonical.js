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

async function findByExternalId(field, value) {
  if (!value) return null;
  const snapshot = await db
    .collection("canonical_songs")
    .where(field, "==", value)
    .limit(2)
    .get();
  if (snapshot.size > 1) throw duplicateCanonicalError();
  return snapshot.empty ? null : snapshot.docs[0];
}

function canonicalSongIdFor(normalizedTitle, normalizedArtist) {
  const hash = crypto
    .createHash("sha256")
    .update(`${normalizedTitle}\n${normalizedArtist}`)
    .digest("hex")
    .slice(0, 32);
  return `normalized_${hash}`;
}

function canonicalSongData({
  docRef,
  title,
  artist,
  album,
  durationMs,
  isrc,
  spotifyId,
  musicBrainzId,
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
    releaseYear: null,
    durationMs,
    isrc,
    spotifyId,
    musicBrainzId,
    musicBrainzWorkId: null,
    iswc: null,
    normalizedTitle,
    normalizedArtist,
    genres: [],
    disambiguation: null,
    schemaVersion: 1,
    canonicalRevision: 1,
    source: sourceFor({ musicBrainzId, isrc, spotifyId }),
    status: "active",
    createdBy: uid,
    baseKey: null,
    baseBpm: null,
    baseSections: [],
    baseAccentBeats: 4,
    baseRegularBeats: 1,
    baseBeatModes: [],
    baseLinks: [],
    createdAt: now,
    updatedAt: now,
  };
}

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

  return db.runTransaction(async (transaction) => {
    const normalizedQuery = db
      .collection("canonical_songs")
      .where("normalizedTitle", "==", normalizedTitle)
      .where("normalizedArtist", "==", normalizedArtist)
      .limit(2);
    const normalizedSnapshot = await transaction.get(normalizedQuery);
    if (normalizedSnapshot.size > 1) throw duplicateCanonicalError();
    if (!normalizedSnapshot.empty) {
      return canonicalResult(normalizedSnapshot.docs[0]);
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
      normalizedTitle,
      normalizedArtist,
      uid: context.auth.uid,
    }));

    return { canonicalSongId: docRef.id, canonicalRevision: 1 };
  });
});
