import 'package:flutter/material.dart';
import '../../../models/beat_mode.dart';
import '../../../theme/mono_pulse_theme.dart';

/// A visual grid editor for metronome beat accent patterns.
///
/// This widget displays a grid of buttons (accentBeats × regularBeats)
/// where each button cycles through BeatMode values:
/// - normal: grey circle
/// - accent: orange circle with icon
/// - silent: transparent/dashed circle
class MetronomePatternEditor extends StatelessWidget {
  /// Number of beats per measure (1-16, default 4).
  final int accentBeats;

  /// Number of subdivisions per beat (1-8, default 1).
  final int regularBeats;

  /// 2D list of beat modes (beats × subdivisions).
  final List<List<BeatMode>> beatModes;

  /// Callback when a beat mode is changed.
  final Function(int beatIndex, int subdivisionIndex, BeatMode mode)
  onBeatModeChanged;

  /// Callback when accentBeats changes.
  final ValueChanged<int>? onAccentBeatsChanged;

  /// Callback when regularBeats changes.
  final ValueChanged<int>? onRegularBeatsChanged;

  const MetronomePatternEditor({
    super.key,
    required this.accentBeats,
    required this.regularBeats,
    required this.beatModes,
    required this.onBeatModeChanged,
    this.onAccentBeatsChanged,
    this.onRegularBeatsChanged,
  });

  /// Get the BeatMode for a specific position, defaulting to normal if not set.
  BeatMode _getBeatMode(int beatIndex, int subdivisionIndex) {
    if (beatIndex >= beatModes.length) return BeatMode.normal;
    if (subdivisionIndex >= beatModes[beatIndex].length) return BeatMode.normal;
    return beatModes[beatIndex][subdivisionIndex];
  }

  /// Cycle to the next BeatMode.
  BeatMode _cycleBeatMode(BeatMode current) {
    switch (current) {
      case BeatMode.normal:
        return BeatMode.accent;
      case BeatMode.accent:
        return BeatMode.silent;
      case BeatMode.silent:
        return BeatMode.normal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Settings row with accentBeats and regularBeats controls
          Row(
            children: [
              // Accent Beats selector
              Expanded(
                child: _buildNumberSelector(
                  label: 'Beats per Measure',
                  value: accentBeats,
                  min: 1,
                  max: 16,
                  onChanged: onAccentBeatsChanged,
                ),
              ),
              const SizedBox(width: MonoPulseSpacing.lg),
              // Regular Beats (subdivisions) selector
              Expanded(
                child: _buildNumberSelector(
                  label: 'Subdivisions per Beat',
                  value: regularBeats,
                  min: 1,
                  max: 8,
                  onChanged: onRegularBeatsChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: MonoPulseSpacing.lg),
          // Visual grid editor
          _buildBeatGrid(),
          // Legend
          const SizedBox(height: MonoPulseSpacing.md),
          _buildLegend(),
        ],
      ),
    );
  }

  /// Build a number selector with +/- buttons.
  Widget _buildNumberSelector({
    required String label,
    required int value,
    required int min,
    required int max,
    ValueChanged<int>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: MonoPulseTypography.labelMedium.copyWith(
            color: MonoPulseColors.textSecondary,
          ),
        ),
        const SizedBox(height: MonoPulseSpacing.xs),
        Row(
          children: [
            // Decrease button
            _buildCircleButton(
              icon: Icons.remove,
              onPressed: value > min ? () => onChanged?.call(value - 1) : null,
            ),
            const SizedBox(width: MonoPulseSpacing.md),
            // Value display
            Expanded(
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: MonoPulseColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
                  border: Border.all(color: MonoPulseColors.borderDefault),
                ),
                child: Text(
                  value.toString(),
                  style: MonoPulseTypography.headlineMedium.copyWith(
                    color: MonoPulseColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: MonoPulseSpacing.md),
            // Increase button
            _buildCircleButton(
              icon: Icons.add,
              onPressed: value < max ? () => onChanged?.call(value + 1) : null,
            ),
          ],
        ),
      ],
    );
  }

