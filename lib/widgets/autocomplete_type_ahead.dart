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
/// - Touch-friendly cards (≥48dp)
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
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song_suggestion.dart';
import '../providers/song_autocomplete_provider.dart';
import 'suggestion_card.dart';

/// Autocomplete TypeAhead widget for song search.
class AutocompleteTypeAhead extends ConsumerStatefulWidget {
  const AutocompleteTypeAhead({
    super.key,
    required this.onSuggestionSelected,
    this.hint = 'Search songs...',
    this.icon = Icons.music_note,
    this.minLength = 2,
    this.debounceMs = 300,
    this.maxSuggestions = 8,
    this.bandId,
  });

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

  @override
  ConsumerState<AutocompleteTypeAhead> createState() =>
      _AutocompleteTypeAheadState();
}

class _AutocompleteTypeAheadState extends ConsumerState<AutocompleteTypeAhead> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChanged);

    // Initialize provider with context after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(autocompleteSearchProvider.notifier).init(bandId: widget.bandId);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _hideOverlay();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AutocompleteTypeAhead oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bandId != widget.bandId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(autocompleteSearchProvider.notifier)
            .init(bandId: widget.bandId);
        ref.read(autocompleteSearchProvider.notifier).clear();
        _hideOverlay();
      });
    }
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      if (_controller.text.length >= widget.minLength) {
        ref
            .read(autocompleteSearchProvider.notifier)
            .updateQuery(_controller.text, debounceMs: widget.debounceMs);
      }
    } else {
      Future.delayed(const Duration(milliseconds: 200), () {
        _hideOverlay();
      });
    }
  }

  void _onTextChanged() {
    ref
        .read(autocompleteSearchProvider.notifier)
        .updateQuery(_controller.text, debounceMs: widget.debounceMs);
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final searchState = ref.read(autocompleteSearchProvider);
        return GestureDetector(
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
                      suggestions: searchState.suggestions,
                      isLoading: searchState.isLoading,
                      error: searchState.error,
                      selectedIndex: searchState.selectedIndex,
                      onSuggestionSelected: _selectSuggestion,
                      onNavigate: _handleKeyboardNavigation,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectSuggestion(SongSuggestion suggestion) {
    ref.read(autocompleteSearchProvider.notifier).selectSuggestion(suggestion);
    widget.onSuggestionSelected(suggestion);
    _hideOverlay();
  }

  void _handleKeyboardNavigation(int direction) {
    ref.read(autocompleteSearchProvider.notifier).navigate(direction);
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider for loading state (suffix icon) and suggestions count
    final searchState = ref.watch(autocompleteSearchProvider);

    // Show/hide overlay based on state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final shouldShowOverlay =
          _focusNode.hasFocus &&
          (searchState.suggestions.isNotEmpty || searchState.isLoading);
      if (shouldShowOverlay) {
        _showOverlay();
        _overlayEntry?.markNeedsBuild();
      } else {
        _hideOverlay();
      }
    });

    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: Icon(widget.icon),
          suffixIcon: _buildSuffixIcon(searchState.isLoading),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (_) {
          if (searchState.suggestions.isNotEmpty &&
              searchState.selectedIndex >= 0) {
            _selectSuggestion(
              searchState.suggestions[searchState.selectedIndex],
            );
          }
        },
      ),
    );
  }

  Widget? _buildSuffixIcon(bool isLoading) {
    if (isLoading) {
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
          ref.read(autocompleteSearchProvider.notifier).clear();
          _focusNode.requestFocus();
        },
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      );
    }

    return null;
  }
}

/// Suggestion dropdown widget
class _SuggestionDropdown extends StatelessWidget {
  const _SuggestionDropdown({
    required this.suggestions,
    required this.isLoading,
    this.error,
    required this.selectedIndex,
    required this.onSuggestionSelected,
    required this.onNavigate,
  });

  final List<SongSuggestion> suggestions;
  final bool isLoading;
  final String? error;
  final int selectedIndex;
  final ValueChanged<SongSuggestion> onSuggestionSelected;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 400, minHeight: 100),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
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
          Text('Search failed', style: Theme.of(context).textTheme.titleSmall),
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
      child: Center(child: CircularProgressIndicator()),
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
          Text('No songs found', style: Theme.of(context).textTheme.titleSmall),
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
