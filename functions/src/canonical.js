const functions = require("firebase-functions");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

function cleanString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function optionalString(value) {
  const cleaned = cleanString(value);
  return cleaned.length > 0 ? cleaned : null;
}

function normalize(value) {
  return cleanString(value)
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, "")
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

async function findByExternalId(field, value) {
  if (!value) return null;
  const snapshot = await db
    .collection("canonical_songs")
    .where(field, "==", value)
    .limit(1)
    .get();
  return snapshot.empty ? null : snapshot.docs[0];
}

exports.ensureCanonicalSong = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Request must be authenticated.",
    );
  }
  if (context.auth.token.demo === true) {
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
  const normalizedSnapshot = await db
    .collection("canonical_songs")
    .where("normalizedTitle", "==", normalizedTitle)
    .where("normalizedArtist", "==", normalizedArtist)
    .limit(1)
    .get();
  if (!normalizedSnapshot.empty) {
    return canonicalResult(normalizedSnapshot.docs[0]);
  }

  const docRef = db.collection("canonical_songs").doc();
  const now = admin.firestore.FieldValue.serverTimestamp();
  await docRef.set({
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
    createdBy: context.auth.uid,
    baseKey: null,
    baseBpm: null,
    baseSections: [],
    baseAccentBeats: 4,
    baseRegularBeats: 1,
    baseBeatModes: [],
    baseLinks: [],
    createdAt: now,
    updatedAt: now,
  });

  return { canonicalSongId: docRef.id, canonicalRevision: 1 };
});