  /// Build a circular button for increment/decrement.
  Widget _buildCircleButton({required IconData icon, VoidCallback? onPressed}) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: onPressed == null
            ? MonoPulseColors.surfaceRaised
            : MonoPulseColors.accentOrange,
        borderRadius: BorderRadius.circular(MonoPulseRadius.xlarge),
        child: InkWell(
          borderRadius: BorderRadius.circular(MonoPulseRadius.xlarge),
          onTap: onPressed,
          child: Icon(
            icon,
            color: onPressed == null
                ? MonoPulseColors.textDisabled
                : MonoPulseColors.black,
            size: 24,
          ),
        ),
      ),
    );
  }

  /// Build the visual beat grid.
  Widget _buildBeatGrid() {
    return Container(
      padding: const EdgeInsets.all(MonoPulseSpacing.lg),
      decoration: BoxDecoration(
        color: MonoPulseColors.surfaceRaised,
        borderRadius: BorderRadius.circular(MonoPulseRadius.large),
        border: Border.all(color: MonoPulseColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Beat Pattern',
            style: MonoPulseTypography.labelMedium.copyWith(
              color: MonoPulseColors.textSecondary,
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.md),
          // Grid header row (subdivision labels)
          if (regularBeats > 1) _buildSubdivisionHeader(),
          // Beat rows
          ...List.generate(
            accentBeats,
            (beatIndex) => _buildBeatRow(beatIndex),
          ),
        ],
      ),
    );
  }

  /// Build the subdivision header row.
  Widget _buildSubdivisionHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: MonoPulseSpacing.xs),
      child: Row(
        children: [
          // Empty corner cell for beat labels
          SizedBox(
            width: 48,
            child: Text(
              'Beat',
              style: MonoPulseTypography.labelSmall.copyWith(
                color: MonoPulseColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: MonoPulseSpacing.sm),
          // Subdivision labels
          Expanded(
            child: Row(
              children: List.generate(
                regularBeats,
                (subIndex) => Expanded(
                  child: Center(
                    child: Text(
                      '${subIndex + 1}',
                      style: MonoPulseTypography.labelSmall.copyWith(
                        color: MonoPulseColors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a single beat row.
  Widget _buildBeatRow(int beatIndex) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MonoPulseSpacing.xs),
      child: Row(
        children: [
          // Beat number label
          SizedBox(
            width: 48,
            child: Text(
              '${beatIndex + 1}',
              style: MonoPulseTypography.labelMedium.copyWith(
                color: MonoPulseColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: MonoPulseSpacing.sm),
          // Beat mode buttons
          Expanded(
            child: Row(
              children: List.generate(
                regularBeats,
                (subIndex) =>
                    Expanded(child: _buildBeatModeButton(beatIndex, subIndex)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build an individual beat mode button.
  Widget _buildBeatModeButton(int beatIndex, int subdivisionIndex) {
    final mode = _getBeatMode(beatIndex, subdivisionIndex);
    final color = _getModeColor(mode);
    final icon = _getModeIcon(mode);
    final hasBorder = mode != BeatMode.silent;

    return AspectRatio(
      aspectRatio: 1,
      child: GestureDetector(
        onTap: () => onBeatModeChanged(
          beatIndex,
          subdivisionIndex,
          _cycleBeatMode(mode),
        ),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: mode == BeatMode.silent
                ? Colors.transparent
                : color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: hasBorder
                ? Border.all(color: color, width: 2)
                : Border.all(
                    color: MonoPulseColors.borderDefault,
                    width: 1,
                    style: BorderStyle.solid,
                  ),
          ),
          child: Center(
            child: icon != null
                ? Icon(
                    icon,
                    color: mode == BeatMode.silent
                        ? MonoPulseColors.textTertiary
                        : color,
                    size: 20,
                  )
                : Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// Get the color for a BeatMode.
  Color _getModeColor(BeatMode mode) {
    switch (mode) {
      case BeatMode.normal:
        return MonoPulseColors.beatModeNormal;
      case BeatMode.accent:
        return MonoPulseColors.beatModeAccent;
      case BeatMode.silent:
        return MonoPulseColors.beatModeSilent;
    }
  }

  /// Get the icon for a BeatMode (null for normal).
  IconData? _getModeIcon(BeatMode mode) {
    switch (mode) {
      case BeatMode.normal:
        return null; // Just a circle
      case BeatMode.accent:
        return Icons.star; // Accent indicator
      case BeatMode.silent:
        return Icons.volume_off; // Silent indicator
    }
  }

  /// Build the legend explaining the beat modes.
  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(
          color: MonoPulseColors.beatModeNormal,
          label: 'Normal',
          icon: null,
        ),
        const SizedBox(width: MonoPulseSpacing.xl),
        _buildLegendItem(
          color: MonoPulseColors.beatModeAccent,
          label: 'Accent',
          icon: Icons.star,
        ),
        const SizedBox(width: MonoPulseSpacing.xl),
        _buildLegendItem(
          color: MonoPulseColors.beatModeSilent,
          label: 'Silent',
          icon: Icons.volume_off,
        ),
      ],
    );
  }

  /// Build a single legend item.
  Widget _buildLegendItem({
    required Color color,
    required String label,
    IconData? icon,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: icon != null
              ? Icon(icon, color: color, size: 10)
              : Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
        ),
        const SizedBox(width: MonoPulseSpacing.xs),
        Text(
          label,
          style: MonoPulseTypography.labelSmall.copyWith(
            color: MonoPulseColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
