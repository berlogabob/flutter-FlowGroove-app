/**
 * Remote MCP server (OAuth) — the "magic" connector. Hosted over HTTPS so Claude /
 * ChatGPT can add it as a custom connector with one-click OAuth (no key, no local
 * server). Streamable HTTP transport in stateless mode (serverless-friendly).
 *
 * Auth: the managed OAuth provider (Google login) issues a JWT; this server validates
 * it via JWKS + audience, maps the Google email to a Firebase uid, and runs the shared
 * tools (./tools.js) scoped to that user. No client secret lives here — a resource
 * server only *validates* tokens.
 *
 * Config (functions env — all public, not secrets):
 *   MCP_OAUTH_ISSUER    — the provider's issuer URL (authorization server)
 *   MCP_OAUTH_AUDIENCE  — the token audience = this MCP endpoint's URL
 *   MCP_JWKS_URL        — JWKS URL (defaults to `${issuer}/.well-known/jwks.json`)
 *   MCP_RESOURCE_URL    — this MCP endpoint URL (defaults to MCP_OAUTH_AUDIENCE)
 */
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const express = require("express");
const { createRemoteJWKSet, jwtVerify } = require("jose");
const { z } = require("zod");
const { McpServer } = require("@modelcontextprotocol/sdk/server/mcp.js");
const {
  StreamableHTTPServerTransport,
} = require("@modelcontextprotocol/sdk/server/streamableHttp.js");
const { runTool } = require("./tools");

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

const ISSUER = (process.env.MCP_OAUTH_ISSUER || "").replace(/\/$/, "");
const AUDIENCE = process.env.MCP_OAUTH_AUDIENCE || "";
const RESOURCE_URL = process.env.MCP_RESOURCE_URL || AUDIENCE;
const JWKS = ISSUER
  ? createRemoteJWKSet(
      new URL(process.env.MCP_JWKS_URL || `${ISSUER}/.well-known/jwks.json`),
    )
  : null;
// AuthKit access tokens carry no email claim (only sub), and the resource-scoped
// token isn't valid at the OIDC userinfo endpoint (401) — resolve the email
// server-side via the WorkOS Management API, keyed by the token's `sub`.
const WORKOS_API_KEY = process.env.WORKOS_API_KEY || "";

const PRM_PATH = "/.well-known/oauth-protected-resource";
// PRM is served at the origin root, not under RESOURCE_URL's own path (e.g. "/mcp"),
// so the 401 challenge must point at the origin + PRM_PATH, not RESOURCE_URL + PRM_PATH.
const PRM_URL = RESOURCE_URL
  ? `${new URL(RESOURCE_URL).origin}${PRM_PATH}`
  : PRM_PATH;

function prmDoc() {
  return {
    resource: RESOURCE_URL,
    authorization_servers: ISSUER ? [ISSUER] : [],
    // Must be scopes the auth server can actually issue — advertising custom
    // scopes the AuthKit tenant doesn't know makes clients (ChatGPT) request
    // them and get invalid_scope, killing the OAuth handshake before sign-in.
    // We don't enforce scopes here anyway (every call runs as write); we only
    // need the email claim to map email→uid, plus offline_access for refresh.
    // ponytail: swap to custom scopes only if/when the tenant defines them.
    scopes_supported: ["openid", "email", "offline_access"],
    bearer_methods_supported: ["header"],
  };
}

/** Look up the user's email via the WorkOS Management API by their WorkOS user id (token `sub`). */
async function workosEmail(sub) {
  if (!WORKOS_API_KEY) {
    console.warn("[mcp] WORKOS_API_KEY unset");
    return null;
  }
  if (!sub) return null;
  try {
    const r = await fetch(
      `https://api.workos.com/user_management/users/${encodeURIComponent(sub)}`,
      { headers: { authorization: `Bearer ${WORKOS_API_KEY}` } },
    );
    if (!r.ok) {
      console.warn("[mcp] workos user lookup HTTP", r.status);
      return null;
    }
    const j = await r.json();
    return j.email || null;
  } catch (e) {
    console.warn("[mcp] workos user lookup error", e.message);
    return null;
  }
}

/** Validates the bearer JWT and maps the user's email to a Firebase uid. */
async function resolveUid(req) {
  const header = req.get("authorization") || "";
  const m = /^Bearer\s+(.+)$/.exec(header.trim());
  if (!m || !JWKS) return null;
  try {
    const { payload } = await jwtVerify(m[1], JWKS, {
      issuer: ISSUER || undefined,
      audience: AUDIENCE || undefined,
    });
    // AuthKit access tokens have no email claim; resolve it via WorkOS Management API.
    const email = payload.email || (await workosEmail(payload.sub));
    if (!email) {
      console.warn("[mcp] token ok but no email (token+userinfo)", { sub: payload.sub });
      return null;
    }
    const user = await admin.auth().getUserByEmail(String(email));
    return user.uid;
  } catch (e) {
    // Keep a lean reason — the original silent null made this hard to debug.
    console.warn("[mcp] resolveUid failed", { code: e.code, message: e.message });
    return null;
  }
}

