import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/song.dart';
import '../../theme/app_theme.dart';

/// A card widget for displaying song information.
///
/// This widget provides a consistent card layout for displaying song
/// details including title, artist, BPM, key, and action buttons.
class SongCard extends StatelessWidget {
  /// The song to display.
  final Song song;

  /// Callback when the edit button is pressed.
  final VoidCallback? onEdit;

  /// Callback when the delete button is pressed.
  final VoidCallback? onDelete;

  /// Callback when the Spotify play button is pressed.
  final VoidCallback? onPlaySpotify;

  /// Whether to show the Spotify play button.
  final bool showSpotifyButton;

  const SongCard({
    super.key,
    required this.song,
    this.onEdit,
    this.onDelete,
    this.onPlaySpotify,
    this.showSpotifyButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.color1,
          child: Icon(Icons.music_note, color: Colors.white),
        ),
        title: Text(song.title),
        subtitle: Text(song.artist),
        trailing: _buildTrailingActions(context),
        onTap: onEdit,
      ),
    );
  }

  Widget _buildTrailingActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSpotifyButton && song.spotifyUrl != null)
          IconButton(
            icon: const Icon(
              Icons.play_circle_fill,
              color: Colors.green,
              size: 28,
            ),
            onPressed: () async {
              if (onPlaySpotify != null) {
                onPlaySpotify!();
              } else {
                final uri = Uri.parse(song.spotifyUrl!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            },
            tooltip: 'Play on Spotify',
          ),
        if (song.ourBPM != null) _buildBpmBadge(),
        if (song.ourKey != null) ...[
          const SizedBox(width: 8),
          Text(
            song.ourKey!,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.edit, size: 20),
          onPressed: onEdit,
          tooltip: 'Edit',
        ),
      ],
    );
  }

  Widget _buildBpmBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.color5.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${song.ourBPM}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// A compact song card for list views.
class CompactSongCard extends StatelessWidget {
  /// The song to display.
  final Song song;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  const CompactSongCard({super.key, required this.song, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.color1.withValues(alpha: 0.3),
          child: const Icon(Icons.music_note, size: 20),
        ),
        title: Text(
          song.title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(song.artist),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (song.ourKey != null)
              Text(
                song.ourKey!,
                style: const TextStyle(
                  color: AppColors.color5,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            if (song.ourBPM != null) ...[
              const SizedBox(width: 8),
              Text(
                '${song.ourBPM} BPM',
                style: const TextStyle(color: AppColors.color5, fontSize: 12),
              ),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
