/**
 * Shared MCP tool logic — pure functions of (db, uid, args), reused by both the
 * API-key gateway (src/mcp/gateway.js) and the remote OAuth server (src/mcp/remote.js).
 * All writes go through the schema validator and are scoped to `uid`; sections get
 * ids so the Flutter Section model can parse them. No canonical writes; the only
 * delete is delete_setlist (songs stay undeletable).
 */
const crypto = require("crypto");
const admin = require("firebase-admin");
const { validateSong, SCHEMA_VERSION } = require("./song_schema");

const WRITE_TOOLS = new Set([
  "create_song", "update_song", "create_band_song", "update_band_song",
  "create_setlist",
  "create_setlist_with_songs", "add_songs_to_setlist", "delete_setlist",
  "create_personal_setlist", "add_personal_song_to_setlist",
  "delete_personal_setlist", "enrich_song",
]);

// Lazily required so the fake-db unit tests never load the resolver (which pulls
// in firebase-functions/params via credentials.js) and never touch the network.
function defaultResolver(db) {
  const { resolveTrack } = require("../metadata/resolver");
  const { spotifyCredentials } = require("../metadata/credentials");
  const { firestoreCache } = require("../metadata/cache");
  const cache = db ? firestoreCache(db) : undefined;
  return (query) => resolveTrack(query, {
    spotifyCredentials: spotifyCredentials(),
    cache,
  });
}

function songsCol(db, uid) {
  return db.collection("users").doc(uid).collection("songs");
}

function bandSongsCol(db, bandId) {
  return db.collection("bands").doc(bandId).collection("songs");
}

function bandSetlistsCol(db, bandId) {
  return db.collection("bands").doc(bandId).collection("setlists");
}

function userSetlistsCol(db, uid) {
  return db.collection("users").doc(uid).collection("setlists");
}

// The setlist tools take an OPTIONAL bandId: with one they act on the band,
// without one on the user's personal library. A personal collection is already
// uid-scoped, so only the band branch needs a permission gate.
const setlistsColFor = (db, uid, bandId) =>
  bandId ? bandSetlistsCol(db, bandId) : userSetlistsCol(db, uid);
const songsColFor = (db, uid, bandId) =>
  bandId ? bandSongsCol(db, bandId) : songsCol(db, uid);

// AI clients send a PLACEHOLDER instead of omitting bandId (observed in the
// wild: bandId:"personal" → the baffling "not a member of this band"). Treat
// those literals as "no band". Anything else is looked up as a real band id.
const PERSONAL_ALIASES = new Set([
  "", "personal", "personal_setlists", "personal_library", "private",
  "me", "my", "mine", "own", "self", "user", "solo",
  "none", "null", "undefined", "n/a", "-",
]);
function normalizeBandId(bandId) {
  if (typeof bandId !== "string") return undefined;
  const trimmed = bandId.trim();
  return PERSONAL_ALIASES.has(trimmed.toLowerCase()) ? undefined : trimmed;
}

// Songs come in two shapes: legacy flat docs, and schemaVersion 2 "linked" docs
// that keep the readable song under `materialized` (canonical + delta is the
// source of truth for the app). Read through this everywhere or v2 songs look
// blank — see lib/models/library_song.dart.
const LINKED_SCHEMA_VERSION = 2;

function isLinked(data) {
  return data.schemaVersion === LINKED_SCHEMA_VERSION &&
    typeof data.canonicalSongId === "string" && data.canonicalSongId !== "";
}

function songFields(data) {
  return isLinked(data) ? (data.materialized || {}) : data;
}

