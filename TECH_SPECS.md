# Technical Specifications

**Project:** Flutter RepSync App  
**Version:** v1.0.0+1  
**Date:** February 25, 2026

---

## Sprint 1: Song Addition Bug Fix

### Problem Statement
Song addition causes loader hang due to:
- Missing timeout on Firestore calls
- No AsyncValue error handling
- Silent failures

### Technical Solution

#### 1.1 Firestore Timeout Implementation

**File:** `lib/repositories/firestore_song_repository.dart`

```dart
Future<void> saveSong(Song song, String uid) async {
  try {
    await firestoreService
        .collection('users')
        .doc(uid)
        .collection('songs')
        .doc(song.id)
        .set(song.toJson())
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('[SongRepository] Timeout saving song: ${song.id}');
            throw TimeoutException('Firestore save timeout after 10s');
          },
        );
  } catch (e, st) {
    debugPrint('[SongRepository] Error saving song: $e');
    debugPrint('[SongRepository] Stack: $st');
    rethrow;
  }
}
```

#### 1.2 AsyncValue Error Handling

**File:** `lib/providers/data/data_providers.dart`

```dart
class CachedSongsNotifier extends Notifier<AsyncValue<List<Song>>> {
  @override
  AsyncValue<List<Song>> build() {
    return const AsyncValue.loading();
  }

  Future<void> addSong(Song song) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(songRepositoryProvider);
      await repo.saveSong(song, uid: currentUser.uid);
      
      // Update local state
      final current = state.value ?? [];
      state = AsyncValue.data([...current, song]);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      // Auto-clear error after 5s
      Future.delayed(const Duration(seconds: 5), () {
        if (state.hasError) {
          state = const AsyncValue.loading();
        }
      });
    }
  }
}
```

#### 1.3 UI Error Display

**File:** `lib/screens/bands/band_screen.dart`

```dart
@override
Widget build(BuildContext context) {
  final songsAsync = ref.watch(cachedSongsProvider);
  
  return songsAsync.when(
    data: (songs) => SongList(songs: songs),
    loading: () => const CircularProgressIndicator(),
    error: (error, stack) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $error'),
            backgroundColor: Colors.red,
          ),
        );
      });
      return SongList(songs: []);
    },
  );
}
```

### Testing Strategy

```dart
// test/providers/cached_songs_notifier_test.dart
test('addSong handles timeout error', () async {
  final notifier = CachedSongsNotifier();
  final mockRepo = MockSongRepository();
  
  when(mockRepo.saveSong(any, uid: any(named: 'uid')))
    .thenThrow(TimeoutException('Timeout'));
  
  await notifier.addSong(testSong);
  
  expect(notifier.state.hasError, true);
});
```

---

## Sprint 2: Calendar Date Picker

### Data Model Changes

**File:** `lib/models/setlist.dart`

```dart
@JsonSerializable()
class Setlist {
  // ... existing fields ...
  
  @JsonKey(
    name: 'date',
    fromJson: _parseDateTime,
    toJson: _dateTimeToJson,
  )
  final DateTime? date;
  
  // Keep eventDate for backward compatibility (deprecated)
  @Deprecated('Use date instead')
  final String? eventDate;
  
  Setlist({
    // ... existing params ...
    this.date,
    @Deprecated('Use date instead') this.eventDate,
  });
  
  // Update copyWith
  Setlist copyWith({
    // ... existing params ...
    DateTime? date,
  }) {
    return Setlist(
      // ... existing ...
      date: date ?? this.date,
    );
  }
}
```

### Firestore Conversion

**File:** `lib/repositories/firestore_setlist_repository.dart`

