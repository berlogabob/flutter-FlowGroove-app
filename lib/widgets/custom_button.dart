import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A customizable button widget with consistent styling.
///
/// This widget provides a reusable button with support for different
/// variants (primary, secondary, outline, text) and loading states.
class CustomButton extends StatelessWidget {
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

  const CustomButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.isLoading = false,
    this.icon,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = _buildButton(context);

    return fullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }

  Widget _buildButton(BuildContext context) {
    if (isLoading) {
      return _buildLoadingButton();
    }

    switch (variant) {
      case ButtonVariant.primary:
        return ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            padding: _padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _buildChild(),
        );
      case ButtonVariant.secondary:
        return ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.color5,
            foregroundColor: Colors.white,
            padding: _padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
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
              borderRadius: BorderRadius.circular(8),
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

  Widget _buildLoadingButton() {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(label),
        ],
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
              borderRadius: BorderRadius.circular(8),
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
              borderRadius: BorderRadius.circular(8),
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
          if (label.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(label),
          ],
        ],
      );
    }
    return Text(label);
  }

  EdgeInsetsGeometry get _padding {
    switch (size) {
      case ButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case ButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
      case ButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
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
