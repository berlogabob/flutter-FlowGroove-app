import 'package:flutter/material.dart';
import '../theme/mono_pulse_theme.dart';

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

  /// Callback when the export PDF button is pressed.
  final VoidCallback? onExportPdf;

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
    this.onExportPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: MonoPulseSpacing.lg,
        vertical: MonoPulseSpacing.sm,
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: MonoPulseColors.surfaceRaised,
          child: Icon(Icons.playlist_play, color: MonoPulseColors.accentOrange),
        ),
        title: Text(
          name,
          style: const TextStyle(color: MonoPulseColors.textPrimary),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$songCount ${songCount == 1 ? 'song' : 'songs'}',
              style: const TextStyle(
                color: MonoPulseColors.textTertiary,
                fontSize: 12,
              ),
            ),
            if (bandName != null && bandName!.isNotEmpty)
              Text(
                bandName!,
                style: const TextStyle(
                  color: MonoPulseColors.textTertiary,
                  fontSize: 12,
                ),
              ),
            if (date != null)
              Text(
                _formatDate(date) ?? '',
                style: const TextStyle(
                  color: MonoPulseColors.textTertiary,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onExportPdf != null)
              IconButton(
                icon: const Icon(
                  Icons.picture_as_pdf,
                  size: 20,
                  color: MonoPulseColors.error,
                ),
                onPressed: onExportPdf,
                tooltip: 'Export PDF',
              ),
            if (onEdit != null)
              IconButton(
                icon: const Icon(
                  Icons.edit,
                  size: 20,
                  color: MonoPulseColors.textSecondary,
                ),
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(
                  Icons.delete,
                  size: 20,
                  color: MonoPulseColors.error,
                ),
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
      margin: const EdgeInsets.symmetric(
        horizontal: MonoPulseSpacing.lg,
        vertical: MonoPulseSpacing.sm,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: MonoPulseColors.surfaceRaised,
          child: const Icon(
            Icons.playlist_play,
            size: 20,
            color: MonoPulseColors.accentOrange,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: MonoPulseColors.textPrimary,
          ),
        ),
        subtitle: Text(
          '$songCount songs',
          style: const TextStyle(color: MonoPulseColors.textTertiary),
        ),
        onTap: onTap,
      ),
    );
  }
}
