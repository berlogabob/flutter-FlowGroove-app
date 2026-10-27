/// A change someone asked for on ONE event.
///
/// Written by the `submitSuggestion` callable — a guest with a share link, a
/// venue's art director, a wedding couple asking for their first dance. The
/// band applies or dismisses typed proposals through `resolveSuggestion`.
/// Legacy requests remain text for the band to interpret.
class EventSuggestion {
  const EventSuggestion({
    required this.id,
    required this.type,
    required this.text,
    required this.status,
    this.songId,
    this.proposal,
    this.candidate,
    this.authorName = '',
    this.createdAt,
  });

  factory EventSuggestion.fromJson(Map<String, dynamic> json, {String? id}) {
    return EventSuggestion(
      id: (json['id'] as String?) ?? id ?? '',
      type: (json['type'] as String?) ?? 'note',
      text: (json['text'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'open',
      songId: json['songId'] as String?,
      proposal: EventSuggestionProposal.fromJson(
        json['proposal'],
        json['type'],
      ),
      candidate:
          json['candidate'] is Map &&
              (json['candidate'] as Map)['title'] is String
          ? {'title': (json['candidate'] as Map)['title']}
          : null,
      // The name the band assigned when sharing, so an anonymous link still
      // reads as "Ana & Rui asked to…" rather than a bare token.
      authorName: (json['authorName'] as String?) ?? '',
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? ''),
    );
  }

  final String id;

  /// One of `reorder` / `add` / `remove` / `note` — mirrors SUGGESTION_TYPES
  /// in `functions/src/events.js`.
  final String type;
  final String text;

  /// `open` until the band decides, then `accepted` or `declined`.
  final String status;
  final String? songId;
  final EventSuggestionProposal? proposal;
  final Map<String, dynamic>? candidate;
  final String authorName;
  final DateTime? createdAt;

  bool get isOpen => status == 'open';

  /// Uses only snapshots already available to the caller.
  String? description({
    List<Map<String, dynamic>> items = const [],
    List<Map<String, dynamic>> songs = const [],
  }) {
    final p = proposal;
    if (p == null) return null;
    String songLabel(String? id, [Map<String, dynamic>? snapshot]) {
      final title =
          snapshot?['title'] ??
          songs.where((s) => s['id'] == id).firstOrNull?['title'];
      if (title is String && title.trim().isNotEmpty) return '"$title"';
      return id == null || id.isEmpty ? 'a song' : '"$id"';
    }

    String itemLabel(String id) {
      final item = items.where((i) => i['id'] == id).firstOrNull;
      if (item == null) return 'a song';
      if (item['type'] == 'break') {
        final label = item['breakLabel'];
        return label is String && label.isNotEmpty ? '"$label"' : 'a break';
      }
      return songLabel(item['songId'] as String?, item);
    }

    return switch (p.kind) {
      'add' => 'Add ${songLabel(p.songId, candidate)}',
      'remove' => 'Remove ${itemLabel(p.itemId!)}',
      _ => 'Move running order to: ${p.itemIds.map(itemLabel).join(' → ')}',
    };
  }

  /// What the person asked for, as a sentence. `note` is already one.
  String get action => switch (type) {
    'add' => 'asked to add a song',
    'remove' => 'asked to remove a song',
    'reorder' => 'asked to change the running order',
    _ => 'left a note',
  };
}

/// The versioned wire proposal. Invalid or future shapes stay legacy requests.
class EventSuggestionProposal {
  const EventSuggestionProposal._({
    required this.kind,
    required this.baseFingerprint,
    this.songId,
    this.itemId,
    this.beforeItemId,
    this.itemIds = const [],
  });

  int get version => 1;
  final String kind;
  final String baseFingerprint;
  final String? songId;
  final String? itemId;
  final String? beforeItemId;
  final List<String> itemIds;

  static EventSuggestionProposal? fromJson(Object? raw, Object? type) {
    if (raw is! Map || raw['version'] != 1 || raw['kind'] != type) return null;
    final kind = raw['kind'];
    final fingerprint = raw['baseFingerprint'];
    if (fingerprint is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(fingerprint)) {
      return null;
    }
    final fields = switch (kind) {
      'add' => ['songId', 'beforeItemId'],
      'remove' => ['itemId'],
      'reorder' => ['itemIds'],
      _ => null,
    };
    if (fields == null ||
        raw.keys.any(
          (k) => !['version', 'kind', 'baseFingerprint', ...fields].contains(k),
        )) {
      return null;
    }
    bool validId(Object? id) =>
        id is String && id.isNotEmpty && !id.contains('/');
    if (kind == 'add' &&
        (!validId(raw['songId']) ||
            (raw.containsKey('beforeItemId') &&
                !validId(raw['beforeItemId'])))) {
      return null;
    }
    if (kind == 'remove' && !validId(raw['itemId'])) return null;
    final ids = raw['itemIds'];
    if (kind == 'reorder' &&
        (ids is! List ||
            !ids.every(validId) ||
            ids.toSet().length != ids.length)) {
      return null;
    }
    return EventSuggestionProposal._(
      kind: kind as String,
      baseFingerprint: fingerprint,
      songId: raw['songId'] as String?,
      itemId: raw['itemId'] as String?,
      beforeItemId: raw['beforeItemId'] as String?,
      itemIds: ids is List ? List<String>.unmodifiable(ids) : const [],
    );
  }
}