```dart
Future<void> saveSetlist(Setlist setlist, String uid) async {
  final data = setlist.toJson();
  
  // Convert DateTime to Timestamp for Firestore
  if (setlist.date != null) {
    data['date'] = Timestamp.fromDate(setlist.date!);
  }
  
  await firestore.collection('users').doc(uid).collection('setlists').doc(setlist.id).set(data);
}

Setlist _setlistFromFirestore(Map<String, dynamic> data, String id) {
  // Convert Timestamp to DateTime
  DateTime? date;
  if (data['date'] is Timestamp) {
    date = (data['date'] as Timestamp).toDate();
  }
  
  return Setlist(
    id: id,
    // ... other fields ...
    date: date,
  );
}
```

### UI Implementation

**File:** `lib/screens/setlists/setlist_edit_screen.dart`

```dart
Future<void> _pickDate() async {
  final picked = await showDatePicker(
    context: context,
    initialDate: widget.setlist.date ?? DateTime.now(),
    firstDate: DateTime.now().subtract(const Duration(days: 365)),
    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
  );
  
  if (picked != null) {
    ref.read(setlistNotifierProvider.notifier).updateDate(picked);
  }
}

@override
Widget build(BuildContext context) {
  return ListTile(
    leading: const Icon(Icons.calendar_today),
    title: const Text('Дата'),
    subtitle: Text(
      widget.setlist.date != null
        ? DateFormat('dd MMMM yyyy', 'ru_RU').format(widget.setlist.date!)
        : 'Не выбрана',
    ),
    onTap: _pickDate,
  );
}
```

---

## Sprint 3: User Base Tags System

### Data Model

**File:** `lib/models/user.dart`

```dart
@JsonSerializable()
class AppUser {
  // ... existing fields ...
  
  @JsonKey(defaultValue: [])
  final List<String> baseTags;
  
  AppUser({
    // ... existing params ...
    this.baseTags = const [],
  });
  
  AppUser copyWith({
    // ... existing params ...
    List<String>? baseTags,
  }) {
    return AppUser(
      // ... existing ...
      baseTags: baseTags ?? this.baseTags,
    );
  }
}
```

### Repository Interface

**File:** `lib/repositories/user_repository.dart`

```dart
abstract class UserRepository {
  Future<AppUser?> getUser(String uid);
  Future<void> saveUser(AppUser user);
  Future<void> updateBaseTags(String uid, List<String> tags);
  Stream<AppUser?> watchUser(String uid);
}
```

### Firestore Implementation

**File:** `lib/repositories/firestore_user_repository.dart`

```dart
class FirestoreUserRepository implements UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  @override
  Future<AppUser?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromJson(doc.data()!);
  }
  
  @override
  Future<void> saveUser(AppUser user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toJson());
  }
  
  @override
  Future<void> updateBaseTags(String uid, List<String> tags) async {
    await _firestore.collection('users').doc(uid).update({
      'baseTags': tags,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  
  @override
  Stream<AppUser?> watchUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromJson(doc.data()!);
    });
  }
}
```

### Provider Implementation

**File:** `lib/providers/user_provider.dart`

```dart
class UserNotifier extends StateNotifier<AsyncValue<AppUser?>> {
  final UserRepository _repo;
  
  UserNotifier(this._repo) : super(const AsyncValue.loading());
  
  Future<void> loadProfile(String uid) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.getUser(uid);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  Future<void> addTag(String tag) async {
    final user = state.value;
    if (user == null) return;
    
    final newTags = [...user.baseTags, tag];
    await _repo.updateBaseTags(user.uid, newTags);
    
    state = AsyncValue.data(user.copyWith(baseTags: newTags));
  }
  
  Future<void> removeTag(String tag) async {
    final user = state.value;
    if (user == null) return;
    
    final newTags = user.baseTags.where((t) => t != tag).toList();
    await _repo.updateBaseTags(user.uid, newTags);
    
    state = AsyncValue.data(user.copyWith(baseTags: newTags));
  }
}

final userNotifierProvider = StateNotifierProvider<UserNotifier, AsyncValue<AppUser?>>((ref) {
  return UserNotifier(FirestoreUserRepository());
});
```

### UI Implementation

**File:** `lib/screens/profile/profile_screen.dart`