/** A fresh MCP server bound to one user; tools reuse the shared runTool. */
function buildServer(uid) {
  const server = new McpServer({ name: "flowgroove", version: "1.0.0" });
  const song = z.record(z.any());
  const call = (tool) => async (args) => {
    const out = await runTool(db, uid, "write", tool, args || {});
    const payload = out.error ? { error: out.error } : out.result;
    return {
      content: [{ type: "text", text: JSON.stringify(payload) }],
      isError: !!out.error,
    };
  };
  server.tool("list_songs", "List the user's FlowGroove songs.", {}, { readOnlyHint: true }, call("list_songs"));
  server.tool("get_song", "Get one song as FlowGroove Song JSON.", { id: z.string() }, { readOnlyHint: true }, call("get_song"));
  server.tool("export_song", "Export a song as FlowGroove Song JSON.", { id: z.string() }, { readOnlyHint: true }, call("export_song"));
  server.tool("validate_song", "Validate a song against the schema (no write).", { song }, { readOnlyHint: true }, call("validate_song"));
  server.tool("create_song", "Create a personal song from FlowGroove Song JSON.", { song }, { readOnlyHint: false, destructiveHint: false }, call("create_song"));
  server.tool("update_song", "Update a personal song by id.", { id: z.string(), song }, { readOnlyHint: false, destructiveHint: true }, call("update_song"));
  // Band + setlist tools. Bands hold their own song copies and setlists.
  server.tool("list_bands", "List the bands the user belongs to, with the user's role (admin/editor/viewer). Use a band id for the band_song / setlist tools.", {}, { readOnlyHint: true }, call("list_bands"));
  server.tool("list_band_songs", "List songs in a band (member only).", { bandId: z.string() }, { readOnlyHint: true }, call("list_band_songs"));
  server.tool("get_band_song", "Get ONE band song as FlowGroove Song JSON, including its sections/chord charts. Read this before update_band_song.", { bandId: z.string(), id: z.string() }, { readOnlyHint: true }, call("get_band_song"));
  server.tool("update_band_song", "Fill in / update an EXISTING band song (admin/editor only). `id` comes from list_band_songs. `song` is a PARTIAL FlowGroove Song JSON — send only what changes: ourKey (e.g. \"Em\"), ourBPM, notes, tags, links, and sections[] where each part is { name, chordChart } with lyrics+chords in ChordPro (\"[Am]lyric [F]line\"). title/artist/album are owned by the shared canonical song and are ignored here.", { bandId: z.string(), id: z.string(), song }, { readOnlyHint: false, destructiveHint: true }, call("update_band_song"));
  server.tool("create_band_song", "Add ONE song to a band from FlowGroove Song JSON (admin/editor only). Map ALL available data, not just title/artist: key -> originalKey/ourKey (e.g. \"Em\"); a chord progression -> sections[] where each labeled part becomes { name, chordChart } (e.g. {name:\"Verse\", chordChart:\"| Am - G - C |\"}); comments/arrangement/bass notes -> notes. Returns the new band song id.", { bandId: z.string(), song }, { readOnlyHint: false, destructiveHint: false }, call("create_band_song"));
  // SCOPE RULE for every setlist tool: OMIT bandId for the user's PERSONAL
  // setlists — that is the default when they say "my playlist"/"personal"/"for
  // me". Pass bandId ONLY when they name a band. Never guess a band.
  server.tool("list_setlists", "List setlists. Omit bandId for the user's PERSONAL setlists (the default); pass bandId only for a named band (member only).", { bandId: z.string().optional() }, { readOnlyHint: true }, call("list_setlists"));
  server.tool("create_setlist", "Create a setlist from EXISTING song ids. Omit bandId for a PERSONAL setlist (ids from list_songs/create_song); pass bandId for a band setlist (ids from list_band_songs/create_band_song, admin/editor only). Unknown ids are skipped. To import a fresh list of songs, use create_setlist_with_songs instead.", { bandId: z.string().optional(), name: z.string(), songIds: z.array(z.string()).optional(), description: z.string().optional() }, { readOnlyHint: false, destructiveHint: false }, call("create_setlist"));
  server.tool(
    "create_setlist_with_songs",
    "PREFERRED for 'add these songs as songs and a setlist/playlist'. Creates the songs AND the setlist in one call. OMIT bandId to put both in the user's PERSONAL library — do that whenever they say 'my'/'personal' or name no band; pass bandId only for a named band (admin/editor only). `entries` is an ORDERED list; each is either a song { type:\"song\", ...FlowGroove Song JSON } or a break/section divider { type:\"break\", breakType, label }. Map ALL song data: key -> ourKey; chord progression -> sections[] { name, chordChart }; comments/bass -> notes. breakType is one of break_pause | set_change | guest_set | encore | backup | custom; use a divider (e.g. { type:\"break\", breakType:\"guest_set\", label:\"EUSTACE\" }) wherever the source list has a labeled section. Songs are deduped by title+artist.",
    { bandId: z.string().optional(), name: z.string(), description: z.string().optional(), entries: z.array(z.record(z.any())) },
    { readOnlyHint: false, destructiveHint: false },
    call("create_setlist_with_songs"),
  );
  server.tool(
    "add_songs_to_setlist",
    "Append EXISTING songs to an existing setlist. `id` is the setlist id, `songIds` come from list_songs (personal) or list_band_songs (band). Omit bandId for a personal setlist; pass bandId for a band setlist (admin/editor only). Unknown ids are skipped.",
    { id: z.string(), songIds: z.array(z.string()), bandId: z.string().optional() },
    { readOnlyHint: false, destructiveHint: false },
    call("add_songs_to_setlist"),
  );
  server.tool(
    "delete_setlist",
    "Delete a setlist by id. Omit bandId for a personal setlist; pass bandId for a band setlist (admin/editor only). Songs are never deleted. To MOVE a setlist between libraries: create_setlist_with_songs in the new scope, then delete_setlist in the old one.",
    { id: z.string(), bandId: z.string().optional() },
    { readOnlyHint: false, destructiveHint: true },
    call("delete_setlist"),
  );

  // Explicit PERSONAL-scope tools. Same code paths as the tools above with no
  // bandId — they exist because clients kept looking for these names (and
  // sending bandId:"personal") instead of omitting the argument. Use these
  // whenever the user says "my"/"personal" and names no band.
  server.tool(
    "list_personal_setlists",
    "List the user's PERSONAL setlists/playlists (not a band's). No arguments.",
    {},
    { readOnlyHint: true },
    call("list_personal_setlists"),
  );
  server.tool(
    "create_personal_setlist",
    "Create a PERSONAL setlist/playlist in the user's own library — use this whenever they say 'my playlist'/'personal' and name no band. Pass `songIds` for songs already in their personal library (from list_songs), OR `entries` (ordered FlowGroove Song JSON objects, plus optional { type:\"break\", breakType, label } dividers) to create the songs and the setlist in one call. Songs are deduped by title+artist.",
    {
      name: z.string(),
      description: z.string().optional(),
      songIds: z.array(z.string()).optional(),
      entries: z.array(z.record(z.any())).optional(),
    },
    { readOnlyHint: false, destructiveHint: false },
    call("create_personal_setlist"),
  );
  server.tool(
    "add_personal_song_to_setlist",
    "Append songs from the user's PERSONAL library to one of their personal setlists. `id` is the setlist id, `songIds` come from list_songs.",
    { id: z.string(), songIds: z.array(z.string()) },
    { readOnlyHint: false, destructiveHint: false },
    call("add_personal_song_to_setlist"),
  );
  server.tool(
    "delete_personal_setlist",
    "Delete one of the user's PERSONAL setlists by id. Songs are never deleted.",
    { id: z.string() },
    { readOnlyHint: false, destructiveHint: true },
    call("delete_personal_setlist"),
  );
  return server;
}

const app = express();
app.use(express.json({ limit: "200kb" }));

app.get(PRM_PATH, (req, res) => res.json(prmDoc()));

app.post("/mcp", async (req, res) => {
  const uid = await resolveUid(req);
  if (!uid) {
    res.set(
      "WWW-Authenticate",
      `Bearer resource_metadata="${PRM_URL}"`,
    );
    res.status(401).json({ error: "unauthorized" });
    return;
  }
  const server = buildServer(uid);
  const transport = new StreamableHTTPServerTransport({
    sessionIdGenerator: undefined, // stateless
  });
  res.on("close", () => {
    transport.close();
  });
  await server.connect(transport);
  await transport.handleRequest(req, res, req.body);
});

app.get("/mcp", (req, res) =>
  res.status(405).json({ error: "use POST for the MCP endpoint" }),
);

exports.app = app;
exports.mcpRemote = functions.https.onRequest(app);
