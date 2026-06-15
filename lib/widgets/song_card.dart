import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/song.dart';
import '../theme/mono_pulse_theme.dart';
import 'app_icon_button.dart';

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

  /// Callback when the metronome action is pressed.
  final VoidCallback? onOpenMetronome;

  /// Whether to show the Spotify play button.
  final bool showSpotifyButton;

  const SongCard({
    super.key,
    required this.song,
    this.showSpotifyButton = true,
    this.onEdit,
    this.onDelete,
    this.onPlaySpotify,
    this.onOpenMetronome,
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
              color: MonoPulseColors.beatModeAccent,
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
        if (onOpenMetronome != null && _hasMetronomeData)
          AppIconButton(
            key: const ValueKey('song-card-open-metronome'),
            icon: Icons.speed,
            label: 'Open in Metronome',
            onPressed: onOpenMetronome,
            color: MonoPulseColors.accentOrange,
          ),
        if (song.ourBPM != null) _buildBpmBadge(),
        if (song.ourKey != null) ...[
          const SizedBox(width: 8),
          Text(
            song.ourKey!,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
        const SizedBox(width: 8),
        AppIconButton(
          icon: Icons.edit,
          label: 'Edit song',
          onPressed: onEdit,
          size: 20,
        ),
      ],
    );
  }

  bool get _hasMetronomeData {
    return song.ourBPM != null ||
        song.originalBPM != null ||
        song.accentBeats != 4 ||
        song.regularBeats != 1 ||
        song.beatModes.isNotEmpty;
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
          fontWeight: FontWeight.w700,
          color: MonoPulseColors.accentOrange,
        ),
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

  /// Callback when the metronome action is pressed.
  final VoidCallback? onOpenMetronome;

  const CompactSongCard({
    super.key,
    required this.song,
    this.onTap,
    this.onOpenMetronome,
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
            if (song.ourKey != null)
              Text(
                song.ourKey!,
                style: MonoPulseTypography.bodySmall.copyWith(
                  color: MonoPulseColors.accentOrange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (song.ourBPM != null) ...[
              const SizedBox(width: MonoPulseSpacing.sm),
              Text(
                '${song.ourBPM} BPM',
                style: MonoPulseTypography.bodySmall.copyWith(
                  color: MonoPulseColors.accentOrange,
                ),
              ),
            ],
            if (onOpenMetronome != null && _hasMetronomeData) ...[
              const SizedBox(width: MonoPulseSpacing.sm),
              AppIconButton(
                key: const ValueKey('compact-song-card-open-metronome'),
                icon: Icons.speed,
                label: 'Open in Metronome',
                onPressed: onOpenMetronome,
                color: MonoPulseColors.accentOrange,
                size: 20,
              ),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  bool get _hasMetronomeData {
    return song.ourBPM != null ||
        song.originalBPM != null ||
        song.accentBeats != 4 ||
        song.regularBeats != 1 ||
        song.beatModes.isNotEmpty;
  }
}
