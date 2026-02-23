import 'package:flutter/material.dart';
import 'unified_item_model.dart';
import 'unified_item_trailing_actions.dart';

/// Optimized list widget with swipe-to-delete and drag-and-drop reordering
class UnifiedItemList<T extends UnifiedItemModel> extends StatefulWidget {
  final List<T> items;
  final VoidCallback? onRefresh;
  final Function(int, int)? onReorder;
  final Function(int)? onDelete;
  final Function(int)? onTap;
  final Function(int)? onEdit;
  final bool showCompact;
  final bool enableReorder;
  final List<UnifiedItemAction> Function(int)? additionalActionsBuilder;

  const UnifiedItemList({
    super.key,
    required this.items,
    this.onRefresh,
    this.onReorder,
    this.onDelete,
    this.onTap,
    this.onEdit,
    this.showCompact = false,
    this.enableReorder = false,
    this.additionalActionsBuilder,
  });

  @override
  State<UnifiedItemList<T>> createState() => _UnifiedItemListState<T>();
}

class _UnifiedItemListState<T extends UnifiedItemModel>
    extends State<UnifiedItemList<T>> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
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
            if (direction == DismissDirection.endToStart &&
                widget.onDelete != null) {
              widget.onDelete!(index);
            }
          },
          child: GestureDetector(
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
    );
  }
}
