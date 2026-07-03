import 'package:flutter/material.dart';

/// Base interface for all unified items (Song, Band, Setlist)
abstract class UnifiedItemModel {
  String get id;
  String get title;
  String? get subtitle;
  String? get description;
  List<String> get tags;
  DateTime get createdAt;
  DateTime? get updatedAt;

  // Common action callbacks
  VoidCallback? get onEdit;
  VoidCallback? get onDelete;
  VoidCallback? get onTap;

  // Type-specific properties
  Map<String, dynamic> get typeSpecificData;

  // For swipe-to-delete confirmation
  String get deleteConfirmationMessage => 'Delete this item?';

  // Custom trailing actions
  List<UnifiedItemAction> get customActions => [];
}

/// Base action interface
abstract class UnifiedItemAction {
  Widget build(BuildContext context);
}

/// Delete action with theme colors
class DeleteAction implements UnifiedItemAction {

  DeleteAction({this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.delete,
        size: 20,
        color: Theme.of(context).colorScheme.error,
      ),
      onPressed: onPressed,
      tooltip: 'Delete',
    );
  }
}

/// Generic trailing icon action.
class IconAction implements UnifiedItemAction {
  IconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20, color: color),
      onPressed: onPressed,
      tooltip: tooltip,
    );
  }
}

/// 3-dots overflow menu of (label, icon, callback) entries.
class OverflowMenuAction implements UnifiedItemAction {
  OverflowMenuAction({required this.entries});

  final List<(String, IconData, VoidCallback)> entries;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      icon: const Icon(Icons.more_vert, size: 20),
      tooltip: 'More',
      onSelected: (i) => entries[i].$3(),
      itemBuilder: (context) => [
        for (var i = 0; i < entries.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Row(
              children: [
                Icon(entries[i].$2, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(entries[i].$1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Edit action with theme colors
class EditAction implements UnifiedItemAction {

  EditAction({this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.edit,
        size: 20,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onPressed: onPressed,
      tooltip: 'Edit',
    );
  }
}
