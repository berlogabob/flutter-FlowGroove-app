// Band/setlist MCP tools. The critical property is the SERVER-SIDE permission
// gate: the Cloud Function uses the admin SDK (bypasses Firestore rules), so
// only band admins/editors may write, and non-members may not read/write.
// Also: setlist creation must never reference songs that aren't in the band.
// Pure functions of (db, uid, ...), so a fake db is enough — no emulator.

const assert = require("node:assert/strict");
const { getBandRole, runTool } = require("../src/mcp/tools");

// Minimal Firestore stand-in. `writes` records every set() (direct or batched)
// so we can assert what was written. `bandSongs` seeds bands/{id}/songs so the
// dedup / songId-validation paths have data to read.
function fakeDb(bandDoc, bandSongs = []) {
  const writes = [];
  const songDocs = bandSongs.map((s) => ({ id: s.id, data: () => s }));
  const docRef = (sub, sid) => ({
    set: async (v) => { writes.push({ sub, sid, v }); },
  });
  const subCol = (sub) => ({
    doc: (sid) => docRef(sub, sid),
    limit: () => ({ get: async () => ({ docs: sub === "songs" ? songDocs : [] }) }),
    get: async () => ({ docs: sub === "songs" ? songDocs : [] }),
  });
  const db = {
    collection: (name) => ({
      doc: () => ({
        get: async () =>
          name === "bands"
            ? { exists: !!bandDoc, data: () => bandDoc }
            : { exists: false },
        collection: subCol,
      }),
      where: () => ({ limit: () => ({ get: async () => ({ docs: [] }) }) }),
    }),
    // batch.set(ref, v) routes through the ref's own set(), landing in writes.
    batch: () => ({
      set: (ref, v) => { ref.set(v); },
      commit: async () => {},
    }),
  };
  return { db, writes };
}

const BAND = {
  name: "super AG2700",
  adminUids: ["admin1"],
  editorUids: ["editor1"],
  memberUids: ["admin1", "editor1", "viewer1"],
};

describe("getBandRole", () => {
  it("maps uids to roles and returns null for outsiders", async () => {
    const { db } = fakeDb(BAND);
    assert.equal(await getBandRole(db, "admin1", "b"), "admin");
    assert.equal(await getBandRole(db, "editor1", "b"), "editor");
    assert.equal(await getBandRole(db, "viewer1", "b"), "viewer");
    assert.equal(await getBandRole(db, "stranger", "b"), null);
  });

  it("returns null when the band does not exist", async () => {
    const { db } = fakeDb(null);
    assert.equal(await getBandRole(db, "admin1", "missing"), null);
  });
});

describe("band write permission gate", () => {
  it("rejects a viewer creating a band song, with no write", async () => {
    const { db, writes } = fakeDb(BAND);
    const out = await runTool(db, "viewer1", "write", "create_band_song", {
      bandId: "b",
      song: { title: "X" },
    });
    assert.equal(out.status, 403);
    assert.equal(writes.length, 0);
  });

  it("rejects a non-member creating a setlist, with no write", async () => {
    const { db, writes } = fakeDb(BAND);
    const out = await runTool(db, "stranger", "write", "create_setlist", {
      bandId: "b",
      name: "AG songlist",
    });
    assert.equal(out.status, 403);
    assert.equal(writes.length, 0);
  });

  it("rejects a non-member using create_setlist_with_songs, with no write", async () => {
    const { db, writes } = fakeDb(BAND);
    const out = await runTool(db, "stranger", "write", "create_setlist_with_songs", {
      bandId: "b",
      name: "AG songlist",
      entries: [{ type: "song", title: "Zombie" }],
    });
    assert.equal(out.status, 403);
    assert.equal(writes.length, 0);
  });
});

describe("create_setlist hardening", () => {
  it("skips songIds that are not in the band and reports them", async () => {
    // Band has only song "s1"; caller passes a bogus id too.
    const { db, writes } = fakeDb(BAND, [{ id: "s1", title: "Real", artist: "" }]);
    const out = await runTool(db, "admin1", "write", "create_setlist", {
      bandId: "b",
      name: "AG songlist",
      songIds: ["s1", "ghost"],
    });
    assert.ok(out.result.id);
    assert.equal(out.result.songCount, 1);
    assert.deepEqual(out.result.ignoredSongIds, ["ghost"]);
    const setlistWrite = writes.find((w) => w.sub === "setlists");
    assert.deepEqual(setlistWrite.v.songIds, ["s1"]);
  });
});

describe("create_setlist_with_songs", () => {
  it("creates band songs + a setlist with break dividers in one call", async () => {
    const { db, writes } = fakeDb(BAND);
    const out = await runTool(db, "admin1", "write", "create_setlist_with_songs", {
      bandId: "b",
      name: "AG songlist",
      entries: [
        { type: "song", title: "Riders on the Storm", artist: "The Doors", ourKey: "Em" },
        { type: "break", breakType: "guest_set", label: "EUSTACE" },
        { type: "song", title: "Venus", artist: "Shocking Blue" },
      ],
    });
    assert.equal(out.result.songsCreated, 2);
    assert.equal(out.result.songsUpdated, 0);
    assert.equal(out.result.breaks, 1);

    const songWrites = writes.filter((w) => w.sub === "songs");
    assert.equal(songWrites.length, 2);

    const setlist = writes.find((w) => w.sub === "setlists").v;
    assert.equal(setlist.items.length, 3);
    assert.equal(setlist.songIds.length, 2); // break excluded from songIds
    const divider = setlist.items[1];
    assert.equal(divider.type, "break");
    assert.equal(divider.breakType, "guest_set");
    assert.equal(divider.breakLabel, "EUSTACE");
  });

  it("enriches (updates) an existing song matched by title+artist, reusing its id", async () => {
    const { db, writes } = fakeDb(BAND, [
      { id: "existing", title: "Venus", artist: "Shocking Blue" },
    ]);
    const out = await runTool(db, "editor1", "write", "create_setlist_with_songs", {
      bandId: "b",
      name: "AG songlist",
      entries: [
        { type: "song", title: "Venus", artist: "Shocking Blue", ourKey: "Em" },
      ],
    });
    assert.equal(out.result.songsCreated, 0);
    assert.equal(out.result.songsUpdated, 1);
    // The match is UPDATED (not skipped): a write to the existing song id with
    // the new field, keeping the same id in the setlist.
    const songWrite = writes.find((w) => w.sub === "songs");
    assert.equal(songWrite.sid, "existing");
    assert.equal(songWrite.v.ourKey, "Em");
    const setlist = writes.find((w) => w.sub === "setlists").v;
    assert.deepEqual(setlist.songIds, ["existing"]);
  });
});
