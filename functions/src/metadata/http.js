// Outbound HTTP for the metadata resolver: timeout, bounded retry, and a
// per-host request gate. Nothing else in functions/ had any of these — every
// other fetch call is bare and unbounded (see the ponytail note in
// mcp/gateway.js), so this is the first such helper.
//
// ponytail: per-host minimum-interval gate, not a token bucket. MusicBrainz's
// 1 req/sec is the only hard limit we actually face and an interval satisfies
// it exactly. Upgrade to a real bucket only if we need burst capacity inside a
// window.

const DEFAULT_TIMEOUT_MS = 10000;
const DEFAULT_ATTEMPTS = 3;

// Minimum ms between requests to the same host. MusicBrainz enforces 1 req/sec
// and starts 503-ing (then blocking the UA) past it; the rest is politeness.
const HOST_MIN_INTERVAL_MS = {
  "musicbrainz.org": 1100,
  "api.lyrics.ovh": 250,
  "api.deezer.com": 120,
  "api.spotify.com": 60,
  "accounts.spotify.com": 60,
};

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Reserved slot per host. Written synchronously before awaiting so two
// concurrent callers can't claim the same slot.
const nextAllowedAt = new Map();

async function gate(host, sleepImpl) {
  const interval = HOST_MIN_INTERVAL_MS[host] || 0;
  if (!interval) return;
  const now = Date.now();
  const slot = Math.max(now, nextAllowedAt.get(host) || 0);
  nextAllowedAt.set(host, slot + interval);
  const wait = slot - now;
  if (wait > 0) await (sleepImpl || sleep)(wait);
}

function retryDelayMs(res, attempt) {
  const header = res && typeof res.headers?.get === "function"
    ? res.headers.get("retry-after")
    : null;
  const seconds = Number(header);
  if (Number.isFinite(seconds) && seconds > 0) return Math.min(seconds * 1000, 30000);
  return Math.min(500 * 2 ** (attempt - 1), 8000);
}

/**
 * GET/POST a URL and parse JSON.
 *
 * Returns null for every failure — a missing recording and a dead upstream are
 * both "no data" to the resolver, which records per-field provenance from what
 * came back rather than from exceptions. Callers never have to try/catch.
 */
async function fetchJson(url, options = {}) {
  const {
    headers,
    method = "GET",
    body,
    timeoutMs = DEFAULT_TIMEOUT_MS,
    attempts = DEFAULT_ATTEMPTS,
    fetchImpl,
    sleepImpl,
    label,
  } = options;
  const fetchFn = fetchImpl || fetch;
  const doSleep = sleepImpl || sleep;

  let host = "";
  try {
    host = new URL(url).host;
  } catch (_) {
    return null;
  }

  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    await gate(host, sleepImpl);
    try {
      const res = await fetchFn(url, {
        method,
        headers,
        body,
        signal: AbortSignal.timeout(timeoutMs),
      });

      if (res.status === 404) return null;
      if (res.status === 429 || res.status >= 500) {
        if (attempt === attempts) {
          console.warn(`[metadata] ${label || host} gave up after ${attempts} attempts (HTTP ${res.status})`);
          return null;
        }
        await doSleep(retryDelayMs(res, attempt));
        continue;
      }
      if (!res.ok) {
        console.warn(`[metadata] ${label || host} HTTP ${res.status}`);
        return null;
      }
      return await res.json();
    } catch (err) {
      if (attempt === attempts) {
        // Node's fetch throws a bare "fetch failed" and hides the real reason in
        // `cause`. Without it a DNS failure, a TLS problem and a connection reset
        // are indistinguishable in the logs — which cost a debugging round trip
        // when MusicBrainz turned out to be unreachable from Cloud Functions.
        const cause = err && err.cause;
        const detail = cause
          ? ` (cause: ${cause.code || cause.errno || ""} ${cause.message || cause})`
          : "";
        console.warn(`[metadata] ${label || host} failed: ${err.message}${detail}`);
        return null;
      }
      await doSleep(retryDelayMs(null, attempt));
    }
  }
  return null;
}

// Test seam: the gate is module state, so suites that assert on timing need a
// clean slate between cases.
function resetGate() {
  nextAllowedAt.clear();
}

module.exports = {
  fetchJson,
  resetGate,
  HOST_MIN_INTERVAL_MS,
  DEFAULT_TIMEOUT_MS,
  DEFAULT_ATTEMPTS,
};
