# FlowGroove Architecture

**Last Updated:** July 5, 2026  
**Version:** 0.14.2+323

## Overview

This repository contains these meaningful systems:

1. Flutter application
2. Hugo marketing site (also the single source for the in-app help **wiki** — `site/content/wiki/`)
3. Telegram bot (lives inside Firebase Functions)
4. Firebase Functions workspace (band membership, account deletion, avatar import, MCP gateway, canonical-song catalog)
5. FlowGroove MCP server (`mcp/`) — connect-your-own-AI: per-user API keys → Functions gateway → Firestore
6. Imported AI workspace context (`memory/`, `.codex/`)

The operational product is split across the Flutter app and the Hugo site. The other areas support deployment, support operations, and continuity.

## Top-Level Layout

```text
flutter_repsync_app/
├── lib/                # Flutter app source
├── test/               # Flutter tests
├── site/               # Hugo source
├── docs/               # GitHub Pages output + reports
├── functions/          # Firebase Functions (incl. Telegram bot in src/telegram/)
├── scripts/            # build, deploy, session, and maintenance scripts
├── memory/             # protected project memory bank
├── .codex/             # active Codex control plane and imported workspace context
└── oldarchive/         # archived Qwen context, exports, backups, and legacy support files
```

## Runtime Systems

### 1. Flutter App

Primary app code lives in `lib/`.

#### Main Layers

- `screens/` - route-level UI
- `widgets/` - reusable UI components
- `providers/` - Riverpod state and derived permissions
- `repositories/` - data access boundaries
- `services/` - integration and business logic
- `models/` - domain and transfer objects
- `router/` - GoRouter configuration
- `theme/` - MonoPulse theme system
- `config/` - runtime/web/mobile config helpers

#### Key Flows

- Auth: Firebase Auth -> `auth_provider.dart` -> GoRouter redirects
- Data: Firestore repositories + local cache + sync orchestration
- Tools: Metronome and tuner providers drive tool-specific widgets
- Permissions: app-level role checks in `permissions_provider.dart`

#### Current User-Facing Modules

- Home/dashboard
- Auth screens
- Songs
- Bands
- Setlists
- Rehearsal Planner (per-band availability poll → confirmed rehearsal)
- Profile
- Metronome
- Tuner
- Concert Mode + Performance sheet (pushed on the root navigator, not GoRouter routes)
- Song duplicate detection / cluster merge
- AI access (MCP) key management

#### Integration Services

- Catalog autofill: MusicBrainz (search; suggestions ranked against title+artist so a full-name query floats the right recording up — no confidence % shown) + Deezer (tempo/key) + lyrics.ovh (lyrics split into Verse/Chorus sections via `lib/utils/lyrics_sections.dart`); Spotify path optional/off. Accepting a suggestion also generates tappable provenance links (MusicBrainz/Spotify deep links + YouTube/chords/lyrics searches) via `lib/utils/suggestion_links.dart`
- Canonical song catalog via Cloud Functions
- Desktop wiki panel loads bundled `site/content/wiki/*.md` (shared with the Hugo site)

### 2. Hugo Site

Marketing-site source lives in `site/`.

#### Purpose

- landing page
- FAQ, about, privacy, terms
- blog and SEO content
- public roadmap (`/roadmap/`) — build-time snapshot of GitHub Project #8
- GitHub Pages preview root
- production root site for FTP deployment

The roadmap page renders the project board on-site (GitHub blocks iframing). On
each deploy, `scripts/fetch-roadmap.sh` pulls Project #8 via `gh api graphql`
into `site/data/roadmap.json`, and `layouts/_default/roadmap.html` renders it as
kanban columns from the `Status` field. Needs `gh` authed with the `project`
scope; on failure it keeps the existing snapshot so deploys never break. Note:
the home page nav is hardcoded in `layouts/index.html` (not the PaperMod menu),
so nav links must be added in both `hugo.toml` and `layouts/index.html`.

#### Important Output Paths

- GitHub Pages preview root: `docs/`
- production FTP root: `site/public/` mirrored to `flowgroove.app/`

### 3. Telegram Bot

There is a single bot — **@flowgroovebot** — served by the `telegramWebhook`
Cloud Function in `functions/src/telegram/` (Telegraf/Node). The same bot also
posts devlogs to the `@flowgrooveapp` channel via `poster/poster.py` (same token).

