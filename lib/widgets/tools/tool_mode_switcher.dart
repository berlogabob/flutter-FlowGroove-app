import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/mono_pulse_theme.dart';
import 'tool_scaffold.dart';

/// Mode switcher widget for tools with multiple modes.
///
/// Features:
/// - Animated pill buttons
/// - Smooth fade transition (250ms)
/// - Consistent styling across all tools
/// - Haptic feedback on tap
///
/// Usage:
/// ```dart
/// ToolModeSwitcher<TunerMode>(
///   activeMode: mode,
///   options: [
///     ToolModeOption(
///       mode: TunerMode.generate,
///       label: 'Generate Tone',
///       icon: Icons.graphic_eq,
///     ),
///     ToolModeOption(
///       mode: TunerMode.listen,
///       label: 'Listen & Tune',
///       icon: Icons.mic,
///     ),
///   ],
///   onModeChanged: (mode) => setMode(mode),
/// )
/// ```
class ToolModeSwitcher<T extends Enum> extends StatelessWidget {
  const ToolModeSwitcher({
    required this.activeMode,
    required this.options,
    required this.onModeChanged,
    super.key,
    this.animationDuration = const Duration(milliseconds: 250),
  });

  /// Currently active mode.
  final T activeMode;

  /// Available mode options.
  final List<ToolModeOption<T>> options;

  /// Callback when mode changes.
  final ValueChanged<T> onModeChanged;

  /// Animation duration.
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: options.map((option) {
        final isActive = activeMode == option.mode;
        return _ModePill(
          label: option.label,
          icon: option.icon,
          isActive: isActive,
          onTap: () {
            HapticFeedback.lightImpact();
            onModeChanged(option.mode);
          },
          animationDuration: animationDuration,
        );
      }).toList(),
    );
  }
}

class ToolModeOption<T> {
  const ToolModeOption({required this.mode, required this.label, this.icon});

  final T mode;
  final String label;
  final IconData? icon;
}

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.animationDuration,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool isActive;
  final VoidCallback onTap;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: animationDuration,
      curve: MonoPulseAnimation.curveCustom,
      opacity: isActive ? 1.0 : 0.6,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: ToolSpacing.lg(context),
            vertical: ToolSpacing.md(context),
          ),
          margin: EdgeInsets.symmetric(horizontal: ToolSpacing.sm(context)),
          decoration: BoxDecoration(
            color: isActive
                ? MonoPulseColors.accentOrange10
                : context.mp.surface,
            borderRadius: BorderRadius.circular(MonoPulseRadius.large),
            border: Border.all(
              color: isActive
                  ? MonoPulseColors.accentOrange
                  : context.mp.borderSubtle,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: isActive
                      ? MonoPulseColors.accentOrange
                      : context.mp.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: MonoPulseTypography.labelLarge.copyWith(
                  color: isActive
                      ? MonoPulseColors.accentOrange
                      : context.mp.textSecondary,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
