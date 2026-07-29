/// Riverpod provider for song autocomplete/search suggestions.
///
/// Provides debounced search across external catalogs (canonical,
/// Spotify, MusicBrainz) via SongSuggestionService.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song_suggestion.dart';
import '../providers/data/data_providers.dart';
import '../services/musicbrainz_service.dart';
import '../services/song_suggestion_service.dart';

/// State for autocomplete search.
class AutocompleteSearchState {

  const AutocompleteSearchState({
    this.query = '',
    this.suggestions = const [],
    this.isLoading = false,
    this.error,
    this.selectedIndex = -1,
  });

  const AutocompleteSearchState.initial()
    : query = '',
      suggestions = const [],
      isLoading = false,
      error = null,
      selectedIndex = -1;
  final String query;
  final List<SongSuggestion> suggestions;
  final bool isLoading;
  final String? error;
  final int selectedIndex;

  AutocompleteSearchState copyWith({
    String? query,
    List<SongSuggestion>? suggestions,
    bool? isLoading,
    String? error,
    int? selectedIndex,
  }) {
    return AutocompleteSearchState(
      query: query ?? this.query,
      suggestions: suggestions ?? this.suggestions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedIndex: selectedIndex ?? this.selectedIndex,
    );
  }
}

/// Notifier for autocomplete search.
class AutocompleteSearchNotifier extends Notifier<AutocompleteSearchState> {
  Timer? _debounceTimer;
  SongSuggestionService? _service;

  SongSuggestionService get _suggestionService {
    // Autofill searches external catalogs only (canonical/Spotify/
    // MusicBrainz) — the user's own library is not a suggestion source (#78).
    _service ??= SongSuggestionService(
      canonicalRepo: ref.read(canonicalSongRepositoryProvider),
      musicBrainz: MusicBrainzService(),
    );
    return _service!;
  }

  /// Kept for call-site compatibility; external-only search needs no
  /// user/band context.
  void init({String? userId, String? bandId}) {
    _service = null;
  }

  @override
  AutocompleteSearchState build() {
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    return const AutocompleteSearchState.initial();
  }

  /// Update search query with debouncing.
  void updateQuery(String query, {int debounceMs = 300}) {
    state = state.copyWith(query: query, selectedIndex: -1);

    _debounceTimer?.cancel();

    if (query.length < 2) {
      state = state.copyWith(suggestions: [], isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true);

    _debounceTimer = Timer(Duration(milliseconds: debounceMs), () {
      _fetchSuggestions(query);
    });
  }

  /// Fetch suggestions from all sources.
  Future<void> _fetchSuggestions(String query) async {
    try {
      final suggestions = await _suggestionService.getSuggestions(
        query: query,
        limit: 8,
      );

      state = state.copyWith(
        suggestions: suggestions,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        suggestions: [],
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Select a suggestion.
  void selectSuggestion(SongSuggestion suggestion) {
    state = state.copyWith(
      query: suggestion.title,
      suggestions: [],
      isLoading: false,
    );
  }

  /// Navigate with keyboard (arrow keys).
  void navigate(int direction) {
    final maxIndex = state.suggestions.length - 1;
    final newIndex = (state.selectedIndex + direction).clamp(-1, maxIndex);
    state = state.copyWith(selectedIndex: newIndex);
  }

  /// Clear search state.
  void clear() {
    _debounceTimer?.cancel();
    state = const AutocompleteSearchState.initial();
  }

  void dispose() {
    _debounceTimer?.cancel();
  }
}

/// Provider for autocomplete search.
final autocompleteSearchProvider =
    NotifierProvider<AutocompleteSearchNotifier, AutocompleteSearchState>(
      AutocompleteSearchNotifier.new,
    );
