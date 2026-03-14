# 🧠 FlowGroove Memory System

**Purpose:** Prevent recurring problems by maintaining institutional memory

---

## 📁 Memory Files

- `CRITICAL_PROBLEMS.md` - Critical issues that must never happen again
- `SECURITY_ISSUES.md` - Security vulnerabilities and fixes
- `BUILD_DEPLOYMENT_ISSUES.md` - Build and deployment problems
- `DEPENDENCY_ISSUES.md` - Dependency conflicts and solutions

---

## 🎯 How This Works

### 1. **Before ANY code change:**
   - Read `CRITICAL_PROBLEMS.md`
   - Check if change affects any known problem area
   - Verify against prevention checklists

### 2. **When problem occurs:**
   - Document in appropriate memory file
   - Include: What, Why, How, Solution, Prevention
   - Tag with severity: CRITICAL, HIGH, MEDIUM, LOW

### 3. **Agent Monitoring:**
   - Mr. Memory (`agents/mr-memory.md`) reads memory before suggesting changes
   - Warns if change might recreate known issue
   - Suggests safer alternatives

---

## 📝 Memory Entry Template

```markdown
## [Problem Title]

**Date:** YYYY-MM-DD  
**Severity:** CRITICAL | HIGH | MEDIUM | LOW  
**Status:** ✅ FIXED | ⚠️ MONITORING | 🔴 ACTIVE  

### The Problem
Clear description

### Root Cause
Why this happened

### The Fix
How resolved

### Prevention
- [ ] Check 1
- [ ] Check 2

### Last Verified
Date
```

---

## 🚨 Critical Rules

### Rule #1: Never Bundle Sensitive Files
```yaml
# ❌ WRONG
assets:
  - .env

# ✅ CORRECT
assets:
  - assets/sounds/
```

### Rule #2: Platform Checks for Firebase
```dart
// ✅ CORRECT
if (!kIsWeb) {
  await Firebase.initializeApp(...);
  await AnalyticsService.initialize();
}
```

### Rule #3: Always Verify Builds
```bash
# Before deploy
find build/web -name "*.env*"  # Must return empty
curl https://flowgroove.app/.env  # Must return 404
```

---

**Created:** March 14, 2026  
**Maintained By:** Mr. Memory Agent
