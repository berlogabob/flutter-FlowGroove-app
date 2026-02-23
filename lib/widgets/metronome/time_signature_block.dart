import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data/metronome_provider.dart';
import '../../theme/mono_pulse_theme.dart';

/// Time Signature Block widget - Mono Pulse design (Sprint Fix)
///
/// Horizontal panel with two INDEPENDENT rows:
/// - Top row: Accent beats (tap to toggle strong/weak, #FF5E00 for strong)
/// - Bottom row: Regular beats (#222222)
///
/// NO text labels "Accent" or "Beats"
///
/// SPRINT FIXES:
/// - Minimum 4 visible circles on ALL devices (standard 4/4)
/// - Adaptive by MediaQuery.width (4-6 circles based on screen width)
/// - Badge at + button: appears after fitting circles (if 4 visible → badge shows 5)
/// - INDEPENDENT rows: adjusting top row doesn't affect bottom row, and vice versa
/// - Horizontal scroll: ScrollView for rows if > visible (thin scrollbar #333333)
/// - Circles stay inside widget (Clip.hardEdge, fixed width = screen width - padding - buttons)
///
/// Circles represent beats:
/// - Inactive: #222222 fill + #333333 stroke
/// - Accent (strong): #FF5E00 fill + pulse
/// - Regular beat: #222222 fill
/// - Current beat: #FF5E00 + pulse animation (scale 1.08)
class TimeSignatureBlock extends ConsumerStatefulWidget {
  const TimeSignatureBlock({super.key});

  @override
  ConsumerState<TimeSignatureBlock> createState() => _TimeSignatureBlockState();
}

class _TimeSignatureBlockState extends ConsumerState<TimeSignatureBlock> {
  // Track which accent beats are strong (true) or weak (false)
  // This is INDEPENDENT from regular beats count
  final Map<int, bool> _accentStates = {};

