import 'package:flutter/foundation.dart';

import '../models/song_suggestion.dart';

/// Simple notifier for autocomplete state (using ChangeNotifier instead of StateNotifier)
class AutocompleteNotifier extends ChangeNotifier {
  String _query = '';
  List<SongSuggestion> _suggestions = [];
  bool _isLoading = false;
  String? _error;
  SongSuggestion? _selectedSuggestion;

  String get query => _query;
  List<SongSuggestion> get suggestions => _suggestions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  SongSuggestion? get selectedSuggestion => _selectedSuggestion;

  void updateQuery(String query) {
    _query = query;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setSuggestions(List<SongSuggestion> suggestions) {
    _suggestions = suggestions;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void selectSuggestion(SongSuggestion? suggestion) {
    _selectedSuggestion = suggestion;
    notifyListeners();
  }

  void clear() {
    _query = '';
    _suggestions = [];
    _isLoading = false;
    _error = null;
    _selectedSuggestion = null;
    notifyListeners();
  }
}
