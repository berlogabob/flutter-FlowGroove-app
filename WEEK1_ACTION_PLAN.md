# 🚀 IMMEDIATE ACTION PLAN - WEEK 1

**Start Date:** March 10, 2026  
**Focus:** Critical theme violations, duplicate color systems  
**Agents:** 3 new + 2 existing  
**Goal:** Fix 100+ violations in 5 days

---

## 👥 AGENT TEAM

### New Agents (Created):
1. ✅ **mr-theme-guardian** - Theme enforcement (95%+ compliance)
2. ✅ **mr-optimization** - Performance (cache Theme.of(), const)
3. ✅ **mr-widget-crafter** - Widget extraction (DRY principle)

### Existing Agents:
4. ✅ **mr-cleaner** - Code refactoring
5. ✅ **mr-sync** - Coordination

---

## 📅 DAY 1: Eliminate Duplicate Color Systems

### Task 1.1: Delete app_colors.dart theme (2 hours)
**Agent:** `mr-theme-guardian`

**Files:**
- `/lib/screens/songs/components/song_constructor/core/theme/app_colors.dart`

**Actions:**
1. Remove `themeColors` list (19 colors)
2. Replace all imports with `MonoPulseColors`
3. Update references to use `MonoPulseColors.sectionColors`

**Expected Impact:** -19 hardcoded colors

---

### Task 1.2: Delete section.dart hardcoded colors (2 hours)
**Agent:** `mr-theme-guardian`

**Files:**
- `/lib/models/section.dart`

**Actions:**
1. Remove `_getDefaultColorAt()` method (16 colors)
2. Replace with `MonoPulseColors.sectionColors`
3. Fix `contrastingTextColor` to use theme method

**Expected Impact:** -16 hardcoded colors

---

### Task 1.3: Verify and test (1 hour)
**Agent:** `mr-sync`

**Actions:**
1. Run `flutter analyze`
2. Fix any compilation errors
3. Run tests to verify no regressions

---

## 📅 DAY 2-3: Fix Critical Color Violations

### Task 2.1: profile_screen.dart (3 hours)
**Agents:** `mr-theme-guardian`, `mr-cleaner`

**File:** `/lib/screens/profile_screen.dart`

**Violations to Fix:**
- Line 180: `Colors.blue` → `MonoPulseColors.info`
- Line 180: `Colors.grey` → `MonoPulseColors.textTertiary`
- Line 191: `Colors.green` → `MonoPulseColors.successGreen`
- Line 218: `Colors.green` → `MonoPulseColors.successGreen`
- Line 232: `Colors.green` → `MonoPulseColors.successGreen`
- Line 242: `Colors.red` → `MonoPulseColors.error`
- Line 245: `Colors.red` → `MonoPulseColors.error`
- Line 567: `Colors.red` → `MonoPulseColors.error`
- Line 570: `Colors.red` → `MonoPulseColors.error`
- Plus 10+ spacing/typography violations

**Expected Impact:** -20 violations

---

### Task 2.2: band_songs_screen.dart (3 hours)
**Agents:** `mr-theme-guardian`, `mr-cleaner`

**File:** `/lib/screens/bands/band_songs_screen.dart`

**Violations to Fix:**
- Line 965: `Colors.red` → `MonoPulseColors.roleAdmin`
- Line 966: `Colors.blue` → `MonoPulseColors.roleEditor`
- Line 540: `Colors.white` → `MonoPulseColors.textPrimary`
- Line 650: `Colors.white` → `MonoPulseColors.textPrimary`
- Line 1050: `Colors.white` → `MonoPulseColors.textPrimary`
- Plus 10+ spacing violations

**Expected Impact:** -15 violations

---

### Task 2.3: join_band_screen.dart (2 hours)
**Agents:** `mr-theme-guardian`, `mr-cleaner`

**File:** `/lib/screens/bands/join_band_screen.dart`

**Violations to Fix:**
- Line 189: `Colors.red.withValues(alpha: 0.1)` → `MonoPulseColors.errorSubtle`
- Line 194: `Colors.red` → `MonoPulseColors.error`
- Line 241: `Colors.white` → `MonoPulseColors.textPrimary`
- Line 255: `Colors.white` → `MonoPulseColors.textPrimary`
- Line 309: `Colors.white` → `MonoPulseColors.textPrimary`
- Plus 7+ spacing violations

**Expected Impact:** -12 violations

---

## 📅 DAY 4: Cache Theme Calls

### Task 3.1: Cache Theme.of() in 20 files (4 hours)
**Agent:** `mr-optimization`

**Files (20 highest priority):**
1. `dashboard_grid.dart` - 8 calls
2. `song_match_dialog.dart` - 14 calls
3. `unified_item_card.dart` - 4 calls
4. `band_card.dart` - 3 calls
5. `setlist_card.dart` - 3 calls
6. `song_card.dart` - 3 calls
7. Plus 14 more files

**Pattern:**
```dart
@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  // Replace all Theme.of(context) with theme
}
```

**Expected Impact:** 30-50% faster rebuilds

---

### Task 3.2: Add const constructors (2 hours)
**Agent:** `mr-optimization`

