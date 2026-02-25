import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/api_error.dart';
import '../models/setlist.dart';
import 'setlist_repository.dart';

/// Firestore implementation of [SetlistRepository].
///
/// Handles all setlist-related data operations with Firestore.
class FirestoreSetlistRepository implements SetlistRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Helper method to check if user is authenticated.
  void _requireAuth() {
    if (_auth.currentUser == null) {
      throw ApiError.auth(
        message: 'Authentication required. Please sign in to continue.',
      );
    }
  }

  /// Helper method to get current user UID.
  String get _currentUserId {
    _requireAuth();
    return _auth.currentUser!.uid;
  }

  @override
  Future<void> saveSetlist(Setlist setlist, {String? uid}) async {
    try {
      final userId = uid ?? _currentUserId;
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('setlists')
          .doc(setlist.id)
          .set(setlist.toJson());
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        throw ApiError.permission(
          message: 'You do not have permission to save this setlist.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> deleteSetlist(String setlistId, {String? uid}) async {
    try {
      final userId = uid ?? _currentUserId;
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('setlists')
          .doc(setlistId)
          .delete();
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        throw ApiError.permission(
          message: 'You do not have permission to delete this setlist.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  @override
  Stream<List<Setlist>> watchSetlists(String uid) {
    try {
      return _firestore
          .collection('users')
          .doc(uid)
          .collection('setlists')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => Setlist.fromJson(doc.data()))
                .toList(),
          )
          .handleError((error, stackTrace) {
            throw ApiError.fromException(error, stackTrace: stackTrace);
          });
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }
}
