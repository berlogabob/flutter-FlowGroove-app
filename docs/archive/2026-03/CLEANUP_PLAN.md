# 🧹 PROJECT CLEANUP PLAN

**Date:** March 11, 2026  
**Status:** 🔄 READY TO EXECUTE  
**Estimated Time:** 2-3 hours

---

## 📊 CURRENT MESS ANALYSIS

### Documentation Files: **75 markdown files in root!**

**Categories:**
- **Active Documentation:** ~15 files (KEEP in root)
- **Session Reports:** ~20 files (ARCHIVE)
- **Audit Reports:** ~10 files (CONSOLIDATE)
- **Modernization Reports:** ~10 files (CONSOLIDATE)
- **Isar Migration:** ~5 files (ARCHIVE - paused)
- **Agent Documentation:** ~5 files (KEEP/REORGANIZE)
- **Old/Obsolete:** ~10 files (DELETE)

### Backup Files: **5+ found**
- `lib/screens/metronome_screen.dart.backup` - DELETE
- `.dart_tool/build/generated/.../.backup` - DELETE
- Git branches for backup - ARCHIVE

### .DS_Store Files: **14 files**
- All platforms - DELETE

### Other Clutter:
- Duplicate reports
- Obsolete plans
- Temporary files

---

## 🎯 CLEANUP STRATEGY

### Phase 1: Create Archive Structure (15 min)
```
docs/
├── archive/           # Old session reports
│   ├── 2026-02/      # February sessions
│   ├── 2026-03/      # March sessions
│   └── modernization/ # Modernization reports
├── audits/           # Audit reports
├── agents/           # Agent documentation (symlink to agents/)
├── plans/            # Active plans
└── guides/           # How-to guides
```

### Phase 2: Consolidate Documentation (30 min)

#### Keep in Root (Essential):
1. ✅ `README.md` - Project readme
2. ✅ `AGENT_MASTER_CONTROL.md` - Agent system guide
3. ✅ `FINAL_COMPREHENSIVE_AUDIT_REPORT.md` - Latest audit
4. ✅ `PHASE3_ISAR_MIGRATION_PLAN.md` - Active plan
5. ✅ `recomendation_upgrade_034.md` - Upgrade plan

#### Move to Archive:
1. 📦 All `qwen-code-export-*.md` files
2. 📦 Session reports (`DAY*_COMPLETE.md`, `DAYS_*_COMPLETE.md`)
3. 📦 Old audit reports (keep only latest)
4. 📦 Modernization reports (consolidate into 1)
5. 📦 Isar migration files (paused initiative)

#### Delete:
1. 🗑️ `metronome_screen.dart.backup`
2. 🗑️ All `.DS_Store` files
3. 🗑️ Duplicate/obsolete files
4. 🗑️ Temporary files

### Phase 3: Clean Backup Files (15 min)
- Delete `.backup` files
- Archive backup git branches
- Clean build artifacts

### Phase 4: Update References (30 min)
- Update README with new structure
- Update agent documentation
- Create cleanup report

---

## 📋 FILE CLASSIFICATION

### KEEP IN ROOT (5 files):
```
README.md
AGENT_MASTER_CONTROL.md
FINAL_COMPREHENSIVE_AUDIT_REPORT.md
PHASE3_ISAR_MIGRATION_PLAN.md
recomendation_upgrade_034.md
```

### ARCHIVE - Session Reports (15 files):
```
DAY1_COMPLETE.md
DAY4_COMPLETE.md
DAYS_2-3_COMPLETE.md
EMERGENCY_FIXES_COMPLETE.md
EMERGENCY_FIXES_COMPLETE_V2.md
emergency_fix.md
BUILD_VERIFICATION_REPORT.md
CLEANUP_REPORT.md
MODERNIZATION_COMPLETE.md
MODERNIZATION_PLAN.md
MODERNIZATION_STATUS.md
FINAL_MODERNIZATION_REPORT.md
FINAL_MODERNIZATION_REPORT_MARCH_2026.md
TASK_1.1_COMPLETE.md
TASK_1.2_COMPLETE.md
```

### ARCHIVE - Audit Reports (keep latest only):
```
KEEP: FINAL_COMPREHENSIVE_AUDIT_REPORT.md
ARCHIVE:
  - COMPREHENSIVE APP AUDIT REPORT.md
  - COMPREHENSIVE_AUDIT_REPORT_MARCH_2026.md
  - COMPREHENSIVE_REMEDIATION_PLAN.md
  - FULL_REMEDIATION_PLAN_RU.md
```

