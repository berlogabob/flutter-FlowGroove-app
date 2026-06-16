# Unified Avatar System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give users one coherent profile avatar (from file upload, Telegram, or Google) and give bands their own avatar, all stored in Firebase Storage as the single source of truth.

**Architecture:** Every avatar source resolves to a file in our own Storage bucket (`profile_pictures/{uid}.jpg`, `band_avatars/{bandId}.jpg`); Firestore `photoURL` always points at our bucket, never an external/token URL. Telegram import runs server-side in a callable Cloud Function so the bot token never leaves the server. Two reusable widgets (`UserAvatar`, `BandAvatar`) render `photoURL` with an initials fallback.

**Tech Stack:** Flutter, Riverpod, Firebase (Storage/Firestore/Auth/Functions), `json_serializable`/`build_runner`, `image_picker`, `cloud_functions`; Cloud Functions in Node 22 (gen1 `functions.https.onCall`, Telegraf), tested with mocha + `firebase-functions-test` against the Firestore emulator; Dart tests with `flutter_test` + `mocktail`.

**Reference spec:** `docs/superpowers/specs/2026-06-16-unified-avatar-system-design.md`

---

## File Structure

**Create:**
- `lib/widgets/user_avatar.dart` — reusable user avatar widget
- `lib/widgets/band_avatar.dart` — reusable band avatar widget
- `lib/services/avatar_function_service.dart` — Dart wrapper for the `importTelegramAvatar` callable
- `functions/src/avatars.js` — `importTelegramAvatar` callable (server-side Telegram mirror)
- `functions/test/callable-import-telegram-avatar.test.js` — function test
- `test/widgets/user_avatar_test.dart`, `test/widgets/band_avatar_test.dart`
- `test/services/storage_service_test.dart`

**Modify:**
- `lib/models/band.dart` (+ regenerate `band.g.dart`) — add `photoURL`
- `lib/models/user.dart` (+ regenerate `user.g.dart`) — add `photoSource`
- `lib/services/storage_service.dart` — injectable deps + `uploadBandAvatar`/`deleteBandAvatar`/`setAvatarFromGoogle`
- `functions/index.js` — export `importTelegramAvatar`; stop writing `telegramPhotoURL`
- `storage.rules` — add `band_avatars/{bandId}` path
- `lib/screens/profile_screen.dart` — wire avatar actions to Storage + migration
- `lib/screens/bands/the_band_screen.dart` — band avatar with admin-only edit

---

## Task 1: Add `photoURL` to the Band model

**Files:**
- Modify: `lib/models/band.dart`
- Regenerate: `lib/models/band.g.dart`
- Test: `test/models/band_test.dart` (create if missing)

- [ ] **Step 1: Write the failing test**

Create/append in `test/models/band_test.dart`:

```dart
import 'package:flowgroove/models/band.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Band.photoURL', () {
    test('round-trips through JSON', () {
      final band = Band(
        id: 'b1',
        name: 'The Band',
        createdBy: 'u1',
        createdAt: DateTime.utc(2026, 1, 1),
        photoURL: 'https://example.com/b1.jpg',
      );
      final json = band.toJson();
      expect(json['photoURL'], 'https://example.com/b1.jpg');
      expect(Band.fromJson(json).photoURL, 'https://example.com/b1.jpg');
    });

    test('copyWith can set and clear photoURL', () {
      final band = Band(
        id: 'b1', name: 'X', createdBy: 'u1', createdAt: DateTime.utc(2026),
        photoURL: 'https://example.com/a.jpg',
      );
      expect(band.copyWith(photoURL: 'https://example.com/b.jpg').photoURL,
          'https://example.com/b.jpg');
      expect(band.copyWith(photoURL: null).photoURL, isNull);
      expect(band.copyWith(name: 'Y').photoURL, 'https://example.com/a.jpg');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/band_test.dart`
Expected: FAIL — `Band` has no `photoURL` named parameter (compile error).

- [ ] **Step 3: Add the field**

In `lib/models/band.dart`, add the constructor param (after `this.description,`):

```dart
    this.description,
    this.photoURL,
```

Add the field declaration (after the `description` field):

```dart
  final String? description;
  final String? photoURL;
```

Add to `copyWith` signature (after `Object? description = _sentinel,`):

```dart
    Object? description = _sentinel,
    Object? photoURL = _sentinel,
```

Add to the `copyWith` return (after the `description:` line):

```dart
      description: description == _sentinel
          ? this.description
          : description as String?,
      photoURL: photoURL == _sentinel ? this.photoURL : photoURL as String?,
```

