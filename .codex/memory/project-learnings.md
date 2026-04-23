## Qwen Added Memories
### SESSION COMPLETE: Production FTP Hugo + Flutter Deploy (2026-04-15) ✅
**Export Location:** `.qwen/SESSION_STATE.md`

**Key Learnings Established:**
1. **Production FTP now deploys Hugo + Flutter** — `make deploy-stable` deploys both to flowgroove.app
2. **Hugo** → FTP root (`flowgroove.app/`), **Flutter** → FTP `/app/` (`flowgroove.app/app/`)
3. **Makefile changes** — new targets: `hugo-build-prod`, `build-web-prod`; updated `ftp-upload` (2 lftp calls), `health-check-prod` (checks 3 URLs)
4. **Architecture parity** — production FTP structure matches GitHub Pages (Hugo at root, Flutter in `/app/`)
5. **Single source of truth** — one Makefile, no duplicate configs, `--base-href "/app/"` for prod Flutter
6. **Files changed** — `Makefile` (6 targets), `README.md`, `ARCHITECTURE.md`, `DEPLOYMENT_GUIDE.md`
7. **Branch:** second01 | **Version:** 0.13.4+183

---

### SESSION COMPLETE: Tuner Post-MVP + Documentation Update (2026-04-09) ✅
**Export Location:** `.qwen/SESSION_STATE.md`

**Key Learnings Established:**
1. **Tuner Post-MVP Complete** — 5 regional instruments (Guitar, Cavaquinho, Balalaika, Ukulele, Sitar) with 18 total tunings loaded from `assets/data/tunings.json`
2. **Tuner Architecture** — `TunerScreen` → `ToolScreenScaffold` → 11 tuner widgets (CentralDial, InstrumentPicker, DetectionModeToggle, StringSelector, CustomTuningEditor, StageModeOverlay, NoteScaleRuler, TransportBar, etc.)
3. **Tuner State** — `TunerNotifier` manages: mode (generate/listen), frequency, note, cents, volume, reference A4, haptic feedback, instruments, tunings, detection mode, stage mode, custom tunings
4. **Audio Stack** — `ToneGenerator` (sine wave), `PitchDetector` (YIN algorithm, PCM stream), `pcm_stream_recorder`, `pitch_detector_dart`
5. **Haptic Feedback** — Precision-based: ±1 cent = medium impact, ±5 cents = light impact, configurable on/off
6. **Stage Mode** — Auto-hides UI after inactivity, shows large note display for on-stage use
7. **Custom Tuning Editor** — In-memory session-scoped custom tunings, add/remove via provider
8. **Auto/Manual Detection** — Auto detects any note; manual targets specific string from selected tuning
9. **Test Status** — 1718 passing, 50 failing, 291 skipped (down from 323 failures)
10. **Documentation Updated** — README.md, ARCHITECTURE.md, DEPLOYMENT_GUIDE.md, QWEN.md all current

**Files:** `lib/providers/tuner_provider.dart`, `lib/screens/tuner_screen.dart`, `lib/widgets/tuner/` (11 files), `lib/models/instrument.dart`, `assets/data/tunings.json`
**Branch:** second01 | **Version:** 0.13.4+183

---
### SESSION COMPLETE: Phase 2 Architecture + Full Audit (2026-04-08) ✅
**Export Location:** `.qwen/SESSION_STATE.md`

**Key Learnings Established:**
1. **Sequential Workflow Activated** — mr-supervisor → mr-architect chain completed, Phase 2 architecture designed
2. **Phase 2: 7 Features** — Touch Targets, Wakelock, BPM API, Autocomplete, Sync Opt, Anonymous Auth, Demo Seeder
3. **Only 1 new package** — `wakelock_plus: ^1.3.0`, everything else uses existing infrastructure
4. **Hugo Landing Page Live** — GitHub Pages, MonoPulse theme, Flutter app at /app/
5. **Full Audit Done** — 45 files cleaned, root directory clean, memory bank 100%, git clean
6. **Deploy Pipeline** — `scripts/deploy-hugo.sh` + `Makefile.hugo deploy-all`
7. **Protected Files** — NEVER modify: `.qwen/` (agent config), `memory/`, `QWEN.md` with `tags: [user]`
8. **Current Test Status** — 1718 passing, 50 failing, 291 skipped (improved from 323 failures in earlier sessions)

