import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/api_error.dart';
import '../models/rehearsal.dart';
import 'rehearsal_repository.dart';

class FirestoreRehearsalRepository implements RehearsalRepository {
  FirestoreRehearsalRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  void _requireAuth() {
    if (_auth.currentUser == null) {
      throw ApiError.auth(message: 'Authentication required');
    }
  }

  CollectionReference<Map<String, dynamic>> _col(String bandId) => _firestore
      .collection('bands')
      .doc(bandId)
      .collection('rehearsals');

  @override
  Stream<List<Rehearsal>> watchRehearsals(String bandId) {
    return _col(bandId).snapshots().map((snap) {
      return snap.docs
          .map((doc) {
            try {
              return Rehearsal.fromJson({...doc.data(), 'id': doc.id});
            } catch (e) {
              debugPrint('❌ Failed to parse rehearsal ${doc.id}: $e');
              return null;
            }
          })
          .whereType<Rehearsal>()
          .toList();
    }).handleError((Object error, StackTrace stackTrace) {
      debugPrint('❌ watchRehearsals stream error: $error');
      throw ApiError.fromException(error, stackTrace: stackTrace);
    });
  }

  @override
  Stream<Rehearsal?> watchRehearsal(String bandId, String rehearsalId) {
    return _col(bandId).doc(rehearsalId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Rehearsal.fromJson({...doc.data()!, 'id': doc.id});
    }).handleError((Object error, StackTrace stackTrace) {
      throw ApiError.fromException(error, stackTrace: stackTrace);
    });
  }

  @override
  Stream<Map<String, RehearsalVote>> watchVotes(String bandId, String rehearsalId) {
    return _col(bandId)
        .doc(rehearsalId)
        .collection('votes')
        .snapshots()
        .map((snap) {
          final votes = <String, RehearsalVote>{};
          for (final doc in snap.docs) {
            try {
              votes[doc.id] = RehearsalVote.fromJson({
                ...doc.data(),
                'uid': doc.id,
              });
            } catch (e) {
              debugPrint('❌ Failed to parse vote ${doc.id}: $e');
            }
          }
          return votes;
        })
        .handleError((Object error, StackTrace stackTrace) {
          throw ApiError.fromException(error, stackTrace: stackTrace);
        });
  }

  @override
  Future<void> saveRehearsal(Rehearsal rehearsal) async {
    try {
      _requireAuth();
      await _col(rehearsal.bandId)
          .doc(rehearsal.id)
          .set(rehearsal.toJson());
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> deleteRehearsal(String bandId, String rehearsalId) async {
    try {
      _requireAuth();
      await _col(bandId).doc(rehearsalId).delete();
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> saveVote(String bandId, String rehearsalId, RehearsalVote vote) async {
    try {
      _requireAuth();
      await _col(bandId)
          .doc(rehearsalId)
          .collection('votes')
          .doc(vote.uid)
          .set(vote.toJson());
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }
}
