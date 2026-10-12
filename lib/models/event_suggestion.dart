/// A change someone asked for on ONE event.
///
/// Written by the `submitSuggestion` callable — a guest with a share link, a
/// venue's art director, a wedding couple asking for their first dance. The
/// band accepts or declines through `resolveSuggestion`; applying the change
/// itself stays in the app, because "add this song" means picking a real song
/// from the library and nobody but the band can do that.
class EventSuggestion {
  const EventSuggestion({
    required this.id,
    required this.type,
    required this.text,
    required this.status,
    this.songId,
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
  final String authorName;
  final DateTime? createdAt;

  bool get isOpen => status == 'open';

  /// What the person asked for, as a sentence. `note` is already one.
  String get action => switch (type) {
    'add' => 'asked to add a song',
    'remove' => 'asked to remove a song',
    'reorder' => 'asked to change the running order',
    _ => 'left a note',
  };
}
