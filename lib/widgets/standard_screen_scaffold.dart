import 'package:flutter/material.dart';

import '../theme/mono_pulse_theme.dart';
import 'app_menu_sheet.dart';
import 'custom_app_bar.dart';
import 'menu_items_scope.dart';
import 'offline_indicator.dart';

/// Standard screen scaffold providing consistent layout across all screens.
///
/// Bottom-first navigation redesign:
/// - Top bar is a slim centered title only (no back arrow, no ⋮ menu).
/// - The screen's [title] and [menuItems] are published into
///   [MenuScopeRegistry] (via [MenuScopePublisher]) so the shell's bottom bar
///   can render them: on branch roots the Menu tab opens a sheet with these
///   items (plus a dot badge when items exist); on pushed branch children the
///   bar becomes `[← Back] [title] [⋮ Menu]`.
/// - Offline indicator banner behavior is unchanged.
///
/// Usage:
/// ```dart
/// StandardScreenScaffold(
///   title: 'Songs',
///   body: SingleChildScrollView(child: ...),
///   menuItems: [
///     AppMenuItem(icon: Icons.upload, label: 'Import', onTap: _import),
///   ],
///   floatingActionButton: FloatingActionButton(...),
/// )
/// ```
class StandardScreenScaffold extends StatelessWidget {

  const StandardScreenScaffold({
    required this.title,
    required this.body,
    super.key,
    this.showOfflineIndicator = true,
    this.showBackButton = true,
    this.menuItems,
    this.floatingActionButton,
  });
  /// Screen title displayed in the slim top bar and the bottom bar.
  final String title;

  /// Main body content of the screen.
  final Widget body;

  /// Contextual actions for the bottom bar's Menu sheet.
  final List<AppMenuItem>? menuItems;

  /// Optional floating action button.
  final Widget? floatingActionButton;

  /// Whether to show offline indicator banner.
  final bool showOfflineIndicator;

  /// Legacy knob from the top-bar era; the slim top bar never shows a back
  /// button (Back lives in the bottom bar). Kept so call sites don't churn.
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return MenuScopePublisher(
      data: MenuScopeData(title: title, items: menuItems ?? const []),
      child: Scaffold(
        backgroundColor: MonoPulseColors.black,
        appBar: CustomAppBar.build(context, title: title),
        body: Column(
          children: [
            if (showOfflineIndicator) const OfflineIndicator.banner(),
            Expanded(child: body),
          ],
        ),
        floatingActionButton: floatingActionButton,
      ),
    );
  }
}
