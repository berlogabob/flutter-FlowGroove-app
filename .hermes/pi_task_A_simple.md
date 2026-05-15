Task: Implement ensureCanonicalSong Firebase callable function for FlowGroove.

**File to create**: `functions/src/canonical.js` (create the functions/src directory if it doesn't exist).

**Code Content** (export the function):
```javascript
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
```

**Modify `functions/index.js`**: Add at the top: `module.exports = { ...require('./src/canonical') }` OR simply add `const canonical = require('./src/canonical');` and then `exports.ensureCanonicalSong = canonical.ensureCanonicalSong;` depending on existing structure.

**Check existing `functions/index.js`**: It currently exports Telegram bot functions. We need to merge: ensure `ensureCanonicalSong` is also exported.

**Testing** (optional now but good): we'll skip for now; but ensure code compiles.

**Action**:
1. Create directory `functions/src` if not exists.
2. Write the above code to `functions/src/canonical.js`.
3. Read the current `functions/index.js`. If it uses `require` for other functions, add `module.exports.ensureCanonicalSong = require('./src/canonical').ensureCanonicalSong;` at the end or merge appropriately.
4. If `functions/index.js` uses ES6 `export`, adjust accordingly (likely CommonJS).
5. After implementing, read back the created file(s) to confirm they contain the function.
6. Provide final summary: files created/modified, any errors.
