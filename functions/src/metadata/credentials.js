// Secret access for the metadata resolver.
//
// This is the first use of Secret Manager in this codebase. Everything else
// reads plain `functions/.env` (see telegram/config.js for the defineString
// pattern, and mcp/remote.js which reads process.env directly) — which means
// WORKOS_API_KEY is currently a live secret sitting in a dotfile that is baked
// into the deployed function's environment. Spotify does not repeat that.
//
// Why a helper rather than calling .value() inline: the resolver has three
// callers with three different runtimes — the lookupTrackMetadata callable, the
// MCP request handlers, and local one-off scripts under scripts/ run with ADC.
// Only the first two are Cloud Functions with secrets bound. `.value()` throws
// (or returns empty) outside that context, so the local path falls back to
// process.env.
//
// Operational setup, once per project:
//   firebase functions:secrets:set SPOTIFY_CLIENT_ID
//   firebase functions:secrets:set SPOTIFY_CLIENT_SECRET
// Then remove both from functions/.env — a bound secret is exposed to the
// function as process.env at runtime, so nothing else has to change.

const fs = require("node:fs");
const path = require("node:path");
const { defineSecret } = require("firebase-functions/params");

const SPOTIFY_CLIENT_ID = defineSecret("SPOTIFY_CLIENT_ID");
const SPOTIFY_CLIENT_SECRET = defineSecret("SPOTIFY_CLIENT_SECRET");

// ponytail: 6-line KEY=VALUE reader instead of a dotenv dependency. The repo
// root .env already holds SPOTIFY_* (the Flutter build reads them from there via
// dart-define), so a script under scripts/ needs no exported vars. Deployed
// functions never reach this — they get the values from Secret Manager.
// Cached because scripts resolve dozens of tracks in a loop.
let rootEnvCache = null;

function rootEnv() {
  if (rootEnvCache) return rootEnvCache;
  rootEnvCache = {};
  try {
    const file = path.join(__dirname, "..", "..", "..", ".env");
    for (const line of fs.readFileSync(file, "utf8").split("\n")) {
      const match = /^\s*([A-Z0-9_]+)\s*=\s*(.*)$/.exec(line);
      if (match) rootEnvCache[match[1]] = match[2].trim().replace(/^["']|["']$/g, "");
    }
  } catch (_) {
    // No root .env (deployed, or a fresh checkout) — expected.
  }
  return rootEnvCache;
}

// Pass to a v2 function's options so the runtime mounts these:
//   onCall({ secrets: spotifySecrets }, handler)
const spotifySecrets = [SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET];

// Cloud Functions / Cloud Run set these. Used to avoid calling .value() outside
// a function runtime, where it logs a WARNING for every access instead of
// throwing — noisy in scripts and tests.
const IN_FUNCTIONS_RUNTIME = Boolean(process.env.K_SERVICE || process.env.FUNCTION_TARGET);

// The repo root .env ships placeholder values ("your_spotify_client_id", etc).
// Without this filter the resolver treats them as configured and burns a token
// request per song on a guaranteed HTTP 400. Mirrors _isPlaceholder in
// lib/config/env_config.dart so both sides agree on what "unset" means.
// Prefix-anchored, not exact-match: the real value in this repo's .env is
// "REPLACE_ME_GET_FROM_SPOTIFY_DASHBOARD", which an exact-match test misses.
const PLACEHOLDER_RE =
  /^(replace_me|your[_-]?|xxx+$|none$)|placeholder|[_-]here$|get[_-]from/i;

function isPlaceholder(value) {
  const v = String(value || "").trim();
  return v.length === 0 || PLACEHOLDER_RE.test(v);
}

function read(param, name) {
  // A bound secret is exposed as process.env at runtime, so this branch covers
  // the deployed path as well as an explicitly exported local var.
  if (!isPlaceholder(process.env[name])) return String(process.env[name]).trim();
  if (IN_FUNCTIONS_RUNTIME) {
    try {
      const value = param.value();
      if (!isPlaceholder(value)) return String(value).trim();
    } catch (_) {
      // Secret not in this function's dependency array.
    }
  }
  const fromFile = rootEnv()[name];
  return isPlaceholder(fromFile) ? "" : String(fromFile).trim();
}

/**
 * @returns {{clientId: string, clientSecret: string}} — both empty when Spotify
 * is not configured. The resolver treats that as "skip Spotify" rather than an
 * error, so an unconfigured environment degrades to MusicBrainz + Deezer +
 * lyrics instead of failing.
 */
function spotifyCredentials() {
  return {
    clientId: read(SPOTIFY_CLIENT_ID, "SPOTIFY_CLIENT_ID"),
    clientSecret: read(SPOTIFY_CLIENT_SECRET, "SPOTIFY_CLIENT_SECRET"),
  };
}

function isSpotifyConfigured() {
  const { clientId, clientSecret } = spotifyCredentials();
  return Boolean(clientId && clientSecret);
}

module.exports = {
  SPOTIFY_CLIENT_ID,
  SPOTIFY_CLIENT_SECRET,
  spotifySecrets,
  spotifyCredentials,
  isSpotifyConfigured,
  isPlaceholder,
};
