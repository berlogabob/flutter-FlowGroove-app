import 'package:flutter/material.dart';
import '../theme/mono_pulse_theme.dart';

/// A customizable loading indicator widget.
///
/// This widget provides a consistent loading indicator that can be used
/// throughout the app with optional text message.
///
/// Includes semantic label for screen readers.
class LoadingIndicator extends StatelessWidget {

  const LoadingIndicator({
    super.key,
    this.size = 40,
    this.semanticsLabel = 'Loading',
    this.color,
    this.message,
    this.messageStyle,
  });
  /// The size of the loading spinner.
  final double size;

  /// The color of the loading spinner.
  final Color? color;

  /// An optional message to display below the spinner.
  final String? message;

  /// The style for the message text.
  final TextStyle? messageStyle;

  /// Semantic label for screen readers. Defaults to 'Loading'.
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      enabled: true,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  color ?? MonoPulseColors.accentOrange,
                ),
                semanticsLabel: semanticsLabel,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: MonoPulseSpacing.lg),
              Text(
                message!,
                style: messageStyle ?? MonoPulseTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A small inline loading indicator for buttons and compact spaces.
class LoadingSpinner extends StatelessWidget {

  const LoadingSpinner({super.key, this.size = 16, this.color});
  /// The size of the spinner.
  final double size;

  /// The color of the spinner.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? MonoPulseColors.accentOrange,
        ),
      ),
    );
  }
}
