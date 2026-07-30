// lookupTrackMetadata — the app's entry point to the shared resolver.
//
// Tests the handler directly with an injected resolver, so no network and no
// emulator. What matters here is the contract the Flutter client depends on:
// auth is required, a title is required, and `sources` always comes back so the
// UI can label sourced data versus a guess.

const assert = require("node:assert/strict");

process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "repsync-app-callable-test";
process.env.FIREBASE_CONFIG = process.env.FIREBASE_CONFIG ||
  JSON.stringify({ projectId: "repsync-app-callable-test" });

const { handleLookup, lookupTrackMetadata } = require("../src/metadata/callable");

const RESOLVED = {
  found: true,
  title: "Sweet Home Alabama",
  artist: "Lynyrd Skynyrd",
  album: "Second Helping",
  releaseYear: 1974,
  durationMs: 283800,
  isrc: "USMC17446153",
  spotifyId: "sp1",
  musicBrainzId: "mb1",
  musicBrainzWorkId: "work1",
  iswc: "T-070.924.653-6",
  deezerId: "dz1",
  bpm: 98,
  sections: [{ name: "Verse 1", chart: "Big wheels keep on turning" }],
  sources: { album: "spotify", bpm: "deezer" },
  missing: [],
};

function deps(overrides = {}) {
  const calls = [];
  return {
    calls,
    resolveTrack: async (query, options) => {
      calls.push({ query, options });
      return { ...RESOLVED, ...overrides };
    },
    spotifyCredentials: () => ({ clientId: "a", clientSecret: "b" }),
  };
}

const authed = (data) => ({ data, auth: { uid: "u1", token: {} } });

describe("lookupTrackMetadata", () => {
  it("declares both Spotify secrets on its endpoint", () => {
    // If this regresses, the deployed function silently loses Spotify and every
    // album/ISRC comes back null.
    const keys = (lookupTrackMetadata.__endpoint.secretEnvironmentVariables || [])
      .map((s) => s.key)
      .sort();
    assert.deepEqual(keys, ["SPOTIFY_CLIENT_ID", "SPOTIFY_CLIENT_SECRET"]);
  });

  it("rejects an unauthenticated caller", async () => {
    await assert.rejects(
      () => handleLookup({ data: { title: "X" } }, deps()),
      (e) => e.code === "unauthenticated",
    );
    await assert.rejects(
      () => handleLookup(undefined, deps()),
      (e) => e.code === "unauthenticated",
    );
  });

  it("requires a title", async () => {
    for (const data of [{}, { title: "" }, { title: "   " }, { artist: "A" }]) {
      await assert.rejects(
        () => handleLookup(authed(data), deps()),
        (e) => e.code === "invalid-argument",
        `expected rejection for ${JSON.stringify(data)}`,
      );
    }
  });

  it("returns the resolved record with its provenance map", async () => {
    const out = await handleLookup(
      authed({ title: "Sweet Home Alabama", artist: "Lynyrd Skynyrd" }),
      deps(),
    );
    assert.equal(out.found, true);
    assert.equal(out.album, "Second Helping");
    assert.equal(out.releaseYear, 1974);
    assert.equal(out.isrc, "USMC17446153");
    assert.equal(out.iswc, "T-070.924.653-6");
    assert.equal(out.bpm, 98);
    assert.equal(out.sections.length, 1);
    assert.equal(out.sources.album, "spotify");
    assert.equal(out.sources.bpm, "deezer");
  });

  it("never returns a key — no provider exposes one", async () => {
    const out = await handleLookup(authed({ title: "X" }), deps());
    assert.equal("originalKey" in out, false);
    assert.equal("ourKey" in out, false);
    assert.equal("key" in out.sources, false);
  });

  it("trims the query and forwards it to the resolver", async () => {
    const d = deps();
    await handleLookup(authed({ title: "  Zombie  ", artist: "  The Cranberries " }), d);
    assert.deepEqual(d.calls[0].query, { title: "Zombie", artist: "The Cranberries" });
  });

  it("passes a skip list through and ignores non-strings in it", async () => {
    const d = deps();
    await handleLookup(authed({ title: "X", skip: ["lyrics", 7, null, "deezer"] }), d);
    assert.deepEqual(d.calls[0].options.skip, ["lyrics", "deezer"]);
  });

  it("defaults skip to empty when absent or malformed", async () => {
    const d = deps();
    await handleLookup(authed({ title: "X", skip: "lyrics" }), d);
    assert.deepEqual(d.calls[0].options.skip, []);
  });

  it("returns found:false without inventing fields", async () => {
    const out = await handleLookup(
      authed({ title: "Timegun", artist: "Offbeats." }),
      deps({ found: false, album: null, isrc: null, sources: {}, sections: null }),
    );
    assert.equal(out.found, false);
    assert.equal(out.album, null);
    assert.deepEqual(out.sources, {});
    assert.deepEqual(out.sections, []);
  });

  it("allows a demo user — it reads public catalogs and writes nothing", async () => {
    const out = await handleLookup(
      { data: { title: "X" }, auth: { uid: "demo", token: { demo: true } } },
      deps(),
    );
    assert.equal(out.found, true);
  });
});
