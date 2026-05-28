import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/song.dart';
import '../models/api_error.dart';
import '../models/link.dart';
import '../models/section.dart';
import '../models/song_suggestion.dart';
import '../models/beat_mode.dart';
import '../repositories/song_repository.dart';
import '../services/analytics_service.dart';
import '../services/matching/fuzzy_matcher.dart';
import '../screens/songs/models/song_form_data.dart';
import 'data/data_providers.dart';

/// Provider for managing song form state.
///
/// This provider encapsulates all form state and operations
/// for the add/edit song screen, eliminating the need for
/// setState in the screen.
final songFormStateProvider =
    NotifierProvider<SongFormStateNotifier, SongFormState>(
      () => SongFormStateNotifier(),
    );

/// State class for song form management.
class SongFormState {
  final SongFormData formData;
  final ApiError? error;
  final bool hasUnsavedChanges;
  final bool isAutoSaving;
  final bool isSaving;
  final bool isLoading;

  // Autocomplete fields
  final SongSuggestion? selectedSuggestion;
  final bool isUsingSuggestion;

  const SongFormState({
    required this.formData,
    this.error,
    this.hasUnsavedChanges = false,
    this.isAutoSaving = false,
    this.isSaving = false,
    this.isLoading = false,
    this.selectedSuggestion,
    this.isUsingSuggestion = false,
  });

  SongFormState copyWith({
    SongFormData? formData,
    ApiError? error,
    bool? hasUnsavedChanges,
    bool? isAutoSaving,
    bool? isSaving,
    bool? isLoading,
    SongSuggestion? selectedSuggestion,
    bool? isUsingSuggestion,
  }) {
    return SongFormState(
      formData: formData ?? this.formData,
      error: error,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      isAutoSaving: isAutoSaving ?? this.isAutoSaving,
      isSaving: isSaving ?? this.isSaving,
      isLoading: isLoading ?? this.isLoading,
      selectedSuggestion: selectedSuggestion ?? this.selectedSuggestion,
      isUsingSuggestion: isUsingSuggestion ?? this.isUsingSuggestion,
    );
  }

  factory SongFormState.initial() => SongFormState(formData: SongFormData());

  factory SongFormState.fromSong(Song song) =>
      SongFormState(formData: SongFormData.fromSong(song));
}

/// Notifier for managing song form state.
class SongFormStateNotifier extends Notifier<SongFormState> {
  @override
  SongFormState build() {
    return SongFormState.initial();
  }

  /// Initialize form with existing song data.
  void initFromSong(Song song) {
    state = SongFormState.fromSong(song);
  }

  /// Mark form as having unsaved changes.
  void markAsChanged() {
    if (!state.hasUnsavedChanges) {
      state = state.copyWith(hasUnsavedChanges: true);
    }
  }

  /// Update form field: title.
  void updateTitle(String value) {
    state = state.copyWith(formData: state.formData.copyWith(title: value));
    markAsChanged();
  }

  /// Update form field: artist.
  void updateArtist(String value) {
    state = state.copyWith(formData: state.formData.copyWith(artist: value));
    markAsChanged();
  }

  /// Update form field: original BPM.
  void updateOriginalBpm(String value) {
    state = state.copyWith(
      formData: state.formData.copyWith(originalBpm: value),
    );
    markAsChanged();
  }

  /// Update form field: our BPM.
  void updateOurBpm(String value) {
    state = state.copyWith(formData: state.formData.copyWith(ourBpm: value));
    markAsChanged();
  }

  /// Update form field: notes.
  void updateNotes(String value) {
    state = state.copyWith(formData: state.formData.copyWith(notes: value));
    markAsChanged();
  }

  /// Update form field: accent beats.
  void updateAccentBeats(int value) {
    state = state.copyWith(
      formData: state.formData.copyWith(accentBeats: value),
    );
    markAsChanged();
  }

  /// Update form field: regular beats.
  void updateRegularBeats(int value) {
    state = state.copyWith(
      formData: state.formData.copyWith(regularBeats: value),
    );
    markAsChanged();
  }

  /// Update form field: beat mode.
  void updateBeatMode(int beatIndex, int subdivisionIndex, BeatMode mode) {
    state = state.copyWith(
      formData: state.formData.copyWith(
        beatModes: state.formData.beatModes.map((beat) {
          return beat.map((m) => m).toList();
        }).toList(),
      ),
    );
    state.formData.updateBeatMode(beatIndex, subdivisionIndex, mode);
    markAsChanged();
  }

