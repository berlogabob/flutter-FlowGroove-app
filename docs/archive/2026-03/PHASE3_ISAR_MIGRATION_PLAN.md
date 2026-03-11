# 🗄️ ISAR MIGRATION PLAN

**Started:** March 10, 2026  
**Status:** 🔄 IN PROGRESS  
**Estimated Time:** 20-30 hours  
**Risk Level:** HIGH (data migration)

---

## 📋 OVERVIEW

Migrating from Hive to Isar database for better performance, type safety, and active maintenance.

### Why Isar?
- ✅ **Faster** - 2-10x faster than Hive
- ✅ **Type-safe** - Compile-time checking
- ✅ **Query support** - Complex queries with conditions
- ✅ **Active maintenance** - Regular updates
- ✅ **Better relationships** - Links between collections
- ✅ **Full-text search** - Built-in search support

### ⚠️ Challenges
- ❌ **No web support** - Need conditional imports
- ❌ **Breaking change** - Data migration required
- ❌ **Schema changes** - Need to redefine all models
- ❌ **Testing** - Full regression testing required

---

## 📦 PACKAGES TO ADD

```yaml
dependencies:
  isar: ^3.1.0+1
  isar_flutter_libs: ^3.1.0+1  # Platform-specific

dev_dependencies:
  isar_generator: ^3.1.0+1
  build_runner: ^2.12.2
```

---

## 📝 MIGRATION STEPS

### Step 1: Setup (2-3 hours)
- [ ] Add Isar packages to pubspec.yaml
- [ ] Run flutter pub get
- [ ] Configure platform-specific setup
- [ ] Create Isar instance service
- [ ] Test basic CRUD operations

### Step 2: Model Migration (8-10 hours)
Migrate each model from Hive to Isar:

#### Models to Migrate:
1. **Song** - Most complex (sections, beatModes, links)
2. **Band** - Members, settings
3. **Setlist** - Song assignments, dates
4. **User** - Profile, preferences
5. **Link** - Song links
6. **Section** - Song structure
7. **MetronomePreset** - Saved presets
8. **MetronomeState** - Current state

Each model requires:
- Remove Hive annotations (@HiveType, @HiveField)
- Add Isar annotations (@collection, @Index)
- Update constructors
- Update toJson/fromJson
- Update copyWith methods
- Test serialization

### Step 3: Repository Migration (6-8 hours)
Update all repository files:

1. **song_repository.dart** - CRUD operations
2. **firestore_song_repository.dart** - Sync logic
3. **setlist_repository.dart** - CRUD operations
4. **firestore_setlist_repository.dart** - Sync logic
5. **band_repository.dart** - CRUD operations
6. **firestore_band_repository.dart** - Sync logic
7. **cache_service.dart** - Isar initialization

Each repository requires:
- Replace Hive box operations with Isar queries
- Update async patterns
- Update error handling
- Test all operations

### Step 4: Data Migration (4-6 hours)
Create migration script:

1. **Export Hive data** - Read all boxes
2. **Transform to Isar** - Convert models
3. **Import to Isar** - Write to collections
4. **Verify** - Check data integrity
5. **Cleanup** - Remove Hive files (optional)

### Step 5: Testing (4-6 hours)
Comprehensive testing:

- [ ] Unit tests for repositories
- [ ] Integration tests for CRUD
- [ ] Migration tests (Hive → Isar)
- [ ] Sync tests (online/offline)
- [ ] Performance tests
- [ ] Manual testing on devices

### Step 6: Web Compatibility (2-3 hours)
Handle web platform:

- [ ] Conditional imports for web
- [ ] Keep Hive for web OR use Isar with fallback
- [ ] Test web build
- [ ] Test web functionality

---

## 🏗️ ARCHITECTURE DECISIONS

### Web Strategy
**Option A: Keep Hive for Web** (Recommended)
```dart
// Conditional imports
export 'isar_service.dart' if (dart.library.html) 'hive_service.dart';
```

**Pros:**
- Isar on mobile (better performance)
- Hive on web (only option)
- Best of both worlds

**Cons:**
- Maintain two database implementations
- More complex codebase

**Option B: Isar Only** (Not Recommended)
- Breaks web support
- Need to disable web or find alternative

### Migration Strategy
**Option A: Big Bang** (All at once)
- Migrate everything in one session
- Fast but risky
- Requires extensive testing

