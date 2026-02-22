import 'package:json_annotation/json_annotation.dart';
import '../../../models/link.dart';
import '../../../models/song.dart';

part 'song_form_data.g.dart';

/// Model class holding all form state for the add/edit song screen.
///
/// This class encapsulates all the form fields and state needed
/// to add or edit a song, making it easier to manage form state
/// separately from the UI logic.
@JsonSerializable()
class SongFormData {
  /// The song title.
  String title;

  /// The artist name.
  String artist;

  /// The original BPM value as a string.
  String originalBpm;

  /// The "our" BPM value as a string.
  String ourBpm;

  /// The notes field.
  String notes;

  /// The list of links.
  final List<Link> links;

  /// The selected tags.
  final List<String> selectedTags;

  /// The original key base note (e.g., 'C', 'D').
  String originalKeyBase;

  /// The original key modifier (e.g., '', '#', 'm').
  String originalKeyModifier;

  /// The "our" key base note.
  String ourKeyBase;

  /// The "our" key modifier.
  String ourKeyModifier;

  /// The Spotify URL if linked.
  String? spotifyUrl;

  /// Creates a new SongFormData instance.
  SongFormData({
    this.title = '',
    this.artist = '',
    this.originalBpm = '',
    this.ourBpm = '',
    this.notes = '',
    List<Link>? links,
    List<String>? selectedTags,
    this.originalKeyBase = 'C',
    this.originalKeyModifier = '',
    this.ourKeyBase = 'C',
    this.ourKeyModifier = '',
    this.spotifyUrl,
  }) : links = links ?? [],
       selectedTags = selectedTags ?? [];

  /// Creates SongFormData from an existing Song.
  factory SongFormData.fromSong(Song song) {
    final data = SongFormData(
      title: song.title,
      artist: song.artist,
      originalBpm: song.originalBPM?.toString() ?? '',
      ourBpm: song.ourBPM?.toString() ?? '',
      notes: song.notes ?? '',
      links: List.from(song.links),
      selectedTags: List.from(song.tags),
      spotifyUrl: song.spotifyUrl,
    );
    data._parseKey(song.originalKey, isOriginal: true);
    data._parseKey(song.ourKey, isOriginal: false);
    return data;
  }

  /// Parse a key string into base and modifier components.
  void _parseKey(String? key, {required bool isOriginal}) {
    if (key == null || key.isEmpty) return;

    final setKey = isOriginal
        ? (base, modifier) {
            originalKeyBase = base;
            originalKeyModifier = modifier;
          }
        : (base, modifier) {
            ourKeyBase = base;
            ourKeyModifier = modifier;
          };

    if (key.length > 1 && key.endsWith('m')) {
      setKey(key[0].toUpperCase(), 'm');
    } else if (key.length > 1) {
      setKey(key[0].toUpperCase(), key.substring(1));
    } else {
      setKey(key.toUpperCase(), '');
    }
  }

  /// Build a key string from base and modifier.
  String _buildKey(String base, String modifier) {
    if (modifier == 'm') return '${base.toLowerCase()}m';
    return '$base$modifier';
  }

  /// Get the original key as a complete string.
  String get originalKey => _buildKey(originalKeyBase, originalKeyModifier);

  /// Get the "our" key as a complete string.
  String get ourKey => _buildKey(ourKeyBase, ourKeyModifier);

  /// Copy key and BPM from original to "our" fields.
  void copyFromOriginal() {
    ourKeyBase = originalKeyBase;
    ourKeyModifier = originalKeyModifier;
    ourBpm = originalBpm;
  }

  /// Clear all form fields.
  void clear() {
    title = '';
    artist = '';
    originalBpm = '';
    ourBpm = '';
    notes = '';
    links.clear();
    selectedTags.clear();
    originalKeyBase = 'C';
    originalKeyModifier = '';
    ourKeyBase = 'C';
    ourKeyModifier = '';
    spotifyUrl = null;
  }

  /// Create a Song object from this form data.
  Song toSong({
    required String id,
    required DateTime createdAt,
    String? bandId,
    String? originalOwnerId,
    String? contributedBy,
    bool isCopy = false,
    DateTime? contributedAt,
  }) {
    return Song(
      id: id,
      title: title.trim(),
      artist: artist.trim(),
      originalKey: originalKey.isNotEmpty ? originalKey : null,
      originalBPM: _parseBpm(originalBpm),
      ourKey: ourKey.isNotEmpty ? ourKey : null,
      ourBPM: _parseBpm(ourBpm),
      links: links,
      notes: notes.trim().isNotEmpty ? notes.trim() : null,
      tags: selectedTags,
      bandId: bandId,
      spotifyUrl: spotifyUrl,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      originalOwnerId: originalOwnerId,
      contributedBy: contributedBy,
      isCopy: isCopy,
      contributedAt: contributedAt,
    );
  }

  /// Parse BPM string to int, returns null if empty or invalid.
  int? _parseBpm(String bpm) {
    if (bpm.trim().isEmpty) return null;
    return int.tryParse(bpm.trim());
  }

  /// Update the title.
  void updateTitle(String value) => title = value;

  /// Update the artist.
  void updateArtist(String value) => artist = value;

  /// Update the notes.
  void updateNotes(String value) => notes = value;

  /// Update the original BPM.
  void updateOriginalBpm(String value) => originalBpm = value;

  /// Update the "our" BPM.
  void updateOurBpm(String value) => ourBpm = value;

  /// Add a link.
  void addLink(Link link) => links.add(link);

  /// Remove a link at the specified index.
  void removeLink(int index) => links.removeAt(index);

  /// Toggle a tag selection.
  void toggleTag(String tag, bool selected) {
    if (selected) {
      if (!selectedTags.contains(tag)) {
        selectedTags.add(tag);
      }
    } else {
      selectedTags.remove(tag);
    }
  }

  /// Update the Spotify URL.
  void updateSpotifyUrl(String? url) => spotifyUrl = url;

  Map<String, dynamic> toJson() => _$SongFormDataToJson(this);

  factory SongFormData.fromJson(Map<String, dynamic> json) =>
      _$SongFormDataFromJson(json);
}