  /// Set sections.
  void setSections(List<Section> sections) {
    state = state.copyWith(
      formData: state.formData.copyWith(sections: sections),
    );
    markAsChanged();
  }

  /// Clear unsaved changes flag.
  void clearUnsavedChanges() {
    state = state.copyWith(hasUnsavedChanges: false);
  }

  /// Set auto-saving state.
  void setAutoSaving(bool value) {
    state = state.copyWith(isAutoSaving: value);
  }

  /// Set saving state.
  void setSaving(bool value) {
    state = state.copyWith(isSaving: value);
  }

  /// Set error state.
  void setError(ApiError? error) {
    state = state.copyWith(error: error);
  }

  /// Clear error state.
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Update original key.
  void updateOriginalKey(String base, String modifier) {
    state = state.copyWith(
      formData: state.formData.copyWith(
        originalKeyBase: base,
        originalKeyModifier: modifier,
      ),
    );
    markAsChanged();
  }

  /// Update our key.
  void updateOurKey(String base, String modifier) {
    state = state.copyWith(
      formData: state.formData.copyWith(
        ourKeyBase: base,
        ourKeyModifier: modifier,
      ),
    );
    markAsChanged();
  }

  /// Add link.
  void addLink(Link link) {
    final newLinks = List<Link>.from(state.formData.links)..add(link);
    state = state.copyWith(formData: state.formData.copyWith(links: newLinks));
    markAsChanged();
  }

  /// Remove link at index.
  void removeLink(int index) {
    final newLinks = List<Link>.from(state.formData.links)..removeAt(index);
    state = state.copyWith(formData: state.formData.copyWith(links: newLinks));
    markAsChanged();
  }

  /// Toggle tag.
  void toggleTag(String tag, bool selected) {
    if (selected) {
      final newTags = List<String>.from(state.formData.selectedTags)..add(tag);
      state = state.copyWith(
        formData: state.formData.copyWith(selectedTags: newTags),
      );
    } else {
      final newTags = List<String>.from(state.formData.selectedTags)
        ..remove(tag);
      state = state.copyWith(
        formData: state.formData.copyWith(selectedTags: newTags),
      );
    }
    markAsChanged();
  }

  /// Copy from original.
  void copyFromOriginal() {
    state = state.copyWith(
      formData: state.formData.copyWith(
        ourKeyBase: state.formData.originalKeyBase,
        ourKeyModifier: state.formData.originalKeyModifier,
        ourBpm: state.formData.originalBpm,
      ),
    );
    markAsChanged();
  }

  /// Initialize beat modes.
  void initializeBeatModes() {
    state.formData.initializeBeatModes();
  }

  /// Save song to repository.
  Future<bool> saveSong({
    required SongRepository songRepo,
    required String uid,
    String? bandId,
    bool isEditing = false,
    Song? existingSong,
  }) async {
    if (state.formData.title.trim().isEmpty) {
      setError(ApiError.validation(message: 'Title is required'));
      return false;
    }

    state = state.copyWith(isSaving: true, error: null);

    try {
      final song = state.formData.toSong(
        id: isEditing && existingSong != null
            ? existingSong.id
            : const Uuid().v4(),
        createdAt: isEditing && existingSong != null
            ? existingSong.createdAt
            : DateTime.now(),
        bandId: bandId,
      );

      final canonicalSongId =
          await _canonicalSongIdForSelectedSuggestion() ??
          existingSong?.canonicalSongId;

      final songWithMetadata = _preserveExistingMetadata(
        song.copyWith(
          canonicalSongId: canonicalSongId,
          isFromMusicBrainz:
              state.selectedSuggestion?.source == SuggestionSource.musicbrainz,
        ),
        existingSong,
      );

      if (bandId != null) {
        if (isEditing) {
          await songRepo.updateBandSong(songWithMetadata, bandId);
        } else {
          await songRepo.saveBandSong(songWithMetadata, bandId);
        }
      } else {
        if (isEditing) {
          await songRepo.updateSong(songWithMetadata, uid: uid);
        } else {
          await songRepo.saveSong(songWithMetadata, uid: uid);
        }
      }

      // Log analytics event for new song
      if (!isEditing) {
        await AnalyticsService.logSongAddedFromSong(song);
      } else {
        // Log song edit with changed fields
        await AnalyticsService.logSongEdited(
          songId: song.id,
          fieldsChanged: [
            'title',
            'artist',
          ], // Would need to track actual changes
        );
      }

      clearUnsavedChanges();
      state = state.copyWith(isSaving: false);
      return true;
    } on ApiError catch (e) {
      state = state.copyWith(error: e, isSaving: false);
      return false;
    } catch (e, stackTrace) {
      state = state.copyWith(
        error: ApiError.fromException(e, stackTrace: stackTrace),
        isSaving: false,
      );
      return false;
    }
  }