### ARCHIVE - Isar Migration (paused):
```
ISAR_MIGRATION_SESSION_1_COMPLETE.md
ISAR_MIGRATION_COMPREHENSIVE_STATUS.md
ISAR_MIGRATION_REALITY_CHECK.md
ISAR_MIGRATION_TEMPLATES.md
```

### DELETE - Obsolete/Temporary:
```
как продожить авто заполнение.md (old Russian notes)
moder_flutter.md (obsolete)
first_urgent_things.md (completed)
FLOWGROOVE_RENAME_PLAN.md (completed)
FLOWGROOVE_RENAME_COMPLETE.md (completed)
FIRESTORESERVICE_DEPRECATION_PLAN.md (superseded)
```

### KEEP - Active Plans:
```
PHASE3_ISAR_MIGRATION_PLAN.md
recomendation_upgrade_034.md
PROJECT_MASTER_DOCUMENTATION.md (if still relevant)
```

### KEEP - Agent Docs:
```
AGENT_MASTER_CONTROL.md
NEW_AGENT_DEPLOYMENT_SUMMARY.md
agents/README.md (already in agents/)
```

---

## 🗑️ DELETION CRITERIA

### Delete Immediately:
- ✅ Backup files (`*.backup`)
- ✅ `.DS_Store` files
- ✅ Build artifacts in `.dart_tool/`
- ✅ Duplicate reports
- ✅ Temporary notes

### Archive (Don't Delete):
- ✅ Session reports (historical value)
- ✅ Old audits (reference)
- ✅ Completed plans (reference)
- ✅ Migration notes (future reference)

### Keep Active:
- ✅ Latest audit report
- ✅ Active plans
- ✅ Agent documentation
- ✅ Current guides

---

## 📊 EXPECTED RESULTS

### Before:
- **75 markdown files** in root
- **5+ backup files**
- **14 .DS_Store files**
- **Messy structure**

### After:
- **~10 markdown files** in root (essential only)
- **0 backup files**
- **0 .DS_Store files**
- **Clean archive structure**

**Reduction:** ~85% fewer files in root!

---

## ⚡ EXECUTION COMMANDS

### Phase 1: Create Archive
```bash
mkdir -p docs/archive/2026-02
mkdir -p docs/archive/2026-03
mkdir -p docs/archive/modernization
mkdir -p docs/audits
mkdir -p docs/plans
mkdir -p docs/guides
```

### Phase 2: Move Files
```bash
# Session reports
mv DAY*.md docs/archive/2026-03/
mv DAYS_*.md docs/archive/2026-03/
mv EMERGENCY_*.md docs/archive/2026-03/
mv TASK_*.md docs/archive/2026-03/

# Modernization reports
mv *MODERNIZATION*.md docs/archive/modernization/
mv CLEANUP_REPORT.md docs/archive/modernization/
mv BUILD_VERIFICATION_REPORT.md docs/archive/modernization/

# Old audits
mv "COMPREHENSIVE APP AUDIT REPORT.md" docs/audits/
mv COMPREHENSIVE_AUDIT_REPORT_MARCH_2026.md docs/audits/
mv COMPREHENSIVE_REMEDIATION_PLAN.md docs/audits/
mv FULL_REMEDIATION_PLAN_RU.md docs/audits/

# Isar files
mv ISAR_*.md docs/archive/2026-03/

# Obsolete
mv "как продожить авто заполнение.md" docs/archive/2026-02/
mv moder_flutter.md docs/archive/2026-02/
mv first_urgent_things.md docs/archive/2026-03/
mv FLOWGROOVE_*.md docs/archive/2026-03/
mv FIRESTORESERVICE_DEPRECATION_PLAN.md docs/archive/2026-02/
```

### Phase 3: Delete Junk
```bash
# Delete backup files
find . -name "*.backup" -type f -delete

# Delete .DS_Store
find . -name ".DS_Store" -type f -delete

# Clean build
flutter clean
```

### Phase 4: Update Git
```bash
git add -A
git commit -m "chore: Clean up project structure, archive old reports

- Archive 60+ old markdown files to docs/archive/
- Delete backup files and .DS_Store
- Keep only essential docs in root
- Improve project organization
"
```

---

## 🎯 SUCCESS CRITERIA

- [ ] Root has ≤15 markdown files
- [ ] All backup files deleted
- [ ] All .DS_Store deleted
- [ ] Archive structure created
- [ ] README updated
- [ ] Git committed
- [ ] Project navigable

---

**Ready to execute?** 🧹
