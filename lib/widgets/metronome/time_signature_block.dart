import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/beat_mode.dart';
import '../../providers/data/metronome_provider.dart';
import '../../theme/mono_pulse_theme.dart';

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
// CIRCLE STRIP LAYOUT
// ============================================================================

/// Maximum touch-target size for a single beat/subdivision circle.
const double _kMaxCircleContainer = 48;

/// Smaller maximum used on narrow screens.
const double _kMaxCircleContainerSmall = 40;

/// Absolute floor for a circle cell. A beat indicator is a real-time status
/// display first: every beat must stay visible, so we keep shrinking down to
/// this floor rather than scrolling. At the app's max of 12 beats this still
/// fits on any phone ~360dp or wider; the scroll fallback only ever engages on
/// extremely narrow (legacy) screens, to avoid clipping.
const double _kMinCircleContainer = 14;

/// Spacing between circles, used only by the (rare) scroll fallback. In the
/// normal fit-to-width layout each cell carries its own padding around the dot,
/// so spacing comes from the cells themselves.
const double _kCircleGap = MonoPulseSpacing.sm;

/// Computed layout for a horizontal strip of beat/subdivision circles.
///
/// `containerSize` is shrunk so that all circles fit the available width.
/// `needsScroll` is true only when even the floor cell size cannot fit every
/// circle (legacy ultra-narrow screens), in which case the strip degrades to a
/// horizontal scroll view instead of clipping.
class _StripMetrics {
  const _StripMetrics({required this.containerSize, required this.needsScroll});

  factory _StripMetrics.compute({
    required double availableWidth,
    required int count,
    required bool isSmallScreen,
  }) {
    final maxContainer = isSmallScreen
        ? _kMaxCircleContainerSmall
        : _kMaxCircleContainer;
    // Each cell already pads the dot, so the cell footprint is the unit that
    // must tile across the available width.
    final ideal = count > 0 ? availableWidth / count : maxContainer;
    final needsScroll = ideal < _kMinCircleContainer;
    final containerSize = ideal.clamp(_kMinCircleContainer, maxContainer);
    return _StripMetrics(
      containerSize: containerSize,
      needsScroll: needsScroll,
    );
  }

  final double containerSize;
  final bool needsScroll;
}

/// Lays out [children] as a strip: evenly spread when they fit, or a
/// horizontal scroll view when the metrics report `needsScroll`.
Widget _buildCircleStrip({
  required BuildContext context,
  required _StripMetrics metrics,
  required List<Widget> children,
  required Key scrollKey,
}) {
  if (!metrics.needsScroll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: children,
    );
  }

  final spaced = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    spaced.add(children[i]);
    if (i < children.length - 1) {
      spaced.add(const SizedBox(width: _kCircleGap));
    }
  }

  return ClipRect(
    child: Theme(
      data: Theme.of(context).copyWith(
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(MonoPulseColors.borderDefault),
          thickness: WidgetStateProperty.all(2),
          radius: const Radius.circular(2),
        ),
      ),
      child: SingleChildScrollView(
        key: scrollKey,
        scrollDirection: Axis.horizontal,
        child: Row(children: spaced),
      ),
    ),
  );
}

// ============================================================================
// BEATS ROW (Top Row)
// ============================================================================
class _BeatsRow extends StatelessWidget {
  const _BeatsRow({
    required this.count,
    required this.subdivisions,
    required this.beatModes,
    required this.onToggleMode,
    required this.onIncrement,
    required this.onDecrement,
    this.currentBeat = -1,
    this.isSmallScreen = false,
  });
  final int count;
  final int currentBeat;
  final int subdivisions;
  final List<List<BeatMode>> beatModes;
  final void Function(int, int, BeatMode) onToggleMode;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final bool isSmallScreen;

