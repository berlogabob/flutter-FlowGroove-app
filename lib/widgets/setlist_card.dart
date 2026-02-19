import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A card widget for displaying setlist information.
///
/// This widget provides a consistent card layout for displaying setlist
/// details including name, song count, and associated band.
class SetlistCard extends StatelessWidget {
  /// The setlist ID.
  final String id;

  /// The setlist name.
  final String name;

  /// The number of songs in the setlist.
  final int songCount;

  /// The band name associated with this setlist.
  final String? bandName;

  /// The date of the setlist (e.g., gig date) as a string.
  final String? date;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  /// Callback when the edit button is pressed.
  final VoidCallback? onEdit;

  /// Callback when the delete button is pressed.
  final VoidCallback? onDelete;

  const SetlistCard({
    super.key,
    required this.id,
    required this.name,
    required this.songCount,
    this.bandName,
    this.date,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.color1,
          child: Icon(Icons.playlist_play, color: Colors.white),
        ),
        title: Text(name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$songCount ${songCount == 1 ? 'song' : 'songs'}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            if (bandName != null && bandName!.isNotEmpty)
              Text(
                bandName!,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            if (date != null)
              Text(
                _formatDate(date) ?? '',
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

  String? _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}

/// A compact setlist card for list views.
class CompactSetlistCard extends StatelessWidget {
  /// The setlist ID.
  final String id;

  /// The setlist name.
  final String name;

  /// The number of songs in the setlist.
  final int songCount;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  const CompactSetlistCard({
    super.key,
    required this.id,
    required this.name,
    required this.songCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.color1.withValues(alpha: 0.3),
          child: const Icon(Icons.playlist_play, size: 20),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text('$songCount songs'),
        onTap: onTap,
      ),
    );
  }
}
