// ignore_for_file: subtype_of_sealed_class, avoid_implementing_value_types
import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flowgroove/models/api_error.dart';
import 'package:flowgroove/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorage extends Mock implements FirebaseStorage {}
class _MockRef extends Mock implements Reference {}
class _MockSnapshot extends Mock implements TaskSnapshot {}
class _MockAuth extends Mock implements FirebaseAuth {}
class _MockUser extends Mock implements User {}
class _MockFirestore extends Mock implements FirebaseFirestore {}
class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}
class _MockDoc extends Mock implements DocumentReference<Map<String, dynamic>> {}
class _FakeFile extends Fake implements File {}
class _FakeSetOptions extends Fake implements SetOptions {}
class _FakeMetadata extends Fake implements SettableMetadata {}

/// A thin fake UploadTask that wraps a real `Future<TaskSnapshot>` so that
/// `await task` resolves properly without needing to mock Future internals.
class _FakeUploadTask implements UploadTask {
  _FakeUploadTask(this._future);
  final Future<TaskSnapshot> _future;

  @override
  Stream<TaskSnapshot> asStream() => _future.asStream();

  @override
  Future<TaskSnapshot> catchError(Function onError,
          {bool Function(Object)? test}) =>
      _future.catchError(onError, test: test);

  @override
  Future<S> then<S>(FutureOr<S> Function(TaskSnapshot) onValue,
          {Function? onError}) =>
      _future.then(onValue, onError: onError);

  @override
  Future<TaskSnapshot> timeout(Duration timeLimit,
          {FutureOr<TaskSnapshot> Function()? onTimeout}) =>
      _future.timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<TaskSnapshot> whenComplete(FutureOr<void> Function() action) =>
      _future.whenComplete(action);

  // Remaining UploadTask members — not used in these tests.
  @override
  Future<bool> cancel() => Future.value(false);

  @override
  Future<bool> pause() => Future.value(false);

  @override
  Future<bool> resume() => Future.value(false);

  @override
  TaskSnapshot get snapshot => throw UnimplementedError();

  @override
  Stream<TaskSnapshot> get snapshotEvents => throw UnimplementedError();

  @override
  FirebaseStorage get storage => throw UnimplementedError();
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeFile());
    registerFallbackValue(_FakeSetOptions());
    registerFallbackValue(_FakeMetadata());
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

    final rootRef = _MockRef();
    final midRef = _MockRef();
    when(() => storage.ref()).thenReturn(rootRef);
    when(() => rootRef.child('band_avatars')).thenReturn(midRef);
    when(() => midRef.child('b1')).thenReturn(ref);

    when(() => firestore.collection('bands')).thenReturn(bands);
    when(() => bands.doc('b1')).thenReturn(bandDoc);
  });

  StorageService service() =>
      StorageService(storage: storage, auth: auth, firestore: firestore);

  group('uploadBandAvatar', () {
    test('uploads file and writes photoURL to band doc', () async {
      final snap = _MockSnapshot();
      // Wrap snap in a _FakeUploadTask so `await ref.putFile(file)` resolves
      // to `snap` without needing to mock Future internals on UploadTask.
      when(() => ref.putFile(any(), any()))
          .thenAnswer((_) => _FakeUploadTask(Future.value(snap)));
      when(() => snap.ref).thenReturn(ref);
      when(() => ref.getDownloadURL())
          .thenAnswer((_) async => 'https://dl/b1.jpg');
      when(() => bandDoc.set(any(), any())).thenAnswer((_) async {});

      final url = await service().uploadBandAvatar(_FakeFile(), 'b1');

      expect(url, 'https://dl/b1.jpg');
      final captured =
          verify(() => bandDoc.set(captureAny(), any())).captured.single
              as Map<String, dynamic>;
      expect(captured['photoURL'], 'https://dl/b1.jpg');
      expect(captured.containsKey('updatedAt'), isTrue);
    });

    test('surfaces permission-denied as a permission ApiError', () async {
      when(() => ref.putFile(any(), any())).thenThrow(
          FirebaseException(plugin: 'storage', code: 'permission-denied'));

      await expectLater(
        () => service().uploadBandAvatar(_FakeFile(), 'b1'),
        throwsA(isA<ApiError>().having(
            (e) => e.type, 'type', ErrorType.permission)),
      );
    });
  });

  group('deleteBandAvatar', () {
    test('ignores not-found and clears photoURL', () async {
      when(() => ref.delete())
          .thenThrow(FirebaseException(plugin: 'storage', code: 'not-found'));
      when(() => bandDoc.set(any(), any())).thenAnswer((_) async {});

      await service().deleteBandAvatar('b1');

      final captured =
          verify(() => bandDoc.set(captureAny(), any())).captured.single
              as Map<String, dynamic>;
      expect(captured['photoURL'], isNull);
      expect(captured.containsKey('updatedAt'), isTrue);
    });
  });

  group('setAvatarFromGoogle', () {
    test('throws when the user has no Google photo', () async {
      when(() => user.photoURL).thenReturn(null);
      await expectLater(
        () => service().setAvatarFromGoogle(),
        throwsA(isA<ApiError>()),
      );
    });
  });
}
