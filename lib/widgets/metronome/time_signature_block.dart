import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data/metronome_provider.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../models/metronome_state.dart';

/// Time Signature Block widget - Beat Modes with proper tap handling
class TimeSignatureBlock extends ConsumerStatefulWidget {
  const TimeSignatureBlock({super.key});

  @override
  ConsumerState<TimeSignatureBlock> createState() => _TimeSignatureBlockState();
}

class _TimeSignatureBlockState extends ConsumerState<TimeSignatureBlock> {
  @override
  Widget build(BuildContext context) {
    final metronome = ref.watch(metronomeProvider.notifier);
    final state = ref.watch(metronomeProvider);
    final isPlaying = state.isPlaying;
    final currentBeat = state.currentBeat;
    final beats = state.accentBeats;
    final subdivisions = state.regularBeats;
    final beatModes = state.beatModes;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.xxxl),
      decoration: BoxDecoration(
        color: MonoPulseColors.blackSurface,
        borderRadius: BorderRadius.circular(MonoPulseRadius.xlarge),
        border: Border.all(color: MonoPulseColors.borderSubtle),
      ),
      padding: const EdgeInsets.all(MonoPulseSpacing.lg),
      child: Column(
        children: [
          // Top row - Beats
          _BeatsRow(
            count: beats,
            currentBeat: isPlaying ? currentBeat : -1,
            subdivisions: subdivisions,
            beatModes: beatModes,
            onToggleMode: (beatIndex, subdivisionIndex, mode) {
              HapticFeedback.lightImpact();
              // Cycle to next mode: normal → accent → silent → normal
              final nextMode = _cycleMode(mode);
              debugPrint(
                'Beat $beatIndex, Subdivision $subdivisionIndex: ${mode} → $nextMode',
              );
              metronome.setBeatMode(beatIndex, subdivisionIndex, nextMode);
            },
            onIncrement: () {
              HapticFeedback.lightImpact();
              if (beats < 12) {
                metronome.setAccentBeats(beats + 1);
              }
            },
            onDecrement: () {
              HapticFeedback.lightImpact();
              if (beats > 1) {
                metronome.setAccentBeats(beats - 1);
              }
            },
          ),
          const SizedBox(height: MonoPulseSpacing.md),
          // Bottom row - Subdivisions
          _SubdivisionsRow(
            count: subdivisions,
            isPlaying: isPlaying,
            currentBeat: isPlaying ? currentBeat : -1,
            beats: beats,
            beatModes: beatModes,
            onToggleMode: (beatIndex, subdivisionIndex, mode) {
              HapticFeedback.lightImpact();
              final nextMode = _cycleMode(mode);
              debugPrint(
                'Beat $beatIndex, Subdivision $subdivisionIndex: ${mode} → $nextMode',
              );
              metronome.setBeatMode(beatIndex, subdivisionIndex, nextMode);
            },
            onIncrement: () {
              HapticFeedback.lightImpact();
              if (subdivisions < 12) {
                metronome.setRegularBeats(subdivisions + 1);
              }
            },
            onDecrement: () {
              HapticFeedback.lightImpact();
              if (subdivisions > 1) {
                metronome.setRegularBeats(subdivisions - 1);
              }
            },
          ),
        ],
      ),
    );
  }

  /// Cycle through modes: normal → accent → silent → normal
  BeatMode _cycleMode(BeatMode currentMode) {
    switch (currentMode) {
      case BeatMode.normal:
        return BeatMode.accent;
      case BeatMode.accent:
        return BeatMode.silent;
      case BeatMode.silent:
        return BeatMode.normal;
    }
  }
}

