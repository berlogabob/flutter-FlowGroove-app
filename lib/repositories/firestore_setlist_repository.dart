import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/api_error.dart';
import '../models/event_suggestion.dart';
import 'firestore_timeout.dart';
import '../models/setlist.dart';
import '../services/analytics_service.dart';
import 'setlist_repository.dart';

class FirestoreSetlistRepository implements SetlistRepository {
  FirestoreSetlistRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static const _initialLoadTimeout = Duration(seconds: 15);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _currentUserId => _auth.currentUser?.uid;

  void _requireAuth() {
    if (_currentUserId == null) {
      throw ApiError.auth(message: 'Authentication required');
    }
  }

  @override
  Future<void> saveSetlist(Setlist setlist, {String? uid}) async {
    // Scope is derived from the data, never trusted from the caller: a
    // setlist carrying a bandId saved personally is invisible in BOTH lists
    // (the personal list filters bandId != ''). Route it to the band
    // collection instead of writing a stray.
    if (setlist.bandId.isNotEmpty) {
      return saveBandSetlist(setlist, setlist.bandId);
    }
    try {
      final userId = uid ?? _currentUserId;
      _requireAuth();

      await withFirestoreTimeout(
        'saveSetlist ${setlist.id}',
        () => _firestore
            .collection('users')
            .doc(userId)
            .collection('setlists')
            .doc(setlist.id)
            // merge + toJsonForSave: a replacing set() here deletes any field
            // this build does not know about — which is exactly how a
            // setlist's event grants were wiped on 2026-08-21 by an older
            // client saving normally.
            .set(setlist.toJsonForSave(), SetOptions(merge: true)),
      );
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
      _requireAuth();

      await withFirestoreTimeout(
        'deleteSetlist $setlistId',
        () => _firestore
            .collection('users')
            .doc(userId)
            .collection('setlists')
            .doc(setlistId)
            .delete(),
      );
      unawaited(AnalyticsService.logSetlistDeleted(setlistId: setlistId));
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
          .map((snapshot) {
            try {
              return snapshot.docs.map<Setlist?>((doc) {
                try {
                  return Setlist.fromJson(doc.data());
                } catch (e) {
                  // Skip it rather than fabricate an empty, editable setlist:
                  // saving that placeholder would overwrite the real data.
                  debugPrint('❌ Failed to parse setlist ${doc.id}: $e');
                  return null;
                }
              }).whereType<Setlist>()
                  // Personal list only: hide band setlists that were
                  // mis-saved into this collection (they carry a bandId and
                  // their band-copy song ids read as all-"Unavailable" here).
                  .where((s) => s.bandId.isEmpty)
                  .toList();
            } catch (e) {
              debugPrint('❌ Failed to map snapshot: $e');
              return <Setlist>[];
            }
          })
          .handleError((Object error, StackTrace stackTrace) {
            debugPrint('❌ Stream error: $error');
            throw ApiError.fromException(error, stackTrace: stackTrace);
          });
    } catch (e, stackTrace) {
      debugPrint('❌ watchSetlists exception: $e');
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> saveBandSetlist(Setlist setlist, String bandId) async {
    try {
      _requireAuth();

      await withFirestoreTimeout(
        'saveBandSetlist ${setlist.id} in band $bandId',
        () => _firestore
            .collection('bands')
            .doc(bandId)
            .collection('setlists')
            .doc(setlist.id)
            // merge: see saveSetlist above. Never a replacing set().
            .set(
              setlist.copyWith(bandId: bandId).toJsonForSave(),
              SetOptions(merge: true),
            ),
      );
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        throw ApiError.permission(
          message: 'You do not have permission to save this band setlist.',
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
  Future<void> deleteBandSetlist(String bandId, String setlistId) async {
    try {
      _requireAuth();

      await withFirestoreTimeout(
        'deleteBandSetlist $setlistId in band $bandId',
        () => _firestore
            .collection('bands')
            .doc(bandId)
            .collection('setlists')
            .doc(setlistId)
            .delete(),
      );
      unawaited(AnalyticsService.logSetlistDeleted(setlistId: setlistId));
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        throw ApiError.permission(
          message: 'You do not have permission to delete this band setlist.',
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
  Future<void> updateEventKitArea({
    required String setlistId,
    required String area,
    required Object? value,
    String? bandId,
    String? uid,
  }) async {
    assert(
      area == 'stage' || area == 'rider' || area == 'people',
      'unknown event kit area "$area"',
    );
    try {
      _requireAuth();
      final doc = bandId != null
          ? _firestore
                .collection('bands')
                .doc(bandId)
                .collection('setlists')
                .doc(setlistId)
          : _firestore
                .collection('users')
                .doc(uid ?? _currentUserId)
                .collection('setlists')
                .doc(setlistId);
      await withFirestoreTimeout(
        'updateEventKitArea $area on $setlistId',
        () => doc.update({
          'eventKit.$area': value,
          'updatedAt': DateTime.now().toIso8601String(),
        }),
      );
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        throw ApiError.permission(
          message: 'You do not have permission to change the $area.',
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
  Stream<List<Setlist>> watchBandSetlists(String bandId) {
    try {
      final stream = _firestore
          .collection('bands')
          .doc(bandId)
          .collection('setlists')
          .snapshots()
          .map((snapshot) {
            try {
              return snapshot.docs.map<Setlist?>((doc) {
                try {
                  final data = doc.data();
                  return Setlist.fromJson({...data, 'id': doc.id});
                } catch (e) {
                  // Skip, don't fabricate an editable placeholder (see above).
                  debugPrint('❌ Failed to parse band setlist ${doc.id}: $e');
                  return null;
                }
              }).whereType<Setlist>().toList();
            } catch (e) {
              debugPrint('❌ Failed to map band setlists snapshot: $e');
              return <Setlist>[];
            }
          })
          .handleError((Object error, StackTrace stackTrace) {
            debugPrint('❌ Band setlists stream error: $error');
            throw ApiError.fromException(error, stackTrace: stackTrace);
          });
      return _withInitialTimeout(stream);
    } catch (e, stackTrace) {
      debugPrint('❌ watchBandSetlists exception: $e');
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// Events [uid] is a guest on, across every band — without being a member of
  /// any of them.
  ///
  /// Reads the user's OWN `eventInvites` index rather than querying setlists.
  /// A guest cannot list a band's setlists and nothing in a setlist tells them
  /// which band it belongs to, so this used to be a collection-group query on a
  /// `guestUids` field. That required a `match /{path=**}/setlists/…` rule which
  /// also matched every user's personal setlists — and it put the grant on a
  /// document clients rewrite, which is how a real setlist lost its grants on
  /// 2026-08-21. The index is written by the events callables and is scoped to
  /// its owner by construction: no shared index, no collection-group rule.
  ///
  /// The returned Setlists are LIST-CARD shaped (name, date, location). Opening
  /// one reads the real setlist document, which the grant permits.
  Stream<List<Setlist>> watchGuestEvents(String uid) {
    try {
      final stream = _firestore
          .collection('users')
          .doc(uid)
          .collection('eventInvites')
          .snapshots()
          .map((snapshot) {
            final out = <Setlist>[];
            for (final doc in snapshot.docs) {
              try {
                final data = doc.data();
                out.add(
                  Setlist(
                    id: data['setlistId'] as String? ?? doc.id,
                    bandId: data['bandId'] as String? ?? '',
                    name: data['name'] as String? ?? 'Event',
                    eventDateTime: _parseInviteDate(data['eventDateTime']),
                    eventLocation: data['eventLocation'] as String?,
                    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
                  ),
                );
              } catch (e) {
                debugPrint('❌ Failed to parse event invite ${doc.id}: $e');
              }
            }
            return out;
          })
          .handleError((Object error, StackTrace stackTrace) {
            debugPrint('❌ Guest events stream error: $error');
            throw ApiError.fromException(error, stackTrace: stackTrace);
          });
      return _withInitialTimeout(stream);
    } catch (e, stackTrace) {
      debugPrint('❌ watchGuestEvents exception: $e');
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  @override
  Stream<List<EventSuggestion>> watchSetlistSuggestions(
    String bandId,
    String setlistId,
  ) {
    return _firestore
        .collection('bands')
        .doc(bandId)
        .collection('setlists')
        .doc(setlistId)
        .collection('suggestions')
        .snapshots()
        .map((snap) {
          final all = [
            for (final doc in snap.docs)
              EventSuggestion.fromJson(doc.data(), id: doc.id),
          ];
          all.sort((a, b) {
            // Open first — the inbox exists to be emptied — then newest.
            if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
            final at = a.createdAt, bt = b.createdAt;
            if (at == null || bt == null) return 0;
            return bt.compareTo(at);
          });
          return all;
        })
        // A non-member reaching this gets permission-denied. An empty inbox is
        // the honest answer rather than an error banner over a screen whose
        // real content loaded fine.
        .handleError((Object error, StackTrace stackTrace) {
          debugPrint('❌ suggestions stream error: $error');
        });
  }

  Stream<List<Setlist>> _withInitialTimeout(Stream<List<Setlist>> source) {
    late StreamController<List<Setlist>> controller;
    StreamSubscription<List<Setlist>>? subscription;
    Timer? timer;
    var receivedFirstValue = false;

    controller = StreamController<List<Setlist>>(
      onListen: () {
        timer = Timer(_initialLoadTimeout, () {
          if (receivedFirstValue || controller.isClosed) return;
          controller.addError(
            ApiError.network(
              message: 'Shared setlists took too long to load. Please retry.',
            ),
          );
          subscription?.cancel();
        });
        subscription = source.listen(
          (setlists) {
            receivedFirstValue = true;
            timer?.cancel();
            controller.add(setlists);
          },
          onError: (Object error, StackTrace stackTrace) {
            timer?.cancel();
            controller.addError(error, stackTrace);
          },
          onDone: () {
            timer?.cancel();
            controller.close();
          },
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () async {
        timer?.cancel();
        await subscription?.cancel();
      },
    );

    return controller.stream;
  }
}

/// `eventInvites` stores the event date the way the app writes it on the
/// setlist — an ISO-8601 string — but tolerate a Timestamp in case a server
/// path ever writes one. Returning null just means the card shows no date.
DateTime? _parseInviteDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}
