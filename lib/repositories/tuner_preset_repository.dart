import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tuner_preset.dart';

class TunerPresetRepository {

  TunerPresetRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestoreOverride = firestore,
      _authOverride = auth;
  static const _localPresetsKey = 'tuner.custom_presets';
  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  bool get _hasFirebase =>
      _firestoreOverride != null ||
      _authOverride != null ||
      Firebase.apps.isNotEmpty;

  Future<List<TunerPreset>> loadLocal() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getStringList(_localPresetsKey) ?? const [];
    return encoded
        .map(
          (value) => TunerPreset.fromJson(
            Map<String, dynamic>.from(jsonDecode(value) as Map),
          ),
        )
        .toList();
  }

  Future<void> save(TunerPreset preset) async {
    _validate(preset);
    if (preset.scope == TunerPresetScope.local) {
      final presets = await loadLocal();
      final index = presets.indexWhere((value) => value.id == preset.id);
      if (index < 0) {
        presets.add(preset);
      } else {
        presets[index] = preset;
      }
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(
        _localPresetsKey,
        presets.map((value) => jsonEncode(value.toJson())).toList(),
      );
      return;
    }

    if (!_hasFirebase) {
      throw StateError('Firebase must be initialized before syncing presets');
    }
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Sign in before syncing a tuner preset');
    final synced = preset.copyWith(ownerId: preset.ownerId ?? uid);
    await _firestore
        .collection('tunerPresets')
        .doc(synced.id)
        .set(synced.toJson(), SetOptions(merge: true));
  }

  Future<void> delete(TunerPreset preset) async {
    if (preset.scope == TunerPresetScope.local) {
      final presets = await loadLocal()
        ..removeWhere((value) => value.id == preset.id);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(
        _localPresetsKey,
        presets.map((value) => jsonEncode(value.toJson())).toList(),
      );
      return;
    }
    if (!_hasFirebase) {
      throw StateError('Firebase must be initialized before syncing presets');
    }
    await _firestore.collection('tunerPresets').doc(preset.id).delete();
  }

  Future<List<TunerPreset>> loadSynced({String? bandId, String? songId}) async {
    if (!_hasFirebase) return const [];
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const [];
    final queries = <Future<QuerySnapshot<Map<String, dynamic>>>>[
      _firestore
          .collection('tunerPresets')
          .where('ownerId', isEqualTo: uid)
          .where('scope', isEqualTo: TunerPresetScope.account.name)
          .get(),
      if (bandId != null)
        _firestore
            .collection('tunerPresets')
            .where('bandId', isEqualTo: bandId)
            .where('scope', isEqualTo: TunerPresetScope.band.name)
            .get(),
      if (songId != null)
        _firestore
            .collection('tunerPresets')
            .where('songId', isEqualTo: songId)
            .where('scope', isEqualTo: TunerPresetScope.song.name)
            .get(),
    ];
    final snapshots = await Future.wait(queries);
    final byId = <String, TunerPreset>{};
    for (final snapshot in snapshots) {
      for (final document in snapshot.docs) {
        final preset = TunerPreset.fromJson(document.data());
        byId[preset.id] = preset;
      }
    }
    return byId.values.toList();
  }

  Stream<List<TunerPreset>> watchAccountPresets() {
    if (!_hasFirebase) return Stream.value(const []);
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection('tunerPresets')
        .where('ownerId', isEqualTo: uid)
        .where('scope', isEqualTo: TunerPresetScope.account.name)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) => TunerPreset.fromJson(document.data()))
              .toList(),
        );
  }

  Stream<List<TunerPreset>> watchBandPresets(String bandId) {
    if (!_hasFirebase) return Stream.value(const []);
    return _firestore
        .collection('tunerPresets')
        .where('bandId', isEqualTo: bandId)
        .where('scope', isEqualTo: TunerPresetScope.band.name)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) => TunerPreset.fromJson(document.data()))
              .toList(),
        );
  }

  void _validate(TunerPreset preset) {
    if (preset.name.trim().isEmpty) {
      throw ArgumentError.value(preset.name, 'name', 'Must not be empty');
    }
    if (preset.referenceHz < 415 || preset.referenceHz > 466) {
      throw ArgumentError.value(
        preset.referenceHz,
        'referenceHz',
        'Must be between 415 and 466 Hz',
      );
    }
    if (preset.centsTolerance < 1 || preset.centsTolerance > 20) {
      throw ArgumentError.value(
        preset.centsTolerance,
        'centsTolerance',
        'Must be between 1 and 20 cents',
      );
    }
    if (preset.scope == TunerPresetScope.band && preset.bandId == null) {
      throw ArgumentError('Band presets require bandId');
    }
    if (preset.scope == TunerPresetScope.song && preset.songId == null) {
      throw ArgumentError('Song presets require songId');
    }
  }
}
