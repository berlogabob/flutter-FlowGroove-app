# FlowGroove Devlog — The Series

A serialized blog: mini "episodes" mined from the real project history
(`site/data/history.yaml` — 635 changes, 233 releases, day 0 = 2026-02-03).
Each episode is a self-contained post that also pulls the reader toward the next,
like a TV season. Source-of-truth for *what shipped* stays in `history.yaml`;
this file is the **editorial bible** — the order to tell it in.

**How to use:** pick the next unwritten episode, ask the scriptwriter (me) to draft
it. Drafts go to `site/content/blog/` in the proven `What changed / Why it matters`
(devlog) or long-form story format. When published, mark the matching
`history.yaml` entry `blog: published` + `blog_ref` (via the `BLOG` overlay in
`scripts/gen_history.py`, then regenerate) so the changelog auto-links it.

**Status legend:** ⬜ idea · ✏️ drafted · ✅ published

**Count:** 48 episodes below across 7 seasons. To reach ~120, split any episode
marked 🔁 into its per-phase beats (each season has 2–3 splittable ones) — the
history has the granularity; this bible just sets the narrative spine.

Already published: S2E1 (metronome drift), and the in-app-help devlog
(`2026-06-24`) which slots as S7E5.

---

## Season 1 — Origin Story
*Why a working musician started writing an app between rehearsals. The hook season:
relatable pain, no code. Long-form, personal.*

- ⬜ **S1E1 — The Tuesday the setlist got lost (again)** — the breaking point that
  started it all. *(story; reuses post-001 beats, fresh open)*
- ✅ **S1E2 — Why I built FlowGroove between rehearsals** — already live as
  `post-001`. Anchor episode.
- ✅ **S1E3 — 5 problems every cover band has** — already live as `post-002`.
- ⬜ **S1E4 — One codebase, three screens: betting on Flutter** — why Flutter for a
  solo dev shipping web + Android at once. 🔁 *(devlog/story; source: Genesis phase)*
- ⬜ **S1E5 — "Free for indie musicians" is a feature, not a price** — the business
  philosophy, Ko-fi, honesty with users. *(story)*
- ⬜ **S1E6 — Day 0: it was called `repsync`** — the rename, the first commit, what
  the app looked like before it had a name. *(devlog; source: commit da5c0759)*

## Season 2 — The Metronome Saga
*The deepest technical thread. The metronome is where most of the hard problems
lived. Devlog format, dev-curious audience.*

- ✅ **S2E1 — Why the metronome slowly drifted** — published `2026-06-25`. The
  WallClockScheduler / drift-compensation fix. Season opener.
- ⬜ **S2E2 — The web metronome was silent (and why)** — `flutter_soloud` has no web
  path; the Web Audio API engine. *(devlog; source: web-metronome-audio-path)*
- ⬜ **S2E3 — Reaper-style accent patterns in a phone metronome** — accent grid,
  subdivisions, Tap BPM. *(devlog; source: Feb 20 metronome phases)*
- ⬜ **S2E4 — The Tone Matrix** — per-beat tone/accent control instead of one flat
  click. *(devlog; source: Mar 30 phase3)*
- ⬜ **S2E5 — It's dead silent on Bluetooth headphones** — SoLoud binds the audio
  device once at init and never handles route changes. 🔁 *(devlog; source:
  metronome-bluetooth-route-bug — war story, may still be open)*
- ⬜ **S2E6 — Instant first beat** — audio pre-initialization so the very first tap
  isn't late. *(devlog; source: Mar 30 phase1)*
- ⬜ **S2E7 — Making the click *feel* tight** — vibration sync + focus manager, the
  perceptual side of timing. *(devlog)*
- ⬜ **S2E8 — A metronome you can read on a dark stage** — visual polish, the central
  tempo circle, contrast over pure black. *(devlog/design)*

## Season 3 — Smart Songs
*The "type it, don't type it" thread: metadata that fills itself in.*

- ⬜ **S3E1 — Manual entry is where good intentions die** — the case for autocomplete.
  *(story/devlog; source: Feb 19 + Mar 30 autocomplete)*
- ⬜ **S3E2 — Pulling BPM and key from MusicBrainz** — wiring a real music database.
  🔁 *(devlog; source: feat(services) MusicBrainz)*
- ⬜ **S3E3 — Canonical songs and the duplicate problem** — dedupe so a shared library
  doesn't rot. *(devlog; source: Mar 30 duplicate detection)*
- ⬜ **S3E4 — Band songs are copies, not links** — the deliberate data-model call and
  why editing one needs a `bandId`. *(devlog; source: band-songs-are-copies-editing)*
- ⬜ **S3E5 — The song structure editor that vanished** — a feature dropped in a
  release and how it got restored. *(war story; source: song-structure-editor-regression)*
- ⬜ **S3E6 — Setlists that survive a coffee spill** — building/ordering setlists,
  export, the paper-setlist replacement. *(devlog; source: setlists area)*

## Season 4 — Playing Together
*Multiplayer: bands, roles, sync, offline, performing live. The product payoff.*

- ⬜ **S4E1 — Real-time sync on a venue's terrible WiFi** — Firestore, offline-first,
  why it's not optional for musicians. 🔁 *(devlog; source: sync area)*
- ⬜ **S4E2 — Who's allowed to do what** — server-authoritative band membership; joins
  go through Cloud Functions, not client writes. *(devlog; source:
  band-membership-server-authoritative)*
- ⬜ **S4E3 — The join-by-link that did nothing** — cold-start deeplink ran before
  Firebase auth restored. *(war story; source: join-deeplink-coldstart-auth-race)*