```dart
@override
Widget build(BuildContext context) {
  final userAsync = ref.watch(userNotifierProvider);
  
  return userAsync.when(
    data: (user) {
      if (user == null) return const SizedBox();
      
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...user.baseTags.map((tag) => FilterChip(
            label: Text(tag),
            onDeleted: () => ref.read(userNotifierProvider.notifier).removeTag(tag),
          )),
          IconButton(
            icon: const Icon(Icons.add_circle),
            onPressed: () => _showAddTagDialog(user),
          ),
        ],
      );
    },
    loading: () => const CircularProgressIndicator(),
    error: (e, st) => Text('Error: $e'),
  );
}

Future<void> _showAddTagDialog(AppUser user) async {
  final controller = TextEditingController();
  
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Добавить тег'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(hintText: 'Название тега'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () {
            if (controller.text.isNotEmpty) {
              ref.read(userNotifierProvider.notifier).addTag(controller.text);
            }
            Navigator.pop(context);
          },
          child: const Text('Добавить'),
        ),
      ],
    ),
  );
}
```

---

## Sprint 4: Band/Setlist Roles

### Band Model Update

**File:** `lib/models/band.dart`

```dart
@JsonSerializable()
class Band {
  // ... existing fields ...
  
  /// Map of memberId -> list of role tags
  /// Example: {"user123": ["vocals", "guitar"], "user456": ["bass"]}
  @JsonKey(defaultValue: {})
  final Map<String, List<String>> memberRoles;
  
  Band({
    // ... existing params ...
    this.memberRoles = const {},
  });
  
  Band copyWith({
    // ... existing params ...
    Map<String, List<String>>? memberRoles,
  }) {
    return Band(
      // ... existing ...
      memberRoles: memberRoles ?? this.memberRoles,
    );
  }
}
```

### Setlist Model Update

**File:** `lib/models/setlist.dart`

```dart
@JsonSerializable()
class Setlist {
  // ... existing fields ...
  
  /// Nested map: songId -> {userId -> roleOverride}
  /// Example: {"song1": {"user123": "lead_vocals", "user456": "backup_vocals"}}
  @JsonKey(defaultValue: {})
  final Map<String, Map<String, String>> assignments;
  
  Setlist({
    // ... existing params ...
    this.assignments = const {},
  });
  
  /// Get unique participants with their roles
  List<Participant> getParticipants(List<BandMember> bandMembers) {
    final participantMap = <String, Participant>{};
    
    // Collect all assignments across all songs
    assignments.forEach((songId, userRoleMap) {
      userRoleMap.forEach((userId, role) {
        if (!participantMap.containsKey(userId)) {
          final bandMember = bandMembers.firstWhere(
            (m) => m.uid == userId,
            orElse: () => BandMember(uid: userId, role: 'member'),
          );
          participantMap[userId] = Participant(
            uid: userId,
            displayName: bandMember.displayName,
            roles: {},
          );
        }
        participantMap[userId]!.roles.add(role);
      });
    });
    
    return participantMap.values.toList();
  }
}

class Participant {
  final String uid;
  final String? displayName;
  final Set<String> roles;
  
  Participant({
    required this.uid,
    this.displayName,
    required this.roles,
  });
}
```

### UI: Role Assignment

**File:** `lib/screens/bands/band_edit_screen.dart`

```dart
Widget _buildRoleSelector(String memberId) {
  final availableRoles = ref.watch(userBaseTagsProvider);
  final currentRoles = widget.band.memberRoles[memberId] ?? [];
  
  return Wrap(
    spacing: 8,
    children: [
      ...availableRoles.map((role) => FilterChip(
        label: Text(role),
        selected: currentRoles.contains(role),
        onSelected: (selected) {
          final newRoles = selected
            ? [...currentRoles, role]
            : currentRoles.where((r) => r != role).toList();
          
          ref.read(bandNotifierProvider.notifier).updateMemberRoles(
            memberId,
            newRoles,
          );
        },
      )),
    ],
  );
}
```

