const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Initialize admin if needed
if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

function normalize(s) {
  return s.toLowerCase().trim().replace(/[^a-z0-9\s]/g, '');
}

exports.ensureCanonicalSong = functions.https.onCall(async (data, context) => {
  // Auth check
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Request must be authenticated.');
  }
  if (context.auth.token.demo === true) {
    throw new functions.https.HttpsError('failed-precondition', 'Demo users not allowed.');
  }

  const { musicBrainzId, isrc, spotifyId, title, artist } = data;

  // Validate input
  if (!musicBrainzId && !isrc && !spotifyId && (!title || !artist)) {
    throw new functions.https.HttpsError('invalid-argument', 'Must provide either external ID(s) or both title and artist.');
  }

  // Try exact match by external IDs
  let snapshot;
  if (musicBrainzId) {
    snapshot = await db.collection('canonical_songs').where('musicBrainzId', '==', musicBrainzId).limit(1).get();
    if (!snapshot.empty) {
      const doc = snapshot.docs[0];
      return { canonicalSongId: doc.id, revision: doc.data().canonicalRevision };
    }
  }
  if (isrc) {
    snapshot = await db.collection('canonical_songs').where('isrc', '==', isrc).limit(1).get();
    if (!snapshot.empty) {
      const doc = snapshot.docs[0];
      return { canonicalSongId: doc.id, revision: doc.data().canonicalRevision };
    }
  }
  if (spotifyId) {
    snapshot = await db.collection('canonical_songs').where('spotifyId', '==', spotifyId).limit(1).get();
    if (!snapshot.empty) {
      const doc = snapshot.docs[0];
      return { canonicalSongId: doc.id, revision: doc.data().canonicalRevision };
    }
  }

  // Try match by normalized title/artist
  if (title && artist) {
    const normTitle = normalize(title);
    const normArtist = normalize(artist);
    snapshot = await db.collection('canonical_songs')
      .where('normalizedTitle', '==', normTitle)
      .where('normalizedArtist', '==', normArtist)
      .limit(1)
      .get();
    if (!snapshot.empty) {
      const doc = snapshot.docs[0];
      return { canonicalSongId: doc.id, revision: doc.data().canonicalRevision };
    }
  }

  // Create new canonical song
  const newId = db.collection('canonical_songs').doc().id;
  const now = admin.firestore.FieldValue.serverTimestamp();
  const canonicalData = {
    schemaVersion: 1,
    canonicalRevision: 1,
    source: 'manual',
    status: 'active',
    createdBy: context.auth.uid,
    musicBrainzId: musicBrainzId || null,
    isrc: isrc || null,
    spotifyId: spotifyId || null,
    title: title,
    artist: artist,
    normalizedTitle: normalize(title),
    normalizedArtist: normalize(artist),
    baseKey: null,
    baseBpm: null,
    baseSections: [],
    baseAccentBeats: [],
    baseRegularBeats: [],
    baseBeatModes: [],
    baseLinks: [],
    createdAt: now,
    updatedAt: now,
  };

  await db.collection('canonical_songs').doc(newId).set(canonicalData);
  return { canonicalSongId: newId, revision: 1 };
});