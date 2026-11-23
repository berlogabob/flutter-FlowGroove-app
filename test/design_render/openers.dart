import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/event_kit.dart';
import 'package:flowgroove/models/instrument.dart';
import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/models/rehearsal.dart';
import 'package:flowgroove/models/section.dart';
import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/models/song_suggestion.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/data/midi_song_provider.dart';
import 'package:flowgroove/providers/permissions_provider.dart';
import 'package:flowgroove/providers/tuner_provider.dart';
import 'package:flowgroove/screens/bands/create_band_screen.dart';
import 'package:flowgroove/screens/bands/rehearsals/rehearsal_detail_screen.dart';
import 'package:flowgroove/screens/bands/the_band_screen.dart';
import 'package:flowgroove/screens/home_screen.dart';
import 'package:flowgroove/screens/practice_regions/grid_editor_dialog.dart';
import 'package:flowgroove/screens/practice_regions/region_name_sheet.dart';
import 'package:flowgroove/screens/practice_regions/slice_edit_sheet.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_letters.dart';
import 'package:flowgroove/screens/practice_regions_screen.dart';
import 'package:flowgroove/screens/practice_setup_wizard.dart';
import 'package:flowgroove/screens/profile_screen.dart';
import 'package:flowgroove/screens/recorder_screen.dart';
import 'package:flowgroove/screens/setlists/event_kit_editor_screen.dart';
import 'package:flowgroove/screens/setlists/event_share_screen.dart';
import 'package:flowgroove/screens/setlists/performer_sheet.dart';
import 'package:flowgroove/screens/settings/api_access_screen.dart';
import 'package:flowgroove/screens/songs/add_song_screen.dart';
import 'package:flowgroove/screens/songs/components/csv_import_export/song_export_dialog.dart';
import 'package:flowgroove/screens/songs/components/csv_import_export/song_import_dialog.dart';
import 'package:flowgroove/screens/songs/components/import_lyrics_dialog.dart';
import 'package:flowgroove/screens/songs/components/lab_recording_sheet.dart';
import 'package:flowgroove/screens/songs/components/links_editor.dart';
import 'package:flowgroove/screens/songs/components/song_constructor/widgets/edit_section_dialog.dart';
import 'package:flowgroove/screens/songs/components/song_constructor/widgets/section_picker.dart';
import 'package:flowgroove/screens/songs/components/song_form.dart';
import 'package:flowgroove/screens/songs/models/song_form_data.dart';
import 'package:flowgroove/screens/songs/song_editor_screen.dart';
import 'package:flowgroove/services/event_share_service.dart';
import 'package:flowgroove/services/export/setlist_export_sheet.dart';
import 'package:flowgroove/services/idea_recorder.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flowgroove/widgets/confirmation_dialog.dart';
import 'package:flowgroove/widgets/custom_button.dart';
import 'package:flowgroove/widgets/metronome/backing_sheet.dart';
import 'package:flowgroove/widgets/metronome/bpm_input_overlay.dart';
import 'package:flowgroove/widgets/metronome/drum_practice_panel.dart';
import 'package:flowgroove/widgets/metronome/metronome_sheets.dart';
import 'package:flowgroove/widgets/metronome/reliability_sheet.dart';
import 'package:flowgroove/widgets/midi/arrangement_sheet.dart';
import 'package:flowgroove/widgets/midi/midi_song_panel.dart';
import 'package:flowgroove/widgets/practice/note_editor_sheet.dart';
import 'package:flowgroove/widgets/primary_action_bar.dart';
import 'package:flowgroove/widgets/role_picker_widget.dart';
import 'package:flowgroove/widgets/share_sheet.dart';
import 'package:flowgroove/widgets/standard_screen_scaffold.dart';
import 'package:flowgroove/widgets/suggestion_selection_dialog.dart';
import 'package:flowgroove/widgets/support_sheet.dart';
import 'package:flowgroove/widgets/tag_input_dialog.dart';
import 'package:flowgroove/widgets/tool_button.dart';
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
import 'package:mockito/mockito.dart';

import '../helpers/mocks.dart';
import '../helpers/mocks.mocks.dart';
import '../screens/practice_regions_screen_test.dart';
import 'fixtures.dart';

/// How to show a spec that has no route of its own (sheet, dialog, picker).
///
/// Modal specs describe the modal only, so [route] is just a backdrop; parity
/// compares the top route. [open] calls the app's own show helper (or taps the
/// real trigger) after the backdrop has settled. Do not await the returned
/// Future of a show helper: it completes only when the modal closes.
class Opener {
  const Opener(
    this.open, {
    this.route = '/main/home',
    this.realAsync = false,
    this.then,
  });

  /// Real taps and typing after [open] and the first settle (awaited).
  final Future<void> Function(WidgetTester tester)? then;

  final String route;

  /// The show helper awaits a platform or IO future before showing the modal:
  /// the render waits briefly in real time after [open] (fake time never
  /// completes it). Off by default: real time also lets plugin calls through.
  final bool realAsync;
  final void Function(
    BuildContext context,
    WidgetTester tester,
    GoRouter router,
  )
  open;
}

