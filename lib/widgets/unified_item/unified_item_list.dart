import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/mono_pulse_theme.dart';
import 'unified_item_card.dart';
import 'unified_item_model.dart';

/// Optimized list widget with swipe-to-delete and drag-and-drop reordering
class UnifiedItemList<T extends UnifiedItemModel> extends StatefulWidget {

  const UnifiedItemList({
    required this.items,
    super.key,
    this.onRefresh,
    this.onReorder,
    this.onDelete,
    this.onTap,
    this.onEdit,
    this.showCompact = false,
    this.enableReorder = false,
    this.additionalActionsBuilder,
    this.padding,
  });
  final List<T> items;
  final VoidCallback? onRefresh;
  final void Function(int, int)? onReorder;
  final FutureOr<void> Function(int)? onDelete;
  final void Function(int)? onTap;
  final void Function(int)? onEdit;
  final bool showCompact;
  final bool enableReorder;
  final List<UnifiedItemAction> Function(int)? additionalActionsBuilder;
  final EdgeInsets? padding;

  @override
  State<UnifiedItemList<T>> createState() => _UnifiedItemListState<T>();
}

class _UnifiedItemListState<T extends UnifiedItemModel>
    extends State<UnifiedItemList<T>> {
  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      // The framework's default handle renders OUTSIDE each item's own rounded
      // container (it "escapes the card"). Turn it off and drive reorder from a
      // long-press on the card body instead — matches the gesture-first pattern
      // (tap = edit, swipe = delete).
      buildDefaultDragHandles: false,
      padding: widget.padding,
      physics: const AlwaysScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];

        return ReorderableDelayedDragStartListener(
          key: ValueKey('drag_${item.id}'),
          index: index,
          child: Dismissible(
          key: ValueKey(item.id),
          background: Container(
            color: Theme.of(context).colorScheme.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: MonoPulseSpacing.lg),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart &&
                widget.onDelete != null) {
              await widget.onDelete!(index);
            }
            // Always return false: these lists are stream/provider-backed, so
            // the row is removed reactively when the data updates. Returning
            // true would make Dismissible drop the widget immediately, but the
            // async delete (e.g. the band-leave Cloud Function) hasn't yet
            // updated `items`, so the dismissed widget would still be in the
            // tree on the next build → "dismissed Dismissible still part of the
            // tree" assertion. Letting the data drive removal avoids that.
            return false;
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (widget.onTap != null) {
                widget.onTap!(index);
              } else if (widget.onEdit != null) {
                widget.onEdit!(index);
              }
            },
            child: UnifiedItemCard<T>(
              item: item,
              showCompact: widget.showCompact,
              customActions: widget.additionalActionsBuilder?.call(index) ?? [],
              onEdit: widget.onEdit != null
                  ? () => widget.onEdit!(index)
                  : null,
              onDelete: widget.onDelete != null
                  ? () => widget.onDelete!(index)
                  : null,
              onTap: widget.onTap != null ? () => widget.onTap!(index) : null,
            ),
          ),
          ),
        );
      },
      onReorderItem: (oldIndex, newIndex) {
        // Only call onReorder if it's enabled and the user is in manual sort mode
        if (widget.enableReorder && widget.onReorder != null) {
          widget.onReorder!(oldIndex, newIndex);
        }
      },
    );
  }
}