- ⬜ **S4E4 — "Failed to load band data" on restart** — null router state and resolving
  bands by id. *(war story; source: band-routes-resolve-by-id)*
- ⬜ **S4E5 — Permission denied on a brand-new account** — a missing `users/{uid}` doc
  crashing role lookup; hardening the rules. *(war story; source:
  band-create-join-userdoc-permission)*
- ⬜ **S4E6 — The demo account that's actually real** — seeding a populated band so
  "Try Demo" sells the app. *(devlog; source: demo-account-seeded-data)*
- ⬜ **S4E7 — Concert Mode** — performing live: the on-stage UI, wakelock, big targets.
  *(devlog/design; source: concert-mode wiki + Apr 9 touch targets)*

## Season 5 — Shipping It
*The unglamorous infrastructure that keeps a solo project alive. For builders.*

- ⬜ **S5E1 — Two deploy channels, one repo** — dev on GitHub Pages, prod on
  flowgroove.app via FTP. 🔁 *(devlog; source: deploy-channels-ftp-vs-pages)*
- ⬜ **S5E2 — Landing page and app, shipping apart** — the dual-deploy architecture +
  MonoPulse Hugo theme. *(devlog; source: Apr 8 dual-deploy)*
- ⬜ **S5E3 — `make release` and the ritual it replaced** — one command for Android +
  GitHub Release; the pre-commit hook that blocks secrets. *(devlog; source: release-process)*
- ⬜ **S5E4 — The robot that commits while I sleep** — the auto release/deploy loop, and
  why git status always looks weird. *(devlog; source: auto-release-deploy-loop)*
- ⬜ **S5E5 — Obtainium said "Conflict"** — CI was randomly debug-signing every build; a
  dedicated upload keystore fixed it. *(war story; source: android-signing-stable-key)*
- ⬜ **S5E6 — The release that crashed on launch** — duplicate Firebase init on a key
  mismatch; the `Firebase.apps.isEmpty` guard. *(war story; source: firebase-init-duplicate-app)*
- ⬜ **S5E7 — Posting the devlog everywhere at once** — the tiny poster CLI
  (devlog → Telegram + Reddit) and why it's deliberately only 4 files. *(devlog; source: poster-cli)*

## Season 6 — Bugs That Taught Me
*Pure war-story season. Each episode: the symptom, the hunt, the one-line truth.
Highest engagement potential — everyone loves a debugging story.*

- ✅ **S6E1 — The blog posts that 404'd** — published `2026-06-25`. A bare `index.html`
  gitignore rule swallowing Hugo pages on Pages.
- ✅ **S6E2 — The iframe that froze the whole web app** — published `2026-06-25`. Why
  HtmlElementView is a trap on Flutter web; open a new tab instead.
- ✅ **S6E3 — Two faces, one user** — published `2026-06-25`. Google avatar on home,
  Telegram avatar on profile; making the profile choice authoritative.
- ⬜ **S6E4 — Avatars that wouldn't upload on web** — `putData` vs `putFile`, bucket
  CORS, mirroring external photos server-side. *(source: storage-web-avatars)*
- ⬜ **S6E5 — The next/prev buttons I accidentally deleted** — a refactor that quietly
  removed navigation, caught in build errors. *(source: 2026-06-24 session)*
- ⬜ **S6E6 — `currentUserProvider` touched 30 nodes** — using a knowledge graph to find
  accidental coupling across band screens. *(source: graphify sessions)*
- ⬜ **S6E7 — "Last good version before the major refactor"** — the v1.0.0 attempt, the
  revert, and learning to tag escape hatches. *(source: Feb 25–26 churn era)*
- ⬜ **S6E8 — The day everything was version 0.11.2+68** — what 235 auto-deploy commits
  taught me about meaningful history (and why this very series exists). *(meta)*

## Season 7 — Building With AI
*The modern-solo-dev meta thread: shipping a real app with AI assistants. Timely,
shareable, distinct from the music angle.*

- ⬜ **S7E1 — A memory that survives `/clear`** — the file-based memory system + "Mr.
  Memory" agent. *(devlog; source: Mar 14 memory system)*
- ⬜ **S7E2 — Lazy on purpose** — the ponytail philosophy: the laziest solution that
  works, applied to a real codebase audit. *(story; source: 2026-06-24 ponytail-audit)*
- ⬜ **S7E3 — Turning a repo into a knowledge graph** — graphify, god nodes, finding what
  connects to what. *(devlog; source: graphify sessions)*
- ⬜ **S7E4 — Linking my design system to an AI** — the Claude design MCP connector and
  keeping the app on-brand. *(devlog; source: 2026-06-23 design sessions)*
- ✅ **S7E5 — In-app help that follows the screen you're on** — published `2026-06-24`.
  Same Markdown powers site docs and the in-app wiki panel.
- ⬜ **S7E6 — I asked the git log to write my blog** — this pipeline: history.yaml →
  changelog → episode bible → posts. The series, explained by the series. *(meta;
  source: scripts/gen_history.py)*

---

### Extending to ~120

The 🔁-marked episodes each fan out into 3–5 per-phase beats already present in
`history.yaml` (e.g. S2E1 → drift, monotonic clock, scheduler rewrite, audio-engine
rewrite). Split those and you clear 90+. The remaining gap fills from the ~589
`blog: none` entries — promote any to `idea` when an angle appears. Don't pre-write
120 stubs; pull the next episode when you're ready to draft it. *(ponytail: a backlog
is not a deliverable until someone reads it.)*
