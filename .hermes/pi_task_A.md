# Pi Task A: ensureCanonicalSong Function

**Project:** FlowGroove (Flutter music app)  
**Path:** /Users/berloga/Documents/GitHub/flutter_repsync_app  
**Reference:** Plan_LibraryUpdate.md Part 4.2

## Instruction

Implement the Firebase callable function `ensureCanonicalSong` in the Functions directory.

### Details

The function signature:
```
exports.ensureCanonicalSong = functions.https.onCall(async (data, context) => { ... });
```

**Input (data):**
- `musicBrainzId` (string, optional)
- `isrc` (string, optional)
- `spotifyId` (string, optional)
- `title` (string, optional)
- `artist` (string, optional)

At least one of external IDs or title+artist must be provided.

**Auth:**
- Must have `context.auth` non-null.
- Reject with error "Demo users not allowed" if `context.auth.token.demo === true`.

**Logic:**

1. Search canonical_songs collection by external IDs:
   - If `musicBrainzId` provided, query where `musicBrainzId == data.musicBrainzId`.
   - If `isrc` provided, query where `isrc == data.isrc`.
   - If `spotifyId` provided, query where `spotifyId == data.spotifyId`.
   - If any exact match found, return `{ canonicalSongId: doc.id, revision: doc.data().canonicalRevision }`.

2. If no match and `title`+`artist` provided:
   - Normalize: lowercase, trim, remove punctuation (keep alphanum and spaces).
   - Query `canonical_songs` where `normalizedTitle == normalizedTitle` and `normalizedArtist == normalizedArtist`.
   - If found, return that.

3. If still no match:
   - Create new doc in `canonical_songs` with auto-ID using Admin SDK.
   - Fields:
     ```
     {
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
       normalizedTitle: normalized(title),
       normalizedArtist: normalized(artist),
       baseKey: null, // optional
       baseBpm: null,
       baseSections: [],
       baseAccentBeats: [],
       baseRegularBeats: [],
       baseBeatModes: [],
       baseLinks: []
     }
     ```
   - Return `{ canonicalSongId: newId, revision: 1 }`.

**Helper**: Implement a simple `normalize(s)` function: `s.toLowerCase().trim().replace(/[^a-z0-9\s]/g, '')`.

**Tests:**
- Create `functions/test/canonical.test.js` using `firebase-functions-test` and `@firebase/rules-unit-testing` or simple mocks.
- Test cases: unauthenticated (error), demo user (error), external ID exact match (returns existing), title/artist match (returns existing), create new (returns new id), missing required fields (error).

**Deploy:**
- Ensure `functions/package.json` has `firebase-functions` and `firebase-admin`.
- Provide `npm test` script that runs jest.

**Deliverable:**
- Updated `functions/index.js` (or new `functions/src/canonical.js` imported) with `ensureCanonicalSong`.
- `functions/test/canonical.test.js`.
- Update `functions/package.json` if needed (add jest if not present).
- Brief README snippet on how to test locally with `firebase emulators:start`.

**Important:** Use only Node.js compatible with current Firebase Functions runtime (likely node18). Use `admin.initializeApp()` if not already. The canonical_songs collection is currently read-only for clients; this function will be the only writer (admin privileges). Use `admin.firestore()`.

Proceed step-by-step. First, read existing `functions/index.js` to understand structure. Then implement. Run tests via `npm test` from functions dir. Fix any errors. After successful tests, output final summary: code changes, test results (pass/fail count), and any issues.
