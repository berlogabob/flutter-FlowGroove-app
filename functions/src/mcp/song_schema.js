/**
 * Server-side validator for FlowGroove Song JSON (see SONG_JSON_SCHEMA.md at repo root).
 * Mirrors the Dart client validator (lib/services/json/song_json_codec.dart) against
 * the same documented schema.
 * ponytail: two small validators, one documented schema. Promote to a shared
 * song.schema.json only if drift bites.
 */
const SCHEMA_VERSION = 1;
// Case-insensitive on purpose. The old anchored /^[A-G][#b]?m?$/ required an
// uppercase root, which meant the Flutter form's own output was rejected here:
// SongFormData._buildKey used to emit lowercase minors ("dm"), so the app failed
// its own server-side validator. Normalising instead of rejecting also converges
// the four independent key conventions in this repo (form, CSV schema, filter
// chips, this file) on one stored spelling.
const KEY_RE = /^([A-G])([#b]?)(m?)$/i;
const KNOWN = new Set([
  "id", "title", "artist", "originalKey", "ourKey", "originalBPM", "ourBPM",
  "notes", "tags", "spotifyUrl", "links", "youtubeUrl", "sections",
  "spotifyId", "musicbrainzId", "isrc", "album", "durationMs",
]);

/**
 * Canonical spelling for a musical key, or null if it is not one.
 *
 * Uppercase root, lowercase accidental, lowercase minor marker: "dm" -> "Dm",
 * "ABM" -> "Abm", "c#M" -> "C#m". Enharmonics are deliberately preserved — Ab
 * and G# are the same pitch but not the same notation choice, so folding them
 * would overwrite the writer's intent.
 */
function normalizeKey(value) {
  if (typeof value !== "string") return null;
  const match = KEY_RE.exec(value.trim());
  if (!match) return null;
  const root = match[1].toUpperCase();
  const accidental = match[2] === "" ? "" : (match[2] === "#" ? "#" : "b");
  const minor = match[3] === "" ? "" : "m";
  return `${root}${accidental}${minor}`;
}

/**
 * Validates one raw song object. Returns { valid, errors, warnings, song }.
 * `song` is a normalized, storable subset (no id/timestamps) when valid.
 */
function validateSong(raw) {
  const errors = [];
  const warnings = [];

  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
    return { valid: false, errors: ["song must be an object"], warnings, song: null };
  }

  const title = typeof raw.title === "string" ? raw.title.trim() : "";
  if (!title) errors.push("title is required");

  const key = (field) => {
    const v = raw[field];
    if (v == null) return null;
    const normalized = normalizeKey(v);
    if (normalized === null) {
      // A warning, not an error. An unusable key should not sink an otherwise
      // good song — an AI or ChordPro import that sends "Cmaj7" is better served
      // by storing the rest of the song and saying so.
      warnings.push(`ignored unparseable ${field} "${v}" (expected like C, G#, Am, Bbm)`);
      return null;
    }
    if (normalized !== v) {
      warnings.push(`normalized ${field} "${v}" to "${normalized}"`);
    }
    return normalized;
  };
  const bpm = (field) => {
    const v = raw[field];
    if (v == null) return null;
    const n = typeof v === "number" ? v : Number(v);
    if (!Number.isFinite(n) || n < 40 || n > 300) {
      errors.push(`invalid ${field} "${v}" (expected 40-300)`);
      return null;
    }
    return Math.round(n);
  };

  const originalKey = key("originalKey");
  const ourKey = key("ourKey");
  const originalBPM = bpm("originalBPM");
  const ourBPM = bpm("ourBPM");

  const tags = Array.isArray(raw.tags)
    ? raw.tags.filter((t) => typeof t === "string")
    : [];
  const sections = Array.isArray(raw.sections)
    ? raw.sections
        .filter((s) => s && typeof s === "object")
        .map((s) => ({
          name: typeof s.name === "string" && s.name.trim() ? s.name.trim() : "Section",
          duration: Number.isFinite(Number(s.duration))
            ? Math.max(1, Math.round(Number(s.duration)))
            : 1,
          notes: typeof s.notes === "string" ? s.notes : "",
          ...(typeof s.chordChart === "string" && s.chordChart
            ? { chordChart: s.chordChart }
            : {}),
        }))
    : [];

  // Links per lib/models/link.dart: { type, url, title? }, type defaults "other".
  // A bare `youtubeUrl` (what LLMs volunteer) folds in as a youtube_original link.
  const links = (Array.isArray(raw.links) ? raw.links : [])
    .filter((l) => l && typeof l === "object" && typeof l.url === "string" && l.url.trim())
    .map((l) => ({
      type: typeof l.type === "string" && l.type ? l.type : "other",
      url: l.url.trim(),
      ...(typeof l.title === "string" && l.title ? { title: l.title } : {}),
    }));
  if (typeof raw.youtubeUrl === "string" && raw.youtubeUrl.trim() &&
      !links.some((l) => l.url === raw.youtubeUrl.trim())) {
    links.push({ type: "youtube_original", url: raw.youtubeUrl.trim() });
  }

  const unknown = Object.keys(raw).filter((k) => !KNOWN.has(k));
  if (unknown.length) warnings.push(`ignored unknown field(s): ${unknown.join(", ")}`);

  if (errors.length) return { valid: false, errors, warnings, song: null };

  const str = (f) => (typeof raw[f] === "string" && raw[f] ? raw[f] : undefined);
  const song = {
    title,
    artist: typeof raw.artist === "string" ? raw.artist.trim() : "",
  };
  if (originalKey) song.originalKey = originalKey;
  if (ourKey) song.ourKey = ourKey;
  if (originalBPM != null) song.originalBPM = originalBPM;
  if (ourBPM != null) song.ourBPM = ourBPM;
  if (str("notes")) song.notes = raw.notes;
  if (tags.length) song.tags = tags;
  if (str("spotifyUrl")) song.spotifyUrl = raw.spotifyUrl;
  if (links.length) song.links = links;
  if (sections.length) song.sections = sections;
  if (str("album")) song.album = raw.album;
  if (str("spotifyId")) song.spotifyId = raw.spotifyId;
  if (str("musicbrainzId")) song.musicbrainzId = raw.musicbrainzId;
  if (str("isrc")) song.isrc = raw.isrc;
  if (Number.isFinite(Number(raw.durationMs))) song.durationMs = Math.round(Number(raw.durationMs));

  return { valid: true, errors, warnings, song };
}

module.exports = { validateSong, normalizeKey, SCHEMA_VERSION };