  /// Auto-save song (silent save without error display).
  Future<bool> autoSave({
    required SongRepository songRepo,
    required String uid,
    String? bandId,
    bool isEditing = false,
    Song? existingSong,
  }) async {
    if (!state.hasUnsavedChanges || state.formData.title.trim().isEmpty) {
      return false;
    }

    setAutoSaving(true);

    try {
      final song = state.formData.toSong(
        id: isEditing && existingSong != null
            ? existingSong.id
            : const Uuid().v4(),
        createdAt: isEditing && existingSong != null
            ? existingSong.createdAt
            : DateTime.now(),
        bandId: bandId,
      );
      final songWithMetadata = _preserveExistingMetadata(song, existingSong);

      if (bandId != null) {
        if (isEditing) {
          await songRepo.updateBandSong(songWithMetadata, bandId);
        } else {
          await songRepo.saveBandSong(songWithMetadata, bandId);
        }
      } else {
        if (isEditing) {
          await songRepo.updateSong(songWithMetadata, uid: uid);
        } else {
          await songRepo.saveSong(songWithMetadata, uid: uid);
        }
      }

      clearUnsavedChanges();
      setAutoSaving(false);
      return true;
    } catch (e) {
      setAutoSaving(false);
      return false;
    }
  }

  /// Reset form to initial state.
  void reset() {
    state = SongFormState.initial();
  }

  /// Reset form from song.
  void resetFromSong(Song song) {
    state = SongFormState.fromSong(song);
  }

  // ============================================================
  // AUTOCOMPLETE INTEGRATION
  // ============================================================

  /// Handle selection of a song suggestion from autocomplete.
  void selectSuggestion(SongSuggestion suggestion) {
    state = state.copyWith(
      selectedSuggestion: suggestion,
      isUsingSuggestion: true,
      formData: state.formData.copyWith(
        title: suggestion.title,
        artist: suggestion.artist,
      ),
    );
    markAsChanged();
  }

  /// Clear selected suggestion and allow manual editing.
  void clearSuggestion() {
    state = state.copyWith(selectedSuggestion: null, isUsingSuggestion: false);
  }

  /// Apply suggestion data to form fields.
  void applySuggestionToForm(SongSuggestion suggestion) {
    state = state.copyWith(
      formData: state.formData.copyWith(
        title: suggestion.title,
        artist: suggestion.artist,
      ),
    );
    markAsChanged();
  }

  Future<String?> _canonicalSongIdForSelectedSuggestion() async {
    final suggestion = state.selectedSuggestion;
    if (suggestion == null) return null;

    final canonicalSongId = suggestion.canonicalSongId;
    if (canonicalSongId != null && canonicalSongId.isNotEmpty) {
      return canonicalSongId;
    }

    if (suggestion.source == SuggestionSource.musicbrainz) {
      final service = ref.read(canonicalSongFunctionServiceProvider);
      final result = await service.ensureFromSuggestion(suggestion);
      return result.canonicalSongId;
    }

    return null;
  }

