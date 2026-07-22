/**
 * Shared MCP tool logic — pure functions of (db, uid, args), reused by both the
 * API-key gateway (src/mcp/gateway.js) and the remote OAuth server (src/mcp/remote.js).
 * All writes go through the schema validator and are scoped to `uid`; sections get
 * ids so the Flutter Section model can parse them. No canonical writes, no delete.
 */
const crypto = require("crypto");
const admin = require("firebase-admin");
const { validateSong, SCHEMA_VERSION } = require("./song_schema");

const WRITE_TOOLS = new Set([
  "create_song", "update_song", "create_band_song", "create_setlist",
  "create_setlist_with_songs",
]);

function songsCol(db, uid) {
  return db.collection("users").doc(uid).collection("songs");
}

function bandSongsCol(db, bandId) {
  return db.collection("bands").doc(bandId).collection("songs");
}

function bandSetlistsCol(db, bandId) {
  return db.collection("bands").doc(bandId).collection("setlists");
}

// Compact list item shared by list_songs / list_band_songs.
function songListItem(d) {
  const x = d.data();
  return {
    id: d.id,
    title: x.title || "",
    artist: x.artist || "",
    ourKey: x.ourKey ?? x.originalKey ?? null,
    ourBPM: x.ourBPM ?? x.originalBPM ?? null,
  };
}

/**
 * Resolve the caller's role in a band: "admin" | "editor" | "viewer" | null.
 * SECURITY GATE — the Cloud Function uses the admin SDK and bypasses Firestore
 * rules, so band membership/permission MUST be enforced here.
 */
async function getBandRole(db, uid, bandId) {
  if (!bandId) return null;
  const doc = await db.collection("bands").doc(bandId).get();
  if (!doc.exists) return null;
  const b = doc.data();
  if ((b.adminUids || []).includes(uid)) return "admin";
  if ((b.editorUids || []).includes(uid)) return "editor";
  if ((b.memberUids || []).includes(uid)) return "viewer";
  return null;
}

const canWriteBand = (role) => role === "admin" || role === "editor";

// Clean export subset (FlowGroove Song JSON) from a stored doc.
function exportShape(id, data) {
  const out = { id, title: data.title || "", artist: data.artist || "" };
  for (const f of ["originalKey", "ourKey", "originalBPM", "ourBPM", "notes",
    "tags", "spotifyUrl", "album", "spotifyId", "musicbrainzId", "isrc", "durationMs"]) {
    if (data[f] != null) out[f] = data[f];
  }
  if (Array.isArray(data.sections)) {
    out.sections = data.sections.map((s) => ({
      name: s.name,
      duration: s.duration,
      notes: s.notes || "",
      ...(s.chordChart ? { chordChart: s.chordChart } : {}),
    }));
  }
  return out;
}

// Sections must carry ids for the Flutter Section model to parse them.
function withSectionIds(song) {
  if (!Array.isArray(song.sections)) return song;
  return {
    ...song,
    sections: song.sections.map((s) => ({ id: crypto.randomUUID(), ...s })),
  };
}

async function listSongs(db, uid) {
  const snap = await songsCol(db, uid).limit(200).get();
  return { songs: snap.docs.map(songListItem) };
}

async function listBands(db, uid) {
  const snap = await db
    .collection("bands")
    .where("memberUids", "array-contains", uid)
    .limit(100)
    .get();
  return {
    bands: snap.docs.map((d) => {
      const b = d.data();
      const role = (b.adminUids || []).includes(uid)
        ? "admin"
        : (b.editorUids || []).includes(uid)
          ? "editor"
          : "viewer";
      return { id: d.id, name: b.name || "", role };
    }),
  };
}

async function listBandSongs(db, uid, bandId) {
  const role = await getBandRole(db, uid, bandId);
  if (!role) return { error: "not a member of this band", status: 403 };
  const snap = await bandSongsCol(db, bandId).limit(200).get();
  return { songs: snap.docs.map(songListItem) };
}

async function createBandSong(db, uid, bandId, song) {
  const role = await getBandRole(db, uid, bandId);
  if (!role) return { error: "not a member of this band", status: 403 };
  if (!canWriteBand(role)) {
    return { error: "need admin or editor role to add songs", status: 403 };
  }
  const { valid, errors, warnings, song: clean } = validateSong(song);
  if (!valid) return { error: "invalid", errors };
  const id = crypto.randomUUID();
  const now = admin.firestore.FieldValue.serverTimestamp();
  await bandSongsCol(db, bandId).doc(id).set({
    ...withSectionIds(clean),
    id,
    createdAt: now,
    updatedAt: now,
  });
  return { id, warnings };
}

