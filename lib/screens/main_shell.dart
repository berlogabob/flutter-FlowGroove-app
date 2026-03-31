import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/mono_pulse_theme.dart';

/// Main application shell with bottom navigation.
/// Works with StatefulShellRoute.indexedStack for proper tab switching.
///
/// Features:
/// - Single tap: Navigate to tab or show next screen in branch
/// - Double tap: Navigate to root screen of each branch
class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  DateTime? _lastTapTime;
  int? _lastTappedIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: MonoPulseColors.black,
          border: Border(
            top: BorderSide(color: MonoPulseColors.borderSubtle, width: 1),
          ),
        ),
        child: NavigationBar(
          backgroundColor: MonoPulseColors.black,
          indicatorColor: MonoPulseColors.accentOrangeSubtle,
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: (index) => _onTap(context, index),
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: const [
            NavigationDestination(
              icon: Icon(
                Icons.home_outlined,
                color: MonoPulseColors.textTertiary,
              ),
              selectedIcon: Icon(
                Icons.home,
                color: MonoPulseColors.accentOrange,
              ),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.music_note_outlined,
                color: MonoPulseColors.textTertiary,
              ),
              selectedIcon: Icon(
                Icons.music_note,
                color: MonoPulseColors.accentOrange,
              ),
              label: 'Songs',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.groups_outlined,
                color: MonoPulseColors.textTertiary,
              ),
              selectedIcon: Icon(
                Icons.groups,
                color: MonoPulseColors.accentOrange,
              ),
              label: 'Bands',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.queue_music_outlined,
                color: MonoPulseColors.textTertiary,
              ),
              selectedIcon: Icon(
                Icons.queue_music,
                color: MonoPulseColors.accentOrange,
              ),
              label: 'Setlists',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.person_outlined,
                color: MonoPulseColors.textTertiary,
              ),
              selectedIcon: Icon(
                Icons.person,
                color: MonoPulseColors.accentOrange,
              ),
              label: 'Profile',
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
        break;
      case 1: // Songs
        context.go('/main/songs');
        break;
      case 2: // Bands
        context.go('/main/bands');
        break;
      case 3: // Setlists
        context.go('/main/setlists');
        break;
      case 4: // Profile
        context.go('/main/profile');
        break;
    }
  }
}
