import 'package:flutter/material.dart';
import '../../theme/mono_pulse_theme.dart';

/// Error Banner Widget - Displays error messages to users
///
/// Three variants:
/// - banner: Full-width banner at top of screen
/// - card: Card-style error display
/// - inline: Small inline error with icon
class ErrorBanner extends StatelessWidget {
  const ErrorBanner.banner({super.key, required this.message, this.onRetry})
    : variant = ErrorBannerVariant.banner;

  const ErrorBanner.card({super.key, required this.message, this.onRetry})
    : variant = ErrorBannerVariant.card;

  const ErrorBanner.inline({super.key, required this.message, this.onRetry})
    : variant = ErrorBannerVariant.inline;

  final String message;
  final VoidCallback? onRetry;
  final ErrorBannerVariant variant;

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case ErrorBannerVariant.banner:
        return _buildBanner(context);
      case ErrorBannerVariant.card:
        return _buildCard(context);
      case ErrorBannerVariant.inline:
        return _buildInline(context);
    }
  }

  Widget _buildBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MonoPulseSpacing.lg),
      decoration: BoxDecoration(
        color: MonoPulseColors.error10,
        border: Border.all(color: MonoPulseColors.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: MonoPulseColors.error,
                size: MonoPulseIcons.sizeLarge,
              ),
              SizedBox(width: MonoPulseSpacing.md),
              Expanded(
                child: Text(
                  message,
                  style: MonoPulseTypography.labelLarge.copyWith(
                    color: MonoPulseColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            SizedBox(height: MonoPulseSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MonoPulseColors.error,
                  foregroundColor: MonoPulseColors.textPrimary,
                  padding: EdgeInsets.symmetric(vertical: MonoPulseSpacing.sm),
                ),
                child: const Text('Retry'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Card(
      color: MonoPulseColors.error10,
      margin: const EdgeInsets.all(MonoPulseSpacing.lg),
      child: Padding(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              color: MonoPulseColors.error,
              size: MonoPulseIcons.sizeXLarge,
            ),
            SizedBox(height: MonoPulseSpacing.lg),
            Text(
              message,
              style: MonoPulseTypography.bodyMedium.copyWith(
                color: MonoPulseColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              SizedBox(height: MonoPulseSpacing.lg),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MonoPulseColors.error,
                  foregroundColor: MonoPulseColors.textPrimary,
                ),
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInline(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.error, color: MonoPulseColors.error, size: MonoPulseIcons.sizeMedium),
        SizedBox(width: MonoPulseSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: MonoPulseTypography.bodySmall.copyWith(
              color: MonoPulseColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

enum ErrorBannerVariant { banner, card, inline }
