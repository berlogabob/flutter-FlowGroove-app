## Qwen Added Memories
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
