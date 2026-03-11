# 📋 ISAR MIGRATION TEMPLATES

**Use these templates to migrate models systematically.**

---

## TEMPLATE 1: Simple Model (No Relationships)

**Examples:** Section, MetronomePreset, MetronomeState, TimeSignature

```dart
import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'model_name.g.dart';

@collection
@JsonSerializable()
class ModelName {
  Id id = Isar.autoIncrement;
  
  @Index()
  String fieldName = '';
  
  int numberField = 0;
  
  bool boolField = false;
  
  String? nullableField;

  ModelName({
    this.id = Isar.autoIncrement,
    required this.fieldName,
    this.numberField = 0,
    this.boolField = false,
    this.nullableField,
  });

  factory ModelName.fromMap(Map<String, dynamic> data) => ModelName(
    id: data['id'] as int? ?? Isar.autoIncrement,
    fieldName: data['fieldName'] as String? ?? '',
    numberField: data['numberField'] as int? ?? 0,
    boolField: data['boolField'] as bool? ?? false,
    nullableField: data['nullableField'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'fieldName': fieldName,
    'numberField': numberField,
    'boolField': boolField,
    'nullableField': nullableField,
  };

  Map<String, dynamic> toJson() => _$ModelNameToJson(this);
  factory ModelName.fromJson(Map<String, dynamic> json) => _$ModelNameFromJson(json);
}
```

---

## TEMPLATE 2: Model with Lists

**Examples:** User (bandIds, baseTags)

```dart
import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'model_name.g.dart';

@collection
@JsonSerializable()
class ModelName {
  Id id = Isar.autoIncrement;
  
  @Index()
  String email = '';
  
  final bandIds = IsarLinks<int>(); // or List<String>
  final baseTags = <String>[];

  ModelName({
    this.id = Isar.autoIncrement,
    required this.email,
  });

  factory ModelName.fromMap(Map<String, dynamic> data) => ModelName(
    id: data['id'] as int? ?? Isar.autoIncrement,
    email: data['email'] as String? ?? '',
  )..bandIds.addAll((data['bandIds'] as List?)?.cast<int>() ?? [])
    ..baseTags.addAll((data['baseTags'] as List?)?.cast<String>() ?? []);

  Map<String, dynamic> toMap() => {
    'id': id,
    'email': email,
    'bandIds': bandIds.toList(),
    'baseTags': baseTags.toList(),
  };

  Map<String, dynamic> toJson() => _$ModelNameToJson(this);
  factory ModelName.fromJson(Map<String, dynamic> json) => _$ModelNameFromJson(json);
}
```

---

## TEMPLATE 3: Model with Embedded Objects

**Examples:** Song (links, sections), Band (members)

```dart
import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'model_name.g.dart';

@collection
@JsonSerializable()
class ModelName {
  Id id = Isar.autoIncrement;
  
  @Index()
  String title = '';
  
  final links = IsarLinks<Link>();
  final sections = IsarLinks<Section>();

  ModelName({
    this.id = Isar.autoIncrement,
    required this.title,
  });

  factory ModelName.fromMap(Map<String, dynamic> data) => ModelName(
    id: data['id'] as int? ?? Isar.autoIncrement,
    title: data['title'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
  };

  Map<String, dynamic> toJson() => _$ModelNameToJson(this);
  factory ModelName.fromJson(Map<String, dynamic> json) => _$ModelNameFromJson(json);
}
```

---

## MIGRATION CHECKLIST

For each model:

### Before Migration:
- [ ] Backup original file
- [ ] Identify model type (Simple/Lists/Embedded)
- [ ] Choose appropriate template

### Migration Steps:
1. [ ] Add Isar import: `import 'package:isar/isar.dart';`
2. [ ] Add `@collection` annotation before class
3. [ ] Change `final String id` → `Id id = Isar.autoIncrement`
4. [ ] Remove `final` from all fields
5. [ ] Add default values to all fields
6. [ ] Add `@Index()` to fields that should be indexed
7. [ ] Update constructor with default values
8. [ ] Add `fromMap()` factory method
9. [ ] Add `toMap()` method
10. [ ] Run build_runner
11. [ ] Test build

### After Migration:
- [ ] Run: `dart run build_runner build --delete-conflicting-outputs`
- [ ] Run: `flutter build web`
- [ ] Fix any compilation errors
- [ ] Test functionality

---

## QUICK REFERENCE: Field Type Conversions

| Hive Type | Isar Type | Default Value |
|-----------|-----------|---------------|
| `final String id` | `Id id` | `Isar.autoIncrement` |
| `final String field` | `String field` | `''` |
| `final int field` | `int field` | `0` |
| `final bool field` | `bool field` | `false` |
| `final double field` | `double field` | `0.0` |
| `final List<String>` | `final List<String>` | `<String>[]` |
| `String? field` | `String? field` | `null` (no change) |

---

## COMMON ISSUES & SOLUTIONS

### Issue: Constructor parameter must have default value
**Solution:** Add `= defaultValue` to all parameters
```dart
// BEFORE
ModelName({required this.field});

// AFTER
ModelName({this.field = ''});
```

### Issue: `final` fields can't be modified
**Solution:** Remove `final` keyword
```dart
// BEFORE
final String field;

// AFTER
String field = '';
```

### Issue: json_serializable can't generate code
**Solution:** Make sure all constructor parameters have defaults
```dart
// This works:
ModelName({this.field = ''});

// This doesn't:
ModelName({required this.field});
```

---

## NEXT MODELS TO MIGRATE

### Session 2: Simple Models (2-3 hours)
1. ✅ **Section** - Use Template 1
2. ✅ **MetronomePreset** - Use Template 1
3. ✅ **MetronomeState** - Use Template 1

### Session 3: Medium Models (3-4 hours)
4. ✅ **User** - Use Template 2 (has lists)
5. ✅ **TimeSignature** - Use Template 1

### Session 4: Complex Models (6-8 hours)
6. ⏳ **Band** - Use Template 3 (has nested objects)
7. ⏳ **Setlist** - Use Template 3 (has relationships)
8. ⏳ **Song** - Use Template 3 (most complex)

---

**Let's migrate the next model together!**
