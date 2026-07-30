/**
 * The one declaration of FlowGroove's MCP tool surface.
 *
 * Two servers expose these tools — mcp/server.js (local stdio, posts to the
 * gateway over HTTP) and functions/src/mcp/remote.js (remote OAuth, calls
 * runTool in-process). Their declarations used to be copy-pasted, and they had
 * already drifted: the same tool was described differently depending on which
 * transport an agent connected through. update_song said "Update a song by id"
 * in one and "Update a personal song by id" in the other. A tool description IS
 * the API for an LLM caller, so that is a real defect, not cosmetic.
 *
 * HANDLERS DO NOT LIVE HERE. They differ by transport by design; each server
 * supplies its own and iterates this list.
 *
 * NOTE: this module deliberately does NOT require("zod"). mcp/ is a separate
 * npm package with its own zod (^3.23.0) while functions/ has ^3.25.76, so a
 * cross-package require must not drag a second zod instance into the process.
 * Each server passes its own `z` to zodShape().
 */

// Field-type vocabulary. Small on purpose — every current tool fits. Anything
// richer should stay inline in the server that needs it rather than growing a
// half-parser here.
//   string | boolean | string[] | record | record[]      ("record" = free-form object)
//   a trailing "?" marks the field optional
const FIELD_TYPES = ["string", "boolean", "string[]", "record", "record[]"];

/**
 * Convert a manifest schema to a zod shape using the CALLER'S zod instance.
 * @param {Record<string,string>} schema
 * @param {object} z the caller's zod
 */
function zodShape(schema, z) {
  const shape = {};
  for (const [field, raw] of Object.entries(schema || {})) {
    // A field is either "type" / "type?" or { type, describe } when it needs a
    // JSON-Schema description.
    const spec = typeof raw === "string" ? raw : raw.type;
    const describe = typeof raw === "string" ? null : raw.describe;
    const optional = spec.endsWith("?");
    const type = optional ? spec.slice(0, -1) : spec;
    let node;
    switch (type) {
      case "string": node = z.string(); break;
      case "boolean": node = z.boolean(); break;
      case "string[]": node = z.array(z.string()); break;
      case "record": node = z.record(z.any()); break;
      case "record[]": node = z.array(z.record(z.any())); break;
      default:
        throw new Error(
          `unknown field type "${spec}" for "${field}" (known: ${FIELD_TYPES.join(", ")})`,
        );
    }
    if (describe) node = node.describe(describe);
    shape[field] = optional ? node.optional() : node;
  }
  return shape;
}

