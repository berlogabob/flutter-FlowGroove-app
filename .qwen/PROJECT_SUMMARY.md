# Project Summary - FlowGroove

## Project Overview
**Name:** FlowGroove  
**Description:** Band repertoire management for cover bands  
**Current Version: 0.13.4+179
**Website:** https://flowgroove.app  
**Repository:** flutter_repsync_app (legacy name retained for package compatibility)  

## Technology Stack
- **Framework:** Flutter 3.41.1 (Dart 3.11.0+)
- **State Management:** Riverpod ^3.3.1
- **Backend:** Firebase (Firestore, Auth, Storage, Analytics)
- **Local Storage:** Hive, SharedPreferences, flutter_secure_storage
- **Platform:** iOS, Android, Web

## Current Development Focus (2026-04-01)
### Active Session: Responsive Widgets Redesign ✅ COMPLETE
**Date:** 2026-04-01  
**Status:** Session complete, export created  

**Key Achievements:**
1. **Responsive Widget Architecture** - Created `ResponsiveLayout` + `AdaptiveColumn` widgets
2. **Layout System** - Implemented responsive breakpoints for mobile/tablet/desktop
3. **Theme Compliance** - Enforced FlowGrooveTheme usage, eliminated hardcoded colors
4. **Provider Initialization Fix** - Established pattern using `addPostFrameCallback`
5. **Agent Workflow** - 10 specialized agents working in parallel

**Files Modified:** 23  
**New Widgets:** 5  
**Bugs Fixed:** 3 (red screen, provider init, null references)

**Export Location:** `chat-exports-collection/2026-04-01_responsive-widgets-redesign.md`

## Architecture

### Core Features
- **Song Management:** CRUD operations, setlist organization
- **Repertoire Library:** Categorized songs with metadata
- **Performance Tools:** Chord charts, lyrics, annotations
- **Collaboration:** Band member access, sharing
- **Responsive UI:** Adaptive layouts for all screen sizes

### Widget Architecture (Responsive)
```
lib/widgets/responsive/
├── responsive_breakpoints.dart    # Breakpoint definitions
├── greeting_card.dart             # Responsive greeting widget
├── stat_card.dart                 # Stats display (3/2/1 col)
├── quick_action_button.dart       # Quick actions (2-col grid)
├── tool_button.dart               # Tools (2-col layout)
└── dashboard_welcome_widget.dart  # Desktop welcome state
```

### State Management
- **Riverpod** for global state
- **Providers** properly initialized with `addPostFrameCallback`
- **ChangeNotifier** for legacy compatibility

## Code Quality Standards

### Theme Compliance (ENFORCED)
- ✅ ALWAYS use `FlowGrooveTheme.colors` (MonoPulseColors)
- ✅ ALWAYS use `FlowGrooveTheme.spacing`
- ✅ NEVER use hardcoded colors or spacing values
- ✅ ALWAYS add `const` constructors where possible

### Protected Files (READ-ONLY)
Files with `tags: [user]` frontmatter are PROTECTED:
- `memory/CRITICAL_PROBLEMS.md`
- `memory/README.md`
- `.qwen/agents/PROTECTED_FILES_RULE.md`
- `.qwen/agents/README.md`
- `.qwen/agents/` directory (agent configuration)
- `memory/` directory (user memory)

### Agent Workflow Rules
1. **ALWAYS** delegate to specialist agents (mr-ux-agent, mr-widget-crafter, mr-theme-guardian, mr-senior-developer, mr-tester)
2. **NEVER** modify code without user request
3. **ALWAYS** use GOST format for outputs
4. **NEVER** delete protected files

## Development Patterns

### Provider Initialization (CRITICAL)
```dart
// NEVER modify providers during widget build
// ALWAYS use:
WidgetsBinding.instance.addPostFrameCallback((_) => _initControllers());
```
**Location:** `lib/screens/songs/add_song_screen.dart`  
**Prevents:** 'Provider modified during build' red screen error

### Responsive Layout Pattern
```dart
// Stats: 3-col (desktop) / 2-col (tablet) / 1-col (mobile)
// Quick Actions: 2-col grid
// Tools: 2-col layout
// Desktop uses welcome widget for empty states
```

### Error Prevention
- Async data needs loading states
- Theme access requires `MaterialApp` ancestor
- Add `ErrorWidget.builder` for graceful degradation

## Current Branch Strategy
- `main` - Production release
- `dev` - Active development
- Feature branches - Temporary feature work

## Quality Gates
- [x] Theme compliance ≥95%
- [x] Test coverage ≥80% (for new logic)
- [x] Architecture compliance (validated by mr-architect)
- [x] Code review completed (mr-senior-developer)
- [x] Documentation updated

## Recent Sessions
| Date | Session | Status | Export |
|------|---------|--------|--------|
| 2026-04-01 | Responsive Widgets Redesign | ✅ Complete | `chat-exports-collection/2026-04-01_responsive-widgets-redesign.md` |
| 2026-02-21 | Metronome Development | 📜 Archived | `docs/archive/project-summary-2026-02-21-stale-session.md` |

## Known Issues & Resolutions
| Issue | Status | Resolution |
|-------|--------|------------|
| Provider initialization during build | ✅ Fixed | Use `addPostFrameCallback` |
| Red screen errors | ✅ Fixed | Proper async loading states |
| Theme violations (hardcoded colors) | ✅ Fixed | Enforced FlowGrooveTheme usage |
| withOpacity deprecation | 🔄 In Progress | Replacing with `withValues` |

## Next Steps
1. Continue theme compliance audit (replace `withOpacity` → `withValues`)
2. Eliminate remaining hardcoded colors
3. Fix import/ordering violations
4. Maintain responsive widget patterns
5. Keep agent workflow active for quality assurance

---

## Session Metadata
**Last Updated: 2026-04-01
**Session Type:** Responsive Widgets Redesign  
**Project Phase:** Active Development (FlowGroove)  
**Previous Session:** Archived to `docs/archive/`  
