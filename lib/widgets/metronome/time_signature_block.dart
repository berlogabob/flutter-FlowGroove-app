import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data/metronome_provider.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../models/beat_mode.dart';

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

    // Adaptive sizing based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 375;

    // Dynamic sizing for compact layout
    final horizontalMargin = isSmallScreen
        ? MonoPulseSpacing.xxl
        : MonoPulseSpacing.xxxl;
    final blockPadding = isSmallScreen
        ? MonoPulseSpacing.md
        : MonoPulseSpacing.lg;
    final rowSpacing = isSmallScreen ? 8.0 : MonoPulseSpacing.md;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
      decoration: BoxDecoration(
        color: MonoPulseColors.blackSurface,
        borderRadius: BorderRadius.circular(MonoPulseRadius.xlarge),
        border: Border.all(color: MonoPulseColors.borderSubtle),
      ),
      padding: EdgeInsets.all(blockPadding),
      child: Column(
        children: [
          // Top row - Beats
          _BeatsRow(
            count: beats,
            currentBeat: isPlaying ? currentBeat : -1,
            subdivisions: subdivisions,
            beatModes: beatModes,
            isSmallScreen: isSmallScreen,
            onToggleMode: (beatIndex, subdivisionIndex, mode) {
              HapticFeedback.lightImpact();
              // Cycle to next mode: normal → accent → silent → normal
              final nextMode = _cycleMode(mode);
              debugPrint(
                'Beat $beatIndex, Subdivision $subdivisionIndex: $mode → $nextMode',
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
          SizedBox(height: rowSpacing),
          // Bottom row - Subdivisions
          _SubdivisionsRow(
            count: subdivisions,
            isPlaying: isPlaying,
            currentBeat: isPlaying ? currentBeat : -1,
            beats: beats,
            beatModes: beatModes,
            isSmallScreen: isSmallScreen,
            onToggleMode: (beatIndex, subdivisionIndex, mode) {
              HapticFeedback.lightImpact();
              final nextMode = _cycleMode(mode);
              debugPrint(
                'Beat $beatIndex, Subdivision $subdivisionIndex: $mode → $nextMode',
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
  final bool isSmallScreen;

  const _BeatsRow({
    required this.count,
    this.currentBeat = -1,
    required this.subdivisions,
    required this.beatModes,
    required this.onToggleMode,
    required this.onIncrement,
    required this.onDecrement,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final visibleCount = _calculateVisibleCount(context);
    final needsScroll = count > visibleCount;

    // Adaptive spacing for small screens
    final buttonSpacing = isSmallScreen
        ? MonoPulseSpacing.sm
        : MonoPulseSpacing.md;
    final addBtnSpacing = isSmallScreen
        ? MonoPulseSpacing.xs
        : MonoPulseSpacing.sm;

    return Row(
      children: [
        _BeatButton(
          icon: Icons.remove,
          onTap: count > 1 ? onDecrement : null,
          isSmallScreen: isSmallScreen,
        ),
        SizedBox(width: buttonSpacing),
        Expanded(
          child: _buildScrollableCircles(
            context: context,
            count: count,
            visibleCount: visibleCount,
            needsScroll: needsScroll,
          ),
        ),
        SizedBox(width: addBtnSpacing),
        _BeatButton(
          icon: Icons.add,
          onTap: count < 12 ? onIncrement : null,
          showBadge: count > visibleCount,
          badgeCount: count,
          isSmallScreen: isSmallScreen,
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
    // Smaller circles on small screens: 16px instead of 20px
    final circleWidth = (isSmallScreen ? 16.0 : 20.0) + MonoPulseSpacing.sm;
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
                  isSmallScreen: isSmallScreen,
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
  final bool isSmallScreen;

  const _SubdivisionsRow({
    required this.count,
    required this.isPlaying,
    required this.currentBeat,
    required this.beats,
    required this.beatModes,
    required this.onToggleMode,
    required this.onIncrement,
    required this.onDecrement,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final visibleCount = _calculateVisibleCount(context);
    final needsScroll = count > visibleCount;

    // Adaptive spacing for small screens
    final buttonSpacing = isSmallScreen
        ? MonoPulseSpacing.sm
        : MonoPulseSpacing.md;
    final addBtnSpacing = isSmallScreen
        ? MonoPulseSpacing.xs
        : MonoPulseSpacing.sm;

    return Row(
      children: [
        _BeatButton(
          icon: Icons.remove,
          onTap: count > 1 ? onDecrement : null,
          isSmallScreen: isSmallScreen,
        ),
        SizedBox(width: buttonSpacing),
        Expanded(
          child: _buildScrollableCircles(
            context: context,
            count: count,
            visibleCount: visibleCount,
            needsScroll: needsScroll,
          ),
        ),
        SizedBox(width: addBtnSpacing),
        _BeatButton(
          icon: Icons.add,
          onTap: count < 12 ? onIncrement : null,
          showBadge: count > visibleCount,
          badgeCount: count,
          isSmallScreen: isSmallScreen,
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
    // Smaller circles on small screens: 16px instead of 20px
    final circleWidth = (isSmallScreen ? 16.0 : 20.0) + MonoPulseSpacing.sm;
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
                  isSmallScreen: isSmallScreen,
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
  final bool isSmallScreen;

  const _BeatCircleWithMode({
    required this.isMainBeat,
    required this.isActive,
    required this.mode,
    required this.onTap,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    // Smaller circles on small screens: 16px instead of 20px
    final circleSize = isSmallScreen ? 16.0 : 20.0;
    final containerSize = isSmallScreen ? 40.0 : 48.0;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: containerSize,
        height: containerSize,
        child: Center(
          child: AnimatedContainer(
            duration: MonoPulseAnimation.durationShort,
            curve: MonoPulseAnimation.curveCustom,
            width: circleSize,
            height: circleSize,
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
          color: MonoPulseColors.textPrimary,
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
  final bool isSmallScreen;

  const _SubdivisionCircleWithMode({
    required this.subdivisionIndex,
    required this.isActive,
    required this.mode,
    this.onTap,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    // Smaller circles on small screens: 16px instead of 20px
    final circleSize = isSmallScreen ? 16.0 : 20.0;
    final containerSize = isSmallScreen ? 40.0 : 48.0;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: containerSize,
        height: containerSize,
        child: Center(
          child: AnimatedContainer(
            duration: MonoPulseAnimation.durationShort,
            curve: MonoPulseAnimation.curveCustom,
            width: circleSize,
            height: circleSize,
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
          color: MonoPulseColors.textPrimary,
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
  final bool isSmallScreen;

  const _BeatButton({
    required this.icon,
    this.onTap,
    this.showBadge = false,
    this.badgeCount = 0,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    // Smaller buttons on small screens
    final buttonSize = isSmallScreen ? 40.0 : 48.0;
    final iconSize = isSmallScreen ? 16.0 : 20.0;
    final badgeSize = isSmallScreen ? 14.0 : 18.0;
    final badgeFontSize = isSmallScreen ? 8.0 : 10.0;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: buttonSize,
        height: buttonSize,
        child: Center(
          child: AnimatedContainer(
            duration: MonoPulseAnimation.durationShort,
            curve: MonoPulseAnimation.curveCustom,
            width: buttonSize - 8,
            height: buttonSize - 8,
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
                    size: iconSize,
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
                      width: badgeSize,
                      height: badgeSize,
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
                            fontSize: badgeFontSize,
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
