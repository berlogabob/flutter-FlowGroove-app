# Desktop Wiki Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On desktop (>1024px) show a contextual wiki help panel on the right that matches the current app screen, while the real app + all its overlays stay confined to a 480px left column.

**Architecture:** Move the desktop split out of the router (`DesktopShell`) and up into `MaterialApp.router`'s `builder`, where `child` *is* the app's root navigator. Constraining `child` to 480px confines every dialog/menu/overlay there for free. The right `WikiPanel` is a sibling outside the navigator that reads the current path from the global `appRouter` and renders bundled markdown. Wiki markdown lives in a new Hugo `wiki` section and doubles as Flutter assets (one source).

**Tech Stack:** Flutter, Riverpod, go_router, Hugo, `flutter_markdown_plus`, `url_launcher`.

## Global Constraints

- Dart SDK `^3.12.0`; Flutter (existing).
- Theme: use `MonoPulseColors` / `MonoPulseTypography` / `MonoPulseSpacing` from `lib/theme/mono_pulse_theme.dart`. No raw hex / magic colors.
- Left app column width: `480`.
- Desktop detection: `getBreakpoint(width) == ScreenBreakpoint.desktop` from `lib/utils/responsive_breakpoints.dart`.
- NO web iframe / `HtmlElementView` (froze the app previously).
- Wiki markdown is the single source: same files feed Hugo and Flutter assets. Never copy/duplicate them.
- Commit messages end with: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. Pre-commit hook may block; use `--no-verify` only if it blocks on unrelated files (google-services.json/AIzaSy).

---

### Task 1: Hugo `wiki` section (content + single-source files)

**Files:**
- Create: `site/content/wiki/_index.md`
- Create: `site/content/wiki/home.md`, `songs.md`, `bands.md`, `setlists.md`, `profile.md`, `metronome.md`, `tuner.md`, `concert-mode.md`

**Interfaces:**
- Produces: 9 markdown files under `site/content/wiki/`. Each starts with YAML front matter (`---\ntitle: "..."\n---`). Filenames (minus `.md`) are the wiki keys consumed in Task 3/4: `home, songs, bands, setlists, profile, metronome, tuner, concert-mode`, plus `_index`.

- [ ] **Step 1: Create the wiki index page**

`site/content/wiki/_index.md`:
```markdown
---
title: "Wiki"
description: "Help and guides for every part of FlowGroove."
---

# FlowGroove Wiki

Short guides for each screen of the app.

- [Home](home/) — your dashboard
- [Songs](songs/) — manage your song library
- [Bands](bands/) — create and join bands
- [Setlists](setlists/) — build performance setlists
- [Profile](profile/) — account and settings
- [Metronome](metronome/) — practice to a steady beat
- [Tuner](tuner/) — tune your instrument
- [Concert Mode](concert-mode/) — perform live
```

- [ ] **Step 2: Create the 8 page files**

Each file follows the same shape. `site/content/wiki/home.md`:
```markdown
---
title: "Home"
---

# Home

Your dashboard. From here you can jump to your songs, bands, setlists, and tools.

- Tap a navigation tab at the bottom to switch sections.
- Quick tips and recent activity show on this screen.
```

`site/content/wiki/songs.md`:
```markdown
---
title: "Songs"
---

# Songs

Your personal song library.

- Tap **+** to add a song (title, BPM, key, structure, links).
- Open a song to edit its details or song structure.
- Songs you add to a band become independent copies in that band.
```

`site/content/wiki/bands.md`:
```markdown
---
title: "Bands"
---

# Bands

Organize rehearsals with your group.

- Create a band, then invite members with a join link.
- Membership is managed on the server — joins go through a secure flow.
- Each band has its own songs, setlists, and about page.
```

`site/content/wiki/setlists.md`:
```markdown
---
title: "Setlists"
---

# Setlists

Order songs for a performance.

- Create a setlist and add songs from your library or a band.
- Reorder songs to match your show.
- Open a setlist in Concert Mode to perform.
```

`site/content/wiki/profile.md`:
```markdown
---
title: "Profile"
---

# Profile

Your account and app settings.

- Update your display name and photo.
- Manage preferences.
- Sign out from the button at the bottom of this screen.
```

`site/content/wiki/metronome.md`:
```markdown
---
title: "Metronome"
---

# Metronome

Practice to a steady beat.

- Set the tempo (BPM) and time signature.
- Tap accents to emphasize beats.
- On the web, audio uses the Web Audio engine automatically.
```

`site/content/wiki/tuner.md`:
```markdown
---
title: "Tuner"
---

# Tuner

Tune your instrument by ear or display.

- Play a note; the tuner shows the detected pitch.
- Use Stage Mode for a large, glanceable display.
```

