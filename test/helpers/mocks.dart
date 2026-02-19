import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:flutter_repsync_app/models/user.dart';
import 'package:flutter_repsync_app/models/song.dart';
import 'package:flutter_repsync_app/models/band.dart';
import 'package:flutter_repsync_app/models/setlist.dart';

// Mock classes for Firebase services
class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock implements CollectionReference {}

class MockQuerySnapshot extends Mock implements QuerySnapshot {}

class MockCredential extends Mock implements UserCredential {}

// Mock HTTP client for API testing
class MockHttpClient extends Mock implements http.Client {}

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
    int? originalBPM,
    int? ourBPM,
    String? originalKey,
    String? ourKey,
    String? notes,
    List<String>? tags,
    String? spotifyUrl,
  }) {
    return Song(
      id: id,
      title: title,
      artist: artist,
      bandId: bandId,
      originalBPM: originalBPM,
      ourBPM: ourBPM,
      originalKey: originalKey,
      ourKey: ourKey,
      notes: notes,
      tags: tags ?? [],
      spotifyUrl: spotifyUrl,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );
  }

  static Band createMockBand({
    String id = 'test-band-id',
    String name = 'Test Band',
    String createdBy = 'test-user-id',
    String? description,
    List<BandMember>? members,
    String? inviteCode,
  }) {
    return Band(
      id: id,
      name: name,
      createdBy: createdBy,
      members: members ?? [],
      description: description,
      inviteCode: inviteCode,
      createdAt: DateTime(2024, 1, 1),
    );
  }

  static Setlist createMockSetlist({
    String id = 'test-setlist-id',
    String bandId = 'test-band-id',
    String name = 'Test Setlist',
    List<String>? songIds,
    String? description,
    String? eventDate,
  }) {
    return Setlist(
      id: id,
      bandId: bandId,
      name: name,
      songIds: songIds ?? [],
      description: description,
      eventDate: eventDate,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );
  }
}
