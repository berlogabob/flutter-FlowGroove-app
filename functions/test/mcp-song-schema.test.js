// FlowGroove Song JSON validator. `links` is documented in SONG_JSON_SCHEMA.md
// but used to be dropped silently on the way to Firestore — these lock the
// pass-through (and the youtubeUrl → links fold) so researched URLs survive.

const assert = require("node:assert/strict");
const { validateSong, normalizeKey } = require("../src/mcp/song_schema");

describe("validateSong links", () => {
  it("keeps links and defaults a missing type to 'other'", () => {
    const { valid, song } = validateSong({
      title: "Internet Friends",
      links: [
        { type: "youtube_original", url: "https://youtu.be/a", title: "Official" },
        { url: "https://tabs.example/x" },
      ],
    });
    assert.equal(valid, true);
    assert.deepEqual(song.links, [
      { type: "youtube_original", url: "https://youtu.be/a", title: "Official" },
      { type: "other", url: "https://tabs.example/x" },
    ]);
  });

  it("folds a bare youtubeUrl into links without warning about it", () => {
    const { valid, warnings, song } = validateSong({
      title: "Wrecking Ball",
      youtubeUrl: "https://youtu.be/b",
    });
    assert.equal(valid, true);
    assert.deepEqual(warnings, []);
    assert.deepEqual(song.links, [{ type: "youtube_original", url: "https://youtu.be/b" }]);
  });

  it("drops url-less entries and does not duplicate an already-listed youtubeUrl", () => {
    const { song } = validateSong({
      title: "X",
      youtubeUrl: "https://youtu.be/c",
      links: [{ type: "youtube_original", url: "https://youtu.be/c" }, { title: "no url" }],
    });
    assert.deepEqual(song.links, [{ type: "youtube_original", url: "https://youtu.be/c" }]);
  });

  it("omits links entirely when there are none", () => {
    const { song } = validateSong({ title: "X" });
    assert.equal("links" in song, false);
  });
});

// Key normalisation. Before this, KEY_RE required an uppercase root, so the
// Flutter form's own output was rejected: SongFormData._buildKey emitted
// lowercase minors ("dm") and this validator called them invalid. Four
// independent key conventions existed in the repo (form, CSV schema, filter
// chips, this file); normalising here converges the write paths on one.
describe("normalizeKey", () => {
  it("uppercases the root and lowercases the minor marker", () => {
    assert.equal(normalizeKey("dm"), "Dm");
    assert.equal(normalizeKey("em"), "Em");
    assert.equal(normalizeKey("c"), "C");
    assert.equal(normalizeKey("ABM"), "Abm");
    assert.equal(normalizeKey("c#M"), "C#m");
    assert.equal(normalizeKey("bb"), "Bb");
  });

  it("leaves already-canonical keys untouched", () => {
    for (const k of ["C", "F#", "Ab", "Am", "C#m", "Abm", "Bbm"]) {
      assert.equal(normalizeKey(k), k);
    }
  });

  it("preserves enharmonic spelling rather than folding it", () => {
    // Ab and G# are the same pitch but not the same notation choice.
    assert.equal(normalizeKey("Ab"), "Ab");
    assert.equal(normalizeKey("G#"), "G#");
  });

  it("trims surrounding whitespace", () => {
    assert.equal(normalizeKey("  Dm  "), "Dm");
  });

  it("returns null for anything that is not a key", () => {
    for (const bad of ["Cmaj7", "H", "C##", "Am7", "C/G", "", "   ", null, undefined, 7, {}]) {
      assert.equal(normalizeKey(bad), null, `expected null for ${JSON.stringify(bad)}`);
    }
  });
});

describe("validateSong key handling", () => {
  it("normalizes and reports what it changed", () => {
    const { valid, warnings, song } = validateSong({
      title: "Wrecking Ball", originalKey: "dm", ourKey: "dm",
    });
    assert.equal(valid, true);
    assert.equal(song.originalKey, "Dm");
    assert.equal(song.ourKey, "Dm");
    assert.equal(warnings.filter((w) => /normalized/.test(w)).length, 2);
  });

  it("keeps an accidental-and-minor key", () => {
    const { song } = validateSong({ title: "Fire Hive", originalKey: "Abm" });
    assert.equal(song.originalKey, "Abm");
  });

  it("drops an unparseable key with a warning instead of failing the song", () => {
    const { valid, errors, warnings, song } = validateSong({
      title: "Imported", originalKey: "Cmaj7", ourBPM: 120,
    });
    // The rest of the song must survive — an AI import sending "Cmaj7" should
    // not lose its BPM and title too.
    assert.equal(valid, true);
    assert.deepEqual(errors, []);
    assert.equal("originalKey" in song, false);
    assert.equal(song.ourBPM, 120);
    assert.match(warnings.join(" | "), /ignored unparseable originalKey "Cmaj7"/);
  });

  it("says nothing when the key was already canonical", () => {
    const { warnings } = validateSong({ title: "X", originalKey: "Am" });
    assert.deepEqual(warnings, []);
  });
});