`site/content/wiki/concert-mode.md`:
```markdown
---
title: "Concert Mode"
---

# Concert Mode

Perform a setlist live.

- Open a setlist to enter Concert Mode.
- Swipe between songs; key details stay on screen.
- Keep the metronome running between songs.
```

- [ ] **Step 3: Verify Hugo builds the section**

Run: `cd site && hugo --quiet && ls public/wiki/`
Expected: directories `home/ songs/ bands/ setlists/ profile/ metronome/ tuner/ concert-mode/` and an `index.html` at `public/wiki/`.

- [ ] **Step 4: Commit**

```bash
git add site/content/wiki/
git commit -m "feat(wiki): add Hugo wiki section with per-screen help pages

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Add markdown dependency + bundle wiki as Flutter assets

**Files:**
- Modify: `pubspec.yaml` (dependencies + flutter assets)

**Interfaces:**
- Produces: `flutter_markdown_plus` available; assets under `site/content/wiki/` loadable via `rootBundle.loadString('site/content/wiki/<key>.md')`.

- [ ] **Step 1: Add the dependency**

In `pubspec.yaml` under `dependencies:` (near `url_launcher: ^6.3.2`), add:
```yaml
  flutter_markdown_plus: ^1.0.0
```

- [ ] **Step 2: Register the wiki assets**

In `pubspec.yaml` under `flutter:` → `assets:`, add:
```yaml
    - site/content/wiki/
```

- [ ] **Step 3: Fetch packages**

Run: `flutter pub get`
Expected: resolves with no errors; `flutter_markdown_plus` listed.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "build: add flutter_markdown_plus and bundle wiki assets

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Pure helpers — front-matter stripping + path→key mapping (TDD)

**Files:**
- Create: `lib/widgets/wiki_content.dart`
- Test: `test/widgets/wiki_content_test.dart`

**Interfaces:**
- Produces:
  - `String stripFrontMatter(String raw)` — returns markdown body with a leading YAML (`---`) or TOML (`+++`) front-matter block removed; returns input unchanged if none.
  - `String wikiKeyForPath(String path)` — maps a router path to a wiki key (`home/songs/bands/setlists/profile/metronome/tuner`), else `_index`.
  - `String wikiAssetForKey(String key)` — returns `site/content/wiki/<key>.md`.

- [ ] **Step 1: Write the failing tests**

`test/widgets/wiki_content_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/widgets/wiki_content.dart';

