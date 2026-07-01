/**
 * Server-side validator for FlowGroove Song JSON (see docs/SONG_JSON_SCHEMA.md).
 * Mirrors the Dart client validator (lib/services/json/song_json_codec.dart) against
 * the same documented schema.
 * ponytail: two small validators, one documented schema. Promote to a shared
 * song.schema.json only if drift bites.
 */
const SCHEMA_VERSION = 1;
const KEY_RE = /^[A-G][#b]?m?$/;
const KNOWN = new Set([
  "id", "title", "artist", "originalKey", "ourKey", "originalBPM", "ourBPM",
  "notes", "tags", "spotifyUrl", "links", "sections",
  "spotifyId", "musicbrainzId", "isrc", "album", "durationMs",
]);

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
    if (typeof v !== "string" || !KEY_RE.test(v)) {
      errors.push(`invalid ${field} "${v}" (expected like C, G#, Am, Bbm)`);
      return null;
    }
    return v;
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
  if (sections.length) song.sections = sections;
  if (str("album")) song.album = raw.album;
  if (str("spotifyId")) song.spotifyId = raw.spotifyId;
  if (str("musicbrainzId")) song.musicbrainzId = raw.musicbrainzId;
  if (str("isrc")) song.isrc = raw.isrc;
  if (Number.isFinite(Number(raw.durationMs))) song.durationMs = Math.round(Number(raw.durationMs));

  return { valid: true, errors, warnings, song };
}

module.exports = { validateSong, SCHEMA_VERSION };
