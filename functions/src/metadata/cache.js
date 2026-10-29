/**
 * Firestore-backed response cache for the metadata resolver.
 *
 * Two problems this solves, in order of how much they hurt:
 *
 *  1. MusicBrainz is intermittently unreachable from Cloud Functions. It works
 *     locally and usually works in us-central1, but sometimes every retry throws
 *     "fetch failed" — and a miss means no MBID and no ISWC for that lookup. A
 *     cached success makes the next call immune to a transient outage.
 *  2. Rate limits. MusicBrainz allows 1 req/sec and the per-host gate in http.js
 *     only serialises a single instance. Under real concurrency, caching is what
 *     keeps us inside the limit rather than hoping.
 *
 * Keyed by request URL, so it is provider-agnostic and needs no knowledge of
 * query shapes. Only GETs are cached — never the Spotify token POST.
 *
 * ponytail: nothing here deletes expired entries — a Firestore TTL policy on
 * `expiresAt` does it, enabled 2026-07-30 and ACTIVE:
 *
 *   gcloud firestore fields ttls list --collection-group=metadata_cache
 *
 * The read path below already treats an expired entry as absent, so the policy
 * only reclaims storage and can never change a lookup's result. No sweeper cron.
 */

const crypto = require("node:crypto");

const COLLECTION = "metadata_cache";
const DEFAULT_TTL_MS = 30 * 24 * 60 * 60 * 1000; // 30 days

// Metadata for a released track does not change. Lyrics and BPM effectively
// never do either, so one TTL covers every provider.
function cacheKey(url) {
  let host = "unknown";
  try {
    host = new URL(url).host.replace(/[^a-z0-9.]/gi, "");
  } catch (_) {
    // keep the fallback
  }
  const hash = crypto.createHash("sha256").update(url).digest("hex").slice(0, 40);
  return `${host}__${hash}`;
}

/**
 * @param {import("firebase-admin").firestore.Firestore} db
 * @param {{ttlMs?: number}} [options]
 * @returns {{get: (url: string) => Promise<any>, set: (url: string, body: any) => Promise<void>}}
 */
function firestoreCache(db, options = {}) {
  const ttlMs = options.ttlMs || DEFAULT_TTL_MS;

  return {
    async get(url) {
      try {
        const doc = await db.collection(COLLECTION).doc(cacheKey(url)).get();
        if (!doc.exists) return undefined;
        const data = doc.data() || {};
        const expiresAt = data.expiresAt && typeof data.expiresAt.toMillis === "function"
          ? data.expiresAt.toMillis()
          : Number(data.expiresAt);
        if (!Number.isFinite(expiresAt) || expiresAt < Date.now()) return undefined;
        // Stored as a JSON string: Firestore rejects undefined and mangles deeply
        // nested arrays-of-maps, and provider payloads are both.
        return typeof data.body === "string" ? JSON.parse(data.body) : undefined;
      } catch (err) {
        // A cache must never be the reason a lookup fails.
        console.warn(`[metadata] cache read failed: ${err.message}`);
        return undefined;
      }
    },

    async set(url, body) {
      try {
        const serialized = JSON.stringify(body);
        // Firestore's document limit is ~1 MiB; a giant payload is not worth a
        // failed write and a confusing log line.
        if (serialized.length > 900000) return;
        await db.collection(COLLECTION).doc(cacheKey(url)).set({
          url,
          body: serialized,
          fetchedAt: new Date(),
          expiresAt: new Date(Date.now() + ttlMs),
        });
      } catch (err) {
        console.warn(`[metadata] cache write failed: ${err.message}`);
      }
    },
  };
}

module.exports = { firestoreCache, cacheKey, COLLECTION, DEFAULT_TTL_MS };
