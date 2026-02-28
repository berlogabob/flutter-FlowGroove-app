import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/api_error.dart';
import '../models/setlist.dart';
import 'setlist_repository.dart';

class FirestoreSetlistRepository implements SetlistRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirestoreSetlistRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  void _requireAuth() {
    if (_currentUserId == null) {
      throw ApiError.auth(message: 'Authentication required');
    }
  }

  @override
  Future<void> saveSetlist(Setlist setlist, {String? uid}) async {
    try {
      final userId = uid ?? _currentUserId;
      _requireAuth();

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('setlists')
          .doc(setlist.id)
          .set(setlist.toJson());
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> deleteSetlist(String setlistId, {String? uid}) async {
    try {
      final userId = uid ?? _currentUserId;
      _requireAuth();

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('setlists')
          .doc(setlistId)
          .delete();
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
          .map((snapshot) {
            try {
              return snapshot.docs.map((doc) {
                try {
                  return Setlist.fromJson(doc.data());
                } catch (e) {
                  debugPrint('❌ Failed to parse setlist ${doc.id}: $e');
                  return Setlist(
                    id: doc.id,
                    bandId: '',
                    name: doc.data()['name'] ?? 'Unknown',
                    description: 'Parse error: ${e.toString()}',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                }
              }).toList();
            } catch (e) {
              debugPrint('❌ Failed to map snapshot: $e');
              return <Setlist>[];
            }
          })
          .handleError((error, stackTrace) {
            debugPrint('❌ Stream error: $error');
            throw ApiError.fromException(error, stackTrace: stackTrace);
          });
    } catch (e, stackTrace) {
      debugPrint('❌ watchSetlists exception: $e');
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }
}
