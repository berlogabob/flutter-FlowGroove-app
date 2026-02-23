import 'package:flutter/material.dart';
import 'unified_item_model.dart';
import 'unified_item_trailing_actions.dart';
import 'adapters/song_item_adapter.dart';
import 'adapters/band_item_adapter.dart';

/// List widget with swipe-to-delete and drag-and-drop reordering
class UnifiedItemList<T extends UnifiedItemModel> extends StatefulWidget {
  final List<T> items;
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
        final additionalActions =
            widget.additionalActionsBuilder?.call(index) ?? [];

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
          child: Card(
            key: Key('card-${item.id}'),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 0,
            color: Theme.of(context).colorScheme.surface,
            child: ListTile(
              leading: widget.enableReorder
                  ? ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle, color: Colors.grey),
                    )
                  : _buildLeadingIcon(context, item),
              title: Text(
                item.title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: widget.showCompact
                      ? FontWeight.w500
                      : FontWeight.bold,
                  fontSize: widget.showCompact ? 14 : 16,
                ),
              ),
              subtitle: _buildSubtitle(context, item),
              trailing: UnifiedItemTrailingActions(
                item: item,
                onEdit: widget.onEdit != null
                    ? () => widget.onEdit!(index)
                    : null,
                onDelete: widget.onDelete != null
                    ? () => widget.onDelete!(index)
                    : null,
                customActions: item.customActions.map((a) => a).toList(),
                additionalActions: additionalActions,
                showCompact: widget.showCompact,
              ),
              onTap: widget.onTap != null ? () => widget.onTap!(index) : null,
            ),
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

  Widget _buildLeadingIcon(BuildContext context, T item) {
    IconData icon;
    bool isShared = false;

    if (item is SongItemAdapter) {
      icon = Icons.music_note;
      isShared = item.isShared;
    } else if (item is BandItemAdapter) {
      icon = Icons.groups;
    } else {
      icon = Icons.info;
    }

    return CircleAvatar(
      backgroundColor: isShared
          ? const Color(0xFFFFE0B2)
          : const Color(0xFF1A1A1A),
      child: Icon(
        isShared ? Icons.content_copy : icon,
        color: isShared ? const Color(0xFFFF9800) : Colors.orange,
      ),
    );
  }

  Widget _buildSubtitle(BuildContext context, T item) {
    if (widget.showCompact) {
      return _buildCompactSubtitle(item);
    }

    final List<Widget> subtitleWidgets = [];

    if (item is SongItemAdapter) {
      final song = item;
      if (song.subtitle?.isNotEmpty == true) {
        subtitleWidgets.add(
          Text(
            song.subtitle!,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        );
      }

      // Add BPM and key badges
      if (song.ourBPM != null || song.ourKey != null) {
        final List<Widget> badges = [];
        if (song.ourBPM != null) {
          badges.add(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE0B2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${song.ourBPM} BPM',
                style: const TextStyle(
                  color: Color(0xFFFF9800),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          );
        }
        if (song.ourKey != null) {
          badges.add(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE0B2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                song.ourKey!,
                style: const TextStyle(
                  color: Color(0xFFFF9800),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          );
        }
        subtitleWidgets.add(Row(children: badges));
      }
    } else if (item is BandItemAdapter) {
      final band = item;
      if (band.subtitle?.isNotEmpty == true) {
        subtitleWidgets.add(
          Text(
            band.subtitle!,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        );
      }
      final membersCount = band.membersCount;
      subtitleWidgets.add(
        Text(
          '$membersCount ${membersCount == 1 ? 'member' : 'members'}',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: subtitleWidgets,
    );
  }

  Widget _buildCompactSubtitle(T item) {
    final List<Widget> compactSubtitles = [];

    if (item is SongItemAdapter) {
      final song = item;
      if (song.ourKey != null) {
        compactSubtitles.add(
          Text(
            song.ourKey!,
            style: const TextStyle(
              color: Color(0xFFFF9800),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        );
      }
      if (song.ourBPM != null) {
        compactSubtitles.add(const SizedBox(width: 8));
        compactSubtitles.add(
          Text(
            '${song.ourBPM} BPM',
            style: const TextStyle(color: Color(0xFFFF9800), fontSize: 12),
          ),
        );
      }
    }

    return Row(children: compactSubtitles);
  }
}
