import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/mono_pulse_theme.dart';
import '../widgets/demo_mode_banner.dart';

/// One navigation destination, shared by the portrait [NavigationBar] and the
/// landscape [NavigationRail] (Mono Pulse: "nav moves to a side rail").
typedef _NavItem = ({IconData icon, IconData selectedIcon, String label});

const List<_NavItem> _navItems = [
  (icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
  (icon: Icons.music_note_outlined, selectedIcon: Icons.music_note, label: 'Songs'),
  (icon: Icons.groups_outlined, selectedIcon: Icons.groups, label: 'Bands'),
  (
    icon: Icons.queue_music_outlined,
    selectedIcon: Icons.queue_music,
    label: 'Setlists',
  ),
  (icon: Icons.person_outlined, selectedIcon: Icons.person, label: 'Profile'),
];

/// Main application shell with adaptive navigation.
/// Works with StatefulShellRoute.indexedStack for proper tab switching.
///
/// Features:
/// - Portrait: bottom navigation bar. Landscape: left navigation rail.
/// - Single tap: Navigate to tab or show next screen in branch
/// - Double tap: Navigate to root screen of each branch
class MainShell extends ConsumerStatefulWidget {

  const MainShell({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  DateTime? _lastTapTime;
  int? _lastTappedIndex;

  @override
  Widget build(BuildContext context) {
    // Clamp selectedIndex to prevent assertion errors when router has more
    // branches than bottom nav destinations (e.g., Tools branch).
    final currentIndex = widget.navigationShell.currentIndex;
    final safeIndex =
        currentIndex >= 0 && currentIndex < 5 ? currentIndex : 0;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final content = DemoModeBanner(child: widget.navigationShell);

    if (isLandscape) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              _buildRail(context, safeIndex),
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: MonoPulseColors.borderSubtle,
              ),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: content,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: MonoPulseColors.black,
          border: Border(
            top: BorderSide(color: MonoPulseColors.borderSubtle),
          ),
        ),
        child: NavigationBar(
          backgroundColor: MonoPulseColors.black,
          indicatorColor: MonoPulseColors.accentOrange10,
          selectedIndex: safeIndex,
          onDestinationSelected: (index) => _onTap(context, index),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final item in _navItems)
              NavigationDestination(
                icon: Icon(item.icon, color: MonoPulseColors.textTertiary),
                selectedIcon: Icon(
                  item.selectedIcon,
                  color: MonoPulseColors.accentOrange,
                ),
                label: item.label,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRail(BuildContext context, int safeIndex) {
    return NavigationRail(
      backgroundColor: MonoPulseColors.black,
      selectedIndex: safeIndex,
      onDestinationSelected: (index) => _onTap(context, index),
      labelType: NavigationRailLabelType.all,
      indicatorColor: MonoPulseColors.accentOrange10,
      selectedIconTheme: const IconThemeData(
        color: MonoPulseColors.accentOrange,
      ),
      unselectedIconTheme: const IconThemeData(
        color: MonoPulseColors.textTertiary,
      ),
      selectedLabelTextStyle: MonoPulseTypography.labelSmall.copyWith(
        color: MonoPulseColors.accentOrange,
      ),
      unselectedLabelTextStyle: MonoPulseTypography.labelSmall.copyWith(
        color: MonoPulseColors.textTertiary,
      ),
      destinations: [
        for (final item in _navItems)
          NavigationRailDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: Text(item.label),
          ),
      ],
    );
  }

  void _onTap(BuildContext context, int index) {
    final now = DateTime.now();

    // Check for double-tap on the same tab
    if (_lastTappedIndex == index &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < 300) {
      // Double-tap detected - navigate to root of branch
      _navigateToRootOfBranch(context, index);
      _lastTapTime = null;
      _lastTappedIndex = null;
      return;
    }

    // Single tap - normal navigation
    _lastTapTime = now;
    _lastTappedIndex = index;
    widget.navigationShell.goBranch(index);
  }

  /// Navigate to the root screen of the specified branch.
  /// Works on both web and mobile by directly navigating to the branch root URL.
  void _navigateToRootOfBranch(BuildContext context, int branchIndex) {
    // Direct URL navigation - most reliable for web
    // These URLs correspond to the root of each StatefulShellRoute branch
    switch (branchIndex) {
      case 0: // Home
        context.go('/main/home');
      case 1: // Songs
        context.go('/main/songs');
      case 2: // Bands
        context.go('/main/bands');
      case 3: // Setlists
        context.go('/main/setlists');
      case 4: // Profile
        context.go('/main/profile');
    }
  }
}
