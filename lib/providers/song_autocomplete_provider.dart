/// Riverpod provider for song autocomplete/search suggestions.
///
/// Provides debounced search across personal library, band library,
/// and MusicBrainz API via SongSuggestionService.
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth/auth_provider.dart';
import '../providers/data/data_providers.dart';
import '../models/song_suggestion.dart';
import '../services/song_suggestion_service.dart';
import '../services/musicbrainz_service.dart';

/// State for autocomplete search.
class AutocompleteSearchState {
  final String query;
  final List<SongSuggestion> suggestions;
  final bool isLoading;
  final String? error;
  final int selectedIndex;

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
  String? _userId;
  String? _bandId;
  SongSuggestionService? _service;

  SongSuggestionService get _suggestionService {
    _service ??= SongSuggestionService(
      songRepo: ref.read(songRepositoryProvider),
      canonicalRepo: ref.read(canonicalSongRepositoryProvider),
      musicBrainz: MusicBrainzService(),
      userId: _userId ?? '',
      bandId: _bandId,
    );
    return _service!;
  }

  /// Initialize with user/band context.
  void init({String? userId, String? bandId}) {
    _userId = userId ?? ref.read(currentUserProvider).value?.uid;
    _bandId = bandId;
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
    state = state.copyWith(query: query, selectedIndex: -1, error: null);

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
        error: null,
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
