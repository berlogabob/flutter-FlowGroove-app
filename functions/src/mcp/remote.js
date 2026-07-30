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
const { mcpRemoteSecrets, workosApiKey } = require("../metadata/credentials");
const { McpServer } = require("@modelcontextprotocol/sdk/server/mcp.js");
const {
  StreamableHTTPServerTransport,
} = require("@modelcontextprotocol/sdk/server/streamableHttp.js");
const { runTool } = require("./tools");
const { TOOLS, zodShape } = require("./tool_manifest");

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
// Read lazily, not at module load: a Secret Manager value is only mounted into
// the process environment once the function instance starts, and a module-load
// read would capture "" on some cold-start paths.

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
  const apiKey = workosApiKey();
  if (!apiKey) {
    console.warn("[mcp] WORKOS_API_KEY unset");
    return null;
  }
  if (!sub) return null;
  try {
    const r = await fetch(
      `https://api.workos.com/user_management/users/${encodeURIComponent(sub)}`,
      { headers: { authorization: `Bearer ${apiKey}` } },
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
  const call = (tool) => async (args) => {
    const out = await runTool(db, uid, "write", tool, args || {});
    const payload = out.error ? { error: out.error } : out.result;
    return {
      content: [{ type: "text", text: JSON.stringify(payload) }],
      isError: !!out.error,
    };
  };
  // Declarations come from the shared manifest so this server and the local
  // stdio one cannot describe the same tool differently. Handlers stay here:
  // this one calls runTool in-process, the local one POSTs to the gateway.
  for (const t of TOOLS) {
    server.tool(t.name, t.description, zodShape(t.schema, z), t.annotations, call(t.name));
  }

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
// The lookup_metadata and enrich_song tools reach Spotify through the shared
// resolver, so this function must mount the Spotify secrets. Without them the
// resolver silently skips Spotify and those tools return no album, release year
// or ISRC — a quiet degradation rather than an error.
exports.mcpRemote = functions.https.onRequest({ secrets: mcpRemoteSecrets }, app);