---

## Sprint 5: Song Tags + Tag Cloud

### Tag Service

**File:** `lib/services/tag_service.dart`

```dart
class TagService {
  final SongRepository _songRepo;
  
  TagService(this._songRepo);
  
  /// Get tag frequency cloud from songs
  /// Limited to 100 most recent songs for performance
  Future<Map<String, int>> getTagCloud(String bandId) async {
    final songs = await _songRepo.getBandSongs(bandId).take(100).toList();
    
    final tagFrequency = <String, int>{};
    
    for (final song in songs) {
      for (final tag in song.tags) {
        tagFrequency[tag] = (tagFrequency[tag] ?? 0) + 1;
      }
    }
    
    // Sort by frequency descending
    final sorted = Map.fromEntries(
      tagFrequency.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)),
    );
    
    return sorted;
  }
  
  /// Filter songs by tag
  List<Song> filterByTag(List<Song> songs, String tag) {
    return songs.where((s) => s.tags.contains(tag)).toList();
  }
}
```

### TextFieldTags Integration

**File:** `lib/screens/songs/song_edit_screen.dart`

```dart
import 'package:textfield_tags/textfield_tags.dart';

TextFieldTags(
  initialTags: widget.song.tags,
  textSeparators: const [' ', ','],
  letterCase: LetterCase.normal,
  validator: (tag) {
    if (tag.isEmpty) {
      return 'Tag cannot be empty';
    }
    return null;
  },
  onTag: (tag) {
    ref.read(songNotifierProvider.notifier).addTag(tag);
  },
  onDelete: (tag) {
    ref.read(songNotifierProvider.notifier).removeTag(tag);
  },
  inputFieldBuilder: (context, inputFieldValues) {
    return TextField(
      controller: inputFieldValues.textEditingController,
      focusNode: inputFieldValues.focusNode,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: 'Tags',
        hintText: 'Add tags...',
        helperText: inputFieldValues.error,
      ),
      onChanged: inputFieldValues.onTagChanged,
      onSubmitted: inputFieldValues.onSubmitted,
    );
  },
);
```

---

## Sprint 6: Export Integration

### PDF Service Update

**File:** `lib/services/export/pdf_service.dart`

```dart
static Future<void> exportSetlist({
  required Setlist setlist,
  required List<Song> songs,
  required List<BandMember> bandMembers,
  bool includeParticipants = false,
}) async {
  final pdf = pw.Document();
  
  pdf.addPage(
    pw.MultiPage(
      build: (context) => [
        if (includeParticipants) ...[
          _buildParticipantsTable(setlist, bandMembers),
          pw.SizedBox(height: 40),
        ],
        ...songs.asMap().entries.map((entry) => _buildSongRow(entry.index, entry.value)),
      ],
    ),
  );
  
  await Printing.layoutPdf(
    onLayout: (format) async => pdf.save(),
    name: '${setlist.name}_setlist.pdf',
  );
}

static pw.Widget _buildParticipantsTable(
  Setlist setlist,
  List<BandMember> bandMembers,
) {
  final participants = setlist.getParticipants(bandMembers);
  
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey300),
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
        children: [
          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Участник')),
          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Роли')),
          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Песни')),
        ],
      ),
      ...participants.map((p) => pw.TableRow(
        children: [
          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(p.displayName ?? 'Unknown')),
          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(p.roles.join(', '))),
          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${p.roles.length}')),
        ],
      )),
    ],
  );
}
```

---

## Appendix: File Modification Summary

| Sprint | Files to Modify | Files to Create |
|--------|----------------|-----------------|
| 1 | 4 | 0 |
| 2 | 4 | 0 |
| 3 | 4 | 3 |
| 4 | 6 | 0 |
| 5 | 5 | 1 |
| 6 | 3 | 0 |
| **Total** | **26** | **4** |

---

**Document Version:** 1.0  
**Last Updated:** February 25, 2026
