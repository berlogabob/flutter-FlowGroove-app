import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/mono_pulse_theme.dart';

/// Custom AppBar with consistent back button and menu across all screens.
///
/// Features:
/// - Circular back button with border (consistent with Mono Pulse design)
/// - Three dots menu button
/// - Haptic feedback on tap
/// - 48px minimum touch zones
///
/// Usage:
/// ```dart
/// appBar: CustomAppBar.build(
///   context,
///   title: 'Songs',
///   menuItems: [
///     PopupMenuItem(child: Text('Import'), onTap: _handleImport),
///     PopupMenuItem(child: Text('Export'), onTap: _handleExport),
///   ],
/// ),
/// ```
class CustomAppBar {
  CustomAppBar._();

  /// Builds a custom AppBar with back button and menu.
  ///
  /// [context] - Build context for navigation
  /// [title] - AppBar title text
  /// [menuItems] - List of menu items (optional)
  /// [onBack] - Custom back action (optional, defaults to Navigator.pop)
  /// [isTool] - Whether this is a tool screen (uses titleLarge typography)
  static PreferredSizeWidget build(
    BuildContext context, {
    required String title,
    List<PopupMenuEntry<dynamic>>? menuItems,
    VoidCallback? onBack,
    bool isTool = false,
  }) {
    return AppBar(
      backgroundColor: MonoPulseColors.black,
      foregroundColor: MonoPulseColors.textPrimary,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          if (onBack != null) {
            onBack();
          } else {
            // For StatefulShellRoute (Metronome/Tuner), always go home
            // For normal routes, use pop
            final currentRoute = GoRouterState.of(context).uri.path;
            if (currentRoute.startsWith('/main/metronome') ||
                currentRoute.startsWith('/main/tuner')) {
              context.go('/main/home');
            } else {
              context.pop();
            }
          }
        },
        // 48px minimum touch zone
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: MonoPulseColors.textSecondary,
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: MonoPulseColors.textSecondary,
                size: 20,
              ),
            ),
          ),
        ),
      ),
      title: Text(
        title,
        style:
            (isTool
                    ? MonoPulseTypography.titleLarge
                    : MonoPulseTypography.headlineLarge)
                .copyWith(
                  color: MonoPulseColors.textHighEmphasis,
                  fontWeight: FontWeight.bold,
                ),
      ),
      centerTitle: true,
      actions: menuItems != null
          ? [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  // Menu will be shown by PopupMenuButton
                },
                // 48px minimum touch zone
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: MonoPulseColors.borderSubtle,
                          width: 1,
                        ),
                      ),
                      child: PopupMenuButton<void>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.more_horiz,
                          color: MonoPulseColors.textSecondary,
                          size: 22,
                        ),
                        itemBuilder: (context) => menuItems,
                        onSelected: (value) {},
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: MonoPulseSpacing.md),
            ]
          : [const SizedBox(width: MonoPulseSpacing.md)],
    );
  }

  /// Builds a simple custom AppBar with only back button (no menu).
  ///
  /// Use this for screens that don't need a menu.
  static PreferredSizeWidget buildSimple(
    BuildContext context, {
    required String title,
    VoidCallback? onBack,
  }) {
    return AppBar(
      backgroundColor: MonoPulseColors.black,
      foregroundColor: MonoPulseColors.textPrimary,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          if (onBack != null) {
            onBack();
          } else {
            // For StatefulShellRoute (Metronome/Tuner), always go home
            // For normal routes, use pop
            final currentRoute = GoRouterState.of(context).uri.path;
            if (currentRoute.startsWith('/main/metronome') ||
                currentRoute.startsWith('/main/tuner')) {
              context.go('/main/home');
            } else {
              context.pop();
            }
          }
        },
        // 48px minimum touch zone
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: MonoPulseColors.textSecondary,
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: MonoPulseColors.textSecondary,
                size: 20,
              ),
            ),
          ),
        ),
      ),
      title: Text(
        title,
        style: MonoPulseTypography.headlineLarge.copyWith(
          color: MonoPulseColors.textHighEmphasis,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
    );
  }

  /// Builds a custom AppBar without back button (for main shell tabs).
  ///
  /// Use this for screens that are part of the bottom navigation
  /// and should not have a back button.
  static PreferredSizeWidget buildNoBack(
    BuildContext context, {
    required String title,
    List<PopupMenuEntry<dynamic>>? menuItems,
  }) {
    return AppBar(
      backgroundColor: MonoPulseColors.black,
      foregroundColor: MonoPulseColors.textPrimary,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: const SizedBox(width: 48), // Empty space for alignment
      title: Text(
        title,
        style: MonoPulseTypography.headlineLarge.copyWith(
          color: MonoPulseColors.textHighEmphasis,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: menuItems != null
          ? [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                },
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: MonoPulseColors.textSecondary,
                          width: 1.5,
                        ),
                      ),
                      child: PopupMenuButton<void>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.more_horiz,
                          color: MonoPulseColors.textSecondary,
                          size: 22,
                        ),
                        itemBuilder: (context) => menuItems,
                        onSelected: (value) {},
                      ),
                    ),
                  ),
                ),
              ),
            ]
          : null,
    );
  }
}
