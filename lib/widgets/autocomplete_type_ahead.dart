import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import '../models/song_suggestion.dart';
import '../services/song_suggestion_service.dart';
import '../services/musicbrainz_service.dart';
import '../repositories/firestore_song_repository.dart';
import 'suggestion_card.dart';

/// Autocomplete TypeAhead field for song search
/// 
/// Provides real-time song suggestions as user types, combining:
/// - Personal library
/// - Group libraries
/// - MusicBrainz API
/// 
/// Features:
/// - Debounced search (300ms delay)
/// - Overlay dropdown with suggestions
/// - Loading indicator
/// - Keyboard navigation
/// - Touch-friendly cards
/// 
/// Usage:
/// ```dart
/// AutocompleteTypeAhead(
///   onSuggestionSelected: (suggestion) {
///     // Handle selection
///   },
///   bandId: currentBandId, // Optional
/// )
/// ```
class AutocompleteTypeAhead extends StatefulWidget {
  /// Callback when user selects a suggestion
  final ValueChanged<SongSuggestion> onSuggestionSelected;

  /// Band ID for group song suggestions
  final String? bandId;

  /// Hint text for the input field
  final String hint;

  /// Icon to show in prefix
  final IconData icon;

  /// Minimum characters before searching
  final int minLength;

  /// Debounce delay in milliseconds
  final int debounceMs;

  /// Maximum suggestions to show
  final int maxSuggestions;

  const AutocompleteTypeAhead({
    super.key,
    required this.onSuggestionSelected,
    this.bandId,
    this.hint = 'Search songs...',
    this.icon = Icons.music_note,
    this.minLength = 2,
    this.debounceMs = 300,
    this.maxSuggestions = 8,
  });

  @override
  State<AutocompleteTypeAhead> createState() => _AutocompleteTypeAheadState();
}

class _AutocompleteTypeAheadState extends State<AutocompleteTypeAhead> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  
  OverlayEntry? _overlayEntry;
  List<SongSuggestion> _suggestions = [];
  bool _isLoading = false;
  String? _error;
  Timer? _debounceTimer;
  
  int _selectedIndex = -1;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initService();
  }

  void _initService() {
    // TODO: Get from provider when integrated
    // For now, service will be created on-demand
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    _hideOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      if (_controller.text.length >= widget.minLength) {
        _fetchSuggestions(_controller.text);
      }
    } else {
      // Delay hiding to allow tap on suggestion
      Future.delayed(const Duration(milliseconds: 200), () {
        _hideOverlay();
      });
    }
  }

  void _onTextChanged() {
    _debounceTimer?.cancel();
    
    if (_controller.text.length < widget.minLength) {
      _hideOverlay();
      return;
    }

    _debounceTimer = Timer(Duration(milliseconds: widget.debounceMs), () {
      _fetchSuggestions(_controller.text);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final service = SongSuggestionService(
        songRepo: FirestoreSongRepository(),
        musicBrainz: MusicBrainzService(),
        userId: user?.uid ?? '',
        bandId: widget.bandId,
      );

      final suggestions = await service.getSuggestions(
        query: query,
        limit: widget.maxSuggestions,
      );

      if (!mounted) return;

      setState(() {
        _suggestions = suggestions;
        _isLoading = false;
        _selectedIndex = -1;
      });

      _showOverlay();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _hideOverlay,
        child: Container(
          color: Colors.transparent,
          child: SafeArea(
            child: UnconstrainedBox(
              child: SizedBox(
                width: MediaQuery.of(context).size.width - 32,
                child: CompositedTransformFollower(
                  link: _layerLink,
                  offset: const Offset(0, 4),
                  child: _SuggestionDropdown(
                    suggestions: _suggestions,
                    isLoading: _isLoading,
                    error: _error,
                    selectedIndex: _selectedIndex,
                    onSuggestionSelected: _selectSuggestion,
                    onNavigate: _handleKeyboardNavigation,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _selectedIndex = -1;
  }

  void _selectSuggestion(SongSuggestion suggestion) {
    widget.onSuggestionSelected(suggestion);
    _hideOverlay();
  }

  void _handleKeyboardNavigation(int newIndex) {
    setState(() {
      _selectedIndex = newIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: Icon(widget.icon),
          suffixIcon: _buildSuffixIcon(),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (_) {
          // Handle enter key
          if (_suggestions.isNotEmpty && _selectedIndex >= 0) {
            _selectSuggestion(_suggestions[_selectedIndex]);
          }
        },
      ),
    );
  }

  Widget? _buildSuffixIcon() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_controller.text.isNotEmpty) {
      return IconButton(
        icon: const Icon(Icons.clear, size: 20),
        onPressed: () {
          _controller.clear();
          _hideOverlay();
          _focusNode.requestFocus();
        },
      );
    }

    return null;
  }
}

/// Suggestion dropdown widget
class _SuggestionDropdown extends StatelessWidget {
  final List<SongSuggestion> suggestions;
  final bool isLoading;
  final String? error;
  final int selectedIndex;
  final ValueChanged<SongSuggestion> onSuggestionSelected;
  final ValueChanged<int> onNavigate;

  const _SuggestionDropdown({
    required this.suggestions,
    required this.isLoading,
    this.error,
    required this.selectedIndex,
    required this.onSuggestionSelected,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(
          maxHeight: 400,
          minHeight: 100,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          ),
        ),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (error != null) {
      return _buildErrorState(context);
    }

    if (isLoading) {
      return _buildLoadingState();
    }

    if (suggestions.isEmpty) {
      return _buildEmptyState(context);
    }

    return _buildSuggestionsList(context);
  }

  Widget _buildErrorState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'Search failed',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Please try again',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const SizedBox(
      height: 100,
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            color: Theme.of(context).colorScheme.outline,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'No songs found',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different search',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        final isSelected = index == selectedIndex;

        return SuggestionCard(
          suggestion: suggestion,
          isSelected: isSelected,
          onTap: () => onSuggestionSelected(suggestion),
        );
      },
    );
  }
}
