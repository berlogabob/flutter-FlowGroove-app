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

  @override
  Widget build(BuildContext context) {
    final breakpoint = context.breakpoint;
    final greeting = userName != null && userName!.isNotEmpty
        ? 'Welcome back, $userName!'
        : 'Welcome!';

    return Container(
      padding: EdgeInsets.all(
        breakpoint == ScreenBreakpoint.desktop
            ? MonoPulseSpacing.xl
            : MonoPulseSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MonoPulseColors.surface,
            MonoPulseColors.surfaceRaised,
          ],
        ),
        borderRadius: BorderRadius.circular(MonoPulseRadius.large),
        border: Border.all(color: MonoPulseColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Welcome icon
          Icon(
            Icons.music_note_rounded,
            size: breakpoint == ScreenBreakpoint.desktop ? 64 : 48,
            color: MonoPulseColors.accentOrange,
          ),
          SizedBox(height: MonoPulseSpacing.md),

          // Greeting
          Text(
            greeting,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: MonoPulseColors.textPrimary,
              fontSize: breakpoint == ScreenBreakpoint.desktop ? 24 : 20,
              height: 1.2,
            ),
          ),
          SizedBox(height: MonoPulseSpacing.sm),

          // Welcome message
          if (message != null && message!.isNotEmpty)
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: MonoPulseColors.textSecondary,
                fontSize: breakpoint == ScreenBreakpoint.desktop ? 16 : 14,
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
                fontSize: breakpoint == ScreenBreakpoint.desktop ? 14 : 13,
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: MonoPulseColors.textTertiary,
                        fontSize: breakpoint == ScreenBreakpoint.desktop ? 14 : 13,
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
                  breakpoint == ScreenBreakpoint.desktop
                      ? 'Get Started'
                      : 'Start',
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
    );
  }
}
