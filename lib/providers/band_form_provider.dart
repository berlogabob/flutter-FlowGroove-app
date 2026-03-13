import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/band.dart';
import '../models/api_error.dart';
import '../repositories/band_repository.dart';

/// Provider for managing band form state.
///
/// This provider encapsulates all form state and operations
/// for the band screen, eliminating the need for
/// setState in the screen.
final bandFormStateProvider =
    NotifierProvider<BandFormStateNotifier, BandFormState>(
      () => BandFormStateNotifier(),
    );

/// State class for band form management.
class BandFormState {
  final Band band;
  final String? description;
  final List<String> tags;
  final List<BandMember> members;
  final ApiError? error;
  final bool hasUnsavedChanges;
  final bool isAutoSaving;
  final bool isSaving;
  final bool isLoading;

  const BandFormState({
    required this.band,
    this.description,
    required this.tags,
    required this.members,
    this.error,
    this.hasUnsavedChanges = false,
    this.isAutoSaving = false,
    this.isSaving = false,
    this.isLoading = false,
  });

  BandFormState copyWith({
    Band? band,
    String? description,
    List<String>? tags,
    List<BandMember>? members,
    ApiError? error,
    bool? hasUnsavedChanges,
    bool? isAutoSaving,
    bool? isSaving,
    bool? isLoading,
  }) {
    return BandFormState(
      band: band ?? this.band,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      members: members ?? this.members,
      error: error,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      isAutoSaving: isAutoSaving ?? this.isAutoSaving,
      isSaving: isSaving ?? this.isSaving,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  factory BandFormState.fromBand(Band band) => BandFormState(
    band: band,
    description: band.description,
    tags: List<String>.from(band.tags),
    members: List<BandMember>.from(band.members),
  );
}

/// Notifier for managing band form state.
class BandFormStateNotifier extends Notifier<BandFormState> {
  @override
  BandFormState build() {
    return BandFormState(
      band: Band.empty,
      tags: [],
      members: [],
    );
  }

  /// Initialize form with existing band data.
  void initFromBand(Band band) {
    state = BandFormState.fromBand(band);
  }

  /// Mark form as having unsaved changes.
  void markAsChanged() {
    if (!state.hasUnsavedChanges) {
      state = state.copyWith(hasUnsavedChanges: true);
    }
  }

  /// Update description.
  void updateDescription(String value) {
    state = state.copyWith(description: value);
    markAsChanged();
  }

  /// Toggle tag.
  void toggleTag(String tag, bool selected) {
    if (selected) {
      final newTags = List<String>.from(state.tags)..add(tag);
      state = state.copyWith(tags: newTags);
    } else {
      final newTags = List<String>.from(state.tags)..remove(tag);
      state = state.copyWith(tags: newTags);
    }
    markAsChanged();
  }

  /// Add member.
  void addMember(BandMember member) {
    final newMembers = List<BandMember>.from(state.members)..add(member);
    state = state.copyWith(members: newMembers);
    markAsChanged();
  }

  /// Remove member at index.
  void removeMember(int index) {
    if (index >= 0 && index < state.members.length) {
      final newMembers = List<BandMember>.from(state.members)..removeAt(index);
      state = state.copyWith(members: newMembers);
      markAsChanged();
    }
  }

  /// Update member at index.
  void updateMember(int index, BandMember member) {
    if (index >= 0 && index < state.members.length) {
      final newMembers = List<BandMember>.from(state.members);
      newMembers[index] = member;
      state = state.copyWith(members: newMembers);
      markAsChanged();
    }
  }

  /// Clear unsaved changes flag.
  void clearUnsavedChanges() {
    // Update the base band with current values
    final updatedBand = state.band.copyWith(
      description: state.description,
      tags: state.tags,
      members: state.members,
    );
    state = state.copyWith(
      band: updatedBand,
      hasUnsavedChanges: false,
    );
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

  /// Save band to repository.
  Future<bool> saveBand({
    required BandRepository bandRepo,
    required String uid,
  }) async {
    if (state.band.name.isEmpty) {
      setError(ApiError.validation(message: 'Band name is required'));
      return false;
    }

    state = state.copyWith(isSaving: true, error: null);

    try {
      // Create updated band with current form values
      final updatedBand = state.band.copyWith(
        description: state.description,
        tags: state.tags,
        members: state.members,
      );

      await bandRepo.saveBand(updatedBand, uid: uid);

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

  /// Auto-save band (silent save without error display).
  Future<bool> autoSave({
    required BandRepository bandRepo,
    required String uid,
  }) async {
    if (!state.hasUnsavedChanges) {
      return false;
    }

    setAutoSaving(true);

    try {
      // Create updated band with current form values
      final updatedBand = state.band.copyWith(
        description: state.description,
        tags: state.tags,
        members: state.members,
      );

      await bandRepo.saveBand(updatedBand, uid: uid);

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
    state = BandFormState(band: Band.empty, tags: [], members: []);
  }

  /// Reset form from band.
  void resetFromBand(Band band) {
    state = BandFormState.fromBand(band);
  }
}

/// Provider for band form error state (derived).
final bandFormErrorProvider = Provider<ApiError?>((ref) {
  return ref.watch(bandFormStateProvider).error;
});

/// Provider for band form unsaved changes state (derived).
final bandFormHasChangesProvider = Provider<bool>((ref) {
  return ref.watch(bandFormStateProvider).hasUnsavedChanges;
});

/// Provider for band form saving state (derived).
final bandFormIsSavingProvider = Provider<bool>((ref) {
  return ref.watch(bandFormStateProvider).isSaving;
});
