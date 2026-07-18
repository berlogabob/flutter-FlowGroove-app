import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../router/branch_stack_observer.dart';
import '../theme/mono_pulse_theme.dart';
import '../widgets/app_menu_sheet.dart';
import '../widgets/bottom_nav_or_action_bar.dart';
import '../widgets/demo_mode_banner.dart';
import '../widgets/menu_items_scope.dart';

/// The 4 branch tabs shown in root mode. Profile isn't a tab — its slot is
/// replaced by Menu (tapping Menu opens a sheet with a Profile row instead of
/// navigating there directly); the branch itself (index 4) is still reached
/// via that row, or by any `context.go('/main/profile')` elsewhere.
const List<AppNavItem> _tabs = [
  (icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
  (
    icon: Icons.music_note_outlined,
    selectedIcon: Icons.music_note,
    label: 'Songs',
  ),
  (icon: Icons.groups_outlined, selectedIcon: Icons.groups, label: 'Bands'),
  (
    icon: Icons.queue_music_outlined,
    selectedIcon: Icons.queue_music,
    label: 'Setlists',
  ),
];

/// The 5 branch root locations, in branch-index order. Used both to clamp
/// [StatefulNavigationShell.currentIndex] and to detect root vs. pushed mode:
/// pushed ⇔ the router's current location isn't one of these.
const List<String> _branchRootLocations = [
  '/main/home',
  '/main/songs',
  '/main/bands',
  '/main/setlists',
  '/main/profile',
];

/// Main application shell with adaptive navigation.
/// Works with StatefulShellRoute.indexedStack for proper tab switching.
///
/// The bottom bar has two mutually exclusive modes (see [AppBottomBar]):
/// - Root mode (on one of the 5 branch roots): the Home/Songs/Bands/Setlists
///   tabs plus a Menu slot. Menu replaces the old Profile tab; it opens a
///   bottom sheet (never navigates) with the current screen's contextual
///   actions plus a Profile row.
/// - Pushed mode (any pushed route inside the shell — a branch child like
///   edit-song): `[← Back] [screen title] [⋮ Menu]`.
///
/// Root-pushed tool routes (Metronome/Tuner/Join Band) live outside the shell
/// entirely (root navigator) — they render their own pushed-mode bar via
/// their own scaffolds, not this one.
///
/// Portrait: bottom bar. Landscape: left rail (same two modes).
class MainShell extends ConsumerStatefulWidget {
  const MainShell({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  DateTime? _lastTapTime;
  int? _lastTappedIndex;

  // Pushed-mode detection needs BOTH signals:
  // - BranchStackObserver depth: intra-branch pushes never update the
  //   router's currentConfiguration.uri (device-verified), only the branch
  //   navigator sees them.
  // - URI check: deep entries (initialLocation/deep link straight to a child
  //   route) build the child without firing observer pushes, so depth stays
  //   0 while the URI correctly points below the branch root.
  bool get _pushed {
    final i = widget.navigationShell.currentIndex;
    final depths = BranchStackObserver.depths.value;
    if (i >= 0 && i < depths.length && depths[i] > 0) return true;
    final uri = GoRouter.maybeOf(
      context,
    )?.routerDelegate.currentConfiguration.uri.toString();
    return uri != null && !_branchRootLocations.contains(uri);
  }

  String get _branchRoot {
    final i = widget.navigationShell.currentIndex;
    return i >= 0 && i < _branchRootLocations.length
        ? _branchRootLocations[i]
        : _branchRootLocations.first;
  }

  @override
  void initState() {
    super.initState();
    BranchStackObserver.depths.addListener(_onDepthsChange);
  }

  @override
  void dispose() {
    BranchStackObserver.depths.removeListener(_onDepthsChange);
    super.dispose();
  }

  void _onDepthsChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // The shell has exactly 5 branches (Home/Songs/Bands/Setlists/Profile)
    // matching _branchRootLocations — Metronome/Tuner/Join Band are pushed on
    // top of the shell via the root navigator instead of being branches.
    final currentIndex = widget.navigationShell.currentIndex;
    final safeIndex = currentIndex >= 0 && currentIndex < 5 ? currentIndex : 0;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final content = DemoModeBanner(child: widget.navigationShell);

    if (isLandscape) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              _buildRail(context, safeIndex),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: context.mp.borderSubtle,
              ),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: content,
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: MenuScopeRegistry.revision,
        builder: (context, _, _) => _buildBar(context, safeIndex),
      ),
    );
  }

  Widget _buildRail(BuildContext context, int safeIndex) {
    return Container(
      width: 76,
      color: context.mp.blackSurface,
      // Scrollable so the tabs never overflow on a short landscape height.
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: MonoPulseSpacing.lg),
        child: ValueListenableBuilder<int>(
          valueListenable: MenuScopeRegistry.revision,
          builder: (context, _, _) => Column(
            children: [
              if (_pushed)
                Padding(
                  padding: const EdgeInsets.only(bottom: MonoPulseSpacing.lg),
                  child: NavTab(
                    item: const (
                      icon: Icons.arrow_back,
                      selectedIcon: Icons.arrow_back,
                      label: 'Back',
                    ),
                    selected: false,
                    onTap: _handleBack,
                  ),
                )
              else
                for (var i = 0; i < _tabs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: MonoPulseSpacing.lg),
                    child: NavTab(
                      item: _tabs[i],
                      selected: i == safeIndex,
                      onTap: () => _onTap(context, i),
                    ),
                  ),
              Padding(
                padding: const EdgeInsets.only(bottom: MonoPulseSpacing.lg),
                child: NavTab(
                  item: const (
                    icon: Icons.more_horiz,
                    selectedIcon: Icons.more_horiz,
                    label: 'Menu',
                  ),
                  selected: !_pushed && safeIndex == 4,
                  showBadge: _currentMenu()?.items.isNotEmpty ?? false,
                  onTap: () => _openMenu(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBar(BuildContext context, int safeIndex) {
    if (_pushed) {
      final entry = _currentMenu();
      return AppBottomBar.actions(
        onBack: _handleBack,
        title: entry?.title,
        primaryAction: entry?.primaryAction,
        onMenu: (entry?.items.isNotEmpty ?? false)
            ? () => _openMenu(context)
            : null,
      );
    }

    return AppBottomBar.tabs(
      tabs: _tabs,
      selectedIndex: safeIndex,
      onTabTap: (i) => _onTap(context, i),
      onMenuTap: () => _openMenu(context),
      menuSelected: safeIndex == 4,
      menuHasBadge: _currentMenu()?.items.isNotEmpty ?? false,
    );
  }

  MenuScopeData? _currentMenu() => _pushed
      // Deepest publisher above the branch root; null when the pushed screen
      // has no menu (the bar then hides its ⋮ — never the root's menu).
      ? MenuScopeRegistry.pushedEntryFor(_branchRoot)
      : MenuScopeRegistry.forLocation(_branchRoot);

  void _openMenu(BuildContext context) {
    final entry = _currentMenu();
    // Use a screen's contextual title only when it actually contributes menu
    // items (e.g. Songs → "Browse catalog"…). A title-only entry like the Home
    // root is just the app menu, so it reads as "Menu" — not "Home", which
    // looked like the wrong location (UX audit F-003).
    final hasItems = entry != null && entry.items.isNotEmpty;
    showAppMenuSheet(
      context,
      title: hasItems ? entry.title : 'Menu',
      items: entry?.items ?? const [],
      showProfileRow: !_pushed,
      ref: ref,
    );
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/main/home');
    }
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
    if (branchIndex >= 0 && branchIndex < _branchRootLocations.length) {
      context.go(_branchRootLocations[branchIndex]);
    }
  }
}
