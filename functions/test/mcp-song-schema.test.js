// FlowGroove Song JSON validator. `links` is documented in SONG_JSON_SCHEMA.md
// but used to be dropped silently on the way to Firestore — these lock the
// pass-through (and the youtubeUrl → links fold) so researched URLs survive.

const assert = require("node:assert/strict");
const { validateSong } = require("../src/mcp/song_schema");

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
