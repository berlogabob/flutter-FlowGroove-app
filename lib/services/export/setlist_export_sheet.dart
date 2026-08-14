import 'package:flutter/material.dart';

import '../../models/event_kit.dart';
import '../../models/lineup.dart';
import '../../models/setlist.dart';
import 'pdf_service.dart';

/// Bottom sheet that lets the user pick a setlist PDF layout.
/// Returns null if dismissed.
Future<SetlistPdfLayout?> pickSetlistPdfLayout(
  BuildContext context, {
  bool withEventGuide = false,
  bool withPerformer = false,
}) => _pickPdfLayout(
  context,
  asIsSubtitle: 'One card per song, full detail',
  compactIcon: Icons.format_list_bulleted,
  compactSubtitle: 'One line per song, fits on one list',
  withPack: true,
  withCheatSheet: true,
  withEventGuide: withEventGuide,
  withPerformer: withPerformer,
);

/// Layout picker + (for the one-musician layout) who it's for. Gates the
/// Event guide / One musician options on the setlist actually having a kit
/// and assignments. Returns null if either step is dismissed.
Future<({SetlistPdfLayout layout, String? performerId})?> pickSetlistPdfExport(
  BuildContext context,
  Setlist setlist,
) async {
  final items = setlist.effectiveItems;
  final layout = await pickSetlistPdfLayout(
    context,
    withEventGuide: setlist.eventKit?.isEmpty == false,
    withPerformer: hasAssignments(items),
  );
  if (layout == null) return null;
  if (layout != SetlistPdfLayout.performer) {
    return (layout: layout, performerId: null);
  }
  if (!context.mounted) return null;
  // Only offer people who actually play something.
  final assigned = songNumbersByPerformer(items);
  final people = [
    for (final person in setlist.eventKit?.people ?? const <EventPerson>[])
      if (assigned.containsKey(person.id)) person,
  ];
  final performer = await showModalBottomSheet<EventPerson>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('Whose copy?')),
          for (final person in people)
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(person.name),
              subtitle: Text(
                assigned[person.id]!.map((n) => '#$n').join(', '),
              ),
              onTap: () => Navigator.pop(context, person),
            ),
        ],
      ),
    ),
  );
  if (performer == null) return null;
  return (layout: layout, performerId: performer.id);
}

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
  bool withPack = false,
  bool withCheatSheet = false,
  bool withEventGuide = false,
  bool withPerformer = false,
}) {
  return showModalBottomSheet<SetlistPdfLayout>(
    context: context,
    builder: (context) => SafeArea(
      // Scrolls: with every option enabled the list outgrows small screens.
      child: ListView(
        shrinkWrap: true,
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
          if (withPack)
            ListTile(
              leading: const Icon(Icons.library_music),
              title: const Text('SetlistPack'),
              subtitle: const Text(
                'Compact setlist + one-page sheet per song',
              ),
              onTap: () => Navigator.pop(context, SetlistPdfLayout.pack),
            ),
          if (withCheatSheet)
            ListTile(
              leading: const Icon(Icons.grid_on),
              title: const Text('Cheat sheet'),
              subtitle: const Text(
                'All songs on one page: key, BPM, chord progressions',
              ),
              onTap: () => Navigator.pop(context, SetlistPdfLayout.cheatSheet),
            ),
          if (withEventGuide)
            ListTile(
              leading: const Icon(Icons.theater_comedy),
              title: const Text('Event guide'),
              subtitle: const Text(
                'Cover + setlist + stage plot + role cards + rider',
              ),
              onTap: () =>
                  Navigator.pop(context, SetlistPdfLayout.eventGuide),
            ),
          if (withPerformer)
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('One musician'),
              subtitle: const Text(
                'Full running order, only their songs highlighted',
              ),
              onTap: () => Navigator.pop(context, SetlistPdfLayout.performer),
            ),
        ],
      ),
    ),
  );
}
