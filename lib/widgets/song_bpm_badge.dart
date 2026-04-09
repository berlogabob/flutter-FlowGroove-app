import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/mono_pulse_theme.dart';
import '../providers/data/song_bpm_provider.dart';

/// Widget to display song BPM with quick metronome start.
///
/// When [spotifyId] is provided, fetches BPM from Spotify automatically.
/// Falls back to manual [bpm] if no Spotify ID or API unavailable.
class SongBPMBadge extends ConsumerWidget {
  final int? bpm;
  final VoidCallback? onTap;
  final bool showLabel;
  final String? spotifyId;

  const SongBPMBadge({
    super.key,
    this.bpm,
    this.onTap,
    this.showLabel = true,
    this.spotifyId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If Spotify ID provided, try to fetch BPM
    if (spotifyId != null && spotifyId!.isNotEmpty) {
      final provider = bpmProviderFor(spotifyId!);
      final result = ref.watch(provider);

      return _buildBadge(
        context,
        result.bpm ?? bpm,
        isLoading: result.source == BpmSource.loading,
        isError: result.source == BpmSource.error,
        isNotAvailable: result.source == BpmSource.notAvailable && bpm == null,
      );
    }

    // No Spotify ID — show manual BPM if available
    if (bpm == null) {
      return const SizedBox.shrink();
    }

    return _buildBadge(context, bpm);
  }

  Widget _buildBadge(
    BuildContext context,
    int? bpm, {
    bool isLoading = false,
    bool isError = false,
    bool isNotAvailable = false,
  }) {
    final displayText = isLoading
        ? '...'
        : isNotAvailable
              ? '—'
              : isError
                    ? '!'
                    : '$bpm BPM';

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isError
              ? MonoPulseColors.error.withValues(alpha: 0.1)
              : MonoPulseColors.accentOrangeSubtle,
          borderRadius: BorderRadius.circular(MonoPulseRadius.huge),
          border: Border.all(
            color: isError
                ? MonoPulseColors.error
                : MonoPulseColors.accentOrange,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLoading ? Icons.hourglass_empty : Icons.speed,
              size: 16,
              color: isError
                  ? MonoPulseColors.error
                  : MonoPulseColors.accentOrange,
            ),
            const SizedBox(width: 4),
            Text(
              displayText,
              style: MonoPulseTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: isError
                    ? MonoPulseColors.error
                    : MonoPulseColors.accentOrange,
              ),
            ),
            if (onTap != null && !isLoading) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.play_circle_outline,
                size: 16,
                color: MonoPulseColors.accentOrange,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