const TOOLS = [
  {
    name: "list_songs",
    description:
      "List the user's FlowGroove songs.",
    schema: {},
    annotations: { readOnlyHint: true },
  },
  {
    name: "get_song",
    description:
      "Get one song as FlowGroove Song JSON.",
    schema: { id: "string" },
    annotations: { readOnlyHint: true },
  },
  {
    name: "export_song",
    description:
      "Export a song as FlowGroove Song JSON.",
    schema: { id: "string" },
    annotations: { readOnlyHint: true },
  },
  {
    name: "validate_song",
    description:
      "Validate a song against the schema (no write).",
    schema: { song: { type: "record", describe: "A song object in FlowGroove Song JSON (see the schema)." } },
    annotations: { readOnlyHint: true },
  },
  {
    name: "create_song",
    description:
      "Create a personal song from FlowGroove Song JSON.",
    schema: { song: { type: "record", describe: "A song object in FlowGroove Song JSON (see the schema)." } },
    annotations: { readOnlyHint: false, destructiveHint: false },
  },
  {
    name: "update_song",
    description:
      "Update a personal song by id.",
    schema: { id: "string", song: { type: "record", describe: "A song object in FlowGroove Song JSON (see the schema)." } },
    annotations: { readOnlyHint: false, destructiveHint: true },
  },
  {
    name: "lookup_metadata",
    description:
      "Look up everything findable about a track — MusicBrainz recording + work ids and ISWC, Spotify album / release year / ISRC / duration, Deezer BPM, and lyrics split into sections. Writes NOTHING. Returns a per-field `sources` map so you can tell sourced data from a guess. Note: no source provides musical KEY or CHORDS.",
    schema: { title: "string", artist: "string?" },
    annotations: { readOnlyHint: true },
  },
  {
    name: "enrich_song",
    description:
      "Look up a song's metadata and write what belongs on the song. Fill-only by default: values already set are LEFT ALONE unless overwrite:true (Deezer reports double-time BPM for some tracks, so clobbering a hand-set BPM corrupts data). Omit bandId for a personal song. Returns `applied`, `skipped` with reasons, `sources`, and `canonicalFields` — album/releaseYear/ISRC/ISWC for a canonical-linked song, which you apply separately via the updateCanonicalSong callable. Existing sections that already contain chord charts are never touched.",
    schema: { id: "string", bandId: "string?", overwrite: "boolean?", includeLyrics: "boolean?", includeLinks: "boolean?" },
    annotations: { readOnlyHint: false, destructiveHint: false },
  },
  {
    name: "list_bands",
    description:
      "List the bands the user belongs to, with the user's role (admin/editor/viewer). Use a band id for the band_song / setlist tools.",
    schema: {},
    annotations: { readOnlyHint: true },
  },
  {
    name: "list_band_songs",
    description:
      "List songs in a band (member only).",
    schema: { bandId: "string" },
    annotations: { readOnlyHint: true },
  },
  {
    name: "get_band_song",
    description:
      "Get ONE band song as FlowGroove Song JSON, including its sections/chord charts. Read this before update_band_song.",
    schema: { bandId: "string", id: "string" },
    annotations: { readOnlyHint: true },
  },
  {
    name: "update_band_song",
    description:
      "Fill in / update an EXISTING band song (admin/editor only). `id` comes from list_band_songs. `song` is a PARTIAL FlowGroove Song JSON — send only what changes: ourKey (e.g. \"Em\"), ourBPM, notes, tags, links, and sections[] where each part is { name, chordChart } with lyrics+chords in ChordPro (\"[Am]lyric [F]line\"). title/artist/album are owned by the shared canonical song and are ignored here.",
    schema: { bandId: "string", id: "string", song: { type: "record", describe: "A song object in FlowGroove Song JSON (see the schema)." } },
    annotations: { readOnlyHint: false, destructiveHint: true },
  },
  {
    name: "create_band_song",
    description:
      "Add ONE song to a band from FlowGroove Song JSON (admin/editor only). Map ALL available data, not just title/artist: key -> originalKey/ourKey (e.g. \"Em\"); a chord progression -> sections[] where each labeled part becomes { name, chordChart } (e.g. {name:\"Verse\", chordChart:\"| Am - G - C |\"}); comments/arrangement/bass notes -> notes. Returns the new band song id.",
    schema: { bandId: "string", song: { type: "record", describe: "A song object in FlowGroove Song JSON (see the schema)." } },
    annotations: { readOnlyHint: false, destructiveHint: false },
  },
  {
    name: "list_setlists",
    description:
      "List setlists. Omit bandId for the user's PERSONAL setlists (the default); pass bandId only for a named band (member only).",
    schema: { bandId: "string?" },
    annotations: { readOnlyHint: true },
  },
  {
    name: "create_setlist",
    description:
      "Create a setlist from EXISTING song ids. Omit bandId for a PERSONAL setlist (ids from list_songs/create_song); pass bandId for a band setlist (ids from list_band_songs/create_band_song, admin/editor only). Unknown ids are skipped. To import a fresh list of songs, use create_setlist_with_songs instead.",
    schema: { bandId: "string?", name: "string", songIds: "string[]?", description: "string?" },
    annotations: { readOnlyHint: false, destructiveHint: false },
  },
  {
    name: "create_setlist_with_songs",
    description:
      "PREFERRED for 'add these songs as songs and a setlist/playlist'. Creates the songs AND the setlist in one call. OMIT bandId to put both in the user's PERSONAL library — do that whenever they say 'my'/'personal' or name no band; pass bandId only for a named band (admin/editor only). `entries` is an ORDERED list; each is either a song { type:\"song\", ...FlowGroove Song JSON } or a break/section divider { type:\"break\", breakType, label }. Map ALL song data: key -> ourKey; chord progression -> sections[] { name, chordChart }; comments/bass -> notes. breakType is one of break_pause | set_change | guest_set | encore | backup | custom; use a divider (e.g. { type:\"break\", breakType:\"guest_set\", label:\"EUSTACE\" }) wherever the source list has a labeled section. Songs are deduped by title+artist.",
    schema: { bandId: "string?", name: "string", description: "string?", entries: "record[]" },
    annotations: { readOnlyHint: false, destructiveHint: false },
  },
  {
    name: "add_songs_to_setlist",
    description:
      "Append EXISTING songs to an existing setlist. `id` is the setlist id, `songIds` come from list_songs (personal) or list_band_songs (band). Omit bandId for a personal setlist; pass bandId for a band setlist (admin/editor only). Unknown ids are skipped.",
    schema: { id: "string", songIds: "string[]", bandId: "string?" },
    annotations: { readOnlyHint: false, destructiveHint: false },
  },
  {
    name: "delete_setlist",
    description:
      "Delete a setlist by id. Omit bandId for a personal setlist; pass bandId for a band setlist (admin/editor only). Songs are never deleted. To MOVE a setlist between libraries: create_setlist_with_songs in the new scope, then delete_setlist in the old one.",
    schema: { id: "string", bandId: "string?" },
    annotations: { readOnlyHint: false, destructiveHint: true },
  },
  {
    name: "list_personal_setlists",
    description:
      "List the user's PERSONAL setlists/playlists (not a band's). No arguments.",
    schema: {},
    annotations: { readOnlyHint: true },
  },
  {
    name: "create_personal_setlist",
    description:
      "Create a PERSONAL setlist/playlist in the user's own library — use this whenever they say 'my playlist'/'personal' and name no band. Pass `songIds` for songs already in their personal library (from list_songs), OR `entries` (ordered FlowGroove Song JSON objects, plus optional { type:\"break\", breakType, label } dividers) to create the songs and the setlist in one call. Songs are deduped by title+artist.",
    schema: { name: "string", description: "string?", songIds: "string[]?", entries: "record[]?" },
    annotations: { readOnlyHint: false, destructiveHint: false },
  },
  {
    name: "add_personal_song_to_setlist",
    description:
      "Append songs from the user's PERSONAL library to one of their personal setlists. `id` is the setlist id, `songIds` come from list_songs.",
    schema: { id: "string", songIds: "string[]" },
    annotations: { readOnlyHint: false, destructiveHint: false },
  },
  {
    name: "delete_personal_setlist",
    description:
      "Delete one of the user's PERSONAL setlists by id. Songs are never deleted.",
    schema: { id: "string" },
    annotations: { readOnlyHint: false, destructiveHint: true },
  },
];

/** Tool names, in declaration order. */
const TOOL_NAMES = TOOLS.map((t) => t.name);

module.exports = { TOOLS, TOOL_NAMES, zodShape, FIELD_TYPES };
