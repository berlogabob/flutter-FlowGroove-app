import 'package:flutter/material.dart';

/// A widget for displaying error messages to the user.
///
/// This widget provides a consistent error banner that can be used
/// throughout the app to display error messages with an optional retry action.
class ErrorBanner extends StatelessWidget {
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

  const ErrorBanner({
    super.key,
    required this.message,
    this.title,
    this.onRetry,
    this.showRetry = false,
    this.style = ErrorBannerStyle.banner,
  });

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

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700, size: 24),
              const SizedBox(width: 12),
              if (title != null) ...[
                Text(
                  title!,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.red.shade900),
          ),
          if (showRetry && onRetry != null) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 48),
            const SizedBox(height: 16),
            if (title != null)
              Text(
                title!,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                  fontSize: 16,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Colors.red.shade900),
              textAlign: TextAlign.center,
            ),
            if (showRetry && onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInline() {
    return Row(
      children: [
        Icon(Icons.error, color: Colors.red.shade700, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: Colors.red.shade700, fontSize: 13),
          ),
        ),
        if (showRetry && onRetry != null)
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
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
