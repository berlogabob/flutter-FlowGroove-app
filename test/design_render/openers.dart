import 'dart:async';

import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/event_kit.dart';
import 'package:flowgroove/models/instrument.dart';
import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/models/section.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/models/song_suggestion.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/data/midi_song_provider.dart';
import 'package:flowgroove/providers/tuner_provider.dart';
import 'package:flowgroove/screens/practice_regions/grid_editor_dialog.dart';
import 'package:flowgroove/screens/practice_regions/region_name_sheet.dart';
import 'package:flowgroove/screens/practice_regions/slice_edit_sheet.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_letters.dart';
import 'package:flowgroove/screens/practice_setup_wizard.dart';
import 'package:flowgroove/screens/setlists/event_kit_editor_screen.dart';
import 'package:flowgroove/screens/setlists/event_share_screen.dart';
import 'package:flowgroove/screens/setlists/performer_sheet.dart';
import 'package:flowgroove/screens/songs/components/csv_import_export/song_export_dialog.dart';
import 'package:flowgroove/screens/songs/components/csv_import_export/song_import_dialog.dart';
import 'package:flowgroove/screens/songs/components/import_lyrics_dialog.dart';
import 'package:flowgroove/screens/songs/components/lab_recording_sheet.dart';
import 'package:flowgroove/screens/songs/components/links_editor.dart';
import 'package:flowgroove/screens/songs/components/song_constructor/widgets/edit_section_dialog.dart';
import 'package:flowgroove/screens/songs/components/song_constructor/widgets/section_picker.dart';
import 'package:flowgroove/services/event_share_service.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flowgroove/widgets/app_menu_sheet.dart';
import 'package:flowgroove/widgets/confirmation_dialog.dart';
import 'package:flowgroove/widgets/custom_button.dart';
import 'package:flowgroove/widgets/invite_code_field.dart';
import 'package:flowgroove/widgets/metronome/backing_sheet.dart';
import 'package:flowgroove/widgets/metronome/bpm_input_overlay.dart';
import 'package:flowgroove/widgets/metronome/drum_practice_panel.dart';
import 'package:flowgroove/widgets/metronome/metronome_sheets.dart';
import 'package:flowgroove/widgets/metronome/reliability_sheet.dart';
import 'package:flowgroove/widgets/midi/arrangement_sheet.dart';
import 'package:flowgroove/widgets/midi/midi_song_panel.dart';
import 'package:flowgroove/widgets/practice/note_editor_sheet.dart';
import 'package:flowgroove/widgets/role_picker_widget.dart';
import 'package:flowgroove/widgets/share_sheet.dart';
import 'package:flowgroove/widgets/suggestion_selection_dialog.dart';
import 'package:flowgroove/widgets/support_sheet.dart';
import 'package:flowgroove/widgets/tag_input_dialog.dart';
import 'package:flowgroove/widgets/tools/tool_mode_switcher.dart';
import 'package:flowgroove/widgets/tuner/custom_tuning_editor.dart';
import 'package:flowgroove/widgets/tuner/instrument_picker.dart';
import 'package:flowgroove/widgets/tuner/settings_sheet.dart';
import 'package:flowgroove/widgets/tuner/stage_mode_overlay.dart';
import 'package:flowgroove/widgets/unified_item/setlist_card_actions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/mocks.dart';
import 'fixtures.dart';

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
  'grid_editor_dialog_tempo_grid': Opener(
    (context, _, _) => showGridEditorDialog(
      context,
      getGrid: () => const AudioGrid(bpm: 120),
      positionMs: () => 0,
      preciseTime: (_) => '00:00.000',
      onRemoveGrid: () async {},
    ),
  ),
  'notes_panel_note_at_n': Opener(
    (context, _, _) => showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Note at 1:23'),
        content: const TextField(
          decoration: InputDecoration(hintText: 'e.g. good chorus entry'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Add'),
          ),
        ],
      ),
    ),
  ),
  'slice_edit_sheet_start': Opener(
    (context, _, _) => showSliceEditSheet(
      context,
      regions: const [
        AudioRegion(
          id: 'region1',
          name: 'Night Set — Verse pad',
          startMs: 12000,
          endMs: 24000,
        ),
        AudioRegion(
          id: 'region2',
          name: 'Night Set — Chorus pad',
          startMs: 24000,
          endMs: 48000,
        ),
      ],
      i: 0,
      name: (region) => region.name,
      preciseTime: (ms) => '00:${(ms ~/ 1000).toString().padLeft(2, '0')}.000',
    ),
  ),
  'practice_regions_speed_n': Opener(
    (context, _, _) => showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.mp.surface,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(MonoPulseSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Speed 100%',
                  style: MonoPulseTypography.titleMedium,
                ),
                Wrap(
                  spacing: MonoPulseSpacing.sm,
                  children: [
                    for (final percent in [50, 60, 70, 75, 80, 85, 90, 100])
                      ChoiceChip(
                        label: Text('$percent%'),
                        selected: percent == 100,
                        onSelected: (_) {},
                      ),
                  ],
                ),
                const SizedBox(height: MonoPulseSpacing.md),
                const Text('Pre-roll', style: MonoPulseTypography.titleMedium),
                Wrap(
                  spacing: MonoPulseSpacing.sm,
                  children: [
                    for (final value in [0, 1, 2])
                      ChoiceChip(
                        label: Text('$value s'),
                        selected: value == 0,
                        onSelected: (_) {},
                      ),
                  ],
                ),
                const SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Click & drums'),
                  subtitle: Text('Needs a whole-number BPM grid'),
                  value: false,
                  onChanged: null,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'profile_currently_using': Opener(
    (context, _, _) => showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.mp.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.send, color: context.mp.textTertiary),
              title: const Text('Use Telegram Photo'),
              subtitle: Text(
                'Import photo from Telegram',
                style: TextStyle(color: context.mp.textTertiary),
              ),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: const Text('Use Google Photo'),
              onTap: () => Navigator.pop(context),
            ),
            for (final option in [
              (Icons.camera_alt, 'Take Photo'),
              (Icons.photo_library, 'Choose from Gallery'),
            ])
              ListTile(
                leading: Icon(option.$1),
                title: Text(option.$2),
                subtitle: const Text(
                  '✓ Currently using',
                  style: TextStyle(color: MonoPulseColors.success),
                ),
                onTap: () => Navigator.pop(context),
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: MonoPulseColors.error),
              title: const Text(
                'Remove Photo',
                style: TextStyle(color: MonoPulseColors.error),
              ),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ),
  ),
  'event_kit_editor_dialog_l103': Opener(
    (context, _, _) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share links inventory'),
        content: SizedBox(
          width: 480,
          height: MediaQuery.sizeOf(context).height * .55,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    for (final share in [
                      (
                        'Jordan Rivera',
                        'venue · stage: view, rider: view · active · 2024-05-12',
                      ),
                      (
                        'Sam Chen',
                        'sound_engineer · stage: edit · active · 2024-05-11',
                      ),
                      (
                        'Riley Park',
                        'client · setlist: view · active · 2024-05-10',
                      ),
                    ])
                      ListTile(
                        title: Text(share.$1),
                        subtitle: Text(share.$2),
                        trailing: IconButton(
                          tooltip: 'Revoke ${share.$1}',
                          icon: const Icon(Icons.link_off),
                          onPressed: () {},
                        ),
                      ),
                    Align(
                      child: TextButton(
                        onPressed: () {},
                        child: const Text('Load more'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
  ),
  'event_share_sheet_l106': Opener((context, tester, _) {
    showDialog<void>(
      context: context,
      builder: (_) => ProviderScope(
        overrides: [
          eventShareServiceProvider.overrideWithValue(
            EventShareService(
              invoker: (_, _) async => {
                'setlistId': 'setlist1',
                'name': 'Gig Setlist',
                'viewer': {
                  'canSuggest': true,
                  'access': {'runningOrder': 'view'},
                },
                'runningOrder': {
                  'ready': true,
                  'baseFingerprint': 'a' * 64,
                  'items': <Map<String, dynamic>>[],
                },
              },
            ),
          ),
        ],
        child: const EventShareScreen(),
      ),
    );
    void openWhenReady(Duration _) {
      final button = find.text('Suggest a change');
      if (button.evaluate().isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback(openWhenReady);
      } else {
        tester
            .widget<FloatingActionButton>(
              find.ancestor(
                of: button,
                matching: find.byType(FloatingActionButton),
              ),
            )
            .onPressed!();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback(openWhenReady);
  }),
  'song_map_part': Opener(
    (context, _, _) => showSectionNameSheet(
      context,
      initialName: 'Bridge',
      groups: const {
        'Intro': SongMapLetter('A', MonoPulseColors.section1),
        'Part B': SongMapLetter('B', MonoPulseColors.section5),
        'Chorus': SongMapLetter('C', MonoPulseColors.section8),
        'Part D': SongMapLetter('D', MonoPulseColors.section3),
        'Part E': SongMapLetter('E', MonoPulseColors.section11),
        'Bridge': SongMapLetter('F', MonoPulseColors.section7),
      },
    ),
  ),
  'song_map_part_light': Opener(
    (context, _, _) => showSectionNameSheet(
      context,
      initialName: 'Bridge',
      groups: const {
        'Intro': SongMapLetter('A', MonoPulseColors.section1),
        'Part B': SongMapLetter('B', MonoPulseColors.section5),
        'Chorus': SongMapLetter('C', MonoPulseColors.section8),
        'Part D': SongMapLetter('D', MonoPulseColors.section3),
        'Part E': SongMapLetter('E', MonoPulseColors.section11),
        'Bridge': SongMapLetter('F', MonoPulseColors.section7),
      },
    ),
  ),
  'performer_sheet_link_to_band_member': Opener(
    (context, _, _) => showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Link to band member')),
            for (final name in [
              'Max Rivera',
              'Jordan Lee',
              'Sam Okafor',
              'Priya Nair',
              'Diego Ferrer',
            ])
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(name),
                onTap: () => Navigator.pop(context),
              ),
          ],
        ),
      ),
    ),
  ),
  'performer_sheet_sheet_l32': Opener(
    (context, _, _) => showPerformerSheet(
      context: context,
      selected: const ['jake', 'mara'],
      kit: const EventKit(
        people: [
          EventPerson(
            id: 'jake',
            name: 'Jake Morris',
            role: 'Guitar',
            uid: 'member1',
          ),
          EventPerson(
            id: 'mara',
            name: 'Mara Velez',
            role: 'Bass',
            uid: 'member2',
          ),
          EventPerson(id: 'sam', name: 'Sam Okafor', role: 'Keys'),
          EventPerson(id: 'riley', name: 'Riley Dubois', role: 'Drums'),
        ],
      ),
      members: [
        BandMember(
          uid: 'member1',
          role: BandMember.roleAdmin,
          displayName: 'Jake Morris',
        ),
        BandMember(
          uid: 'member2',
          role: BandMember.roleEditor,
          displayName: 'Mara Velez',
        ),
      ],
      songNumber: 12,
      songTitle: 'Wonderwall',
    ),
  ),
  'api_access_revoke_key': Opener(
    (context, _, _) => showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('Revoke key'),
        content: const Text('Revoke sk_7f3a…? Any AI using it loses access.'),
        actions: [
          TextButton(onPressed: () {}, child: const Text('Cancel')),
          TextButton(onPressed: () {}, child: const Text('Revoke')),
        ],
      ),
    ),
  ),
  'links_editor_add_link': Opener((context, tester, _) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: LinksEditor(
          links: const [],
          onAddLink: (_) {},
          onRemoveLink: (_) {},
        ),
      ),
    );
    tester.binding.addPostFrameCallback((_) {
      tester.tap(find.text('Add'));
    });
  }),
  'suggestion_selection_dialog': Opener(
    (context, _, _) => showDialog<void>(
      context: context,
      builder: (context) => const SuggestionSelectionDialog(
        suggestion: SongSuggestion(
          id: 'suggestion1',
          title: 'Wonderwall',
          artist: 'Oasis',
          source: SuggestionSource.spotify,
          type: SuggestionType.exact,
          album: "What's the Story Afternoon?",
          releaseYear: 1995,
          bpm: 87,
          key: 'G',
        ),
      ),
    ),
  ),
  'event_kit_editor_sheet_l154': Opener((context, tester, _) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => EventKitEditorScreen(
          setlist: MockDataHelper.createMockSetlist(
            id: 'setlist1',
            bandId: 'band1',
            name: 'Gig Setlist',
          ),
          bandId: 'band1',
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tester.tap(find.byIcon(Icons.add).first);
    });
  }),
  'event_kit_editor_sheet_l181': Opener((context, tester, _) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => EventKitEditorScreen(
          setlist: MockDataHelper.createMockSetlist(
            id: 'setlist1',
            bandId: 'band1',
            name: 'Gig Setlist',
          ),
          bandId: 'band1',
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tester.tap(find.byIcon(Icons.add).first);
    });
  }),
  'event_kit_editor_brand_optional': Opener(
    (context, _, _) => showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Brand (optional)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Brand'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final brand in [
                    'Marshall',
                    'Orange',
                    'Vox AC30',
                    'Mesa Boogie',
                    'Fender Twin',
                    'Ampeg SVT',
                    'Roland JC-120',
                    'Hartke',
                    'Blackstar',
                    'Laney',
                    'Peavey',
                  ])
                    ChoiceChip(
                      label: Text(brand),
                      selected: brand == 'Vox AC30',
                      onSelected: (_) {},
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Custom brand',
                  hintText: 'Type a brand',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'Vox AC30'),
            child: const Text('Done'),
          ),
        ],
      ),
    ),
  ),
  'practice_regions_replace_n_sections': Opener(
    (context, _, _) => showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Replace 8 sections?'),
        content: const Text(
          'Your current sections will be replaced when you finish setup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    ),
  ),
  'practice_regions_replace_n_regions': Opener(
    (context, _, _) => showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Replace 9 regions?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    ),
  ),
  'practice_setup_wizard_sheet_l27': Opener(
    (context, _, _) => showPracticeSetupWizard(
      context,
      durationMs: 180000,
      detectGrid: () async => (bpm: 87.0, firstDownbeatMs: 12345),
      fileMarkers: () async => const [],
      previewGrid: (_) async {},
      newId: () => 'region1',
    ),
  ),
  'profile_link_telegram': Opener(
    (context, _, _) => showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.send),
        title: const Text('Link Telegram'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Link your Telegram account to automatically import your profile name and photo to FlowGroove.',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(dialogContext)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How it works:'),
                    SizedBox(height: 6),
                    Text('1. Click "Open Telegram" below'),
                    Text('2. Send /link command to the bot'),
                    Text('3. Tap "Yes, link my profile"'),
                    Text('4. Your name and photo will be imported'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          CustomButton(
            onPressed: () => Navigator.pop(dialogContext),
            icon: Icons.send,
            label: 'Open Telegram',
          ),
        ],
      ),
    ),
  ),
  'profile_delete_account': Opener(
    (context, _, _) => showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.delete_forever),
        title: const Text('Delete account'),
        content: const Text(
          'This permanently deletes your account and all your data — your '
          'songs, setlists, and band memberships. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () {}, child: const Text('Cancel')),
          TextButton(onPressed: () {}, child: const Text('Delete')),
        ],
      ),
    ),
  ),
  'recorder_link_recording_to_song': Opener(
    (context, _, _) => showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        const songs = [
          ('Wonderwall', 'Oasis'),
          ('Seven Nation Army', 'The White Stripes'),
          ('Valerie', 'Amy Winehouse'),
          ('Hey Jude', 'The Beatles'),
          ('Wonderwall', 'Oasis'),
          ('Wonderwall', 'Oasis'),
        ];
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Link recording to song')),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "Choose a song to attach this recording to. It will appear in that song's Lab timeline.",
                ),
              ),
              const ListTile(title: Text('SONGS')),
              for (var i = 0; i < songs.length; i++) ...[
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.music_note),
                  title: Text(songs[i].$1),
                  subtitle: Text(songs[i].$2),
                  trailing: const Icon(Icons.arrow_right),
                  onTap: () => Navigator.pop(sheetContext),
                ),
                if (i < songs.length - 1) const Divider(),
              ],
            ],
          ),
        );
      },
    ),
  ),
  'section_picker': Opener(
    (context, _, _) => showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: SectionPicker(onSectionSelected: (_) {}),
        ),
      ),
    ),
  ),
  'edit_section_dialog': Opener(
    (context, _, _) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditSectionDialog(
        section: Section(
          id: 'section1',
          name: 'Verse',
          duration: 3,
          notes: '',
          chordChart: '[Am]Twinkle [F]little [C]star',
        ),
      ),
    ),
  ),
  'setlist_export_sheet_whose_copy': Opener(
    (context, _, _) => showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: const [
            ListTile(title: Text('Whose copy?')),
            Divider(),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Marcus Reed'),
              subtitle: Text('#1, #3, #5, #7'),
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Dana Kowalski'),
              subtitle: Text('#2, #6'),
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Devon Diaz'),
              subtitle: Text('#4, #8, #10'),
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Priya Nair'),
              subtitle: Text('#9'),
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Sam Okafor'),
              subtitle: Text('#1, #2, #4, #6, #8, #10'),
            ),
          ],
        ),
      ),
    ),
  ),
  'setlist_card_actions_quick_action': Opener(
    (context, _, _) => showDialog<void>(
      context: context,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showSetlistQuickActionPicker(context, ref);
          });
          return const SizedBox.shrink();
        },
      ),
    ),
  ),
  'song_card_actions_sheet_l209': Opener(
    (context, _, _) => showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: const [
            ListTile(title: Text('Add to band…')),
            ListTile(title: Text('Choose the band to save "Wonderwall" to')),
            Divider(),
            ListTile(
              leading: Icon(Icons.groups),
              title: Text('FlowGroove'),
              subtitle: Text('Rehearsal Fri 7pm'),
              trailing: Icon(Icons.check),
            ),
            ListTile(
              leading: Icon(Icons.groups),
              title: Text('The Weekend Set'),
              subtitle: Text("4 members · You're editor"),
            ),
            ListTile(
              leading: Icon(Icons.groups),
              title: Text('Sunday Jam'),
              subtitle: Text('2 members'),
            ),
            ListTile(
              leading: Icon(Icons.groups),
              title: Text('Cover Crew'),
              subtitle: Text('1 member'),
            ),
          ],
        ),
      ),
    ),
  ),
  'add_song_helper_search_on_web': Opener(
    (context, _, _) => showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Search on Web'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Open Spotify search in browser?'),
            const SizedBox(height: 16),
            const Text(
              'Wonderwall Oasis',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          CustomButton(
            onPressed: () => Navigator.pop(dialogContext),
            label: 'Open Spotify',
          ),
        ],
      ),
    ),
  ),
  'drum_practice_panel': Opener(
    (context, _, _) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const DrumPracticePanel(songId: 'song1', bandId: 'band1'),
    ),
  ),
  'drum_grid_editor': Opener((context, tester, _) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const DrumPracticePanel(songId: 'song1'),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tester.tap(find.text('New pattern'));
    });
  }),
  'song_import_dialog': Opener(
    (context, _, _) => showDialog<void>(
      context: context,
      builder: (_) => const SongImportDialog(librarySongs: []),
    ),
  ),
  'songs_list_importing_songs': Opener(
    (context, _, _) => showDialog<void>(
      context: context,
      builder: (_) => const SongImportDialog(librarySongs: []),
    ),
  ),
  'song_export_dialog': Opener(
    (context, _, _) => showDialog<void>(
      context: context,
      builder: (_) => SongExportDialog(
        songs: List.generate(
          128,
          (index) => Song(
            id: 'song${index + 1}',
            title: index == 0 ? 'First Song' : 'Song ${index + 1}',
            artist: 'Test Artist',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
        ),
      ),
    ),
  ),
  'songs_list_filter_options': Opener(
    (_, tester, _) => tester
        .widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Key / BPM'),
        )
        .onPressed!(),
    route: '/main/songs',
  ),
  'tuner_stage': Opener(
    (context, _, _) => showDialog<void>(
      context: context,
      builder: (_) => ProviderScope(
        overrides: [tunerProvider.overrideWith(_StageTuner.new)],
        child: const StageModeOverlay(child: SizedBox.expand()),
      ),
    ),
  ),
  'tuner_tone': Opener((context, tester, _) {
    tester
        .widget<ToolModeSwitcher<TunerMode>>(
          find.byType(ToolModeSwitcher<TunerMode>),
        )
        .onModeChanged(TunerMode.generate);
  }, route: '/main/tuner'),
  'custom_tuning_editor': Opener(
    (context, _, _) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CustomTuningEditor(),
    ),
    route: '/main/tuner',
  ),
  'lab_recording_sheet': Opener(
    (context, _, _) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const LabRecordingSheet(),
    ),
  ),
  'app_menu_sheet_sheet_l53': Opener(
    (context, _, _) => showAppMenuSheet(
      context,
      title: 'More',
      items: const [
        AppMenuItem(icon: Icons.av_timer, label: 'Metronome'),
        AppMenuItem(icon: Icons.tune, label: 'Tuner'),
        AppMenuItem(icon: Icons.mic_outlined, label: 'Recorder'),
      ],
      showProfileRow: true,
    ),
  ),
  'bpm_input_overlay_sheet_l15': Opener(
    (context, _, _) => showTempoInputSheet(context),
  ),
  'instrument_picker': Opener(
    (context, _, _) => showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ProviderScope(
        overrides: [tunerProvider.overrideWith(_PickerTuner.new)],
        child: const InstrumentPicker(),
      ),
    ),
  ),
  'midi_song_panel': Opener(
    (context, _, _) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // Practice notifier is overridden in fixtures.dart (root): the panel's loader
      // provider is not scoped, so a nested override would not reach it.
      builder: (_) => MidiSongPanel(entry: kRenderMidiEntry),
    ),
  ),
  'tuner_settings_sheet': Opener(
    (context, _, _) => showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const TunerSettingsSheet(),
    ),
  ),
  'metronome_sheets_sheet_l14': Opener(
    (context, _, _) => showSoundSheet(context),
  ),
  'reliability_sheet_keep_timing_reliable': Opener(
    (context, _, _) => showReliabilitySheet(context),
  ),
  'song_library_block_sheet_l85': Opener((_, tester, _) {
    tester
        .widget<InkWell>(
          find
              .ancestor(
                of: find.text('Songs & Setlists'),
                matching: find.byType(InkWell),
              )
              .first,
        )
        .onTap!();
  }, route: '/main/metronome'),
  'midi_import_flow_import_midi': Opener(
    (context, _, _) => showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import MIDI'),
        content: const Text('Not a valid MIDI file'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    ),
  ),
  'note_editor_sheet': Opener(
    (context, _, _) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => NoteEditorSheet(
        track: const MidiTrackMeta(
          index: 0,
          name: 'Bass',
          channel: 0,
          program: 0,
          detectedRole: MidiRole.bass,
          noteCount: 6,
          minPitch: 45,
          maxPitch: 55,
        ),
        notes: const [
          MidiNote(tick: 120, dur: 120, pitch: 45, vel: 100),
          MidiNote(tick: 480, dur: 120, pitch: 45, vel: 100),
          MidiNote(tick: 240, dur: 120, pitch: 48, vel: 100),
          MidiNote(tick: 720, dur: 120, pitch: 48, vel: 100),
          MidiNote(tick: 360, dur: 120, pitch: 50, vel: 100),
          MidiNote(tick: 59520, dur: 120, pitch: 55, vel: 100),
        ],
        ppq: 480,
        beatsPerBar: 4,
        sections: const [],
        onApply: (_) {},
      ),
    ),
  ),
  'arrangement_sheet': Opener((context, _, _) {
    final entry = SongLabEntry(
      id: 'arrangement1',
      songId: 'song3',
      bandId: 'band1',
      type: LabEntryType.midi,
      authorId: 'test-user',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      midiSong: const MidiSongMeta(
        fileUrl: 'render-fixture',
        ppq: 480,
        initialBpm: 120,
        startBar: 4,
        useFileTempo: true,
        tracks: [],
      ),
    );
    final notes = [
      const MidiNote(tick: 3840, dur: 241920, pitch: 48, vel: 100),
    ];
    final midi = MidiSongData(
      ppq: 480,
      tempos: [const TempoChange(tick: 0, microsPerQuarter: 500000)],
      timeSigs: const [TimeSigChange(tick: 0, numerator: 4, denominator: 4)],
      tracks: [
        for (var i = 0; i < 4; i++)
          MidiTrackData(
            index: i,
            name: 'Instrument ${i + 1}',
            channel: i,
            program: i,
            notes: notes,
          ),
      ],
    );
    final song = Song(
      id: 'song3',
      title: 'Third Song',
      artist: 'Test Artist',
      bandId: 'band1',
      ourBPM: 106,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      sections: [
        for (final name in ['Intro', 'Verse', 'Chorus', 'Bridge', 'Outro'])
          Section(id: name.toLowerCase(), name: name),
      ],
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ProviderScope(
        overrides: [
          midiSongProvider(entry).overrideWith((ref) => midi),
          bandSongsProvider('band1')
              .overrideWith((ref) => Stream.value([song])),
        ],
        child: ArrangementSheet(entry: entry, bandId: 'band1'),
      ),
    );
  }),
  'share_sheet_copy_to_clipboard': Opener(
    (context, _, _) => showShareSheet(context, 'First Song'),
  ),
  'support_sheet_telegram': Opener(
    (context, _, _) => showSupportSheet(context),
  ),
};