**Option B: Incremental** (Model by model)
- Migrate one model at a time
- Slower but safer
- Easier to rollback

**Recommendation:** Incremental migration, starting with simplest model.

---

## 📊 MODEL COMPLEXITY

| Model | Complexity | Estimated Time | Dependencies |
|-------|------------|----------------|--------------|
| **Link** | Low | 1 hour | None |
| **Section** | Low | 1 hour | None |
| **MetronomePreset** | Low | 1 hour | None |
| **MetronomeState** | Low | 1 hour | Preset |
| **User** | Medium | 2 hours | None |
| **Band** | Medium | 3 hours | User |
| **Setlist** | High | 4 hours | Song, Band |
| **Song** | High | 6 hours | Link, Section |

**Total:** 19 hours (models only)

---

## 🔧 ISAR SETUP EXAMPLE

### Model Definition
```dart
import 'package:isar/isar.dart';

part 'song.g.dart';

@collection
class Song {
  Id id = Isar.autoIncrement;
  
  @Index()
  String songId = '';  // Original ID from Firestore
  
  String title = '';
  String artist = '';
  
  @Index()
  String? bandId;
  
  // Relationships
  final links = IsarLinks<Link>();
  final sections = IsarLinks<Section>();
  
  // Timestamps
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
}
```

### Isar Service
```dart
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

class IsarService {
  static final IsarService _instance = IsarService._internal();
  factory IsarService() => _instance;
  IsarService._internal();

  late Isar _isar;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [SongSchema, BandSchema, SetlistSchema],
      directory: dir.path,
    );
  }

  Isar get db => _isar;
}
```

---

## ⚠️ RISKS & MITIGATION

### Risk 1: Data Loss
**Mitigation:**
- Export all Hive data before migration
- Create backup script
- Test migration on copy first
- Keep Hive files until verified

### Risk 2: Web Incompatibility
**Mitigation:**
- Keep Hive for web (conditional imports)
- Or disable web temporarily
- Document limitation clearly

### Risk 3: Breaking Changes
**Mitigation:**
- Incremental migration
- Feature flags for testing
- Rollback plan ready
- Extensive testing before release

### Risk 4: Performance Regression
**Mitigation:**
- Benchmark before/after
- Test with large datasets
- Profile queries
- Optimize indexes

---

## 🧪 TESTING STRATEGY

### Unit Tests
- [ ] Model serialization
- [ ] Repository CRUD operations
- [ ] Query conditions
- [ ] Relationships

### Integration Tests
- [ ] Full CRUD flow
- [ ] Sync with Firestore
- [ ] Offline mode
- [ ] Conflict resolution

### Migration Tests
- [ ] Export Hive data
- [ ] Import to Isar
- [ ] Verify data integrity
- [ ] Test all features

### Performance Tests
- [ ] Query speed
- [ ] Insert/update speed
- [ ] Large dataset handling
- [ ] Memory usage

---

## 📅 TIMELINE

### Week 1: Setup & Simple Models
- Day 1-2: Setup, add packages, create Isar service
- Day 3-4: Migrate Link, Section models
- Day 5: Migrate MetronomePreset, MetronomeState

### Week 2: Core Models
- Day 1-2: Migrate User model
- Day 3-4: Migrate Band model
- Day 5: Migrate Song model (part 1)

### Week 3: Complex Models & Repositories
- Day 1-2: Migrate Song model (part 2), Setlist model
- Day 3-4: Migrate repositories
- Day 5: Data migration script

### Week 4: Testing & Polish
- Day 1-2: Unit tests, integration tests
- Day 3: Migration testing
- Day 4: Performance testing
- Day 5: Bug fixes, documentation

---

## 🎯 SUCCESS CRITERIA

Phase 3 is complete when:
- ✅ All models migrated to Isar
- ✅ All repositories updated
- ✅ Data migration script works
- ✅ All tests pass
- ✅ No data loss
- ✅ Performance improved or equal
- ✅ Web compatibility handled
- ✅ Documentation updated

---

## 🚀 GETTING STARTED

### First Steps:
1. Add Isar packages
2. Run flutter pub get
3. Create IsarService
4. Migrate simplest model (Link)
5. Test basic CRUD
6. Continue with next model

**Let's begin!** 🎉

---

**Last Updated:** March 10, 2026  
**Phase 3 Status:** 🔄 **STARTING**  
**Estimated Completion:** 3-4 weeks  
**Risk Level:** HIGH (manage with testing)
