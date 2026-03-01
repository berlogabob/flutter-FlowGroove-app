import 'package:flutter/material.dart';
import '../../theme/mono_pulse_theme.dart';

/// Error Banner Widget - Displays error messages to users
///
/// Three variants:
/// - banner: Full-width banner at top of screen
/// - card: Card-style error display
/// - inline: Small inline error with icon
class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final ErrorBannerVariant variant;

  const ErrorBanner.banner({super.key, required this.message, this.onRetry})
    : variant = ErrorBannerVariant.banner;

  const ErrorBanner.card({super.key, required this.message, this.onRetry})
    : variant = ErrorBannerVariant.card;

  const ErrorBanner.inline({super.key, required this.message, this.onRetry})
    : variant = ErrorBannerVariant.inline;

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MonoPulseColors.errorSubtle,
        border: Border.all(color: MonoPulseColors.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: MonoPulseColors.error,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: MonoPulseColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MonoPulseColors.error,
                  foregroundColor: MonoPulseColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 8),
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
      color: MonoPulseColors.errorSubtle,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              color: MonoPulseColors.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: MonoPulseColors.textPrimary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
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
        const Icon(Icons.error, color: MonoPulseColors.error, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: MonoPulseColors.textPrimary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

enum ErrorBannerVariant { banner, card, inline }
