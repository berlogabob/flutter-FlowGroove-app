import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/api_error.dart';

/// Service for handling Firebase Storage operations.
///
/// Provides methods for uploading, downloading, and deleting files
/// in Firebase Storage (profile pictures, band avatars, and custom paths).
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

  /// Helper method to check if user is authenticated.
  void _requireAuth() {
    if (_auth.currentUser == null) {
      throw ApiError.auth(
        message: 'Authentication required. Please sign in to continue.',
      );
    }
  }

  /// Get current user UID.
  String get _currentUserId {
    final user = _auth.currentUser;
    if (user == null) {
      throw ApiError.auth(
        message: 'Authentication required. Please sign in to continue.',
      );
    }
    return user.uid;
  }

  /// Upload a profile picture to Firebase Storage.
  ///
  /// The file is stored at: profile_pictures/{uid}.jpg
  ///
  /// Returns the download URL of the uploaded file.
  ///
  /// Throws [ApiError] if upload fails or user is not authenticated.
  Future<String> uploadProfilePicture(File file) async {
    try {
      _requireAuth();
      final uid = _currentUserId;

      // Create a reference to the file location
      final ref = _storage.ref().child('profile_pictures').child('$uid.jpg');

      // Upload the file
      final uploadTask = ref.putFile(file);

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update Firestore user document with the new photo URL
      await _firestore.collection('users').doc(uid).set({
        'photoURL': downloadUrl,
        'photoSource': 'upload',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update Firebase Auth profile
      await _auth.currentUser!.updatePhotoURL(downloadUrl);

      return downloadUrl;
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        throw ApiError.permission(
          message: 'You do not have permission to upload a profile picture.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// Delete the current user's profile picture.
  ///
  /// Removes the file from Firebase Storage and clears the photo URL
  /// from both Firestore and Firebase Auth.
  ///
  /// Throws [ApiError] if deletion fails or user is not authenticated.
  Future<void> deleteProfilePicture() async {
    try {
      _requireAuth();
      final uid = _currentUserId;

      // Create a reference to the file location
      final ref = _storage.ref().child('profile_pictures').child('$uid.jpg');

      // Delete the file if it exists
      try {
        await ref.delete();
      } on FirebaseException catch (e) {
        // Ignore not-found errors (file doesn't exist)
        if (e.code != 'not-found') rethrow;
      }

      // Update Firestore user document
      await _firestore.collection('users').doc(uid).set({
        'photoURL': null,
        'photoSource': null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update Firebase Auth profile
      await _auth.currentUser!.updatePhotoURL(null);
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        throw ApiError.permission(
          message:
              'You do not have permission to delete the profile picture.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// Get the profile picture URL for a user.
  ///
  /// First checks Firestore, then Firebase Auth profile.
  ///
  /// Returns null if no profile picture is set.
  Future<String?> getProfilePictureUrl(String uid) async {
    try {
      // Try to get from Firestore first
      final userDoc =
          await _firestore.collection('users').doc(uid).get();

      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null && data['photoURL'] != null) {
          return data['photoURL'] as String;
        }
      }

      // Fallback to Firebase Auth profile
      // Note: This only works for the current user
      if (uid == _auth.currentUser?.uid) {
        return _auth.currentUser?.photoURL;
      }

      return null;
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// Upload a band avatar to `band_avatars/{bandId}` (extension-less, so the
  /// Storage rule's {bandId} wildcard binds to the real band document id) and
  /// store the download URL on the band document. Caller must be a band admin
  /// (enforced by Storage + Firestore rules).
  Future<String> uploadBandAvatar(File file, String bandId) async {
    try {
      _requireAuth();
      // Stored without a file extension so the Storage rule's {bandId}
      // wildcard binds to the real band document id for the admin lookup.
      final ref = _storage.ref().child('band_avatars').child(bandId);
      final snapshot = await ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
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

  /// Delete a band avatar from Storage and clear `photoURL` on the band document.
  ///
  /// If the file does not exist in Storage the deletion is skipped silently.
  /// Throws [ApiError] if the caller lacks permission or another error occurs.
  Future<void> deleteBandAvatar(String bandId) async {
    try {
      _requireAuth();
      final ref = _storage.ref().child('band_avatars').child(bandId);
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

  /// Upload a file to a custom path in Firebase Storage.
  ///
  /// Use this for other file types beyond profile pictures.
  ///
  /// [path] should be the full path including filename (e.g., 'bands/{bandId}/songs/{songId}.pdf')
  ///
  /// Returns the download URL of the uploaded file.
  Future<String> uploadFile(File file, String path) async {
    try {
      _requireAuth();

      // Create a reference to the file location
      final ref = _storage.ref().child(path);

      // Upload the file
      final uploadTask = ref.putFile(file);

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get the download URL
      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        throw ApiError.permission(
          message: 'You do not have permission to upload this file.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// Delete a file from Firebase Storage.
  ///
  /// [path] should be the full path to the file.
  Future<void> deleteFile(String path) async {
    try {
      _requireAuth();

      // Create a reference to the file location
      final ref = _storage.ref().child(path);

      // Delete the file
      await ref.delete();
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'not-found') {
        // File doesn't exist, nothing to do
        return;
      }
      if (e.code == 'permission-denied') {
        throw ApiError.permission(
          message: 'You do not have permission to delete this file.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }
}
