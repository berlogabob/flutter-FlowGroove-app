import 'package:flowgroove/widgets/confirmation_dialog.dart';
import 'package:flowgroove/widgets/custom_button.dart';
import 'package:flowgroove/widgets/invite_code_field.dart';
import 'package:flowgroove/widgets/metronome/backing_sheet.dart';
import 'package:flowgroove/widgets/role_picker_widget.dart';
import 'package:flowgroove/widgets/tag_input_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:flowgroove/screens/songs/components/import_lyrics_dialog.dart';

/// How to show a spec that has no route of its own (sheet, dialog, picker).
///
/// Modal specs describe the modal only, so [route] is just a backdrop; parity
/// compares the top route. [open] calls the app's own show helper (or taps the
/// real trigger) after the backdrop has settled. Do not await the returned
/// Future of a show helper: it completes only when the modal closes.
class Opener {
  const Opener(this.open, {this.route = '/main/home'});

  final String route;
  final void Function(
    BuildContext context,
    WidgetTester tester,
    GoRouter router,
  )
  open;
}

BuildContext hostContext(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).last);

final kOpeners = <String, Opener>{
  'confirmation_dialog': Opener(
    (context, _, _) => showDialog<bool>(
      context: context,
      builder: (_) => const ConfirmationDialog(
        title: 'Save trim?',
        message:
            'This replaces the original recording. The part outside the '
            'kept sections is gone for good.',
        confirmLabel: 'Trim',
        icon: Icons.content_cut,
      ),
    ),
  ),
  'role_picker_dialog': Opener(
    (context, _, _) => showRolePicker(context: context, currentRoles: const []),
  ),
  'tag_input_dialog': Opener((context, _, _) => TagInputDialog.show(context)),
  'song_form_provider_similar_song_exists': Opener(
    (context, _, _) => showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('Similar Song Exists'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"Wonderwall" by Oasis',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            const Text(
              'A similar song already exists in your library. Do you want to:',
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () {}, child: const Text('Cancel')),
          TextButton(onPressed: () {}, child: const Text('Save Anyway')),
        ],
      ),
    ),
  ),
  'create_band_discard_changes': Opener(
    (context, _, _) => showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to discard them?',
        ),
        actions: [
          TextButton(onPressed: () {}, child: const Text('Cancel')),
          TextButton(onPressed: () {}, child: const Text('Discard')),
        ],
      ),
    ),
  ),
  'create_band_band_created': Opener(
    (context, _, _) => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Band Created!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this invite code with your bandmates:'),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: InviteCodeField(code: 'KQ7X2M')),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy',
                ),
              ],
            ),
          ],
        ),
        actions: [TextButton(onPressed: () {}, child: const Text('Done'))],
      ),
    ),
  ),
  'rehearsal_detail_suggest_a_different_time': Opener(
    (context, _, _) => showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: 'Sunday 18:00?');
        return AlertDialog(
          title: const Text('Suggest a different time'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'e.g. Sunday 18:00?'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Send'),
            ),
          ],
        );
      },
    ),
  ),
  'the_band_edit_band_name': Opener(
    (context, _, _) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Band Name'),
        content: TextField(
          controller: TextEditingController(text: 'FlowGroove'),
          decoration: InputDecoration(
            labelText: 'Band Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: () {}, child: const Text('Save')),
        ],
      ),
    ),
  ),
  'the_band_edit_description': Opener(
    (context, _, _) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Description'),
        content: TextField(
          controller: TextEditingController(text: 'Rock band from Portland.'),
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
            hintText: 'Enter band description...',
          ),
          maxLines: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: () {}, child: const Text('Save')),
        ],
      ),
    ),
  ),
  'home_sheet_l112': Opener(
    (context, _, _) => showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('Rehearsals — choose a band'),
              subtitle: const Text(
                'Rehearsals are per band — choose one to see its schedule.',
              ),
            ),
            const Divider(),
            for (final bandName in [
              'The Groove Collective',
              'Neon Drifters',
              'Basement Static',
              'Cedar & Rue',
            ])
              ListTile(
                leading: const Icon(Icons.event),
                title: Text(bandName),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => Navigator.pop(sheetContext),
              ),
          ],
        ),
      ),
    ),
  ),
  'home_rehearsals': Opener(
    (context, _, _) => showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Rehearsals — choose a band'),
              subtitle: Text(
                'Rehearsals are per band — choose one to see its schedule.',
              ),
            ),
            const Divider(),
            for (final bandName in [
              'FlowGroove',
              'The Neon Skyline',
              'Midnight Canvas',
              'Solar Flare',
              'Paper Planes Quartet',
            ])
              ListTile(
                leading: const Icon(Icons.event),
                title: Text(bandName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(sheetContext),
              ),
          ],
        ),
      ),
    ),
  ),
  'metronome_launchpad': Opener((_, _, router) => router.go('/main/metronome')),
  'backing_sheet': Opener(
    (context, _, _) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const BackingSheet(songId: 'song1', bandId: 'band1'),
    ),
  ),
  'import_lyrics_dialog': Opener((context, tester, _) {
    const lyrics =
        '{title: Back to Black}\n'
        '{artist: Amy Winehouse}\n'
        '{key: Dm}\n'
        '{tempo: 123}\n\n'
        '{start_of_verse: Verse 1}\n'
        '[Dm]He left no time to [Gm]regret\n'
        '{end_of_verse}\n'
        '{start_of_chorus}\n'
        '[C]For love is [G]the thing that [Am]keeps me breathing\n'
        '{end_of_chorus}\n'
        '{start_of_verse: Verse 2}\n'
        '[Dm]No [Am]room for an[n]y other\n'
        '{end_of_verse}';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ImportLyricsDialog(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final field = tester.widget<TextField>(find.byType(TextField));
      field.controller!.text = lyrics;
      field.onChanged!(lyrics);
    });
  }),
  'performance_sheet_you_already_have_a_song_map': Opener(
    (context, _, _) => showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('You already have a song map'),
        content: const Text(
          'Replace it with the imported one, or append the imported sections?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Append'),
          ),
          CustomButton(
            onPressed: () => Navigator.pop(dialogContext),
            label: 'Replace',
          ),
        ],
      ),
    ),
  ),
};
