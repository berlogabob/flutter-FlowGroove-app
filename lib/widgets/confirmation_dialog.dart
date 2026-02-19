import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A confirmation dialog widget.
///
/// This widget provides a consistent confirmation dialog for destructive
/// actions like deletions or irreversible operations.
class ConfirmationDialog extends StatelessWidget {
  /// The title of the dialog.
  final String title;

  /// The message explaining what will be confirmed.
  final String message;

  /// The label for the confirm button.
  final String confirmLabel;

  /// The label for the cancel button.
  final String cancelLabel;

  /// The icon to display in the dialog.
  final IconData? icon;

  /// Whether the action is destructive (e.g., delete).
  final bool isDestructive;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.icon,
    this.isDestructive = true,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(
        icon ?? (isDestructive ? Icons.warning_amber : Icons.info_outline),
        color: isDestructive ? Colors.red : AppColors.color1,
        size: 48,
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDestructive ? Colors.red : AppColors.color1,
            foregroundColor: Colors.white,
          ),
          child: Text(confirmLabel),
        ),
      ],
    );
  }

  /// Show a delete confirmation dialog.
  static Future<bool> showDeleteDialog(
    BuildContext context, {
    String title = 'Delete Item',
    String message = 'Are you sure you want to delete this item?',
    String confirmLabel = 'Delete',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        isDestructive: true,
      ),
    ).then((value) => value ?? false);
  }

  /// Show a generic confirmation dialog.
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        isDestructive: false,
        icon: icon,
      ),
    ).then((value) => value ?? false);
  }
}
