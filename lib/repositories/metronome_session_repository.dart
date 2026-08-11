import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/metronome_session.dart';

/// Practice sessions, stored per user in Firestore.
///
/// These used to live only in the local Hive box [boxName], which meant a
/// reinstall or a second device lost every streak and logbook entry. Firestore
/// offline persistence is enabled app-wide (see main.dart), so moving here
/// keeps offline writes working and adds cross-device sync — no second store
/// to reconcile. The Hive box is still opened, but only so
/// [migrateLocalSessions] can upload what it already holds.
class MetronomeSessionRepository {
  MetronomeSessionRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _injectedFirestore = firestore,
      _injectedAuth = auth;

  /// Legacy local box. Read once by [migrateLocalSessions], never written.
  static const String boxName = 'metronome_sessions_v1';

  /// Whether the legacy Hive box is open (migration source only).
  static bool storageReady = false;

  static const _migratedKey = 'practice_sessions.migrated_to_firestore';

  /// ponytail: newest 500 sessions, not the whole history. Covers the 7-day
  /// window, the 30-entry logbook and any realistic streak. Page or aggregate
  /// server-side if someone ever needs lifetime totals.
  static const _fetchLimit = 500;

  final FirebaseFirestore? _injectedFirestore;
  final FirebaseAuth? _injectedAuth;

  // Resolved lazily: this repository is constructed inside providers that
  // widget tests build without ever calling Firebase.initializeApp, and
  // touching `.instance` in the constructor threw for all of them.
  FirebaseFirestore? get _firestore {
    try {
      return _injectedFirestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseAuth? get _auth {
    try {
      return _injectedAuth ?? FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _sessions {
    final uid = _auth?.currentUser?.uid;
    if (uid == null) return null;
    return _firestore
        ?.collection('users')
        .doc(uid)
        .collection('practiceSessions');
  }

  Future<void> save(MetronomeSession session) async {
    final sessions = _sessions;
    if (sessions == null) return;
    await sessions.doc(session.id).set(session.toJson());
  }

  Future<List<MetronomeSession>> listAll() async {
    final sessions = _sessions;
    if (sessions == null) return const [];
    // startedAt is an ISO-8601 string, so lexicographic order is chronological.
    final snapshot = await sessions
        .orderBy('startedAt', descending: true)
        .limit(_fetchLimit)
        .get();
    return snapshot.docs
        .map((doc) => MetronomeSession.fromJson(doc.data()))
        .toList();
  }

  /// One-shot upload of sessions recorded before the Firestore move. Runs at
  /// most once per device (a SharedPreferences flag), no-ops when signed out.
  /// The Hive box is left on disk so a rollback still finds its data.
  Future<void> migrateLocalSessions() async {
    final db = _firestore;
    if (!storageReady || db == null || _sessions == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedKey) ?? false) return;

    try {
      final box = await Hive.openBox<dynamic>(boxName);
      final local = box.values.whereType<Map<dynamic, dynamic>>().toList();
      // Firestore batches cap at 500 writes.
      for (var i = 0; i < local.length; i += 500) {
        final chunk = local.skip(i).take(500);
        final batch = db.batch();
        for (final value in chunk) {
          final session = MetronomeSession.fromJson(
            Map<String, dynamic>.from(value),
          );
          batch.set(_sessions!.doc(session.id), session.toJson());
        }
        await batch.commit();
      }
      await prefs.setBool(_migratedKey, true);
      debugPrint('📈 Migrated ${local.length} practice sessions to Firestore');
    } catch (error) {
      // Leave the flag unset so the next launch retries.
      debugPrint('Practice session migration failed: $error');
    }
  }
}
