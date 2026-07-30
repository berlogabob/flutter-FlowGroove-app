// lookup_metadata / enrich_song. The resolver is injected via `deps`, so these
// never touch the network.
//
// Two behaviours carry real weight:
//
//   Fill-only by default. Deezer reports double-time BPM for some tracks (196
//   against a true ~98 for Sweet Home Alabama), so overwriting a BPM a musician
//   set by hand would corrupt the library rather than enrich it.
//
//   The sections append-guard. "Wrecking Ball" in prod carries ten real chord
//   charts followed by ten fabricated placeholder sections from an earlier fill
//   run. Enrichment must refuse to touch sections that already hold content.

const assert = require("node:assert/strict");
const { runTool } = require("../src/mcp/tools");

function fakeUserDb(songs = []) {
  const writes = [];
  const songById = new Map(songs.map((s) => [s.id, s]));
  const asDocs = () => [...songById.values()].map((s) => ({ id: s.id, data: () => s }));
  const docRef = (sub, sid) => ({
    id: sid,
    set: async (v) => { writes.push({ sub, sid, v }); },
    get: async () => ({ exists: songById.has(sid), data: () => songById.get(sid) }),
    collection: (name) => ({ doc: (cid) => docRef(`${sub}/${name}`, cid || "commit1") }),
  });
  const subCol = (sub) => ({
    doc: (sid) => docRef(sub, sid),
    limit: () => ({ get: async () => ({ docs: asDocs() }) }),
    get: async () => ({ docs: asDocs() }),
  });
  const db = {
    collection: () => ({
      doc: () => ({ get: async () => ({ exists: false }), collection: subCol }),
    }),
    batch: () => ({ set: (ref, v) => { ref.set(v); }, commit: async () => {} }),
  };
  return { db, writes };
}

const UID = "u1";

const RESOLVED = {
  found: true,
  title: "Sweet Home Alabama",
  artist: "Lynyrd Skynyrd",
  musicBrainzId: "mb-1",
  musicBrainzWorkId: "work-1",
  iswc: "T-070.076.790-3",
  album: "Second Helping",
  releaseYear: 1974,
  durationMs: 283000,
  isrc: "USMC17446153",
  spotifyId: "sp-1",
  deezerId: "dz-1",
  bpm: 196,
  sections: [
    { name: "Verse 1", chart: "Big wheels keep on turning" },
    { name: "Chorus", chart: "Sweet home Alabama" },
  ],
  sources: { album: "spotify", isrc: "spotify", bpm: "deezer", sections: "lyrics.ovh" },
  missing: [],
};

const resolverDeps = (override = {}) => ({
  resolveTrack: async () => ({ ...RESOLVED, ...override }),
});

const enrich = (db, args, override) =>
  runTool(db, UID, "write", "enrich_song", args, resolverDeps(override));

describe("lookup_metadata", () => {
  it("returns resolver output without writing anything", async () => {
    const { db, writes } = fakeUserDb([]);
    const out = await runTool(db, UID, "read", "lookup_metadata",
      { title: "Sweet Home Alabama", artist: "Lynyrd Skynyrd" }, resolverDeps());

    assert.equal(out.result.metadata.album, "Second Helping");
    assert.equal(out.result.metadata.sources.album, "spotify");
    assert.equal(writes.length, 0);
  });

  it("requires a title", async () => {
    const { db } = fakeUserDb([]);
    const out = await runTool(db, UID, "read", "lookup_metadata", { artist: "X" }, resolverDeps());
    // Dispatched through wrap(), so failures surface at the top level with a
    // status rather than nested under `result`.
    assert.match(out.error, /title is required/);
    assert.equal(out.status, 400);
  });

  it("is readable with a read-only key", async () => {
    const { db } = fakeUserDb([]);
    const out = await runTool(db, UID, "read", "lookup_metadata",
      { title: "X" }, resolverDeps());
    assert.equal(out.status, undefined);
  });
});

