import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A card widget for displaying band information.
///
/// This widget provides a consistent card layout for displaying band
/// details including name, members count, and action buttons.
class BandCard extends StatelessWidget {
  /// The band ID.
  final String id;

  /// The band name.
  final String name;

  /// The number of members in the band.
  final int memberCount;

  /// The band description or genre.
  final String? description;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  /// Callback when the edit button is pressed.
  final VoidCallback? onEdit;

  /// Callback when the delete button is pressed.
  final VoidCallback? onDelete;

  const BandCard({
    super.key,
    required this.id,
    required this.name,
    required this.memberCount,
    this.description,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.color5,
          child: const Icon(Icons.groups, color: Colors.white),
        ),
        title: Text(name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description != null && description!.isNotEmpty)
              Text(description!),
            Text(
              '$memberCount ${memberCount == 1 ? 'member' : 'members'}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

/// A compact band card for list views.
class CompactBandCard extends StatelessWidget {
  /// The band ID.
  final String id;

  /// The band name.
  final String name;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  const CompactBandCard({
    super.key,
    required this.id,
    required this.name,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.color5.withValues(alpha: 0.3),
          child: const Icon(Icons.groups, size: 20),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        onTap: onTap,
      ),
    );
  }
}
