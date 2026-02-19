import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_repsync_app/models/user.dart';
import 'package:flutter_repsync_app/models/song.dart';
import 'package:flutter_repsync_app/models/band.dart';
import 'package:flutter_repsync_app/models/setlist.dart';

// Mock classes for Firebase services
class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock implements CollectionReference {}

class MockDocumentReference extends Mock implements DocumentReference {}

class MockQuerySnapshot extends Mock implements QuerySnapshot {}

class MockDocumentSnapshot extends Mock implements DocumentSnapshot {}

class MockCredential extends Mock implements UserCredential {}

// Mock data helpers
class MockDataHelper {
  static AppUser createMockAppUser({
    String uid = 'test-user-id',
    String? displayName = 'Test User',
    String? email = 'test@example.com',
    List<String>? bandIds,
  }) {
    return AppUser(
      uid: uid,
      displayName: displayName,
      email: email,
      bandIds: bandIds ?? [],
      createdAt: DateTime(2024, 1, 1),
    );
  }

  static Song createMockSong({
    String id = 'test-song-id',
    String title = 'Test Song',
    String artist = 'Test Artist',
    String? bandId,
  }) {
    return Song(
      id: id,
      title: title,
      artist: artist,
      bandId: bandId,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );
  }

  static Band createMockBand({
    String id = 'test-band-id',
    String name = 'Test Band',
    String createdBy = 'test-user-id',
    List<BandMember>? members,
  }) {
    return Band(
      id: id,
      name: name,
      createdBy: createdBy,
      members: members ?? [],
      createdAt: DateTime(2024, 1, 1),
    );
  }

  static Setlist createMockSetlist({
    String id = 'test-setlist-id',
    String bandId = 'test-band-id',
    String name = 'Test Setlist',
    List<String>? songIds,
  }) {
    return Setlist(
      id: id,
      bandId: bandId,
      name: name,
      songIds: songIds ?? [],
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );
  }
}