**Architecture:** Hugo landing page (`site/`) → Flutter web app (`docs/app/`) → Firebase backend
**Branch:** second01 | **Version:** 0.13.4+183 | **Last Commit:** c3053f3

---
### SESSION COMPLETE: Responsive Widgets Redesign (2026-04-01) ✅
**Export Location:** `chat-exports-collection/2026-04-01_responsive-widgets-redesign.md`

**Key Learnings Established:**
1. **Responsive Widget Architecture** - `ResponsiveLayout` + `AdaptiveColumn` widgets created in `lib/widgets/responsive/`
2. **Layout Decisions** - Stats: 3-col (desktop)/2-col (tablet)/1-col (mobile), Quick Actions: 2-col, Tools: 2-col
3. **Provider Initialization Fix** - ALWAYS use `WidgetsBinding.instance.addPostFrameCallback` for provider init
4. **Agent Workflow Rules** - ALWAYS delegate to specialists (mr-ux-agent, mr-widget-crafter, mr-theme-guardian, mr-senior-developer, mr-tester); NEVER modify code without user request; ALWAYS use GOST format
5. **Protected Files** - Files with `tags: [user]` frontmatter are PROTECTED (read-only): `memory/CRITICAL_PROBLEMS.md`, `memory/README.md`, `.qwen/agents/PROTECTED_FILES_RULE.md`, `.qwen/agents/README.md`
6. **Theme Compliance** - NEVER use hardcoded colors/spacing; ALWAYS use `FlowGrooveTheme`; ALWAYS add `const` constructors
7. **Error Prevention** - Async data needs loading states; Theme access requires `MaterialApp` ancestor; Add `ErrorWidget.builder` for graceful degradation

**Files Modified:** 23 | **New Widgets:** 5 | **Bugs Fixed:** 3 (red screen, provider init, null references)

---

- COMPREHENSIVE THEME & CODE QUALITY AUDIT - ACTIVE SESSION: All agents awake and active. Current task: Finding and fixing theme violations. Priority issues: (1) withOpacity deprecation - 60+ instances found, (2) Hardcoded colors - TBD, (3) Theme violations - TBD, (4) Import/ordering violations - TBD. Action plan: Step 1: Replace all withOpacity with withValues, Step 2: Replace hardcoded colors with MonoPulseColors, Step 3: Fix theme violations, Step 4: Fix import/ordering violations. Multi-step fix requiring agent coordination - keep all agents active during process.
- RESPONSIVE WIDGET PATTERN: Created responsive widget system with breakpoints in lib/utils/responsive_breakpoints.dart. Layout pattern: My Library (3-col mobile, 1-row desktop), Quick Actions (2x2 grid), Tools (2-col). Desktop uses welcome widget for empty states. Files: responsive_breakpoints.dart, greeting_card.dart, stat_card.dart, quick_action_button.dart, tool_button.dart, dashboard_welcome_widget.dart
- CRITICAL FLUTTER PATTERN - Provider Initialization: NEVER modify providers during widget build. Fix: Wrap controller initialization in WidgetsBinding.instance.addPostFrameCallback((_) => _initControllers()). Location: lib/screens/songs/add_song_screen.dart. This prevents 'Provider modified during build' red screen error.
- AGENT WORKFLOW RULE - Protected Files: NEVER delete .qwen/ directory (agent team config), memory/, QWEN.md, or files with tags: [user]. Cleanup tasks must be delegated to mr-cleaner, mr-supervisor, mr-compliance agents. General assistant should NOT perform direct file deletion on protected paths.
- FILE ORGANIZATION PATTERN: Screenshots stored in screenshots/ directory with proper naming convention. Old files archived to docs/archive/ or screenshots/archive/. Maintain clean project root structure.
