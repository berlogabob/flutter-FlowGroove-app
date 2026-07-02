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
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MonoPulseSpacing.sm,
              vertical: MonoPulseSpacing.sm,
            ),
            child: Row(
              children: [
                for (var i = 0; i < _navItems.length; i++)
                  Expanded(
                    child: _NavTab(
                      item: _navItems[i],
                      selected: i == safeIndex,
                      onTap: () => _onTap(context, i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRail(BuildContext context, int safeIndex) {
    return Container(
      width: 76,
      color: MonoPulseColors.blackSurface,
      // Scrollable so the five tabs never overflow on a short landscape height.
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: MonoPulseSpacing.lg),
        child: Column(
          children: [
            for (var i = 0; i < _navItems.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: MonoPulseSpacing.lg),
                child: _NavTab(
                  item: _navItems[i],
                  selected: i == safeIndex,
                  onTap: () => _onTap(context, i),
                ),
              ),
          ],
        ),
      ),
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

/// A single navigation tab (Mono Pulse): icon on top, label below. When
/// selected the icon + label turn orange and the label gets a rounded pill
/// background. Shared by the bottom bar (portrait) and the side rail
/// (landscape). Keeps a ≥48px tap target.
class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? MonoPulseColors.accentOrange
        : MonoPulseColors.textTertiary;

    final label = Text(
      item.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: MonoPulseTypography.labelSmall.copyWith(
        color: color,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? item.selectedIcon : item.icon, color: color, size: 22),
              const SizedBox(height: MonoPulseSpacing.xs),
              // Pill behind the label only when selected (per the doc's tab bar).
              DecoratedBox(
                decoration: BoxDecoration(
                  color: selected
                      ? MonoPulseColors.accentOrange15
                      : MonoPulseColors.transparent,
                  borderRadius: BorderRadius.circular(MonoPulseRadius.huge),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MonoPulseSpacing.sm,
                    vertical: MonoPulseSpacing.xxs,
                  ),
                  child: label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
