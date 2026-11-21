import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/providers/permissions_provider.dart';
import 'package:flowgroove/repositories/firestore_lab_repository.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_transport.dart';
import 'package:flowgroove/screens/practice_regions_screen.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/mocks.mocks.dart';
import '../../../providers/backing_transport_test.dart' show FakeMetronome;

void main() {
  for (final theme in [MonoPulseTheme.lightTheme, MonoPulseTheme.theme]) {
    testWidgets(
      'transport fits one row on the ${theme.brightness.name} surface',
      (tester) async {
        tester.view
          ..physicalSize = const Size(360, 640)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final date = DateTime(2026, 11, 21);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              isDemoUserProvider.overrideWithValue(false),
              labRepositoryProvider.overrideWithValue(
                FirestoreLabRepository(
                  firestore: MockFirebaseFirestore(),
                  auth: MockFirebaseAuth(),
                ),
              ),
              metronomeProvider.overrideWith(FakeMetronome.new),
            ],
            child: MaterialApp(
              theme: theme,
              home: PracticeRegionsScreen(
                entry: SongLabEntry(
                  id: 'take',
                  songId: '_inbox',
                  type: LabEntryType.recording,
                  authorId: 'user',
                  createdAt: date,
                  updatedAt: date,
                  regions: const [
                    AudioRegion(
                      id: 'intro',
                      name: 'Intro',
                      startMs: 0,
                      endMs: 4000,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        final transport = find.byType(SongMapTransport);
        final panel = find
            .descendant(of: transport, matching: find.byType(Material))
            .first;
        expect(tester.widget<Material>(panel).color, theme.colorScheme.surface);

        final bounds = tester.getRect(panel);
        final playCenter = tester.getCenter(find.byKey(const ValueKey('play')));
        var previousDx = bounds.left;
        for (final key in [
          'play',
          'loop',
          'speed',
          'count-in',
          'click',
          'click-and-drums',
        ]) {
          final control = find.descendant(
            of: transport,
            matching: find.byKey(ValueKey(key)),
          );
          expect(control, findsOneWidget);
          final rect = tester.getRect(control);
          expect(rect.left, greaterThanOrEqualTo(bounds.left), reason: key);
          expect(rect.right, lessThanOrEqualTo(bounds.right), reason: key);
          expect(rect.center.dx, greaterThan(previousDx), reason: key);
          expect(rect.center.dy, closeTo(playCenter.dy, 4), reason: key);
          previousDx = rect.center.dx;
        }

        final appBar = find.byType(AppBar);
        for (final key in ['shift', 'add-note']) {
          expect(
            find.descendant(of: appBar, matching: find.byKey(ValueKey(key))),
            findsNothing,
          );
        }
        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();
        for (final (key, tooltip) in [
          ('shift', 'Edit'),
          ('add-note', 'Note'),
        ]) {
          final button = find.byKey(ValueKey(key));
          expect(tester.widget(button), isA<PopupMenuItem<String>>());
          expect(button.hitTestable(), findsOneWidget);
          expect(find.byTooltip(tooltip), findsOneWidget);
          final rect = tester.getRect(button);
          expect(rect.left, greaterThanOrEqualTo(bounds.left));
          expect(rect.right, lessThanOrEqualTo(bounds.right));
        }
      },
    );
  }
}