  @override
  Widget build(BuildContext context) {
    final buttonSpacing = isSmallScreen
        ? MonoPulseSpacing.sm
        : MonoPulseSpacing.md;
    final addBtnSpacing = isSmallScreen
        ? MonoPulseSpacing.xs
        : MonoPulseSpacing.sm;
    final buttonSize = isSmallScreen ? 40.0 : 48.0;

    return Row(
      children: [
        SizedBox(
          width: isSmallScreen ? 42 : 52,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Beats',
              style: MonoPulseTypography.labelSmall.copyWith(
                color: MonoPulseColors.textSecondary,
              ),
            ),
          ),
        ),
        _BeatButton(
          key: const Key('main-beats-decrement'),
          icon: Icons.remove,
          onTap: count > 1 ? onDecrement : null,
          isSmallScreen: isSmallScreen,
        ),
        SizedBox(width: buttonSpacing),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final metrics = _StripMetrics.compute(
                availableWidth: constraints.maxWidth,
                count: count,
                isSmallScreen: isSmallScreen,
              );
              return _buildCircleStrip(
                context: context,
                metrics: metrics,
                scrollKey: const Key('main-beat-strip-scroll'),
                children: List.generate(count, (beatIndex) {
                  // Mode for the first subdivision of this beat (for display).
                  final mode =
                      beatIndex < beatModes.length &&
                          beatModes[beatIndex].isNotEmpty
                      ? beatModes[beatIndex][0]
                      : BeatMode.normal;

                  final isBeatActive =
                      currentBeat >= 0 &&
                      subdivisions > 0 &&
                      (currentBeat ~/ subdivisions) == beatIndex;

                  return _BeatModeCircle(
                    key: Key('main_beat_dot_$beatIndex'),
                    semanticLabel: 'Main beat ${beatIndex + 1}',
                    isActive: isBeatActive,
                    mode: mode,
                    containerSize: metrics.containerSize,
                    onTap: () => onToggleMode(beatIndex, 0, mode),
                    isSmallScreen: isSmallScreen,
                  );
                }),
              );
            },
          ),
        ),
        SizedBox(width: addBtnSpacing),
        _BeatButton(
          key: const Key('main-beats-increment'),
          icon: Icons.add,
          onTap: count < 12 ? onIncrement : null,
          badgeCount: count,
          isSmallScreen: isSmallScreen,
          buttonSize: buttonSize,
        ),
      ],
    );
  }
}

// ============================================================================
// SUBDIVISIONS ROW (Bottom Row)
// ============================================================================
class _SubdivisionsRow extends StatelessWidget {
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
  final int count;
  final bool isPlaying;
  final int currentBeat;
  final int beats;
  final List<List<BeatMode>> beatModes;
  final void Function(int, int, BeatMode) onToggleMode;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final bool isSmallScreen;

  @override
  Widget build(BuildContext context) {
    final buttonSpacing = isSmallScreen
        ? MonoPulseSpacing.sm
        : MonoPulseSpacing.md;
    final addBtnSpacing = isSmallScreen
        ? MonoPulseSpacing.xs
        : MonoPulseSpacing.sm;
    final buttonSize = isSmallScreen ? 40.0 : 48.0;

    return Row(
      children: [
        SizedBox(
          width: isSmallScreen ? 42 : 52,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Subdivision',
              style: MonoPulseTypography.labelSmall.copyWith(
                color: MonoPulseColors.textSecondary,
              ),
            ),
          ),
        ),
        _BeatButton(
          key: const Key('subdivisions-decrement'),
          icon: Icons.remove,
          onTap: count > 1 ? onDecrement : null,
          isSmallScreen: isSmallScreen,
        ),
        SizedBox(width: buttonSpacing),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final metrics = _StripMetrics.compute(
                availableWidth: constraints.maxWidth,
                count: count,
                isSmallScreen: isSmallScreen,
              );
              final currentBeatIndex = isPlaying && count > 0
                  ? currentBeat ~/ count
                  : -1;
              return _buildCircleStrip(
                context: context,
                metrics: metrics,
                scrollKey: const Key('subdivision-strip-scroll'),
                children: List.generate(count, (subdivisionIndex) {
                  // Mode for this subdivision of the current beat.
                  final mode =
                      currentBeatIndex >= 0 &&
                          currentBeatIndex < beatModes.length &&
                          subdivisionIndex < beatModes[currentBeatIndex].length
                      ? beatModes[currentBeatIndex][subdivisionIndex]
                      : BeatMode.normal;

                  final isSubdivisionActive =
                      isPlaying &&
                      currentBeat >= 0 &&
                      (currentBeat % count) == subdivisionIndex;

                  return _BeatModeCircle(
                    key: Key('subdivision_dot_$subdivisionIndex'),
                    semanticLabel: 'Subdivision ${subdivisionIndex + 1}',
                    isActive: isSubdivisionActive,
                    mode: mode,
                    containerSize: metrics.containerSize,
                    onTap: currentBeatIndex >= 0
                        ? () => onToggleMode(
                            currentBeatIndex,
                            subdivisionIndex,
                            mode,
                          )
                        : null,
                    isSmallScreen: isSmallScreen,
                  );
                }),
              );
            },
          ),
        ),
        SizedBox(width: addBtnSpacing),
        _BeatButton(
          key: const Key('subdivisions-increment'),
          icon: Icons.add,
          onTap: count < 12 ? onIncrement : null,
          badgeCount: count,
          isSmallScreen: isSmallScreen,
          buttonSize: buttonSize,
        ),
      ],
    );
  }
}

// ============================================================================
// BEAT MODE CIRCLE (TAPPABLE) — Mono Pulse audit A5
// ============================================================================
// Tinted fill + bright ring + per-state glyph so Normal / Accent / Silent read
// at a glance instead of blurring into muddy solid fills. The currently-playing
// cell intensifies to a solid fill + glow.
//
// Shared by both the main-beat strip and the subdivision strip (they previously
// duplicated identical color/indicator logic).

/// Resolved visuals for one beat-mode cell.
class _BeatCellStyle {
  const _BeatCellStyle({
    required this.fill,
    required this.ring,
    required this.glyphColor,
    this.glyph,
  });

