# 🔍 Git History Quick Reference

**Generated:** March 14, 2026  
**Analysis Directory:** `git-history-analysis/`

---

## 📁 Generated Files

| File | Purpose |
|------|---------|
| `branches.txt` | All branches with dates |
| `tags.txt` | All releases/tags |
| `recent-commits.txt` | Last 50 commits |
| `march-13-14-commits.txt` | Critical commits from March 13-14 |
| `file-commits.txt` | Commits touching key files |
| `branch-diffs.txt` | Differences between branches |
| `keyword-commits.txt` | Commits by keyword |
| `working-to-current.patch` | Patch from working to current |
| `broken-to-fixed.patch` | Patch showing what was fixed |
| `SUMMARY.md` | Complete summary |

---

## 🔎 Quick Search Commands

### Find commits that changed specific file:
```bash
git log --all --oneline -- lib/main.dart
git log --all --oneline -- lib/screens/profile_screen.dart
git log --all --oneline -- lib/services/analytics_service.dart
```

### Find commits with keyword:
```bash
git log --all --oneline --grep="analytics"
git log --all --oneline --grep="firebase"
git log --all --oneline --grep="profile"
git log --all --oneline --grep="ko-fi"
```

### Find commits that added/removed specific code:
```bash
git log --all -S"FirebaseAnalytics" --oneline
git log --all -S"kIsWeb" --oneline
git log --all -S"setPersistence" --oneline
```

### Compare branches:
```bash
# See what changed
git diff branch1 branch2

# See file changes only
git diff --stat branch1 branch2

# See specific file
git diff branch1 branch2 -- lib/main.dart
```

### Restore file from old commit:
```bash
# Find commit
git log --all --oneline -- lib/main.dart

# Restore file
git checkout <commit-hash> -- lib/main.dart
```

### View commit details:
```bash
git show <commit-hash>
git show <commit-hash> --stat
git show <commit-hash> lib/main.dart
```

---

## 📊 Key Branches

| Branch | Status | Purpose |
|--------|--------|---------|
| `second01` | ✅ Active | Current development |
| `feature/march-14-complete` | ✅ Working | Working version with Memory System |
| `backup/march-14-analytics-fix` | ✅ Working | Analytics fix backup |
| `feature/tools-migration-backup` | ⚠️ Broken | Development (web broken) |
| `main` | 🚀 Production | Production version |

---

## 🎯 Key Commits to Know

### Working Version:
```
5ed6781 Release 0.13.1+167 (March 13)
db6cdeb feat: Add multi-platform deployment system
```

### Analytics Fix:
```
a768bd9 backup: Analytics disabled on web (working version)
```

### Memory System:
```
03dec0c feat: Add Memory System with Mr. Memory agent
```

### Broken Commits (avoid):
```
b302ea1 fix: Force clean FTP deploy (broke web)
```

---

## 🔧 Useful Analysis Commands

### Show all changes in date range:
```bash
git log --all --since="2026-03-13" --until="2026-03-15" --oneline
```

### Find who changed what:
```bash
git log --all --author="Berloga" --oneline
git blame lib/main.dart
```

### Search code in all commits:
```bash
git log --all -S"search_term" --oneline
git grep "search_term" $(git rev-list --all)
```

### Create backup of current state:
```bash
git branch backup/$(date +%Y-%m-%d)
git push origin backup/$(date +%Y-%m-%d)
```

### View patch file:
```bash
cat git-history-analysis/broken-to-fixed.patch
cat git-history-analysis/working-to-current.patch
```

### Apply patch (if needed):
```bash
git apply git-history-analysis/some-patch.patch
```

---

## 📝 Common Scenarios

### "I need to see what was in version 0.13.1+167"
```bash
git show 5ed6781
git checkout 5ed6781 -- lib/main.dart  # restore specific file
```

### "What changed between working and broken version?"
```bash
git diff backup/march-14-analytics-fix feature/tools-migration-backup
```

### "Find when Analytics was added"
```bash
git log --all -S"AnalyticsService" --oneline
```

### "Restore working version of file"
```bash
# Find last working commit for file
git log --all --oneline -- lib/main.dart | grep -i "working\|fix"

# Restore from that commit
git checkout <commit-hash> -- lib/main.dart
```

### "See all my work from today"
```bash
git log --all --author="Berloga" --since="2026-03-14" --oneline
```

---

## 🚀 Quick Restore Commands

### Restore entire working version:
```bash
git checkout backup/march-14-analytics-fix
```

### Restore specific file from working version:
```bash
git checkout backup/march-14-analytics-fix -- lib/main.dart
```

### Create backup before experimenting:
```bash
git branch backup/before-experiment-$(date +%H-%M)
git push origin backup/before-experiment-$(date +%H-%M)
```

### Undo last commit (keep changes):
```bash
git reset --soft HEAD~1
```

### Undo last commit (discard changes):
```bash
git reset --hard HEAD~1
```

---

## 📞 Emergency Commands

### "I broke everything, help!"
```bash
# See current state
git status

# Undo all local changes
git reset --hard HEAD

# Switch to known working version
git checkout backup/march-14-analytics-fix
```

### "I need to find when something broke"
```bash
# Binary search through commits
git bisect start
git bisect bad HEAD          # Current is broken
git bisect good 5ed6781      # This was working
# Git will help you find the breaking commit
git bisect reset             # When done
```

### "Show me ALL changes at once"
```bash
git diff backup/march-14-analytics-fix second01 > all-changes.patch
```

---

**Last Updated:** March 14, 2026  
**Analysis Directory:** `git-history-analysis/`  
**Working Branch:** `second01`
