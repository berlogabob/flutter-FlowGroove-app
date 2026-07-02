import 'package:flutter/material.dart';

import '../theme/mono_pulse_theme.dart';

/// A widget for displaying error messages to the user.
///
/// This widget provides a consistent error banner that can be used
/// throughout the app to display error messages with an optional retry action.
/// Styled with MonoPulse tokens so it reads correctly on the dark-only theme.
class ErrorBanner extends StatelessWidget {

  const ErrorBanner({
    required this.message,
    this.title,
    this.onRetry,
    this.showRetry = false,
    this.style = ErrorBannerStyle.banner,
    super.key,
  });
  /// The error message to display.
  final String message;

  /// An optional title for the error.
  final String? title;

  /// Callback when the retry button is pressed.
  final VoidCallback? onRetry;

  /// Whether to show the retry button.
  final bool showRetry;

  /// The style of the error banner.
  final ErrorBannerStyle style;

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case ErrorBannerStyle.banner:
        return _buildBanner();
      case ErrorBannerStyle.card:
        return _buildCard();
      case ErrorBannerStyle.inline:
        return _buildInline();
    }
  }

  Widget _retryButton() {
    return ElevatedButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh, size: 16),
      label: const Text('Retry'),
      style: ElevatedButton.styleFrom(
        backgroundColor: MonoPulseColors.error,
        foregroundColor: MonoPulseColors.white,
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MonoPulseSpacing.lg),
      decoration: BoxDecoration(
        color: MonoPulseColors.error10,
        borderRadius: BorderRadius.circular(MonoPulseRadius.small),
        border: Border.all(color: MonoPulseColors.error30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline,
                  color: MonoPulseColors.error, size: 24),
              const SizedBox(width: MonoPulseSpacing.md),
              if (title != null) ...[
                Text(
                  title!,
                  style: MonoPulseTypography.titleMedium
                      .copyWith(color: MonoPulseColors.error),
                ),
                const SizedBox(width: MonoPulseSpacing.sm),
              ],
            ],
          ),
          const SizedBox(height: MonoPulseSpacing.sm),
          Text(
            message,
            style: MonoPulseTypography.bodyMedium
                .copyWith(color: MonoPulseColors.textPrimary),
          ),
          if (showRetry && onRetry != null) ...[
            const SizedBox(height: MonoPulseSpacing.md),
            _retryButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Card(
      color: MonoPulseColors.error10,
      child: Padding(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        child: Column(
          children: [
            const Icon(Icons.error_outline,
                color: MonoPulseColors.error, size: 48),
            const SizedBox(height: MonoPulseSpacing.lg),
            if (title != null)
              Text(
                title!,
                style: MonoPulseTypography.headlineSmall
                    .copyWith(color: MonoPulseColors.error),
              ),
            const SizedBox(height: MonoPulseSpacing.sm),
            Text(
              message,
              style: MonoPulseTypography.bodyMedium
                  .copyWith(color: MonoPulseColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            if (showRetry && onRetry != null) ...[
              const SizedBox(height: MonoPulseSpacing.lg),
              _retryButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInline() {
    return Row(
      children: [
        const Icon(Icons.error, color: MonoPulseColors.error, size: 20),
        const SizedBox(width: MonoPulseSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: MonoPulseTypography.bodySmall
                .copyWith(color: MonoPulseColors.error),
          ),
        ),
        if (showRetry && onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

/// Error banner display styles.
enum ErrorBannerStyle {
  /// Full-width banner style.
  banner,

  /// Card style with centered content.
  card,

  /// Compact inline style.
  inline,
}