// ============================================================================
// BEATS ROW (Top Row)
// ============================================================================
class _BeatsRow extends StatelessWidget {
  final int count;
  final int currentBeat;
  final int subdivisions;
  final List<List<BeatMode>> beatModes;
  final Function(int, int, BeatMode) onToggleMode;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _BeatsRow({
    required this.count,
    this.currentBeat = -1,
    required this.subdivisions,
    required this.beatModes,
    required this.onToggleMode,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final visibleCount = _calculateVisibleCount(context);
    final needsScroll = count > visibleCount;

    return Row(
      children: [
        _BeatButton(icon: Icons.remove, onTap: count > 1 ? onDecrement : null),
        const SizedBox(width: MonoPulseSpacing.md),
        Expanded(
          child: _buildScrollableCircles(
            context: context,
            count: count,
            visibleCount: visibleCount,
            needsScroll: needsScroll,
          ),
        ),
        const SizedBox(width: MonoPulseSpacing.sm),
        _BeatButton(
          icon: Icons.add,
          onTap: count < 12 ? onIncrement : null,
          showBadge: count > visibleCount,
          badgeCount: count,
        ),
      ],
    );
  }

  int _calculateVisibleCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth =
        screenWidth -
        (MonoPulseSpacing.xxxl * 2) -
        (MonoPulseSpacing.lg * 2) -
        (48 * 2) -
        MonoPulseSpacing.md -
        MonoPulseSpacing.sm;
    final circleWidth = 20.0 + MonoPulseSpacing.sm;
    final maxVisible = (availableWidth / circleWidth).floor();
    return maxVisible.clamp(4, 6);
  }

