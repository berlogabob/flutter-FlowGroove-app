import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_menu_sheet.dart';

/// Ambient "what menu does the current screen offer" data, carried down the
/// tree as a plain [InheritedWidget]. Cheap local lookup for a descendant
/// that wants its nearest ancestor screen's menu without prop-drilling
/// title/items through every constructor.
///
/// This does NOT solve the shell's problem of reading the *currently visible*
/// screen's menu — the shell is an ancestor of the branch content (and
/// root-pushed tool routes live on a different `Navigator` entirely), so it
/// can never be a descendant of the screen it wants to read. For that,
/// [MenuScopeRegistry] below (a plain, non-Riverpod notifier) is the
/// cross-navigator channel; screens publish into it via [MenuScopePublisher].
class MenuItemsScope extends InheritedWidget {
  const MenuItemsScope({
    required this.title,
    required this.items,
    required super.child,
    super.key,
  });

  final String title;
  final List<AppMenuItem> items;

  static MenuItemsScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MenuItemsScope>();
  }

  static MenuItemsScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'No MenuItemsScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(MenuItemsScope oldWidget) {
    return title != oldWidget.title || items != oldWidget.items;
  }
}

/// The Back/Title/Menu bar content the shell should show for one screen.
class MenuScopeData {
  const MenuScopeData({
    required this.title,
    this.items = const [],
    this.primaryAction,
  });

  final String title;
  final List<AppMenuItem> items;

  /// Replaces the title slot in the pushed-mode bottom bar (e.g.
  /// `SetlistViewScreen`'s "Open in Metronome" button). [title] still names
  /// the menu sheet when [items] is non-empty.
  final Widget? primaryAction;
}

/// Cross-navigator registry the shell reads to render its pushed-mode bottom
/// bar (Back / title / Menu) and its root-mode Menu dot badge, without
/// needing an `InheritedWidget` descendant relationship it can't have.
///
/// Entries are keyed by go_router location and never removed on dispose —
/// only overwritten by a fresh registration for that same location. This
/// sidesteps a dispose-ordering race: branch roots are kept alive forever by
/// `StatefulShellRoute.indexedStack` and only run `initState` once, while
/// pushed children mount/unmount on every push/pop. If a pushed child's
/// `dispose()` blindly cleared a single shared "current" slot, popping back
/// to a root screen would leave the shell reading a wiped value instead of
/// the still-mounted root screen's entry. Keying by location means each
/// screen's last-known data is always exactly where the shell looks for it,
/// whether that screen ever runs its lifecycle callbacks again or not.
class MenuScopeRegistry {
  MenuScopeRegistry._();

  static final Map<String, MenuScopeData> _entries = <String, MenuScopeData>{};

  /// Bumped on every publish so listeners (the shell) can rebuild without
  /// needing to know which keys changed.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static MenuScopeData? forLocation(String location) => _entries[location];

  static void publish(String location, MenuScopeData data) {
    _entries[location] = data;
    revision.value++;
  }

  /// Live publishers in mount order, keyed by State identity — unlike the
  /// location map these ARE removed on dispose, which is safe because
  /// removal is by token, immune to indexedStack dispose-ordering.
  static final List<_StackEntry> _stack = <_StackEntry>[];

  static void attach(
    Object token,
    String location,
    int branch,
    MenuScopeData data,
  ) {
    final i = _stack.indexWhere((e) => identical(e.token, token));
    final entry = (
      token: token,
      location: location,
      branch: branch,
      data: data,
    );
    if (i >= 0) {
      _stack[i] = entry;
    } else {
      _stack.add(entry);
    }
    revision.value++;
  }

  static void detach(Object token) {
    _stack.removeWhere((e) => identical(e.token, token));
    revision.value++;
  }

  /// The menu of the topmost pushed child currently VISIBLE on branch [branch]
  /// (its branch roots are in [roots] and excluded). Null when the pushed screen
  /// didn't publish a menu — the shell then hides the bar's ⋮ instead of showing
  /// the root screen's (wrong) menu.
  ///
  /// Entries are matched by the branch they're shown on, tagged at publish time
  /// ([CurrentBranchScope]) — NOT by route-location prefix. A cross-branch push
  /// (e.g. `edit-song`, a `/main/songs` route, opened from the bands branch)
  /// keeps its route's foreign location but is visible on — and tagged with —
  /// the bands branch, so its own menu still resolves here. Location prefix
  /// alone can't tell which navigator a cross-branch push is visible on, and
  /// would return the parent screen's menu instead (device-verified regression).
  static MenuScopeData? pushedEntryFor(int branch, {Set<String> roots = const {}}) {
    for (final e in _stack.reversed) {
      if (e.branch == branch && !roots.contains(e.location)) return e.data;
    }
    return null;
  }

