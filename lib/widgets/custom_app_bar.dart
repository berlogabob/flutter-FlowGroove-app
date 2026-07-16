import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/mono_pulse_theme.dart';
import 'app_menu_sheet.dart';

/// Slim top app bar: centered title only (bottom-first navigation redesign).
///
/// Back and the `⋮` contextual menu moved to the bottom bar (`AppBottomBar`):
/// pushed screens get `[← Back] [title] [⋮ Menu]` from the shell (branch
/// children) or from their own scaffold (root-pushed tools), and branch roots
/// get the tab bar with the Menu slot. The top bar's only job now is naming
/// the screen.
///
/// Exception: screens pushed imperatively via `Navigator.push` (Performance
/// Sheet, Song Editor, AI access) live outside go_router, so the shell's
/// bottom bar can't serve them — they pass `onBack` (and optionally
/// `menuItems`) to keep a working back/menu in the top bar until they are
/// migrated to routes.
class CustomAppBar {
  CustomAppBar._();

  /// Builds the slim app bar.
  ///
  /// [title] - centered title text
  /// [actions] - extra action widgets (right side)
  /// [onBack] - ONLY for imperatively-pushed screens (see class doc); renders
  ///   the circular back button. Router-routed screens must leave this null —
  ///   the bottom bar owns Back.
  /// [menuItems] - ONLY for imperatively-pushed screens; renders a `⋮` that
  ///   opens the app menu sheet.
  /// [isTool] - tool screens use titleLarge typography
  static PreferredSizeWidget build(
    BuildContext context, {
    required String title,
    bool isTool = false,
    List<Widget>? actions,
    VoidCallback? onBack,
    List<AppMenuItem>? menuItems,
  }) {
    return AppBar(
      backgroundColor: MonoPulseColors.black,
      foregroundColor: MonoPulseColors.textPrimary,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      automaticallyImplyLeading: false,
      leading: onBack != null ? _backButton(onBack) : null,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style:
            (isTool
                    ? MonoPulseTypography.titleLarge
                    : MonoPulseTypography.headlineSmall)
                .copyWith(
                  color: MonoPulseColors.textHighEmphasis,
                  fontWeight: FontWeight.w700,
                ),
      ),
      centerTitle: true,
      actions: [
        ...?actions,
        if (menuItems?.isNotEmpty ?? false)
          _menuButton(context, title, menuItems!),
        const SizedBox(width: MonoPulseSpacing.md),
      ],
    );
  }

  static Widget _menuButton(
    BuildContext context,
    String title,
    List<AppMenuItem> menuItems,
  ) {
    return Semantics(
      button: true,
      label: 'Menu',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          showAppMenuSheet(context, title: title, items: menuItems);
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
                border: Border.all(color: MonoPulseColors.borderSubtle),
              ),
              child: const Icon(
                Icons.more_horiz,
                color: MonoPulseColors.textSecondary,
                size: MonoPulseIcons.sizeLarge,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _backButton(VoidCallback onBack) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onBack();
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
