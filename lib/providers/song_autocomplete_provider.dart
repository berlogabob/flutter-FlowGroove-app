import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/canonical_song_repository.dart';
import '../repositories/firestore_song_repository.dart';
import '../services/musicbrainz_service.dart';
import '../services/song_suggestion_service.dart';
import '../models/song_suggestion.dart';

/// Provider for MusicBrainzService
final musicBrainzServiceProvider = Provider<MusicBrainzService>((ref) {
  return MusicBrainzService();
});

/// Provider for CanonicalSongRepository
final canonicalSongRepositoryProvider = Provider<CanonicalSongRepository>((ref) {
  return FirestoreCanonicalSongRepository();
});

/// Provider for SongSuggestionService
/// 
/// Requires userId and optional bandId from the current context.
/// Use this provider within a screen that has access to user/band context.
final songSuggestionServiceProvider = Provider.family<SongSuggestionService, String?>((ref, bandId) {
  final user = FirebaseAuth.instance.currentUser;
  
  if (user == null) {
    throw StateError('User must be authenticated to use SongSuggestionService');
  }
  
  return SongSuggestionService(
    songRepo: ref.read(songRepositoryProvider),
    musicBrainz: ref.read(musicBrainzServiceProvider),
    userId: user.uid,
    bandId: bandId,
  );
});

/// Provider for autocomplete suggestions
/// 
/// Watches the query and returns suggestions.
/// Use with FutureBuilder or AsyncValue for UI state.
final songSuggestionsProvider = FutureProvider.family<List<SongSuggestion>, String>((ref, query) async {
  if (query.length < 2) {
    return [];
  }
  
  // Get service without band context for general search
  final service = ref.read(songSuggestionServiceProvider(null));
  
  return await service.getSuggestions(
    query: query,
    limit: 10,
  );
});

/// Provider for autocomplete suggestions with band context
final songSuggestionsWithBandProvider = FutureProvider.family<List<SongSuggestion>, ({String query, String? bandId})>((ref, params) async {
  if (params.query.length < 2) {
    return [];
  }
  
  final service = ref.read(songSuggestionServiceProvider(params.bandId));
  
  return await service.getSuggestions(
    query: params.query,
    limit: 10,
  );
});

/// State notifier for managing autocomplete state
class AutocompleteStateNotifier extends StateNotifier<AutocompleteState> {
  AutocompleteStateNotifier() : super(const AutocompleteState());

  void updateQuery(String query) {
    state = state.copyWith(query: query);
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void setSuggestions(List<SongSuggestion> suggestions) {
    state = state.copyWith(suggestions: suggestions);
  }

  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  void selectSuggestion(SongSuggestion? suggestion) {
    state = state.copyWith(selectedSuggestion: suggestion);
  }

  void clear() {
    state = const AutocompleteState();
  }
}

/// Provider for autocomplete state management
final autocompleteStateProvider = StateNotifierProvider<AutocompleteStateNotifier, AutocompleteState>((ref) {
  return AutocompleteStateNotifier();
});

/// Current autocomplete state
class AutocompleteState {
  final String query;
  final List<SongSuggestion> suggestions;
  final bool isLoading;
  final String? error;
  final SongSuggestion? selectedSuggestion;

  const AutocompleteState({
    this.query = '',
    this.suggestions = const [],
    this.isLoading = false,
    this.error,
    this.selectedSuggestion,
  });

  AutocompleteState copyWith({
    String? query,
    List<SongSuggestion>? suggestions,
    bool? isLoading,
    String? error,
    SongSuggestion? selectedSuggestion,
  }) {
    return AutocompleteState(
      query: query ?? this.query,
      suggestions: suggestions ?? this.suggestions,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      selectedSuggestion: selectedSuggestion ?? this.selectedSuggestion,
    );
  }
}
