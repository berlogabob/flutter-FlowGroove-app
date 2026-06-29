import 'package:flutter/material.dart';

import 'pdf_service.dart';

/// Bottom sheet that lets the user pick a setlist PDF layout.
/// Returns null if dismissed. Add option (c) chords+lyrics here when built.
Future<SetlistPdfLayout?> pickSetlistPdfLayout(BuildContext context) {
  return showModalBottomSheet<SetlistPdfLayout>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: const Text('As is'),
            subtitle: const Text('One card per song, full detail'),
            onTap: () =>
                Navigator.pop(context, SetlistPdfLayout.detailed),
          ),
          ListTile(
            leading: const Icon(Icons.format_list_bulleted),
            title: const Text('Compact'),
            subtitle: const Text('One line per song, fits on one list'),
            onTap: () => Navigator.pop(context, SetlistPdfLayout.compact),
          ),
        ],
      ),
    ),
  );
}
