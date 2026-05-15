Implement the Firebase callable function `ensureCanonicalSong` as described below.

**Location**: Add to `functions/index.js` (create separate export) or new file `functions/src/canonical.js` if you prefer modularization.

**Spec:**
- Function: `exports.ensureCanonicalSong = functions.https.onCall(async (data, context) => { ... })`
- Auth: Require `context.auth`. Reject if `context.auth.token.demo === true` with error "Demo users not allowed".
- Input: `data` may contain `musicBrainzId`, `isrc`, `spotifyId`, `title`, `artist`. At least one of these must be provided.
- Logic:
  1. If any external ID (musicBrainzId, isrc, spotifyId) is provided, query `admin.firestore().collection('canonical_songs')` for a document where that field equals the given value. If found, return `{ canonicalSongId: doc.id, revision: doc.data().canonicalRevision }`.
  2. If no match and both `title` and `artist` are provided:
     - Normalize: lowercase, trim whitespace, remove any character not alphanumeric or space (regex `[^a-z0-9\\s]`).
     - Query for a document where `normalizedTitle == normalize(title)` and `normalizedArtist == normalize(artist)`. If found, return it.
  3. If still no match, create a new canonical song:
     - Generate ID: `admin.firestore().collection('canonical_songs').doc().id`
     - Build document:
       ```js
       const canonicalData = {
         schemaVersion: 1,
         canonicalRevision: 1,
         source: data.source || 'manual',
         status: 'active',
         createdBy: context.auth.uid,
         musicBrainzId: data.musicBrainzId || null,
         isrc: data.isrc || null,
         spotifyId: data.spotifyId || null,
         title: data.title,
         artist: data.artist,
         normalizedTitle: normalize(data.title),
         normalizedArtist: normalize(data.artist),
         baseKey: null,
         baseBpm: null,
         baseSections: [],
         baseAccentBeats: [],
         baseRegularBeats: [],
         baseBeatModes: [],
         baseLinks: []
       };
       ```
     - Use `admin.initializeApp()` if not already. Write with `setDoc`.
     - Return `{ canonicalSongId: newId, revision: 1 }`.
- Helper function `normalize(s)` implemented in JS.

**Testing:**
- Create `functions/test/canonical.test.js` using `firebase-functions-test` and `@firebase/rules-unit-testing` (or simple jest mocks of admin and functions).
- Write tests for:
  - Unauthenticated: throws functions.https.HttpsError with 'unauthenticated'
  - Demo user: throws with 'failed-precondition' and message "Demo users not allowed"
  - External ID exact match (mock query)
  - Title/artist match
  - Create new (mock no match)
  - Missing all fields: throw 'invalid-argument'
- Ensure tests pass with `npm test` from `functions/`.

**Deliverables:**
- Code for `ensureCanonicalSong` in proper location.
- Test file `functions/test/canonical.test.js`.
- If needed, update `functions/package.json` to include `"test": "jest"` and jest dependencies (if not present; assume present).
- Final summary: lines added, test results (number of passing/failing), and any issues encountered.

Work in /Users/berloga/Documents/GitHub/flutter_repsync_app.
