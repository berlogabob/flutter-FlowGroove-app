import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/song.dart';
import '../models/api_error.dart';
import '../models/link.dart';
import '../models/section.dart';
import '../repositories/song_repository.dart';
import '../services/analytics_service.dart';
import '../screens/songs/models/song_form_data.dart';

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

  const SongFormState({
    required this.formData,
    this.error,
    this.hasUnsavedChanges = false,
    this.isAutoSaving = false,
    this.isSaving = false,
    this.isLoading = false,
  });

  SongFormState copyWith({
    SongFormData? formData,
    ApiError? error,
    bool? hasUnsavedChanges,
    bool? isAutoSaving,
    bool? isSaving,
    bool? isLoading,
  }) {
    return SongFormState(
      formData: formData ?? this.formData,
      error: error,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      isAutoSaving: isAutoSaving ?? this.isAutoSaving,
      isSaving: isSaving ?? this.isSaving,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  factory SongFormState.initial() =>
      SongFormState(formData: SongFormData());

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
  void updateBeatMode(int beatIndex, int subdivisionIndex, dynamic mode) {
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

      if (bandId != null) {
        await songRepo.saveBandSong(song, bandId);
      } else {
        await songRepo.saveSong(song, uid: uid);
      }

      // Log analytics event for new song
      if (!isEditing) {
        await AnalyticsService.logSongAddedFromSong(song);
      } else {
        // Log song edit with changed fields
        await AnalyticsService.logSongEdited(
          songId: song.id,
          fieldsChanged: ['title', 'artist'], // Would need to track actual changes
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

      if (bandId != null) {
        await songRepo.saveBandSong(song, bandId);
      } else {
        await songRepo.saveSong(song, uid: uid);
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
