# Agent System for FlowGroove

Autonomous AI agents that drive development, testing, and release of the FlowGroove Flutter app.

## Hierarchy
```
USER (Final Authority)
  ↓
mr-supervisor (Master Coordinator) ⭐ NEW
  ↓
mr-compliance (Rules Enforcer) ⭐ NEW
  ↓
mr-quality-control (Quality Gate) ⭐ NEW
  ↓
mr-sync (Project Coordinator)
  ↓
mr-planner (Task Decomposition)
  ├── mr-architect (Design validation)
  ├── creative-director (UX flow)
  ├── mr-theme-guardian (Theme enforcement)
  ├── mr-optimization (Performance)
  ├── mr-widget-crafter (Widget extraction)
  ├── mr-senior-developer (Code review)
  ├── mr-cleaner (Refactor & optimization)
  ├── mr-tester (Testing)
  ├── mr-logger (Documentation)
  ├── mr-ux-agent (UI implementation)
  ├── mr-android (Mobile debug)
  ├── mr-android-debug (Android specialist)
  ├── mr-stupid-user (User simulation)
  ├── mr-repetitive (Pattern detection)
  └── mr-release (Release orchestration)
```

## Agent Categories

### 👑 Master Agents (New)
- **mr-supervisor**: Master coordinator, oversees all agents, resolves conflicts
- **mr-compliance**: Rules enforcer, monitors compliance with project politics
- **mr-quality-control**: Final quality gate, blocks releases with issues

### 📋 Coordination & Planning
- **mr-sync**: Overall coordination, conflict resolution
- **mr-planner**: Task decomposition, sprint planning
- **mr-architect**: Architecture design, pattern validation

### 🛡️ Quality & Enforcement
- **mr-compliance** ⭐: Project rules enforcement, politics adherence
- **mr-quality-control** ⭐: Final quality gate, zero defects
- **mr-theme-guardian**: Design system enforcement, theme compliance (95%+)
- **mr-optimization**: Performance optimization, const constructors, caching
- **mr-widget-crafter**: Widget extraction, DRY principle enforcement
- **mr-cleaner**: Code quality, formatting, dead code removal
- **mr-senior-developer**: Code review, best practices

### 🎨 Implementation & Testing
- **creative-director**: UX patterns, user journey design
- **mr-ux-agent**: UI implementation
- **mr-tester**: Test creation, coverage
- **mr-android**: Android-specific issues
- **mr-android-debug**: Android debugging specialist
- **mr-stupid-user**: User simulation, edge case testing
- **mr-repetitive**: Pattern detection, duplication finder
- **mr-logger**: Documentation, knowledge base

### 🚀 Release
- **mr-release**: Release orchestration, versioning

## Usage
1. **Request work**: `@agent mr-planner Design song structure editor`
2. **Agents collaborate**: Each produces GOST-formatted output
3. **Master agents oversee**: mr-supervisor, mr-compliance, mr-quality-control monitor
4. **Coordinator merges**: `mr-sync` ensures no conflicts
5. **Quality gate**: mr-quality-control gives final approval
6. **Verify**: All changes tested before merge

## Project Rules (ENFORCED BY MASTER AGENTS)

### Rule 1: User Request Required
- ✅ Agents MUST have user request to start work
- ❌ Agents CANNOT initiate work unsolicited
- ❌ Agents CANNOT expand scope beyond request
- **Enforced by:** mr-compliance

### Rule 2: No Direct Code Modification
- ✅ Agents MUST provide recommendations only
- ❌ Agents CANNOT modify code directly
- **Enforced by:** mr-supervisor

### Rule 3: GOST Format Required
- ✅ All agent outputs MUST use GOST format
- ❌ Outputs without GOST are rejected
- **Enforced by:** mr-compliance

### Rule 4: Quality Gates
- ✅ Theme compliance: ≥95% (enforced by mr-theme-guardian)
- ✅ Test coverage: ≥80% for new logic (enforced by mr-tester)
- ✅ Architecture compliance: Required (enforced by mr-architect)
- ✅ Code review: Required (enforced by mr-senior-developer)
- ✅ Final approval: Required (enforced by mr-quality-control)
- **Enforced by:** mr-quality-control

### Rule 5: Documentation
- ✅ All changes MUST be documented
- ✅ All decisions MUST have rationale
- ✅ All violations MUST be reported
- **Enforced by:** mr-compliance

