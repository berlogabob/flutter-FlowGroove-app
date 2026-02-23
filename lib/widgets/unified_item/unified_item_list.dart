import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import 'unified_item_model.dart';
import 'unified_item_card.dart';

class UnifiedItemList<T extends UnifiedItemModel> extends StatefulWidget {
  final List<T> items;
  final VoidCallback? onReorder;
  final VoidCallback? onDelete;
  final bool showCompact;

  const UnifiedItemList({
    super.key,
    required this.items,
    this.onReorder,
    this.onDelete,
    this.showCompact = false,
  });

  @override
  State<UnifiedItemList<T>> createState() => _UnifiedItemListState<T>();
}

class _UnifiedItemListState<T extends UnifiedItemModel>
    extends State<UnifiedItemList<T>> {
  final List<T> _items = [];

  @override
  void initState() {
    super.initState();
    _items.addAll(widget.items);
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];

        return Dismissible(
          key: ValueKey(item.id),
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              // Delete action
              if (widget.onDelete != null) {
                widget.onDelete!();
              }
              return true;
            }
            return false;
          },
          onDismissed: (direction) {
            if (direction == DismissDirection.endToStart) {
              final removedItem = _items.removeAt(index);
              setState(() {});

              // Notify parent of deletion
              if (widget.onDelete != null) {
                widget.onDelete!();
              }
            }
          },
          child: UnifiedItemCard<T>(
            item: item,
            showCompact: widget.showCompact,
            onTap: () {
              // Handle tap to edit
              // This will be handled by the screen-level implementation
            },
          ),
        );
      },
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) {
          newIndex -= 1;
        }
        final item = _items.removeAt(oldIndex);
        _items.insert(newIndex, item);
        setState(() {});

        // Notify parent of reordering
        if (widget.onReorder != null) {
          widget.onReorder!();
        }
      },
    );
  }
}
