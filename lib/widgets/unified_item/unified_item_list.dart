import 'dart:async';

import 'package:flutter/material.dart';
import 'unified_item_model.dart';
import 'unified_item_card.dart';

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

  @override
  State<UnifiedItemList<T>> createState() => _UnifiedItemListState<T>();
}

class _UnifiedItemListState<T extends UnifiedItemModel>
    extends State<UnifiedItemList<T>> {
  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];

        return Dismissible(
          key: ValueKey(item.id),
          background: Container(
            color: Theme.of(context).colorScheme.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart &&
                widget.onDelete != null) {
              await widget.onDelete!(index);
              return true;
            }
            return false;
          },
          onDismissed: (direction) {
            // Already handled in confirmDismiss - do nothing here
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
        );
      },
      onReorder: (oldIndex, newIndex) {
        var adjustedIndex = newIndex;
        if (adjustedIndex > oldIndex) {
          adjustedIndex -= 1;
        }

        // Only call onReorder if it's enabled and the user is in manual sort mode
        if (widget.enableReorder && widget.onReorder != null) {
          widget.onReorder!(oldIndex, adjustedIndex);
        }
      },
    );
  }
}
