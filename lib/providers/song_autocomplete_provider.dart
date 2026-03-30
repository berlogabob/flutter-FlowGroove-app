import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song_suggestion.dart';

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