#### Purpose

- link Telegram users to FlowGroove accounts
- route support DMs into the `SUPPORT_GROUP_ID` group as per-user forum topics, with admin replies routed back to the user
- post devlogs to the announce channel (poster script)

This subsystem is documented separately in `functions/src/telegram/README.md`.

### Devlog publishing pipeline

One devlog post fans out from a single source. Only **Reddit** is automated — a
Devvit *cloud* cron crossposts the newest feed item to `r/FlowGroove` (live there
since 2026-06-29; before that the bot was installed only in the test sub). The Hugo
site and the Telegram channel are posted **manually** — the old nightly launchd
auto-deploy (`devlog-daily.sh`) was unreliable (macOS Full Disk Access, exit 126)
and is disabled. X and Instagram are manual too: copy is pre-written in the post's
`.social.yaml` sidecar (`x` / `instagram` blocks) — nothing reads those. The map
below shows every entry point and the two dedup guards.

```mermaid
flowchart TD
    subgraph author["Authoring — manual"]
        draft["poster.py draft --title --commits"]
        write["edit .md body + telegram.text"]
        files[".md (draft:true) + .social.yaml"]
        draft --> files
        write --> files
    end

    subgraph tg["Telegram — manual"]
        tgpub["poster.py publish telegram"]
        tgchan["@flowgrooveapp channel"]
        tgpub -->|"dup-guard: .social.yaml message_id"| tgchan
    end
    files --> tgpub

    subgraph manual["X + Instagram — manual copy/paste"]
        xnode["X / Twitter — paste x.text"]
        ignode["Instagram — paste caption + image"]
    end
    files -.->|"hand-posted, nothing reads these"| xnode
    files -.->|"hand-posted, nothing reads these"| ignode

    subgraph web["Web + RSS feed — manual deploy"]
        flip["flip draft:false"]
        deploy["make deploy-hugo (FTP, prod)"]
        mirror["scripts/mirror-feed.sh (separate step)"]
        hugo["hugo --minify -> site/public/ + index.xml"]
        ftp["FTP -> flowgroove.app/blog/"]
        feed["GCS reddit-feed.xml (public)"]
        flip --> deploy --> hugo --> ftp
        hugo --> mirror --> feed
    end
    files --> flip

    subgraph reddit["Reddit — Devvit, automatic"]
        cron["scheduler cron 0 11 UTC daily"]
        menu["mod menu: Publish latest devlog now"]
        bot["check-feed: newest /blog/ item only"]
        sub["r/FlowGroove link post"]
        cron --> bot
        menu --> bot
        bot -->|"dup-guard: Redis posted:guid"| sub
    end
    feed --> bot
```

**Entry points**

| Channel | Trigger | Type | Source |
|---------|---------|------|--------|
| Web | `make deploy-hugo` (FTP → flowgroove.app) | manual | `Makefile` |
| Reddit feed | `scripts/mirror-feed.sh` — run **after** deploy | manual | `scripts/mirror-feed.sh` |
| Telegram | `poster.py publish telegram <slug>` (needs a `.social.yaml`) | manual | `poster/poster.py` |
| Reddit | scheduler cron `0 11 * * *` (live in r/FlowGroove since 2026-06-29) | scheduled (cloud) | `reddit-bot/devvit.json` |
| Reddit | mod menu "Publish latest devlog now" | manual (mod) | `reddit-bot/src/server/index.ts` |
| X / Twitter | copy `x.text` from the sidecar, post by hand | manual | `<post>.social.yaml` |
| Instagram | copy `instagram.caption` + `image`, post by hand | manual | `<post>.social.yaml` |

The nightly `devlog-daily.sh` launchd job (09:00) that used to chain deploy + feed
mirror is **disabled** — it failed under macOS Full Disk Access (exit 126). Deploys
are manual; re-enable only after granting FDA to the launchd process.

**Caveats:**
- `make deploy-hugo` uploads the site over FTP but does **not** refresh the Reddit
  feed — run `scripts/mirror-feed.sh` after it (the disabled nightly job used to chain
  the two; `scripts/deploy-hugo.sh` is the GitHub-Pages/dev path and mirrors on its own).
- The Reddit bot posts only the **newest** `/blog/` item per feed refresh. Deploy one
  post at a time when each needs to reach Reddit (see `poster/README.md`, `reddit-bot/README.md`).
