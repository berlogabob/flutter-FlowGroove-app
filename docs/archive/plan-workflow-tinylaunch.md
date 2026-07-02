# Plan / Workflow — Win the TinyLaunch Top-3 Badge for FlowGroove

> Goal: launch FlowGroove on TinyLaunch and land **Top 3 → badge + DR-72 dofollow backlink**.
> Not a user-acquisition play. It's a cheap badge + backlink + PR rehearsal before MicroLaunch/Product Hunt.
> Status: **plan — awaiting approval**. Execution will run on Sonnet.

---

## 0. Verified facts (June 2026)

| Thing | Value | Source |
|-------|-------|--------|
| Premium Launch | **$39** — skip queue, guaranteed backlink, shown 3rd–4th | tinylaunch.com/pricing |
| Standard Launch | Free, queue >1 month wait | tinylaunch.com/pricing |
| Backlink | **DR 72 dofollow** — only if badge embedded back | tinylaunch.com (homepage) |
| Top-3 reward | Badge + high-authority backlink | tinylaunch.com |
| New batch | Every **Monday ~11:00 MSK** | Habr case study |
| Votes for top-3 | **~35–40** historically; anti-fraud active | Habr case study |
| Category | **Music & Audio** exists | submission form |

**Card field limits:** name ≤30 · tagline ≤60 · description ≤10000 (simple HTML, no styles/scripts/links/embeds) · logo PNG/JPG/WebP ~200KB · working https URL · category.

---

## 1. Gap analysis — current `site/` vs what's needed

**Already done** (no work): features grid, story, FAQ (5), Ko-fi, badge placeholder, GitHub/Telegram/Reddit links, `privacy.md` + `terms.md` exist.

**Gaps to close** (ranked by impact on votes/approval):
1. ❌ **No app screenshots / no demo GIF** — `static/images/` has only logos + SVG covers. Highest impact.
2. ❌ **No positioning hook for the TinyLaunch crowd** (indie/SaaS/dev). Page is 100% "for musicians".
3. ❌ **No real OG/thumbnail image** (only `og-cover.svg`) — this is the card thumbnail people scan.
4. ❌ **No download / store / "what platform" clarity** — only "Open App".
5. ❌ **Privacy/Terms not linked in footer.**
6. ❌ **`content/tinylaunch.md` is stale** — DR 66 (→72), launch date May 1 (past).

---

## 2. Workflow (check off as we go)

### A. Landing page — visual + trust (the real work)
- [x] ~~Capture screenshots~~ — DONE via demo account: Home, Songs, Setlists, Tuner, Metronome → `site/static/images/shot-*.png`
- [x] ~~Add screenshots section~~ — DONE (`See It In Action` in `_index.md` + new `screenshot-card` shortcode + CSS)
- [x] ~~Real OG image~~ — DONE (`og-cover.png` 1200×630, `seo.html` updated)
- [x] ~~indie/open-source/Flutter hook~~ — DONE (hero body + `home_info`)
- [x] ~~platform/download clarity~~ — DONE (profile subtitle: "runs free in your browser")
- [x] ~~Privacy/Terms in footer~~ — DONE (`footer.text`; old `customText`/`hideCredits` keys were no-ops)
- [x] ~~**BUG: homepage body never rendered**~~ — DONE: PaperMod `profileMode` dropped all `_index.md` content; fixed via `layouts/_default/list.html` override (verified non-breaking for blog/tags/categories)
- [x] ~~Seed demo account with real data~~ — DONE on prod (`repsync-app-8685c`, demo uid `lePjILMinYV4A0UFbg5qePv6VBg2`): 8 real cover songs + "Saturday Night Set" setlist; band "дискотека" (inappropriate desc) renamed → "The Cover Collective". All `gabibabi`/`babi` junk deleted. Verified clean.
- [x] ~~**RE-SHOOT Songs + Setlists + Home**~~ — DONE: captured real demo data via Playwright (served `build/web` at its `/flutter-FlowGroove-app/app/` base href, logged in through "Try Demo Account", shot Home/Songs/Setlists at 384×720). Added a 2nd setlist ("Acoustic Evening") so the Setlists screen isn't sparse. Overwrote `shot-home/songs/setlists.png`. Build clean, all 5 carousel images present.
- [ ] Make **1 demo GIF** (~15–20s) of real-time sync — optional/deferred (needs 2 simultaneous sessions)
- [ ] Verify `https://flowgroove.app` loads fast, no broken links, mobile-OK
- [ ] Deploy site (`make deploy-hugo` per repo memory) and re-check live

- [x] ~~**New custom landing page**~~ — DONE: implemented Claude Design "FlowGroove Landing" as a standalone `site/layouts/index.html` (sticky nav, hero+phone, features, interactive screenshot carousel, story, FAQ accordion, Ko-fi goals, footer). Vanilla JS replaces the design's DCLogic; responsive breakpoints added (design was desktop-only); all links/images via `relURL` (works on flowgroove.app root + github.io subpath). Verified: home is fully custom, blog/about still PaperMod, prod build clean.

