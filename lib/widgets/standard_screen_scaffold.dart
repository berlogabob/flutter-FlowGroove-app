import 'package:flutter/material.dart';

import '../theme/mono_pulse_theme.dart';
import 'app_menu_sheet.dart';
import 'menu_items_scope.dart';
import 'offline_indicator.dart';

/// Standard screen scaffold providing consistent layout across all screens.
///
/// Bottom-first navigation redesign:
/// - No top app bar at all. Root screens show no title anywhere — the
///   selected bottom tab label is the location signal. Pushed screens get
///   their title from the shell's bottom bar.
/// - The screen's [title] and [menuItems] are published into
///   [MenuScopeRegistry] (via [MenuScopePublisher]) so the shell's bottom bar
///   can render them: on branch roots the Menu tab opens a sheet with these
///   items (plus a dot badge when items exist); on pushed branch children the
///   bar becomes `[← Back] [title] [⋮ Menu]`.
/// - Offline indicator banner behavior is unchanged. The body is wrapped in
///   `SafeArea(bottom: false)` to clear the status bar now that the app bar
///   (which used to absorb that inset) is gone.
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
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (showOfflineIndicator) const OfflineIndicator.banner(),
              Expanded(child: body),
            ],
          ),
        ),
        floatingActionButton: floatingActionButton,
      ),
    );
  }
}