- **Telegram needs the `.social.yaml` sidecar** (`telegram.text`); web + Reddit don't.
  The 2026-06-25 series posts ship without sidecars, so they reach web + Reddit but
  **not** Telegram until a sidecar is added.
- **X / Instagram:** no automation — the sidecar just stores the copy. X links are
  clickable; Instagram captions are not, so the `instagram` block says "link in bio"
  and carries a hashtag block + an `image` pointer (no per-post images exist; reuse a
  shared asset from `site/static/images/`).

### 4. Firebase Functions

Cloud function code lives in `functions/` (Node 22, gen-2). Implementations are under
`functions/src/`; `functions/index.js` only wires exports. Mocha tests run against the
Firestore emulator (`npm test` — needs JDK 21+).

Server-authoritative callables (admin-SDK, so they bypass client-side rules):

- `joinBand`, `updateBandMember` (`src/bands.js`) — atomic membership writes.
- `deleteAccount` (`src/account.js`) — account deletion for Google Play: detaches the
  user from every band (dissolving empty ones, promoting a remaining member if needed),
  recursive-deletes their data + avatar, then deletes the Auth user last. No client
  re-auth needed.
- `ensureCanonicalSong` (`src/canonical.js`) — dedupe/create canonical songs.
- `setBandAvatar` / `removeBandAvatar` (`src/band_avatar.js`),
  `importTelegramAvatar` / `importGoogleAvatar` (`src/avatars.js`).
- `createApiKey` / `listApiKeys` / `revokeApiKey` (`src/mcp/keys.js`) — per-user MCP
  API keys (random token shown once, only its SHA-256 stored, revocable, demo-blocked).

HTTP + scheduled: `telegramWebhook`, `shareToTelegram`, `onBandSetlistCreated`,
`dailyEventReminder`, `onRehearsalCreated` / `onRehearsalUpdated`
(`src/telegram/rehearsals_notify.js` — fan out proposal/confirmation notices via
`notifyBandMembers`), plus the MCP endpoints `mcpGateway`
(`src/mcp/gateway.js`, API-key) and `mcpRemote` (`src/mcp/remote.js`, remote OAuth) — see §6.

Note: rehearsal CRUD is **not** a callable — the client writes
`bands/{bandId}/rehearsals/*` directly, gated by Firestore rules (member-owns-own-vote,
editor/admin create, admin delete). Only the Telegram fan-out is server code.

### 5. AI Workspace Context

The repo keeps a protected memory bank and a normalized Codex control plane:

- `memory/` - protected root memory bank
- `.codex/` - preferred active structure for agents, rules, tasks, sessions, and durable workflow state
- `oldarchive/` - archived Qwen source context and related historical outputs

This context is operational documentation, not app runtime code.

### 6. AI-ready Song Workflow / MCP

The **Song JSON** format (`docs/SONG_JSON_SCHEMA.md`, `services/json/song_json_codec.dart`)
is the stable contract for letting a user's own AI prepare songs. Three ways to use it, all
sharing one set of tool functions (`src/mcp/tools.js`):

- **Manual (built):** export a song as JSON / paste AI output into Import (auto-detects
  JSON vs CSV, validated + previewed before save). Ready-made prompts via
  `services/json/song_ai_prompt.dart` + `docs/AI_PROMPTS.md`.
- **MCP API key (built + deployed, e2e-verified):** per-user **API key** (in-app: Profile →
  *AI access (MCP)*; token shown once, only its SHA-256 stored) → the authenticated
  `mcpGateway` (maps key→uid, read/write scope) → a user-run **Node MCP server** (`mcp/`,
  `@modelcontextprotocol/sdk`). Live in prod. See `mcp/README.md`.
- **Remote OAuth connector (spike; provider/deploy gated):** `mcpRemote`
  (`src/mcp/remote.js`) — a hosted MCP Streamable-HTTP server so Claude/ChatGPT add
  FlowGroove as a **one-click custom connector** (OAuth 2.1 via a managed provider + Google
  login → Firebase uid). No key, no local server. Runbook: `docs/MCP_REMOTE_SETUP.md`.

Every path validates writes server-side (`src/mcp/song_schema.js`), scopes them to the
caller's own uid, and does no canonical-song or destructive writes. Users bring their own AI,
so FlowGroove pays no tokens. Richer tools (sections/chords/lab/homework) land with Song Lab.

