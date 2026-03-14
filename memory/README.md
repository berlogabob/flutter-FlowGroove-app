# 🧠 FlowGroove Memory System

**Purpose:** Prevent recurring problems by maintaining institutional memory

**Location:** `/memory/`

---

## 📁 Memory Structure

```
memory/
├── README.md                           # This file - how to use memory system
├── CRITICAL_PROBLEMS.md                # Critical issues that must never happen again
├── SECURITY_ISSUES.md                  # Security vulnerabilities and fixes
├── BUILD_DEPLOYMENT_ISSUES.md          # Build and deployment problems
├── DEPENDENCY_ISSUES.md                # Dependency conflicts and solutions
├── ANDROID_ISSUES.md                   # Android-specific problems
├── IOS_ISSUES.md                       # iOS-specific problems
├── WEB_ISSUES.md                       # Web-specific problems
├── FIREBASE_ISSUES.md                  # Firebase-related problems
├── CODE_QUALITY.md                     # Code quality issues and best practices
└── ARCHITECTURE_DECISIONS.md           # Important architecture decisions
```

---

## 🎯 How This Works

### 1. **Problem Discovery**
When you encounter a problem:
- Create/update relevant memory file
- Document: What, Why, How, Solution, Prevention
- Tag with severity: CRITICAL, HIGH, MEDIUM, LOW

### 2. **Agent Monitoring**
The Memory Guardian Agent (`agents/mr-memory.md`):
- Reads all memory files before any code change
- Checks proposed changes against known problems
- Warns if a change might recreate a known issue
- Suggests adding new problems to memory

### 3. **Integration with Workflow**
Before ANY code modification:
```
1. Read memory/ files
2. Check if change affects any known problem area
3. Validate against best practices from memory
4. If new problem found → Add to memory
5. Proceed with change only after memory check
```

---

## 📝 Memory Entry Template

```markdown
## [Problem Title]

**Date:** YYYY-MM-DD  
**Severity:** CRITICAL | HIGH | MEDIUM | LOW  
**Status:** ✅ FIXED | ⚠️ MONITORING | 🔴 ACTIVE  
**Category:** security | build | deployment | code | dependency | etc.

### The Problem
Clear description of what went wrong

### Root Cause
Why did this happen?

### Impact
What was affected? What could have happened?

### The Fix
How was it resolved?

### Prevention
How to prevent this from happening again:
- [ ] Specific check 1
- [ ] Specific check 2
- [ ] Files to review
- [ ] Commands to run

### Files Involved
- `path/to/file1.ext`
- `path/to/file2.ext`

### Related Issues
- GitHub Issue #XXX
- Related memory entries

### Last Verified
Date when this was last confirmed as fixed
```

---

## 🤖 Memory Guardian Agent Role

**Agent:** `mr-memory.md`

**Responsibilities:**
1. **Pre-Change Review**
   - Read all memory files before any code modification
   - Cross-reference proposed changes with known problems
   - Block changes that violate memory rules

2. **Pattern Detection**
   - Identify when a change might recreate a known problem
   - Warn about similar patterns to past issues
   - Suggest safer alternatives

3. **Memory Updates**
   - Add new problems when discovered
   - Update status of existing problems
   - Archive resolved issues

4. **Team Integration**
   - Work with `mr-architect.md` on design decisions
   - Collaborate with `mr-senior-developer.md` on implementations
   - Alert `mr-tester.md` about critical areas to test
   - Inform `mr-release.md` about deployment risks

---

## 🔍 Quick Reference

### Critical Areas (Always Check Memory)

| Area | Memory File | Last Check |
|------|-------------|------------|
| `.env` in builds | `SECURITY_ISSUES.md` | 2026-03-14 |
| FTP deployment | `BUILD_DEPLOYMENT_ISSUES.md` | 2026-03-14 |
| Android deprecation | `ANDROID_ISSUES.md` | 2026-03-14 |
| Git branch pushes | `BUILD_DEPLOYMENT_ISSUES.md` | 2026-03-14 |
| Dependency updates | `DEPENDENCY_ISSUES.md` | 2026-03-14 |

---

## 📊 Memory Statistics

- **Total Problems Documented:** 0
- **Critical Issues:** 0
- **Active Warnings:** 0
- **Last Memory Review:** N/A

---

## 🚀 Getting Started

### For Developers:
1. Before coding: Read `memory/CRITICAL_PROBLEMS.md`
2. When stuck: Check relevant memory file
3. After fixing: Document in memory

### For Agents:
1. **Always** read memory before suggesting changes
2. **Always** check if change affects known problem areas
3. **Always** update memory when new problems found

---

**Created:** March 14, 2026  
**Last Updated:** March 14, 2026  
**Maintained By:** Memory Guardian Agent (`mr-memory.md`)
