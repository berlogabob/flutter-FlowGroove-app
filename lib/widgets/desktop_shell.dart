import 'package:flowgroove/screens/main_shell.dart' show MainShell;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth/auth_provider.dart';
import '../theme/mono_pulse_theme.dart';
import '../utils/responsive_breakpoints.dart';
import 'dashboard_welcome_widget.dart';
import 'loading_indicator.dart';

/// Desktop shell wrapper that adds a sidebar with welcome widget on wide screens.
///
/// This widget wraps the main app shell ([MainShell]) and displays a sidebar
/// with welcome content only on desktop/wide screens (> 1024px).
///
/// Layout:
/// - Desktop: Main app (mobile phone width, centered) + Sidebar (all remaining space)
/// - Tablet/Mobile: Main app (100%)
///
/// Features:
/// - Main app preserves mobile phone dimensions and aspect ratio
/// - Main app always visible without scrolling (fixed mobile layout)
/// - Sidebar takes all free space on the right
/// - Navigation bars remain in main app only
///
/// Usage:
/// ```dart
/// DesktopShell(
///   child: MainShell(navigationShell: navigationShell),
/// )
/// ```
class DesktopShell extends ConsumerWidget {

  const DesktopShell({required this.child, super.key});
  /// The main app shell (typically [MainShell]).
  final Widget child;

  /// Maximum width for the main app area (mobile phone simulation).
  static const double maxMainAppWidth = 480;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final breakpoint = getBreakpoint(constraints.maxWidth);
        
        debugPrint('🖥️ DesktopShell: breakpoint=$breakpoint, width=${constraints.maxWidth.toStringAsFixed(0)}px');

        // Only show sidebar on desktop
        if (breakpoint == ScreenBreakpoint.desktop) {
          debugPrint('✅ DesktopShell: Showing sidebar (desktop mode)');
          return Row(
            children: [
              // Main app (preserves mobile phone layout) - centered
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: maxMainAppWidth,
                    ),
                    child: child,
                  ),
                ),
              ),
              // Sidebar divider
              Container(
                width: 1,
                height: double.infinity,
                color: MonoPulseColors.borderSubtle,
              ),
              // Welcome sidebar - takes all remaining space
              Expanded(
                child: _buildSidebar(context, ref),
              ),
            ],
          );
        }

        // Mobile/Tablet: just the main app (100% width)
        debugPrint('📱 DesktopShell: No sidebar (mobile/tablet mode)');
        return child;
      },
    );
  }

  Widget _buildSidebar(BuildContext context, WidgetRef ref) {
    debugPrint('📝 DesktopShell: Building welcome sidebar');
    // Get user name from auth provider
    final userAsync = ref.watch(appUserProvider);

    return ColoredBox(
      color: MonoPulseColors.surface,
      child: userAsync.when(
        data: (user) {
          final userName = user?.displayName ?? 'User';
          return DashboardWelcomeWidget.sidebar(userName: userName);
        },
        loading: () => const Center(child: LoadingIndicator()),
        error: (_, _) => DashboardWelcomeWidget.sidebar(userName: 'User'),
      ),
    );
  }
}