**Widgets to Make Const:**
1. `TagCloudWidget` 
2. `UnifiedItemBadge`
3. `SongBPMBadge`
4. `TimeSignatureDropdown`
5. `LinkChip`
6. `LinkChipRow`

**Pattern:**
```dart
class MyWidget extends StatelessWidget {
  final String title;
  const MyWidget({Key? key, required this.title}) : super(key: key);
}

// Usage:
const MyWidget(title: 'Hello')
```

**Expected Impact:** Better compile-time optimization

---

## 📅 DAY 5: Extract Common Widgets

### Task 4.1: Create AppAvatar widget (2 hours)
**Agent:** `mr-widget-crafter`

**Source Pattern (15 occurrences):**
```dart
CircleAvatar(
  backgroundColor: MonoPulseColors.surfaceRaised,
  radius: 20,
  child: Icon(Icons.music_note, color: MonoPulseColors.accentOrange),
)
```

**Extracted Widget:**
```dart
class AppAvatar extends StatelessWidget {
  final IconData icon;
  final Color? backgroundColor;
  final double size;
  
  const AppAvatar({
    Key? key,
    required this.icon,
    this.backgroundColor,
    this.size = 40,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: backgroundColor ?? MonoPulseColors.surfaceRaised,
      radius: size / 2,
      child: Icon(icon, color: MonoPulseColors.accentOrange, size: size * 0.6),
    );
  }
}
```

**Files to Update:** 15

---

### Task 4.2: Create AppCard widget (2 hours)
**Agent:** `mr-widget-crafter`

**Source Pattern (118 occurrences):**
```dart
Container(
  decoration: BoxDecoration(
    color: MonoPulseColors.surface,
    borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
    border: Border.all(color: MonoPulseColors.borderSubtle),
  ),
)
```

**Extracted Widget:**
```dart
class AppCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  
  const AppCard({
    Key? key,
    required this.child,
    this.color,
    this.padding,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? MonoPulseColors.surface,
        borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
        border: Border.all(color: MonoPulseColors.borderSubtle),
      ),
      padding: padding ?? const EdgeInsets.all(MonoPulseSpacing.md),
      child: child,
    );
  }
}
```

**Files to Update:** 118 (gradual migration)

---

### Task 4.3: Create AppSnackBar helper (1 hour)
**Agent:** `mr-widget-crafter`

**Source Pattern (38 occurrences):**
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(message),
    backgroundColor: MonoPulseColors.accentOrange,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
    ),
  ),
);
```

**Extracted Helper:**
```dart
class AppSnackBar {
  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: MonoPulseColors.accentOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
        ),
      ),
    );
  }
  
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: MonoPulseColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
        ),
      ),
    );
  }
}
```

**Files to Update:** 38 (gradual migration)

---

## 📊 WEEK 1 SUCCESS METRICS

| Metric | Before | After | Target |
|--------|--------|-------|--------|
| **Duplicate Color Systems** | 2 | 0 | 0 ✅ |
| **Hardcoded Colors** | 89 | 54 | -35 ✅ |
| **Theme Compliance** | 48% | 65% | +17% ✅ |
| **Uncached Theme Calls** | 78 | 58 | -20 ✅ |
| **Const Widgets** | 10+ missing | All const | ✅ |
| **Duplicate Patterns** | 6 major | 3 remaining | -50% ✅ |

---

## 🎯 DAILY STANDUP FORMAT

### End of Day Report (Each Agent)
```markdown
## [AGENT NAME] - Day [X] Report

### Completed
- [ ] Task 1
- [ ] Task 2

### Blocked
- [ ] Issue (if any)

### Metrics
- Violations fixed: [X]
- Files updated: [Y]
- Compliance: [Z]%

### Next Day Plan
- [ ] Task 1
- [ ] Task 2
```

---

## 🚨 ESCALATION PATH

### If Blocked:
1. **Agent** → Report to `mr-sync`
2. **mr-sync** → Coordinate with `mr-planner`
3. **mr-planner** → Reassign or adjust plan
4. **Update** → Document in daily report

### If Quality Issues:
1. **mr-senior-developer** → Review changes
2. **Request fixes** → Back to responsible agent
3. **Re-test** → `mr-tester` verifies
4. **Merge** → Only after approval

---

## 📝 END OF WEEK REPORT

**Deliverables:**
1. ✅ Duplicate color systems eliminated
2. ✅ Critical color violations fixed (35+)
3. ✅ Theme calls cached (20+ files)
4. ✅ Const constructors added (10+ widgets)
5. ✅ Common widgets extracted (3 widgets)
6. ✅ Documentation updated

**Metrics:**
- Theme compliance: 48% → 65%
- Hardcoded colors: 89 → 54
- Performance: +30% faster rebuilds

**Next Week Focus:**
- Fix remaining 54 color violations
- Fix 77 spacing violations
- Fix 138 typography violations

---

**Plan Created:** March 10, 2026  
**Execution:** March 11-15, 2026  
**Team:** 5 agents (3 new + 2 existing)  
**Goal:** 100+ violations fixed in Week 1
