# FlowGroove Architecture

**Last Updated:** June 16, 2026  
**Version:** 0.14.0+203

## Overview

This repository contains five meaningful systems:

1. Flutter application
2. Hugo marketing site
3. Telegram support bot
4. Firebase Functions workspace
5. Imported AI workspace context (`memory/`, `.codex/`)

The operational product is split across the Flutter app and the Hugo site. The other areas support deployment, support operations, and continuity.

## Top-Level Layout

```text
flutter_repsync_app/
├── lib/                # Flutter app source
├── test/               # Flutter tests
├── site/               # Hugo source
├── docs/               # GitHub Pages output + reports
├── telegram_bot/       # Telegram support bot
├── functions/          # Firebase Functions
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
- Profile
- Metronome
- Tuner

### 2. Hugo Site

Marketing-site source lives in `site/`.

#### Purpose

- landing page
- FAQ, about, privacy, terms
- blog and SEO content
- GitHub Pages preview root
- production root site for FTP deployment

#### Important Output Paths

- GitHub Pages preview root: `docs/`
- production FTP root: `site/public/` mirrored to `flowgroove.app/`

### 3. Telegram Bot

The Telegram support bot lives in `telegram_bot/`.

#### Purpose

- link Telegram users to FlowGroove accounts
- create support topics
- support admin reply workflow

This subsystem is documented separately in `telegram_bot/README.md` and was not runtime-validated in this audit pass.

### 4. Firebase Functions

Cloud function code lives in `functions/`.

The directory is present and versioned, but it was not deeply validated during this pass.

### 5. AI Workspace Context

The repo keeps a protected memory bank and a normalized Codex control plane:

- `memory/` - protected root memory bank
- `.codex/` - preferred active structure for agents, rules, tasks, sessions, and durable workflow state
- `oldarchive/` - archived Qwen source context and related historical outputs

This context is operational documentation, not app runtime code.

## App Structure

### Routing

`lib/router/app_router.dart` defines:

- public auth routes:
  `login`, `register`, `forgot-password`
- shell-based app routes under `/main/...`
- branches for:
  `home`, `songs`, `bands`, `setlists`, `profile`, `metronome`, `tuner`

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

### Data And Services

Primary service areas:

- Firebase/Firestore access
- audio engine and pitch detection
- CSV/PDF export
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
