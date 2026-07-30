// Resolver tests. Fixture-driven with an injected fetch — no live network, so
// these stay green when MusicBrainz rate-limits or Spotify rotates a secret.
//
// The fixtures are trimmed real payloads. The album/year values are the ones
// measured during planning, which is the point of the heuristic tests: Spotify
// returns "Second Helping" 1974 where MusicBrainz's releases[0] returned a 1997
// compilation, and that regression is what put bootleg albums into prod.

const assert = require("node:assert/strict");
const {
  resolveTrack,
  stripEdition,
  pickSpotifyTrack,
  lyricsToSections,
  artistMatches,
  pickMusicBrainzRecording,
  resetTokenCache,
} = require("../src/metadata/resolver");
const { fetchJson, resetGate } = require("../src/metadata/http");

const noSleep = async () => {};

function jsonRes(body, status = 200) {
  return {
    ok: status >= 200 && status < 300,
    status,
    headers: { get: () => null },
    json: async () => body,
  };
}

// --- fixtures -------------------------------------------------------------

const SPOTIFY_SEARCH = {
  tracks: {
    items: [
      {
        id: "live1",
        name: "Sweet Home Alabama",
        duration_ms: 457000,
        artists: [{ name: "Lynyrd Skynyrd" }],
        album: { name: "Lyve From Steel Town", album_type: "compilation", release_date: "1998-06-01" },
      },
      {
        id: "studio1",
        name: "Sweet Home Alabama",
        duration_ms: 283000,
        artists: [{ name: "Lynyrd Skynyrd" }],
        album: { name: "Second Helping (Expanded Edition)", album_type: "album", release_date: "1974-04-15" },
      },
      {
        id: "reissue1",
        name: "Sweet Home Alabama",
        duration_ms: 283000,
        artists: [{ name: "Lynyrd Skynyrd" }],
        album: { name: "Second Helping", album_type: "album", release_date: "1997-07-29" },
      },
    ],
  },
};

const MB_SEARCH = {
  recordings: [{
    id: "d4e6b911-5ea5-4b7f-be53-08bf7a7f4841",
    title: "Sweet Home Alabama",
    disambiguation: "",
    "artist-credit": [{ artist: { name: "Lynyrd Skynyrd" } }],
  }],
};

const MB_RECORDING = {
  relations: [{
    work: {
      id: "769f4a49-44f5-3588-bf07-c19e01952501",
      title: "Sweet Home Alabama",
      iswcs: ["T-070.076.790-3"],
    },
  }],
};

const LYRICS = "Big wheels keep on turning\nCarry me home\n\nSweet home Alabama\n\nAnother verse here\n\nSweet home Alabama";

function makeFetch(overrides = {}) {
  const calls = [];
  const fetchImpl = async (url) => {
    calls.push(url);
    for (const [fragment, responder] of Object.entries(overrides)) {
      if (url.includes(fragment)) {
        return typeof responder === "function" ? responder(url) : responder;
      }
    }
    if (url.includes("accounts.spotify.com")) {
      return jsonRes({ access_token: "tok", expires_in: 3600 });
    }
    if (url.includes("api.spotify.com/v1/search")) return jsonRes(SPOTIFY_SEARCH);
    if (url.includes("api.spotify.com/v1/tracks/")) {
      return jsonRes({ external_ids: { isrc: "USMC17446153" } });
    }
    if (url.includes("musicbrainz.org/ws/2/recording/?")) return jsonRes(MB_SEARCH);
    if (url.includes("musicbrainz.org/ws/2/recording/")) return jsonRes(MB_RECORDING);
    if (url.includes("api.deezer.com/search")) {
      return jsonRes({ data: [{ id: 24949681, title: "Sweet Home Alabama", artist: { name: "Lynyrd Skynyrd" } }] });
    }
    if (url.includes("api.deezer.com/track/")) return jsonRes({ bpm: 98.4 });
    if (url.includes("api.lyrics.ovh")) return jsonRes({ lyrics: LYRICS });
    return jsonRes({}, 404);
  };
  return { fetchImpl, calls };
}

const resolve = (over = {}, opts = {}) => {
  const { fetchImpl, calls } = makeFetch(over);
  return resolveTrack(
    { title: "Sweet Home Alabama", artist: "Lynyrd Skynyrd" },
    { fetchImpl, sleepImpl: noSleep, spotifyCredentials: { clientId: "a", clientSecret: "b" }, ...opts },
  ).then((result) => ({ result, calls }));
};

beforeEach(() => {
  resetGate();
  resetTokenCache();
});

// --- unit -----------------------------------------------------------------