void main() {
  group('stripFrontMatter', () {
    test('removes YAML front matter', () {
      const raw = '---\ntitle: "Home"\n---\n\n# Home\nbody';
      expect(stripFrontMatter(raw), '# Home\nbody');
    });
    test('removes TOML front matter', () {
      const raw = '+++\ntitle = "Home"\n+++\nBody only';
      expect(stripFrontMatter(raw), 'Body only');
    });
    test('returns input unchanged when no front matter', () {
      const raw = '# Home\nbody';
      expect(stripFrontMatter(raw), '# Home\nbody');
    });
  });

  group('wikiKeyForPath', () {
    test('maps a section path to its key', () {
      expect(wikiKeyForPath('/main/songs/123'), 'songs');
      expect(wikiKeyForPath('/main/home'), 'home');
      expect(wikiKeyForPath('/main/metronome'), 'metronome');
    });
    test('falls back to _index for unknown paths', () {
      expect(wikiKeyForPath('/login'), '_index');
      expect(wikiKeyForPath('/'), '_index');
    });
  });

  test('wikiAssetForKey builds the asset path', () {
    expect(wikiAssetForKey('songs'), 'site/content/wiki/songs.md');
    expect(wikiAssetForKey('_index'), 'site/content/wiki/_index.md');
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widgets/wiki_content_test.dart`
Expected: FAIL — `wiki_content.dart` / functions not found.

- [ ] **Step 3: Write the implementation**

`lib/widgets/wiki_content.dart`:
```dart
/// Pure helpers for the desktop wiki panel. No Flutter UI deps so they are
/// trivially testable.

/// Strips a leading Hugo front-matter block (YAML `---` or TOML `+++`) from
/// [raw], returning the markdown body. Returns [raw] unchanged if there is no
/// recognizable front matter.
String stripFrontMatter(String raw) {
  final s = raw.trimLeft();
  for (final delim in const ['---', '+++']) {
    if (s.startsWith(delim)) {
      final close = s.indexOf('\n$delim', delim.length);
      if (close != -1) {
        final bodyStart = s.indexOf('\n', close + 1);
        return bodyStart == -1 ? '' : s.substring(bodyStart + 1).trimLeft();
      }
    }
  }
  return raw;
}

const _sections = [
  'home',
  'songs',
  'bands',
  'setlists',
  'profile',
  'metronome',
  'tuner',
];

/// Maps a router [path] to a wiki key, or `_index` when nothing matches.
String wikiKeyForPath(String path) {
  for (final key in _sections) {
    if (path.startsWith('/main/$key')) return key;
  }
  return '_index';
}

/// Asset path for a wiki [key] (single source shared with Hugo).
String wikiAssetForKey(String key) => 'site/content/wiki/$key.md';
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/widgets/wiki_content_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/wiki_content.dart test/widgets/wiki_content_test.dart
git commit -m "feat(wiki): pure helpers for front-matter strip and path mapping

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: WikiPanel widget

**Files:**
- Create: `lib/widgets/wiki_panel.dart`

**Interfaces:**
- Consumes: `wikiKeyForPath`, `wikiAssetForKey`, `stripFrontMatter` (Task 3); global `appRouter` (`lib/router/app_router.dart`); `MonoPulse*` theme.
- Produces: `class WikiPanel extends StatefulWidget` with a `const WikiPanel({super.key})` constructor. Renders the wiki page for the current route.

- [ ] **Step 1: Write the widget**

`lib/widgets/wiki_panel.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../router/app_router.dart' show appRouter;
import '../theme/mono_pulse_theme.dart';
import 'wiki_content.dart';

/// Desktop-only right panel showing the wiki page that matches the current app
/// screen. Lives OUTSIDE the app navigator (a sibling of `child` in
/// `MaterialApp.router`'s builder), so dialog barriers never dim it. Reads the
/// current location from the global [appRouter] and renders the bundled
/// markdown that doubles as the Hugo wiki source.
class WikiPanel extends StatefulWidget {
  const WikiPanel({super.key});

  @override
  State<WikiPanel> createState() => _WikiPanelState();
}

class _WikiPanelState extends State<WikiPanel> {
  late final Listenable _location = appRouter.routeInformationProvider;
  String _key = '';
  Future<String>? _content;

  @override
  void initState() {
    super.initState();
    _location.addListener(_onRouteChanged);
    _sync();
  }

  @override
  void dispose() {
    _location.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _onRouteChanged() => setState(_sync);

  void _sync() {
    final path = appRouter.routeInformationProvider.value.uri.path;
    final key = wikiKeyForPath(path);
    if (key == _key && _content != null) return;
    _key = key;
    _content = _load(key);
  }

  Future<String> _load(String key) async {
    try {
      return stripFrontMatter(await rootBundle.loadString(wikiAssetForKey(key)));
    } catch (_) {
      // Fall back to the index if a screen has no dedicated page yet.
      return stripFrontMatter(await rootBundle.loadString(wikiAssetForKey('_index')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MonoPulseColors.surface,
      child: FutureBuilder<String>(
        future: _content,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return Markdown(
            data: snap.data!,
            padding: const EdgeInsets.all(MonoPulseSpacing.xl),
            styleSheet: MarkdownStyleSheet(
              h1: MonoPulseTypography.headlineSmall
                  .copyWith(color: MonoPulseColors.textPrimary),
              p: MonoPulseTypography.bodyMedium
                  .copyWith(color: MonoPulseColors.textSecondary),
              listBullet: MonoPulseTypography.bodyMedium
                  .copyWith(color: MonoPulseColors.textSecondary),
              a: const TextStyle(color: MonoPulseColors.accentOrange),
            ),
            onTapLink: (text, href, title) {
              if (href != null) {
                launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
              }
            },
          );
        },
      ),
    );
  }
}
```

> Note for implementer: if `MonoPulseTypography.headlineSmall` / `bodyMedium` are named differently in `lib/theme/mono_pulse_theme.dart`, use the nearest existing equivalents (the same ones `DashboardWelcomeWidget` used: `Theme.of(context).textTheme.headlineSmall`/`bodyMedium` is an acceptable fallback). Verify in Step 2.

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/widgets/wiki_panel.dart`
Expected: No errors. Fix any theme symbol names flagged here.

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/wiki_panel.dart
git commit -m "feat(wiki): desktop WikiPanel rendering per-screen markdown

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Wire the desktop split into the builder; remove DesktopShell

**Files:**
- Modify: `lib/main.dart` (builder ~line 257)
- Modify: `lib/router/app_router.dart:212`
- Delete: `lib/widgets/desktop_shell.dart`
- Delete: `lib/widgets/dashboard_welcome_widget.dart`

**Interfaces:**
- Consumes: `WikiPanel` (Task 4); `getBreakpoint` / `ScreenBreakpoint` (`lib/utils/responsive_breakpoints.dart`); `MonoPulseColors`.

- [ ] **Step 1: Add the desktop-split helper + imports in main.dart**

In `lib/main.dart`, add imports near the other widget/util imports:
```dart
import 'utils/responsive_breakpoints.dart';
import 'widgets/wiki_panel.dart';
import 'theme/mono_pulse_theme.dart';
```
(skip any already imported.)

Add this top-level function in `lib/main.dart` (outside the class):
```dart
/// On desktop, render the app in a fixed 480px phone-width column with the
/// wiki panel on the right. `app` is the root navigator (the builder's
/// `child`), so all its dialogs/menus/overlays stay inside the left column.
Widget _withDesktopWiki(BuildContext context, Widget app) {
  return LayoutBuilder(
    builder: (context, constraints) {
      if (getBreakpoint(constraints.maxWidth) != ScreenBreakpoint.desktop) {
        return app;
      }
      final mq = MediaQuery.of(context);
      return Row(
        children: [
          SizedBox(
            width: 480,
            child: MediaQuery(
              data: mq.copyWith(size: Size(480, mq.size.height)),
              child: app,
            ),
          ),
          Container(width: 1, color: MonoPulseColors.borderSubtle),
          const Expanded(child: WikiPanel()),
        ],
      );
    },
  );
}
```

- [ ] **Step 2: Apply the split in the builder's data + error branches**

In `lib/main.dart`, in the `builder`'s `userAsync.when`, wrap the returned child in the `data` and `error` branches:
```dart
          data: (user) {
            debugPrint('🟢 Auth state: DATA - user=${user?.email ?? "NULL"}');
            return _withDesktopWiki(context, child ?? const SizedBox.shrink());
          },
```
```dart
          error: (error, stack) {
            debugPrint('🔴 Auth state: ERROR - $error');
            debugPrint('Stack: $stack');
            return _withDesktopWiki(context, child ?? const SizedBox.shrink());
          },
```
(Leave the `loading` branch as-is.)

- [ ] **Step 3: Stop using DesktopShell in the router**

In `lib/router/app_router.dart`, line ~212, change:
```dart
        return DesktopShell(child: MainShell(navigationShell: navigationShell));
```
to:
```dart
        return MainShell(navigationShell: navigationShell);
```
Remove the now-unused `DesktopShell` import at the top of the file.

- [ ] **Step 4: Delete the dead files**

Run:
```bash
git rm lib/widgets/desktop_shell.dart lib/widgets/dashboard_welcome_widget.dart
```

- [ ] **Step 5: Verify the project analyzes and tests pass**

Run: `flutter analyze`
Expected: No errors (no dangling references to `DesktopShell` / `DashboardWelcomeWidget`).

Run: `flutter test test/widgets/wiki_content_test.dart`
Expected: PASS.

- [ ] **Step 6: Verify behavior in the running web app**

Run: `flutter run -d chrome` (or the project's usual web launch), widen the window past 1024px.
Expected:
- App stays in a 480px column on the left; wiki panel on the right.
- Navigating tabs (Home → Songs → Bands → Setlists → Profile → Metronome → Tuner) swaps the right panel to the matching page.
- Opening the **logout confirm** dialog from Profile dims/centers only over the **left** column, not the right panel.
- Narrowing below 1024px hides the panel and shows the normal full-width app.

- [ ] **Step 7: Commit**

```bash
git add lib/main.dart lib/router/app_router.dart
git commit -m "feat(wiki): desktop split in app builder; confine overlays to left column

Removes DesktopShell/DashboardWelcomeWidget; the MaterialApp.router builder now
renders the app in a 480px left column with WikiPanel on the right, so all app
overlays stay within the app column.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:**
- New top-level Hugo `wiki` section → Task 1. ✓
- Small page per main screen + index that links them → Task 1 (8 pages + `_index`). ✓
- Wiki shown next to corresponding app screen (native markdown, Opt 1) → Tasks 2–4. ✓
- Single markdown source (Hugo + Flutter assets) → Tasks 1–2. ✓
- Move app overlays to left column / right = desktop-only wiki → Task 5 (builder split confines overlays; `DesktopShell` removed). ✓
- No iframe → satisfied (native `Markdown` widget, no platform view). ✓
- Delete dead `DesktopShell`/`DashboardWelcomeWidget` → Task 5. ✓

**Placeholder scan:** None — all code/content is concrete. The one implementer note (Task 4) is a verification instruction with a named fallback, not a TODO.

**Type consistency:** `wikiKeyForPath` / `wikiAssetForKey` / `stripFrontMatter` signatures defined in Task 3 are used identically in Task 4. `WikiPanel` const constructor (Task 4) matches its use in Task 5. `getBreakpoint`/`ScreenBreakpoint.desktop` match the existing API.

Note: `concert-mode.md` exists for Hugo but has no in-app route, so `wikiKeyForPath` never returns it — intentional (8 pages requested; in-app falls back to `_index`).
