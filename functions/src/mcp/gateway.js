/**
 * MCP gateway — a single authenticated HTTPS endpoint the (API-key) MCP server calls.
 * Auth: `Authorization: Bearer fg_...` → SHA-256 → apiKeys/{hash} → { uid, scope }.
 * Tool logic is shared with the remote OAuth server via ./tools.js. Body: { tool, args }.
 */
const crypto = require("crypto");
const functions = require("firebase-functions");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();
const { runTool } = require("./tools");
const { spotifySecrets } = require("../metadata/credentials");

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

/** The raw request handler (exported for tests; wrapped by makeGateway). */
async function handle(req, res) {
  try {
    if (req.method !== "POST") {
      res.status(405).json({ error: "POST only" });
      return;
    }
    if (JSON.stringify(req.body || {}).length > MAX_BODY) {
      res.status(413).json({ error: "payload too large" });
      return;
    }

    const auth = await authenticate(req);
    if (!auth) {
      res.status(401).json({ error: "invalid or missing API key" });
      return;
    }

    const body = req.body || {};
    const out = await runTool(db, auth.uid, auth.scope, body.tool, body.args || {});
    if (out.error) {
      res.status(out.status || 400).json({ error: out.error });
      return;
    }

    auth.ref
      .update({ lastUsedAt: admin.firestore.FieldValue.serverTimestamp() })
      .catch(() => {});
    res.status(200).json(out.result);
  } catch (e) {
    res.status(500).json({ error: "internal", detail: String(e && e.message) });
  }
}

function makeGateway() {
// The lookup_metadata and enrich_song tools reach Spotify through the shared
// resolver, so this function must mount the Spotify secrets. Without them the
// resolver silently skips Spotify and those tools return no album, release year
// or ISRC — a quiet degradation rather than an error.
  return functions.https.onRequest({ secrets: spotifySecrets }, handle);
}

exports.handle = handle;
exports.makeGateway = makeGateway;
exports.mcpGateway = makeGateway();
