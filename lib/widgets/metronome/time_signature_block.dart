import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data/metronome_provider.dart';
import '../../theme/mono_pulse_theme.dart';

/// Time Signature Block widget - Mono Pulse design (Sprint Fix)
///
/// Horizontal panel with two rows:
/// - Top row: Accent beats (tap to toggle strong/weak, #FF5E00 for strong)
/// - Bottom row: Regular beats (#222222)
///
/// NO text labels "Accent" or "Beats"
///
/// Circles represent beats:
/// - Inactive: #222222 fill + #333333 stroke
/// - Accent (strong): #FF5E00 fill + pulse
/// - Regular beat: #222222 fill
/// - Current beat: #FF5E00 + pulse animation (scale 1.08)
///
/// Adaptive: 4-6 visible circles based on screen width
/// >5 circles → orange badge at + button (circle #FF5E00, white text 12px)
/// Horizontal scroll if doesn't fit
/// Circles stay inside widget (Clip.hardEdge, fixed width)
class TimeSignatureBlock extends ConsumerStatefulWidget {
  const TimeSignatureBlock({super.key});

  @override
  ConsumerState<TimeSignatureBlock> createState() => _TimeSignatureBlockState();
}

class _TimeSignatureBlockState extends ConsumerState<TimeSignatureBlock> {
  // Track which accent beats are strong (true) or weak (false)
  final Map<int, bool> _accentStates = {};

  @override
  Widget build(BuildContext context) {
    final metronome = ref.watch(metronomeProvider.notifier);
    final state = ref.watch(metronomeProvider);
    final isPlaying = state.isPlaying;
    final currentBeat = state.currentBeat;
    final regularBeats = state.regularBeats;
    final accentBeats = state.accentBeats;

    // Initialize accent states when regular beats change
    for (int i = 0; i < regularBeats; i++) {
      if (!_accentStates.containsKey(i)) {
        _accentStates[i] =
            i < accentBeats; // First N beats are strong by default
      }
    }

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
          // Top row - Accent beats (NO label)
          _BeatRow(
            count: regularBeats,
            isAccentRow: true,
            accentStates: _accentStates,
            currentBeat: isPlaying ? currentBeat : -1,
            onToggleAccent: (index, isStrong) {
              HapticFeedback.lightImpact();
              setState(() {
                _accentStates[index] = isStrong;
              });
              // Update the accent pattern in provider
              _updateAccentPattern(metronome, regularBeats);
            },
            onIncrement: () {
              HapticFeedback.lightImpact();
              if (regularBeats < 12) {
                metronome.setRegularBeats(regularBeats + 1);
                setState(() {
                  _accentStates[regularBeats] =
                      true; // New beat is strong by default
                });
              }
            },
            onDecrement: () {
              HapticFeedback.lightImpact();
              if (regularBeats > 1) {
                metronome.setRegularBeats(regularBeats - 1);
                setState(() {
                  _accentStates.remove(regularBeats - 1);
                });
              }
            },
          ),
          const SizedBox(height: MonoPulseSpacing.md),
          // Bottom row - Regular beats (NO label)
          _BeatRow(
            count: regularBeats,
            isAccentRow: false,
            currentBeat: isPlaying ? currentBeat : -1,
            onIncrement: () {
              HapticFeedback.lightImpact();
              if (regularBeats < 12) {
                metronome.setRegularBeats(regularBeats + 1);
                setState(() {
                  _accentStates[regularBeats] = true;
                });
              }
            },
            onDecrement: () {
              HapticFeedback.lightImpact();
              if (regularBeats > 1) {
                metronome.setRegularBeats(regularBeats - 1);
                setState(() {
                  _accentStates.remove(regularBeats - 1);
                });
              }
            },
          ),
        ],
      ),
    );
  }

  void _updateAccentPattern(MetronomeNotifier metronome, int beatCount) {
    final pattern = List.generate(
      beatCount,
      (index) => _accentStates[index] ?? (index == 0),
    );
    metronome.setAccentPattern(pattern);
  }
}

