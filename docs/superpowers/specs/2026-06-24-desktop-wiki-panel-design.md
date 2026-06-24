# Desktop Wiki Panel + Left-Confined App — Design

Date: 2026-06-24
Status: Approved

## Goal

On desktop / wide screens (>1024px), the app already renders as a phone-width
column on the left with empty space on the right. Replace the right space with a
**contextual wiki panel** that shows a small help page matching the current app
screen. The wiki pages live in a new top-level Hugo `wiki` section so they are
*also* published on the website. The left column becomes the **only** place the
real app lives — all app overlays (dialogs, menus, logout confirm) stay confined
to it and never spill over the right panel.

Principle (from the user): *the real app only takes the left widget and is
identical to the phone / Android app; the right widget is desktop-only support,
populated with useful information.*

## Architecture — the key move

Today the desktop split lives **inside** the router: `DesktopShell` wraps
`MainShell` at `app_router.dart:212`. Because of that, the app's root navigator
(and every `showDialog` / sheet / menu overlay — 112 call sites across 22 files,
all defaulting to `useRootNavigator: true`) spans the whole window.

Move the split **up into `MaterialApp.router`'s `builder`** (`main.dart:257`).
The `builder`'s `child` argument **is the app's root Navigator**, so constraining
`child` to a 480px box confines every overlay to that box automatically — **zero
edits to the 112 call sites.**

```
builder(context, child):              // child == app root Navigator
  desktop?  Row[
              SizedBox(480, MediaQuery→phone(child)),   // LEFT = the real app
              divider,
              Expanded(WikiPanel),                       // RIGHT = desktop-only wiki
            ]
  else      child                                        // phone/tablet: unchanged
```

- **Left** = the real app, identical to phone layout. Keep the existing
  `MediaQuery` override to a 480-wide portrait size (currently in `DesktopShell`)
  so `MainShell` / `HomeScreen` render the phone layout, not the side-rail one.
- **Right** = `WikiPanel`, a sibling **outside** the navigator, so dialog
  barriers never dim it.
- **Delete `DesktopShell`** — fold its phone-width `MediaQuery` override into the
  builder, and return `MainShell` directly at `app_router.dart:212`. Delete the
  now-dead `DashboardWelcomeWidget` if nothing else references it (grep first).

Desktop detection reuses `getBreakpoint` / `ScreenBreakpoint.desktop` from
`lib/utils/responsive_breakpoints.dart`.

## WikiPanel — `lib/widgets/wiki_panel.dart` (new)

- Listens to `appRouter.routeInformationProvider` (a `ChangeNotifier` exposing
  the current `Uri`). `appRouter` is a global (`app_router.dart:88`), so the
  panel can read it even though it sits outside the router's `InheritedWidget`.
- Maps the current path prefix → a wiki key:
  - `/main/home` → `home`
  - `/main/songs…` → `songs`
  - `/main/bands…` → `bands`
  - `/main/setlists…` → `setlists`
  - `/main/profile…` → `profile`
  - tool routes (metronome / tuner / concert mode) → `metronome` / `tuner` /
    `concert-mode` (resolve exact paths from `app_router.dart` during impl)
  - anything else (e.g. login) → the wiki index (`_index`)
- Loads the matching bundled markdown asset, strips Hugo front matter, renders
  with a markdown widget styled in Mono Pulse colors/typography.

## Single markdown source

Wiki pages live in **`site/content/wiki/`** and are **also listed as Flutter
assets** (`assets: - site/content/wiki/` in `pubspec.yaml`; asset paths are
project-root relative). One file feeds both Hugo (public page) and Flutter
(panel). No copying, no sync step.

Front matter is stripped at load time: if the file starts with `---` (YAML) or
`+++` (TOML), drop through the matching closing delimiter, render the rest.
~5 lines, with one `assert`-based self-check (both delimiter styles + no front
matter).

## Hugo `wiki` section (new top-level, sibling of about/faq/blog)

`site/content/wiki/`:
- `_index.md` — the wiki **home page**; links to all 8 sub-pages.
- `home.md`, `songs.md`, `bands.md`, `setlists.md`, `profile.md`,
  `metronome.md`, `tuner.md`, `concert-mode.md` — small help pages, each with
  minimal Hugo front matter (title) + a few short sections.

## Dependency

One maintained markdown renderer (`flutter_markdown_plus` or `markdown_widget` —
the original `flutter_markdown` is discontinued). Pick the lighter one at impl.
Justified: hand-rolling a markdown parser is reinvention.

## Testing / verification

- Front-matter stripper: one `assert`-based `demo()`/test (YAML, TOML, none).
- Path→key mapping: small pure function, one `assert`-based check.
- The layout split and overlay confinement are structural/visual — verify by
  running the desktop/web app: panel shows the right page per screen, and the
  logout confirm dialog dims only the left column.

## Out of scope (skipped, add later if needed)

- Live content fetch (Opt 3 — `flutter_widget_from_html` + http + CORS).
- Per-call-site overlay edits (the builder split makes them unnecessary).
- Keeping `DesktopShell` / `DashboardWelcomeWidget` (deleted unless still used).
- A welcome card above the wiki (can add back above `WikiPanel` content later).

## Files touched

New:
- `site/content/wiki/_index.md` + 8 page files
- `lib/widgets/wiki_panel.dart`

Modified:
- `lib/main.dart` (`builder` ~line 257: desktop split)
- `pubspec.yaml` (markdown dep + `site/content/wiki/` assets)
- `lib/router/app_router.dart:212` (return `MainShell` directly)

Deleted:
- `lib/widgets/desktop_shell.dart`
- `lib/widgets/dashboard_welcome_widget.dart` (if no other references)
