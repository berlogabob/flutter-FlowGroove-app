import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A customizable loading indicator widget.
///
/// This widget provides a consistent loading indicator that can be used
/// throughout the app with optional text message.
class LoadingIndicator extends StatelessWidget {
  /// The size of the loading spinner.
  final double size;

  /// The color of the loading spinner.
  final Color? color;

  /// An optional message to display below the spinner.
  final String? message;

  /// The style for the message text.
  final TextStyle? messageStyle;

  const LoadingIndicator({
    super.key,
    this.size = 40,
    this.color,
    this.message,
    this.messageStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                color ?? AppColors.color1,
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style:
                  messageStyle ??
                  const TextStyle(color: AppColors.color4, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// A small inline loading indicator for buttons and compact spaces.
class LoadingSpinner extends StatelessWidget {
  /// The size of the spinner.
  final double size;

  /// The color of the spinner.
  final Color? color;

  const LoadingSpinner({super.key, this.size = 16, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(color ?? Colors.white),
      ),
    );
  }
}