class _BeatRow extends StatelessWidget {
  final int count;
  final bool isAccentRow;
  final Map<int, bool>? accentStates;
  final int currentBeat;
  final Function(int, bool)? onToggleAccent;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _BeatRow({
    required this.count,
    required this.isAccentRow,
    this.accentStates,
    this.currentBeat = -1,
    this.onToggleAccent,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate how many circles can fit on screen (4-6 based on width)
    final screenWidth = MediaQuery.of(context).size.width;
    final circleWidth = 32.0; // circle + spacing
    final maxVisible = (screenWidth - 80) ~/ circleWidth; // Account for margins
    final visibleCount = maxVisible.clamp(4, 6);
    final needsScroll = count > visibleCount;

    return Row(
      children: [
        // Minus button
        _BeatButton(icon: Icons.remove, onTap: count > 1 ? onDecrement : null),

        const SizedBox(width: MonoPulseSpacing.md),

        // Beat circles with horizontal scroll if needed
        Expanded(
          child: ClipRect(
            clipBehavior: Clip.hardEdge,
            child: needsScroll
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: Row(
                      children: List.generate(
                        count,
                        (index) => Padding(
                          padding: EdgeInsets.only(
                            right: index < count - 1 ? MonoPulseSpacing.sm : 0,
                          ),
                          child: _BeatCircle(
                            index: index,
                            isAccentRow: isAccentRow,
                            isStrong: accentStates?[index] ?? false,
                            isActive: currentBeat == index,
                            onToggle: isAccentRow
                                ? () {
                                    if (onToggleAccent != null) {
                                      final newState =
                                          !(accentStates?[index] ?? false);
                                      onToggleAccent!(index, newState);
                                    }
                                  }
                                : null,
                          ),
                        ),
                      ),
                    ),
                  )
                : Row(
                    children: List.generate(
                      count,
                      (index) => Padding(
                        padding: EdgeInsets.only(
                          right: index < count - 1 ? MonoPulseSpacing.sm : 0,
                        ),
                        child: _BeatCircle(
                          index: index,
                          isAccentRow: isAccentRow,
                          isStrong: accentStates?[index] ?? false,
                          isActive: currentBeat == index,
                          onToggle: isAccentRow
                              ? () {
                                  if (onToggleAccent != null) {
                                    final newState =
                                        !(accentStates?[index] ?? false);
                                    onToggleAccent!(index, newState);
                                  }
                                }
                              : null,
                        ),
                      ),
                    ),
                  ),
          ),
        ),

        const SizedBox(width: MonoPulseSpacing.sm),

        // Plus button with badge if >5 circles
        _BeatButton(
          icon: Icons.add,
          onTap: count < 12 ? onIncrement : null,
          showBadge: count > 5,
          badgeCount: count,
        ),
      ],
    );
  }
}

class _BeatCircle extends StatefulWidget {
  final int index;
  final bool isAccentRow;
  final bool isStrong;
  final bool isActive;
  final VoidCallback? onToggle;

  const _BeatCircle({
    required this.index,
    required this.isAccentRow,
    this.isStrong = false,
    this.isActive = false,
    this.onToggle,
  });

  @override
  State<_BeatCircle> createState() => _BeatCircleState();
}

class _BeatCircleState extends State<_BeatCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: MonoPulseAnimation.durationShort,
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: MonoPulseAnimation.curveCustom,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_BeatCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _triggerPulse();
    }
  }

  void _triggerPulse() {
    _pulseController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // Minimum 48px touch zone per Mono Pulse brandbook
    const touchZoneSize = 48.0;
    const circleSize = 20.0;

    // Determine colors based on row type and state
    Color fillColor;
    Color strokeColor;

    if (widget.isAccentRow) {
      // Top row: accents
      if (widget.isStrong) {
        // Strong accent: #FF5E00 fill
        fillColor = MonoPulseColors.accentOrange;
        strokeColor = MonoPulseColors.accentOrange;
      } else {
        // Weak accent: #222222 fill, #333333 stroke
        fillColor = MonoPulseColors.borderSubtle;
        strokeColor = MonoPulseColors.borderDefault;
      }
    } else {
      // Bottom row: regular beats
      fillColor = MonoPulseColors.borderSubtle;
      strokeColor = MonoPulseColors.borderDefault;
    }

    // Active beat overrides colors
    if (widget.isActive) {
      fillColor = MonoPulseColors.accentOrange;
      strokeColor = MonoPulseColors.accentOrange;
    }

    return GestureDetector(
      onTap: widget.onToggle,
      child: AnimatedScale(
        scale: _pulseController.isAnimating ? _pulseAnimation.value : 1.0,
        duration: MonoPulseAnimation.durationShort,
        curve: MonoPulseAnimation.curveCustom,
        child: SizedBox(
          width: touchZoneSize,
          height: touchZoneSize,
          child: Center(
            child: Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fillColor,
                border: Border.all(color: strokeColor, width: 1.5),
                boxShadow: widget.isActive
                    ? [
                        BoxShadow(
                          color: MonoPulseColors.accentOrange.withValues(
                            alpha: 0.4,
                          ),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BeatButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool showBadge;
  final int? badgeCount;

  const _BeatButton({
    required this.icon,
    this.onTap,
    this.showBadge = false,
    this.badgeCount,
  });

  @override
  State<_BeatButton> createState() => _BeatButtonState();
}

class _BeatButtonState extends State<_BeatButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onTap != null;

    return GestureDetector(
      onTapDown: (_) {
        if (isEnabled) {
          setState(() => _isPressed = true);
          HapticFeedback.vibrate();
        }
      },
      onTapUp: (_) {
        if (isEnabled) {
          setState(() => _isPressed = false);
          HapticFeedback.vibrate();
          widget.onTap!();
        }
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: MonoPulseAnimation.durationShort,
        curve: MonoPulseAnimation.curveCustom,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              // Minimum 48px touch zone
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isEnabled
                    ? MonoPulseColors.blackElevated
                    : MonoPulseColors.blackElevated.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(MonoPulseRadius.huge),
                border: Border.all(
                  color: isEnabled
                      ? MonoPulseColors.borderSubtle
                      : MonoPulseColors.borderSubtle.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                widget.icon,
                size: 20,
                color: isEnabled
                    ? (_isPressed
                          ? MonoPulseColors.accentOrange
                          : MonoPulseColors.textSecondary)
                    : MonoPulseColors.textDisabled,
              ),
            ),
            // Badge for >5 circles
            if (widget.showBadge && widget.badgeCount != null)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: MonoPulseColors.accentOrange,
                    shape: BoxShape.circle,
                    border: Border.all(color: MonoPulseColors.black, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '${widget.badgeCount}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: MonoPulseColors.white,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
