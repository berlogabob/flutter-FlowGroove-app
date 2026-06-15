import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/song.dart';
import '../theme/mono_pulse_theme.dart';

/// A card widget for displaying song information.
///
/// This widget provides a consistent card layout for displaying song
/// details including title, artist, BPM, key, and action buttons.
class SongCard extends StatelessWidget {

  const SongCard({
    required this.song,
    this.onEdit,
    this.onDelete,
    this.onPlaySpotify,
    this.onOpenMetronome,
    this.showSpotifyButton = true,
    super.key,
  });
  /// The song to display.
  final Song song;

  /// Callback when the edit button is pressed.
  final VoidCallback? onEdit;

  /// Callback when the delete button is pressed.
  final VoidCallback? onDelete;

  /// Callback when the Spotify play button is pressed.
  final VoidCallback? onPlaySpotify;

  /// Callback when the metronome button is pressed.
  final VoidCallback? onOpenMetronome;

  /// Whether to show the Spotify play button.
  final bool showSpotifyButton;

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
          child: Icon(Icons.music_note, color: MonoPulseColors.accentOrange),
        ),
        title: Text(
          song.title,
          style: const TextStyle(color: MonoPulseColors.textPrimary),
        ),
        subtitle: Text(
          song.artist,
          style: const TextStyle(color: MonoPulseColors.textSecondary),
        ),
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
        if (song.ourBPM != null && onOpenMetronome != null)
          IconButton(
            key: const ValueKey('song-card-open-metronome'),
            icon: const Icon(Icons.music_note, size: 20),
            onPressed: onOpenMetronome,
            tooltip: 'Open in Metronome',
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
      padding: const EdgeInsets.symmetric(
        horizontal: MonoPulseSpacing.md,
        vertical: MonoPulseSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: MonoPulseColors.accentOrangeSubtle,
        borderRadius: BorderRadius.circular(MonoPulseRadius.small),
      ),
      child: Text(
        '${song.ourBPM}',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: MonoPulseColors.accentOrange,
        ),
      ),
    );
  }
}

/// A compact song card for list views.
class CompactSongCard extends StatelessWidget {

  const CompactSongCard({
    required this.song,
    this.onTap,
    this.onOpenMetronome,
    super.key,
  });
  /// The song to display.
  final Song song;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  /// Callback when the metronome button is pressed.
  final VoidCallback? onOpenMetronome;

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
          child: Icon(
            Icons.music_note,
            size: 20,
            color: MonoPulseColors.accentOrange,
          ),
        ),
        title: Text(
          song.title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: MonoPulseColors.textPrimary,
          ),
        ),
        subtitle: Text(
          song.artist,
          style: const TextStyle(color: MonoPulseColors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (song.ourBPM != null && onOpenMetronome != null)
              IconButton(
                key: const ValueKey('compact-song-card-open-metronome'),
                icon: const Icon(Icons.music_note, size: 18),
                onPressed: onOpenMetronome,
                tooltip: 'Open in Metronome',
              ),
            if (song.ourKey != null)
              Text(
                song.ourKey!,
                style: const TextStyle(
                  color: MonoPulseColors.accentOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            if (song.ourBPM != null) ...[
              const SizedBox(width: MonoPulseSpacing.sm),
              Text(
                '${song.ourBPM} BPM',
                style: const TextStyle(
                  color: MonoPulseColors.accentOrange,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