/// Runs [action] on the first element of [finder] at the end of the first frame
/// that builds it (up to [frames] frames). Openers are synchronous, the render
/// test pumps after them, so triggers that appear late (streams, pushed routes)
/// need this.
void tapWhenBuilt(
  Finder finder,
  void Function(Element element) action, {
  int frames = 20,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final found = finder.evaluate();
    if (found.isNotEmpty) {
      action(found.first);
    } else if (frames > 1) {
      tapWhenBuilt(finder, action, frames: frames - 1);
    } else {
      throw StateError('opener trigger never built: $finder');
    }
  });
  // A settled tree schedules no frames: ask for one, or the callback never runs.
  WidgetsBinding.instance.scheduleFrame();
}

BuildContext hostContext(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).last);

final kOpeners = <String, Opener>{
  'forgot_password': Opener(
    (_, _, _) {},
    route: '/login',
    then: (tester) async {
      // The app pushes this screen from the login form, so it has a back arrow.
      final forgot = find.widgetWithText(TextButton, 'Forgot Password?');
      await tester.ensureVisible(forgot);
      await tester.tap(forgot);
      await tester.pumpAndSettle();
    },
  ),
  'rehearsal_edit': Opener(
    (_, _, _) {},
    route: '/main/bands/band1/rehearsals/reh1',
    then: (tester) async {
      // Detail screen -> its real 'Edit details' button.
      final edit = find.widgetWithText(TextButton, 'Edit details');
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
    },
  ),
  'join_band': Opener(
    (_, _, _) {},
    route: '/main/join-band',
    then: (tester) async {
      await tester.runAsync(setupRenderBandInvite);
      await tester.enterText(find.byType(TextField), 'abc123');
      await tester.tap(find.text('Find Band'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    },
  ),
  'create_setlist': Opener(
    (_, _, _) {},
    route: '/main/setlists/create',
    then: (tester) async {
      await tester.enterText(find.byType(TextField).first, 'Friday Night');
      await tester.tap(find.widgetWithText(TextButton, 'Add'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      for (final title in ['Wonderwall', 'Seven Nation Army', 'Valerie']) {
        await tester.tap(find.text(title));
      }
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
    },
  ),
  'canonical_browse': Opener(
    (_, _, _) {},
    route: '/main/songs/catalog',
    then: (tester) async {
      await tester.enterText(find.byType(TextField), 'love');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    },
  ),
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
    (context, _, _) => showRolePicker(
      context: context,
      currentRoles: const ['guitarist', 'drummer', 'Bass Player'],
    ),
  ),
  'tag_input_dialog': Opener(
    (context, _, _) => TagInputDialog.show(
      context,
      initialTags: const ['setlist', 'crowd-pleaser', 'working-title'],
      suggestions: const ['live', 'studio', 'cover', 'soundcheck'],
    ),
  ),
  'song_form_provider_similar_song_exists': Opener((context, _, _) {
    final user = MockUser();
    when(user.uid).thenReturn('user1');
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => AsyncValue.data(user)),
            songRepositoryProvider.overrideWith(
              (ref) => RenderSongRepository(),
            ),
          ],
          child: AddSongScreen(
            initialFormData: SongFormData(
              title: 'First Song',
              artist: 'Test Artist',
            ),
          ),
        ),
      ),
    );
    tapWhenBuilt(
      find.byType(SongForm, skipOffstage: false),
      (element) =>
          (find
                      .byType(PrimaryActionBar, skipOffstage: false)
                      .evaluate()
                      .last
                      .widget
                  as PrimaryActionBar)
              .onPressed!(),
    );
    tapWhenBuilt(find.byType(AlertDialog), (element) {
      expect(find.text('"First Song" by Test Artist'), findsOneWidget);
    });
  }),
  'create_band_discard_changes': Opener((context, _, _) {
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute<void>(builder: (_) => const CreateBandScreen()));
    tapWhenBuilt(find.byType(EditableText, skipOffstage: false), (element) {
      ((element as StatefulElement).state as EditableTextState)
          .userUpdateTextEditingValue(
            const TextEditingValue(text: 'Test Band'),
            SelectionChangedCause.keyboard,
          );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(element).maybePop();
      });
    });
    tapWhenBuilt(find.byType(AlertDialog), (_) {
      expect(
        find.byType(CreateBandScreen, skipOffstage: false),
        findsOneWidget,
      );
    });
  }),
  'create_band_band_created': Opener((context, _, _) {
    final user = MockUser();
    when(user.uid).thenReturn('user1');
    when(user.displayName).thenReturn('Test User');
    when(user.email).thenReturn(null);
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => AsyncValue.data(user)),
          ],
          child: const CreateBandScreen(),
        ),
      ),
    );
    tapWhenBuilt(find.byType(EditableText, skipOffstage: false), (element) {
      ((element as StatefulElement).state as EditableTextState)
          .userUpdateTextEditingValue(
            const TextEditingValue(text: 'Test Band'),
            SelectionChangedCause.keyboard,
          );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final action = find.byType(PrimaryActionBar, skipOffstage: false);
        (action.evaluate().last.widget as PrimaryActionBar).onPressed!();
      });
    });
    tapWhenBuilt(find.byType(AlertDialog), (_) {
      expect(
        find.byType(CreateBandScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('Band Created!'), findsOneWidget);
    });
  }),
  'rehearsal_detail_suggest_a_different_time': Opener((context, _, _) {
    final user = MockUser();
    when(user.uid).thenReturn('user1');
    final band = MockDataHelper.createMockBand(id: 'band1', name: 'Test Band');
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => AsyncValue.data(user)),
            rehearsalVotesProvider(('band1', 'reh1')).overrideWith(
              (ref) => Stream.value({
                'user1': RehearsalVote(
                  uid: 'user1',
                  answers: const {},
                  comment: 'Sunday 18:00?',
                  updatedAt: DateTime(2024),
                ),
              }),
            ),
          ],
          child: RehearsalDetailScreen(band: band, rehearsalId: 'reh1'),
        ),
      ),
    );
    tapWhenBuilt(
      find.text('None of these work — suggest a time', skipOffstage: false),
      (element) =>
          element.findAncestorWidgetOfExactType<TextButton>()!.onPressed!(),
    );
    tapWhenBuilt(find.byType(AlertDialog), (_) {
      expect(
        find.byType(RehearsalDetailScreen, skipOffstage: false),
        findsOneWidget,
      );
    });
  }),
  'the_band_edit_band_name': Opener((context, _, router) {
    router.pushNamed('the-band', pathParameters: {'id': 'band1'});
    tapWhenBuilt(
      find.byWidgetPredicate(
        (widget) =>
            widget is StandardScreenScaffold &&
            widget.menuItems?.any((item) => item.label == 'Edit Band Name') ==
                true,
        skipOffstage: false,
      ),
      (element) => (element.widget as StandardScreenScaffold).menuItems!
          .firstWhere((item) => item.label == 'Edit Band Name')
          .onTap!(),
    );
    tapWhenBuilt(find.byType(AlertDialog), (_) {
      expect(find.byType(TheBandScreen, skipOffstage: false), findsOneWidget);
    });
  }),
  'the_band_edit_description': Opener((context, _, router) {
    router.pushNamed('the-band', pathParameters: {'id': 'band1'});
    tapWhenBuilt(
      find.byWidgetPredicate(
        (widget) =>
            widget is StandardScreenScaffold &&
            widget.menuItems?.any((item) => item.label == 'Edit Description') ==
                true,
        skipOffstage: false,
      ),
      (element) => (element.widget as StandardScreenScaffold).menuItems!
          .firstWhere((item) => item.label == 'Edit Description')
          .onTap!(),
    );
    tapWhenBuilt(find.byType(AlertDialog), (_) {
      expect(find.byType(TheBandScreen, skipOffstage: false), findsOneWidget);
    });
  }),
  'home_sheet_l112': Opener((context, _, _) {
    // _openRehearsals with 2+ bands shows the real band picker sheet.
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => ProviderScope(
          overrides: [
            bandsProvider.overrideWith(
              (ref) => Stream.value([
                MockDataHelper.createMockBand(
                  id: 'band1',
                  name: 'The Groove Collective',
                ),
                MockDataHelper.createMockBand(
                  id: 'band2',
                  name: 'Neon Drifters',
                ),
              ]),
            ),
          ],
          child: const HomeScreen(),
        ),
      ),
    );
    tapWhenBuilt(
      find
          .byWidgetPredicate(
            (widget) => widget is ToolButton && widget.label == 'Rehearsals',
            skipOffstage: false,
          )
          .last,
      (element) {
        // _openRehearsals reads bandsProvider once: start the stream, tap a
        // frame later, as a user does after Home has loaded (F121).
        final container = ProviderScope.containerOf(element);
        final sub = container.listen(bandsProvider, (_, _) {});
        void tapWhenLoaded([Duration? _]) {
          if (container.read(bandsProvider).hasValue) {
            sub.close();
            (element.widget as ToolButton).onTap!();
          } else {
            WidgetsBinding.instance.addPostFrameCallback(tapWhenLoaded);
            WidgetsBinding.instance.scheduleFrame();
          }
        }

        tapWhenLoaded();
      },
    );
  }),
  'home_rehearsals': Opener(
    (_, _, _) {},
    then: (tester) async {
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is ToolButton && widget.label == 'Rehearsals',
        ),
      );
      await tester.pumpAndSettle();
    },
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
  'performance_sheet_you_already_have_a_song_map': Opener((context, _, _) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => SongEditorScreen(
          title: 'First Song',
          sections: [Section(id: 'section1', name: 'Verse')],
        ),
      ),
    );
    tapWhenBuilt(find.byType(SongEditorScreen, skipOffstage: false), (element) {
      final menu = find.descendant(
        of: find.byType(SongEditorScreen, skipOffstage: false),
        matching: find.text('Menu', skipOffstage: false),
        skipOffstage: false,
      );
      menu.evaluate().first.findAncestorWidgetOfExactType<InkWell>()!.onTap!();
      tapWhenBuilt(find.text('Import lyrics & chords', skipOffstage: false), (
        element,
      ) {
        element.findAncestorWidgetOfExactType<ListTile>()!.onTap!();
        tapWhenBuilt(find.byType(ImportLyricsDialog, skipOffstage: false), (_) {
          final field =
              find
                      .descendant(
                        of: find.byType(
                          ImportLyricsDialog,
                          skipOffstage: false,
                        ),
                        matching: find.byType(TextField, skipOffstage: false),
                        skipOffstage: false,
                      )
                      .evaluate()
                      .single
                      .widget
                  as TextField;
          const lyrics =
              '{start_of_verse: Verse}\n[Am]First Song\n{end_of_verse}';
          field.controller!.text = lyrics;
          field.onChanged!(lyrics);
          tapWhenBuilt(
            find.byWidgetPredicate(
              (widget) => widget is CustomButton && widget.label == 'Import 1',
              skipOffstage: false,
            ),
            (element) => (element.widget as CustomButton).onPressed!(),
          );
        });
      });
    });
    tapWhenBuilt(find.byType(AlertDialog), (_) {
      expect(
        find.byType(SongEditorScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('You already have a song map'), findsOneWidget);
    });
  }),
  'grid_editor_dialog_tempo_grid': Opener(
    (context, _, _) => showGridEditorDialog(
      context,
      getGrid: () => const AudioGrid(bpm: 120),
      positionMs: () => 0,
      preciseTime: (_) => '00:00.000',
      onRemoveGrid: () async {},
    ),
  ),
  'notes_panel_note_at_n': Opener((context, _, _) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => ProviderScope(
          overrides: [
            labRepositoryProvider.overrideWithValue(RenderLabRepository()),
          ],
          child: PracticeRegionsScreen(
            entry: PracticeRegionsScreenFixture.entry().copyWith(
              attachmentIds: const [],
            ),
          ),
        ),
      ),
    );
    tapWhenBuilt(
      find.byWidgetPredicate(
        (widget) =>
            widget is PopupMenuButton<String> && widget.tooltip == 'More',
        skipOffstage: false,
      ),
      (element) =>
          (element.widget as PopupMenuButton<String>).onSelected!('note'),
    );
    tapWhenBuilt(find.byType(AlertDialog), (_) {
      expect(
        find.byType(PracticeRegionsScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('Note at 0:00'), findsOneWidget);
    });
  }),
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
  'practice_regions_speed_n': Opener((context, _, _) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => ProviderScope(
          overrides: [
            labRepositoryProvider.overrideWithValue(RenderLabRepository()),
          ],
          child: PracticeRegionsScreen(
            entry: PracticeRegionsScreenFixture.entry().copyWith(
              attachmentIds: const [],
            ),
          ),
        ),
      ),
    );
    tapWhenBuilt(
      find.byKey(const ValueKey('speed'), skipOffstage: false),
      (element) => (element.widget as OutlinedButton).onPressed!(),
    );
    tapWhenBuilt(find.byType(BottomSheet), (_) {
      expect(
        find.byType(PracticeRegionsScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('Speed 100%'), findsOneWidget);
    });
  }),
  // F123: copy kept until the parity lock decision; real path renders a different state.
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
  'event_kit_editor_dialog_l103': Opener((context, _, _) {
    final user = MockUser();
    when(user.uid).thenReturn('test-user-id');
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(AsyncData(user)),
            canEditBandProvider('band1').overrideWith((ref) => true),
            eventShareServiceProvider.overrideWithValue(
              EventShareService(
                invoker: (_, _) async => {
                  'shares': [
                    for (final (id, name, role, access, date) in [
                      (
                        'share1',
                        'Test User',
                        'venue',
                        {'stage': 'view', 'rider': 'view'},
                        '2024-05-12T00:00:00.000Z',
                      ),
                      (
                        'share2',
                        'Test Member Two',
                        'sound_engineer',
                        {'stage': 'edit'},
                        '2024-05-11T00:00:00.000Z',
                      ),
                      (
                        'share3',
                        'Test Member Three',
                        'client',
                        {'runningOrder': 'view'},
                        '2024-05-10T00:00:00.000Z',
                      ),
                    ])
                      {
                        'tokenId': id,
                        'participantId': id,
                        'name': name,
                        'role': role,
                        'access': access,
                        'state': 'active',
                        'createdAt': date,
                        'expiresAt': null,
                      },
                  ],
                  'hasMore': true,
                  'nextCursor': 'share3',
                },
              ),
            ),
          ],
          child: EventKitEditorScreen(
            setlist: MockDataHelper.createMockSetlist(
              id: 'setlist1',
              bandId: 'band1',
              name: 'Gig Setlist',
            ),
            bandId: 'band1',
          ),
        ),
      ),
    );
    tapWhenBuilt(
      find.widgetWithText(
        ActionChip,
        'Share links inventory',
        skipOffstage: false,
      ),
      (element) {
        expect(
          find.byType(EventKitEditorScreen, skipOffstage: false),
          findsOneWidget,
        );
        (element.widget as ActionChip).onPressed!();
      },
    );
  }),
  'event_share': Opener((context, tester, _) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => ProviderScope(
          overrides: [
            eventShareServiceProvider.overrideWithValue(
              EventShareService(
                invoker: (_, _) async => {
                  'setlistId': 'setlist1',
                  'name': 'Summer Garden Party',
                  'eventDateTime': '2027-06-12T19:00:00',
                  'eventLocation': 'The Garden House, Lisbon',
                  'description': 'An evening of live music in the garden.',
                  'viewer': {
                    'name': 'Test User',
                    'canSuggest': true,
                    'access': {
                      'eventInfo': 'view',
                      'runningOrder': 'view',
                      'songDetail': 'view',
                      'stage': 'view',
                      'rider': 'view',
                    },
                  },
                  'people': [
                    {'name': 'Maya Santos', 'role': 'vocalist'},
                    {'name': 'Daniel Costa', 'role': 'guitarist'},
                  ],
                  'items': [
                    {'id': 'item1', 'songId': 'song1'},
                    {'id': 'item2', 'songId': 'song2'},
                    {'id': 'break1', 'type': 'break'},
                    {'id': 'item3', 'songId': 'song3'},
                  ],
                  'songs': [
                    {
                      'id': 'song1',
                      'title': 'Valerie',
                      'artist': 'Amy Winehouse',
                      'ourKey': 'Eb',
                      'ourBPM': 106,
                    },
                    {
                      'id': 'song2',
                      'title': 'Wonderwall',
                      'artist': 'Oasis',
                      'ourKey': 'F#m',
                      'ourBPM': 87,
                    },
                    {
                      'id': 'song3',
                      'title': 'Seven Nation Army',
                      'artist': 'The White Stripes',
                      'ourKey': 'Em',
                      'ourBPM': 124,
                    },
                  ],
                  'stage': {
                    'Front': [
                      {'label': 'Vocals'},
                      {'label': 'Guitar'},
                    ],
                  },
                  'rider': [
                    {'label': 'Vocal microphone', 'qty': 2},
                  ],
                  'mySuggestions': [
                    {'text': 'Could you play an encore?', 'status': 'open'},
                  ],
                },
              ),
            ),
          ],
          child: const EventShareScreen(),
        ),
      ),
    );
  }),
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
  'performer_sheet_link_to_band_member': Opener((context, _, _) {
    showPerformerSheet(
      context: context,
      selected: const [],
      kit: const EventKit(
        people: [EventPerson(id: 'guest1', name: 'Test User', role: '')],
      ),
      members: [
        for (final (i, name) in [
          'Max Rivera',
          'Jordan Lee',
          'Sam Okafor',
          'Priya Nair',
          'Diego Ferrer',
        ].indexed)
          BandMember(
            uid: 'user$i',
            role: BandMember.roleEditor,
            displayName: name,
          ),
      ],
      songNumber: 1,
      songTitle: 'First Song',
    );
    tapWhenBuilt(
      find.descendant(
        of: find.byKey(const ValueKey('performer_guest1'), skipOffstage: false),
        matching: find.byType(PopupMenuButton<String>, skipOffstage: false),
        skipOffstage: false,
      ),
      (element) =>
          (element.widget as PopupMenuButton<String>).onSelected!('link'),
    );
    tapWhenBuilt(find.text('Link to band member'), (_) {
      expect(find.text('Who plays #1', skipOffstage: false), findsOneWidget);
    });
  }),
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
  'api_access_revoke_key': Opener((context, _, _) {
    setupRenderApiKeys().then((_) {
      if (!context.mounted) return;
      Navigator.of(
        context,
        rootNavigator: true,
      ).push(MaterialPageRoute<void>(builder: (_) => const ApiAccessScreen()));
      tapWhenBuilt(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'Revoke',
          skipOffstage: false,
        ),
        (element) {
          expect(
            find.byType(ApiAccessScreen, skipOffstage: false),
            findsOneWidget,
          );
          (element.widget as IconButton).onPressed!();
        },
      );
    });
  }),
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
  'event_kit_editor_sheet_l154': Opener((context, _, _) {
    // _addToZone: tap the first stage zone cell (an InkWell around a 84 dp cell).
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
    tapWhenBuilt(
      find.byWidgetPredicate(
        (w) =>
            w is InkWell &&
            w.onTap != null &&
            w.child is Container &&
            (w.child! as Container).constraints?.minHeight == 84,
        skipOffstage: false,
      ),
      (element) => (element.widget as InkWell).onTap!(),
    );
  }),
  'event_kit_editor_sheet_l181': Opener(
    (context, _, _) {
      // _addToZone: tap the first stage zone cell, then pick people and gear.
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
    },
    then: (tester) async {
      // Tap the first stage zone cell once the band's members have loaded.
      await tester.tap(
        find
            .byWidgetPredicate(
              (w) =>
                  w is InkWell &&
                  w.onTap != null &&
                  w.child is Container &&
                  (w.child! as Container).constraints?.minHeight == 84,
            )
            .first,
      );
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      for (final label in ['Dana Rivera', 'Drum kit', 'Guitar amp']) {
        final row = find.descendant(of: sheet, matching: find.text(label));
        // Scroll the sheet's list (its last Scrollable; the search field has
        // one too) until the lazily built row exists.
        final scrollable = tester.state<ScrollableState>(
          find.descendant(of: sheet, matching: find.byType(Scrollable)).last,
        );
        scrollable.position.jumpTo(0);
        await tester.pump();
        for (var i = 0; i < 80 && row.evaluate().isEmpty; i++) {
          scrollable.position.jumpTo(scrollable.position.pixels + 150);
          await tester.pump();
        }
        await tester.ensureVisible(row.first);
        await tester.pump();
        await tester.tap(row.first);
        await tester.pump();
      }
      tester
          .state<ScrollableState>(
            find.descendant(of: sheet, matching: find.byType(Scrollable)).last,
          )
          .position
          .jumpTo(0);
      await tester.pump();
    },
  ),
  'event_kit_editor_sheet_l191': Opener(
    (context, _, _) {
      // _addPerson via the 'Add person' chip, then the name is typed.
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
    },
    then: (tester) async {
      final chip = find.widgetWithText(ActionChip, 'Add person');
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Name').last,
        'Sam Rivera',
      );
      await tester.pumpAndSettle();
      // The frame's person: a client (may suggest) whose running order is
      // raised to Edit.
      final client = find.widgetWithText(ActionChip, 'Client');
      await tester.ensureVisible(client);
      await tester.tap(client);
      await tester.pumpAndSettle();
      final edit = find.descendant(
        of: find.byKey(const ValueKey('access-runningOrder')),
        matching: find.text('Edit'),
      );
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
    },
  ),
  'event_kit_editor_sheet_l256': Opener((context, tester, _) {
    // _addRiderItem via the 'Add rider item' chip.
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
      tester
          .widget<ActionChip>(
            find.widgetWithText(
              ActionChip,
              'Add rider item',
              skipOffstage: false,
            ),
          )
          .onPressed!();
    });
  }),
  'song_lab_sheet_l144': Opener((_, tester, _) {
    // _compose(note) via the Add menu's onSelected (the menu itself is a popup).
    tester
        .widget<PopupMenuButton<LabEntryType>>(
          find.byType(PopupMenuButton<LabEntryType>),
        )
        .onSelected!(LabEntryType.note);
  }, route: '/main/songs/song1/lab'),
  'song_lab_sheet_l664': Opener((_, tester, _) {
    // _composeTask: switch to the Tasks segment, then the 'Add task' chip once
    // the tasks stream has delivered (a few frames).
    tester
        .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
        .onSelectionChanged!({true});
    tapWhenBuilt(
      find.widgetWithText(ActionChip, 'Add task', skipOffstage: false),
      (element) => (element.widget as ActionChip).onPressed!(),
    );
  }, route: '/main/songs/song1/lab'),
  'create_setlist_sheet_l350': Opener(
    (_, _, _) {
      // _showSongPicker: the 'Add' button is enabled once the songs have loaded.
      tapWhenBuilt(
        find.ancestor(
          of: find.text('Add', skipOffstage: false),
          matching: find.byWidgetPredicate(
            (w) => w is TextButton && w.onPressed != null,
            skipOffstage: false,
          ),
        ),
        (element) => (element.widget as TextButton).onPressed!(),
      );
    },
    route: '/main/setlists/create',
    realAsync: true,
  ),
  'event_kit_editor_brand_optional': Opener((context, _, _) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => EventKitEditorScreen(
          setlist: Setlist(
            id: 'setlist1',
            bandId: 'band1',
            name: 'Gig Setlist',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            eventKit: const EventKit(
              stage: {
                'back-left': [
                  StagePlacement(kind: 'equipment', label: 'Guitar amp'),
                ],
              },
            ),
          ),
          bandId: 'band1',
        ),
      ),
    );
    tapWhenBuilt(
      find.byWidgetPredicate(
        (w) =>
            w is InkWell &&
            w.onTap != null &&
            w.child is Container &&
            (w.child! as Container).constraints?.minHeight == 84,
        skipOffstage: false,
      ),
      (element) {
        expect(
          find.byType(EventKitEditorScreen, skipOffstage: false),
          findsOneWidget,
        );
        (element.widget as InkWell).onTap!();
        tapWhenBuilt(
          find.byWidgetPredicate(
            (w) =>
                w is TextField &&
                w.decoration?.hintText == 'Search gear or type your own…',
            skipOffstage: false,
          ),
          (element) {
            (element.widget as TextField).onChanged!('Guitar amp');
            tapWhenBuilt(
              find.ancestor(
                of: find.descendant(
                  of: find.byType(BottomSheet, skipOffstage: false),
                  matching: find.text('Guitar amp', skipOffstage: false),
                ),
                matching: find.byWidgetPredicate(
                  (w) => w is GestureDetector && w.onTap != null,
                  skipOffstage: false,
                ),
              ),
              (element) {
                (element.widget as GestureDetector).onTap!();
                tapWhenBuilt(
                  find.byWidgetPredicate(
                    (w) => w is InputChip && w.onSelected != null,
                    skipOffstage: false,
                  ),
                  (element) => (element.widget as InputChip).onSelected!(true),
                );
              },
            );
          },
        );
      },
    );
  }),
  'practice_regions_replace_n_regions': Opener((context, _, _) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => ProviderScope(
          overrides: [
            labRepositoryProvider.overrideWithValue(RenderLabRepository()),
          ],
          child: PracticeRegionsScreen(
            entry: PracticeRegionsScreenFixture.entry(
              grid: const AudioGrid(bpm: 120),
              regions: [
                for (var i = 0; i < 9; i++)
                  AudioRegion(
                    id: 'region$i',
                    name: 'Part ${i + 1}',
                    startMs: i * 1000,
                    endMs: (i + 1) * 1000,
                  ),
              ],
            ).copyWith(attachmentIds: const []),
          ),
        ),
      ),
    );
    tapWhenBuilt(
      find.byWidgetPredicate(
        (widget) =>
            widget is PopupMenuButton<String> && widget.tooltip == 'More',
        skipOffstage: false,
      ),
      (element) {
        (element.widget as PopupMenuButton<String>).onSelected!('slice');
        tapWhenBuilt(
          find.widgetWithText(
            ChoiceChip,
            'Slice every N bars',
            skipOffstage: false,
          ),
          (element) {
            (element.widget as ChoiceChip).onSelected!(true);
            tapWhenBuilt(
              find.widgetWithText(FilledButton, 'Apply', skipOffstage: false),
              (element) => (element.widget as FilledButton).onPressed!(),
            );
          },
        );
      },
    );
    tapWhenBuilt(find.byType(AlertDialog), (_) {
      expect(
        find.byType(PracticeRegionsScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('Replace 9 regions?'), findsOneWidget);
    });
  }),
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
  'profile_link_telegram': Opener((context, _, _) {
    setupRenderTelegram().then((_) {
      if (!context.mounted) return;
      Navigator.of(
        context,
        rootNavigator: true,
      ).push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen()));
      tapWhenBuilt(
        find.widgetWithText(ListTile, 'Link Telegram', skipOffstage: false),
        (element) => (element.widget as ListTile).onTap!(),
      );
      tapWhenBuilt(find.byType(AlertDialog), (_) {
        expect(find.byType(ProfileScreen, skipOffstage: false), findsOneWidget);
        expect(find.text('Open Telegram'), findsOneWidget);
      });
    });
  }),
  'profile_delete_account': Opener((context, _, _) {
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen()));
    tapWhenBuilt(find.text('Danger zone', skipOffstage: false), (element) {
      element.findAncestorWidgetOfExactType<InkWell>()!.onTap!();
      tapWhenBuilt(
        find.widgetWithText(TextButton, 'Delete account', skipOffstage: false),
        (element) => (element.widget as TextButton).onPressed!(),
      );
    });
    tapWhenBuilt(find.byType(AlertDialog), (_) {
      expect(find.byType(ProfileScreen, skipOffstage: false), findsOneWidget);
      expect(find.text('Delete account'), findsWidgets);
    });
  }),
  'recorder_link_recording_to_song': Opener((context, _, _) {
    final user = MockUser();
    when(user.uid).thenReturn('test-user-id');
    final auth = MockFirebaseAuth();
    when(auth.currentUser).thenReturn(user);
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWith((ref) => auth),
            labEntriesProvider((ideaInboxSongId, null))
                .overrideWith((ref) => Stream.value([kRenderRecording])),
          ],
          child: const RecorderScreen(),
        ),
      ),
    );
    tapWhenBuilt(
      find.byWidgetPredicate(
        (widget) =>
            widget is PopupMenuButton<String> &&
            widget.tooltip == 'Menu for Test Recording',
        skipOffstage: false,
      ),
      (element) =>
          (element.widget as PopupMenuButton<String>).onSelected!('link'),
    );
    tapWhenBuilt(find.byType(BottomSheet), (_) {
      expect(find.byType(RecorderScreen, skipOffstage: false), findsOneWidget);
      expect(find.text('Link recording to song'), findsOneWidget);
      expect(find.text('First Song'), findsOneWidget);
    });
  }),
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
  'setlist_export_sheet_whose_copy': Opener((context, _, _) {
    final setlist = Setlist(
      id: 'setlist1',
      bandId: 'band1',
      name: 'Gig Setlist',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      eventKit: const EventKit(
        people: [EventPerson(id: 'user1', name: 'Test User', role: '')],
      ),
      items: const [
        SetlistItem(id: 'song1', songId: 'song1', performerIds: ['user1']),
      ],
    );
    pickSetlistPdfExport(context, setlist);
    tapWhenBuilt(find.text('As is'), (element) {
      final scrollable = Scrollable.of(element);
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      tapWhenBuilt(find.text('One musician'), (element) {
        (element.findAncestorWidgetOfExactType<ListTile>()!).onTap!();
      });
    });
    tapWhenBuilt(find.text('Whose copy?'), (_) {
      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('Test User')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('#1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.byType(Divider)),
        findsNothing,
      );
    });
  }),
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
  // F123: copy kept until the parity lock decision; real path renders a different state.
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
  'add_song_helper_search_on_web': Opener((context, _, _) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => AddSongScreen(
          initialFormData: SongFormData(
            title: 'First Song',
            artist: 'Test Artist',
          ),
        ),
      ),
    );
    tapWhenBuilt(find.byType(SongForm, skipOffstage: false), (element) {
      (element.widget as SongForm).onSearchWeb();
    });
    tapWhenBuilt(find.byType(AlertDialog), (_) {
      expect(find.byType(AddSongScreen, skipOffstage: false), findsOneWidget);
    });
  }),
  'drum_practice_panel': Opener(
    (context, _, _) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const DrumPracticePanel(songId: 'song1', bandId: 'band1'),
    ),
    then: (tester) async {
      // Drag the sheet up to its full height so the buttons at the end of the
      // list are on screen.
      await tester.drag(
        find.descendant(
          of: find.byType(DrumPracticePanel),
          matching: find.byType(ListView),
        ),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
    },
  ),
  'drum_grid_editor': Opener(
    (context, tester, _) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const DrumPracticePanel(songId: 'song1'),
    ),
    then: (tester) async {
      await tester.tap(find.byTooltip('Edit pattern'));
      await tester.pumpAndSettle();
    },
  ),
  'song_import_dialog': Opener(
    (context, _, _) => showDialog<void>(
      context: context,
      builder: (_) => const SongImportDialog(librarySongs: []),
    ),
  ),
  'songs_list_importing_songs': Opener((_, _, _) {
    // Real path: Songs 'Library actions' menu -> 'Import from CSV' -> _handleImport.
    tapWhenBuilt(
      find.byWidgetPredicate(
        (w) => w is PopupMenuButton && w.tooltip == 'Library actions',
      ),
      (menu) {
        // ignore: avoid_dynamic_calls
        ((menu as StatefulElement).state as dynamic).showButtonMenu();
        tapWhenBuilt(
          find.ancestor(
            of: find.text('Import from CSV'),
            matching: find.byType(InkWell),
          ),
          (item) => (item.widget as InkWell).onTap!(),
        );
      },
    );
  }, route: '/main/songs'),
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
    // The real overlay with the tuner in stage mode, on its own full-screen
    // route so the Home backdrop is covered like the tuner's own content.
    (context, _, _) => Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => ProviderScope(
          overrides: [tunerProvider.overrideWith(_StageTuner.new)],
          child: const Scaffold(
            body: StageModeOverlay(child: SizedBox.expand()),
          ),
        ),
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
    // The root menu: the 'More' tab of the shell's bottom bar. Songs is the
    // backdrop because it shows none of the menu's tool names.
    (_, _, _) {},
    route: '/main/songs',
    then: (tester) async {
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
    },
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
    realAsync: true,
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
  'midi_import_flow_import_midi': Opener((_, _, _) {
    // Real pickAndImportMidi: the picker returns a file that is not MIDI, so
    // the flow shows its own 'Import MIDI' failure dialog.
    final previous = FilePickerPlatform.instance;
    FilePickerPlatform.instance = _RenderFilePicker(
      'notes.txt',
      'not a midi file'.codeUnits,
    );
    addTearDown(() => FilePickerPlatform.instance = previous);
    tapWhenBuilt(
      find.ancestor(
        of: find.text('Import MIDI'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
      (element) => (element.widget as ButtonStyleButton).onPressed!(),
    );
  }, route: '/main/songs/song1/lab'),
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

/// Picker that "picks" one in-memory file.
class _RenderFilePicker extends FilePickerPlatform {
  _RenderFilePicker(this.name, this.bytes);

  final String name;
  final List<int> bytes;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
    AndroidSAFOptions? androidSafOptions,
  }) async => FilePickerResult([
    PlatformFile(
      name: name,
      size: bytes.length,
      bytes: Uint8List.fromList(bytes),
    ),
  ]);
}
