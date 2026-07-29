# Session report — 2026-07-16 → 2026-07-17 (the marathon)

One continuous working session from "check what we didn't finish on the worktree"
to shipping **0.17.1+338** on every channel. This is the trace document: what
shipped, what broke, why, and where to look if something surfaces later.

## Releases

| Version | What |
|---|---|
| 0.16.0+336 | UX-audit stack (#101–#106, docs #120), setlist card parity (#130), global Settings (#131), Song Lab discoverability (#140), practice dashboard (#134) |
| 0.17.0+337 | Light theme (#132/#148), Recorder + Audio note (#145/#146), cluster merge (#143), two-deck song cards (#144), Song Lab audio + menu fix (#147), Event Kit, canonical browse, scheduler |
| 0.17.1+338 | Hotfix: cyan tonal buttons, wrapping quick-start labels, release-all Pages leg (#149) |

## Issues closed (this session)

#51 #56 #57 #58 #59 #65 #66–#70 #69 #72 #73 #74 #81 #86 #97 #98 #99→skipped(open) #129 #132 #133(#134) #145 #149 — plus the earlier sweeps that took the board 68 → 12.
Left open: #42/#48/#49/#50 (Play, user org account), #77 (one user step: OAuth provider account — runbook `mcp/REMOTE_SETUP.md`), #99 (logo redesign, deliberately skipped).

## Architecture decisions (load-bearing, know these)

- **Ideas inbox = virtual Firestore parent**: unlinked recordings live at
  `users/{uid}/songs/_inbox/labEntries/{id}`. The `_inbox` parent doc is never
  created → invisible to library queries; existing rules wildcards cover it.
  Zero rules changes. Linking rewrites the entry under the target song with the
  SAME id (Storage object name still matches; audio object itself stays under
  `_inbox` — move only if it ever matters). `lib/services/idea_recorder.dart`.
- **One capture path**: Home Audio note, Practice, Recorder screen and Song
  Lab's + Record chip all go through `captureIdea()` → `LabRecordingSheet`
  (`autoStart` supported) → `StorageService.uploadLabAudio` → `SongLabEntry`.
- **MonoPulsePalette ThemeExtension** (#132): 14 theme-dependent neutrals,
  read via `context.mp`; brand/beat/status/section colors stay const on
  `MonoPulseColors`. Both themes come from ONE parameterized builder
  (`MonoPulseTheme._build`); the shared ColorScheme is exposed as
  `schemeFor()` for tests. 531 call sites migrated (codex CLI, 4 verified
  batches). Deliberately NOT migrated: ErrorWidget fallback (no Theme on
  crash), ink-on-colored-pill contrast helpers (`section.dart`,
  song_constructor `app_colors.dart`).
- **Menu registry keys = `matchedLocation`** (not `uri`): a branch root first
  mounted under a child route registers its own path regardless of what's on
  top. `lib/widgets/menu_items_scope.dart`.
- **Codex CLI delegation**: bulk mechanical sweeps run via
  `codex exec --full-auto` in sequential per-directory batches; Claude
  architects, verifies each batch (grep-to-zero, analyzer severity, area
  tests), commits. Worked well; codex correctly refused one theme-invariant
  file.

## Incidents — root causes and fix locations

| Symptom | Root cause | Fix |
|---|---|---|
| GitHub Pages blank | Pages source was `beta` branch AND bare .gitignore rules swallowed docs/ JS | Pages source → second01/docs (`gh api`); `!docs/...` negations in .gitignore |
| Songs ⋮ menu only Profile/Settings | Branch root first mounted under a child captured the child's `uri` as its registry key (capture-once) | key by `matchedLocation` (menu_items_scope.dart) + regression test in songs_list_screen_test |
| Cyan tonal buttons (0.17.0) | `ColorScheme.dark().copyWith(secondary: x)` bakes the BASE scheme's getter fallback (legacy teal #03DAC6) into `secondaryContainer` — Flutter color_scheme.dart:1099 | pin secondaryContainer/tertiaryContainer (+on*) in `schemeFor`; test `test/theme/mono_pulse_scheme_test.dart` |
| release-all "Pages deployed" but stale | `Makefile.hugo deploy-all` writes `docs/app/` which is gitignored → commit contained 1 file; layout also conflicts with deploy-test | #149: non-interactive `deploy-pages` target; release-all uses it; deploy-test = confirm wrapper |
| First 0.17.1 release aborted at test-fast | New theme test built full ThemeData → GoogleFonts runtime fetch throws in test zone (flaky) | test targets extracted `schemeFor()`; no fonts involved. The abort itself = release guard working |
| APK "signatures do not match" on install | debug-signed preview vs release-signed installed app | build `--release` for device installs |
| Xcode "No Accounts" / iOS build broke | disk 100% full (155MB free) | freed ~7GB (DerivedData, pod caches); pod repo update |
| Quick-start labels wrapped | third button label grew ("Idea"→"Recorder") | FittedBox scaleDown, one line (practice_screen.dart `_quickStartButton`) |
| MCP setup doc vanished | it lived in `docs/` — which is the Pages web bundle and gets wiped by every Pages deploy | restored from git (dd895d2e) to `mcp/REMOTE_SETUP.md`; rule: docs/ is NOT a documentation directory |

## If X breaks, look at Y

- **Recordings missing / not linking** → `idea_recorder.dart` (inbox id `_inbox`), `firestore_lab_repository.dart` paths, Storage rules `lab_audio/…`.
- **Wrong colors anywhere** → `MonoPulseTheme.schemeFor` + `MonoPulsePalette` in `mono_pulse_theme.dart`; run `test/theme/mono_pulse_scheme_test.dart`. New widgets must use `context.mp.*` for neutrals.
- **Bottom-bar menus wrong/empty** → `MenuScopeRegistry` in `menu_items_scope.dart`; keys are matchedLocation; regression test in songs_list_screen_test.
- **A release channel stale** → `Makefile`: `release-all` = test-fast → bump → deploy-rules → deploy-stable (Hugo FTP + app hosting) → deploy-pages → release. Verify per-channel with `version.json` (app.flowgroove.app, github.io) — the banner alone is not proof (#149 lesson).
- **Pages blank again** → check Pages source branch (`gh api .../pages`) and .gitignore negations before anything else.

## Branch cleanup (this session's end)

Remote reduced to `main` + `second01`. Deleted: `beta` (defunct Pages-source
web-build branch — tagged `archive/beta-pages-source` first), `feat/68`,
`feat/69`, `feat/70` (merged). Local stale branches (backup/*, dev0*, old
feat/*) deleted where merged; unmerged relics listed by `git branch --no-merged second01`.

## Still open / user-gated

1. **Play launch**: org account (#50) → screenshots → console forms (playstore/PLAY_APP_CONTENT.md, LISTING.md, creds in `.env.play-reviewer` — never commit) → close #42/#48/#49/#50.
2. **#77**: user creates OAuth provider (WorkOS recommended) per `mcp/REMOTE_SETUP.md` → env vars → `firebase deploy --only functions:mcpRemote` → connect in claude.ai (Pro).
3. **#99**: simplified logo mark for flowgroove.app nav/footer (design task, FTP now unfrozen).
4. Console-side polish (no issue): Google brand review, email-template action URL.