## App Structure

### Routing

`lib/router/app_router.dart` defines:

- public auth routes:
  `login`, `register`, `forgot-password`
- shell-based app routes under `/main/...`
- **5 shell branches**: `home`, `songs`, `bands`, `setlists`, `profile`
- **root-navigator pushed routes** (outside the shell, `parentNavigatorKey`):
  `metronome`, `tuner`, `practice`, `join-band` — pushed so system back always
  has a screen underneath (PRs #101/#104; the old hidden "Tools branch" made
  back exit the app)
- band sub-routes (resolved through `BandRouteResolver`):
  `band-songs`, `band-setlists`, `band-members`, `band-rehearsals` (+ `create-rehearsal`,
  `rehearsal-detail`, `edit-rehearsal`)

### Navigation (bottom-first, since the 2026-07 UX audit — PRs #104/#105)

There is **no top app bar anywhere**. The bottom bar owns navigation and has
exactly two states, decided by `MainShell`:

- **Root mode** (on a branch root): `[Home][Songs][Bands][Setlists][⋮ Menu]`.
  The Menu slot replaces the old Profile tab: it opens a bottom sheet
  (`showAppMenuSheet`, `lib/widgets/app_menu_sheet.dart`) with a mandatory
  screen-title header, the screen's contextual actions (`AppMenuItem`, with
  `trailing` toggle support for the tool menus), and a Profile row. A dot badge
  marks screens that have actions; the slot lights up while the profile branch
  is active.
