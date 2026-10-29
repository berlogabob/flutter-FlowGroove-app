import 'package:flowgroove/models/instrument.dart';
import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/models/tuner_launch_context.dart';
import 'package:flowgroove/models/tuner_preset.dart';
import 'package:flowgroove/providers/tuner_provider.dart';
import 'package:flowgroove/screens/tuner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mocks.dart';

class _Tuner extends TunerNotifier {
  @override
  TunerState build() => const TunerState(
    selectedTuning: Tuning(id: 'standard', name: 'Standard', notes: ['E2']),
  );

  void selectLocal() {
    state = state.copyWith(
      customTuningScopes: {'standard': TunerPresetScope.local},
    );
  }

  @override
  Future<void> loadContextPresets({String? bandId, String? songId}) async {}

  @override
  Future<void> stopAll() async {}
}

void main() {
  for (final item in [false, true]) {
    testWidgets('failed ${item ? 'item' : 'song'} linking allows safe retry', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      var fail = true;
      final song = MockDataHelper.createMockSong();
      final now = DateTime.utc(2026);
      final setlist = Setlist(
        id: 'list',
        bandId: 'band',
        name: 'Show',
        items: [SetlistItem(id: 'item', songId: song.id)],
        createdAt: now,
        updatedAt: now,
      );
      final notifier = _Tuner();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [tunerProvider.overrideWith(() => notifier)],
          child: MaterialApp(
            home: TunerScreen(
              launchContext: TunerLaunchContext(
                song: song,
                setlist: item ? setlist : null,
                setlistItemId: item ? 'item' : null,
                saveSong: item
                    ? null
                    : (value) async {
                        calls++;
                        expect(value.id, song.id);
                        expect(value.defaultTuningPresetId, 'standard');
                        if (fail) throw StateError('private backend detail');
                      },
                saveSetlist: !item
                    ? null
                    : (value) async {
                        calls++;
                        expect(value.id, 'list');
                        expect(value.tuningPresetIdForItem('item'), 'standard');
                        if (fail) throw StateError('private backend detail');
                      },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final action = find.text(item ? 'Use for item' : 'Use for song');
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(tester.takeException(), isNull);
      expect(find.text('Tuning preset linked.'), findsNothing);
      expect(find.textContaining('private backend detail'), findsNothing);
      expect(
        find.text('Could not link tuning preset. Please try again.'),
        findsOneWidget,
      );
      fail = false;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Tuning preset linked.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      notifier.selectLocal();
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(
        find.text('Save this custom preset to your account before linking it.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
