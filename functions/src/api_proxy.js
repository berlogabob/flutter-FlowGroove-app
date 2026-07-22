const functions = require("firebase-functions");

// ponytail: CORS-only passthrough for public, no-auth APIs the web build can't
// reach directly (they send no Access-Control-Allow-Origin). Allowlisted hosts
// so this never becomes an open proxy. Add a host here to extend it.
const ALLOWED_HOSTS = new Set(["api.deezer.com", "api.lyrics.ovh"]);

/**
 * Build the proxy handler. `fetchImpl` is injectable for tests.
 */
function makeApiProxy({ fetchImpl } = {}) {
  const fetchFn = fetchImpl || fetch;

  return async function apiProxy(req, res) {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, OPTIONS");

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "GET") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    const target = req.query.url;
    if (!target || typeof target !== "string") {
      res.status(400).json({ error: "Missing url parameter" });
      return;
    }

    let parsed;
    try {
      parsed = new URL(target);
    } catch (_) {
      res.status(400).json({ error: "Invalid url" });
      return;
    }
    if (parsed.protocol !== "https:" || !ALLOWED_HOSTS.has(parsed.host)) {
      res.status(403).json({ error: "Host not allowed" });
      return;
    }

    try {
      const upstream = await fetchFn(parsed.toString());
      const body = await upstream.text();
      res.status(upstream.status);
      res.set("Content-Type", "application/json");
      res.send(body);
    } catch (_) {
      res.status(502).json({ error: "Upstream request failed" });
    }
  };
}

exports.makeApiProxy = makeApiProxy;
exports.apiProxy = functions.https.onRequest(makeApiProxy());