  /// Test hook: wipe all entries between pumps.
  @visibleForTesting
  static void reset() {
    _entries.clear();
    _stack.clear();
    revision.value++;
  }
}

typedef _StackEntry = ({
  Object token,
  String location,
  int branch,
  MenuScopeData data,
});

/// The index of the branch currently visible in the shell, exposed to branch
/// content so a published menu can be tagged with the branch it's really shown
/// on. Needed because a route from one branch can be pushed onto another
/// branch's navigator (e.g. `edit-song`, a `/main/songs` route, opened from the
/// bands branch) — its location says "songs" but it's visible on "bands", and
/// only the shell knows that.
class CurrentBranchScope extends InheritedWidget {
  const CurrentBranchScope({
    required this.index,
    required super.child,
    super.key,
  });

  final int index;

  /// Reads WITHOUT registering a dependency: an entry's host branch is fixed at
  /// publish time and must not change when the visible branch later changes
  /// (a `dependOn…` here would re-tag orphaned pushed children on tab switch).
  static int? indexOf(BuildContext context) {
    final widget = context
        .getElementForInheritedWidgetOfExactType<CurrentBranchScope>()
        ?.widget;
    return widget is CurrentBranchScope ? widget.index : null;
  }

  @override
  bool updateShouldNotify(CurrentBranchScope oldWidget) =>
      index != oldWidget.index;
}

/// Publishes [data] into [MenuScopeRegistry] under this screen's go_router
/// location for as long as this widget is in the tree, and exposes it locally
/// as a [MenuItemsScope].
///
/// The location key is `GoRouterState.of(context).matchedLocation` — the
/// route's OWN matched path, resolved per page. NOT `uri`: `uri` is always
/// the full current location, so a branch root that first mounts UNDER a
/// child route (deep navigation into a not-yet-visited tab, e.g. Practice →
/// a song's Lab before ever opening the Songs tab) would register under the
/// child's uri and the shell's root-menu lookup would miss forever — the ⋮
/// sheet then shows only the global Profile/Settings rows.
///
/// Writes are deferred to a post-frame callback (never done synchronously
/// during build/lifecycle) — mutating shared state that an ancestor (the
/// shell) listens to, mid-build, is the exact "setState() called during
/// build" screen-blanking regression class this app has hit before with
/// Riverpod provider writes; a plain `ValueNotifier` isn't immune to the same
/// assertion if a listener reacts synchronously.
///
/// Screens without a GoRouter ancestor (imperative `Navigator.push` overlays,
/// bare widget tests) simply don't publish; the local [MenuItemsScope] still
/// works.
class MenuScopePublisher extends StatefulWidget {
  const MenuScopePublisher({
    required this.data,
    required this.child,
    super.key,
  });

  final MenuScopeData data;
  final Widget child;

  @override
  State<MenuScopePublisher> createState() => _MenuScopePublisherState();
}

class _MenuScopePublisherState extends State<MenuScopePublisher> {
  String? _location;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_location == null) {
      try {
        _location = GoRouterState.of(context).matchedLocation;
      } catch (_) {
        // Not under a GoRoute (imperative push, widget test) — no registry
        // publication; the shell can't see this screen anyway.
        return;
      }
      _publish();
    }
  }

  @override
  void didUpdateWidget(covariant MenuScopePublisher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_location != null) _publish();
  }

  void _publish() {
    final location = _location;
    if (location == null) return;
    final data = widget.data;
    // Tag with the branch this screen is visible on (captured now, while the
    // context is valid) so a cross-branch push resolves to its own menu.
    final branch = CurrentBranchScope.indexOf(context) ?? -1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MenuScopeRegistry.publish(location, data);
      if (mounted) MenuScopeRegistry.attach(this, location, branch, data);
    });
  }

  @override
  void dispose() {
    final token = this;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MenuScopeRegistry.detach(token);
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MenuItemsScope(
      title: widget.data.title,
      items: widget.data.items,
      child: widget.child,
    );
  }
}
