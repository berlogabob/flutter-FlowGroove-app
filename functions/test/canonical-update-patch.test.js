// canonicalUpdatePatch decides what a canonical update actually writes. It is
// pure so the same validation covers both callers: the updateCanonicalSong
// callable (app + agent traffic, auth-checked) and admin-SDK repair scripts,
// which bypass firestore.rules entirely.
//
// The default is fill-only. That matters because a canonical is shared by every
// band that links to it, so "any authenticated user may rewrite it" would be a
// vandalism vector — and because the 14 canonicals in prod need blanks filled,
// not their few good values clobbered.

const assert = require("node:assert/strict");

process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "repsync-app-callable-test";
process.env.FIREBASE_CONFIG = process.env.FIREBASE_CONFIG ||
  JSON.stringify({ projectId: "repsync-app-callable-test" });

const { canonicalUpdatePatch, canonicalSongIdFor, normalize } =
  require("../src/canonical");

describe("canonicalUpdatePatch", () => {
  it("fills blank fields", () => {
    const { changes, warnings } = canonicalUpdatePatch(
      { album: null, releaseYear: null, genres: [] },
      { album: "Second Helping", releaseYear: 1974, genres: ["rock"] },
    );
    assert.deepEqual(changes, {
      album: "Second Helping", releaseYear: 1974, genres: ["rock"],
    });
    assert.deepEqual(warnings, []);
  });

  it("keeps an existing value and warns, without overwrite", () => {
    const { changes, warnings } = canonicalUpdatePatch(
      { album: "Apocalypse Now" },
      { album: "The Doors" },
    );
    assert.deepEqual(changes, {});
    assert.deepEqual(warnings, ["album already set — kept existing value"]);
  });

  it("replaces an existing value with overwrite", () => {
    const { changes, warnings } = canonicalUpdatePatch(
      { album: "Apocalypse Now" },
      { album: "The Doors" },
      { overwrite: true },
    );
    assert.deepEqual(changes, { album: "The Doors" });
    assert.deepEqual(warnings, []);
  });

  it("treats an identical value as a no-op, not a conflict", () => {
    const { changes, warnings } = canonicalUpdatePatch(
      { album: "The Doors", genres: ["rock"] },
      { album: "The Doors", genres: ["rock"] },
    );
    assert.deepEqual(changes, {});
    assert.deepEqual(warnings, []);
  });

  it("ignores blank incoming values so a null never wipes real data", () => {
    const { changes } = canonicalUpdatePatch(
      { album: "The Doors", isrc: "USEE19900203" },
      { album: null, isrc: "", genres: [] },
      { overwrite: true },
    );
    assert.deepEqual(changes, {});
  });

  it("refuses title and artist, which define the document id", () => {
    const { changes, warnings } = canonicalUpdatePatch(
      { title: "Old", artist: "Old" },
      { title: "New", artist: "New" },
      { overwrite: true },
    );
    assert.deepEqual(changes, {});
    assert.deepEqual(warnings, [
      "title defines the canonical id and cannot be updated here",
      "artist defines the canonical id and cannot be updated here",
    ]);
  });

  it("warns about unknown fields instead of writing them", () => {
    const { changes, warnings } = canonicalUpdatePatch(
      {},
      { album: "X", status: "hidden", createdBy: "someone-else", nonsense: 1 },
    );
    assert.deepEqual(changes, { album: "X" });
    assert.deepEqual(warnings, [
      "ignored unknown field: status",
      "ignored unknown field: createdBy",
      "ignored unknown field: nonsense",
    ]);
  });

  it("range-checks numeric fields", () => {
    const { changes, warnings } = canonicalUpdatePatch({}, {
      releaseYear: 1206,
      durationMs: -5,
      baseBpm: 5000,
    });
    assert.deepEqual(changes, { releaseYear: 1206 });
    assert.equal(warnings.length, 2);
    assert.match(warnings[0], /durationMs must be a number/);
    assert.match(warnings[1], /baseBpm must be a number/);
  });

  it("rejects a future release year but accepts next year", () => {
    const nextYear = new Date().getFullYear() + 1;
    assert.deepEqual(
      canonicalUpdatePatch({}, { releaseYear: nextYear }).changes,
      { releaseYear: nextYear },
    );
    assert.deepEqual(canonicalUpdatePatch({}, { releaseYear: nextYear + 5 }).changes, {});
  });

  it("rounds fractional numbers", () => {
    assert.deepEqual(canonicalUpdatePatch({}, { baseBpm: 98.4 }).changes, { baseBpm: 98 });
  });

  it("cleans and filters the genres array", () => {
    const { changes } = canonicalUpdatePatch({}, { genres: ["  rock ", "", "  ", "blues"] });
    assert.deepEqual(changes, { genres: ["rock", "blues"] });
  });

  it("rejects a non-array genres value", () => {
    const { changes, warnings } = canonicalUpdatePatch({}, { genres: "rock" });
    assert.deepEqual(changes, {});
    assert.deepEqual(warnings, ["genres must be an array — ignored"]);
  });

  it("rejects non-string values for string fields", () => {
    const { changes, warnings } = canonicalUpdatePatch({}, { album: { nope: true } });
    assert.deepEqual(changes, {});
    assert.deepEqual(warnings, ["album must be a string — ignored"]);
  });

  it("handles a missing existing document without throwing", () => {
    assert.deepEqual(
      canonicalUpdatePatch(null, { album: "X" }).changes,
      { album: "X" },
    );
    assert.deepEqual(canonicalUpdatePatch(undefined, undefined).changes, {});
  });
});

describe("canonical id derivation", () => {
  it("is Unicode-aware, so Cyrillic titles do not collapse", () => {
    assert.equal(normalize("День рождения"), "день рождения");
    assert.equal(normalize("Ногу Свело!"), "ногу свело");
    assert.notEqual(
      canonicalSongIdFor(normalize("День рождения"), normalize("Ногу Свело!")),
      canonicalSongIdFor(normalize("День рождения"), normalize("Ленинград")),
    );
  });

  it("reproduces the prod artifact id from empty normalization", () => {
    // sha256("\n") — the doc every Cyrillic song collapsed into before the
    // Unicode fix. Pinned so it is obvious what the guard in ensureCanonicalSong
    // is preventing.
    assert.equal(
      canonicalSongIdFor("", ""),
      "normalized_01ba4719c80b6fe911b091a7c05124b6",
    );
  });

  it("normalizes punctuation-only input to empty, which the guard rejects", () => {
    assert.equal(normalize("!!!"), "");
    assert.equal(normalize("???"), "");
  });
});
