/**
 * lookupTrackMetadata — the app's door to the shared resolver.
 *
 * Before this, the Flutter client fanned out to MusicBrainz, Deezer and Spotify
 * itself, which meant (a) the Spotify client secret had to exist in the app
 * bundle, and (b) the album-selection heuristic lived in Dart while the agent
 * path had its own copy. Fixing one never fixed the other — which is how
 * canonical_songs ended up with "Apocalypse Now" as the album for Light My Fire.
 *
 * A callable rather than an onRequest endpoint: callables are addressed by name,
 * so the client needs no URL, no dart-define, and no entry in web/config.js —
 * and Firebase attaches the caller's identity for free.
 *
 * ponytail: no per-user rate limiting here. The resolver's per-host gate keeps a
 * single instance inside MusicBrainz's 1 req/sec, and the Firestore cache in
 * Stage 7 is the real fix for scale. Add a token bucket keyed by uid only if
 * abuse shows up in the logs.
 */

const functions = require("firebase-functions");

const { resolveTrack } = require("./resolver");
const { spotifyCredentials, spotifySecrets } = require("./credentials");

/**
 * The handler, separated from the onCall wrapper so the auth and shape logic is
 * testable without a network round trip. `deps.resolveTrack` is the seam.
 */
async function handleLookup(request, deps = {}) {
  const data = (request && request.data) || {};
  if (!request || !request.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Request must be authenticated.",
    );
  }

  const title = typeof data.title === "string" ? data.title.trim() : "";
  const artist = typeof data.artist === "string" ? data.artist.trim() : "";
  if (!title) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "title is required.",
    );
  }

  const resolve = deps.resolveTrack || resolveTrack;
  // Demo users are deliberately allowed: this only reads public catalogs and
  // writes nothing, so there is nothing for a demo account to damage.
  const resolved = await resolve({ title, artist }, {
    spotifyCredentials: deps.spotifyCredentials
      ? deps.spotifyCredentials()
      : spotifyCredentials(),
    // The caller may not want the slowest source. lyrics.ovh gets a 20s
    // timeout and is useless for instrumentals.
    skip: Array.isArray(data.skip)
      ? data.skip.filter((s) => typeof s === "string")
      : [],
  });

  return {
    found: resolved.found,
    title: resolved.title,
    artist: resolved.artist,
    album: resolved.album,
    releaseYear: resolved.releaseYear,
    durationMs: resolved.durationMs,
    isrc: resolved.isrc,
    spotifyId: resolved.spotifyId,
    musicBrainzId: resolved.musicBrainzId,
    musicBrainzWorkId: resolved.musicBrainzWorkId,
    iswc: resolved.iswc,
    deezerId: resolved.deezerId,
    bpm: resolved.bpm,
    sections: resolved.sections || [],
    // Per-field provenance, so the client can label what came from where and
    // never present a guess as sourced data.
    sources: resolved.sources || {},
    missing: resolved.missing || [],
  };
}

exports.handleLookup = handleLookup;
exports.lookupTrackMetadata = functions.https.onCall(
  { secrets: spotifySecrets },
  (request) => handleLookup(request),
);
