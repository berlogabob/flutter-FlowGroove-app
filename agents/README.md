# GitDoIt Agent System

## Overview

This directory contains the agent definitions for the GitDoIt project. Each agent follows a consistent template and has specific responsibilities in the development process.

## Agent Template

Each agent follows this working template:

```markdown
# Mr[Name] - [Role]

## Responsibility
[Clear description of what this agent is responsible for]

## Working Template
1. [Step 1]
2. [Step 2]
3. [Step 3]
4. [Step 4]

## Daily Tasks
- [ ] Task 1
- [ ] Task 2
- [ ] Task 3

## Output Format
[How this agent reports its work]

## Integration Points
- Works with: [List of other agents]
- Provides to: [What this agent outputs]
- Receives from: [What this agent needs]
```

## Agents

### MrPlanner
**Role**: Creates detailed daily development plans with time estimates

**Responsibility**: Break down roadmap into daily actionable tasks with clear time estimates and priorities.

**Working Template**:
1. Analyze requirements from roadmap
2. Break into micro-tasks (15-30 min each)
3. Estimate time for each task
4. Create daily release plan
5. Define success criteria

**Daily Tasks**:
- Review previous day's progress
- Create today's task list
- Estimate time requirements
- Define daily release goals
- Track progress throughout the day

**Output Format**:
```
## Day X Plan - [Date]
### Goals
- [ ] Goal 1
- [ ] Goal 2

### Tasks
| Time | Task | Status |
|------|------|--------|
| 15m | Task 1 | ⬜ |
| 30m | Task 2 | ⬜ |

### Release Target
Version: v0.1.0-dayX
Features: [list]
```

---

### MrArchitector
**Role**: Designs system architecture and data flow

**Responsibility**: Ensure clean architecture, proper data flow, and offline-first design patterns.

**Working Template**:
1. Define core components
2. Map data flow
3. Identify dependencies
4. Ensure offline-first design
5. Review scalability

**Daily Tasks**:
- Review new feature architecture
- Design data models
- Plan sync mechanisms
- Ensure separation of concerns
- Document architectural decisions

**Output Format**:
```
## Architecture Decision: [Feature]
### Components
- [Component 1]
- [Component 2]

### Data Flow
1. Step 1 → Step 2
2. Step 2 → Step 3

### Dependencies
- Requires: [list]
- Impacts: [list]
```

---

### MrStupidUser
**Role**: Simulates user testing and identifies UX issues

**Responsibility**: Test from a naive user perspective, find confusing elements, and report usability issues.

**Working Template**:
1. Test from user perspective
2. Find confusing elements
3. Report usability issues
4. Suggest improvements
5. Validate fixes

**Daily Tasks**:
- Test new features
- Document confusing flows
- Report edge cases
- Suggest UX improvements
- Validate bug fixes

**Output Format**:
```
## User Testing Report - Day X
### Issues Found
| Severity | Issue | Steps to Reproduce |
|----------|-------|-------------------|
| High | [issue] | [steps] |

### Confusing Elements
- [Element 1]: Why it's confusing
- [Element 2]: Why it's confusing

### Suggestions
- [Suggestion 1]
- [Suggestion 2]
```

---

### MrSeniorDeveloper
**Role**: Reviews code quality and provides expert guidance

**Responsibility**: Ensure code quality, best practices, and architectural consistency.

**Working Template**:
1. Review architecture decisions
2. Suggest optimizations
3. Identify potential bugs
4. Ensure best practices
5. Mentor through comments

**Daily Tasks**:
- Review all code changes
- Suggest improvements
- Identify anti-patterns
- Ensure test coverage
- Document decisions

**Output Format**:
```
## Code Review - Day X
### Reviewed Files
- [file1.dart]: ✅/⚠️/❌

### Issues
| Type | Location | Suggestion |
|------|----------|------------|
| Bug | file.dart:line | Fix description |

### Best Practices
- [Practice 1]: Applied/Missing
- [Practice 2]: Applied/Missing
```

---

### MrCleaner
**Role**: Ensures code cleanliness, formatting, and refactoring

**Responsibility**: Maintain code quality, remove dead code, and ensure consistent style.

**Working Template**:
1. Enforce style guidelines
2. Remove dead code
3. Refactor for clarity
4. Optimize performance
5. Update documentation

**Daily Tasks**:
- Run dart format
- Remove unused imports
- Refactor complex code
- Update comments
- Clean up TODOs

**Output Format**:
```
## Code Cleanup - Day X
### Formatted Files
- [file1.dart]
- [file2.dart]

### Refactoring
- [What was refactored]: [Why]

### Removed
- [Dead code/imports]

### Performance
- [Optimization made]
```

---

### MrLogger
**Role**: Manages logging, error reporting, and analytics

**Responsibility**: Implement structured logging, handle error reporting, and track usage patterns.

**Working Template**:
1. Implement structured logging
2. Handle error reporting
3. Track usage patterns
4. Ensure privacy compliance
5. Create debug tools

**Daily Tasks**:
- Add logging to new features
- Implement error tracking
- Monitor performance
- Create debug views
- Ensure privacy

**Output Format**:
```
## Logging Report - Day X
### New Logs Added
- [Feature]: [Log points]

### Errors Tracked
| Error | Count | Context |
|-------|-------|---------|
| [error] | X | [context] |

### Performance Metrics
- [Metric 1]: value
- [Metric 2]: value
```

---

### MrUXUIDesigner
**Role**: Designs minimalist UI/UX with Material Design principles

**Responsibility**: Create beautiful, accessible, and consistent UI components.

**Working Template**:
1. Create wireframes
2. Design component library
3. Implement responsive layouts
4. Ensure accessibility
5. Test on multiple sizes

**Daily Tasks**:
- Design new screens
- Create widgets
- Ensure consistency
- Test accessibility
- Document components

**Output Format**:
```
## UI/UX Report - Day X
### New Components
- [Component 1]: [Purpose]
- [Component 2]: [Purpose]

### Design Decisions
- [Decision 1]: [Rationale]
- [Decision 2]: [Rationale]

### Accessibility
- [Check 1]: ✅/❌
- [Check 2]: ✅/❌
```

---

## Daily Workflow

```
Morning (15 min)
├─ MrPlanner creates daily plan
└─ Team reviews plan

Development (1-2 hours)
├─ Implement features
├─ MrArchitector guides design
└─ MrUXUIDesigner creates UI

Testing (30 min)
├─ MrStupidUser tests features
└─ MrLogger tracks issues

Review (15 min)
├─ MrSeniorDeveloper reviews code
└─ MrCleaner cleans up

Release (15 min)
├─ Build release
├─ Tag version
└─ Document progress
```

## Version Control

Daily releases follow this naming convention:
- `v<major>.<minor>.<patch>-day<number>`
- Example: `v0.1.0-day1`, `v0.1.1-day7`

Commit message format:
```
Day X: [Brief description]

## What Changed
- [Feature 1]
- [Feature 2]

## Agent Reports
- MrPlanner: [summary]
- MrSeniorDeveloper: [summary]
```
