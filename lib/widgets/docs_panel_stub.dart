import 'package:flutter/material.dart';

/// Non-web builds have no iframe; show the fallback (welcome widget).
/// ponytail: mobile never hits the desktop sidebar breakpoint anyway,
/// fallback just keeps io builds compiling.
class DocsPanel extends StatelessWidget {
  const DocsPanel({required this.url, required this.fallback, super.key});
  final String url;
  final Widget fallback;

  @override
  Widget build(BuildContext context) => fallback;
}