class _StageTuner extends TunerNotifier {
  @override
  TunerState build() => const TunerState(
    note: 'C4',
    frequency: 262,
    cents: 4,
    isListening: true,
    stageModeActive: true,
    selectedInstrument: Instrument(
      id: 'guitar',
      name: 'Guitar',
      subtitle: '',
      origin: '',
      icon: '',
      stringCount: 6,
      stringLabels: [],
      tunings: [],
    ),
    selectedTuning: Tuning(id: 'standard', name: 'Standard', notes: []),
  );
}

const _kGuitar = Instrument(
  id: 'guitar',
  name: 'Guitar',
  subtitle: '6 strings',
  origin: '',
  icon: '',
  stringCount: 6,
  stringLabels: [],
  tunings: [
    Tuning(
      id: 'standard',
      name: 'Standard',
      notes: ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'],
    ),
  ],
);

/// Two instruments, guitar selected: the picker builds its ListTile rows (F92).
class _PickerTuner extends TunerNotifier {
  @override
  TunerState build() => const TunerState(
    instruments: [
      _kGuitar,
      Instrument(
        id: 'bass',
        name: 'Bass',
        subtitle: '4 strings',
        origin: '',
        icon: '',
        stringCount: 4,
        stringLabels: [],
        tunings: [
          Tuning(
            id: 'standard',
            name: 'Standard',
            notes: ['E1', 'A1', 'D2', 'G2'],
          ),
        ],
      ),
    ],
    selectedInstrument: _kGuitar,
    selectedTuning: Tuning(
      id: 'standard',
      name: 'Standard',
      notes: ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'],
    ),
  );

  @override
  Future<void> stopAll() async {}
}
