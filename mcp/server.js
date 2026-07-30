#!/usr/bin/env node
/**
 * FlowGroove MCP server. A thin stdio bridge: each tool forwards to the
 * authenticated FlowGroove gateway with your API key. Runs locally — your AI
 * client spawns it. Config via env: FLOWGROOVE_API_KEY, FLOWGROOVE_GATEWAY_URL.
 */
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const API_KEY = process.env.FLOWGROOVE_API_KEY;
const GATEWAY = process.env.FLOWGROOVE_GATEWAY_URL;

if (!API_KEY || !GATEWAY) {
  console.error(
    "FlowGroove MCP: set FLOWGROOVE_API_KEY and FLOWGROOVE_GATEWAY_URL " +
      "(create a key in the app: Profile → AI access (MCP)).",
  );
  process.exit(1);
}

async function call(tool, args) {
  try {
    const res = await fetch(GATEWAY, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${API_KEY}`,
      },
      body: JSON.stringify({ tool, args: args || {} }),
    });
    const body = await res.text();
    return { content: [{ type: "text", text: body }], isError: !res.ok };
  } catch (e) {
    return {
      content: [{ type: "text", text: `Gateway error: ${e.message}` }],
      isError: true,
    };
  }
}

const song = z
  .record(z.any())
  .describe("A song object in FlowGroove Song JSON (see the schema).");

const server = new McpServer({ name: "flowgroove", version: "1.0.0" });

server.tool("list_songs", "List the user's FlowGroove songs.", {}, () =>
  call("list_songs"),
);
server.tool(
  "get_song",
  "Get one song as FlowGroove Song JSON.",
  { id: z.string() },
  ({ id }) => call("get_song", { id }),
);
server.tool(
  "export_song",
  "Export a song as FlowGroove Song JSON.",
  { id: z.string() },
  ({ id }) => call("export_song", { id }),
);
server.tool(
  "validate_song",
  "Validate a song object against the FlowGroove schema (no write).",
  { song },
  ({ song }) => call("validate_song", { song }),
);
server.tool(
  "create_song",
  "Create a song from FlowGroove Song JSON (needs a write-scope key).",
  { song },
  ({ song }) => call("create_song", { song }),
);
server.tool(
  "update_song",
  "Update a song by id with FlowGroove Song JSON (needs a write-scope key).",
  { id: z.string(), song },
  ({ id, song }) => call("update_song", { id, song }),
);
server.tool(
  "lookup_metadata",
  "Look up everything findable about a track — MusicBrainz recording + work ids and ISWC, Spotify album / release year / ISRC / duration, Deezer BPM, and lyrics split into sections. Writes NOTHING. Returns a per-field `sources` map so you can tell sourced data from a guess. Note: no source provides musical KEY or CHORDS.",
  { title: z.string(), artist: z.string().optional() },
  ({ title, artist }) => call("lookup_metadata", { title, artist }),
);
server.tool(
  "enrich_song",
  "Look up a song's metadata and write what belongs on the song (needs a write-scope key). Fill-only by default: values already set are LEFT ALONE unless overwrite:true (Deezer reports double-time BPM for some tracks, so clobbering a hand-set BPM corrupts data). Omit bandId for a personal song. Returns `applied`, `skipped` with reasons, `sources`, and `canonicalFields` — album/releaseYear/ISRC/ISWC for a canonical-linked song, which you apply separately via the updateCanonicalSong callable. Existing sections that already contain chord charts are never touched.",
  {
    id: z.string(),
    bandId: z.string().optional(),
    overwrite: z.boolean().optional(),
    includeLyrics: z.boolean().optional(),
    includeLinks: z.boolean().optional(),
  },
  (args) => call("enrich_song", args),
);

// Band + setlist tools. Same names/shapes as the remote OAuth server
// (functions/src/mcp/remote.js) — both dispatch through the shared runTool.
const bandId = z.string();
// SCOPE RULE for every setlist tool: OMIT bandId for the user's PERSONAL
// setlists (the default when they say "my"/"personal" or name no band).
const optionalBandId = z.string().optional();

server.tool(
  "list_bands",
  "List the bands the user belongs to, with the user's role (admin/editor/viewer). Use a band id for the band_song / setlist tools.",
  {},
  () => call("list_bands"),
);
server.tool(
  "list_band_songs",
  "List songs in a band (member only).",
  { bandId },
  ({ bandId }) => call("list_band_songs", { bandId }),
);
server.tool(
  "get_band_song",
  "Get ONE band song as FlowGroove Song JSON, including its sections/chord charts. Read this before update_band_song.",
  { bandId, id: z.string() },
  ({ bandId, id }) => call("get_band_song", { bandId, id }),
);
server.tool(
  "update_band_song",
  'Fill in / update an EXISTING band song (admin/editor only). `id` comes from list_band_songs. `song` is a PARTIAL FlowGroove Song JSON — send only what changes: ourKey (e.g. "Em"), ourBPM, notes, tags, links, and sections[] where each part is { name, chordChart } with lyrics+chords in ChordPro ("[Am]lyric [F]line"). title/artist/album are owned by the shared canonical song and are ignored here.',
  { bandId, id: z.string(), song },
  ({ bandId, id, song }) => call("update_band_song", { bandId, id, song }),
);
server.tool(
  "create_band_song",
  'Add ONE song to a band from FlowGroove Song JSON (admin/editor only). Map ALL available data, not just title/artist: key -> originalKey/ourKey (e.g. "Em"); a chord progression -> sections[] where each labeled part becomes { name, chordChart }; comments/arrangement/bass notes -> notes. Returns the new band song id.',
  { bandId, song },
  ({ bandId, song }) => call("create_band_song", { bandId, song }),
);
server.tool(
  "list_setlists",
  "List setlists. Omit bandId for the user's PERSONAL setlists (the default); pass bandId only for a named band (member only).",
  { bandId: optionalBandId },
  ({ bandId }) => call("list_setlists", { bandId }),
);
server.tool(
  "create_setlist",
  "Create a setlist from EXISTING song ids. Omit bandId for a PERSONAL setlist (ids from list_songs/create_song); pass bandId for a band setlist (ids from list_band_songs/create_band_song, admin/editor only). Unknown ids are skipped. To import a fresh list of songs, use create_setlist_with_songs instead.",
  {
    bandId: optionalBandId,
    name: z.string(),
    songIds: z.array(z.string()).optional(),
    description: z.string().optional(),
  },
  (args) => call("create_setlist", args),
);
server.tool(
  "create_setlist_with_songs",
  'PREFERRED for "add these songs as songs and a setlist/playlist". Creates the songs AND the setlist in one call. OMIT bandId to put both in the user\'s PERSONAL library — do that whenever they say "my"/"personal" or name no band; pass bandId only for a named band (admin/editor only). `entries` is an ORDERED list; each is either a song { type:"song", ...FlowGroove Song JSON } or a break/section divider { type:"break", breakType, label }. breakType is one of break_pause | set_change | guest_set | encore | backup | custom. Songs are deduped by title+artist.',
  {
    bandId: optionalBandId,
    name: z.string(),
    description: z.string().optional(),
    entries: z.array(z.record(z.any())),
  },
  (args) => call("create_setlist_with_songs", args),
);
server.tool(
  "add_songs_to_setlist",
  "Append EXISTING songs to an existing setlist. `id` is the setlist id, `songIds` come from list_songs (personal) or list_band_songs (band). Omit bandId for a personal setlist; pass bandId for a band setlist (admin/editor only). Unknown ids are skipped.",
  { id: z.string(), songIds: z.array(z.string()), bandId: optionalBandId },
  (args) => call("add_songs_to_setlist", args),
);
server.tool(
  "delete_setlist",
  "Delete a setlist by id. Omit bandId for a personal setlist; pass bandId for a band setlist (admin/editor only). Songs are never deleted. To MOVE a setlist between libraries: create_setlist_with_songs in the new scope, then delete_setlist in the old one.",
  { id: z.string(), bandId: optionalBandId },
  ({ id, bandId }) => call("delete_setlist", { id, bandId }),
);

// Explicit PERSONAL-scope tools — same paths with no bandId. They exist because
// clients hunt for these names instead of omitting the argument.
server.tool(
  "list_personal_setlists",
  "List the user's PERSONAL setlists/playlists (not a band's). No arguments.",
  {},
  () => call("list_personal_setlists"),
);
server.tool(
  "create_personal_setlist",
  'Create a PERSONAL setlist/playlist in the user\'s own library — use this whenever they say "my playlist"/"personal" and name no band. Pass `songIds` for songs already in their personal library (from list_songs), OR `entries` (ordered FlowGroove Song JSON objects, plus optional { type:"break", breakType, label } dividers) to create the songs and the setlist in one call.',
  {
    name: z.string(),
    description: z.string().optional(),
    songIds: z.array(z.string()).optional(),
    entries: z.array(z.record(z.any())).optional(),
  },
  (args) => call("create_personal_setlist", args),
);
server.tool(
  "add_personal_song_to_setlist",
  "Append songs from the user's PERSONAL library to one of their personal setlists. `id` is the setlist id, `songIds` come from list_songs.",
  { id: z.string(), songIds: z.array(z.string()) },
  (args) => call("add_personal_song_to_setlist", args),
);
server.tool(
  "delete_personal_setlist",
  "Delete one of the user's PERSONAL setlists by id. Songs are never deleted.",
  { id: z.string() },
  ({ id }) => call("delete_personal_setlist", { id }),
);

await server.connect(new StdioServerTransport());
