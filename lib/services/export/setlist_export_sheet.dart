import 'package:flutter/material.dart';

import 'pdf_service.dart';

/// Bottom sheet that lets the user pick a setlist PDF layout.
/// Returns null if dismissed. Add option (c) chords+lyrics here when built.
Future<SetlistPdfLayout?> pickSetlistPdfLayout(BuildContext context) =>
    _pickPdfLayout(
      context,
      asIsSubtitle: 'One card per song, full detail',
      compactIcon: Icons.format_list_bulleted,
      compactSubtitle: 'One line per song, fits on one list',
    );

/// Same picker for a song performance-sheet PDF (#79): "As is" flows across
/// pages, "Compact" scales everything onto a single A4 page.
Future<SetlistPdfLayout?> pickSongSheetPdfLayout(BuildContext context) =>
    _pickPdfLayout(
      context,
      asIsSubtitle: 'Full size, flows across pages',
      compactIcon: Icons.fit_screen,
      compactSubtitle: 'Fit everything on one A4 page',
    );

Future<SetlistPdfLayout?> _pickPdfLayout(
  BuildContext context, {
  required String asIsSubtitle,
  required IconData compactIcon,
  required String compactSubtitle,
}) {
  return showModalBottomSheet<SetlistPdfLayout>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: const Text('As is'),
            subtitle: Text(asIsSubtitle),
            onTap: () => Navigator.pop(context, SetlistPdfLayout.detailed),
          ),
          ListTile(
            leading: Icon(compactIcon),
            title: const Text('Compact'),
            subtitle: Text(compactSubtitle),
            onTap: () => Navigator.pop(context, SetlistPdfLayout.compact),
          ),
        ],
      ),
    ),
  );
}
