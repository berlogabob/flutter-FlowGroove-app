// Response cache for the metadata resolver.
//
// Why it exists: MusicBrainz is intermittently unreachable from Cloud Functions.
// It works locally and usually works in us-central1, but a real deployed call
// logged "musicbrainz/search failed: fetch failed" through all three retries,
// losing the MBID and ISWC for that lookup. A cached success makes the next call
// immune. It also keeps concurrent users inside MusicBrainz's 1 req/sec limit,
// which the per-instance gate in http.js cannot do alone.

const assert = require("node:assert/strict");
const { firestoreCache, cacheKey, COLLECTION } = require("../src/metadata/cache");
const { fetchJson, resetGate } = require("../src/metadata/http");

const noSleep = async () => {};

// Minimal Firestore stand-in for a single collection of docs.
function fakeDb() {
  const docs = new Map();
  const reads = [];
  const writes = [];
  return {
    docs, reads, writes,
    collection: (name) => ({
      doc: (id) => ({
        get: async () => {
          reads.push(`${name}/${id}`);
          return { exists: docs.has(id), data: () => docs.get(id) };
        },
        set: async (v) => {
          writes.push(`${name}/${id}`);
          docs.set(id, v);
        },
      }),
    }),
  };
}

function jsonRes(body, status = 200) {
  return {
    ok: status >= 200 && status < 300,
    status,
    headers: { get: () => null },
    json: async () => body,
  };
}

describe("cacheKey", () => {
  it("is stable for the same url and differs across urls", () => {
    const a = cacheKey("https://musicbrainz.org/ws/2/recording/?query=x");
    assert.equal(a, cacheKey("https://musicbrainz.org/ws/2/recording/?query=x"));
    assert.notEqual(a, cacheKey("https://musicbrainz.org/ws/2/recording/?query=y"));
  });

  it("carries the host so entries are legible in the console", () => {
    assert.match(cacheKey("https://api.deezer.com/track/1"), /^api\.deezer\.com__[0-9a-f]{40}$/);
  });

  it("survives a malformed url", () => {
    assert.match(cacheKey("not a url"), /^unknown__[0-9a-f]{40}$/);
  });
});

describe("firestoreCache", () => {
  it("round-trips a payload", async () => {
    const db = fakeDb();
    const cache = firestoreCache(db);
    assert.equal(await cache.get("https://x.test/a"), undefined);
    await cache.set("https://x.test/a", { hello: "world", n: [1, 2] });
    assert.deepEqual(await cache.get("https://x.test/a"), { hello: "world", n: [1, 2] });
  });

  it("writes into the metadata_cache collection with an expiry", async () => {
    const db = fakeDb();
    await firestoreCache(db).set("https://x.test/a", { a: 1 });
    assert.ok(db.writes[0].startsWith(`${COLLECTION}/`));
    const stored = [...db.docs.values()][0];
    assert.equal(stored.url, "https://x.test/a");
    assert.ok(stored.expiresAt instanceof Date);
    assert.ok(stored.expiresAt.getTime() > Date.now());
  });

  it("ignores an expired entry", async () => {
    const db = fakeDb();
    const cache = firestoreCache(db, { ttlMs: -1000 });
    await cache.set("https://x.test/a", { a: 1 });
    assert.equal(await cache.get("https://x.test/a"), undefined);
  });

  it("accepts a Firestore Timestamp for expiresAt", async () => {
    const db = fakeDb();
    const key = cacheKey("https://x.test/a");
    db.docs.set(key, {
      url: "https://x.test/a",
      body: JSON.stringify({ a: 1 }),
      expiresAt: { toMillis: () => Date.now() + 60000 },
    });
    assert.deepEqual(await firestoreCache(db).get("https://x.test/a"), { a: 1 });
  });

  it("never lets a broken cache break a lookup", async () => {
    const broken = {
      collection: () => ({
        doc: () => ({
          get: async () => { throw new Error("firestore down"); },
          set: async () => { throw new Error("firestore down"); },
        }),
      }),
    };
    const cache = firestoreCache(broken);
    assert.equal(await cache.get("https://x.test/a"), undefined);
    await cache.set("https://x.test/a", { a: 1 }); // must not throw
  });

  it("skips a payload too large for a Firestore document", async () => {
    const db = fakeDb();
    await firestoreCache(db).set("https://x.test/big", { blob: "x".repeat(950000) });
    assert.equal(db.writes.length, 0);
  });
});

describe("fetchJson with a cache", () => {
  beforeEach(() => resetGate());

  it("serves the second call from cache without a second fetch", async () => {
    const db = fakeDb();
    const cache = firestoreCache(db);
    let calls = 0;
    const fetchImpl = async () => { calls += 1; return jsonRes({ mbid: "abc" }); };
    const url = "https://musicbrainz.org/ws/2/recording/?query=x";

    assert.deepEqual(await fetchJson(url, { cache, fetchImpl, sleepImpl: noSleep }), { mbid: "abc" });
    assert.deepEqual(await fetchJson(url, { cache, fetchImpl, sleepImpl: noSleep }), { mbid: "abc" });
    assert.equal(calls, 1, "second call must come from cache");
  });

  it("makes a cached success immune to a later outage", async () => {
    // The exact scenario observed in production: MusicBrainz throws on every
    // retry. With a warm cache the lookup still succeeds.
    const db = fakeDb();
    const cache = firestoreCache(db);
    const url = "https://musicbrainz.org/ws/2/recording/?query=x";
    await fetchJson(url, { cache, sleepImpl: noSleep, fetchImpl: async () => jsonRes({ mbid: "abc" }) });

    const out = await fetchJson(url, {
      cache, sleepImpl: noSleep, attempts: 3,
      fetchImpl: async () => { throw new Error("fetch failed"); },
    });
    assert.deepEqual(out, { mbid: "abc" });
  });

  it("never caches a POST — the Spotify token carries credentials", async () => {
    const db = fakeDb();
    const cache = firestoreCache(db);
    let calls = 0;
    const fetchImpl = async () => { calls += 1; return jsonRes({ access_token: "t" }); };
    const args = {
      cache, fetchImpl, sleepImpl: noSleep, method: "POST",
      body: "grant_type=client_credentials",
    };
    await fetchJson("https://accounts.spotify.com/api/token", args);
    await fetchJson("https://accounts.spotify.com/api/token", args);
    assert.equal(calls, 2, "token exchange must never be cached");
    assert.equal(db.writes.length, 0);
  });

  it("does not cache a failure, so an outage is not pinned for the whole TTL", async () => {
    const db = fakeDb();
    const cache = firestoreCache(db);
    await fetchJson("https://api.deezer.com/track/1", {
      cache, sleepImpl: noSleep, attempts: 1,
      fetchImpl: async () => jsonRes({}, 500),
    });
    assert.equal(db.writes.length, 0);
  });

  it("works with no cache supplied at all", async () => {
    const out = await fetchJson("https://api.deezer.com/track/1", {
      sleepImpl: noSleep,
      fetchImpl: async () => jsonRes({ bpm: 120 }),
    });
    assert.deepEqual(out, { bpm: 120 });
  });
});
