# Track website + user flow (TinyLaunch and beyond)

## Context

You asked how to confirm the Hugo landing site is tracked like the Flutter app,
and how to attribute traffic from TinyLaunch / other sources — wondering whether
to add Facebook Pixel or Google Ads.

**Premise correction from exploration:** the website is *already* instrumented.
`site/layouts/partials/analytics.html` loads **GA4** (`G-T6YBX0M53W`) + **Microsoft
Clarity** (`w8h5eswdua`) on every page. (The Flutter *web* build has analytics
disabled in `main.dart`, so on web the site's GA4 tag is the only signal — that's
fine, it covers web.)

The real gaps: (1) no UTM tagging so referral sources blur together, (2) three
conversion helper functions in `analytics.html` (`trackDemoClick`, `trackKofiClick`,
`trackFAQClick`) are **defined but wired to nothing**, (3) no Meta Pixel / Ads tag.

Goal: see where visitors come from (TinyLaunch etc.) and which ones convert —
with the **least code**, since most of this is free in GA4 already.

## Approach (ladder: free settings first, tiny code second, pixels deferred)

### Phase 1 — Zero code (does 80% of the job)

1. **UTM-tag the TinyLaunch submission** and any promo link you control. Submit the
   site to TinyLaunch as:
   `https://flowgroove.app/?utm_source=tinylaunch&utm_medium=referral&utm_campaign=launch`
   Reuse the pattern for Reddit/Telegram/etc. (`utm_source=reddit`, etc.). GA4 already
   reads these — no code.

2. **Turn on GA4 Enhanced Measurement** (GA4 Admin → Data streams → Web stream →
   Enhanced measurement). This auto-tracks **outbound clicks** (Ko-fi, GitHub,
   Telegram, Reddit links), scroll depth, and site search — covering most of the
   "conversion" clicks you listed with no code.

3. **Read the data:** GA4 → Reports → Acquisition → *Traffic acquisition* shows
   sources/UTMs; Clarity shows session replays + heatmaps. This is your "counter."

### Phase 2 — Tiny code: the clicks GA4 can't auto-catch

Enhanced Measurement only catches *outbound* clicks. The internal **"Open App"** CTA
(same-domain `/app/`) and **FAQ expands** need wiring. Reuse the existing dead helpers
— no new functions.

- **File `site/layouts/index.html`:**
  - Hero CTA `Open App — it's free` (line ~252) and nav `Open App` (line ~240):
    add `onclick="trackDemoClick&#40;&#41;"` (rename intent to `open_app` — see below).
  - FAQ accordion JS (the click handler at line ~448): add one line
    `if (typeof trackFAQClick === 'function') trackFAQClick(item.querySelector('.faq-q span').textContent);`
  - Ko-fi buttons (lines ~253, ~354) are outbound → already covered by Enhanced
    Measurement; optionally also add `onclick="trackKofiClick&#40;&#41;"` for a named event.

- **File `site/layouts/partials/analytics.html`:** rename `trackDemoClick` →
  `trackOpenApp` (event name `open_app`, category `conversion`) so the event reads
  honestly — there's no separate "demo" button anymore, the app open *is* the
  conversion. Keep `trackKofiClick` / `trackFAQClick` as-is.

> ponytail: these `onclick` handlers only exist on the home `index.html`. Blog/other
> pages render through `extend_head.html` → same `analytics.html`, so the functions
> load everywhere; they just have no buttons to fire on elsewhere. That's fine.

### Phase 3 — Ad pixels: defer, but make them a one-line config flip

You're not running paid ads *yet*. So don't ship live pixel scripts now — gate them
on config IDs that default empty (mirrors the existing `ga4_id`/`clarity_id` pattern).

- **`site/hugo.toml`** `[params.analytics]` block (lines ~77-80): add commented
  placeholders `# meta_pixel_id = ""` and `# gads_id = ""`.
- **`site/layouts/partials/analytics.html`:** add two `{{- with .Site.Params.analytics.meta_pixel_id -}}` /
  `{{- with .Site.Params.analytics.gads_id -}}` blocks containing the standard Meta
  Pixel base snippet and the Google Ads `gtag('config','AW-...')` line. With no ID
  set they render **nothing** — zero runtime cost until you actually run a campaign.

**Google Ads note:** you likely won't even need the `gads_id` block. When you start
Google Ads, just **link GA4 ↔ Google Ads** in the GA4 UI and import your existing
`open_app` event as a conversion — no tag at all. The `gads_id` stub is only for
remarketing/extra conversion actions.

**Cookie consent gap (flagged, your call):** `content/privacy.md` promises a "cookie
consent banner" that doesn't exist; GA4/Clarity (and any future Meta Pixel) load
unconditionally. Not required to ship tracking, but adding a Meta Pixel raises the
GDPR stakes. Out of scope here unless you want it — say so.

## Files touched

- `site/layouts/index.html` — wire `onclick` on Open App + Ko-fi; one line in FAQ JS.
- `site/layouts/partials/analytics.html` — rename `trackDemoClick`→`trackOpenApp`;
  add config-gated Meta Pixel + Google Ads stubs.
- `site/hugo.toml` — commented `meta_pixel_id` / `gads_id` placeholders.

No new dependencies. No new files.

## Verification

1. `cd site && hugo` (or your `make deploy-hugo` dry path) — build succeeds, no
   template errors.
2. Open `site/public/index.html` and grep: the Open App buttons have
   `onclick="trackOpenApp()"`; pixel stubs are **absent** (IDs empty).
3. Local serve (`hugo server`) + GA4 **DebugView** (or browser Network tab): click
   Open App → see `open_app`; expand a FAQ → see `faq_expand`; click Ko-fi → see the
   outbound `click` event.
4. Visit the site with `?utm_source=tinylaunch` and confirm it appears in GA4
   Realtime → traffic source = tinylaunch.
5. Pixel flip test (later): set a dummy `meta_pixel_id` in hugo.toml, rebuild,
   confirm the Meta snippet now renders; clear it, confirm it disappears.