describe("enrich_song fill-only semantics", () => {
  const SONG = {
    id: "s1",
    title: "Sweet Home Alabama",
    artist: "Lynyrd Skynyrd",
    originalBPM: 98,
    album: null,
    isrc: null,
  };

  it("fills blanks and leaves a hand-set BPM alone", async () => {
    const { db, writes } = fakeUserDb([SONG]);
    const out = await enrich(db, { id: "s1" });

    assert.equal(out.result.found, true);
    assert.ok(out.result.applied.includes("album"));
    assert.ok(out.result.applied.includes("isrc"));
    assert.equal(out.result.skipped.originalBPM, "already set");

    const written = writes[0].v;
    assert.equal(written.album, "Second Helping");
    assert.equal(written.isrc, "USMC17446153");
    // 196 is Deezer's double-time reading; the real 98 must survive.
    assert.equal("originalBPM" in written, false);
  });

  it("overwrites only when explicitly asked", async () => {
    const { db, writes } = fakeUserDb([SONG]);
    const out = await enrich(db, { id: "s1", overwrite: true });

    assert.ok(out.result.applied.includes("originalBPM"));
    assert.equal(writes[0].v.originalBPM, 196);
  });

  it("fills a blank BPM without overwrite", async () => {
    const { db, writes } = fakeUserDb([{ ...SONG, originalBPM: null }]);
    await enrich(db, { id: "s1" });
    assert.equal(writes[0].v.originalBPM, 196);
  });

  it("reports canonical-only fields instead of writing them to the song", async () => {
    const { db, writes } = fakeUserDb([SONG]);
    const out = await enrich(db, { id: "s1" });

    assert.deepEqual(out.result.canonicalFields, {
      releaseYear: 1974,
      musicBrainzWorkId: "work-1",
      iswc: "T-070.076.790-3",
    });
    assert.equal("releaseYear" in writes[0].v, false);
    assert.equal("iswc" in writes[0].v, false);
  });

  it("passes through the provenance map", async () => {
    const { db } = fakeUserDb([SONG]);
    const out = await enrich(db, { id: "s1" });
    assert.equal(out.result.sources.album, "spotify");
    assert.equal(out.result.sources.bpm, "deezer");
  });

  it("reports found:false without writing when nothing matches", async () => {
    const { db, writes } = fakeUserDb([SONG]);
    const out = await enrich(db, { id: "s1" }, { found: false });

    assert.equal(out.result.found, false);
    assert.deepEqual(out.result.applied, []);
    assert.equal(writes.length, 0);
    assert.match(out.result.warnings[0], /no metadata match/);
  });

  it("requires an id and an existing song with a title", async () => {
    const { db } = fakeUserDb([{ id: "notitle", title: "", artist: "X" }]);
    assert.match((await enrich(db, {})).error, /id is required/);
    assert.equal((await enrich(db, { id: "missing" })).error, "not_found");
    assert.match((await enrich(db, { id: "notitle" })).error, /no title/);
  });

  it("refuses to write with a read-only key", async () => {
    const { db, writes } = fakeUserDb([SONG]);
    const out = await runTool(db, UID, "read", "enrich_song", { id: "s1" }, resolverDeps());
    assert.equal(out.status, 403);
    assert.equal(writes.length, 0);
  });
});

describe("enrich_song sections append-guard", () => {
  const base = { id: "s1", title: "Sweet Home Alabama", artist: "Lynyrd Skynyrd" };

  it("adds lyric sections to a song with no section content", async () => {
    const { db, writes } = fakeUserDb([{ ...base, sections: [] }]);
    const out = await enrich(db, { id: "s1" });

    assert.ok(out.result.applied.includes("sections"));
    assert.equal(writes[0].v.sections.length, 2);
    assert.equal(writes[0].v.sections[0].chordChart, "Big wheels keep on turning");
  });

  it("refuses when existing sections already carry chord charts", async () => {
    const { db, writes } = fakeUserDb([{
      ...base,
      sections: [{ name: "Intro", chordChart: "| D | C | G |" }],
    }]);
    const out = await enrich(db, { id: "s1" });

    assert.equal(out.result.skipped.sections, "existing sections already have chord charts");
    assert.equal("sections" in writes[0].v, false);
  });

  it("refuses when existing sections are already lyric-labelled", async () => {
    const { db } = fakeUserDb([{
      ...base,
      sections: [{ name: "Verse 1", chordChart: "" }, { name: "Chorus", chordChart: "" }],
    }]);
    const out = await enrich(db, { id: "s1" });
    assert.match(out.result.skipped.sections, /already labelled as lyrics/);
  });

  it("keeps empty structural sections and appends after them", async () => {
    const { db, writes } = fakeUserDb([{
      ...base,
      sections: [{ name: "Intro", chordChart: "" }, { name: "Solo", chordChart: "" }],
    }]);
    await enrich(db, { id: "s1" });

    const written = writes[0].v.sections;
    assert.equal(written.length, 4);
    assert.equal(written[0].name, "Intro");
    assert.equal(written[2].name, "Verse 1");
  });

  it("can be told to skip lyrics entirely", async () => {
    const { db, writes } = fakeUserDb([{ ...base, sections: [] }]);
    const out = await enrich(db, { id: "s1", includeLyrics: false });
    assert.equal(out.result.applied.includes("sections"), false);
    assert.equal("sections" in writes[0].v, false);
  });
});

