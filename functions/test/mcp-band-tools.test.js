// Band/setlist MCP tools. The critical property is the SERVER-SIDE permission
// gate: the Cloud Function uses the admin SDK (bypasses Firestore rules), so
// only band admins/editors may write, and non-members may not read/write.
// Also: setlist creation must never reference songs that aren't in the band.
// Pure functions of (db, uid, ...), so a fake db is enough — no emulator.

const assert = require("node:assert/strict");
const { getBandRole, runTool } = require("../src/mcp/tools");

// Minimal Firestore stand-in. `writes` records every set() (direct or batched)
// and `deletes` every delete(), so we can assert what was written. `songs` seeds
// the {bands|users}/{id}/songs subcollection so the dedup / songId-validation
// paths have data to read; `setlistIds` seeds existing setlist docs for delete.
function fakeDb(bandDoc, songs = [], setlists = []) {
  const writes = [];
  const deletes = [];
  const songDocs = songs.map((s) => ({ id: s.id, data: () => s }));
  // `setlists` seeds existing setlist docs: an id string, or { id, ...data }.
  const setlistDocs = new Map(
    setlists.map((s) => (typeof s === "string" ? [s, { id: s }] : [s.id, s])),
  );
  const songById = new Map(songs.map((s) => [s.id, s]));
  const docRef = (sub, sid) => ({
    id: sid,
    set: async (v) => { writes.push({ sub, sid, v }); },
    get: async () => ({
      exists: sub === "setlists" ? setlistDocs.has(sid) : songById.has(sid),
      data: () => (sub === "setlists" ? setlistDocs.get(sid) : songById.get(sid)),
    }),
    delete: async () => { deletes.push({ sub, sid }); },
    // Linked songs append a commit under songs/{id}/commits.
    collection: (name) => ({ doc: (cid) => docRef(`${sub}/${name}`, cid || "commit1") }),
  });
  const docsFor = (sub) => {
    if (sub === "songs") return songDocs;
    if (sub === "setlists") {
      return [...setlistDocs.values()].map((s) => ({ id: s.id, data: () => s }));
    }
    return [];
  };
  const subCol = (sub) => ({
    doc: (sid) => docRef(sub, sid),
    limit: () => ({ get: async () => ({ docs: docsFor(sub) }) }),
    get: async () => ({ docs: docsFor(sub) }),
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
  return { db, writes, deletes };
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

// schemaVersion 2 ("linked") songs keep the readable song under `materialized`
// and the app renders canonical + delta. Reading top-level fields showed them as
// blank rows; writing top-level fields would be invisible in the app.
const LINKED_SONG = {
  id: "linked1",
  schemaVersion: 2,
  canonicalSongId: "normalized_abc",
  ownerType: "band",
  baseRevision: 1,
  latestCommitId: "c0",
  delta: { beatModes: { "0-0": "accent" } },
  materialized: { id: "linked1", title: "День рождения", artist: "Ленинград" },
};

describe("linked (schemaVersion 2) songs", () => {
  it("list_band_songs reads through materialized instead of returning blanks", async () => {
    const { db } = fakeDb(BAND, [LINKED_SONG]);
    const out = await runTool(db, "viewer1", "read", "list_band_songs", { bandId: "b" });
    assert.deepEqual(out.result.songs, [
      { id: "linked1", title: "День рождения", artist: "Ленинград", ourKey: null, ourBPM: null },
    ]);
  });

  it("update_band_song merges the delta, keeps existing delta fields, and commits", async () => {
    const { db, writes } = fakeDb(BAND, [LINKED_SONG]);
    const out = await runTool(db, "admin1", "write", "update_band_song", {
      bandId: "b",
      id: "linked1",
      song: { ourKey: "Am", ourBPM: 76, sections: [{ name: "Куплет", chordChart: "[Am]Все эти" }] },
    });
    assert.equal(out.error, undefined);

    const songWrite = writes.find((w) => w.sub === "songs");
    assert.equal(songWrite.sid, "linked1");
    assert.equal(songWrite.v.delta.ourKey, "Am");
    assert.equal(songWrite.v.delta.ourBPM, 76);
    assert.equal(songWrite.v.delta.sections.length, 1);
    // pre-existing delta field survives
    assert.deepEqual(songWrite.v.delta.beatModes, { "0-0": "accent" });
    // canonical-owned fields stay in materialized, untouched
    assert.equal(songWrite.v.materialized.artist, "Ленинград");
    assert.ok(songWrite.v.materialized.sections[0].id, "sections need ids");

    const commit = writes.find((w) => w.sub === "songs/commits");
    assert.equal(commit.v.parentCommitId, "c0");
    assert.equal(commit.v.authorId, "admin1");
    assert.equal(songWrite.v.latestCommitId, commit.v.id);
  });

  it("update_band_song reports that title/artist belong to the canonical song", async () => {
    const { db } = fakeDb(BAND, [LINKED_SONG]);
    const out = await runTool(db, "admin1", "write", "update_band_song", {
      bandId: "b",
      id: "linked1",
      song: { title: "Другое название", ourKey: "Am" },
    });
    assert.ok(out.result.warnings.some((w) => w.includes("canonical")));
  });

  it("update_band_song refuses viewers and unknown ids", async () => {
    const { db, writes } = fakeDb(BAND, [LINKED_SONG]);
    const denied = await runTool(db, "viewer1", "write", "update_band_song", {
      bandId: "b", id: "linked1", song: { ourKey: "Am" },
    });
    assert.equal(denied.status, 403);
    const missing = await runTool(db, "admin1", "write", "update_band_song", {
      bandId: "b", id: "ghost", song: { ourKey: "Am" },
    });
    assert.equal(missing.error, "not_found");
    assert.equal(writes.length, 0);
  });

  it("update_band_song writes flat fields on a legacy (non-linked) song", async () => {
    const { db, writes } = fakeDb(BAND, [{ id: "old1", title: "Venus", artist: "Shocking Blue" }]);
    const out = await runTool(db, "editor1", "write", "update_band_song", {
      bandId: "b", id: "old1", song: { ourKey: "Em" },
    });
    assert.equal(out.error, undefined);
    const w = writes.find((x) => x.sub === "songs");
    assert.equal(w.v.ourKey, "Em");
    assert.equal(w.v.materialized, undefined);
  });

  it("create_setlist_with_songs dedups against linked songs instead of duplicating", async () => {
    const { db, writes } = fakeDb(BAND, [LINKED_SONG]);
    const out = await runTool(db, "admin1", "write", "create_setlist_with_songs", {
      bandId: "b",
      name: "ДР",
      entries: [{ type: "song", title: "День рождения", artist: "Ленинград", ourKey: "Am" }],
    });
    assert.equal(out.result.songsCreated, 0);
    assert.equal(out.result.songsUpdated, 1);
    assert.deepEqual(writes.find((w) => w.sub === "setlists").v.songIds, ["linked1"]);
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

// Omitting bandId targets users/{uid}/{songs,setlists}. The app's personal
// setlist stream filters on bandId.isEmpty, so bandId MUST be written as "".
describe("personal scope (no bandId)", () => {
  it("create_setlist_with_songs writes personal songs + a setlist with bandId ''", async () => {
    // "stranger" is a non-member of BAND — personal scope must not consult it.
    const { db, writes } = fakeDb(BAND);
    const out = await runTool(db, "stranger", "write", "create_setlist_with_songs", {
      name: "100% No Modern Talking",
      entries: [
        { type: "song", title: "Internet Friends", artist: "Knife Party", ourKey: "F" },
        { type: "song", title: "Fire Hive", artist: "Knife Party" },
      ],
    });
    assert.equal(out.error, undefined);
    assert.equal(out.result.songsCreated, 2);
    assert.equal(writes.filter((w) => w.sub === "songs").length, 2);
    const setlist = writes.find((w) => w.sub === "setlists").v;
    assert.equal(setlist.bandId, "");
    assert.equal(setlist.songIds.length, 2);
  });

  it("create_setlist writes bandId '' and validates ids against the personal bank", async () => {
    const { db, writes } = fakeDb(BAND, [{ id: "p1", title: "Wrecking Ball", artist: "Miley Cyrus" }]);
    const out = await runTool(db, "stranger", "write", "create_setlist", {
      name: "My list",
      songIds: ["p1", "ghost"],
    });
    assert.equal(out.result.songCount, 1);
    assert.deepEqual(out.result.ignoredSongIds, ["ghost"]);
    const setlist = writes.find((w) => w.sub === "setlists").v;
    assert.equal(setlist.bandId, "");
    assert.deepEqual(setlist.songIds, ["p1"]);
  });
});

// Regression: a client sent bandId:"personal" (a placeholder, not a real id)
// and got "not a member of this band" instead of a personal setlist.
describe("bandId placeholders mean personal", () => {
  for (const placeholder of ["personal", "Personal", " personal ", "me", "none", ""]) {
    it(`treats bandId ${JSON.stringify(placeholder)} as the personal library`, async () => {
      const { db, writes } = fakeDb(BAND);
      const out = await runTool(db, "stranger", "write", "create_setlist_with_songs", {
        bandId: placeholder,
        name: "My list",
        entries: [{ type: "song", title: "Fire Hive", artist: "Knife Party" }],
      });
      assert.equal(out.error, undefined);
      assert.equal(writes.find((w) => w.sub === "setlists").v.bandId, "");
    });
  }

  it("still rejects a real-looking band id the user is not in", async () => {
    const { db } = fakeDb(BAND);
    const out = await runTool(db, "stranger", "write", "create_setlist", {
      bandId: "31384e08-b57f-40e4-81e4-e8b7cb024b82",
      name: "My list",
    });
    assert.equal(out.status, 403);
  });
});

describe("personal alias tools", () => {
  it("create_personal_setlist uses existing personal song ids", async () => {
    const { db, writes } = fakeDb(BAND, [
      { id: "p1", title: "Internet Friends", artist: "Knife Party" },
      { id: "p2", title: "Fire Hive", artist: "Knife Party" },
    ]);
    const out = await runTool(db, "u1", "write", "create_personal_setlist", {
      name: "100% No Modern Talking",
      songIds: ["p1", "p2"],
    });
    assert.equal(out.result.songCount, 2);
    const setlist = writes.find((w) => w.sub === "setlists").v;
    assert.equal(setlist.bandId, "");
    assert.deepEqual(setlist.songIds, ["p1", "p2"]);
    // songIds path must NOT re-create the songs.
    assert.equal(writes.filter((w) => w.sub === "songs").length, 0);
  });

  it("create_personal_setlist creates songs when given entries", async () => {
    const { db, writes } = fakeDb(BAND);
    const out = await runTool(db, "u1", "write", "create_personal_setlist", {
      name: "EP",
      entries: [{ type: "song", title: "Tourniquet", artist: "Knife Party" }],
    });
    assert.equal(out.result.songsCreated, 1);
    assert.equal(writes.find((w) => w.sub === "setlists").v.bandId, "");
  });

  it("add_personal_song_to_setlist appends and keeps the existing items", async () => {
    const { db, writes } = fakeDb(
      BAND,
      [{ id: "p1", title: "Fire Hive", artist: "Knife Party" }],
      [{ id: "sl1", songIds: ["old"], items: [{ id: "i0", songId: "old" }] }],
    );
    const out = await runTool(db, "u1", "write", "add_personal_song_to_setlist", {
      id: "sl1",
      songIds: ["p1", "ghost"],
    });
    assert.equal(out.result.added, 1);
    assert.deepEqual(out.result.ignoredSongIds, ["ghost"]);
    const write = writes.find((w) => w.sub === "setlists").v;
    assert.deepEqual(write.songIds, ["old", "p1"]);
    assert.equal(write.items.length, 2);
  });

  it("add_songs_to_setlist rejects a viewer on a band setlist, with no write", async () => {
    const { db, writes } = fakeDb(BAND, [{ id: "s1", title: "X", artist: "" }], ["sl1"]);
    const out = await runTool(db, "viewer1", "write", "add_songs_to_setlist", {
      bandId: "b",
      id: "sl1",
      songIds: ["s1"],
    });
    assert.equal(out.status, 403);
    assert.equal(writes.length, 0);
  });

  it("list_personal_setlists hides band setlists mis-saved into the personal collection", async () => {
    const { db } = fakeDb(BAND, [], [
      { id: "mine", name: "My list", bandId: "", songIds: ["a"] },
      { id: "strayed", name: "23/07 MAIN COURSE", bandId: "b", songIds: ["x", "y"] },
    ]);
    const out = await runTool(db, "u1", "read", "list_personal_setlists", {});
    assert.deepEqual(out.result.setlists.map((s) => s.name), ["My list"]);
  });

  it("list_personal_setlists ignores any bandId it is handed", async () => {
    const { db } = fakeDb(BAND);
    const out = await runTool(db, "stranger", "read", "list_personal_setlists", {
      bandId: "b",
    });
    assert.equal(out.error, undefined);
    assert.deepEqual(out.result.setlists, []);
  });
});

describe("delete_setlist", () => {
  it("rejects a viewer deleting a band setlist, with no delete", async () => {
    const { db, deletes } = fakeDb(BAND, [], ["sl1"]);
    const out = await runTool(db, "viewer1", "write", "delete_setlist", {
      bandId: "b",
      id: "sl1",
    });
    assert.equal(out.status, 403);
    assert.equal(deletes.length, 0);
  });

  it("deletes a personal setlist", async () => {
    const { db, deletes } = fakeDb(BAND, [], ["sl1"]);
    const out = await runTool(db, "u1", "write", "delete_setlist", { id: "sl1" });
    assert.deepEqual(out.result, { id: "sl1", deleted: true });
    assert.deepEqual(deletes, [{ sub: "setlists", sid: "sl1" }]);
  });

  it("returns not_found for a missing setlist, with no delete", async () => {
    const { db, deletes } = fakeDb(BAND, [], []);
    const out = await runTool(db, "u1", "write", "delete_setlist", { id: "gone" });
    assert.equal(out.error, "not_found");
    assert.equal(deletes.length, 0);
  });

  it("is a write tool — a read-only key cannot call it", async () => {
    const { db, deletes } = fakeDb(BAND, [], ["sl1"]);
    const out = await runTool(db, "u1", "read", "delete_setlist", { id: "sl1" });
    assert.equal(out.status, 403);
    assert.equal(deletes.length, 0);
  });
});