### Rule 6: Agent Hierarchy
```
User → mr-supervisor → mr-compliance → mr-quality-control → 
mr-sync → mr-planner → Specialist Agents
```
- ✅ Chain of command MUST be respected
- ❌ Agents CANNOT bypass hierarchy
- **Enforced by:** mr-supervisor

## Quality Gates

### Pre-Merge Gates (ALL MUST PASS)
1. ✅ User request documented
2. ✅ Architecture approved (mr-architect)
3. ✅ Code reviewed (mr-senior-developer)
4. ✅ Theme compliance ≥95% (mr-theme-guardian)
5. ✅ Tests written (mr-tester)
6. ✅ Compliance verified (mr-compliance)
7. ✅ Final approval (mr-quality-control)

### Pre-Release Gates (ALL MUST PASS)
1. ✅ All pre-merge gates passed
2. ✅ No critical bugs
3. ✅ No rule violations pending
4. ✅ Performance benchmarks met
5. ✅ User acceptance confirmed
6. ✅ mr-supervisor approval

## Agent Performance Metrics

| Agent | Response Time | Quality Score | Compliance | Status |
|-------|--------------|---------------|------------|--------|
| mr-supervisor | <30min | ≥95% | 100% | 🟢 Active |
| mr-compliance | <1h | ≥95% | 100% | 🟢 Active |
| mr-quality-control | <1h | ≥98% | 100% | 🟢 Active |
| mr-sync | <1h | ≥90% | ≥95% | 🟢 Active |
| mr-planner | <2h | ≥90% | ≥95% | 🟢 Active |
| mr-architect | <4h | ≥90% | ≥95% | 🟢 Active |
| mr-theme-guardian | <2h | ≥95% | 100% | 🟢 Active |
| mr-senior-developer | <4h | ≥90% | ≥95% | 🟢 Active |
| mr-cleaner | <2h | ≥90% | ≥95% | 🟢 Active |
| mr-tester | <4h | ≥90% | ≥95% | 🟢 Active |
| mr-release | <1h | ≥95% | 100% | 🟢 Active |

## Escalation Protocol

```
Agent Issue → mr-compliance (warning) → mr-supervisor (escalation) → User (final)
Critical Bug → mr-quality-control (block) → mr-supervisor → Immediate fix
Rule Violation → mr-compliance (document) → mr-supervisor (action) → User (notify)
Quality Escape → mr-quality-control (investigate) → Retrospective → Process fix
```

## Master Agent Controls

### mr-supervisor Controls:
- `/supervisor status` - Get overall agent status
- `/supervisor conflicts` - List active conflicts
- `/supervisor escalate [issue]` - Escalate to user
- `/supervisor reassign [task] [agent]` - Reassign task
- `/supervisor suspend [agent]` - Suspend agent for violations

### mr-compliance Controls:
- `/compliance audit [agent/file/task]` - Audit compliance
- `/compliance violations` - List recent violations
- `/compliance warn [agent]` - Issue warning
- `/compliance block [merge/release]` - Block for compliance
- `/compliance report` - Generate compliance report

### mr-quality-control Controls:
- `/qc check [PR/release]` - Run quality gate check
- `/qc block [merge/release]` - Block for quality issues
- `/qc approve [merge/release]` - Approve after checks pass
- `/qc metrics` - Show quality metrics
- `/qc retrospective [version]` - Run quality retrospective

## Guidelines
- **Modularity**: Extract if used ≥3 times
- **Consistency**: Theme colors, spacing, component patterns enforced
- **Fail-Safe**: All features must work offline first
- **Performance**: Cache Theme.of(), MediaQuery.of(), add const everywhere
- **Zero Defects**: No bugs allowed to production (mr-quality-control enforces)
- **Documentation**: If it's not documented, it didn't happen

## New Agent Powers (Master Agents)

### mr-supervisor:
- ✅ Can override any agent decision
- ✅ Can reassign tasks between agents
- ✅ Can suspend agents for rule violations
- ✅ Can block any merge/release
- ✅ Reports directly to user

### mr-compliance:
- ✅ Can audit any agent's work
- ✅ Can issue compliance warnings
- ✅ Can block work until compliance achieved
- ✅ Can enforce project politics
- ✅ Maintains violation logs

### mr-quality-control:
- ✅ Can block ANY merge/release
- ✅ Can require additional reviews
- ✅ Can override agent approvals
- ✅ Final sign-off before production
- ✅ Tracks quality metrics

> Built with ❤️ for musicians and cover bands
> **Master Agents Added:** March 11, 2026 - Enhanced oversight and quality control