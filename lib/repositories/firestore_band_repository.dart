import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/api_error.dart';
import '../models/band.dart';
import 'band_repository.dart';

/// Firestore implementation of [BandRepository].
///
/// Handles all band-related data operations with Firestore,
/// including personal band references and global band data.
class FirestoreBandRepository implements BandRepository {
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
    final user = _auth.currentUser;
    if (user == null) {
      throw ApiError.auth(
        message: 'Authentication required. Please sign in to continue.',
      );
    }
    return user.uid;
  }

  @override
  Future<void> saveBand(Band band, {String? uid}) async {
    try {
      final userId = uid ?? _currentUserId;
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('bands')
          .doc(band.id)
          .set(band.toJson());
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        throw ApiError.permission(
          message: 'You do not have permission to save this band.',
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
  Future<void> deleteBand(String bandId, {String? uid}) async {
    try {
      final userId = uid ?? _currentUserId;
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('bands')
          .doc(bandId)
          .delete();
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        throw ApiError.permission(
          message: 'You do not have permission to delete this band.',
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
  Stream<List<Band>> watchBands(String uid) {
    try {
      return _firestore
          .collection('users')
          .doc(uid)
          .collection('bands')
          .snapshots()
          .asyncMap((snapshot) async {
            final bandIds = snapshot.docs.map((doc) => doc.id).toList();

            if (bandIds.isEmpty) return <Band>[];

            final bands = <Band>[];
            for (final bandId in bandIds) {
              try {
                final bandDoc = await _firestore
                    .collection('bands')
                    .doc(bandId)
                    .get();
                if (bandDoc.exists) {
                  final data = bandDoc.data()!;
                  data['id'] = bandDoc.id;
                  bands.add(Band.fromJson(data));
                }
              } on FirebaseException catch (e) {
                if (e.code == 'not-found') {
                  continue;
                }
                rethrow;
              }
            }
            return bands;
          })
          .handleError((error, stackTrace) {
            throw ApiError.fromException(error, stackTrace: stackTrace);
          });
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> saveBandToGlobal(Band band) async {
    try {
      _requireAuth();
      await _firestore.collection('bands').doc(band.id).set(band.toJson());
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        throw ApiError.permission(
          message: 'You do not have permission to modify this band.',
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
  Future<Band?> getBandByInviteCode(String code) async {
    try {
      _requireAuth();
      final snapshot = await _firestore
          .collection('bands')
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      final data = doc.data();
      data['id'] = doc.id;
      return Band.fromJson(data);
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'not-found') {
        return null;
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  @override
  Future<bool> isInviteCodeTaken(String code) async {
    try {
      _requireAuth();
      final snapshot = await _firestore
          .collection('bands')
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } on FirebaseException catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> addUserToBand(String bandId, {String? userId}) async {
    try {
      final uid = userId ?? _currentUserId;
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('bands')
          .doc(bandId)
          .set({'bandId': bandId, 'joinedAt': FieldValue.serverTimestamp()});
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        throw ApiError.permission(
          message: 'You do not have permission to join this band.',
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
  Future<void> removeUserFromBand(String bandId, {String? userId}) async {
    try {
      final uid = userId ?? _currentUserId;
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('bands')
          .doc(bandId)
          .delete();
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        throw ApiError.permission(
          message: 'You do not have permission to leave this band.',
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
