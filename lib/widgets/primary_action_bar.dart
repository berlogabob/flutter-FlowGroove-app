import 'package:flutter/material.dart';
import '../theme/mono_pulse_theme.dart';
import 'custom_button.dart';

/// A persistent bottom action bar for form screens.
///
/// Pins a full-width primary action button to the bottom of the screen
/// with safe area awareness, suitable for Create/Edit form screens.
///
/// The action bar is always visible and doesn't scroll with content.
///
/// Usage:
/// ```dart
/// Scaffold(
///   appBar: AppBar(title: const Text('Create Item')),
///   body: SingleChildScrollView(
///     child: Column(
///       children: [
///         // Form fields
///       ],
///     ),
///   ),
///   bottomNavigationBar: PrimaryActionBar(
///     label: 'Create',
///     onPressed: _handleCreate,
///     isLoading: _isLoading,
///   ),
/// )
/// ```
class PrimaryActionBar extends StatelessWidget {
  /// Text displayed on the action button
  final String label;

  /// Callback when the action button is pressed
  final VoidCallback? onPressed;

  /// Whether the button is in a loading state
  final bool isLoading;

  /// The visual variant of the button (defaults to primary)
  final ButtonVariant variant;

  /// The size of the button (defaults to large for prominence)
  final ButtonSize size;

  /// Optional icon to display before the label
  final IconData? icon;

  /// Optional secondary action button (e.g., "Cancel")
  final ({String label, VoidCallback onPressed})? secondaryAction;

  /// Background color of the action bar
  final Color backgroundColor;

  /// Elevation/shadow of the action bar
  final double elevation;

  const PrimaryActionBar({
    super.key,
    required this.label,
    this.isLoading = false,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.large,
    this.backgroundColor = MonoPulseColors.surface,
    this.elevation = 8,
    this.onPressed,
    this.icon,
    this.secondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      elevation: elevation,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(MonoPulseSpacing.lg),
          child: secondaryAction != null
              ? Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        label: secondaryAction!.label,
                        onPressed: secondaryAction!.onPressed,
                        variant: ButtonVariant.outline,
                        size: size,
                        fullWidth: true,
                      ),
                    ),
                    const SizedBox(width: MonoPulseSpacing.md),
                    Expanded(
                      child: CustomButton(
                        label: label,
                        onPressed: onPressed,
                        variant: variant,
                        size: size,
                        isLoading: isLoading,
                        icon: icon,
                        fullWidth: true,
                      ),
                    ),
                  ],
                )
              : CustomButton(
                  label: label,
                  onPressed: onPressed,
                  variant: variant,
                  size: size,
                  isLoading: isLoading,
                  icon: icon,
                  fullWidth: true,
                ),
        ),
      ),
    );
  }
}
