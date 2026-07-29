const assert = require("node:assert/strict");
const { t, pickLang, STRINGS } = require("../src/telegram/i18n");

describe("telegram i18n", function () {
  it("interpolates placeholders", () => {
    const s = t("en", "status_ok", { id: "u1", name: "Andre", email: "a@b.c" });
    assert.ok(s.includes("u1") && s.includes("Andre") && s.includes("a@b.c"));
    assert.ok(t("en", "link_not_found", { userId: "xyz" }).includes("xyz"));
  });

  it("falls back to Russian for an unknown language", () => {
    assert.equal(t("de", "unlink_done"), t("ru", "unlink_done"));
  });

  it("returns the key itself for an unknown key", () => {
    assert.equal(t("en", "___missing___"), "___missing___");
  });

  it("pickLang chooses en for en* codes, ru otherwise", () => {
    assert.equal(pickLang({ from: { language_code: "en-US" } }), "en");
    assert.equal(pickLang({ from: { language_code: "ru" } }), "ru");
    assert.equal(pickLang({}), "ru");
  });

  it("every Russian key has an English counterpart", () => {
    for (const key of Object.keys(STRINGS.ru)) {
      assert.ok(key in STRINGS.en, `missing en translation for "${key}"`);
    }
  });
});
