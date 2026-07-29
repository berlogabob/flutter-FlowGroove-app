import 'package:flutter/material.dart';
import '../theme/mono_pulse_theme.dart';

/// A customizable button widget with consistent styling.
///
/// This widget provides a reusable button with support for different
/// variants (primary, secondary, outline, text) and loading states.
class CustomButton extends StatelessWidget {
  const CustomButton({
    required this.label,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.isLoading = false,
    this.icon,
    this.fullWidth = false,
    super.key,
  });

  /// The text displayed on the button.
  final String label;

  /// Callback when the button is pressed.
  final VoidCallback? onPressed;

  /// The visual variant of the button.
  final ButtonVariant variant;

  /// The size of the button.
  final ButtonSize size;

  /// Whether the button is in a loading state.
  final bool isLoading;

  /// An optional icon to display before the label.
  final IconData? icon;

  /// Whether the button should expand to fill available width.
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final button = _buildButton(context);

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }

  Widget _buildButton(BuildContext context) {
    if (isLoading) {
      return _buildLoadingButton(context);
    }

    switch (variant) {
      case ButtonVariant.primary:
        return ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            padding: _padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MonoPulseRadius.large),
            ),
          ),
          child: _buildChild(),
        );
      case ButtonVariant.secondary:
        return ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.mp.surface,
            foregroundColor: MonoPulseColors.accentOrange,
            padding: _padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MonoPulseRadius.large),
              side: const BorderSide(color: MonoPulseColors.accentOrange),
            ),
          ),
          child: _buildChild(),
        );
      case ButtonVariant.outline:
        return OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: _padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MonoPulseRadius.large),
            ),
          ),
          child: _buildChild(),
        );
      case ButtonVariant.text:
        return TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(padding: _padding),
          child: _buildChild(),
        );
    }
  }

  Widget _buildLoadingButton(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(context.mp.textPrimary),
          ),
        ),
        if (label.isNotEmpty) ...[const SizedBox(width: 8), Text(label)],
      ],
    );

    switch (variant) {
      case ButtonVariant.primary:
      case ButtonVariant.secondary:
        return ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            padding: _padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MonoPulseRadius.large),
            ),
          ),
          child: child,
        );
      case ButtonVariant.outline:
        return OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            padding: _padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MonoPulseRadius.large),
            ),
          ),
          child: child,
        );
      case ButtonVariant.text:
        return TextButton(
          onPressed: null,
          style: TextButton.styleFrom(padding: _padding),
          child: child,
        );
    }
  }

  Widget _buildChild() {
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: _iconSize),
          if (label.isNotEmpty) ...[const SizedBox(width: 8), Text(label)],
        ],
      );
    }
    return Text(label);
  }

  EdgeInsetsGeometry get _padding {
    switch (size) {
      case ButtonSize.small:
        return const EdgeInsets.symmetric(
          horizontal: MonoPulseSpacing.md,
          vertical: MonoPulseSpacing.sm,
        );
      case ButtonSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: MonoPulseSpacing.xxl,
          vertical: MonoPulseSpacing.md,
        );
      case ButtonSize.large:
        return const EdgeInsets.symmetric(
          horizontal: MonoPulseSpacing.xxxl,
          vertical: MonoPulseSpacing.lg,
        );
    }
  }

  double get _iconSize {
    switch (size) {
      case ButtonSize.small:
        return 16;
      case ButtonSize.medium:
        return 18;
      case ButtonSize.large:
        return 20;
    }
  }
}

/// Button visual variants.
enum ButtonVariant {
  /// Primary button with main brand color.
  primary,

  /// Secondary button with accent color.
  secondary,

  /// Outlined button with border.
  outline,

  /// Text-only button.
  text,
}

/// Button size options.
enum ButtonSize {
  /// Small button for compact spaces.
  small,

  /// Medium button (default).
  medium,

  /// Large button for prominent actions.
  large,
}
