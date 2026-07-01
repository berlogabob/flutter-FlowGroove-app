/**
 * MCP gateway — a single authenticated HTTPS endpoint the Node MCP server calls.
 * Auth: `Authorization: Bearer fg_...` → SHA-256 → apiKeys/{hash} → { uid, scope }.
 * All writes go through the schema validator and the Admin SDK, scoped to the
 * key's own uid. No canonical writes, no delete. Body: { tool, args }.
 */
const crypto = require("crypto");
const functions = require("firebase-functions");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();
const { validateSong, SCHEMA_VERSION } = require("./song_schema");

const WRITE_TOOLS = new Set(["create_song", "update_song"]);
const MAX_BODY = 100 * 1024; // reject absurd payloads
// ponytail: no real rate limiter — per-key lastUsedAt only. Add a token-bucket
// keyed on the apiKey doc if abuse shows up.

function hashToken(token) {
  return crypto.createHash("sha256").update(token).digest("hex");
}

async function authenticate(req) {
  const header = req.get("authorization") || req.get("Authorization") || "";
  const m = /^Bearer\s+(fg_[A-Za-z0-9_-]+)$/.exec(header.trim());
  if (!m) return null;
  const ref = db.collection("apiKeys").doc(hashToken(m[1]));
  const doc = await ref.get();
  if (!doc.exists) return null;
  return { uid: doc.data().uid, scope: doc.data().scope || "read", ref };
}

function songsCol(uid) {
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

async function listSongs(uid) {
  const snap = await songsCol(uid).limit(200).get();
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

async function getSong(uid, id) {
  if (!id) return { error: "id is required" };
  const doc = await songsCol(uid).doc(id).get();
  if (!doc.exists) return { error: "not_found" };
  return { schemaVersion: SCHEMA_VERSION, song: exportShape(doc.id, doc.data()) };
}

async function exportSong(uid, id) {
  const doc = await songsCol(uid).doc(id).get();
  if (!doc.exists) return { error: "not_found" };
  return { schemaVersion: SCHEMA_VERSION, songs: [exportShape(doc.id, doc.data())] };
}

async function createSong(uid, args) {
  const { valid, errors, warnings, song } = validateSong(args.song || args);
  if (!valid) return { error: "invalid", errors };
  const id = crypto.randomUUID();
  const now = admin.firestore.FieldValue.serverTimestamp();
  await songsCol(uid).doc(id).set({
    ...withSectionIds(song),
    id,
    createdAt: now,
    updatedAt: now,
  });
  return { id, warnings };
}

async function updateSong(uid, args) {
  const id = args.id;
  if (!id) return { error: "id is required" };
  const ref = songsCol(uid).doc(id);
  const doc = await ref.get();
  if (!doc.exists) return { error: "not_found" };
  const { valid, errors, warnings, song } = validateSong(args.song || args);
  if (!valid) return { error: "invalid", errors };
  await ref.set(
    {
      ...withSectionIds(song),
      id,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  return { id, warnings };
}

/** The raw request handler (exported for tests; wrapped by makeGateway). */
async function handle(req, res) {
  {
    try {
      if (req.method !== "POST") {
        res.status(405).json({ error: "POST only" });
        return;
      }
      const raw = JSON.stringify(req.body || {});
      if (raw.length > MAX_BODY) {
        res.status(413).json({ error: "payload too large" });
        return;
      }

      const auth = await authenticate(req);
      if (!auth) {
        res.status(401).json({ error: "invalid or missing API key" });
        return;
      }

      const body = req.body || {};
      const tool = body.tool;
      const args = body.args || {};

      if (WRITE_TOOLS.has(tool) && auth.scope !== "write") {
        res.status(403).json({ error: "this key is read-only" });
        return;
      }

      let result;
      switch (tool) {
        case "list_songs":
          result = await listSongs(auth.uid);
          break;
        case "get_song":
          result = await getSong(auth.uid, args.id);
          break;
        case "validate_song":
          result = validateSong(args.song || {});
          break;
        case "export_song":
          result = await exportSong(auth.uid, args.id);
          break;
        case "create_song":
          result = await createSong(auth.uid, args);
          break;
        case "update_song":
          result = await updateSong(auth.uid, args);
          break;
        default:
          res.status(400).json({ error: `unknown tool "${tool}"` });
          return;
      }

      auth.ref
        .update({ lastUsedAt: admin.firestore.FieldValue.serverTimestamp() })
        .catch(() => {});
      res.status(200).json(result);
    } catch (e) {
      res.status(500).json({ error: "internal", detail: String(e && e.message) });
    }
  }
}

function makeGateway() {
  return functions.https.onRequest(handle);
}

exports.handle = handle;
exports.makeGateway = makeGateway;
exports.mcpGateway = makeGateway();
