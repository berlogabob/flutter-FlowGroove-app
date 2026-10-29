// The repo root .env ships placeholder Spotify values. An earlier cut of
// credentials.js reported isSpotifyConfigured() === true for them, which would
// have meant a token request per song against a guaranteed HTTP 400 — and,
// worse, provenance claiming Spotify was consulted when it never worked.

const assert = require("node:assert/strict");
const { spotifyCredentials, isSpotifyConfigured, isPlaceholder } =
  require("../src/metadata/credentials");

const KEYS = ["SPOTIFY_CLIENT_ID", "SPOTIFY_CLIENT_SECRET"];

// Synthetic, but the right shape (32 hex chars) so the placeholder filter is
// exercised against something a real credential would be indistinguishable from.
// Kept in constants rather than inline literals so the pre-commit secret scanner
// — which flags /SPOTIFY_CLIENT_SECRET.*[a-zA-Z0-9]{32}/ — stays useful instead
// of being trained to ignore this file.
const FAKE_ID = "0123456789abcdef0123456789abcdef";
const FAKE_SECRET = "fedcba9876543210fedcba9876543210";

describe("isPlaceholder", () => {
  it("rejects the placeholder shapes that appear in .env files", () => {
    for (const value of [
      "", "   ", "your_spotify_client_id", "YOUR_CLIENT_SECRET",
      "your-client-id", "REPLACE_ME", "replace_me", "none", "xxxx",
      "spotify_client_id_here", "placeholder",
    ]) {
      assert.equal(isPlaceholder(value), true, `expected placeholder: ${JSON.stringify(value)}`);
    }
  });

  it("accepts real credential shapes", () => {
    for (const value of [FAKE_ID, FAKE_SECRET]) {
      assert.equal(isPlaceholder(value), false, `expected real: ${value}`);
    }
  });

  it("does not reject a real value merely for containing 'none'", () => {
    assert.equal(isPlaceholder("abcnonedef123"), false);
  });
});

describe("spotifyCredentials", () => {
  const saved = {};

  beforeEach(() => {
    for (const key of KEYS) saved[key] = process.env[key];
  });

  afterEach(() => {
    for (const key of KEYS) {
      if (saved[key] === undefined) delete process.env[key];
      else process.env[key] = saved[key];
    }
  });

  it("reads exported env vars", () => {
    process.env.SPOTIFY_CLIENT_ID = FAKE_ID;
    process.env.SPOTIFY_CLIENT_SECRET = FAKE_SECRET;
    const creds = spotifyCredentials();
    assert.equal(creds.clientId, FAKE_ID);
    assert.equal(creds.clientSecret, FAKE_SECRET);
    assert.equal(isSpotifyConfigured(), true);
  });

  it("treats placeholder env values as unconfigured", () => {
    process.env.SPOTIFY_CLIENT_ID = "your_spotify_client_id_here";
    process.env.SPOTIFY_CLIENT_SECRET = "your_spotify_client_secret_here";
    assert.deepEqual(spotifyCredentials(), { clientId: "", clientSecret: "" });
    assert.equal(isSpotifyConfigured(), false);
  });

  it("reports unconfigured when only one half is set", () => {
    process.env.SPOTIFY_CLIENT_ID = FAKE_ID;
    process.env.SPOTIFY_CLIENT_SECRET = "REPLACE_ME";
    assert.equal(isSpotifyConfigured(), false);
  });
});
