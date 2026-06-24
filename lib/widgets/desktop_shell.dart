import 'package:flowgroove/screens/main_shell.dart' show MainShell;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth/auth_provider.dart';
import '../theme/mono_pulse_theme.dart';
import '../utils/responsive_breakpoints.dart';
import 'dashboard_welcome_widget.dart';

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

/// Resolves the Hugo help page as a sibling of the app's base href
/// (`<root>/app/` → `<root>/faq/`), so it works on any host without a hardcoded
/// URL. Pure so it can be tested without the real (web-only) [Uri.base].
String resolveDocsUrl(Uri appBase) => appBase.resolve('../faq/').toString();

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
          final mq = MediaQuery.of(context);
          return Row(
            children: [
              // Main app: a phone-width column that renders exactly like the
              // mobile app. MainShell/HomeScreen branch on MediaQuery (orientation
              // + width); on a wide window they'd read "landscape desktop" and
              // show the side-rail layout. Override the subtree's MediaQuery to a
              // portrait 480-wide phone so it matches the Mono Pulse phone screens.
              SizedBox(
                width: maxMainAppWidth,
                child: MediaQuery(
                  data: mq.copyWith(
                    size: Size(maxMainAppWidth, mq.size.height),
                  ),
                  child: child,
                ),
              ),
              // Sidebar divider
              Container(
                width: 1,
                height: double.infinity,
                color: MonoPulseColors.borderSubtle,
              ),
              // Docs panel - takes all remaining space
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
    final userAsync = ref.watch(appUserProvider);
    final userName = userAsync.value?.displayName ?? 'User';

    // Native sidebar + a link to the Hugo docs (single source of truth) opened
    // in a new tab. We deliberately do NOT embed an iframe: an HtmlElementView
    // platform view composites above Flutter's overlay on web, which froze the
    // app (dimmed dialogs, dead buttons, blank home).
    return ColoredBox(
      color: MonoPulseColors.surface,
      child: Column(
        children: [
          Expanded(child: DashboardWelcomeWidget.sidebar(userName: userName)),
          Padding(
            padding: const EdgeInsets.all(MonoPulseSpacing.lg),
            child: OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(resolveDocsUrl(Uri.base)),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Open Help & FAQ'),
            ),
          ),
        ],
      ),
    );
  }
}
