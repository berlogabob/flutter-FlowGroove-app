// update_song (the PERSONAL library tool) had two bugs that update_band_song
// did not:
//
//   1. No isLinked branch. On a schemaVersion-2 song it flat-merged top-level
//      fields, but the app renders canonical+delta (falling back to
//      `materialized`) — so the write was silently invisible. The user saw
//      "saved" and nothing changed.
//   2. validateSong always returns a full song shape with artist: "" when
//      absent, and update_song merged that whole shape, so any partial patch
//      BLANKED the artist.
//
// Both matter for enrichment, which is partial-patch by nature: filling an ISRC
// must not erase the artist, and filling a linked song's sections must land
// where the app looks.
//
// Pure functions of (db, uid, args), so a fake db is enough — no emulator.

const assert = require("node:assert/strict");
const { runTool } = require("../src/mcp/tools");

// Firestore stand-in for users/{uid}/songs. `writes` records every set(),
// direct or batched, so we can assert exactly what landed where.
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

const UID = "7RPi5xPJV5XeTm0SIWubea9DVjJ3";

const FLAT_SONG = {
  id: "flat1",
  title: "Sweet Home Alabama",
  artist: "Lynyrd Skynyrd",
  originalKey: "G",
  originalBPM: 98,
  ourBPM: 98,
  tags: ["ready"],
};

const LINKED_SONG = {
  id: "linked1",
  schemaVersion: 2,
  canonicalSongId: "normalized_5cc9cdb41734266b6517b74939270c64",
  ownerType: "user",
  ownerId: UID,
  baseRevision: 1,
  latestCommitId: "commit0",
  delta: { ourKey: "C", notes: "nothing", tags: ["fast"] },
  materialized: {
    id: "linked1",
    title: "Back to Black",
    artist: "Amy Winehouse",
    album: "Greatest Hits",
    durationMs: 283000,
    ourKey: "C",
    ourBPM: 123,
    notes: "nothing",
    tags: ["fast"],
    bandId: null,
  },
};

const call = (db, args) => runTool(db, UID, "write", "update_song", args);

describe("update_song on a flat personal song", () => {
  it("does not blank the artist on a partial patch", async () => {
    const { db, writes } = fakeUserDb([FLAT_SONG]);
    const out = await call(db, { id: "flat1", song: { isrc: "USMC17446153" } });

    assert.equal(out.result.id, "flat1");
    assert.equal(writes.length, 1);
    assert.equal(writes[0].v.isrc, "USMC17446153");
    assert.equal("artist" in writes[0].v, false, "artist must not be written at all");
    assert.equal("title" in writes[0].v, false);
  });

  it("writes only the fields the caller actually sent", async () => {
    const { db, writes } = fakeUserDb([FLAT_SONG]);
    await call(db, { id: "flat1", song: { album: "Second Helping", releaseYear: 1974 } });

    const written = writes[0].v;
    assert.equal(written.album, "Second Helping");
    // Untouched values must not be echoed back, so a concurrent edit is not
    // silently reverted.
    assert.equal("ourBPM" in written, false);
    assert.equal("tags" in written, false);
    assert.equal("originalKey" in written, false);
  });

  it("accepts a flat patch as well as {id, song}", async () => {
    const { db, writes } = fakeUserDb([FLAT_SONG]);
    await call(db, { id: "flat1", ourKey: "Am" });

    assert.equal(writes[0].v.ourKey, "Am");
    assert.equal("artist" in writes[0].v, false);
    // The id must not leak into the patch as a song field.
    assert.equal(writes[0].v.id, "flat1");
  });

  it("still updates title and artist when they are explicitly sent", async () => {
    const { db, writes } = fakeUserDb([FLAT_SONG]);
    await call(db, { id: "flat1", song: { title: "Sweet Home Alabama", artist: "Lynyrd Skynyrd Band" } });

    assert.equal(writes[0].v.artist, "Lynyrd Skynyrd Band");
  });

  it("reports not_found for a missing song and requires an id", async () => {
    const { db, writes } = fakeUserDb([FLAT_SONG]);
    assert.equal((await call(db, { id: "nope", song: { ourKey: "C" } })).result.error, "not_found");
    assert.match((await call(db, { song: { ourKey: "C" } })).result.error, /id is required/);
    assert.equal(writes.length, 0);
  });
});