async function listSetlists(db, uid, bandId) {
  const role = await getBandRole(db, uid, bandId);
  if (!role) return { error: "not a member of this band", status: 403 };
  const snap = await bandSetlistsCol(db, bandId).limit(100).get();
  return {
    setlists: snap.docs.map((d) => {
      const s = d.data();
      return {
        id: d.id,
        name: s.name || "",
        songCount: Array.isArray(s.songIds) ? s.songIds.length : 0,
      };
    }),
  };
}

async function createSetlist(db, uid, bandId, args) {
  const role = await getBandRole(db, uid, bandId);
  if (!role) return { error: "not a member of this band", status: 403 };
  if (!canWriteBand(role)) {
    return { error: "need admin or editor role to create setlists", status: 403 };
  }
  const name = (args.name || "").trim();
  if (!name) return { error: "name is required" };
  const requested = Array.isArray(args.songIds) ? args.songIds.filter(Boolean) : [];
  // Only reference songs that actually exist in this band — never create a
  // setlist full of dangling "Unavailable" rows. Unknown ids are reported back.
  const snap = await bandSongsCol(db, bandId).get();
  const known = new Set(snap.docs.map((d) => d.id));
  const songIds = requested.filter((s) => known.has(s));
  const unknown = requested.filter((s) => !known.has(s));
  const id = crypto.randomUUID();
  const now = admin.firestore.FieldValue.serverTimestamp();
  await bandSetlistsCol(db, bandId).doc(id).set({
    id,
    bandId,
    name,
    description: args.description || null,
    songIds,
    items: songIds.map((sid) => ({ id: crypto.randomUUID(), songId: sid })),
    createdAt: now,
    updatedAt: now,
  });
  const out = { id, songCount: songIds.length };
  if (unknown.length) {
    out.warnings = [
      `${unknown.length} song id(s) are not in this band and were skipped — ` +
      `add them with create_band_song (or use create_setlist_with_songs).`,
    ];
    out.ignoredSongIds = unknown;
  }
  return out;
}

/**
 * Create band songs AND a setlist in ONE call from an ordered list of entries.
 * Each entry is either a song ({ type:"song", ...FlowGroove Song JSON }) or a
 * break/divider ({ type:"break", breakType, label }). Song entries are written
 * to the band library (deduped by title+artist so re-imports don't duplicate);
 * break entries become divider items in the setlist. Prevents the AI from
 * half-chaining create_band_song → create_setlist with invented ids.
 */
async function createSetlistWithSongs(db, uid, bandId, args) {
  const role = await getBandRole(db, uid, bandId);
  if (!role) return { error: "not a member of this band", status: 403 };
  if (!canWriteBand(role)) {
    return { error: "need admin or editor role", status: 403 };
  }
  const name = (args.name || "").trim();
  if (!name) return { error: "name is required" };
  const entries = Array.isArray(args.entries) ? args.entries : [];
  if (!entries.length) return { error: "entries is required" };

  // Existing band songs → dedup key (title|artist, lowercased) → id.
  const existingSnap = await bandSongsCol(db, bandId).get();
  const byKey = new Map();
  for (const d of existingSnap.docs) {
    const x = d.data();
    byKey.set(`${(x.title || "").toLowerCase()}|${(x.artist || "").toLowerCase()}`, d.id);
  }

  const batch = db.batch();
  const now = admin.firestore.FieldValue.serverTimestamp();
  const items = [];
  const invalid = [];
  let created = 0;
  let reused = 0;
  let breaks = 0;

  for (const entry of entries) {
    if (entry && entry.type === "break") {
      items.push({
        id: crypto.randomUUID(),
        type: "break",
        breakType: entry.breakType || "custom",
        breakLabel: entry.label || entry.breakLabel || null,
      });
      breaks += 1;
      continue;
    }
    // Song entry: allow either { type:"song", ...fields } or a bare song object.
    const raw = entry && entry.song ? entry.song : entry;
    const { valid, song } = validateSong(raw || {});
    if (!valid) {
      invalid.push((raw && raw.title) || "(untitled)");
      continue;
    }
    const key = `${(song.title || "").toLowerCase()}|${(song.artist || "").toLowerCase()}`;
    let songId = byKey.get(key);
    if (songId) {
      reused += 1;
    } else {
      songId = crypto.randomUUID();
      batch.set(bandSongsCol(db, bandId).doc(songId), {
        ...withSectionIds(song),
        id: songId,
        createdAt: now,
        updatedAt: now,
      });
      byKey.set(key, songId);
      created += 1;
    }
    items.push({ id: crypto.randomUUID(), songId });
  }

  const setlistId = crypto.randomUUID();
  batch.set(bandSetlistsCol(db, bandId).doc(setlistId), {
    id: setlistId,
    bandId,
    name,
    description: args.description || null,
    songIds: items.filter((i) => i.songId).map((i) => i.songId),
    items,
    createdAt: now,
    updatedAt: now,
  });
  await batch.commit();

  const out = { id: setlistId, songsCreated: created, songsReused: reused, breaks };
  if (invalid.length) out.warnings = [`skipped ${invalid.length} invalid song(s): ${invalid.join(", ")}`];
  return out;
}