  @override
  Widget build(BuildContext context) {
    final metronome = ref.watch(metronomeProvider.notifier);
    final state = ref.watch(metronomeProvider);
    final isPlaying = state.isPlaying;
    final currentBeat = state.currentBeat;
    final regularBeats = state.regularBeats;
    final accentPattern = state.accentPattern;

    // Initialize accent states from pattern when it changes
    for (int i = 0; i < accentPattern.length; i++) {
      if (!_accentStates.containsKey(i)) {
        _accentStates[i] = accentPattern[i];
      }
    }

    // Sync accent states with pattern (in case pattern changed externally)
    for (int i = 0; i < accentPattern.length; i++) {
      if (_accentStates[i] != accentPattern[i]) {
        _accentStates[i] = accentPattern[i];
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
          // Top row - Accent beats (INDEPENDENT, NO label)
          _AccentRow(
            accentPattern: accentPattern,
            currentBeat: isPlaying ? currentBeat : -1,
            onToggleAccent: (index, isStrong) {
              HapticFeedback.lightImpact();
              final newPattern = List<bool>.from(accentPattern);
              if (index < newPattern.length) {
                newPattern[index] = isStrong;
                metronome.setAccentPattern(newPattern);
                setState(() {
                  _accentStates[index] = isStrong;
                });
              }
            },
            onAddAccent: () {
              HapticFeedback.lightImpact();
              // Add a new accent to the pattern (extends pattern)
              final newPattern = List<bool>.from(accentPattern);
              newPattern.add(false); // New accent is weak by default
              metronome.setAccentPattern(newPattern);
              setState(() {
                _accentStates[newPattern.length - 1] = false;
              });
            },
            onRemoveAccent: () {
              HapticFeedback.lightImpact();
              // Remove last accent from pattern (but keep at least 1)
              if (accentPattern.length > 1) {
                final newPattern = List<bool>.from(accentPattern);
                newPattern.removeLast();
                metronome.setAccentPattern(newPattern);
                setState(() {
                  _accentStates.remove(newPattern.length);
                });
              }
            },
          ),
          const SizedBox(height: MonoPulseSpacing.md),
          // Bottom row - Regular beats (INDEPENDENT, NO label)
          _BeatRow(
            count: regularBeats,
            currentBeat: isPlaying ? currentBeat : -1,
            onIncrement: () {
              HapticFeedback.lightImpact();
              if (regularBeats < 12) {
                metronome.setRegularBeats(regularBeats + 1);
              }
            },
            onDecrement: () {
              HapticFeedback.lightImpact();
              if (regularBeats > 1) {
                metronome.setRegularBeats(regularBeats - 1);
              }
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ACCENT ROW (Top Row) - INDEPENDENT from Beat Row
// ============================================================================
class _AccentRow extends StatelessWidget {
  final List<bool> accentPattern;
  final int currentBeat;
  final Function(int, bool) onToggleAccent;
  final VoidCallback onAddAccent;
  final VoidCallback onRemoveAccent;

  const _AccentRow({
    required this.accentPattern,
    this.currentBeat = -1,
    required this.onToggleAccent,
    required this.onAddAccent,
    required this.onRemoveAccent,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate adaptive visible count based on screen width
    final visibleCount = _calculateVisibleCount(context);
    final needsScroll = accentPattern.length > visibleCount;

    return Row(
      children: [
        // Minus button
        _BeatButton(
          icon: Icons.remove,
          onTap: accentPattern.length > 1 ? onRemoveAccent : null,
        ),

        const SizedBox(width: MonoPulseSpacing.md),

        // Accent circles with horizontal scroll if needed
        Expanded(
          child: _buildScrollableCircles(
            context: context,
            count: accentPattern.length,
            visibleCount: visibleCount,
            needsScroll: needsScroll,
            isAccentRow: true,
          ),
        ),

        const SizedBox(width: MonoPulseSpacing.sm),

        // Plus button with badge if > visible circles
        _BeatButton(
          icon: Icons.add,
          onTap: accentPattern.length < 12 ? onAddAccent : null,
          showBadge: accentPattern.length > visibleCount,
          badgeCount: accentPattern.length,
        ),
      ],
    );
  }

  Widget _buildScrollableCircles({
    required BuildContext context,
    required int count,
    required int visibleCount,
    required bool needsScroll,
    required bool isAccentRow,
  }) {
    return ClipRect(
      clipBehavior: Clip.hardEdge,
      child: needsScroll
          ? Theme(
              data: Theme.of(context).copyWith(
                scrollbarTheme: ScrollbarThemeData(
                  thumbColor: WidgetStateProperty.all(
                    MonoPulseColors.borderDefault,
                  ),
                  trackColor: WidgetStateProperty.all(
                    MonoPulseColors.transparent,
                  ),
                  thickness: WidgetStateProperty.all(2),
                  radius: const Radius.circular(2),
                ),
              ),
              child: Scrollbar(
                thumbVisibility: true,
                trackVisibility: false,
                child: SingleChildScrollView(
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
                          isAccentRow: true,
                          isStrong: accentPattern[index],
                          isActive: currentBeat == index,
                          onToggle: () {
                            onToggleAccent(index, !accentPattern[index]);
                          },
                        ),
                      ),
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
                    isAccentRow: true,
                    isStrong: accentPattern[index],
                    isActive: currentBeat == index,
                    onToggle: () {
                      onToggleAccent(index, !accentPattern[index]);
                    },
                  ),
                ),
              ),
            ),
    );
  }
}

// ============================================================================
// BEAT ROW (Bottom Row) - INDEPENDENT from Accent Row
// ============================================================================
class _BeatRow extends StatelessWidget {
  final int count;
  final int currentBeat;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _BeatRow({
    required this.count,
    this.currentBeat = -1,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate adaptive visible count based on screen width
    final visibleCount = _calculateVisibleCount(context);
    final needsScroll = count > visibleCount;

    return Row(
      children: [
        // Minus button
        _BeatButton(icon: Icons.remove, onTap: count > 1 ? onDecrement : null),

        const SizedBox(width: MonoPulseSpacing.md),

        // Beat circles with horizontal scroll if needed
        Expanded(
          child: _buildScrollableCircles(
            context: context,
            count: count,
            visibleCount: visibleCount,
            needsScroll: needsScroll,
          ),
        ),

        const SizedBox(width: MonoPulseSpacing.sm),

        // Plus button with badge if > visible circles
        _BeatButton(
          icon: Icons.add,
          onTap: count < 12 ? onIncrement : null,
          showBadge: count > visibleCount,
          badgeCount: count,
        ),
      ],
    );
  }

  Widget _buildScrollableCircles({
    required BuildContext context,
    required int count,
    required int visibleCount,
    required bool needsScroll,
  }) {
    return ClipRect(
      clipBehavior: Clip.hardEdge,
      child: needsScroll
          ? Theme(
              data: Theme.of(context).copyWith(
                scrollbarTheme: ScrollbarThemeData(
                  thumbColor: WidgetStateProperty.all(
                    MonoPulseColors.borderDefault,
                  ),
                  trackColor: WidgetStateProperty.all(
                    MonoPulseColors.transparent,
                  ),
                  thickness: WidgetStateProperty.all(2),
                  radius: const Radius.circular(2),
                ),
              ),
              child: Scrollbar(
                thumbVisibility: true,
                trackVisibility: false,
                child: SingleChildScrollView(
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
                          isAccentRow: false,
                          isActive: currentBeat == index,
                        ),
                      ),
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
                    isAccentRow: false,
                    isActive: currentBeat == index,
                  ),
                ),
              ),
            ),
    );
  }
}

// ============================================================================
// ADAPTIVE VISIBLE COUNT CALCULATION
// ============================================================================
int _calculateVisibleCount(BuildContext context) {
  // Calculate visible circles based on screen width
  final screenWidth = MediaQuery.of(context).size.width;
  // Available width = screen width - margins (xxxl * 2) - padding (lg * 2) - buttons (48 * 2) - spacing (md + sm)
  final availableWidth =
      screenWidth -
      (MonoPulseSpacing.xxxl * 2) -
      (MonoPulseSpacing.lg * 2) -
      (48 * 2) -
      MonoPulseSpacing.md -
      MonoPulseSpacing.sm;

  // Circle width = 20px circle + spacing (sm = 8px) = 28px minimum
  // Touch zone = 48px (but circles are visually smaller)
  final circleWidth = 20.0 + MonoPulseSpacing.sm;
  final maxVisible = (availableWidth / circleWidth).floor();

  // Always show at least 4 circles (standard 4/4), max 6
  return maxVisible.clamp(4, 6);
}

// ============================================================================
// BEAT CIRCLE
// ============================================================================
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

// ============================================================================
// BEAT BUTTON (+/-)
// ============================================================================
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
            // Badge for > visible circles
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
