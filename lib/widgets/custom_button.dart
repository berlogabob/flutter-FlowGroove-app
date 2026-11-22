import 'package:material_ui/material_ui.dart';

import '../theme/mono_pulse_theme.dart';

/// The app's button. Use it instead of raw ElevatedButton / OutlinedButton so
/// every call site gets the same shape, padding and loading behaviour.
///
/// Mirrored by the FigCraft "Button" component (Variant × Size), linked through
/// Code Connect in design/figcraft/build.py.
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

  /// Callback when the button is pressed; null disables it.
  final VoidCallback? onPressed;

  /// The visual variant of the button.
  final ButtonVariant variant;

  /// The size of the button.
  final ButtonSize size;

  /// Shows a spinner and disables the button.
  final bool isLoading;

  /// An optional icon to display before the label.
  final IconData? icon;

  /// Whether the button should expand to fill available width.
  final bool fullWidth;

  static const _border = BorderSide(
    color: MonoPulseColors.charcoal,
    width: 1.2,
  );
  static const _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(MonoPulseRadius.button)),
  );

  @override
  Widget build(BuildContext context) {
    final button = _buildButton(context);
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }

  Widget _buildButton(BuildContext context) {
    final tap = isLoading ? null : onPressed;
    final child = _content(context);
    switch (variant) {
      case ButtonVariant.primary:
        return ElevatedButton(
          onPressed: tap,
          style: ElevatedButton.styleFrom(
            padding: _padding,
            shape: _shape.copyWith(side: _border),
          ),
          child: child,
        );
      case ButtonVariant.secondary:
        return ElevatedButton(
          onPressed: tap,
          style: ElevatedButton.styleFrom(
            backgroundColor: MonoPulseColors.white,
            foregroundColor: MonoPulseColors.charcoal,
            padding: _padding,
            shape: _shape.copyWith(side: _border),
          ),
          child: child,
        );
      case ButtonVariant.danger:
        return ElevatedButton(
          onPressed: tap,
          style: ElevatedButton.styleFrom(
            backgroundColor: MonoPulseColors.error,
            foregroundColor: MonoPulseColors.charcoal,
            padding: _padding,
            shape: _shape.copyWith(side: _border),
          ),
          child: child,
        );
      case ButtonVariant.outline:
        return OutlinedButton(
          onPressed: tap,
          style: OutlinedButton.styleFrom(padding: _padding, shape: _shape),
          child: child,
        );
      case ButtonVariant.tonal:
        return FilledButton.tonal(
          onPressed: tap,
          // The FilledButton theme carries the CTA border and shadow; tonal
          // is the soft variant, so it drops both.
          style: FilledButton.styleFrom(
            padding: _padding,
            elevation: 0,
            shape: _shape,
          ),
          child: child,
        );
      case ButtonVariant.text:
        return TextButton(
          onPressed: tap,
          style: TextButton.styleFrom(padding: _padding),
          child: child,
        );
    }
  }

  Widget _content(BuildContext context) {
    final onLight =
        variant == ButtonVariant.secondary || variant == ButtonVariant.danger;
    const spinnerSize = MonoPulseIcons.sizeSmall;
    final slotSize = icon == null ? spinnerSize : _iconSize;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: slotSize,
          child: Center(
            child: isLoading
                ? SizedBox.square(
                    dimension: spinnerSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: onLight
                          ? MonoPulseColors.charcoal
                          : context.mp.textPrimary,
                    ),
                  )
                : icon == null
                ? null
                : Icon(icon, size: _iconSize),
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(width: MonoPulseSpacing.sm),
          Flexible(
            child: Text(
              label,
              overflow: icon == null ? null : TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  /// Medium matches the app-wide ElevatedButton / OutlinedButton theme
  /// padding, so moving a raw themed button onto CustomButton keeps its size.
  EdgeInsetsGeometry get _padding {
    switch (size) {
      case ButtonSize.small:
        return const EdgeInsets.symmetric(
          horizontal: MonoPulseSpacing.md,
          vertical: MonoPulseSpacing.sm,
        );
      case ButtonSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: MonoPulseSpacing.xl,
          vertical: MonoPulseSpacing.lg,
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
        return MonoPulseIcons.sizeSmall;
      case ButtonSize.medium:
        return 18;
      case ButtonSize.large:
        return MonoPulseIcons.sizeMedium;
    }
  }
}

/// Button visual variants.
enum ButtonVariant {
  /// Orange call to action (ElevatedButton, charcoal border). Raw
  /// FilledButtons share this look through the theme.
  primary,

  /// White button with charcoal border.
  secondary,

  /// Outlined, transparent background.
  outline,

  /// Text-only button.
  text,

  /// Soft filled button for secondary actions in a row (FilledButton.tonal).
  tonal,

  /// Destructive action: error red, charcoal border.
  danger,
}

/// Button size options.
enum ButtonSize {
  /// Small button for compact spaces.
  small,

  /// Medium button (default); same padding as the theme's buttons.
  medium,

  /// Large button for prominent actions.
  large,
}
