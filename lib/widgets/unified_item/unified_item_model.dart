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
  final VoidCallback? onPressed;

  DeleteAction({this.onPressed});

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

/// Edit action with theme colors
class EditAction implements UnifiedItemAction {
  final VoidCallback? onPressed;

  EditAction({this.onPressed});

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