describe("enrich_song links", () => {
  const base = { id: "s1", title: "Sweet Home Alabama", artist: "Lynyrd Skynyrd" };

  it("adds provenance links", async () => {
    const { db, writes } = fakeUserDb([{ ...base, links: [] }]);
    await enrich(db, { id: "s1" });

    const urls = writes[0].v.links.map((l) => l.url);
    assert.ok(urls.some((u) => u.includes("musicbrainz.org/recording/mb-1")));
    assert.ok(urls.some((u) => u.includes("open.spotify.com/track/sp-1")));
    assert.ok(urls.some((u) => u.includes("youtube.com")));
    assert.ok(urls.some((u) => u.includes("ultimate-guitar.com")));
  });

  it("does not duplicate links on a second run", async () => {
    const existing = [{
      type: "other", title: "MusicBrainz",
      url: "https://musicbrainz.org/recording/mb-1",
    }];
    const { db, writes } = fakeUserDb([{ ...base, links: existing }]);
    await enrich(db, { id: "s1" });

    const urls = writes[0].v.links.map((l) => l.url);
    assert.equal(urls.filter((u) => u.includes("musicbrainz.org")).length, 1);
  });

  it("adds nothing when every link is already present", async () => {
    const { db, writes } = fakeUserDb([{ ...base, links: [], album: "Second Helping" }]);
    await enrich(db, { id: "s1" });
    const firstLinks = writes[0].v.links;

    const { db: db2, writes: writes2 } = fakeUserDb([{ ...base, links: firstLinks, album: "Second Helping", isrc: "USMC17446153", durationMs: 283000, spotifyId: "sp-1", musicbrainzId: "mb-1", originalBPM: 98, sections: [{ name: "Verse 1", chordChart: "x" }] }]);
    const out = await enrich(db2, { id: "s1" });

    assert.deepEqual(out.result.applied, []);
    assert.equal(writes2.length, 0, "a fully enriched song must produce no write");
  });
});

describe("enrich_song on a linked (schemaVersion 2) song", () => {
  const LINKED = {
    id: "linked1",
    schemaVersion: 2,
    canonicalSongId: "canon1",
    baseRevision: 1,
    latestCommitId: "c0",
    delta: { ourKey: "C" },
    materialized: {
      id: "linked1",
      title: "Sweet Home Alabama",
      artist: "Lynyrd Skynyrd",
      album: "Wrong Album",
      sections: [],
      links: [],
      bandId: null,
    },
  };

  it("writes only delta fields and routes the rest to canonicalFields", async () => {
    const { db, writes } = fakeUserDb([LINKED]);
    const out = await enrich(db, { id: "linked1" });

    assert.equal(out.result.skipped.album, "owned by the canonical song");
    assert.equal(out.result.skipped.isrc, "owned by the canonical song");
    assert.equal(out.result.canonicalFields.album, "Second Helping");
    assert.equal(out.result.canonicalFields.isrc, "USMC17446153");
    assert.equal(out.result.canonicalFields.musicBrainzId, "mb-1");
    assert.equal(out.result.canonicalFields.baseBpm, 196);
    assert.equal(out.result.canonicalFields.releaseYear, 1974);

    const songWrite = writes.find((w) => w.sub === "songs");
    assert.equal(songWrite.materialized, undefined);
    assert.equal("album" in songWrite.v, false);
    assert.equal(songWrite.v.materialized.album, "Wrong Album", "canonical owns the album");
    assert.ok(songWrite.v.delta.sections, "sections belong in the delta");
    assert.equal(songWrite.v.delta.ourKey, "C", "existing delta survives");
    assert.ok(out.result.commitId);
  });
});
