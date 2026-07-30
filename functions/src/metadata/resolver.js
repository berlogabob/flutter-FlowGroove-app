// The one place song metadata is fetched. Both the app (via the
// lookupTrackMetadata callable) and agents (via the MCP lookup_metadata tool)
// go through here, so a fix to the album heuristic or a rate limit lands
// everywhere at once.
//
// Source split is evidence-based, not arbitrary — measured on a hard 6-song
// sample from the real library:
//   MusicBrainz  recording MBID, work MBID, ISWC   (work+ISWC 4/4; genres 0/4)
//   Spotify      album, releaseYear, ISRC, duration (album+year+ISRC 6/6)
//   Deezer       BPM                                (5/6; returns 0 = unknown)
//   lyrics.ovh   lyrics -> sections                 (4/6)
// MusicBrainz is deliberately NOT the album source: its search ranks
// compilations equal to studio originals, so `releases[0]` gave "Sweet Home
// Alabama" -> "Fast Cars and Southern Stars" (1997 comp) where Spotify gives
// "Second Helping" (1974). That bug is why several canonical_songs in prod
// point at bootlegs.
//
// Spotify's /audio-features and /recommendations are gone for this app (403 /
// 404 — Development mode, post-Nov-2024 deprecation), so there is no key or
// BPM source there. Key and chords have no API at all; callers supply them
// separately and must label them via `sources`.

const { fetchJson } = require("./http");

const USER_AGENT = "FlowGroove/1.0 ( berloga.bob@gmail.com )";
const MB = "https://musicbrainz.org/ws/2";

// Trailing "(2025 Remaster)" / "(Deluxe Version)" / "(Expanded Edition)" etc.
// Anchored at the end so a leading parenthetical title — "(What's the Story)
// Morning Glory?" — is never touched.
const EDITION_RE = new RegExp(
  "\\s*[([][^)\\]]*\\b(remaster(?:ed)?|deluxe|expanded|edition|version|anniversary" +
  "|reissue|bonus|special|legacy|mono|stereo|explicit|remastered)\\b[^)\\]]*[)\\]]\\s*$",
  "i",
);

const ALBUM_TYPE_RANK = { album: 0, single: 1, compilation: 2 };

function clean(value) {
  return typeof value === "string" ? value.trim() : "";
}

function norm(value) {
  return clean(value)
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s]/gu, "")
    .replace(/\s+/g, " ")
    .trim();
}

/** "Bangerz (Deluxe Version)" -> "Bangerz". Never returns empty. */
function stripEdition(name) {
  let out = clean(name);
  for (let i = 0; i < 3; i += 1) {
    const next = out.replace(EDITION_RE, "").trim();
    if (!next || next === out) break;
    out = next;
  }
  return out || clean(name);
}

/** Drop null/undefined so a later source can't blank an earlier one's value. */
function stripNulls(obj) {
  if (!obj) return {};
  return Object.fromEntries(
    Object.entries(obj).filter(([, v]) => v !== null && v !== undefined),
  );
}

/** Guard against a confident hit for the wrong artist. */
function artistMatches(wanted, got) {
  const a = norm(wanted);
  const b = norm(got);
  if (!a || !b) return false;
  return a === b || a.includes(b) || b.includes(a);
}

// ---------------------------------------------------------------- Spotify

let tokenCache = { value: "", expiresAt: 0 };

