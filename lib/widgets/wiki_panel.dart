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

  /// When pinned, the panel stays on the user-chosen page and stops following
  /// app screen changes. Auto-enabled when the user taps an internal wiki link.
  bool _pinned = false;

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

  void _onRouteChanged() {
    if (_pinned) return; // user is reading a pinned page; don't yank it away
    setState(_sync);
  }

  void _togglePin() {
    setState(() {
      _pinned = !_pinned;
      if (!_pinned) _sync(); // back to mirroring: resync to the current screen
    });
  }

  void _sync() {
    // Use go_router's RESOLVED location, not the raw platform URI. Under the
    // default hash strategy the raw `routeInformationProvider.value.uri` is the
    // whole browser URL (`/app/#/main/home`) whose `.path` is `/app/`, so the
    // mapping always fell back to `_index`. `appRouter.state.uri` is `/main/home`.
    final path = appRouter.state.uri.path;
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
    // Material ancestor: the panel is a sibling of the app navigator (see
    // main.dart `_withDesktopWiki`), so it has no Scaffold/Material of its own —
    // the toolbar button would assert without this.
    return Material(
      color: MonoPulseColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _togglePin,
                  icon: Icon(
                    _pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 16,
                  ),
                  label: Text(_pinned ? 'Pinned' : 'Following app'),
                  style: TextButton.styleFrom(
                    foregroundColor: _pinned
                        ? MonoPulseColors.accentOrange
                        : MonoPulseColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
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
                    if (href == null) return;
                    final key = wikiKeyForHref(href);
                    if (key != null) {
                      // Internal wiki link → swap panel content in place and pin
                      // so changing app screens won't yank the page away.
                      setState(() {
                        _pinned = true;
                        _key = key;
                        _content = _load(key);
                      });
                    } else {
                      // External/unknown → new tab; resolve relative links
                      // against the current URL so `../faq/` etc. still work.
                      launchUrl(
                        Uri.base.resolve(href),
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
