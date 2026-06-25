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
