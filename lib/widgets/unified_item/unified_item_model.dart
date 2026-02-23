import 'package:flutter/material.dart';

abstract class UnifiedItemModel {
  String get id;
  String get title;
  String? get subtitle;
  String? get description;
  List<String> get tags;
  DateTime get createdAt;
  DateTime get updatedAt;

  // Common action callbacks
  VoidCallback? get onEdit;
  VoidCallback? get onDelete;
  VoidCallback? get onTap;

  // Type-specific properties (to be implemented by concrete classes)
  Map<String, dynamic> get typeSpecificData;

  // Optional: for swipe-to-delete confirmation
  String get deleteConfirmationMessage => 'Delete this item?';

  // Optional: for custom trailing actions
  List<UnifiedItemAction> get customActions => [];
}

abstract class UnifiedItemAction {
  Widget build();
}

class DeleteAction implements UnifiedItemAction {
  final VoidCallback? onPressed;

  DeleteAction({this.onPressed});

  @override
  Widget build() {
    return IconButton(
      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
      onPressed: onPressed,
      tooltip: 'Delete',
    );
  }
}

class EditAction implements UnifiedItemAction {
  final VoidCallback? onPressed;

  EditAction({this.onPressed});

  @override
  Widget build() {
    return IconButton(
      icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
      onPressed: onPressed,
      tooltip: 'Edit',
    );
  }
}
