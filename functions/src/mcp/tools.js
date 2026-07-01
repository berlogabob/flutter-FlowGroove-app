/**
 * Shared MCP tool logic — pure functions of (db, uid, args), reused by both the
 * API-key gateway (src/mcp/gateway.js) and the remote OAuth server (src/mcp/remote.js).
 * All writes go through the schema validator and are scoped to `uid`; sections get
 * ids so the Flutter Section model can parse them. No canonical writes, no delete.
 */
const crypto = require("crypto");
const admin = require("firebase-admin");
const { validateSong, SCHEMA_VERSION } = require("./song_schema");

const WRITE_TOOLS = new Set(["create_song", "update_song"]);

function songsCol(db, uid) {
  return db.collection("users").doc(uid).collection("songs");
}

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
  return {
    songs: snap.docs.map((d) => {
      const x = d.data();
      return {
        id: d.id,
        title: x.title || "",
        artist: x.artist || "",
        ourKey: x.ourKey ?? x.originalKey ?? null,
        ourBPM: x.ourBPM ?? x.originalBPM ?? null,
      };
    }),
  };
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
    default:
      return { error: `unknown tool "${tool}"`, status: 400 };
  }
}

module.exports = {
  listSongs, getSong, exportSong, createSong, updateSong,
  runTool, validateSong, WRITE_TOOLS, SCHEMA_VERSION,
};