async function getSong(db, uid, id) {
  if (!id) return { error: "id is required" };
  const doc = await songsCol(db, uid).doc(id).get();
  if (!doc.exists) return { error: "not_found" };
  return { schemaVersion: SCHEMA_VERSION, song: exportShape(doc.id, doc.data()) };
}

async function exportSong(db, uid, id) {
  const doc = await songsCol(db, uid).doc(id).get();
  if (!doc.exists) return { error: "not_found" };
  return { schemaVersion: SCHEMA_VERSION, songs: [exportShape(doc.id, doc.data())] };
}

async function createSong(db, uid, args) {
  const { valid, errors, warnings, song } = validateSong(args.song || args);
  if (!valid) return { error: "invalid", errors };
  const id = crypto.randomUUID();
  const now = admin.firestore.FieldValue.serverTimestamp();
  await songsCol(db, uid).doc(id).set({
    ...withSectionIds(song),
    id,
    createdAt: now,
    updatedAt: now,
  });
  return { id, warnings };
}

async function updateSong(db, uid, args) {
  const id = args.id;
  if (!id) return { error: "id is required" };
  const ref = songsCol(db, uid).doc(id);
  const doc = await ref.get();
  if (!doc.exists) return { error: "not_found" };
  const { valid, errors, warnings, song } = validateSong(args.song || args);
  if (!valid) return { error: "invalid", errors };
  await ref.set(
    { ...withSectionIds(song), id, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true },
  );
  return { id, warnings };
}

/** Dispatch a tool by name for a resolved uid. Returns { result } or { error, status }. */
async function runTool(db, uid, scope, tool, args) {
  if (WRITE_TOOLS.has(tool) && scope !== "write") {
    return { error: "this key is read-only", status: 403 };
  }
  switch (tool) {
    case "list_songs":
      return { result: await listSongs(db, uid) };
    case "get_song":
      return { result: await getSong(db, uid, args.id) };
    case "validate_song":
      return { result: validateSong(args.song || {}) };
    case "export_song":
      return { result: await exportSong(db, uid, args.id) };
    case "create_song":
      return { result: await createSong(db, uid, args) };
    case "update_song":
      return { result: await updateSong(db, uid, args) };
    case "list_bands":
      return { result: await listBands(db, uid) };
    case "list_band_songs":
      return wrap(await listBandSongs(db, uid, args.bandId));
    case "create_band_song":
      return wrap(await createBandSong(db, uid, args.bandId, args.song || {}));
    case "list_setlists":
      return wrap(await listSetlists(db, uid, args.bandId));
    case "create_setlist":
      return wrap(await createSetlist(db, uid, args.bandId, args));
    case "create_setlist_with_songs":
      return wrap(await createSetlistWithSongs(db, uid, args.bandId, args));
    default:
      return { error: `unknown tool "${tool}"`, status: 400 };
  }
}

// Band/setlist helpers may return their own { error, status }; pass those
// through unchanged, otherwise wrap a success value as { result }.
function wrap(out) {
  if (out && out.error) return { error: out.error, status: out.status || 400 };
  return { result: out };
}

module.exports = {
  listSongs, getSong, exportSong, createSong, updateSong,
  listBands, listBandSongs, createBandSong, listSetlists, createSetlist,
  createSetlistWithSongs,
  getBandRole, runTool, validateSong, WRITE_TOOLS, SCHEMA_VERSION,
};
