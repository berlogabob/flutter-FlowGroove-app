import 'package:flutter/widgets.dart';

/// Tracks how many page routes are stacked above each shell branch's root.
///
/// The shell needs to know "is the active branch showing a pushed child?"
/// to switch its bottom bar between tabs mode and back/menu mode. The
/// router's `currentConfiguration.uri` does NOT update for intra-branch
/// pushes (verified on device and in tests), so we observe the branch
/// navigators directly instead.
///
/// Only [PageRoute]s are counted: dialogs and bottom sheets are
/// [PopupRoute]s pushed onto the same navigator and must not flip the bar.
class BranchStackObserver extends NavigatorObserver {
  BranchStackObserver(this.branchIndex);

  final int branchIndex;

  static const int branchCount = 5;

  /// depths[i] = number of page routes above branch i's root (0 = at root).
  static final ValueNotifier<List<int>> depths = ValueNotifier<List<int>>(
    List<int>.filled(branchCount, 0),
  );

  int _pageRoutes = 0;

  void _set() {
    // didPush/didPop fire during navigation (often mid-build); notifying the
    // shell synchronously triggers "setState() called during build". Defer
    // the flush; it recomputes from _pageRoutes so stacked callbacks are
    // idempotent.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final value = _pageRoutes > 0 ? _pageRoutes - 1 : 0;
      if (depths.value[branchIndex] == value) return;
      final next = List<int>.of(depths.value);
      next[branchIndex] = value;
      depths.value = next;
    });
  }

  /// Test hook.
  static void reset() {
    depths.value = List<int>.filled(branchCount, 0);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) {
      _pageRoutes++;
      _set();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) {
      _pageRoutes--;
      _set();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) {
      _pageRoutes--;
      _set();
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    // Page-for-page replace keeps the count; only adjust on type mismatch.
    final wasPage = oldRoute is PageRoute;
    final isPage = newRoute is PageRoute;
    if (wasPage != isPage) {
      _pageRoutes += isPage ? 1 : -1;
      _set();
    }
  }
}
