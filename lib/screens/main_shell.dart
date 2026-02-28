import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/mono_pulse_theme.dart';

/// Main application shell with bottom navigation.
/// Works with StatefulShellRoute.indexedStack for proper tab switching.
class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
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
          selectedIndex: navigationShell.currentIndex,
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
    navigationShell.goBranch(index);
  }
}
