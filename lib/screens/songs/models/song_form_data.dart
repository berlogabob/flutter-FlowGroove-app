import 'package:json_annotation/json_annotation.dart';

import '../../../models/beat_mode.dart';
import '../../../models/link.dart';
import '../../../models/section.dart';
import '../../../models/song.dart';

part 'song_form_data.g.dart';

/// Model class holding all form state for the add/edit song screen.
///
/// This class encapsulates all the form fields and state needed
/// to add or edit a song, making it easier to manage form state
/// separately from the UI logic.
@JsonSerializable()
class SongFormData {
  /// Creates a new SongFormData instance.
  SongFormData({
    this.title = '',
    this.artist = '',
    this.originalBpm = '',
    this.ourBpm = '',
    this.notes = '',
    List<Link>? links,
    List<String>? selectedTags,
    this.originalKeyBase = '',
    this.originalKeyModifier = '',
    this.ourKeyBase = '',
    this.ourKeyModifier = '',
    this.spotifyUrl,
    this.accentBeats = 4,
    this.regularBeats = 1,
    List<List<BeatMode>>? beatModes,
    List<Section>? sections,
  }) : links = links ?? [],
       selectedTags = selectedTags ?? [],
       beatModes = beatModes ?? [],
       sections = sections ?? [];

  /// Creates a new SongFormData instance from an existing Song.
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
      accentBeats: song.accentBeats,
      regularBeats: song.regularBeats,
      beatModes: song.beatModes.isNotEmpty
          ? song.beatModes
                .map((row) => row.map((mode) => mode).toList())
                .toList()
          : [],
      sections: List.from(song.sections),
    );
    data._parseKey(song.originalKey, isOriginal: true);
    data._parseKey(song.ourKey, isOriginal: false);

    return data;
  }

  factory SongFormData.fromJson(Map<String, dynamic> json) =>
      _$SongFormDataFromJson(json);

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

  /// Metronome: Number of beats per measure (1-16, default 4).
  int accentBeats;

  /// Metronome: Number of subdivisions per beat (1-8, default 1).
  int regularBeats;

  /// Metronome: 2D list of beat modes (beats × subdivisions).
  final List<List<BeatMode>> beatModes;

  /// The song structure sections.
  final List<Section> sections;

  /// Creates a copy of this SongFormData with the given fields replaced.
  SongFormData copyWith({
    String? title,
    String? artist,
    String? originalBpm,
    String? ourBpm,
    String? notes,
    List<Link>? links,
    List<String>? selectedTags,
    String? originalKeyBase,
    String? originalKeyModifier,
    String? ourKeyBase,
    String? ourKeyModifier,
    String? spotifyUrl,
    int? accentBeats,
    int? regularBeats,
    List<List<BeatMode>>? beatModes,
    List<Section>? sections,
  }) {
    return SongFormData(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      originalBpm: originalBpm ?? this.originalBpm,
      ourBpm: ourBpm ?? this.ourBpm,
      notes: notes ?? this.notes,
      links: links ?? List.from(this.links),
      selectedTags: selectedTags ?? List.from(this.selectedTags),
      originalKeyBase: originalKeyBase ?? this.originalKeyBase,
      originalKeyModifier: originalKeyModifier ?? this.originalKeyModifier,
      ourKeyBase: ourKeyBase ?? this.ourKeyBase,
      ourKeyModifier: ourKeyModifier ?? this.ourKeyModifier,
      spotifyUrl: spotifyUrl ?? this.spotifyUrl,
      accentBeats: accentBeats ?? this.accentBeats,
      regularBeats: regularBeats ?? this.regularBeats,
      beatModes:
          beatModes ??
          this.beatModes
              .map((row) => row.map((mode) => mode).toList())
              .toList(),
      sections: sections ?? List.from(this.sections),
    );
  }

  /// Parse a key string into base and modifier components.
  void _parseKey(String? key, {required bool isOriginal}) {
    if (key == null || key.isEmpty) return;

    final setKey = isOriginal
        ? (String base, String modifier) {
            originalKeyBase = base;
            originalKeyModifier = modifier;
          }
        : (String base, String modifier) {
            ourKeyBase = base;
            ourKeyModifier = modifier;
          };

    if (key.length > 1 && key.endsWith('m')) {
      setKey(key[0].toUpperCase(), key.substring(1));
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

  /// Clear all form fields.
  void clear() {
    title = '';
    artist = '';
    originalBpm = '';
    ourBpm = '';
    notes = '';
    links.clear();
    selectedTags.clear();
    originalKeyBase = '';
    originalKeyModifier = '';
    ourKeyBase = '';
    ourKeyModifier = '';
    spotifyUrl = null;
    accentBeats = 4;
    regularBeats = 1;
    beatModes.clear();
    sections.clear();
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
      accentBeats: accentBeats,
      regularBeats: regularBeats,
      beatModes: _copyBeatModes(),
      sections: sections,
    );
  }

  /// Create a detached copy of the current beat modes grid.
  List<List<BeatMode>> _copyBeatModes() {
    return beatModes.map((row) => row.map((mode) => mode).toList()).toList();
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

  /// Update the accent beats (beats per measure).
  void updateAccentBeats(int value) => accentBeats = value;

  /// Update the regular beats (subdivisions per beat).
  void updateRegularBeats(int value) => regularBeats = value;

  /// Update a beat mode at the specified position.
  void updateBeatMode(int beatIndex, int subdivisionIndex, BeatMode mode) {
    // Ensure the 2D list is large enough
    while (beatModes.length <= beatIndex) {
      beatModes.add([]);
    }
    while (beatModes[beatIndex].length <= subdivisionIndex) {
      beatModes[beatIndex].add(BeatMode.normal);
    }
    beatModes[beatIndex][subdivisionIndex] = mode;
  }

  /// Initialize beat modes grid with default values.
  void initializeBeatModes() {
    beatModes.clear();
    for (int i = 0; i < accentBeats; i++) {
      final row = <BeatMode>[];
      for (int j = 0; j < regularBeats; j++) {
        // First beat of each measure is accent by default
        row.add(i == 0 ? BeatMode.accent : BeatMode.normal);
      }
      beatModes.add(row);
    }
  }

  /// Add a section.
  void addSection(Section section) => sections.add(section);

  /// Remove a section at the specified index.
  void removeSection(int index) => sections.removeAt(index);

  /// Update a section at the specified index.
  void updateSection(int index, Section section) {
    if (index >= 0 && index < sections.length) {
      sections[index] = section;
    }
  }

  /// Reorder sections (for drag and drop).
  void reorderSection(int oldIndex, int newIndex) {
    var adjustedIndex = newIndex;
    if (adjustedIndex > oldIndex) {
      adjustedIndex -= 1;
    }
    final section = sections.removeAt(oldIndex);
    sections.insert(adjustedIndex, section);
  }

  /// Set all sections.
  void setSections(List<Section> newSections) {
    sections.clear();
    sections.addAll(newSections);
  }

  Map<String, dynamic> toJson() => _$SongFormDataToJson(this);
}