describe("update_song on a linked (schemaVersion 2) personal song", () => {
  it("writes delta + materialized + a commit instead of flat fields", async () => {
    const { db, writes } = fakeUserDb([LINKED_SONG]);
    const out = await call(db, { id: "linked1", song: { ourBPM: 124 } });

    assert.ok(out.result.commitId, "a linked update must append a commit");

    const songWrite = writes.find((w) => w.sub === "songs");
    const commitWrite = writes.find((w) => w.sub === "songs/commits");
    assert.ok(songWrite, "expected a write to the song doc");
    assert.ok(commitWrite, "expected a write to the commits subcollection");

    // The whole point: nothing lands as a top-level song field.
    assert.equal("ourBPM" in songWrite.v, false);
    assert.equal(songWrite.v.delta.ourBPM, 124);
    assert.equal(songWrite.v.materialized.ourBPM, 124);

    assert.equal(commitWrite.v.operation, "update");
    assert.equal(commitWrite.v.authorId, UID);
    assert.equal(commitWrite.v.parentCommitId, "commit0");
    assert.equal(commitWrite.v.canonicalSongId, LINKED_SONG.canonicalSongId);
  });

  it("keeps delta fields it was not asked to change", async () => {
    const { db, writes } = fakeUserDb([LINKED_SONG]);
    await call(db, { id: "linked1", song: { ourBPM: 124 } });

    const { delta } = writes.find((w) => w.sub === "songs").v;
    assert.equal(delta.ourKey, "C", "pre-existing delta.ourKey must survive");
    assert.equal(delta.notes, "nothing");
    assert.deepEqual(delta.tags, ["fast"]);
  });

  it("keeps materialized fields it was not asked to change", async () => {
    const { db, writes } = fakeUserDb([LINKED_SONG]);
    await call(db, { id: "linked1", song: { ourBPM: 124 } });

    const { materialized } = writes.find((w) => w.sub === "songs").v;
    assert.equal(materialized.title, "Back to Black");
    assert.equal(materialized.artist, "Amy Winehouse");
    assert.equal(materialized.album, "Greatest Hits");
  });

  it("refuses canonical-owned fields and does not write them to materialized", async () => {
    const { db, writes } = fakeUserDb([LINKED_SONG]);
    const out = await call(db, {
      id: "linked1",
      song: { title: "Hacked", artist: "Hacked", album: "Hacked", durationMs: 1, ourKey: "Dm" },
    });

    const warnings = out.result.warnings.join(" | ");
    for (const field of ["title", "artist", "album", "durationMs"]) {
      assert.match(warnings, new RegExp(`${field} is owned by the canonical song`));
    }

    const { materialized, delta } = writes.find((w) => w.sub === "songs").v;
    // The old update_band_song warned about these and then merged them anyway,
    // so the warning was a lie. They must genuinely not be written.
    assert.equal(materialized.title, "Back to Black");
    assert.equal(materialized.artist, "Amy Winehouse");
    assert.equal(materialized.album, "Greatest Hits");
    assert.equal(materialized.durationMs, 283000);
    // The legitimate delta field in the same patch still applies.
    assert.equal(delta.ourKey, "Dm");
  });

  it("does not invent a bandId on a personal song", async () => {
    const { db, writes } = fakeUserDb([LINKED_SONG]);
    await call(db, { id: "linked1", song: { ourBPM: 124 } });

    const { materialized } = writes.find((w) => w.sub === "songs").v;
    assert.equal(materialized.bandId, null);
  });

  it("stores sections in the delta so lyrics survive a canonical refresh", async () => {
    const { db, writes } = fakeUserDb([LINKED_SONG]);
    await call(db, {
      id: "linked1",
      song: { sections: [{ name: "Verse 1", chordChart: "He left no time to regret" }] },
    });

    const { delta, materialized } = writes.find((w) => w.sub === "songs").v;
    assert.equal(delta.sections.length, 1);
    assert.equal(delta.sections[0].name, "Verse 1");
    assert.ok(delta.sections[0].id, "sections must get ids");
    assert.equal(materialized.sections.length, 1);
  });
});

describe("update_song scope gate", () => {
  it("refuses to write with a read-only key", async () => {
    const { db, writes } = fakeUserDb([FLAT_SONG]);
    const out = await runTool(db, UID, "read", "update_song", {
      id: "flat1", song: { ourKey: "C" },
    });
    assert.equal(out.status, 403);
    assert.equal(writes.length, 0);
  });
});
