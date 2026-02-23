import 'package:flutter/material.dart';
import 'unified_item_model.dart';
import 'unified_item_card.dart';

/// List widget with swipe-to-delete and drag-and-drop reordering
class UnifiedItemList<T extends UnifiedItemModel> extends StatefulWidget {
  final List<T> items;
  final Function(int, int)? onReorder;
  final Function(int)? onDelete;
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
            color: Theme.of(context).colorScheme.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              // Show confirmation dialog
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Item'),
                  content: Text(item.deleteConfirmationMessage),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        'Delete',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              return confirmed ?? false;
            }
            return false;
          },
          onDismissed: (direction) {
            if (direction == DismissDirection.endToStart) {
              _items.removeAt(index);
              setState(() {});

              // Notify parent of deletion
              if (widget.onDelete != null) {
                widget.onDelete!(index);
              }
            }
          },
          child: UnifiedItemCard<T>(
            item: item,
            showCompact: widget.showCompact,
            onEdit: widget.items[index].onEdit,
            onDelete: () {
              // Handle delete from card
              if (widget.onDelete != null) {
                widget.onDelete!(index);
              }
            },
            onTap: widget.items[index].onTap,
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
          widget.onReorder!(oldIndex, newIndex);
        }
      },
    );
  }
}
