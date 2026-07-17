import 'package:flutter/material.dart';
import '../theme/mono_pulse_theme.dart';

/// Canonical card variants for consistent styling across the app.
///
/// Two variants:
/// - [AppCardVariant.surface]: Base card with subtle border, no elevation
/// - [AppCardVariant.raised]: Elevated card with shadow for emphasis
///
/// Usage:
/// ```dart
/// // Base card
/// AppCard(
///   variant: AppCardVariant.surface,
///   child: Padding(
///     padding: const EdgeInsets.all(MonoPulseSpacing.lg),
///     child: Text('Content'),
///   ),
/// )
///
/// // Raised card
/// AppCard(
///   variant: AppCardVariant.raised,
///   child: Padding(
///     padding: const EdgeInsets.all(MonoPulseSpacing.lg),
///     child: Text('Important Content'),
///   ),
/// )
/// ```
/// Visual variants for [AppCard]. Declared top-level — Dart does not allow
/// enums nested inside a class.
enum AppCardVariant {
  /// Base card: surface background, subtle border, no elevation
  surface,

  /// Elevated card: raised background, shadow, subtle border
  raised,
}

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.variant = AppCardVariant.surface,
    this.onTap,
    this.backgroundColor,
    this.padding,
    this.border,
  });

  /// The visual variant of the card
  final AppCardVariant variant;

  /// The child widget to display inside the card
  final Widget child;

  /// Custom background color (defaults to surface color)
  final Color? backgroundColor;

  /// Optional padding around the child (in addition to card structure)
  final EdgeInsetsGeometry? padding;

  /// Optional border (used for surface variant)
  final Border? border;

  /// Optional callback when card is tapped
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = padding != null
        ? Padding(padding: padding!, child: child)
        : child;

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor ?? _getBackgroundColor(context),
        borderRadius: BorderRadius.circular(MonoPulseRadius.xlarge),
        border: border ?? _getDefaultBorder(context),
        boxShadow: variant == AppCardVariant.raised
            ? [MonoPulseElevation.shadowLow]
            : null,
      ),
      child: content,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MonoPulseRadius.xlarge),
          child: card,
        ),
      );
    }

    return card;
  }

  Color _getBackgroundColor(BuildContext context) {
    return variant == AppCardVariant.surface
        ? context.mp.surface
        : context.mp.surfaceRaised;
  }

  Border? _getDefaultBorder(BuildContext context) {
    return variant == AppCardVariant.surface
        ? Border.all(color: context.mp.borderSubtle)
        : Border.all(color: context.mp.borderDefault);
  }
}
