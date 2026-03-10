# Agent System for RepSync

Autonomous AI agents that drive development, testing, and release of the RepSync Flutter app.

## Hierarchy
```
mr-sync (Coordinator)
├── mr-planner (Task decomposition)
│   ├── mr-architect (Design validation)
│   ├── creative-director (UX flow)
│   ├── mr-theme-guardian (Theme enforcement) ⭐ NEW
│   ├── mr-optimization (Performance) ⭐ NEW
│   └── mr-widget-crafter (Widget extraction) ⭐ NEW
├── mr-senior-developer (Code review)
├── mr-cleaner (Refactor & optimization)
├── mr-tester (Testing)
├── mr-logger (Logging)
├── mr-ux-agent (UI implementation)
├── mr-android (Mobile debug)
└── mr-release (Release orchestration)
```

## Agent Roles

### Coordination & Planning
- **mr-sync**: Overall coordination, conflict resolution
- **mr-planner**: Task decomposition, sprint planning
- **mr-architect**: Architecture design, pattern validation

### Quality & Enforcement
- **mr-theme-guardian** ⭐: Design system enforcement, theme compliance (95%+)
- **mr-optimization** ⭐: Performance optimization, const constructors, caching
- **mr-widget-crafter** ⭐: Widget extraction, DRY principle enforcement
- **mr-cleaner**: Code quality, formatting, dead code removal
- **mr-senior-developer**: Code review, best practices

### Implementation & Testing
- **creative-director**: UX patterns, user journey design
- **mr-ux-agent**: UI implementation
- **mr-tester**: Test creation, coverage
- **mr-android**: Android-specific issues
- **mr-logger**: Documentation, knowledge base

### Release
- **mr-release**: Release orchestration, versioning

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
- ✅ **NEW**: Theme violations block merges (>5% non-compliance)
- ✅ **NEW**: Performance regressions must be documented

## Guidelines
- **Modularity**: Extract if used ≥3 times
- **Consistency**: Theme colors, spacing, component patterns enforced
- **Fail-Safe**: All features must work offline first
- **Performance**: Cache Theme.of(), MediaQuery.of(), add const everywhere

## New Agent Responsibilities

### mr-theme-guardian
- **Goal**: 95%+ theme compliance
- **Blocks**: Commits with >5 hardcoded colors
- **Metrics**: Track color/spacing/typography violations
- **Authority**: Can block releases for theme violations

### mr-optimization
- **Goal**: 30-50% faster rebuilds
- **Focus**: Const constructors, caching, build optimization
- **Metrics**: Track rebuild times, allocation counts
- **Authority**: Can request refactoring for performance

### mr-widget-crafter
- **Goal**: Eliminate duplicate patterns
- **Rule**: Extract if used 3+ times
- **Metrics**: Track widget reuse, code reduction
- **Authority**: Can propose widget extraction

> Built with ❤️ for musicians and cover bands