// Compact list item shared by list_songs / list_band_songs.
function songListItem(d) {
  const x = songFields(d.data());
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
  // `links` belongs here: validateSong accepts and preserves it (see
  // mcp-song-schema.test.js), and enrich_song writes a provenance block of
  // MusicBrainz / Spotify / YouTube / chord-search urls. Omitting it from the
  // export made get_song and export_song silently drop links that were stored
  // on the doc — a one-way round trip.
  for (const f of ["originalKey", "ourKey", "originalBPM", "ourBPM", "notes",
    "tags", "spotifyUrl", "links", "album", "spotifyId", "musicbrainzId", "isrc",
    "durationMs"]) {
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

async function getBandSong(db, uid, bandId, id) {
  const role = await getBandRole(db, uid, bandId);
  if (!role) return { error: "not a member of this band", status: 403 };
  if (!id) return { error: "id is required" };
  const doc = await bandSongsCol(db, bandId).doc(id).get();
  if (!doc.exists) return { error: "not_found" };
  return { schemaVersion: SCHEMA_VERSION, song: exportShape(doc.id, songFields(doc.data())) };
}

// Fields a linked song may override on top of its canonical, per
// SongDeltaField.allowed in lib/models/song_delta.dart. Anything else
// (title/artist/album/duration) belongs to the canonical song and cannot be
// changed from here.
const DELTA_FIELDS = ["ourKey", "ourBPM", "notes", "tags", "links", "sections"];

// Owned by the canonical song. On a linked doc these are dropped from the write
// entirely, not merely warned about — an earlier version warned and then merged
// them into `materialized` anyway, which made the warning untrue.
const CANONICAL_OWNED_FIELDS = ["title", "artist", "album", "durationMs"];

/**
 * Apply a partial patch to an existing song doc, personal or band.
 *
 * Shared by update_song and update_band_song so the two can't drift: they did,
 * and the personal one was missing the linked-doc branch entirely, which made
 * every write to a schemaVersion-2 personal song invisible in the app.
 *
 * Two storage shapes. schemaVersion 2 "linked" docs get `delta` + `materialized`
 * merged and a commit appended (mirrors _updateLinkedSong in
 * lib/repositories/firestore_song_repository.dart). Legacy flat docs merge
 * directly. Either way only fields the caller actually sent are written, because
 * validateSong returns a full song shape and merging that would blank anything
 * the patch omitted — notably `artist`, which it defaults to "".
 */
async function applySongUpdate(db, { ref, data, patch, uid, bandId }) {
  const id = ref.id;
  const current = songFields(data);
  // A partial patch is the normal case; title only has to survive validation.
  const { valid, errors, warnings, song } = validateSong({
    ...patch,
    title: patch.title || current.title || "",
  });
  if (!valid) return { error: "invalid", errors };

  const validated = withSectionIds(song);
  const sent = (f) => patch[f] !== undefined ||
    (f === "links" && patch.youtubeUrl !== undefined);
  const clean = Object.fromEntries(
    Object.entries(validated).filter(([f]) => sent(f)),
  );
  const now = admin.firestore.FieldValue.serverTimestamp();

  if (!isLinked(data)) {
    await ref.set({ ...clean, id, updatedAt: now }, { merge: true });
    return { id, warnings };
  }

  const notes = [...warnings];
  for (const f of CANONICAL_OWNED_FIELDS) {
    if (clean[f] === undefined) continue;
    if (clean[f] !== current[f]) {
      notes.push(`${f} is owned by the canonical song and was not changed`);
    }
    delete clean[f];
  }

  const delta = { ...(data.delta || {}) };
  for (const f of DELTA_FIELDS) {
    if (clean[f] !== undefined) delta[f] = clean[f];
  }
  const materialized = { ...current, ...clean, id, updatedAt: now };
  // Only band songs carry a bandId; setting one on a personal song would make it
  // invisible in both lists (the personal query filters bandId != "").
  if (bandId) materialized.bandId = bandId;

  const commitId = ref.collection("commits").doc().id;
  const batch = db.batch();
  batch.set(ref, { delta, materialized, latestCommitId: commitId, updatedAt: now }, { merge: true });
  batch.set(ref.collection("commits").doc(commitId), {
    id: commitId,
    parentCommitId: data.latestCommitId || null,
    canonicalSongId: data.canonicalSongId,
    baseRevision: data.baseRevision || 1,
    delta,
    operation: "update",
    authorId: uid,
    message: bandId ? "Update linked song (MCP)" : "Update linked personal song (MCP)",
    createdAt: now,
    clientMutationId: crypto.randomUUID(),
  });
  await batch.commit();
  return { id, commitId, warnings: notes };
}

/** Update an EXISTING band song (admin/editor). */
async function updateBandSong(db, uid, bandId, args) {
  const role = await getBandRole(db, uid, bandId);
  if (!role) return { error: "not a member of this band", status: 403 };
  if (!canWriteBand(role)) {
    return { error: "need admin or editor role to edit songs", status: 403 };
  }
  const id = args.id || args.songId;
  if (!id) return { error: "id is required (the band song id)" };
  const ref = bandSongsCol(db, bandId).doc(id);
  const doc = await ref.get();
  if (!doc.exists) return { error: "not_found" };

  return applySongUpdate(db, {
    ref, data: doc.data(), patch: args.song || {}, uid, bandId,
  });
}

async function listSetlists(db, uid, bandId) {
  if (bandId) {
    const role = await getBandRole(db, uid, bandId);
    if (!role) return { error: "not a member of this band", status: 403 };
  }
  const snap = await setlistsColFor(db, uid, bandId).limit(100).get();
  // Personal list: hide band setlists mis-saved into users/{uid}/setlists —
  // their song ids point at band copies and read as "Unavailable" here. Matches
  // the app's own filter (FirestoreSetlistRepository.watchSetlists).
  const docs = bandId
    ? snap.docs
    : snap.docs.filter((d) => !(d.data().bandId || ""));
  return {
    setlists: docs.map((d) => {
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
  if (bandId) {
    const role = await getBandRole(db, uid, bandId);
    if (!role) return { error: "not a member of this band", status: 403 };
    if (!canWriteBand(role)) {
      return { error: "need admin or editor role to create setlists", status: 403 };
    }
  }
  const name = (args.name || "").trim();
  if (!name) return { error: "name is required" };
  const requested = Array.isArray(args.songIds) ? args.songIds.filter(Boolean) : [];
  // Only reference songs that actually exist in the target library — never create
  // a setlist full of dangling "Unavailable" rows. Unknown ids are reported back.
  const snap = await songsColFor(db, uid, bandId).get();
  const known = new Set(snap.docs.map((d) => d.id));
  const songIds = requested.filter((s) => known.has(s));
  const unknown = requested.filter((s) => !known.has(s));
  const id = crypto.randomUUID();
  const now = admin.firestore.FieldValue.serverTimestamp();
  // bandId "" (not null) is what the app's personal setlist stream filters on.
  await setlistsColFor(db, uid, bandId).doc(id).set({
    id,
    bandId: bandId || "",
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
      `${unknown.length} song id(s) are not in this ${bandId ? "band" : "user's library"} ` +
      `and were skipped — add them with ${bandId ? "create_band_song" : "create_song"} ` +
      `(or use create_setlist_with_songs).`,
    ];
    out.ignoredSongIds = unknown;
  }
  return out;
}

/**
 * Create songs AND a setlist in ONE call from an ordered list of entries, in the
 * band (bandId) or the user's personal library (no bandId).
 * Each entry is either a song ({ type:"song", ...FlowGroove Song JSON }) or a
 * break/divider ({ type:"break", breakType, label }). Song entries are written
 * to the target library (deduped by title+artist so re-imports don't duplicate);
 * break entries become divider items in the setlist. Prevents the AI from
 * half-chaining create_band_song → create_setlist with invented ids.
 */
async function createSetlistWithSongs(db, uid, bandId, args) {
  if (bandId) {
    const role = await getBandRole(db, uid, bandId);
    if (!role) return { error: "not a member of this band", status: 403 };
    if (!canWriteBand(role)) {
      return { error: "need admin or editor role", status: 403 };
    }
  }
  const name = (args.name || "").trim();
  if (!name) return { error: "name is required" };
  const entries = Array.isArray(args.entries) ? args.entries : [];
  if (!entries.length) return { error: "entries is required" };

  // Existing songs in the target library → dedup key (title|artist, lowercased) → id.
  const targetSongs = songsColFor(db, uid, bandId);
  const existingSnap = await targetSongs.get();
  const byKey = new Map();
  for (const d of existingSnap.docs) {
    const x = songFields(d.data());
    byKey.set(`${(x.title || "").toLowerCase()}|${(x.artist || "").toLowerCase()}`, d.id);
  }

  const batch = db.batch();
  const now = admin.firestore.FieldValue.serverTimestamp();
  const items = [];
  const invalid = [];
  let created = 0;
  let updated = 0;
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
      // Enrich the existing song with the supplied fields (key, chord
      // sections, notes, …) instead of bare-reusing it — a re-import fixes
      // songs that were previously created without their metadata. merge:true
      // preserves createdAt and any fields not in this payload.
      batch.set(
        targetSongs.doc(songId),
        { ...withSectionIds(song), id: songId, updatedAt: now },
        { merge: true },
      );
      updated += 1;
    } else {
      songId = crypto.randomUUID();
      batch.set(targetSongs.doc(songId), {
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
  batch.set(setlistsColFor(db, uid, bandId).doc(setlistId), {
    id: setlistId,
    bandId: bandId || "",
    name,
    description: args.description || null,
    songIds: items.filter((i) => i.songId).map((i) => i.songId),
    items,
    createdAt: now,
    updatedAt: now,
  });
  await batch.commit();

  const out = { id: setlistId, songsCreated: created, songsUpdated: updated, breaks };
  if (invalid.length) out.warnings = [`skipped ${invalid.length} invalid song(s): ${invalid.join(", ")}`];
  return out;
}

/**
 * Append EXISTING songs to an existing setlist (band: admin/editor; personal:
 * no bandId). Ids must already be in the matching library — unknown ones are
 * skipped and reported rather than written as dangling "Unavailable" rows.
 */
async function addSongsToSetlist(db, uid, bandId, args) {
  const id = args.id || args.setlistId;
  if (!id) return { error: "id is required (the setlist id)" };
  if (bandId) {
    const role = await getBandRole(db, uid, bandId);
    if (!role) return { error: "not a member of this band", status: 403 };
    if (!canWriteBand(role)) {
      return { error: "need admin or editor role to edit setlists", status: 403 };
    }
  }
  const requested = (Array.isArray(args.songIds) ? args.songIds : [args.songId])
    .filter((s) => typeof s === "string" && s);
  if (!requested.length) return { error: "songIds is required" };

  const ref = setlistsColFor(db, uid, bandId).doc(id);
  const doc = await ref.get();
  if (!doc.exists) return { error: "not_found" };

  const snap = await songsColFor(db, uid, bandId).get();
  const known = new Set(snap.docs.map((d) => d.id));
  const toAdd = requested.filter((s) => known.has(s));
  const unknown = requested.filter((s) => !known.has(s));

  const cur = doc.data() || {};
  const items = Array.isArray(cur.items) ? cur.items : [];
  const songIds = Array.isArray(cur.songIds) ? cur.songIds : [];
  await ref.set(
    {
      songIds: [...songIds, ...toAdd],
      items: [...items, ...toAdd.map((sid) => ({ id: crypto.randomUUID(), songId: sid }))],
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  const out = { id, added: toAdd.length, songCount: songIds.length + toAdd.length };
  if (unknown.length) {
    out.warnings = [
      `${unknown.length} song id(s) are not in this ${bandId ? "band" : "user's library"} and were skipped.`,
    ];
    out.ignoredSongIds = unknown;
  }
  return out;
}

/**
 * Delete a setlist (band: admin/editor only; personal: no bandId). The only
 * delete in the MCP — songs stay undeletable. "Move a setlist between libraries"
 * = create_setlist_with_songs in the new scope, then delete_setlist in the old.
 */
async function deleteSetlist(db, uid, bandId, id) {
  if (!id) return { error: "id is required" };
  if (bandId) {
    const role = await getBandRole(db, uid, bandId);
    if (!role) return { error: "not a member of this band", status: 403 };
    if (!canWriteBand(role)) {
      return { error: "need admin or editor role to delete setlists", status: 403 };
    }
  }
  const ref = setlistsColFor(db, uid, bandId).doc(id);
  const doc = await ref.get();
  if (!doc.exists) return { error: "not_found" };
  await ref.delete();
  return { id, deleted: true };
}

async function getSong(db, uid, id) {
  if (!id) return { error: "id is required" };
  const doc = await songsCol(db, uid).doc(id).get();
  if (!doc.exists) return { error: "not_found" };
  return { schemaVersion: SCHEMA_VERSION, song: exportShape(doc.id, songFields(doc.data())) };
}

async function exportSong(db, uid, id) {
  const doc = await songsCol(db, uid).doc(id).get();
  if (!doc.exists) return { error: "not_found" };
  return { schemaVersion: SCHEMA_VERSION, songs: [exportShape(doc.id, songFields(doc.data()))] };
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

/** Update an EXISTING personal song. */
async function updateSong(db, uid, args) {
  const id = args.id;
  if (!id) return { error: "id is required" };
  const ref = songsCol(db, uid).doc(id);
  const doc = await ref.get();
  if (!doc.exists) return { error: "not_found" };

  // Accept either { id, song: {...} } or a flat { id, title, ourKey, ... } —
  // several AI clients send the flat form. `id` and `song` are envelope keys, not
  // song fields, so they must not become part of the patch.
  const { id: _envelopeId, song: nested, ...flat } = args;
  const patch = nested || flat;

  return applySongUpdate(db, { ref, data: doc.data(), patch, uid });
}

// Resolver field -> song field. Only these are writable on a SONG; releaseYear,
// musicBrainzWorkId, iswc and genres belong to the canonical song and are
// returned to the caller under `canonicalFields` instead.
const SONG_FIELD_FROM_RESOLVER = {
  musicbrainzId: "musicBrainzId",
  isrc: "isrc",
  album: "album",
  durationMs: "durationMs",
  spotifyId: "spotifyId",
  originalBPM: "bpm",
};
const CANONICAL_ONLY_RESOLVER_FIELDS = [
  "releaseYear", "musicBrainzWorkId", "iswc", "genres",
];

// Sections whose name looks like lyrics already. Mirrors the append-guard in
// scripts/append_canonical_lyrics.js.
const LYRIC_SECTION_LABEL = /^(verse|chorus|bridge|lyrics)\b/i;

function isBlank(value) {
  if (value === null || value === undefined) return true;
  if (typeof value === "string") return value.trim().length === 0;
  if (Array.isArray(value)) return value.length === 0;
  return false;
}

/** Provenance links, mirroring lib/utils/suggestion_links.dart. */
function provenanceLinks(resolved) {
  const q = encodeURIComponent(`${resolved.artist} ${resolved.title}`);
  const links = [];
  if (resolved.musicBrainzId) {
    links.push({
      type: "other",
      title: "MusicBrainz",
      url: `https://musicbrainz.org/recording/${resolved.musicBrainzId}`,
    });
  }
  if (resolved.spotifyId) {
    links.push({
      type: "other",
      title: "Spotify",
      url: `https://open.spotify.com/track/${resolved.spotifyId}`,
    });
  }
  links.push({
    type: "youtube_original",
    title: "YouTube",
    url: `https://www.youtube.com/results?search_query=${q}`,
  });
  links.push({
    type: "chords",
    title: "Chords",
    url: `https://www.ultimate-guitar.com/search.php?search_type=title&value=${q}`,
  });
  return links;
}

/**
 * Look up everything findable about a track, without writing anything.
 *
 * Exists so an agent stops reimplementing MusicBrainz/Spotify/Deezer/lyrics
 * fetching in throwaway scripts — the album heuristic, rate limits and
 * provenance then live in exactly one place for both app and agent.
 */
async function lookupMetadata(args, deps, db) {
  const title = typeof args.title === "string" ? args.title.trim() : "";
  const artist = typeof args.artist === "string" ? args.artist.trim() : "";
  if (!title) return { error: "title is required" };
  const resolve = deps.resolveTrack || defaultResolver(db);
  const resolved = await resolve({ title, artist });
  return { schemaVersion: SCHEMA_VERSION, metadata: resolved };
}

/**
 * Resolve a song's metadata and write what belongs on the song.
 *
 * Fill-only by default: a value already present is left alone unless
 * `overwrite` is set. That is not politeness — Deezer reports double-time BPM
 * for some tracks (196 against a true ~98), so clobbering a BPM a musician set
 * by hand would actively corrupt the library.
 *
 * Linked (schemaVersion 2) songs can only carry the delta fields, so album /
 * duration / ISRC / MBID for those are reported under `canonicalFields` for the
 * caller to apply via updateCanonicalSong rather than written here. MCP still
 * performs no canonical writes.
 */
async function enrichSong(db, uid, args, deps) {
  const bandId = normalizeBandId(args.bandId);
  const id = args.id || args.songId;
  if (!id) return { error: "id is required" };

  if (bandId) {
    const role = await getBandRole(db, uid, bandId);
    if (!role) return { error: "not a member of this band", status: 403 };
    if (!canWriteBand(role)) {
      return { error: "need admin or editor role to edit songs", status: 403 };
    }
  }

  const ref = songsColFor(db, uid, bandId).doc(id);
  const doc = await ref.get();
  if (!doc.exists) return { error: "not_found" };

  const data = doc.data();
  const current = songFields(data);
  const title = current.title || "";
  const artist = current.artist || "";
  if (!title) return { error: "song has no title to look up" };

  const resolve = deps.resolveTrack || defaultResolver(db);
  const resolved = await resolve({ title, artist });
  if (!resolved || !resolved.found) {
    return {
      id,
      found: false,
      applied: [],
      skipped: {},
      canonicalFields: {},
      sources: {},
      warnings: [`no metadata match for "${title}" by "${artist}"`],
    };
  }

  const overwrite = args.overwrite === true;
  const linked = isLinked(data);
  const patch = {};
  const applied = [];
  const skipped = {};
  const warnings = [];

  for (const [songField, resolverField] of Object.entries(SONG_FIELD_FROM_RESOLVER)) {
    const value = resolved[resolverField];
    if (isBlank(value)) continue;
    if (linked && !DELTA_FIELDS.includes(songField)) {
      skipped[songField] = "owned by the canonical song";
      continue;
    }
    if (!isBlank(current[songField]) && !overwrite) {
      skipped[songField] = "already set";
      continue;
    }
    patch[songField] = value;
    applied.push(songField);
  }

  // Links are additive and deduped by url, so re-running never piles them up.
  if (args.includeLinks !== false) {
    const existing = Array.isArray(current.links) ? current.links : [];
    const seen = new Set(existing.map((l) => l && l.url).filter(Boolean));
    const added = provenanceLinks(resolved).filter((l) => !seen.has(l.url));
    if (added.length > 0) {
      patch.links = [...existing, ...added];
      applied.push("links");
    }
  }

  // Append-guard: never touch sections once any of them carries real content.
  // This is what stops a second "Wrecking Ball", where a previous run appended
  // ten placeholder sections after ten real chord charts.
  if (args.includeLyrics !== false && Array.isArray(resolved.sections) &&
      resolved.sections.length > 0) {
    const existing = Array.isArray(current.sections) ? current.sections : [];
    const hasContent = existing.some((s) => s && !isBlank(s.chordChart));
    const hasLyricLabels = existing.some((s) =>
      s && typeof s.name === "string" && LYRIC_SECTION_LABEL.test(s.name));
    if (hasContent) {
      skipped.sections = "existing sections already have chord charts";
    } else if (hasLyricLabels) {
      skipped.sections = "existing sections are already labelled as lyrics";
    } else {
      patch.sections = [
        ...existing,
        ...resolved.sections.map((s) => ({ name: s.name, chordChart: s.chart })),
      ];
      applied.push("sections");
    }
  }

  const canonicalFields = {};
  for (const field of CANONICAL_ONLY_RESOLVER_FIELDS) {
    if (!isBlank(resolved[field])) canonicalFields[field] = resolved[field];
  }
  // On a linked song these were skipped above, so surface them too — the caller
  // needs the whole set to repair the canonical in one updateCanonicalSong call.
  if (linked) {
    for (const [songField, resolverField] of Object.entries(SONG_FIELD_FROM_RESOLVER)) {
      if (skipped[songField] !== "owned by the canonical song") continue;
      const canonicalName = songField === "musicbrainzId"
        ? "musicBrainzId"
        : (songField === "originalBPM" ? "baseBpm" : songField);
      canonicalFields[canonicalName] = resolved[resolverField];
    }
  }

  if (applied.length === 0) {
    return {
      id, found: true, applied: [], skipped, canonicalFields,
      sources: resolved.sources || {}, warnings,
    };
  }

  const out = await applySongUpdate(db, { ref, data, patch, uid, bandId });
  if (out.error) return out;

  return {
    id,
    found: true,
    applied,
    skipped,
    canonicalFields,
    sources: resolved.sources || {},
    commitId: out.commitId,
    warnings: [...warnings, ...(out.warnings || [])],
  };
}

/** Dispatch a tool by name for a resolved uid. Returns { result } or { error, status }. */
async function runTool(db, uid, scope, tool, args, deps = {}) {
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
    case "lookup_metadata":
      return wrap(await lookupMetadata(args, deps, db));
    case "enrich_song":
      return wrap(await enrichSong(db, uid, args, deps));
    case "list_bands":
      return { result: await listBands(db, uid) };
    case "list_band_songs":
      return wrap(await listBandSongs(db, uid, args.bandId));
    case "get_band_song":
      return wrap(await getBandSong(db, uid, args.bandId, args.id));
    case "create_band_song":
      return wrap(await createBandSong(db, uid, args.bandId, args.song || {}));
    case "update_band_song":
      return wrap(await updateBandSong(db, uid, args.bandId, args));
    // Setlist tools: bandId is optional AND placeholder-tolerant (see
    // normalizeBandId) — no bandId means the user's personal library.
    case "list_setlists":
      return wrap(await listSetlists(db, uid, normalizeBandId(args.bandId)));
    case "create_setlist":
      return wrap(await createSetlist(db, uid, normalizeBandId(args.bandId), args));
    case "create_setlist_with_songs":
      return wrap(await createSetlistWithSongs(db, uid, normalizeBandId(args.bandId), args));
    case "add_songs_to_setlist":
      return wrap(await addSongsToSetlist(db, uid, normalizeBandId(args.bandId), args));
    case "delete_setlist":
      return wrap(await deleteSetlist(db, uid, normalizeBandId(args.bandId), args.id));
    // Explicit personal-scope aliases. Redundant with the optional bandId above,
    // but AI clients kept hunting for these exact names (and passing
    // bandId:"personal") instead of omitting the argument. bandId is IGNORED here.
    case "list_personal_setlists":
      return wrap(await listSetlists(db, uid, undefined));
    case "create_personal_setlist":
      // Songs already in the personal bank → songIds; fresh song JSON → entries.
      return wrap(
        Array.isArray(args.entries) && args.entries.length
          ? await createSetlistWithSongs(db, uid, undefined, args)
          : await createSetlist(db, uid, undefined, args),
      );
    case "add_personal_song_to_setlist":
      return wrap(await addSongsToSetlist(db, uid, undefined, args));
    case "delete_personal_setlist":
      return wrap(await deleteSetlist(db, uid, undefined, args.id));
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
  listBands, listBandSongs, getBandSong, createBandSong, updateBandSong,
  listSetlists, createSetlist,
  createSetlistWithSongs, addSongsToSetlist, deleteSetlist, normalizeBandId,
  getBandRole, runTool, validateSong, WRITE_TOOLS, SCHEMA_VERSION,
  lookupMetadata, enrichSong, provenanceLinks,
};
