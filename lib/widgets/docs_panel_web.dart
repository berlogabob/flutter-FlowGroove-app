// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// Web sidebar panel: embeds a Hugo page (single source of truth) in an iframe.
class DocsPanel extends StatelessWidget {
  const DocsPanel({required this.url, required this.fallback, super.key});
  final String url;

  /// Unused on web (iframe replaces it); kept for a shared constructor.
  final Widget fallback;

  static final Set<String> _registered = {};

  @override
  Widget build(BuildContext context) {
    final viewType = 'docs-iframe-$url';
    if (_registered.add(viewType)) {
      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
        return html.IFrameElement()
          ..src = url
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%';
      });
    }
    return HtmlElementView(viewType: viewType);
  }
}
