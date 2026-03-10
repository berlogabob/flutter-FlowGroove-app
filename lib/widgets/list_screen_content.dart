import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/mono_pulse_theme.dart';
import 'unified_item/unified_item_model.dart';
import 'unified_item/unified_item_list.dart';
import 'unified_item/unified_filter_sort_widget.dart';
import 'empty_state.dart';
import 'error_banner.dart';
import 'loading_indicator.dart';

/// Generic list content widget for displaying unified items.
///
/// Features:
/// - Loading, error, and empty state handling
/// - Filter/sort widget integration
/// - Swipe-to-delete and drag-and-drop support
/// - Type-specific item rendering via adapters
///
/// Usage:
/// ```dart
/// ListScreenContent<SongItemAdapter>(
///   items: songAdapters,
///   itemsAsync: songsProvider,
///   filterWidget: UnifiedFilterSortWidget(...),
///   emptyStateBuilder: () => EmptyState.songs(onAdd: _addSong),
///   onDelete: _deleteSong,
///   onEdit: _editSong,
///   onTap: _viewSong,
/// )
/// ```
class ListScreenContent<T extends UnifiedItemModel>
    extends ConsumerStatefulWidget {
  /// List of items to display.
  final List<T> items;

  /// Async value for loading/error states (optional).
  final AsyncValue<List<dynamic>>? itemsAsync;

  /// Current sort option.
  final SortOption sortOption;

  /// Current filter text.
  final String? filterText;

  /// Widget for additional filters (e.g., Key/BPM chips, tag cloud).
  final Widget? additionalFilters;

  /// Tag cloud widget (optional).
  final Widget? tagCloud;

  /// Enable manual reordering (drag-and-drop).
  final bool enableReorder;

  /// Callback when items are reordered.
  final Function(int, int)? onReorder;

  /// Callback when item is deleted.
  final Function(int)? onDelete;

  /// Callback when item is edited.
  final Function(int)? onEdit;

  /// Callback when item is tapped.
  final Function(int)? onTap;

  /// Builder for additional custom actions.
  final List<UnifiedItemAction> Function(int)? additionalActionsBuilder;

  /// Factory for empty state when no items exist.
  final EmptyState Function() emptyStateBuilder;

  /// Factory for empty state when search returns no results.
  final EmptyState Function(String query)? searchEmptyStateBuilder;

  const ListScreenContent({
    super.key,
    required this.items,
    this.itemsAsync,
    this.sortOption = SortOption.manual,
    this.filterText,
    this.additionalFilters,
    this.tagCloud,
    this.enableReorder = false,
    this.onReorder,
    this.onDelete,
    this.onEdit,
    this.onTap,
    this.additionalActionsBuilder,
    required this.emptyStateBuilder,
    this.searchEmptyStateBuilder,
  });

  @override
  ConsumerState<ListScreenContent<T>> createState() =>
      _ListScreenContentState<T>();
}

class _ListScreenContentState<T extends UnifiedItemModel>
    extends ConsumerState<ListScreenContent<T>> {
  @override
  Widget build(BuildContext context) {
    // Handle loading state
    if (widget.itemsAsync?.isLoading == true && widget.items.isEmpty) {
      return const LoadingIndicator();
    }

    // Handle error state
    final error = widget.itemsAsync?.error;
    if (error != null && widget.items.isEmpty) {
      return ErrorBanner.card(message: error.toString(), onRetry: () {});
    }

    // Build content
    return Column(
      children: [
        // Filter/Sort widget
        if (widget.filterText != null || widget.sortOption != SortOption.manual)
          Padding(
            padding: const EdgeInsets.all(MonoPulseSpacing.lg),
            child: UnifiedFilterSortWidget(
              currentSort: widget.sortOption,
              onSortChanged: (_) {},
              filterText: widget.filterText,
              onFilterChanged: (_) {},
            ),
          ),

        // Additional filters (Key/BPM chips, etc.)
        if (widget.additionalFilters != null) widget.additionalFilters!,

        // Tag cloud
        if (widget.tagCloud != null) widget.tagCloud!,

        // List or empty state
        Expanded(
          child: widget.items.isEmpty ? _buildEmptyState() : _buildList(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final hasFilter =
        widget.filterText != null && widget.filterText!.isNotEmpty;

    if (hasFilter && widget.searchEmptyStateBuilder != null) {
      return widget.searchEmptyStateBuilder!(widget.filterText!);
    }

    return widget.emptyStateBuilder();
  }

  Widget _buildList() {
    return UnifiedItemList<T>(
      items: widget.items,
      enableReorder: widget.enableReorder,
      onReorder: widget.onReorder,
      onDelete: widget.onDelete,
      onTap: widget.onTap,
      onEdit: widget.onEdit,
      additionalActionsBuilder: widget.additionalActionsBuilder,
    );
  }
}

/// Extension for accessing sort/filter callbacks from parent widgets.
extension ListScreenContentCallbacks<T extends UnifiedItemModel>
    on ListScreenContent<T> {
  /// Get sort option changed callback.
  ValueChanged<SortOption?> get onSortChanged => (option) {
    // To be implemented by parent widget
  };

  /// Get filter text changed callback.
  ValueChanged<String?> get onFilterChanged => (value) {
    // To be implemented by parent widget
  };
}
