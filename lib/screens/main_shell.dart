import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/mono_pulse_theme.dart';
import 'home_screen.dart';
import 'songs/songs_list_screen.dart';
import 'bands/my_bands_screen.dart';
import 'setlists/setlists_list_screen.dart';
import 'profile_screen.dart';

/// Provider to track the current bottom navigation index.
final bottomNavIndexProvider = NotifierProvider<BottomNavNotifier, int>(() {
  return BottomNavNotifier();
});

class BottomNavNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    state = index;
  }

  void reset() {
    state = 0;
  }
}

/// Main application shell with bottom navigation.
///
/// Uses IndexedStack to preserve state of each tab.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    SongsListScreen(),
    MyBandsScreen(),
    SetlistsListScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _screens),
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
            selectedIndex: _currentIndex,
            onDestinationSelected: _onDestinationSelected,
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            destinations: [
              _buildDestination(Icons.home_outlined, Icons.home, 'Home', 0),
              _buildDestination(
                Icons.music_note_outlined,
                Icons.music_note,
                'Songs',
                1,
              ),
              _buildDestination(
                Icons.groups_outlined,
                Icons.groups,
                'Bands',
                2,
              ),
              _buildDestination(
                Icons.queue_music_outlined,
                Icons.queue_music,
                'Setlists',
                3,
              ),
              _buildDestination(
                Icons.person_outlined,
                Icons.person,
                'Profile',
                4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  NavigationDestination _buildDestination(
    IconData icon,
    IconData selectedIcon,
    String label,
    int index,
  ) {
    final isSelected = _currentIndex == index;
    return NavigationDestination(
      icon: Icon(
        icon,
        color: isSelected
            ? MonoPulseColors.accentOrange
            : MonoPulseColors.textTertiary,
      ),
      selectedIcon: Icon(selectedIcon, color: MonoPulseColors.accentOrange),
      label: label,
    );
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
    ref.read(bottomNavIndexProvider.notifier).setIndex(index);
  }
}