describe("stripEdition", () => {
  it("strips trailing edition parentheticals", () => {
    assert.equal(stripEdition("Second Helping (Expanded Edition)"), "Second Helping");
    assert.equal(stripEdition("Bangerz (Deluxe Version)"), "Bangerz");
    assert.equal(stripEdition("No Need To Argue (2025 Remaster)"), "No Need To Argue");
    assert.equal(stripEdition("Ride The Lightning (Remastered)"), "Ride The Lightning");
  });

  it("strips stacked suffixes", () => {
    assert.equal(stripEdition("Album (Deluxe Edition) (Remastered)"), "Album");
  });

  it("leaves a leading parenthetical title alone", () => {
    assert.equal(
      stripEdition("(What's the Story) Morning Glory?"),
      "(What's the Story) Morning Glory?",
    );
  });

  it("leaves a non-edition trailing parenthetical alone", () => {
    assert.equal(stripEdition("Sgt. Pepper (Reprise)"), "Sgt. Pepper (Reprise)");
  });

  it("never returns empty", () => {
    assert.equal(stripEdition("(Remastered)"), "(Remastered)");
  });
});

describe("pickSpotifyTrack", () => {
  it("prefers a real album over a compilation, earliest first", () => {
    const picked = pickSpotifyTrack(SPOTIFY_SEARCH.tracks.items, "Lynyrd Skynyrd");
    assert.equal(picked.id, "studio1");
    assert.equal(picked.album.release_date, "1974-04-15");
  });

  it("prefers an album over a single even when the single is older", () => {
    const picked = pickSpotifyTrack([
      { id: "s", artists: [{ name: "Offbeats." }], album: { name: "Timegun", album_type: "single", release_date: "2022-07-09" } },
      { id: "a", artists: [{ name: "Offbeats." }], album: { name: "Scandi", album_type: "album", release_date: "2022-08-13" } },
    ], "Offbeats.");
    assert.equal(picked.id, "a");
  });

  it("rejects a hit by a different artist", () => {
    const picked = pickSpotifyTrack([
      { id: "x", artists: [{ name: "Some Tribute Band" }], album: { name: "Covers", album_type: "album", release_date: "2001" } },
    ], "Lynyrd Skynyrd");
    assert.equal(picked, null);
  });

  it("returns null on empty input", () => {
    assert.equal(pickSpotifyTrack([], "X"), null);
    assert.equal(pickSpotifyTrack(undefined, "X"), null);
  });

  // Ranking by album_type BEFORE date is a deliberate, measured choice. The
  // obvious-looking alternative — earliest release wins — was compared against
  // all 34 real library lookups: the two rules disagreed 6 times and date-first
  // was right only once (Status Quo, where Spotify mislabels the 1979 original as
  // a compilation and the 2003 re-recordings as an album). The five it got wrong
  // are pinned below. Do not switch to date-first to fix Status Quo.
  describe("album_type outranks release date (measured, do not invert)", () => {
    const pick = (items) => pickSpotifyTrack(items, "A");
    const track = (name, type, date) => ({
      id: name, artists: [{ name: "A" }],
      album: { name, album_type: type, release_date: date },
    });

    it("prefers the studio album over an earlier single", () => {
      // Light My Fire: the 1967 single predates the 1967-01-04 album.
      assert.equal(pick([
        track("Light My Fire / Crystal Ship", "single", "1967"),
        track("The Doors", "album", "1967-01-04"),
      ]).album.name, "The Doors");
    });

    it("prefers the album over an acoustic single of the same song", () => {
      // Shape of You: date-first picks the acoustic re-cut. Wrong recording.
      assert.equal(pick([
        track("Shape of You (Acoustic)", "single", "2017-02-10"),
        track("÷", "album", "2017-03-03"),
      ]).album.name, "÷");
    });

    it("does not put a song on an earlier compilation it is not from", () => {
      // Ride the Lightning: date-first lands it on Kill 'Em All (1983).
      assert.equal(pick([
        track("Kill 'Em All", "compilation", "1983-07-24"),
        track("Ride The Lightning", "album", "1984-07-27"),
      ]).album.name, "Ride The Lightning");
    });

    it("prefers the album over a same-year compilation", () => {
      assert.equal(pick([
        track("Back To Black", "compilation", "2006"),
        track("Back To Black", "album", "2006-10-27"),
      ]).album.album_type, "album");
    });

    it("accepts the known cost: a mislabelled original loses to a later album", () => {
      // Status Quo. Spotify types the 1979 original as a compilation and the 2003
      // re-recordings album as an album, so this one resolves imperfectly. Kept
      // deliberately — inverting the rule breaks the four cases above.
      assert.equal(pick([
        track("Whatever You Want", "compilation", "1979"),
        track("Riffs", "album", "2003"),
      ]).album.name, "Riffs");
    });
  });
});

