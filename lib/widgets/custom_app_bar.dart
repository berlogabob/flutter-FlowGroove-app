import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/mono_pulse_theme.dart';

/// Custom AppBar with consistent back button and menu across all screens.
///
/// Features:
/// - Circular back button with border (consistent with Mono Pulse design)
/// - Three dots menu button for screen-specific actions
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
  /// [menuItems] - Screen-specific menu items
  /// [actions] - Extra action widgets shown before the menu button
  /// [onBack] - Custom back action (optional, defaults to Navigator.pop)
  /// [isTool] - Whether this is a tool screen (uses titleLarge typography)
  static PreferredSizeWidget build(
    BuildContext context, {
    required String title,
    bool isTool = false,
    List<PopupMenuEntry<dynamic>>? menuItems,
    List<Widget>? actions,
    VoidCallback? onBack,
  }) {
    return AppBar(
      backgroundColor: MonoPulseColors.black,
      foregroundColor: MonoPulseColors.textPrimary,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: _backButton(context, onBack),
      title: Text(
        title,
        style:
            (isTool
                    ? MonoPulseTypography.titleLarge
                    : MonoPulseTypography.headlineLarge)
                .copyWith(
                  color: MonoPulseColors.textHighEmphasis,
                  fontWeight: FontWeight.w700,
                ),
      ),
      centerTitle: true,
      actions: [
        ...?actions,
        if (menuItems?.isNotEmpty ?? false) _menuButton(menuItems!),
        const SizedBox(width: MonoPulseSpacing.md),
      ],
    );
  }

  /// Builds a custom AppBar with only a back button.
  static PreferredSizeWidget buildSimple(
    BuildContext context, {
    required String title,
    VoidCallback? onBack,
  }) => build(context, title: title, onBack: onBack);

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
      leading: const SizedBox(width: MonoPulseSpacing.massive), // Empty space for alignment (48px)
      title: Text(
        title,
        style: MonoPulseTypography.headlineLarge.copyWith(
          color: MonoPulseColors.textHighEmphasis,
          fontWeight: FontWeight.w700,
        ),
      ),
      centerTitle: true,
      actions: [
        if (menuItems?.isNotEmpty ?? false) _menuButton(menuItems!),
        const SizedBox(width: MonoPulseSpacing.md),
      ],
    );
  }

  static Widget _menuButton(List<PopupMenuEntry<dynamic>> menuItems) {
    return GestureDetector(
      onTap: HapticFeedback.lightImpact,
      // minTapTarget touch zone
      child: SizedBox(
        width: MonoPulseSpacing.massive, // 48px
        height: MonoPulseSpacing.massive,
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: MonoPulseColors.borderSubtle),
            ),
            child: PopupMenuButton<void>(
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.more_horiz,
                color: MonoPulseColors.textSecondary,
                size: MonoPulseIcons.sizeLarge,
              ),
              itemBuilder: (_) => menuItems,
            ),
          ),
        ),
      ),
    );
  }

  static Widget _backButton(BuildContext context, VoidCallback? onBack) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (onBack != null) {
          onBack();
        } else if (context.canPop()) {
          // Screen was push()ed via go_router — pop it. This covers
          // Metronome/Tuner/Join Band too: they're pushed on the root
          // navigator on top of the shell, so there's a shell screen
          // underneath to return to.
          context.pop();
        } else if (Navigator.of(context).canPop()) {
          // Screen was pushed imperatively (e.g. AI access via Navigator.push);
          // go_router's pop can't see it, so pop the Navigator directly.
          Navigator.of(context).pop();
        } else {
          // Reached via go()/goNamed() which replaced the stack (e.g. a
          // deep-link cold start landing directly on Join Band) — nothing to
          // pop, so fall back home instead of a dead button.
          context.go('/main/home');
        }
      },
      // minTapTarget touch zone
      child: SizedBox(
        width: MonoPulseSpacing.massive, // 48px
        height: MonoPulseSpacing.massive,
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: MonoPulseColors.textSecondary,
                width: MonoPulseBorder.default_,
              ),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: MonoPulseColors.textSecondary,
              size: MonoPulseIcons.sizeMedium,
              semanticLabel: 'Back',
            ),
          ),
        ),
      ),
    );
  }
}
