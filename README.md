# FlowGroove

[![Flutter](https://img.shields.io/badge/Flutter-ready-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.14.0+203-brightgreen.svg)](https://github.com/berlogabob/flutter-FlowGroove-app/releases)
[![Live App](https://img.shields.io/badge/Live%20App-flowgroove.app-blue)](https://flowgroove.app)

FlowGroove is a real-time repertoire and setlist manager for cover bands and gigging musicians. It gives the band one source of truth for songs, setlists, notes, keys, BPM, and rehearsal-ready tools, with instant sync and offline support.

Try it live: [https://flowgroove.app](https://flowgroove.app)

This repository also contains the Hugo marketing site, Firebase functions (including the single Telegram bot, `@flowgroovebot`), the active `.codex/` internal workspace, and an `oldarchive/` area for legacy materials.

## Quick Start

### Use The Live App

1. Open [flowgroove.app](https://flowgroove.app)
2. Sign up with Google or email
3. Create a band and add your first song
4. Invite bandmates; updates sync automatically

### GitHub Pages Preview: Safe Dual Deploy

This is the safe path for previewing the Hugo site and Flutter app together:

```bash
make -f Makefile.hugo deploy-all
```

URLs:

- Landing page: `https://berlogabob.github.io/flutter-FlowGroove-app/`
- Flutter app: `https://berlogabob.github.io/flutter-FlowGroove-app/app/`

### Flutter-Only GitHub Pages Publish

This path publishes only the Flutter app and overwrites `docs/` root output:

```bash
make deploy-test
```

Use it only when you intentionally want a Flutter-only publish.

### Android Release

```bash
make release
```

Builds APK + AAB, tags the current version, and attempts to create a GitHub Release.

### Production FTP Deploy

1. Prepare local non-tracked env sources:

```bash
cp .env.example .env
cp .ftp-env.example .ftp-env  # optional FTP-only override
```

2. Replace all `REPLACE_ME_*` placeholders with real local values.
3. Run the production deploy:

```bash
make deploy-stable
```

`make deploy-stable` runs a preflight gate before any backup or upload. It validates local env files, blocks tracked `web/config.js`, and refuses deploys when secret-bearing archive/backup paths are staged.

Deploy target:

- Hugo to `https://flowgroove.app/`
- Flutter web to `https://flowgroove.app/app/`

## Features

### Core App

- Shared song library with metadata, links, unique IDs, and structure editing
- Tagging, filter/sort, and duplicate detection with field-by-field cluster merge
- Lyrics + chords performance sheet (ChordPro): keep-awake stage view, live transpose, per-song PDF via the standard 3-dot menu (As is, or Compact — fit one A4 page; key/scale · tempo · time · song-map header), paste-to-import, and a Song ⇄ ChordPro sync codec that round-trips a full chart without losing unknown directives
- Band management with membership and invite/join flows
- Rehearsal Planner: propose times, poll member availability (can/maybe/can't), auto-suggest the best slot around required/optional members, confirm with an attached setlist, and export to calendar (.ics)
- Drag-and-drop setlists with per-gig overrides for key, BPM, notes, and order
- Offline-first data flow with Hive-backed local caching
- Firebase Auth, Firestore, and Storage integration
- In-app account deletion (Google Play compliant), removing all associated data
- CSV and FlowGroove Song JSON import/export (documented, AI-ready schema; paste auto-detects format) plus PDF export
- Search-to-autofill from MusicBrainz (type the artist too to rank the right recording first), enriched with tempo/key from Deezer and lyrics from lyrics.ovh (split into Verse/Chorus sections); accepting a match drops in tappable provenance links (MusicBrainz, Spotify, YouTube, chords, lyrics); your own library is excluded from suggestions
- Bring-your-own-AI: copy a prompt for ChatGPT/Claude/Gemini, or connect an agent via MCP — a one-click remote OAuth connector (spike) or a per-user API key + local server — FlowGroove pays no AI tokens
- Responsive desktop/mobile layout

### Music Tools

- Metronome with custom time signatures, accent patterns, presets, and transport controls
- Tuner with generate/listen modes and YIN-based pitch detection
- Regional instruments and multiple tunings
- Custom in-session tuning editor
- Auto/manual note detection
- Stage mode overlay
- Haptic feedback and A4 calibration
- Wakelock during tool usage

### Access And Workflow

- Demo account quick login
- Demo mode banner and read-only behavior
- Role-aware permission helpers
- Song autocomplete and BPM lookup provider layer
- Telegram bot (`@flowgroovebot`) served by the `telegramWebhook` function in `functions/src/telegram/` — handles account linking and support DMs

## Tech Stack

- Flutter web with Android/iOS-ready build paths
- Firebase Auth, Firestore, Storage, and Functions
- Hive offline storage
- Riverpod state management
- go_router navigation
- PDF and printing support
- Audio player, metronome, and tuner tooling

## Repository Layout

### Main Areas

- `lib/` - Flutter application code
- `test/` - Flutter test suite
- `site/` - Hugo landing page source
- `docs/` - generated GitHub Pages output plus project reports
- `functions/` - Firebase Functions source (includes the Telegram bot in `functions/src/telegram/`)
- `.codex/` - active internal workspace for agents, rules, memory, tasks, and session control
- `memory/` - protected project memory bank retained at the repo root
- `oldarchive/` - archived Qwen context, exports, reports, snapshots, and legacy support files

### Current File Counts

- `lib/`: 240 Dart files
- `test/`: 97 Dart test files
- `site/`: 247 files
- `docs/`: 127 files

## Common Commands

| Command | Purpose | Notes |
|---|---|---|
| `make -f Makefile.hugo serve` | Run Hugo locally | Local landing-page development |
| `make -f Makefile.hugo deploy-all` | GitHub Pages dual deploy | Safe preview path |
| `make deploy-test` | Flutter-only GitHub Pages publish | Overwrites `docs/` root |
| `make deploy-stable` | Production FTP deploy | Hugo root + Flutter `/app/` |
| `make build-android` | Build APK | Demo config by default |
| `make release` | Build APK + AAB + release flow | Uses current git branch/tag |
| `flutter test` | Run the full Flutter suite | Not run in full during this audit pass |
| `bash test/security/git_audit_test.sh` | Security audit | Passes with warnings; history still needs periodic review |

## Documentation

### Core Docs

- [README.md](README.md)
- [ARCHITECTURE.md](ARCHITECTURE.md)
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
- [docs/README.md](docs/README.md)
- [CHANGELOG.md](CHANGELOG.md)

### User Guides (Wiki)

The in-app help panel and the public wiki share one source: [`site/content/wiki/`](site/content/wiki/). Edit those `.md` files to update both.

### Supporting Docs

- [site/README.md](site/README.md)
- [functions/src/telegram/README.md](functions/src/telegram/README.md)
- [memory/README.md](memory/README.md)
- [memory/CRITICAL_PROBLEMS.md](memory/CRITICAL_PROBLEMS.md)
- [.codex/README.md](.codex/README.md)

### Existing Reports

- [docs/fix-verification-report.md](docs/fix-verification-report.md)
- [docs/performance-fixes-summary.md](docs/performance-fixes-summary.md)
- [docs/tuner-debug-report.md](docs/tuner-debug-report.md)
- [docs/tuner-testing-summary.md](docs/tuner-testing-summary.md)
- [docs/tuner-ux-enhancement-summary.md](docs/tuner-ux-enhancement-summary.md)

## Roadmap

- Spotify integration for automatic BPM and key lookup
- Smart song auto-fill
- Premium features
- Native app store releases
- Gig calendar integration

## Validation Snapshot

Historical audit snapshot before the April 24, 2026 FTP hardening pass:

- `flutter test test/config/`: 62 passed
- `bash test/security/git_audit_test.sh`: failed at that time on tracked `web/config.js`
- `flutter analyze`: 4411 issues across the whole repo before archival cleanup
- `flutter analyze lib test`: 3996 issues across live app/test code, dominated by lint backlog

See the dated audit report for details and prioritized findings. Legacy archived material now lives under `oldarchive/` and is excluded from analyzer scope.

## Security Notes

- Firebase configuration is runtime-injected for web and passed via compile-time defines for non-web builds
- Web runtime config is public-only: generated `web/config.js` should contain only `FIREBASE_API_KEY` and optional proxy URLs
- Spotify web access must go through `SPOTIFY_PROXY_URL`; direct client-credential mode is intentionally disabled on web
- Client-side Telegram Bot API methods are disabled; privileged Telegram actions belong in `functions/` or other backend paths
- Non-web builds no longer read `assets/env.json`; use compile-time `--dart-define` inputs instead
- Client-side RapidAPI track analysis is disabled until it moves behind a backend proxy
- `web/config.js` is a generated artifact and should stay untracked
- Demo Firebase keys are present in tracked demo config files
- Android/AAB build targets source demo or local `.env` values through [scripts/build-mobile-with-env.sh](scripts/build-mobile-with-env.sh)
- If FTP credentials were ever stored in tracked files, rotate them before the next real production deploy

## Support Development

FlowGroove is in active development. If the app saves your band time, you can support continued work through Ko-fi:

[Buy Me a Coffee on Ko-fi](https://ko-fi.com/flowgrooveapp)

## License

MIT License. See [LICENSE](LICENSE).

## Status

- Version: `0.14.0+203`
- Last updated: June 16, 2026
- Current project state: active development with `.codex/` as the canonical internal layer and `oldarchive/` for legacy context