- [ ] **Step 4: Regenerate the serializer**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: regenerates `lib/models/band.g.dart` with `photoURL` in `_$BandFromJson`/`_$BandToJson`.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/models/band_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/models/band.dart lib/models/band.g.dart test/models/band_test.dart
git commit -m "feat(model): add photoURL to Band"
```

---

## Task 2: Add `photoSource` to the AppUser model

**Files:**
- Modify: `lib/models/user.dart`
- Regenerate: `lib/models/user.g.dart`
- Test: `test/models/user_test.dart`

- [ ] **Step 1: Write the failing test**

Append to `test/models/user_test.dart` inside `main()`:

```dart
  group('AppUser.photoSource', () {
    test('round-trips and copyWith clears via null', () {
      final user = AppUser(
        uid: 'u1',
        createdAt: DateTime.utc(2026),
        photoURL: 'https://example.com/u1.jpg',
        photoSource: 'telegram',
      );
      expect(user.toJson()['photoSource'], 'telegram');
      expect(AppUser.fromJson(user.toJson()).photoSource, 'telegram');
      expect(user.copyWith(photoSource: 'upload').photoSource, 'upload');
      expect(user.copyWith(photoSource: null).photoSource, isNull);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/user_test.dart`
Expected: FAIL — no `photoSource` parameter.

- [ ] **Step 3: Add the field**

In `lib/models/user.dart` constructor (after `this.photoURL,`):

```dart
    this.photoURL,
    this.photoSource,
```

Field declaration (after `final String? photoURL;`):

```dart
  final String? photoURL;
  final String? photoSource;
```

`copyWith` signature (after `Object? photoURL = _sentinel,`):

```dart
    Object? photoURL = _sentinel,
    Object? photoSource = _sentinel,
```

`copyWith` return (after the `photoURL:` line):

```dart
      photoURL: photoURL == _sentinel ? this.photoURL : photoURL as String?,
      photoSource: photoSource == _sentinel
          ? this.photoSource
          : photoSource as String?,
```

- [ ] **Step 4: Regenerate and run**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/models/user_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/user.dart lib/models/user.g.dart test/models/user_test.dart
git commit -m "feat(model): add photoSource to AppUser"
```

---

## Task 3: Make StorageService injectable

No behavior change — this enables unit testing in later tasks.

**Files:**
- Modify: `lib/services/storage_service.dart:13-16`

- [ ] **Step 1: Replace the field initializers with constructor injection**

Replace:

```dart
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
```

with:

```dart
class StorageService {
  StorageService({
    FirebaseStorage? storage,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
```

- [ ] **Step 2: Verify nothing broke**

Run: `flutter analyze lib/services/storage_service.dart`
Expected: No new errors. (All existing call sites use `StorageService()` with no args, which still works.)

- [ ] **Step 3: Commit**

```bash
git add lib/services/storage_service.dart
git commit -m "refactor(storage): allow dependency injection in StorageService"
```

---

## Task 4: Add band-avatar upload/delete to StorageService

**Files:**
- Modify: `lib/services/storage_service.dart`
- Test: `test/services/storage_service_test.dart` (create)

- [ ] **Step 1: Write the failing test**

Create `test/services/storage_service_test.dart`:

```dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flowgroove/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorage extends Mock implements FirebaseStorage {}
class _MockRef extends Mock implements Reference {}
class _MockUploadTask extends Mock implements UploadTask {}
class _MockSnapshot extends Mock implements TaskSnapshot {}
class _MockAuth extends Mock implements FirebaseAuth {}
class _MockUser extends Mock implements User {}
class _MockFirestore extends Mock implements FirebaseFirestore {}
class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}
class _MockDoc extends Mock implements DocumentReference<Map<String, dynamic>> {}
class _FakeFile extends Fake implements File {}
class _FakeSetOptions extends Fake implements SetOptions {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeFile());
    registerFallbackValue(_FakeSetOptions());
    registerFallbackValue(<String, dynamic>{});
  });

  late _MockStorage storage;
  late _MockAuth auth;
  late _MockFirestore firestore;
  late _MockUser user;
  late _MockRef ref;
  late _MockCollection bands;
  late _MockDoc bandDoc;

  setUp(() {
    storage = _MockStorage();
    auth = _MockAuth();
    firestore = _MockFirestore();
    user = _MockUser();
    ref = _MockRef();
    bands = _MockCollection();
    bandDoc = _MockDoc();

    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('u1');

    // storage.ref().child('band_avatars').child('b1.jpg')
    final rootRef = _MockRef();
    final midRef = _MockRef();
    when(() => storage.ref()).thenReturn(rootRef);
    when(() => rootRef.child('band_avatars')).thenReturn(midRef);
    when(() => midRef.child('b1.jpg')).thenReturn(ref);

    when(() => firestore.collection('bands')).thenReturn(bands);
    when(() => bands.doc('b1')).thenReturn(bandDoc);
    when(() => bandDoc.set(any(), any())).thenAnswer((_) async {});
  });

  StorageService service() =>
      StorageService(storage: storage, auth: auth, firestore: firestore);

  group('uploadBandAvatar', () {
    test('uploads file and writes photoURL to band doc', () async {
      final task = _MockUploadTask();
      final snap = _MockSnapshot();
      when(() => ref.putFile(any())).thenReturn(task);
      when(() => task.whenComplete(any())).thenAnswer((_) async => snap);
      when(() => snap.ref).thenReturn(ref);
      when(() => ref.getDownloadURL())
          .thenAnswer((_) async => 'https://dl/b1.jpg');

      final url = await service().uploadBandAvatar(_FakeFile(), 'b1');

      expect(url, 'https://dl/b1.jpg');
      final captured =
          verify(() => bandDoc.set(captureAny(), any())).captured.single
              as Map<String, dynamic>;
      expect(captured['photoURL'], 'https://dl/b1.jpg');
    });
  });

  group('deleteBandAvatar', () {
    test('ignores not-found and clears photoURL', () async {
      when(() => ref.delete())
          .thenThrow(FirebaseException(plugin: 'storage', code: 'not-found'));

      await service().deleteBandAvatar('b1');

      final captured =
          verify(() => bandDoc.set(captureAny(), any())).captured.single
              as Map<String, dynamic>;
      expect(captured['photoURL'], isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/storage_service_test.dart`
Expected: FAIL — `uploadBandAvatar`/`deleteBandAvatar` not defined.

- [ ] **Step 3: Implement the methods**

In `lib/services/storage_service.dart`, add after `deleteProfilePicture()`:

```dart
  /// Upload a band avatar to `band_avatars/{bandId}.jpg` and store the
  /// download URL on the band document. Caller must be a band admin
  /// (enforced by Storage + Firestore rules).
  Future<String> uploadBandAvatar(File file, String bandId) async {
    try {
      _requireAuth();
      final ref =
          _storage.ref().child('band_avatars').child('$bandId.jpg');
      final snapshot = await ref.putFile(file);
      final downloadUrl = await snapshot.ref.getDownloadURL();
      await _firestore.collection('bands').doc(bandId).set({
        'photoURL': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return downloadUrl;
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        throw ApiError.permission(
          message: 'Only band admins can change the band avatar.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// Delete a band avatar and clear `photoURL` on the band document.
  Future<void> deleteBandAvatar(String bandId) async {
    try {
      _requireAuth();
      final ref =
          _storage.ref().child('band_avatars').child('$bandId.jpg');
      try {
        await ref.delete();
      } on FirebaseException catch (e) {
        if (e.code != 'not-found') rethrow;
      }
      await _firestore.collection('bands').doc(bandId).set({
        'photoURL': null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        throw ApiError.permission(
          message: 'Only band admins can change the band avatar.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }
```

Note: the existing `uploadProfilePicture` uses `final uploadTask = ref.putFile(file); final snapshot = await uploadTask;` — `await ref.putFile(file)` is equivalent and is what the test stubs. Keep the `await ref.putFile(...)` form shown above.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/storage_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/storage_service.dart test/services/storage_service_test.dart
git commit -m "feat(storage): add band avatar upload/delete"
```

---

## Task 5: Add `setAvatarFromGoogle` to StorageService

Mirrors the Google account photo into our bucket via the existing `uploadProfilePicture`.

**Files:**
- Modify: `lib/services/storage_service.dart`
- Test: `test/services/storage_service_test.dart`

- [ ] **Step 1: Write the failing test**

Append inside `main()` in `test/services/storage_service_test.dart`:

```dart
  group('setAvatarFromGoogle', () {
    test('throws when the user has no Google photo', () async {
      when(() => user.photoURL).thenReturn(null);
      await expectLater(
        () => service().setAvatarFromGoogle(),
        throwsA(isA<Object>()),
      );
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/storage_service_test.dart -n setAvatarFromGoogle`
Expected: FAIL — `setAvatarFromGoogle` not defined.

- [ ] **Step 3: Implement**

Add this import near the top of `lib/services/storage_service.dart` (after the existing imports):

```dart
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
```

Add the method after `deleteBandAvatar`:

```dart
  /// Mirror the signed-in user's Google account photo into our bucket so the
  /// avatar has a stable URL we own. Sets photoSource = 'google'.
  Future<String> setAvatarFromGoogle() async {
    _requireAuth();
    final googleUrl = _auth.currentUser?.photoURL;
    if (googleUrl == null || googleUrl.isEmpty || !googleUrl.startsWith('http')) {
      throw ApiError.validation(
        message: 'No Google profile photo is available to import.',
      );
    }
    final response = await http
        .get(Uri.parse(googleUrl))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw ApiError.network(
        message: 'Could not download your Google photo. Please try again.',
      );
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/google_avatar.jpg');
    await file.writeAsBytes(response.bodyBytes);
    final url = await uploadProfilePicture(file);
    await _firestore.collection('users').doc(_currentUserId).set({
      'photoSource': 'google',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return url;
  }
```

Note: `uploadProfilePicture` already sets `photoSource: 'firebase'`; the follow-up `set` above overrides it to `'google'` for provenance. If `ApiError.validation`/`ApiError.network` do not exist, check `lib/models/api_error.dart` for the correct factory names and use the nearest equivalent (e.g. `ApiError.fromException`). Verify before implementing.

- [ ] **Step 4: Confirm `path_provider` is a dependency**

Run: `grep -n "path_provider" pubspec.yaml`
Expected: present (used by `profile_screen.dart`). If absent, stop and add it.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/services/storage_service_test.dart`
Expected: PASS (all groups).

- [ ] **Step 6: Commit**

```bash
git add lib/services/storage_service.dart test/services/storage_service_test.dart
git commit -m "feat(storage): mirror Google account photo into our bucket"
```

---

## Task 6: Add the band-avatar Storage rule

No automated test harness exists for Storage rules in this repo (only Firestore rules), so this task ends with a manual verification checkpoint.

**Files:**
- Modify: `storage.rules`

- [ ] **Step 1: Add the rule**

In `storage.rules`, add a `band_avatars` match block before the catch-all `match /{allPaths=**}`:

```
    match /band_avatars/{bandId} {
      allow read: if request.auth != null;
      allow write, delete: if request.auth != null &&
        firestore.get(/databases/(default)/documents/bands/$(bandId))
          .data.adminUids.hasAny([request.auth.uid]);
    }
    match /{allPaths=**} {
      allow read, write: if false;
    }
```

- [ ] **Step 2: Validate rules syntax**

Run: `firebase deploy --only storage --dry-run` (or `firebase emulators:start --only storage` and confirm it loads without parse errors).
Expected: rules compile with no syntax error.

- [ ] **Step 3: Commit**

```bash
git add storage.rules
git commit -m "feat(rules): allow band admins to write band_avatars"
```

> **Checkpoint (manual):** After deploy, verify a band admin can upload to
> `band_avatars/{bandId}.jpg` and a non-admin member is denied.

---

## Task 7: `importTelegramAvatar` Cloud Function

Server-side mirror of the user's Telegram profile photo. The bot token stays on the server.

**Files:**
- Create: `functions/src/avatars.js`
- Modify: `functions/index.js`
- Test: `functions/test/callable-import-telegram-avatar.test.js`

- [ ] **Step 1: Write the failing test**

Create `functions/test/callable-import-telegram-avatar.test.js`:

```js
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const functionsTestFactory = require("firebase-functions-test");

const projectId = "repsync-app-callable-test";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || projectId;
process.env.FIREBASE_CONFIG = process.env.FIREBASE_CONFIG ||
  JSON.stringify({ projectId });

const functionsTest = functionsTestFactory({ projectId });
const { makeImportTelegramAvatar } = require("../src/avatars");
const db = admin.firestore();

function buildSubject(overrides = {}) {
  const saved = [];
  const fakeBucket = {
    name: "test-bucket",
    file: () => ({
      save: async (buf, opts) => { saved.push({ buf, opts }); },
    }),
  };
  const fakeTelegram = {
    getUserProfilePhotos: async () => ({
      total_count: 1,
      photos: [[{ file_id: "file-1" }]],
    }),
    getFileLink: async () => "https://telegram/file-1.jpg",
  };
  const fn = makeImportTelegramAvatar({
    getTelegram: () => overrides.telegram || fakeTelegram,
    getBucket: () => overrides.bucket || fakeBucket,
    fetchImpl: overrides.fetchImpl ||
      (async () => ({ arrayBuffer: async () => new ArrayBuffer(4) })),
  });
  return { fn: functionsTest.wrap(fn), saved };
}

async function clearUsers() {
  const snap = await db.collection("users").get();
  await Promise.all(snap.docs.map((d) => d.ref.delete()));
}

describe("importTelegramAvatar callable", function () {
  this.timeout(20000);
  beforeEach(clearUsers);
  after(async () => { await clearUsers(); functionsTest.cleanup(); });

  it("rejects unauthenticated callers", async () => {
    const { fn } = buildSubject();
    await assert.rejects(() => fn({}, {}),
      (e) => e.code === "unauthenticated");
  });

  it("fails when the user has no telegramId", async () => {
    await db.collection("users").doc("u1").set({ displayName: "A" });
    const { fn } = buildSubject();
    await assert.rejects(
      () => fn({}, { auth: { uid: "u1" } }),
      (e) => e.code === "failed-precondition",
    );
  });

  it("fails when Telegram has no photo", async () => {
    await db.collection("users").doc("u1").set({ telegramId: "123" });
    const { fn } = buildSubject({
      telegram: {
        getUserProfilePhotos: async () => ({ total_count: 0, photos: [] }),
      },
    });
    await assert.rejects(
      () => fn({}, { auth: { uid: "u1" } }),
      (e) => e.code === "not-found",
    );
  });

  it("mirrors the photo and updates the user doc", async () => {
    await db.collection("users").doc("u1").set({ telegramId: "123" });
    const { fn, saved } = buildSubject();
    const result = await fn({}, { auth: { uid: "u1" } });

    assert.equal(saved.length, 1);
    assert.match(result.photoURL, /firebasestorage\.googleapis\.com/);
    const doc = await db.collection("users").doc("u1").get();
    assert.equal(doc.data().photoSource, "telegram");
    assert.equal(doc.data().photoURL, result.photoURL);
    assert.equal(doc.data().telegramPhotoURL, undefined);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd functions && npm run test:callables`
Expected: FAIL — `../src/avatars` cannot be found.

- [ ] **Step 3: Implement the function**

Create `functions/src/avatars.js`:

```js
const crypto = require("crypto");
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { defineString } = require("firebase-functions/params");
const { Telegram } = require("telegraf");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const TELEGRAM_BOT_TOKEN = defineString("TELEGRAM_BOT_TOKEN");

function defaultTelegram() {
  return new Telegram(TELEGRAM_BOT_TOKEN.value());
}

function defaultBucket() {
  return admin.storage().bucket();
}

/**
 * Builds the `importTelegramAvatar` callable. Dependencies are injectable for
 * testing. In production the Telegram client and Storage bucket use the real
 * bot token / default bucket.
 */
function makeImportTelegramAvatar({ getTelegram, getBucket, fetchImpl } = {}) {
  return functions.https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Request must be authenticated.",
      );
    }
    const uid = context.auth.uid;
    const userRef = db.collection("users").doc(uid);
    const snap = await userRef.get();
    const telegramId = snap.exists ? snap.data().telegramId : null;
    if (!telegramId) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Telegram is not linked to this account.",
      );
    }

    const telegram = (getTelegram || defaultTelegram)();
    const photos = await telegram.getUserProfilePhotos(Number(telegramId), {
      limit: 1,
    });
    if (!photos || !photos.total_count) {
      throw new functions.https.HttpsError(
        "not-found",
        "No Telegram profile photo found.",
      );
    }

    const fileId = photos.photos[0][0].file_id;
    const fileLink = await telegram.getFileLink(fileId);
    const fetchFn = fetchImpl || fetch;
    const res = await fetchFn(fileLink.toString());
    const buffer = Buffer.from(await res.arrayBuffer());

    const bucket = (getBucket || defaultBucket)();
    const filePath = `profile_pictures/${uid}.jpg`;
    const token = crypto.randomUUID();
    await bucket.file(filePath).save(buffer, {
      contentType: "image/jpeg",
      metadata: { metadata: { firebaseStorageDownloadTokens: token } },
    });

    const photoURL =
      `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
      `${encodeURIComponent(filePath)}?alt=media&token=${token}`;

    await userRef.set({
      photoURL,
      photoSource: "telegram",
      telegramPhotoURL: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return { photoURL };
  });
}

exports.makeImportTelegramAvatar = makeImportTelegramAvatar;
exports.importTelegramAvatar = makeImportTelegramAvatar();
```

- [ ] **Step 4: Wire the export**

In `functions/index.js`, after the existing band exports (around line 435):

```js
const avatars = require("./src/avatars");
exports.importTelegramAvatar = avatars.importTelegramAvatar;
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd functions && npm run test:callables`
Expected: PASS (the four new cases, plus existing callable tests still pass).

- [ ] **Step 6: Commit**

```bash
git add functions/src/avatars.js functions/index.js functions/test/callable-import-telegram-avatar.test.js
git commit -m "feat(functions): importTelegramAvatar mirrors TG photo server-side"
```

---

## Task 8: Stop the bot from writing the token URL

Removes the bot-token leak: `/link` no longer saves `telegramPhotoURL`.

**Files:**
- Modify: `functions/index.js` (the link callback handler, ~lines 89-123)

- [ ] **Step 1: Locate and edit the handler**

In `functions/index.js`, in the consent/link callback handler that fetches the
profile photo, remove the photo-fetch block and the `telegramPhotoURL` write.
Specifically:

- Delete the `ctx.telegram.getUserProfilePhotos(...)` / `getFile(...)` block and
  the `telegramPhotoURL` local (the lines building
  `https://api.telegram.org/file/bot${TELEGRAM_BOT_TOKEN.value()}/...`).
- In the Firestore update, remove the `telegramPhotoURL: telegramPhotoURL,` line.
- Replace the conditional reply that depended on the photo with the
  no-photo variant unconditionally:

```js
const replyMsg =
  `✅ *Готово!*\n\nИмпортируем:\n• Имя: \`${telegramUsername}\`\n\n` +
  `Фото можно импортировать в приложении: Profile → Avatar → Use Telegram Photo.\n\n` +
  `Есть вопросы? Пишите в поддержку!`;
```

- [ ] **Step 2: Verify the bot file still parses**

Run: `cd functions && node -e "require('./index.js'); console.log('ok')"`
Expected: prints `ok` (no syntax error). (Token params resolve lazily; requiring the module should not throw.)

- [ ] **Step 3: Commit**

```bash
git add functions/index.js
git commit -m "fix(functions): stop persisting Telegram token URL on link"
```

---

## Task 9: `UserAvatar` widget

**Files:**
- Create: `lib/widgets/user_avatar.dart`
- Test: `test/widgets/user_avatar_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/widgets/user_avatar_test.dart`:

```dart
import 'package:flowgroove/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows initials when no photoURL', (tester) async {
    await tester.pumpWidget(host(
      const UserAvatar(photoURL: null, displayName: 'Andre Berloga'),
    ));
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('uses NetworkImage when photoURL is an http url', (tester) async {
    await tester.pumpWidget(host(
      const UserAvatar(
        photoURL: 'https://example.com/u1.jpg',
        displayName: 'Andre',
      ),
    ));
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isA<NetworkImage>());
  });

  testWidgets('falls back to ? when name is empty', (tester) async {
    await tester.pumpWidget(host(
      const UserAvatar(photoURL: null, displayName: ''),
    ));
    expect(find.text('?'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/user_avatar_test.dart`
Expected: FAIL — `user_avatar.dart` does not exist.

- [ ] **Step 3: Implement the widget**

Create `lib/widgets/user_avatar.dart`:

```dart
import 'package:flutter/material.dart';

/// Renders a user's avatar from [photoURL], falling back to the first letter
/// of [displayName]. Always reads from a network URL — local-file avatars are
/// no longer used (everything is mirrored to Firebase Storage).
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    required this.photoURL,
    required this.displayName,
    this.radius = 24,
    super.key,
  });

  final String? photoURL;
  final String? displayName;
  final double radius;

  String get _initial {
    final name = displayName?.trim() ?? '';
    return name.isEmpty ? '?' : name.characters.first.toUpperCase();
  }

  bool get _hasPhoto => photoURL != null && photoURL!.startsWith('http');

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: _hasPhoto ? NetworkImage(photoURL!) : null,
      child: _hasPhoto
          ? null
          : Text(
              _initial,
              style: TextStyle(
                fontSize: radius * 0.8,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/user_avatar_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/user_avatar.dart test/widgets/user_avatar_test.dart
git commit -m "feat(widget): add UserAvatar"
```

---

## Task 10: `BandAvatar` widget

**Files:**
- Create: `lib/widgets/band_avatar.dart`
- Test: `test/widgets/band_avatar_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/widgets/band_avatar_test.dart`:

```dart
import 'package:flowgroove/widgets/band_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows band initial when no photoURL', (tester) async {
    await tester.pumpWidget(host(
      const BandAvatar(photoURL: null, bandName: 'Nightcrawlers'),
    ));
    expect(find.text('N'), findsOneWidget);
  });

  testWidgets('uses NetworkImage when photoURL is set', (tester) async {
    await tester.pumpWidget(host(
      const BandAvatar(
        photoURL: 'https://example.com/b1.jpg',
        bandName: 'Nightcrawlers',
      ),
    ));
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isA<NetworkImage>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/band_avatar_test.dart`
Expected: FAIL — `band_avatar.dart` does not exist.

- [ ] **Step 3: Implement the widget**

Create `lib/widgets/band_avatar.dart`:

```dart
import 'package:flutter/material.dart';

/// Renders a band's avatar from [photoURL], falling back to the first letter
/// of [bandName]. Uses a rounded-square shape to distinguish bands from users.
class BandAvatar extends StatelessWidget {
  const BandAvatar({
    required this.photoURL,
    required this.bandName,
    this.radius = 24,
    super.key,
  });

  final String? photoURL;
  final String? bandName;
  final double radius;

  String get _initial {
    final name = bandName?.trim() ?? '';
    return name.isEmpty ? '?' : name.characters.first.toUpperCase();
  }

  bool get _hasPhoto => photoURL != null && photoURL!.startsWith('http');

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: _hasPhoto ? NetworkImage(photoURL!) : null,
      child: _hasPhoto
          ? null
          : Text(
              _initial,
              style: TextStyle(
                fontSize: radius * 0.8,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/band_avatar_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/band_avatar.dart test/widgets/band_avatar_test.dart
git commit -m "feat(widget): add BandAvatar"
```

---

## Task 11: Dart wrapper for the Telegram-import callable

**Files:**
- Create: `lib/services/avatar_function_service.dart`

- [ ] **Step 1: Implement the service**

Create `lib/services/avatar_function_service.dart` (mirrors `band_function_service.dart`):

```dart
import 'package:cloud_functions/cloud_functions.dart';

import '../models/api_error.dart';

/// Calls the `importTelegramAvatar` Cloud Function, which mirrors the user's
/// Telegram profile photo into our Storage bucket and returns the new URL.
class AvatarFunctionService {
  AvatarFunctionService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  /// Returns the new `photoURL`. Throws [ApiError] on failure
  /// (e.g. not linked, no photo).
  Future<String> importTelegramAvatar() async {
    try {
      final callable = _functions.httpsCallable('importTelegramAvatar');
      final result = await callable.call<Map<String, dynamic>>();
      final url = result.data['photoURL'] as String?;
      if (url == null) {
        throw ApiError.unknown(message: 'No photo URL returned.');
      }
      return url;
    } on FirebaseFunctionsException catch (e, stackTrace) {
      if (e.code == 'failed-precondition') {
        throw ApiError.validation(
          message: 'Link your Telegram account first.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      if (e.code == 'not-found') {
        throw ApiError.validation(
          message: 'No Telegram profile photo was found.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }
}
```

Note: verify the exact `ApiError` factory names in `lib/models/api_error.dart`
(`unknown`/`validation`/`fromException`) and match the signatures used in
`band_function_service.dart`. Adjust if they differ.

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/services/avatar_function_service.dart`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/services/avatar_function_service.dart
git commit -m "feat(service): AvatarFunctionService for Telegram import callable"
```

---

## Task 12: Wire the profile screen to Storage (+ migrate local photo)

Replace local-only avatar handling with Storage-backed flows.

**Files:**
- Modify: `lib/screens/profile_screen.dart`

- [ ] **Step 1: Replace `_pickPhoto` to upload to Storage**

In `lib/screens/profile_screen.dart`, replace the body of `_pickPhoto` (lines
147-173) so that after picking it uploads via `StorageService`:

```dart
  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      setState(() => _photoSource = 'upload');
      final url =
          await StorageService().uploadProfilePicture(File(pickedFile.path));
      if (!mounted) return;
      setState(() {
        _profilePhotoPath = null;
        _telegramPhotoURL = url;
        _photoSource = 'upload';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading photo: $e')),
        );
      }
    }
  }
```

Add the import at the top if missing:

```dart
import '../../services/storage_service.dart';
```

(`_telegramPhotoURL` is reused as "the network photo URL to display"; the avatar
rendering already prefers it. If the screen tracks the displayed URL under a
different field, set that one instead — confirm by reading the avatar build code
in this file before editing.)

- [ ] **Step 2: Replace `_removePhoto` to delete from Storage**

```dart
  Future<void> _removePhoto() async {
    try {
      await StorageService().deleteProfilePicture();
      if (!mounted) return;
      setState(() {
        _profilePhotoPath = null;
        _telegramPhotoURL = null;
        _photoSource = 'upload';
      });
    } catch (e) {
      debugPrint('Error removing photo: $e');
    }
  }
```

- [ ] **Step 3: Make the Telegram option import server-side**

In `_showPhotoOptions`, change the Telegram `onTap` branch that currently does
`setState(() { _photoSource = 'telegram'; ... })` to call the callable:

```dart
              onTap: () async {
                Navigator.pop(context);
                final hasTelegram = _telegramId != null; // see Step 5
                if (!hasTelegram) {
                  _showTelegramLinkDialog();
                  return;
                }
                try {
                  final url = await AvatarFunctionService().importTelegramAvatar();
                  if (!mounted) return;
                  setState(() {
                    _telegramPhotoURL = url;
                    _photoSource = 'telegram';
                    _profilePhotoPath = null;
                  });
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Telegram import failed: $e')),
                    );
                  }
                }
              },
```

Add import:

```dart
import '../../services/avatar_function_service.dart';
```

- [ ] **Step 4: Add a "Use Google Photo" option**

In `_showPhotoOptions`, add a `ListTile` (after the Telegram tile) shown only
when the user is Google-linked:

```dart
            if (FirebaseAuth.instance.currentUser?.providerData
                .any((p) => p.providerId == 'google.com') ??
                false)
              ListTile(
                leading: const Icon(Icons.account_circle),
                title: const Text('Use Google Photo'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final url = await StorageService().setAvatarFromGoogle();
                    if (!mounted) return;
                    setState(() {
                      _telegramPhotoURL = url;
                      _photoSource = 'google';
                      _profilePhotoPath = null;
                    });
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Google import failed: $e')),
                      );
                    }
                  }
                },
              ),
```

Add import if missing:

```dart
import 'package:firebase_auth/firebase_auth.dart';
```

- [ ] **Step 5: Track `telegramId` and migrate the legacy local photo**

In `_loadTelegramProfile()` (where the user doc is read), also capture
`telegramId` into a new state field and run the one-time local→Storage
migration. Add the field near the other state fields:

```dart
  String? _telegramId;
```

In the doc-read block, after reading data, add:

```dart
        _telegramId = data?['telegramId'] as String?;
        final existingUrl = data?['photoURL'] as String?;
        if (existingUrl != null) {
          _telegramPhotoURL = existingUrl;
          _photoSource = (data?['photoSource'] as String?) ?? 'upload';
        } else {
          // One-time migration: upload a legacy local photo to Storage.
          final dir = await getApplicationDocumentsDirectory();
          final legacy = File('${dir.path}/profile_photo.jpg');
          if (await legacy.exists()) {
            try {
              final url =
                  await StorageService().uploadProfilePicture(legacy);
              await legacy.delete();
              _telegramPhotoURL = url;
              _photoSource = 'upload';
            } catch (e) {
              debugPrint('Avatar migration skipped: $e');
            }
          }
        }
```

(Confirm `getApplicationDocumentsDirectory`/`File`/`path_provider` imports are
already present in this file — they are, per existing `_pickPhoto`.)

- [ ] **Step 6: Analyze and run the existing profile tests**

Run: `flutter analyze lib/screens/profile_screen.dart`
Expected: no errors.
Run: `flutter test` (full suite) and confirm nothing regressed.

- [ ] **Step 7: Manual verification checkpoint**

Launch the app (`/run` skill or `flutter run`). Verify: pick from gallery →
avatar uploads and survives a restart; "Use Telegram Photo" (when linked)
imports; "Use Google Photo" (when Google-linked) imports; Remove clears it.

- [ ] **Step 8: Commit**

```bash
git add lib/screens/profile_screen.dart
git commit -m "feat(profile): Storage-backed avatar (upload/Telegram/Google) + migration"
```

---

## Task 13: Band avatar UI (admin-only edit)

**Files:**
- Modify: `lib/screens/bands/the_band_screen.dart`

- [ ] **Step 1: Read the screen to find the header and admin check**

Run: `grep -n "BandMember.roleAdmin\|adminUids\|isAdmin\|AppBar\|band.name\|Band band\|ref.watch" lib/screens/bands/the_band_screen.dart`
Identify (a) where the band header/title renders and (b) how the screen already
determines whether the current user is an admin. Reuse the existing admin check;
do not invent a new one.

- [ ] **Step 2: Render `BandAvatar` in the header**

Add the import:

```dart
import '../../widgets/band_avatar.dart';
```

Place a `BandAvatar` in the band header:

```dart
BandAvatar(photoURL: band.photoURL, bandName: band.name, radius: 32),
```

- [ ] **Step 3: Add an admin-only edit affordance**

Wrap/adjoin the avatar with an edit button visible only to admins, opening a
bottom sheet with "Change avatar" (gallery) and "Remove avatar":

```dart
if (isCurrentUserAdmin) // reuse the existing admin boolean from Step 1
  IconButton(
    icon: const Icon(Icons.edit),
    tooltip: 'Change band avatar',
    onPressed: () => _showBandAvatarOptions(context, band),
  ),
```

Add the handler method to the screen's State class:

```dart
  Future<void> _showBandAvatarOptions(BuildContext context, Band band) async {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Change avatar'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final picked = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 512,
                  maxHeight: 512,
                  imageQuality: 85,
                );
                if (picked == null) return;
                try {
                  await StorageService()
                      .uploadBandAvatar(File(picked.path), band.id);
                  if (mounted) setState(() {});
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Upload failed: $e')),
                    );
                  }
                }
              },
            ),
            if (band.photoURL != null)
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Remove avatar'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  try {
                    await StorageService().deleteBandAvatar(band.id);
                    if (mounted) setState(() {});
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Remove failed: $e')),
                      );
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
```

Add imports if missing:

```dart
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../services/storage_service.dart';
```

(If `the_band_screen` is a `ConsumerWidget` without State, lift these into a
`ConsumerStatefulWidget` or place the handler where `setState`/`ref` is
available — match the file's existing widget style; check in Step 1.)

- [ ] **Step 4: Analyze and run tests**

Run: `flutter analyze lib/screens/bands/the_band_screen.dart`
Expected: no errors.
Run: `flutter test`
Expected: green.

- [ ] **Step 5: Manual verification checkpoint**

As a band admin, change and remove the band avatar; confirm a non-admin member
sees the avatar but no edit affordance.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/bands/the_band_screen.dart
git commit -m "feat(bands): admin-editable band avatar"
```

---

## Task 14: Final full-suite verification

- [ ] **Step 1: Dart tests + analyze**

Run: `flutter analyze`
Run: `flutter test`
Expected: no errors, all green.

- [ ] **Step 2: Function tests**

Run: `cd functions && npm test`
Expected: callable + rules + migration suites pass.

- [ ] **Step 3: Commit any final fixups**

```bash
git add -A
git commit -m "chore(avatar): final verification fixups"
```

---

## Self-Review Notes

- **Spec coverage:** storage layout (Tasks 4/7), Band.photoURL (1), AppUser.photoSource (2), mirror external photos (5 Google / 7 Telegram), stop token-URL leak (7 writes clean URL + deletes field, 8 bot stops writing it), band-admin-only perms (6 rules + 13 UI), resize/compress only (12/13 use `image_picker` maxWidth/imageQuality, no crop dep), `UserAvatar`/`BandAvatar` (9/10), profile rewrite + migration (12), band screen UI (13), error handling via `ApiError` (4/5/11), tests (1/2/4/5/7/9/10 + manual checkpoints for rules/UI).
- **Known verification points flagged inline:** exact `ApiError` factory names; the profile screen's actual "displayed URL" field name; the band screen's existing admin check and widget style. Each task says to confirm before editing rather than assuming.
- **Out of scope (YAGNI), not planned:** crop UI, avatar history, multi-image.