describe("artistMatches", () => {
  it("matches case, punctuation and containment", () => {
    assert.equal(artistMatches("Offbeats.", "offbeats"), true);
    assert.equal(artistMatches("The Eagles", "Eagles"), true);
    assert.equal(artistMatches("Guns N' Roses", "Guns N Roses"), true);
  });

  it("rejects unrelated artists and blanks", () => {
    assert.equal(artistMatches("Metallica", "Miley Cyrus"), false);
    assert.equal(artistMatches("", "Metallica"), false);
  });
});

describe("pickMusicBrainzRecording", () => {
  const rec = (id, score, name = "The Rolling Stones") => ({
    id, score, "artist-credit": [{ artist: { name } }],
  });

  it("prefers the higher score", () => {
    assert.equal(
      pickMusicBrainzRecording([rec("bbb", 80), rec("aaa", 100)], "The Rolling Stones").id,
      "aaa",
    );
  });

  // Equally-scored hits come back in arbitrary order. Two passes over "Jumping
  // Jack Flash" picked different recordings, leaving a song whose MBID matched no
  // canonical and could not be linked. The id tie-break makes runs agree.
  it("is deterministic for equal scores regardless of input order", () => {
    const a = rec("9b35aaa2-6c3b-479c-8be2-c9ec41a04026", 100);
    const b = rec("8b66dd5a-8a6d-422b-8bc4-789d9886fb63", 100);
    const first = pickMusicBrainzRecording([a, b], "The Rolling Stones").id;
    const second = pickMusicBrainzRecording([b, a], "The Rolling Stones").id;
    assert.equal(first, second);
    assert.equal(first, "8b66dd5a-8a6d-422b-8bc4-789d9886fb63");
  });

  it("skips recordings credited to a different artist", () => {
    assert.equal(
      pickMusicBrainzRecording([rec("x", 100, "Cavern Sounds Orchestra")], "The Rolling Stones"),
      null,
    );
  });

  it("ignores entries with no id and handles empty input", () => {
    assert.equal(pickMusicBrainzRecording([{ score: 100 }], "A"), null);
    assert.equal(pickMusicBrainzRecording([], "A"), null);
    assert.equal(pickMusicBrainzRecording(undefined, "A"), null);
  });
});

describe("lyricsToSections", () => {
  it("labels repeated stanzas Chorus and unique ones Verse N", () => {
    const sections = lyricsToSections(LYRICS);
    assert.deepEqual(sections.map((s) => s.name), ["Verse 1", "Chorus", "Verse 2", "Chorus"]);
    assert.equal(sections[0].chart, "Big wheels keep on turning\nCarry me home");
  });

  it("handles CRLF and empty input", () => {
    assert.deepEqual(lyricsToSections("a\r\n\r\nb").map((s) => s.name), ["Verse 1", "Verse 2"]);
    assert.deepEqual(lyricsToSections(""), []);
    assert.deepEqual(lyricsToSections(null), []);
  });
});

// --- http ----------------------------------------------------------------

describe("fetchJson", () => {
  it("retries a 500 then succeeds", async () => {
    let n = 0;
    const body = await fetchJson("https://api.deezer.com/track/1", {
      sleepImpl: noSleep,
      fetchImpl: async () => {
        n += 1;
        return n === 1 ? jsonRes({}, 500) : jsonRes({ bpm: 120 });
      },
    });
    assert.equal(n, 2);
    assert.deepEqual(body, { bpm: 120 });
  });

  it("gives up after the attempt budget and returns null", async () => {
    let n = 0;
    const body = await fetchJson("https://api.deezer.com/track/1", {
      sleepImpl: noSleep,
      attempts: 3,
      fetchImpl: async () => { n += 1; return jsonRes({}, 429); },
    });
    assert.equal(n, 3);
    assert.equal(body, null);
  });

  it("returns null on 404 without retrying", async () => {
    let n = 0;
    const body = await fetchJson("https://api.lyrics.ovh/v1/a/b", {
      sleepImpl: noSleep,
      fetchImpl: async () => { n += 1; return jsonRes({}, 404); },
    });
    assert.equal(n, 1);
    assert.equal(body, null);
  });

  it("returns null when the request throws (timeout/abort)", async () => {
    const body = await fetchJson("https://api.deezer.com/track/1", {
      sleepImpl: noSleep,
      attempts: 2,
      fetchImpl: async () => { throw new Error("The operation was aborted"); },
    });
    assert.equal(body, null);
  });

  it("returns null for a malformed url instead of throwing", async () => {
    assert.equal(await fetchJson("not a url", { sleepImpl: noSleep }), null);
  });
});

// --- resolveTrack --------------------------------------------------------

