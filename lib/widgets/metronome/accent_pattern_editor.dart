/// Accent pattern editor widget
///
/// Visual grid editor for beat modes.
/// Features:
/// - 2D grid (beats × subdivisions)
/// - Tap to cycle modes (normal → accent → silent)
/// - Visual feedback for each mode
/// - Grid expands with time signature
/// - 48x48px touch zones
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/mono_pulse_theme.dart';
import '../../models/beat_mode.dart';
import '../../providers/data/metronome_provider.dart';

/// Accent pattern editor with 2D grid
class AccentPatternEditor extends ConsumerWidget {
  const AccentPatternEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(metronomeProvider);
    final notifier = ref.read(metronomeProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Beat Pattern',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: () => _showHelpDialog(context),
              child: const Text('Help'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Grid header
        _GridHeader(
          accentBeats: state.accentBeats,
          regularBeats: state.regularBeats,
        ),
        const SizedBox(height: 8),
        // Beat mode grid
        _BeatModeGrid(
          beatModes: state.beatModes,
          accentBeats: state.accentBeats,
          regularBeats: state.regularBeats,
          onModeChanged: (beatIndex, subIndex, mode) {
            notifier.setBeatMode(beatIndex, subIndex, mode);
            HapticFeedback.lightImpact();
          },
        ),
        const SizedBox(height: 16),
        // Legend
        _Legend(),
      ],
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Beat Pattern Editor'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LegendItem(
              mode: BeatMode.normal,
              description: 'Normal: Standard click',
            ),
            SizedBox(height: 8),
            _LegendItem(
              mode: BeatMode.accent,
              description: 'Accent: Louder, higher pitch',
            ),
            SizedBox(height: 8),
            _LegendItem(
              mode: BeatMode.silent,
              description: 'Silent: Visual only, no sound',
            ),
            SizedBox(height: 16),
            Text(
              'Tap any cell to cycle through modes.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

/// Grid header showing beat and subdivision counts
class _GridHeader extends StatelessWidget {
  const _GridHeader({
    required this.accentBeats,
    required this.regularBeats,
  });

  final int accentBeats;
  final int regularBeats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Beats: $accentBeats',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            'Subdivisions: $regularBeats',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.secondary,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

/// Beat mode grid widget
class _BeatModeGrid extends StatelessWidget {
  const _BeatModeGrid({
    required this.beatModes,
    required this.accentBeats,
    required this.regularBeats,
    required this.onModeChanged,
  });

  final List<List<BeatMode>> beatModes;
  final int accentBeats;
  final int regularBeats;
  final Function(int, int, BeatMode) onModeChanged;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: regularBeats,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: beatModes.length * (beatModes.isNotEmpty ? beatModes[0].length : 0),
      itemBuilder: (context, index) {
        final beatIndex = index ~/ regularBeats;
        final subIndex = index % regularBeats;

        if (beatIndex >= beatModes.length ||
            subIndex >= beatModes[beatIndex].length) {
          return const SizedBox.shrink();
        }

        final mode = beatModes[beatIndex][subIndex];

        return _BeatModeCell(
          mode: mode,
          beatIndex: beatIndex,
          subIndex: subIndex,
          onTap: () => onModeChanged(beatIndex, subIndex, mode.next()),
        );
      },
    );
  }
}

/// Individual beat mode cell
class _BeatModeCell extends StatelessWidget {
  const _BeatModeCell({
    required this.mode,
    required this.beatIndex,
    required this.subIndex,
    required this.onTap,
  });

  final BeatMode mode;
  final int beatIndex;
  final int subIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _getModeColor(context);
    final icon = _getModeIcon();
    final label = _getModeLabel();

    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(MonoPulseRadius.small),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${beatIndex + 1}.${subIndex + 1}',
              style: TextStyle(
                fontSize: 8,
                color: color.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getModeColor(BuildContext context) {
    switch (mode) {
      case BeatMode.normal:
        return MonoPulseColors.textTertiary;
      case BeatMode.accent:
        return Theme.of(context).colorScheme.primary;
      case BeatMode.silent:
        return MonoPulseColors.textTertiary.withValues(alpha: 0.3);
    }
  }

  IconData _getModeIcon() {
    switch (mode) {
      case BeatMode.normal:
        return Icons.circle_outlined;
      case BeatMode.accent:
        return Icons.star;
      case BeatMode.silent:
        return Icons.volume_off;
    }
  }

  String _getModeLabel() {
    switch (mode) {
      case BeatMode.normal:
        return 'Normal';
      case BeatMode.accent:
        return 'Accent';
      case BeatMode.silent:
        return 'Silent';
    }
  }
}

/// Legend showing mode meanings
class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _LegendItem(
          mode: BeatMode.normal,
          description: 'Normal',
        ),
        _LegendItem(
          mode: BeatMode.accent,
          description: 'Accent',
        ),
        _LegendItem(
          mode: BeatMode.silent,
          description: 'Silent',
        ),
      ],
    );
  }
}

/// Individual legend item
class _LegendItem extends StatelessWidget {

  const _LegendItem({
    required this.mode,
    required this.description,
  });
  final BeatMode mode;
  final String description;

  @override
  Widget build(BuildContext context) {
    final color = _getModeColor(context);
    final icon = _getModeIcon();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          description,
          style: TextStyle(
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _getModeColor(BuildContext context) {
    switch (mode) {
      case BeatMode.normal:
        return MonoPulseColors.textTertiary;
      case BeatMode.accent:
        return Theme.of(context).colorScheme.primary;
      case BeatMode.silent:
        return MonoPulseColors.textTertiary.withValues(alpha: 0.3);
    }
  }

  IconData _getModeIcon() {
    switch (mode) {
      case BeatMode.normal:
        return Icons.circle_outlined;
      case BeatMode.accent:
        return Icons.star;
      case BeatMode.silent:
        return Icons.volume_off;
    }
  }
}
