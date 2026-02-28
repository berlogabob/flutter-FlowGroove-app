import 'package:flutter/material.dart';
import 'custom_app_bar.dart';
import 'offline_indicator.dart';
import '../theme/mono_pulse_theme.dart';

/// Standard screen scaffold providing consistent layout across all screens.
///
/// Features:
/// - CustomAppBar with optional back button and menu
/// - Offline indicator banner (optional)
/// - Consistent background color (MonoPulseColors.black)
/// - SafeArea handling
///
/// Usage:
/// ```dart
/// StandardScreenScaffold(
///   title: 'Songs',
///   body: SingleChildScrollView(child: ...),
///   menuItems: [
///     PopupMenuItem(child: Text('Import'), onTap: _import),
///   ],
///   floatingActionButton: FloatingActionButton(...),
///   showBackButton: false, // Hide back button for main tabs
/// )
/// ```
class StandardScreenScaffold extends StatelessWidget {
  /// Screen title displayed in AppBar.
  final String title;

  /// Main body content of the screen.
  final Widget body;

  /// Optional menu items for three-dots menu.
  final List<PopupMenuItem<void>>? menuItems;

  /// Optional floating action button.
  final Widget? floatingActionButton;

  /// Whether to show offline indicator banner.
  final bool showOfflineIndicator;

  /// Whether to show back button in AppBar.
  final bool showBackButton;

  const StandardScreenScaffold({
    super.key,
    required this.title,
    required this.body,
    this.menuItems,
    this.floatingActionButton,
    this.showOfflineIndicator = true,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MonoPulseColors.black,
      appBar: showBackButton
          ? CustomAppBar.build(context, title: title, menuItems: menuItems)
          : CustomAppBar.buildNoBack(
              context,
              title: title,
              menuItems: menuItems,
            ),
      body: Column(
        children: [
          if (showOfflineIndicator) const OfflineIndicator.banner(),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