describe("resolveTrack", () => {
  it("merges every source and records per-field provenance", async () => {
    const { result } = await resolve();

    assert.equal(result.found, true);
    assert.equal(result.album, "Second Helping");
    assert.equal(result.releaseYear, 1974);
    assert.equal(result.isrc, "USMC17446153");
    assert.equal(result.spotifyId, "studio1");
    assert.equal(result.durationMs, 283000);
    assert.equal(result.musicBrainzId, "d4e6b911-5ea5-4b7f-be53-08bf7a7f4841");
    assert.equal(result.musicBrainzWorkId, "769f4a49-44f5-3588-bf07-c19e01952501");
    assert.equal(result.iswc, "T-070.076.790-3");
    assert.equal(result.bpm, 98);
    assert.equal(result.deezerId, "24949681");
    assert.equal(result.sections.length, 4);

    assert.equal(result.sources.album, "spotify");
    assert.equal(result.sources.releaseYear, "spotify");
    assert.equal(result.sources.isrc, "spotify");
    assert.equal(result.sources.musicBrainzId, "musicbrainz");
    assert.equal(result.sources.iswc, "musicbrainz");
    assert.equal(result.sources.bpm, "deezer");
    assert.equal(result.sources.sections, "lyrics.ovh");
  });

  it("never claims a source for key or chords", async () => {
    const { result } = await resolve();
    assert.equal(result.originalKey, null);
    assert.equal("originalKey" in result.sources, false);
    assert.equal("chords" in result.sources, false);
  });

  it("treats Deezer bpm 0 as unknown, not as a real 0", async () => {
    const { result } = await resolve({ "api.deezer.com/track/": jsonRes({ bpm: 0 }) });
    assert.equal(result.bpm, null);
    assert.equal("bpm" in result.sources, false);
    assert.ok(result.missing.includes("bpm"));
  });

  it("still resolves when MusicBrainz has no match", async () => {
    const { result } = await resolve({ "musicbrainz.org": jsonRes({ recordings: [] }) });
    assert.equal(result.found, true);
    assert.equal(result.musicBrainzId, null);
    assert.equal(result.album, "Second Helping");
    assert.ok(result.missing.includes("musicBrainzId"));
    assert.ok(result.missing.includes("iswc"));
  });

  it("still resolves when Spotify is unavailable", async () => {
    const { result } = await resolve({ "spotify.com": jsonRes({}, 503) });
    assert.equal(result.found, true);
    assert.equal(result.musicBrainzId, "d4e6b911-5ea5-4b7f-be53-08bf7a7f4841");
    assert.ok(result.missing.includes("album"));
    assert.ok(result.missing.includes("isrc"));
  });

  it("skips Spotify entirely without credentials", async () => {
    const { result, calls } = await resolve({}, { spotifyCredentials: null });
    assert.equal(calls.some((u) => u.includes("spotify")), false);
    assert.ok(result.missing.includes("album"));
    assert.equal(result.found, true);
  });

  it("honours the skip list", async () => {
    const { calls } = await resolve({}, { skip: ["lyrics", "deezer"] });
    assert.equal(calls.some((u) => u.includes("lyrics.ovh")), false);
    assert.equal(calls.some((u) => u.includes("deezer")), false);
  });

  it("reports found:false for an unknown track without inventing fields", async () => {
    const { fetchImpl } = makeFetch({
      "api.spotify.com/v1/search": jsonRes({ tracks: { items: [] } }),
      "musicbrainz.org": jsonRes({ recordings: [] }),
      "api.deezer.com": jsonRes({ data: [] }),
      "api.lyrics.ovh": jsonRes({}, 404),
    });
    const result = await resolveTrack(
      { title: "Timegun", artist: "Offbeats." },
      { fetchImpl, sleepImpl: noSleep, spotifyCredentials: { clientId: "a", clientSecret: "b" } },
    );
    assert.equal(result.found, false);
    assert.deepEqual(result.sources, {});
    assert.equal(result.album, null);
    assert.equal(result.bpm, null);
  });

  it("requires a title", async () => {
    const result = await resolveTrack({ title: "  ", artist: "X" }, { sleepImpl: noSleep });
    assert.equal(result.found, false);
    assert.match(result.error, /title is required/);
  });

  it("reuses the cached Spotify token across calls", async () => {
    const { fetchImpl, calls } = makeFetch();
    const args = [
      { title: "Sweet Home Alabama", artist: "Lynyrd Skynyrd" },
      { fetchImpl, sleepImpl: noSleep, spotifyCredentials: { clientId: "a", clientSecret: "b" } },
    ];
    await resolveTrack(...args);
    await resolveTrack(...args);
    assert.equal(calls.filter((u) => u.includes("accounts.spotify.com")).length, 1);
  });
});
