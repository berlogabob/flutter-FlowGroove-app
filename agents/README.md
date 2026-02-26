# Agent System for RepSync

Autonomous AI agents that drive development, testing, and release of the RepSync Flutter app.

## Hierarchy
```
mr-sync (Coordinator)
├── mr-planner (Task decomposition)
│   ├── mr-architect (Design validation)
│   └── creative-director (UX flow)
├── mr-senior-developer (Code review)
├── mr-cleaner (Refactor & optimization)
├── mr-tester (Testing)
├── mr-logger (Logging)
├── mr-ux-agent (UI implementation)
├── mr-android (Mobile debug)
└── mr-release (Release orchestration)
```

## Usage
1. **Request work**: `@agent mr-planner Design song structure editor`
2. **Agents collaborate**: Each produces GOST-formatted output
3. **Coordinator merges**: `mr-sync` ensures no conflicts
4. **Verify**: All changes tested before merge

## Rules
- ✅ All agents follow **GOST format** (Guided Output Structure Template)
- ✅ No direct code modification — only recommendations
- ✅ Critical issues block releases
- ✅ Versioning: `MAJOR.MINOR.PATCH+BUILD` (build auto-increments)

## Guidelines
- **Modularity**: Extract if used ≥3 times
- **Consistency**: Theme colors, spacing, component patterns enforced
- **Fail-Safe**: All features must work offline first

> Built with ❤️ for musicians and cover bands