  final Color fill;
  final Color ring;
  final Color glyphColor;

  /// Glyph for Accent (★) / Silent (⊘). Normal uses a small filled dot instead.
  final IconData? glyph;
}

_BeatCellStyle _beatCellStyle(BeatMode mode, bool isActive) {
  switch (mode) {
    case BeatMode.normal:
      return isActive
          ? const _BeatCellStyle(
              fill: MonoPulseColors.beatModeNormalBright,
              ring: MonoPulseColors.beatModeNormalBright,
              glyphColor: MonoPulseColors.black,
            )
          : const _BeatCellStyle(
              fill: MonoPulseColors.accentOrange15,
              ring: MonoPulseColors.beatModeNormal,
              glyphColor: MonoPulseColors.beatModeNormal,
            );
    case BeatMode.accent:
      return isActive
          ? const _BeatCellStyle(
              fill: MonoPulseColors.beatModeAccentBright,
              ring: MonoPulseColors.beatModeAccentBright,
              glyphColor: MonoPulseColors.black,
              glyph: Icons.star,
            )
          : _BeatCellStyle(
              fill: MonoPulseColors.beatModeAccent.withValues(alpha: 0.16),
              ring: MonoPulseColors.beatModeAccentBright,
              glyphColor: MonoPulseColors.beatModeAccentBright,
              glyph: Icons.star,
            );
    case BeatMode.silent:
      // ponytail: solid grey ring, not the doc's dashed ring — a dashed circle
      // needs a CustomPainter; the ⊘ glyph already reads as "muted". Swap to a
      // dashed-border painter if the dashed look is specifically wanted.
      return const _BeatCellStyle(
        fill: MonoPulseColors.transparent,
        ring: MonoPulseColors.textDisabled,
        glyphColor: MonoPulseColors.textDisabled,
        glyph: Icons.block,
      );
  }
}

class _BeatModeCircle extends StatelessWidget {
  const _BeatModeCircle({
    required this.isActive,
    required this.mode,
    required this.containerSize,
    required this.semanticLabel,
    super.key,
    this.onTap,
    this.isSmallScreen = false,
  });

  final bool isActive;
  final BeatMode mode;
  final double containerSize;
  final String semanticLabel;
  final VoidCallback? onTap;
  final bool isSmallScreen;

  @override
  Widget build(BuildContext context) {
    // Visible cell scales with the container but never exceeds the design size.
    final circleSize = math
        .min(isSmallScreen ? 16.0 : 20.0, containerSize - 8)
        .clamp(8.0, 20.0);
    final style = _beatCellStyle(mode, isActive);

    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
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
                color: style.fill,
                border: Border.all(color: style.ring, width: 2),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: style.ring.withValues(alpha: 0.6),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : const [],
              ),
              child: Transform.scale(
                scale: isActive ? 1.08 : 1.0,
                child: _glyph(style, circleSize),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _glyph(_BeatCellStyle style, double circleSize) {
    if (style.glyph != null) {
      return Center(
        child: Icon(
          style.glyph,
          size: circleSize * 0.6,
          color: style.glyphColor,
        ),
      );
    }
    // Normal: a small centered dot (·).
    final dot = (circleSize * 0.28).clamp(4.0, 7.0);
    return Center(
      child: Container(
        width: dot,
        height: dot,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: style.glyphColor,
        ),
      ),
    );
  }
}

// ============================================================================
// BEAT BUTTON (Plus/Minus)
// ============================================================================
class _BeatButton extends StatelessWidget {
  const _BeatButton({
    required this.icon,
    super.key,
    this.onTap,
    this.badgeCount = 0,
    this.isSmallScreen = false,
    this.buttonSize,
  });
  final IconData icon;
  final VoidCallback? onTap;

  /// Shown as a small badge on the button when greater than zero. Used so the
  /// total beat/subdivision count stays visible even when the strip scrolls.
  final int badgeCount;
  final bool isSmallScreen;
  final double? buttonSize;

  @override
  Widget build(BuildContext context) {
    // Smaller buttons on small screens
    final size = buttonSize ?? (isSmallScreen ? 40.0 : 48.0);
    final iconSize = isSmallScreen ? 16.0 : 20.0;
    final badgeSize = isSmallScreen ? 14.0 : 18.0;
    final badgeFontSize = isSmallScreen ? 8.0 : 10.0;
    final showBadge = badgeCount > 0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: AnimatedContainer(
            duration: MonoPulseAnimation.durationShort,
            curve: MonoPulseAnimation.curveCustom,
            width: size - 8,
            height: size - 8,
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
              clipBehavior: Clip.none,
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
                    top: -2,
                    right: -2,
                    child: Container(
                      width: badgeSize,
                      height: badgeSize,
                      decoration: BoxDecoration(
                        color: MonoPulseColors.accentOrange,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: MonoPulseColors.blackSurface,
                          width: 1.5,
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