async function spotifyToken(creds, opts) {
  const clientId = clean(creds && creds.clientId);
  const clientSecret = clean(creds && creds.clientSecret);
  if (!clientId || !clientSecret) return "";
  if (tokenCache.value && Date.now() < tokenCache.expiresAt) return tokenCache.value;

  const basic = Buffer.from(`${clientId}:${clientSecret}`).toString("base64");
  const body = await fetchJson("https://accounts.spotify.com/api/token", {
    ...opts,
    method: "POST",
    headers: {
      Authorization: `Basic ${basic}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
    label: "spotify/token",
  });
  const token = body && clean(body.access_token);
  if (!token) return "";
  const ttl = Number(body.expires_in) || 3600;
  // Expire a minute early so an in-flight batch never trips over the boundary.
  tokenCache = { value: token, expiresAt: Date.now() + (ttl - 60) * 1000 };
  return token;
}

/**
 * Pick the release a musician would call "the album": a real album over a
 * single over a compilation, and within that the earliest release date.
 */
function pickSpotifyTrack(items, artist) {
  const candidates = (items || []).filter((t) =>
    t && t.album && artistMatches(artist, (t.artists && t.artists[0] && t.artists[0].name) || ""));
  if (candidates.length === 0) return null;
  return candidates.sort((a, b) => {
    const rankA = ALBUM_TYPE_RANK[a.album.album_type] ?? 3;
    const rankB = ALBUM_TYPE_RANK[b.album.album_type] ?? 3;
    if (rankA !== rankB) return rankA - rankB;
    return String(a.album.release_date || "9999").localeCompare(
      String(b.album.release_date || "9999"));
  })[0];
}

async function fromSpotify(title, artist, creds, opts) {
  const token = await spotifyToken(creds, opts);
  if (!token) return null;
  const headers = { Authorization: `Bearer ${token}` };
  const query = encodeURIComponent(`track:${title} artist:${artist}`);
  const search = await fetchJson(
    `https://api.spotify.com/v1/search?q=${query}&type=track&limit=10`,
    { ...opts, headers, label: "spotify/search" },
  );
  const picked = pickSpotifyTrack(search && search.tracks && search.tracks.items, artist);
  if (!picked) return null;

  // ISRC only comes back from the full track object, not from search results.
  const full = await fetchJson(`https://api.spotify.com/v1/tracks/${picked.id}`, {
    ...opts, headers, label: "spotify/track",
  });
  const releaseDate = clean(picked.album.release_date);
  const year = Number(releaseDate.slice(0, 4));
  return {
    spotifyId: picked.id,
    album: stripEdition(picked.album.name),
    releaseYear: Number.isFinite(year) && year > 0 ? year : null,
    durationMs: Number.isFinite(picked.duration_ms) ? picked.duration_ms : null,
    isrc: (full && full.external_ids && clean(full.external_ids.isrc)) || null,
  };
}

// ------------------------------------------------------------ MusicBrainz

async function fromMusicBrainz(title, artist, opts) {
  const headers = { "User-Agent": USER_AGENT, Accept: "application/json" };
  const query = encodeURIComponent(`recording:"${title}" AND artist:"${artist}"`);
  const search = await fetchJson(
    `${MB}/recording/?query=${query}&fmt=json&limit=5`,
    { ...opts, headers, label: "musicbrainz/search" },
  );
  const recordings = (search && search.recordings) || [];
  const hit = recordings.find((r) => {
    const credited = (r["artist-credit"] || [])
      .map((c) => (c.artist && c.artist.name) || "").join(" ");
    return artistMatches(artist, credited);
  });
  if (!hit) return null;

  // The work relation carries composition identity (work MBID + ISWC), which is
  // what lets covers and live versions resolve to one canonical. Genres/tags
  // came back empty 4/4 on the sample, so they are not requested.
  const detail = await fetchJson(
    `${MB}/recording/${hit.id}?inc=work-rels&fmt=json`,
    { ...opts, headers, label: "musicbrainz/recording" },
  );
  const works = ((detail && detail.relations) || [])
    .map((rel) => rel.work)
    .filter(Boolean);
  const work = works[0] || null;
  const iswcs = (work && work.iswcs) || [];
  return {
    musicBrainzId: hit.id,
    musicBrainzWorkId: (work && work.id) || null,
    iswc: clean(iswcs[0]) || null,
    disambiguation: clean(hit.disambiguation) || null,
  };
}

// ----------------------------------------------------------------- Deezer

async function fromDeezer(title, artist, opts) {
  const query = encodeURIComponent(`artist:"${artist}" track:"${title}"`);
  const search = await fetchJson(
    `https://api.deezer.com/search?q=${query}&limit=5`,
    { ...opts, label: "deezer/search" },
  );
  const hit = ((search && search.data) || []).find((t) =>
    t && artistMatches(artist, (t.artist && t.artist.name) || ""));
  if (!hit) return null;

  // Search results never carry BPM; only the full track object does.
  const full = await fetchJson(`https://api.deezer.com/track/${hit.id}`, {
    ...opts, label: "deezer/track",
  });
  const rawBpm = full && Number(full.bpm);
  // Deezer returns 0 for "we don't know" — storing 0 would show a real 0 BPM.
  const bpm = Number.isFinite(rawBpm) && rawBpm > 0 ? Math.round(rawBpm) : null;
  // Measured hazard: Deezer reports double-time for some tracks (Sweet Home
  // Alabama comes back 196 against a true ~98). We deliberately do NOT guess a
  // halving — 140 for Knife Party and 166 for Zombie are genuine. Consumers
  // must therefore treat this as a fill-only-if-blank value and never overwrite
  // a BPM a human already set.
  return { deezerId: String(hit.id), bpm };
}

// ------------------------------------------------------------- lyrics.ovh

/** Mirror of lib/utils/lyrics_sections.dart lyricsToSections(). */
function lyricsToSections(lyrics) {
  const stanzas = String(lyrics || "")
    .replace(/\r\n/g, "\n")
    .split(/\n[ \t]*\n/)
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
  if (stanzas.length === 0) return [];

  const counts = {};
  for (const s of stanzas) counts[s] = (counts[s] || 0) + 1;

  const out = [];
  const chorusLabel = {};
  let verseNo = 0;
  let chorusNo = 0;
  for (const s of stanzas) {
    let name;
    if (counts[s] > 1) {
      if (chorusLabel[s] === undefined) {
        chorusNo += 1;
        chorusLabel[s] = chorusNo === 1 ? "Chorus" : `Chorus ${chorusNo}`;
      }
      name = chorusLabel[s];
    } else {
      verseNo += 1;
      name = `Verse ${verseNo}`;
    }
    out.push({ name, chart: s });
  }
  return out;
}

async function fromLyrics(title, artist, opts) {
  // lyrics.ovh matches many titles only without punctuation (Knockin', R.E.M.),
  // so fall back through progressively looser spellings — same ladder that
  // scripts/append_canonical_lyrics.js proved out.
  const strip = (s) => s.replace(/[^\p{L}\p{N} ]/gu, " ").replace(/\s+/g, " ").trim();
  const attempts = [
    [artist, title],
    [artist.toLowerCase(), title.toLowerCase()],
    [strip(artist), strip(title)],
  ];
  for (const [a, t] of attempts) {
    if (!a || !t) continue;
    const body = await fetchJson(
      `https://api.lyrics.ovh/v1/${encodeURIComponent(a)}/${encodeURIComponent(t)}`,
      { ...opts, timeoutMs: 20000, attempts: 2, label: "lyrics.ovh" },
    );
    const lyrics = body && clean(body.lyrics).replace(/\r\n/g, "\n");
    if (lyrics) return { lyrics, sections: lyricsToSections(lyrics) };
  }
  return null;
}

// --------------------------------------------------------------- resolve

const PROVENANCE_FIELDS = {
  spotify: ["spotifyId", "album", "releaseYear", "durationMs", "isrc"],
  musicbrainz: ["musicBrainzId", "musicBrainzWorkId", "iswc", "disambiguation"],
  deezer: ["deezerId", "bpm"],
  "lyrics.ovh": ["sections"],
};

// Genuinely optional upstream fields — absent for most records even on a
// perfect lookup, so listing them as "missing" would make every result look
// half-resolved.
const OPTIONAL_FIELDS = new Set(["disambiguation"]);

/**
 * Resolve everything findable about one track.
 *
 * Never throws and never partially fails: any unreachable source simply leaves
 * its fields null and absent from `sources`. Returns the merged record plus a
 * per-field provenance map, so a caller can tell a real ISRC from a guess — the
 * durable guard against unlabelled data reaching the library.
 */
async function resolveTrack({ title, artist }, options = {}) {
  const cleanTitle = clean(title);
  const cleanArtist = clean(artist);
  if (!cleanTitle) {
    return { found: false, error: "title is required", sources: {}, missing: [] };
  }

  const { spotifyCredentials, fetchImpl, sleepImpl, skip = [] } = options;
  const opts = { fetchImpl, sleepImpl };
  const want = (name) => !skip.includes(name);

  // Independent upstreams, so fan out. The per-host gate in http.js keeps each
  // one inside its own rate limit regardless of ordering here.
  const [spotify, musicbrainz, deezer, lyrics] = await Promise.all([
    want("spotify") && cleanArtist
      ? fromSpotify(cleanTitle, cleanArtist, spotifyCredentials, opts) : null,
    want("musicbrainz") && cleanArtist
      ? fromMusicBrainz(cleanTitle, cleanArtist, opts) : null,
    want("deezer") && cleanArtist
      ? fromDeezer(cleanTitle, cleanArtist, opts) : null,
    want("lyrics") && cleanArtist
      ? fromLyrics(cleanTitle, cleanArtist, opts) : null,
  ]);

  const allFields = Object.values(PROVENANCE_FIELDS).flat();
  // Every known field is present as null when unresolved. Firestore rejects
  // undefined outright, and a caller shouldn't have to distinguish "absent" from
  // "unknown" to write the result safely.
  const blanks = Object.fromEntries([...allFields, "lyrics"].map((f) => [f, null]));

  const merged = {
    title: cleanTitle,
    artist: cleanArtist,
    ...blanks,
    ...stripNulls(musicbrainz),
    ...stripNulls(spotify),
    ...stripNulls(deezer),
    ...stripNulls(lyrics),
  };

  const present = {
    spotify, musicbrainz, deezer, "lyrics.ovh": lyrics,
  };
  const sources = {};
  for (const [source, fields] of Object.entries(PROVENANCE_FIELDS)) {
    if (!present[source]) continue;
    for (const field of fields) {
      if (merged[field] !== null && merged[field] !== undefined) sources[field] = source;
    }
  }

  const missing = allFields
    .filter((f) => !OPTIONAL_FIELDS.has(f))
    .filter((f) => merged[f] === null || merged[f] === undefined);

  return {
    found: Boolean(spotify || musicbrainz),
    ...merged,
    // Neither key nor chords has any API source. They stay null here on
    // purpose; a caller that fills them must add its own `sources` entry.
    originalKey: null,
    sources,
    missing,
  };
}

module.exports = {
  resolveTrack,
  // exported for tests
  stripEdition,
  pickSpotifyTrack,
  lyricsToSections,
  artistMatches,
  norm,
  resetTokenCache() {
    tokenCache = { value: "", expiresAt: 0 };
  },
};