- **Pushed mode** (any pushed screen, branch child or root-pushed tool):
  `[← Back] [screen title | primaryAction] [⋮ Menu]`
  (`AppBottomBar`, `lib/widgets/bottom_nav_or_action_bar.dart`). Back pops with
  a `/main/home` fallback. The title is the location signal; a screen can swap
  it for a primary action (SetlistView's "Open in Metronome").

Pushed-mode detection (`lib/router/branch_stack_observer.dart`): go_router's
`currentConfiguration.uri` **never updates for intra-branch pushes** (verified
on device), so per-branch `NavigatorObserver`s count `PageRoute` depth above
each branch root (PopupRoutes excluded so sheets/dialogs don't flip the bar),
OR'd with a non-root-URI check for deep entries. Notifier flushes are
post-frame — synchronous notification during navigation triggers
setState-during-build.

Screens publish their menu/title via `MenuScopePublisher` →
`MenuScopeRegistry` (`lib/widgets/menu_items_scope.dart`): post-frame writes
only, a location map for roots plus an identity-keyed publisher stack so
pushed mode surfaces the deepest screen's menu (and hides ⋮ when the pushed
screen has none). Registrations are removed by token identity — safe against
`indexedStack` dispose ordering.

Destructive actions use **single-level snackbar undo** (5s,
`showAppSnackBar(actionLabel:, onAction:, analyticsAction:)`) at
client-recoverable points: song-structure section delete, setlist delete,
song-removed-from-setlist, practice-song unload. Member removal keeps a
confirm dialog — membership is server-authoritative (Cloud Functions) and not
client-reversible.

### Setlist data model (never-drop, PR #105)

A setlist entry whose `songId` no longer resolves (deleted song, merge
artifact) is **still an entry**: counts use raw `effectiveItems.length`, the
editor and view render orphans as removable "Unavailable song" rows
(`lib/widgets/setlist_song_row.dart`), saves round-trip orphans unchanged, the
metronome queue plays the resolvable subset, and duplicate-merge rewrites
`items` (not just the legacy `songIds` mirror, which `toJson` regenerates from
`effectiveItems`). Orphan cleanup is manual-by-design. History: the pre-audit
editor silently deleted orphans on save.

### Analytics (HEART, PR #106)

`lib/services/analytics_service.dart`: new events flow through a single
consent-guarded `_log` choke point (`AnalyticsService.enabled`, driven by
`analyticsConsentProvider` — "Share usage analytics" switch in
Profile ▸ Account, default on). Event set per the audit's HEART section:
`back_used{ui|system}`, `menu_opened`, `undo_shown/undo_used`,
`filter_zero_results`, `search_song_open`, invite funnel
(`invite_generated`→`invite_link_opened`→`join_completed`→`band_opened`),
`tool_opened`, `practice_session`, `rehearsal_created`, `setlist_edited`.
Legacy static methods predate the choke point and are not consent-gated.

### State Management

The app uses Riverpod 3.x.

Key provider groups:

- `providers/auth/` - auth and error state
- `providers/data/` - repositories, metronome, song BPM
- `providers/sync/` - reconnect and write queue orchestration
- feature providers:
  `tuner_provider.dart`
  `song_autocomplete_provider.dart`
  `permissions_provider.dart`
  `wakelock_provider.dart`

Provider rules learned the hard way (#80):

- Per-band family stream providers (e.g. `bandSongsProvider`) are
  **autoDispose** so Firestore listeners close when unwatched.
- Never do a one-shot `ref.read(provider).value ?? []` on a stream provider —
  a cold provider is still `loading` and you silently get `[]`. Await
  `ref.read(provider.future)` instead.
- Awaiting `.future` of an **autoDispose** provider requires an active
  listener (`ref.watch` in the screen's build, or `ref.listenManual`),
  otherwise Riverpod disposes it mid-load: "Bad state: disposed during
  loading state".

### Data And Services

Primary service areas:

- Firebase/Firestore access
- audio engine and pitch detection
- CSV/PDF export (incl. per-song chords+lyrics performance sheet PDF)
- ChordPro lyrics+chords: parse/transpose, plus a **Song ⇄ ChordPro sync codec**
  (`utils/chordpro.dart`: `songToChordPro`/`chordProToSong`, `keyToScale`,
  `songMapSummary`) that treats the `Song` as source of truth and ChordPro as its
  readable text layer — standard directives for key/tempo/time, `x_flowgroove_*`
  for song map & original key, and unknown directives preserved on round-trip.
  Rendered by `widgets/chord_chart_view.dart`; paste-to-import supported.
  See `docs/CHORDPRO.md`.
- Song JSON import/export — versioned, documented format
  (`services/json/song_json_codec.dart`, schema in `docs/SONG_JSON_SCHEMA.md`); the
  import dialog auto-detects JSON vs CSV. This is the contract the AI/MCP layer writes against.
- connectivity and cache control
- matching/search utilities
- external API wrappers for Spotify and MusicBrainz

### Tool Architecture

#### Metronome

- provider-driven state
- custom time signatures and accent patterns
- transport and fine adjustment widgets
- audio engine prewarm on startup

#### Tuner

- generate and listen modes
- YIN pitch detection
- regional instruments and tuning presets from `assets/data/tunings.json`
- custom tuning editor
- stage mode overlay
- note scale ruler

#### Performance Sheet (songs)

- `Section.chordChart` holds ChordPro source (`[Am]Twinkle [F]star`); a song's
  sections form the sheet
- `screens/performance_sheet_screen.dart` — full-screen, keep-awake (reuses
  `wakelockProvider`), live ± semitone transpose, chords rendered over lyrics,
  plus hands-free **auto-scroll** (a `Ticker` nudges the `ScrollController`;
  play/pause, ± speed, and a Manual ⇄ BPM toggle that seeds speed from the
  passed tempo — a feel heuristic, no per-line bar timing)
- reachable directly from a saved song: a **Performance sheet** quick-action on
  each song row (`songs_list_screen.dart`, gated on `Song.hasSheetContent`) and
  a lyrics button in **concert mode** (`concert_mode_screen.dart`, opens the
  loaded `activeSong` seeded with the live metronome BPM)
- per-song PDF export at the current transpose (`services/export/pdf_service.dart`),
  with a header line for key + derived scale, tempo, time signature and song map
- per-song **ChordPro `.cho` export** (`services/export/chordpro_export.dart`:
  `shareSongChordPro` → `songToChordPro` + share_plus), from the sheet's AppBar
  when opened on a saved `Song`
- **CSV** carries chords too: `section_{n}_chart` column round-trips
  `Section.chordChart` (`services/csv/song_csv_schema.dart` `sectionFields`)
- paste ChordPro/lyrics → sections (`screens/songs/components/import_lyrics_dialog.dart`)
- **Song ⇄ ChordPro sync** (`utils/chordpro.dart`): `songToChordPro` assembles a
  canonical document (header directives + `x_flowgroove_song_map`/`_original_key`
  + labelled section blocks); `chordProToSong` reads it back onto a `Song`,
  preserving unrecognized directives. `keyToScale` derives the scale from the key
  string (no model field); `songMapSummary` collapses the section run for cards/PDF
- **Song editor** (`screens/songs/song_editor_screen.dart` +
  `chordpro_sync_controller.dart`): full-screen, live two-way sync between the
  visual song map and a ChordPro text area over one `sections` store. Map edits
  regenerate text instantly; text edits debounce then `reconcileSections` merges
  back (matched by order+name), preserving section id/bars/colour. Section extras
  ride in `{x_flowgroove_section: bars=N; color=RRGGBB}`. Opened from the
  Add/Edit-Song overflow menu.
- `widgets/song_card.dart` surfaces key + derived scale + section count (full map
  lives in the editor)
- directive conventions: `docs/CHORDPRO.md`

#### Rehearsal Planner (bands)

A per-band availability poll that grows into a confirmed rehearsal event — one
merged document lifecycle (`collecting → confirmed → done/cancelled`), not a
separate proposal-vs-event split.

- **Model** `models/rehearsal.dart`: `Rehearsal` (candidate slots, required/optional
  member uids, optional `setlistId`, free-text `location`, `status`,
  `confirmedSlotId`), `CandidateSlot`, and `RehearsalVote` (`answers` map
  slotId→`can|maybe|cant`). Same `@JsonSerializable` + `_sentinel` copyWith idiom as
  `Band`/`Setlist`.
- **Storage** `bands/{bandId}/rehearsals/{id}` mirrors band setlists; votes live in a
  `.../votes/{uid}` subcollection keyed by uid (one doc per member — makes the
  "member owns only their own vote" rule a one-liner).
- **Writes are client-side, rules-gated** (no CRUD callable):
  `repositories/firestore_rehearsal_repository.dart` behind `RehearsalRepository`,
  exposed via `bandRehearsalsProvider` / `rehearsalProvider` /
  `rehearsalVotesProvider` in `providers/data/data_providers.dart`.
- **Best-slot scoring** is a pure function (`utils/rehearsal_scoring.dart`): a required
  member's `cant` blocks a slot; otherwise required `can`+100 / `maybe`+40, optional
  `can`+10 / `maybe`+4. The organizer still confirms manually (suggestion, not
  automation). Unit-tested in `test/rehearsal_scoring_test.dart`.
- **UI** `screens/bands/rehearsals/` — list, edit (slots via native date/time pickers,
  Required→Optional member chips, setlist + location), and detail (per-slot voting,
  best-slot highlight, conflict + "waiting on" notices, organizer confirm, confirmed
  card with the attached setlist's songs). Entry point is a tool button on the band
  dashboard (`the_band_screen.dart`).
- **Calendar export** `utils/ics_export.dart` — a hand-rolled `.ics` (VEVENT) shared
  via `share_plus`; no calendar dependency, no two-way sync in V1.
- **Notifications** are Telegram-only, via the `onRehearsalCreated` /
  `onRehearsalUpdated` triggers (§4); there is no in-app notification center.

## Deployment Topology

### GitHub Pages Preview

Safe dual deploy:

```bash
make -f Makefile.hugo deploy-all
```

Result:

- `docs/` root -> Hugo landing page
- `docs/app/` -> Flutter web app

### Flutter-Only GitHub Pages Publish

```bash
make deploy-test
```

This is intentionally Flutter-only and overwrites `docs/` root output. It should not be treated as the default preview path.

### Production FTP

```bash
make deploy-stable
```

Result:

- `site/public/` -> `flowgroove.app/`
- `build/web/` -> `flowgroove.app/app/`

## Operational Notes

### Generated And Historical Areas

- `docs/` mixes generated site output and human-written reports
- `oldarchive/` contains archived Qwen context, exports, legacy scripts, local state, and historical snapshots
- `oldarchive/**` is excluded from analyzer scope so archived code does not pollute live repo checks
- `screenshots/` remains a documentation-support asset directory used by current reports

### Validation Snapshot

As of April 24, 2026:

- scoped config tests pass
- repo-wide security audit fails
- repo-wide analyzer output is dominated by lint backlog
- the April 24 audit captured explicit hard analyzer errors from the pre-archive `backup/config-modernization-2026-04-02/` snapshot

See `docs/project-audit-2026-04-24.md` for the full audit.