  Song _preserveExistingMetadata(Song song, Song? existingSong) {
    if (existingSong == null) return song;

    final sameCanonical =
        existingSong.canonicalSongId != null &&
        existingSong.canonicalSongId == song.canonicalSongId;
    final preserveExternalMetadata =
        song.canonicalSongId == null || sameCanonical;

    return song.copyWith(
      canonicalSongId: song.canonicalSongId ?? existingSong.canonicalSongId,
      libraryBaseRevision: sameCanonical
          ? existingSong.libraryBaseRevision
          : null,
      latestCommitId: sameCanonical ? existingSong.latestCommitId : null,
      originalOwnerId: existingSong.originalOwnerId,
      originalSongId: existingSong.originalSongId,
      contributedBy: existingSong.contributedBy,
      isCopy: existingSong.isCopy,
      contributedAt: existingSong.contributedAt,
      spotifyId: preserveExternalMetadata ? existingSong.spotifyId : null,
      musicbrainzId: preserveExternalMetadata
          ? existingSong.musicbrainzId
          : null,
      isrc: preserveExternalMetadata ? existingSong.isrc : null,
      deezerId: preserveExternalMetadata ? existingSong.deezerId : null,
      normalizedTitle: preserveExternalMetadata
          ? existingSong.normalizedTitle
          : null,
      normalizedArtist: preserveExternalMetadata
          ? existingSong.normalizedArtist
          : null,
      titleSoundex: preserveExternalMetadata ? existingSong.titleSoundex : null,
      artistSoundex: preserveExternalMetadata
          ? existingSong.artistSoundex
          : null,
      durationMs: preserveExternalMetadata ? existingSong.durationMs : null,
      album: preserveExternalMetadata ? existingSong.album : null,
      variantType: preserveExternalMetadata ? existingSong.variantType : null,
      variantOf: preserveExternalMetadata ? existingSong.variantOf : null,
      isFromMusicBrainz:
          song.isFromMusicBrainz || existingSong.isFromMusicBrainz,
    );
  }

  /// Check for potential duplicates before save.
  /// Returns the duplicate song if found (for warning dialog).
  Future<Song?> checkForDuplicates({
    required SongRepository songRepo,
    required String uid,
    String? bandId,
  }) async {
    final title = state.formData.title.trim();
    final artist = state.formData.artist.trim();

    if (title.isEmpty || artist.isEmpty) {
      return null;
    }

    // Get songs for comparison
    List<Song> songsToCheck;
    if (bandId != null) {
      // Get band's songs from repository
      final bandSongs = await songRepo.getBandSongs(bandId);
      songsToCheck = bandSongs.map((s) => s).toList();
    } else {
      // Get user's personal songs
      songsToCheck = await songRepo.getSongs(uid);
    }

    // Check each song for similarity
    for (final song in songsToCheck) {
      // Skip if this is the same song (editing)
      if (state.selectedSuggestion != null &&
          state.selectedSuggestion!.id == song.id) {
        continue;
      }

      final matchResult = FuzzyMatcher.calculateMatchScore(
        inputTitle: title,
        inputArtist: artist,
        targetTitle: song.title,
        targetArtist: song.artist,
        targetAlbum: song.album,
      );

      // High confidence duplicate - show warning
      if (matchResult.overall >= 0.90) {
        return song;
      }
    }

    return null;
  }

  /// Save song after duplicate check
  /// Shows warning if duplicate found, allows user to proceed or cancel
  Future<bool> saveWithDuplicateCheck({
    required SongRepository songRepo,
    required String uid,
    required BuildContext context,
    String? bandId,
    bool isEditing = false,
    Song? existingSong,
  }) async {
    // Check for duplicates
    final duplicate = await checkForDuplicates(
      songRepo: songRepo,
      uid: uid,
      bandId: bandId,
    );

    // If duplicate found and not already using suggestion, show warning
    if (duplicate != null && !state.isUsingSuggestion) {
      final proceed = await _showDuplicateWarning(context, duplicate);
      if (!proceed) {
        return false; // User cancelled
      }
    }

    // Proceed with save
    return await saveSong(
      songRepo: songRepo,
      uid: uid,
      bandId: bandId,
      isEditing: isEditing,
      existingSong: existingSong,
    );
  }

  /// Show duplicate warning dialog
  Future<bool> _showDuplicateWarning(
    BuildContext context,
    Song duplicate,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
        title: const Text('Similar Song Exists'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${duplicate.title}" by ${duplicate.artist}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            const Text(
              'A similar song already exists in your library. '
              'Do you want to:',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // Cancel
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), // Proceed anyway
            child: const Text('Save Anyway'),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}

/// Provider for song form error state (derived).
final songFormErrorProvider = Provider<ApiError?>((ref) {
  return ref.watch(songFormStateProvider).error;
});

/// Provider for song form unsaved changes state (derived).
final songFormHasChangesProvider = Provider<bool>((ref) {
  return ref.watch(songFormStateProvider).hasUnsavedChanges;
});

/// Provider for song form saving state (derived).
final songFormIsSavingProvider = Provider<bool>((ref) {
  return ref.watch(songFormStateProvider).isSaving;
});
