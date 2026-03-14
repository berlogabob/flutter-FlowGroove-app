# 🛡️ PROTECTED FILES RULE - ALL AGENTS

**Priority:** CRITICAL  
**Effective:** Immediately  
**Applies To:** ALL agents (mr-architect, mr-senior-developer, mr-tester, mr-cleaner, mr-logger, mr-planner, mr-release, mr-repetitive, mr-stupid-user, mr-sync, creative-director, ux-agent, mr-android, mr-memory, etc.)

---

## ⚠️ CRITICAL RULE: PROTECTED MARKDOWN FILES

### The Rule
**ANY markdown file (`.md`) with frontmatter containing `tags: [user]` is PROTECTED and MUST NOT be modified, deleted, or altered by ANY agent.**

### Protected File Format
```markdown
---
tags: [user]
---

# File content here
```

### What Agents CANNOT Do
- ❌ **CANNOT** modify protected files
- ❌ **CANNOT** delete protected files
- ❌ **CANNOT** remove or change `tags: [user]` frontmatter
- ❌ **CANNOT** move protected files
- ❌ **CANNOT** rename protected files
- ❌ **CANNOT** alter content of protected files

### What Agents CAN Do
- ✅ **CAN** read protected files
- ✅ **CAN** reference protected files
- ✅ **CAN** use information from protected files
- ✅ **CAN** create NEW protected files (with user permission)

---

## 🔍 How to Identify Protected Files

### Check for Protected Status
```bash
# Check if file has user tag
grep -l "^tags: \[user\]" *.md

# Or check frontmatter
head -5 file.md | grep "tags: \[user\]"
```

### Example Protected Files
- Any `.md` file with:
  ```markdown
  ---
  tags: [user]
  ---
  ```

### Non-Protected Files
- Files WITHOUT `tags: [user]` in frontmatter
- Files with different tags: `tags: [agent]`, `tags: [auto-generated]`
- Non-markdown files (`.dart`, `.yaml`, `.json`, etc.)

---

## 🚨 VIOLATION CONSEQUENCES

### If Agent Violates This Rule
1. **Immediate rollback** of changes
2. **Agent deactivation** for that task
3. **Memory update** to prevent recurrence
4. **Report to user** for review

### Rollback Procedure
```bash
# If protected file was modified
git checkout HEAD -- path/to/protected-file.md

# If protected file was deleted
git checkout HEAD^ -- path/to/protected-file.md

# Verify restoration
head -5 path/to/protected-file.md
# Should show: tags: [user]
```

---

## 📋 Agent Responsibilities

### Before ANY File Operation
1. **Check if file is protected:**
   ```bash
   head -5 file.md | grep "tags: \[user\]"
   ```

2. **If protected:**
   - STOP immediately
   - Do NOT modify
   - Do NOT delete
   - Read-only access only

3. **If unsure:**
   - Ask user for permission
   - Check with Mr. Memory agent
   - Err on the side of caution

### Mr. Cleaner Specific Rules
- **NEVER** clean/delete files with `tags: [user]`
- **ALWAYS** skip protected files in cleanup operations
- **CHECK** frontmatter before any file removal

### Mr. Editor Specific Rules
- **NEVER** edit content of protected files
- **NEVER** modify frontmatter of protected files
- **READ-ONLY** access to protected files

### Mr. Release Specific Rules
- **VERIFY** protected files are NOT in commit if changes detected
- **WARN** user if protected file appears in changes
- **EXCLUDE** protected files from automated commits

### All Other Agents
- **RESPECT** protected file status
- **READ-ONLY** access
- **ASK** if unsure

---

## 🛡️ Technical Implementation

### Pre-Commit Hook (Recommended)
```bash
#!/bin/bash
# .git/hooks/pre-commit

# Check for modifications to protected files
protected_files=$(git diff --cached --name-only | xargs -I {} sh -c 'head -5 "{}" 2>/dev/null | grep -q "tags: \[user\]" && echo "{}"')

if [ -n "$protected_files" ]; then
    echo "❌ ERROR: Attempting to commit changes to protected files:"
    echo "$protected_files"
    echo ""
    echo "Protected files (tags: [user]) cannot be modified by agents."
    echo "Please revert changes to these files."
    exit 1
fi
```

### Git Attributes (Alternative)
```
# .gitattributes
*.md filter=protected-check
```

---

## 📖 Examples

### ✅ CORRECT Agent Behavior
```
Agent: "I need to reference the user requirements."
Action: Reads file with tags: [user]
Result: ✅ OK - Read-only access
```

### ❌ WRONG Agent Behavior
```
Agent: "I'll clean up old markdown files."
Action: Deletes file with tags: [user]
Result: ❌ VIOLATION - Protected file deleted
```

### ✅ CORRECT Agent Behavior
```
Agent: "I'll update the documentation."
Action: Checks frontmatter first, sees tags: [user], skips file
Result: ✅ OK - Protected file respected
```

### ❌ WRONG Agent Behavior
```
Agent: "I'll fix the formatting in this file."
Action: Modifies file with tags: [user] without permission
Result: ❌ VIOLATION - Protected file modified
```

---

## 🎯 Summary

| Action | Protected Files (`tags: [user]`) | Other Files |
|--------|----------------------------------|-------------|
| Read | ✅ Allowed | ✅ Allowed |
| Reference | ✅ Allowed | ✅ Allowed |
| Modify | ❌ FORBIDDEN | ✅ Allowed (with caution) |
| Delete | ❌ FORBIDDEN | ✅ Allowed (if safe) |
| Move/Rename | ❌ FORBIDDEN | ✅ Allowed (if safe) |
| Change Tags | ❌ FORBIDDEN | ⚠️ Ask first |

---

## 📞 Emergency Contacts

If agent is unsure:
1. **Check with Mr. Memory** - `agents/mr-memory.md`
2. **Ask User** - Direct permission required
3. **Review This File** - `agents/PROTECTED_FILES_RULE.md`

---

**Created:** March 14, 2026  
**Priority:** CRITICAL  
**Enforcement:** MANDATORY for ALL agents  
**Violations:** NOT TOLERATED

**REMEMBER: If it has `tags: [user]`, HANDS OFF! 🛡️**
