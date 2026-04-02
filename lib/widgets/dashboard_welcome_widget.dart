import 'package:flutter/material.dart';
import '../theme/mono_pulse_theme.dart';
import '../utils/responsive_breakpoints.dart';

/// Welcome widget for dashboard empty states, especially on desktop.
///
/// Displays a welcoming message with tips or quick start suggestions
/// when the dashboard has empty space (typically on desktop layouts).
///
/// Features:
/// - Responsive design adapts to available space
/// - Optional user personalization
/// - Configurable quick tips list
/// - Optional call-to-action button
/// - Consistent Mono Pulse branding
///
/// Usage:
/// ```dart
/// // Default welcome widget
/// DashboardWelcomeWidget.defaultWelcome(userName: 'John')
///
/// // Custom welcome widget
/// DashboardWelcomeWidget(
///   userName: 'John',
///   message: 'Welcome to your music management hub',
///   quickTips: [
///     'Add your first song to get started',
///     'Create a band to organize rehearsals',
///     'Use the tuner tool for quick tuning',
///   ],
///   onGetStarted: () => context.goNamed('add-song'),
/// )
/// ```
class DashboardWelcomeWidget extends StatelessWidget {
  /// User name for personalized greeting (optional).
  final String? userName;

  /// Custom welcome message (optional).
  final String? message;

  /// List of quick tips to display (optional).
  final List<String> quickTips;

  /// Callback for "Get Started" button (optional).
  final VoidCallback? onGetStarted;

  const DashboardWelcomeWidget({
    super.key,
    this.userName,
    this.message,
    this.quickTips = const [],
    this.onGetStarted,
  });

  /// Default welcome widget with Mono Pulse branding.
  factory DashboardWelcomeWidget.defaultWelcome({String? userName}) {
    return DashboardWelcomeWidget(
      userName: userName,
      message: 'Welcome to your music management hub',
      quickTips: const [
        'Add your first song to get started',
        'Create a band to organize rehearsals',
        'Use the tuner tool for quick tuning',
      ],
    );
  }

  /// Sidebar welcome widget optimized for desktop sidebar layout.
  ///
  /// Compact version designed for narrow sidebar display on desktop.
  /// Features:
  /// - Smaller icon size (48px)
  /// - Compact typography
  /// - Optimized spacing for sidebar context
  factory DashboardWelcomeWidget.sidebar({String? userName}) {
    return DashboardWelcomeWidget(
      userName: userName,
      message: 'Your music management hub',
      quickTips: const [
        'Add your first song to get started',
        'Create a band to organize rehearsals',
        'Use the tuner tool for quick tuning',
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final breakpoint = context.breakpoint;
    final isSidebar = breakpoint == ScreenBreakpoint.desktop;
    final greeting = userName != null && userName!.isNotEmpty
        ? 'Welcome back, $userName!'
        : 'Welcome!';

    return SingleChildScrollView(
      padding: EdgeInsets.all(
        isSidebar ? MonoPulseSpacing.lg : MonoPulseSpacing.xl,
      ),
      child: IntrinsicHeight(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome icon
            Icon(
              Icons.music_note_rounded,
              size: isSidebar ? 48 : 64,
              color: MonoPulseColors.accentOrange,
            ),
            SizedBox(height: MonoPulseSpacing.md),

            // Greeting
            Text(
              greeting,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: MonoPulseColors.textPrimary,
                fontSize: isSidebar ? 20 : 24,
                height: 1.2,
              ),
            ),
            SizedBox(height: MonoPulseSpacing.sm),

            // Welcome message
            if (message != null && message!.isNotEmpty)
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MonoPulseColors.textSecondary,
                  fontSize: isSidebar ? 14 : 16,
                  height: 1.4,
                ),
              ),

            if (quickTips.isNotEmpty) ...[
              SizedBox(height: MonoPulseSpacing.lg),

              // Tips section
              Text(
                'Quick Tips:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: MonoPulseColors.textPrimary,
                  fontSize: isSidebar ? 13 : 14,
                ),
              ),
              SizedBox(height: MonoPulseSpacing.sm),

              // Tips list
              ...quickTips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: MonoPulseSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: MonoPulseColors.accentOrange,
                    ),
                    SizedBox(width: MonoPulseSpacing.sm),
                    Expanded(
                      child: Text(
                        tip,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: MonoPulseColors.textTertiary,
                          fontSize: isSidebar ? 13 : 14,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],

            // Get started button
            if (onGetStarted != null) ...[
              SizedBox(height: MonoPulseSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onGetStarted,
                  icon: const Icon(Icons.add),
                  label: Text(
                    isSidebar ? 'Get Started' : 'Get Started',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MonoPulseColors.accentOrange,
                    foregroundColor: MonoPulseColors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: MonoPulseSpacing.sm,
                      horizontal: MonoPulseSpacing.lg,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