> **Theme decision (SETTLED — confirmed by the build):** keep PaperMod, stay linked. The custom landing is ONE standalone `layouts/index.html` override — **zero theme files touched**, PaperMod still serves+maintains blog/about/faq/wiki/legal. Do NOT fork (weeks re-inventing SEO/RSS/pagination/dark-mode). Only fork/vendor if you later reskin the WHOLE site to the "Mono Pulse" language — separate project, not needed for launch. Known tradeoff: visual seam between custom home and PaperMod inner pages (acceptable for launch).
> **Prior-session cruft found (optional cleanup, not blocking):** dead `assets/css/custom.css` (1 line, unreferenced); 7 unused shortcodes (`hero*`, `video-*`) + likely `single.embed.html` — abandoned custom-hero attempt. Delete, or reuse `hero*` as the product-hero starting point.
> **`.well-known/assetlinks.json`** — KEEP (confirmed). Required for Android App Links verification (`com.flowgroove.app`). Make sure the deploy actually uploads `/.well-known/assetlinks.json` to the FTP root.

### B. TinyLaunch card copy (draft, ready to paste)
- [ ] **Name:** `FlowGroove`
- [ ] **Tagline (≤60):** `Songs, setlists & rehearsal tools for bands` (44 chars)
- [ ] **Category:** Music & Audio
- [ ] **Description (simple HTML):** finalize the block below
- [ ] **Logo:** export `logo_clean.png` → ≤200KB PNG
- [ ] **URL:** `https://flowgroove.app`

```html
<h2>What is FlowGroove?</h2>
<p>An open-source, Flutter app that fixes real band-workflow chaos. Songs, setlists, metronome, tuner and rehearsal flow in one place.</p>
<h2>The problem</h2>
<p>Bands scatter songs, keys, BPM, notes and setlists across chats, PDFs, spreadsheets and separate metronome/tuner apps.</p>
<h2>The solution</h2>
<p>FlowGroove brings it all into one musician-first workspace — with real-time setlist sync across the whole band.</p>
<h2>Features</h2>
<ul>
  <li>Real-time setlist sync across all devices</li>
  <li>Auto BPM &amp; key detection</li>
  <li>Songs database with structure & notes</li>
  <li>Setlists for rehearsals and gigs</li>
  <li>Metronome &amp; tuner built in</li>
  <li>Works offline · stage-ready dark mode</li>
</ul>
<h2>Who is it for?</h2>
<p>Cover bands, small groups, teachers, session and solo musicians.</p>
```

### C. Launch-day campaign (target: 45+ votes — buffer over the 35–40 threshold)
> Case-study reality: author took **top-1 with only ~25 votes** (own channels + ~15 friends). The win came from the **end-game rally**, not launch day. Right-size accordingly — don't build a campaign bigger than the platform.
- [ ] Buy **Premium Launch ($39)** ~1 week ahead (paid slots are limited)
- [ ] Build **boost list of ~25–35 people** to DM personally — split into **launch-day group + a reserve group held for the final night**
- [ ] Launch Monday (~11:00 MSK batch): collect **first 15–20 votes in opening hours** (early top-3 snowballs)
- [ ] Ask each person for: **upvote + open site + short comment** (engagement signals)
- [ ] One post each to personal TG, FlowGroove TG, Reddit — then stop. **DMs are the only real channel** (author's big TG/Twitter + $50 email push converted ~0)
- [ ] Monitor + reply to every comment within hours
- [ ] **🔑 Don't coast.** Even if comfortably top-2, check standings the night before Monday cutoff and **fire the reserve group** — this is exactly the move that saved the case-study win after a last-night vote-buying surge (admin later purged the fakes)

### D. Post-launch
- [ ] **Embed the TinyLaunch badge with dofollow link back** on `flowgroove.app` (required to keep the backlink) — wire up the existing `tinylaunch-badge` shortcode
- [ ] Update `content/tinylaunch.md`: fix DR 66→72, real launch date, fill results table
- [ ] Write a short "We launched on TinyLaunch" devlog post (poster CLI → Telegram/Reddit)
- [ ] Thank the boost list

### E. Ship it (final)
- [ ] **Double-check everything**: local `hugo` build is clean, screenshots render, all links resolve, footer has Privacy/Terms, badge embed present
- [ ] **`make release-all`** — deploys Firebase rules + FTP app + Hugo site to flowgroove.app + GitHub Pages + cuts Android GitHub release
- [ ] Verify live: `https://flowgroove.app` loads the new page, no regressions

---

## 3. Corrections to make in repo (fold into A/D)
- [ ] `content/tinylaunch.md`: `DR 66+` → `DR 72`
- [ ] `content/tinylaunch.md`: launch date May 1 (past) → real Monday date
- [ ] `content/tinylaunch.md`: set `draft: true` stays (internal doc) — do **not** publish

---

## Skipped on purpose (ponytail)
- No paid email blast ($50) / featured spots ($15–30/wk) — author's $50 newsletter ad returned ~0; add only if you want extra reach for its own sake.
- No big paid social campaign — author got ~0 votes from large TG/Twitter pushes; effort goes to DMs + the card instead.
- No new video production pipeline — one screen-recorded GIF is enough.
- No directory-submission package ($179+) — out of scope for the badge.
- No 3-week prep gauntlet — that was for Product Radar; TinyLaunch is a ~1-week-prep "warm-up" platform.
