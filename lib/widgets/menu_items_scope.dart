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

  static void attach(Object token, String location, MenuScopeData data) {
    final i = _stack.indexWhere((e) => identical(e.token, token));
    if (i >= 0) {
      _stack[i] = (token: token, location: location, data: data);
    } else {
      _stack.add((token: token, location: location, data: data));
    }
    revision.value++;
  }

  static void detach(Object token) {
    _stack.removeWhere((e) => identical(e.token, token));
    revision.value++;
  }

  /// The deepest live publisher for a screen pushed ABOVE [branchRoot]
  /// (location strictly below the root). Null when the pushed screen didn't
  /// publish a menu — the shell then hides the bar's ⋮ instead of showing
  /// the root screen's (wrong) menu.
  static MenuScopeData? pushedEntryFor(String branchRoot) {
    for (final e in _stack.reversed) {
      if (e.location != branchRoot && e.location.startsWith(branchRoot)) {
        return e.data;
      }
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

typedef _StackEntry = ({Object token, String location, MenuScopeData data});

/// Publishes [data] into [MenuScopeRegistry] under this screen's go_router
/// location for as long as this widget is in the tree, and exposes it locally
/// as a [MenuItemsScope].
///
/// The location key is captured ONCE, on first `didChangeDependencies`
/// (`GoRouterState.of(context).uri`) — never re-read on rebuild. A kept-alive
/// branch-root screen that rebuilds while a child route is on top would
/// otherwise see the CHILD's uri in its own `GoRouterState` and clobber the
/// child's registry entry with the root's data.
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
        _location = GoRouterState.of(context).uri.toString();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MenuScopeRegistry.publish(location, data);
      if (mounted) MenuScopeRegistry.attach(this, location, data);
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
