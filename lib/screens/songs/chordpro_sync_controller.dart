import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/section.dart';
import '../../models/song.dart';
import '../../utils/chordpro.dart';

/// How an imported/pasted document combines with the current map.
enum ImportMode { replace, append }

/// Header metadata lifted from the ChordPro text, for the screen to mirror in
/// its header and hand back to the song form on close.
class ChordProSyncMeta {
  const ChordProSyncMeta({
    this.title,
    this.artist,
    this.ourKey,
    this.ourBpm,
    this.timeTop,
  });

  final String? title;
  final String? artist;
  final String? ourKey;
  final int? ourBpm;
  final int? timeTop;
}

/// Keeps a song's [sections] and its ChordPro [text] as two live views of ONE
/// store. Structural edits from the visual map regenerate the text immediately;
/// text edits are debounced then reconciled back onto the sections (via
/// [reconcileSections]) so typing chords never wipes structure. Pure Dart, no
/// widgets — unit-testable.
class ChordProSyncController extends ChangeNotifier {
  ChordProSyncController({
    required List<Section> sections,
    String? title,
    String? artist,
    String? ourKey,
    int? ourBpm,
    int? timeTop,
    this.debounce = const Duration(milliseconds: 400),
  }) : _sections = List.of(sections),
       _title = title,
       _artist = artist,
       _ourKey = ourKey,
       _ourBpm = ourBpm,
       _timeTop = timeTop {
    _text = _render();
  }

  final Duration debounce;
  Timer? _debounceTimer;

  List<Section> _sections;
  String _text = '';
  String? _title;
  String? _artist;
  String? _ourKey;
  int? _ourBpm;
  int? _timeTop;

  List<Section> get sections => List.unmodifiable(_sections);
  String get text => _text;
  ChordProSyncMeta get meta => ChordProSyncMeta(
    title: _title,
    artist: _artist,
    ourKey: _ourKey,
    ourBpm: _ourBpm,
    timeTop: _timeTop,
  );

  Song _base() => Song(
    id: '',
    title: _title ?? '',
    artist: _artist ?? '',
    ourKey: _ourKey,
    ourBPM: _ourBpm,
    accentBeats: _timeTop ?? 4,
    sections: _sections,
    createdAt: DateTime(2000),
    updatedAt: DateTime(2000),
  );

  String _render() => songToChordPro(_base());

  /// A structural edit from the visual map (reorder/rename/add/delete/edit) —
  /// regenerate the text immediately.
  void updateFromMap(List<Section> newSections) {
    _sections = List.of(newSections);
    _text = _render();
    notifyListeners();
  }

  /// A text edit from the ChordPro field — store now, reconcile after [debounce].
  void updateFromText(String newText) {
    _text = newText;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, _reparse);
  }

  /// Run any pending reparse immediately (e.g. before leaving the screen).
  void flushPending() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
      _reparse();
    }
  }

  void _reparse() {
    final p = chordProToSong(_text, base: _base());
    _sections = reconcileSections(_sections, p.sections);
    _adoptMeta(p.song, _text);
    notifyListeners();
  }

  void _adoptMeta(Song s, String source) {
    if (s.title.isNotEmpty) _title = s.title;
    if (s.artist.isNotEmpty) _artist = s.artist;
    _ourKey = s.ourKey ?? _ourKey;
    _ourBpm = s.ourBPM ?? _ourBpm;
    // accentBeats always has a value; only adopt when the text actually had {time}.
    if (RegExp(r'\{\s*time\b', caseSensitive: false).hasMatch(source)) {
      _timeTop = s.accentBeats;
    }
  }

  /// Whether importing [pastedText] over the current map is a wholesale change
  /// (non-empty map + a different section-name sequence). The screen uses this
  /// to decide whether to prompt Replace / Append / Cancel.
  bool isImportConflict(String pastedText) {
    if (_sections.isEmpty) return false;
    final incoming = chordProToSong(pastedText, base: _base()).sections;
    if (incoming.isEmpty) return false;
    final a = _sections.map((s) => s.name).toList();
    final b = incoming.map((s) => s.name).toList();
    return !listEquals(a, b);
  }

  /// Apply pre-built [incoming] sections either replacing or appending, then
  /// re-render the text. Callers pass sections with unique ids. On [replace],
  /// optional [meta] (title/key/tempo/time from the pasted doc) is adopted too.
  void applyImport(List<Section> incoming, ImportMode mode, {ChordProSyncMeta? meta}) {
    _sections = mode == ImportMode.replace
        ? List.of(incoming)
        : [..._sections, ...incoming];
    if (meta != null && mode == ImportMode.replace) {
      _title = meta.title ?? _title;
      _artist = meta.artist ?? _artist;
      _ourKey = meta.ourKey ?? _ourKey;
      _ourBpm = meta.ourBpm ?? _ourBpm;
      _timeTop = meta.timeTop ?? _timeTop;
    }
    _text = _render();
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
