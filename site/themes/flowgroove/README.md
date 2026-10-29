# FlowGroove

Light paper by default, with a saved dark mode under `fg-theme`. The theme owns
shared tokens, header/footer, editorial styles, and the small toggle/menu script.
The standalone landing loads those same assets; its composition stays in
`static/landing/styles.css`. Fonts are served from `static/fonts/`.

Hugo uses `flowgroove` first and falls back to the unmodified PaperMod theme.
Project SEO, analytics, RSS, embed output, and shortcodes remain in `layouts/`.
The `notfound` home output explicitly generates `404.html`; `404.md` remains
untouched as a separate content page. The error document canonicalizes to it.

From `site/`:

```sh
hugo --minify -d /tmp/theme-public
python3 scripts/check-flowgroove.py /tmp/theme-public
node scripts/test-flowgroove.cjs
```

The checker reports existing unpublished-post links separately. Production has
28 distinct changelog URLs targeting draft posts. `tinylaunch.md` is also a draft;
it can be inspected with `hugo --buildDrafts` without changing publication state.
There is no content page for `/songs/`; `/wiki/songs/` exists. Content and front
matter were not changed. Browser layout/screenshots still need visual review.

Rollback: set `theme = "PaperMod"` in `hugo.toml`, then copy the contents of
`layouts_legacy/` over `layouts/`, retaining other existing layouts. This restores
the original list and roadmap templates and a standalone landing with its legacy
light chrome. `index.notfound.html` keeps the error document working on rollback.
No files under `themes/PaperMod/` need changing.