  Widget _buildScrollableCircles({
    required BuildContext context,
    required int count,
    required int visibleCount,
    required bool needsScroll,
  }) {
    return ClipRect(
      clipBehavior: Clip.hardEdge,
      child: Theme(
        data: Theme.of(context).copyWith(
          scrollbarTheme: ScrollbarThemeData(
            thumbColor: WidgetStateProperty.all(MonoPulseColors.borderDefault),
            thickness: WidgetStateProperty.all(2),
            radius: const Radius.circular(2),
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: needsScroll ? null : const NeverScrollableScrollPhysics(),
          child: Row(
            children: List.generate(count, (beatIndex) {
              // Get mode for first subdivision of this beat (for display)
              final mode =
                  beatIndex < beatModes.length &&
                      beatModes[beatIndex].isNotEmpty
                  ? beatModes[beatIndex][0]
                  : BeatMode.normal;

              // Check if this beat is active
              final isBeatActive =
                  currentBeat >= 0 &&
                  (currentBeat ~/ subdivisions) == beatIndex;

              return Padding(
                padding: EdgeInsets.only(
                  right: beatIndex < count - 1 ? MonoPulseSpacing.sm : 0,
                ),
                child: _BeatCircleWithMode(
                  isMainBeat: true,
                  isActive: isBeatActive,
                  mode: mode,
                  onTap: () => onToggleMode(beatIndex, 0, mode),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SUBDIVISIONS ROW (Bottom Row)
// ============================================================================
class _SubdivisionsRow extends StatelessWidget {
  final int count;
  final bool isPlaying;
  final int currentBeat;
  final int beats;
  final List<List<BeatMode>> beatModes;
  final Function(int, int, BeatMode) onToggleMode;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _SubdivisionsRow({
    required this.count,
    required this.isPlaying,
    required this.currentBeat,
    required this.beats,
    required this.beatModes,
    required this.onToggleMode,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final visibleCount = _calculateVisibleCount(context);
    final needsScroll = count > visibleCount;

    return Row(
      children: [
        _BeatButton(icon: Icons.remove, onTap: count > 1 ? onDecrement : null),
        const SizedBox(width: MonoPulseSpacing.md),
        Expanded(
          child: _buildScrollableCircles(
            context: context,
            count: count,
            visibleCount: visibleCount,
            needsScroll: needsScroll,
          ),
        ),
        const SizedBox(width: MonoPulseSpacing.sm),
        _BeatButton(
          icon: Icons.add,
          onTap: count < 12 ? onIncrement : null,
          showBadge: count > visibleCount,
          badgeCount: count,
        ),
      ],
    );
  }

  int _calculateVisibleCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth =
        screenWidth -
        (MonoPulseSpacing.xxxl * 2) -
        (MonoPulseSpacing.lg * 2) -
        (48 * 2) -
        MonoPulseSpacing.md -
        MonoPulseSpacing.sm;
    final circleWidth = 20.0 + MonoPulseSpacing.sm;
    final maxVisible = (availableWidth / circleWidth).floor();
    return maxVisible.clamp(4, 6);
  }

  Widget _buildScrollableCircles({
    required BuildContext context,
    required int count,
    required int visibleCount,
    required bool needsScroll,
  }) {
    return ClipRect(
      clipBehavior: Clip.hardEdge,
      child: Theme(
        data: Theme.of(context).copyWith(
          scrollbarTheme: ScrollbarThemeData(
            thumbColor: WidgetStateProperty.all(MonoPulseColors.borderDefault),
            thickness: WidgetStateProperty.all(2),
            radius: const Radius.circular(2),
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: needsScroll ? null : const NeverScrollableScrollPhysics(),
          child: Row(
            children: List.generate(count, (subdivisionIndex) {
              // Get current beat index
              final currentBeatIndex = isPlaying ? currentBeat ~/ count : -1;

              // Get mode for this subdivision of current beat
              final mode =
                  currentBeatIndex >= 0 &&
                      currentBeatIndex < beatModes.length &&
                      subdivisionIndex < beatModes[currentBeatIndex].length
                  ? beatModes[currentBeatIndex][subdivisionIndex]
                  : BeatMode.normal;

              // Check if this subdivision is active
              final isSubdivisionActive =
                  isPlaying &&
                  currentBeat >= 0 &&
                  (currentBeat % count) == subdivisionIndex;

              return Padding(
                padding: EdgeInsets.only(
                  right: subdivisionIndex < count - 1 ? MonoPulseSpacing.sm : 0,
                ),
                child: _SubdivisionCircleWithMode(
                  subdivisionIndex: subdivisionIndex,
                  isActive: isSubdivisionActive,
                  mode: mode,
                  onTap: currentBeatIndex >= 0
                      ? () => onToggleMode(
                          currentBeatIndex,
                          subdivisionIndex,
                          mode,
                        )
                      : null,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// BEAT CIRCLE WITH MODE (TAPPABLE)
// ============================================================================
class _BeatCircleWithMode extends StatelessWidget {
  final bool isMainBeat;
  final bool isActive;
  final BeatMode mode;
  final VoidCallback onTap;

  const _BeatCircleWithMode({
    required this.isMainBeat,
    required this.isActive,
    required this.mode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: AnimatedContainer(
            duration: MonoPulseAnimation.durationShort,
            curve: MonoPulseAnimation.curveCustom,
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getColorForMode(),
              border: Border.all(color: _getBorderColorForMode(), width: 1.5),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: _getColorForMode().withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: Transform.scale(
              scale: isActive ? 1.08 : 1.0,
              child: _buildModeIndicator(),
            ),
          ),
        ),
      ),
    );
  }

  Color _getColorForMode() {
    switch (mode) {
      case BeatMode.normal:
        return isActive
            ? MonoPulseColors.beatModeNormalBright
            : MonoPulseColors.beatModeNormal;
      case BeatMode.accent:
        return isActive
            ? MonoPulseColors.beatModeAccentBright
            : MonoPulseColors.beatModeAccent;
      case BeatMode.silent:
        return isActive
            ? MonoPulseColors.beatModeSilentBright
            : MonoPulseColors.beatModeSilent;
    }
  }

  Color _getBorderColorForMode() {
    switch (mode) {
      case BeatMode.normal:
        return isActive
            ? MonoPulseColors.beatModeNormalBright
            : MonoPulseColors.beatModeNormal.withValues(alpha: 0.7);
      case BeatMode.accent:
        return isActive
            ? MonoPulseColors.beatModeAccentBright
            : MonoPulseColors.beatModeAccent.withValues(alpha: 0.7);
      case BeatMode.silent:
        return isActive
            ? MonoPulseColors.beatModeSilentBright
            : MonoPulseColors.beatModeSilent.withValues(alpha: 0.7);
    }
  }

  Widget _buildModeIndicator() {
    if (mode == BeatMode.normal) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Container(
        width: mode == BeatMode.accent ? 8 : 6,
        height: mode == BeatMode.accent ? 8 : 6,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ============================================================================
// SUBDIVISION CIRCLE WITH MODE (TAPPABLE)
// ============================================================================
class _SubdivisionCircleWithMode extends StatelessWidget {
  final int subdivisionIndex;
  final bool isActive;
  final BeatMode mode;
  final VoidCallback? onTap;

  const _SubdivisionCircleWithMode({
    required this.subdivisionIndex,
    required this.isActive,
    required this.mode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: AnimatedContainer(
            duration: MonoPulseAnimation.durationShort,
            curve: MonoPulseAnimation.curveCustom,
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getColorForMode(),
              border: Border.all(color: _getBorderColorForMode(), width: 1.5),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: _getColorForMode().withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: Transform.scale(
              scale: isActive ? 1.08 : 1.0,
              child: _buildModeIndicator(),
            ),
          ),
        ),
      ),
    );
  }

  Color _getColorForMode() {
    switch (mode) {
      case BeatMode.normal:
        return isActive
            ? MonoPulseColors.beatModeNormalBright
            : MonoPulseColors.beatModeNormal;
      case BeatMode.accent:
        return isActive
            ? MonoPulseColors.beatModeAccentBright
            : MonoPulseColors.beatModeAccent;
      case BeatMode.silent:
        return isActive
            ? MonoPulseColors.beatModeSilentBright
            : MonoPulseColors.beatModeSilent;
    }
  }

  Color _getBorderColorForMode() {
    switch (mode) {
      case BeatMode.normal:
        return isActive
            ? MonoPulseColors.beatModeNormalBright
            : MonoPulseColors.beatModeNormal.withValues(alpha: 0.7);
      case BeatMode.accent:
        return isActive
            ? MonoPulseColors.beatModeAccentBright
            : MonoPulseColors.beatModeAccent.withValues(alpha: 0.7);
      case BeatMode.silent:
        return isActive
            ? MonoPulseColors.beatModeSilentBright
            : MonoPulseColors.beatModeSilent.withValues(alpha: 0.7);
    }
  }

  Widget _buildModeIndicator() {
    if (mode == BeatMode.normal) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Container(
        width: mode == BeatMode.accent ? 8 : 6,
        height: mode == BeatMode.accent ? 8 : 6,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ============================================================================
// BEAT BUTTON (Plus/Minus)
// ============================================================================
class _BeatButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool showBadge;
  final int badgeCount;

  const _BeatButton({
    required this.icon,
    this.onTap,
    this.showBadge = false,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: AnimatedContainer(
            duration: MonoPulseAnimation.durationShort,
            curve: MonoPulseAnimation.curveCustom,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: onTap != null
                  ? MonoPulseColors.blackElevated
                  : MonoPulseColors.borderSubtle,
              border: Border.all(
                color: onTap != null
                    ? MonoPulseColors.borderDefault
                    : MonoPulseColors.borderSubtle,
                width: 1.5,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    icon,
                    size: 20,
                    color: onTap != null
                        ? MonoPulseColors.textSecondary
                        : MonoPulseColors.textTertiary,
                  ),
                ),
                if (showBadge)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: MonoPulseColors.accentOrange,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: MonoPulseColors.black,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$badgeCount',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: MonoPulseColors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
