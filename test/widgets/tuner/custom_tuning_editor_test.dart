import 'dart:async';

import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/instrument.dart';
import 'package:flowgroove/models/tuner_preset.dart';
import 'package:flowgroove/models/user.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/tuner_provider.dart';
import 'package:flowgroove/widgets/tuner/custom_tuning_editor.dart';
import 'package:mockito/mockito.dart';

import '../../helpers/mocks.mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Identity extends AppUserNotifier {
  _Identity(this.initial);
  final AsyncValue<AppUser?> initial;
  @override
  AsyncValue<AppUser?> build() => initial;
  void change(AsyncValue<AppUser?> value) => state = value;
}

class _Tuner extends TunerNotifier {
  final saved = <TunerPresetScope>[];
  final targets = <(String?, String?)>[];
  @override
  TunerState build() => const TunerState();
  @override
  Future<void> addCustomTuning(
    Tuning tuning, {
    TunerPresetScope scope = TunerPresetScope.local,
    String? bandId,
    String? songId,
  }) async {
    saved.add(scope);
    targets.add((bandId, songId));
  }

  @override
  void selectTuning(Tuning tuning) {}
}

Future<_Tuner> pumpEditor(
  WidgetTester tester,
  _Identity identity, {
  List<Band> bands = const [],
  Stream<List<Band>>? bandStream,
  String? uid = 'u1',
  String? bandId = 'b1',
}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auth = MockFirebaseAuth();
  final user = MockUser();
  when(user.uid).thenReturn(uid ?? 'u1');
  when(auth.currentUser).thenReturn(uid == null ? null : user);
  final tuner = _Tuner();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appUserProvider.overrideWith(() => identity),
        firebaseAuthProvider.overrideWithValue(auth),
        authStateProvider.overrideWith(
          (ref) => Stream.value(uid == null ? null : user),
        ),
        bandsProvider.overrideWith((ref) => bandStream ?? Stream.value(bands)),
        tunerProvider.overrideWith(() => tuner),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: CustomTuningEditor(bandId: bandId, songId: 's1'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tuner;
}

List<TunerPresetScope?> offered(WidgetTester tester) => tester
    .widget<DropdownButton<TunerPresetScope>>(
      find.byType(DropdownButton<TunerPresetScope>),
    )
    .items!
    .map((item) => item.value)
    .toList();

void main() {
  testWidgets('signed-out editor offers only device-local saving', (
    tester,
  ) async {
    await pumpEditor(tester, _Identity(const AsyncValue.data(null)), uid: null);
    expect(offered(tester), [TunerPresetScope.local]);
  });
  final authorized = AsyncValue<AppUser?>.data(
    AppUser(uid: 'u1', createdAt: DateTime(2026)),
  );
  final denied = <String, AsyncValue<AppUser?>>{
    'demo': AsyncValue.data(
      AppUser(uid: 'u1', accessRole: 'demo', createdAt: DateTime(2026)),
    ),
    'loading': const AsyncValue.loading(),
    'error': AsyncValue.error(StateError('offline'), StackTrace.current),
    'identity mismatch': AsyncValue.data(
      AppUser(uid: 'other', createdAt: DateTime(2026)),
    ),
    // Match Riverpod's retained-data refresh states; stale grants must fail closed.
    // ignore: invalid_use_of_internal_member
    'cached loading': const AsyncValue<AppUser?>.loading().copyWithPrevious(
      authorized,
    ),
    'cached error': AsyncValue<AppUser?>.error(
      StateError('offline'),
      StackTrace.current,
      // ignore: invalid_use_of_internal_member
    ).copyWithPrevious(authorized),
  };
  for (final entry in denied.entries) {
    testWidgets('${entry.key} still permits local Save but no synced choice', (
      tester,
    ) async {
      final tuner = await pumpEditor(tester, _Identity(entry.value));
      expect(offered(tester), [TunerPresetScope.local]);
      await tester.enterText(find.byType(TextField), 'Local tuning');
      await tester.tap(find.text('Save Custom Tuning'));
      await tester.pumpAndSettle();
      expect(tuner.saved, [TunerPresetScope.local]);
      expect(tester.takeException(), isNull);
    });
  }
  final band = Band(
    id: 'b1',
    name: 'Band',
    createdBy: 'u1',
    createdAt: DateTime(2026),
    editorUids: ['u1'],
  );
  for (final scope in TunerPresetScope.values) {
    testWidgets('authorized editor saves ${scope.name} with existing scope', (
      tester,
    ) async {
      final tuner = await pumpEditor(
        tester,
        _Identity(authorized),
        bands: [band],
      );
      expect(offered(tester), TunerPresetScope.values);
      await tester.tap(find.byType(DropdownButton<TunerPresetScope>));
      await tester.pumpAndSettle();
      const labels = [
        'This device',
        'My account',
        'Current band',
        'Current song',
      ];
      await tester.tap(find.text(labels[scope.index]).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'My tuning');
      await tester.tap(find.text('Save Custom Tuning'));
      await tester.pumpAndSettle();
      expect(tuner.saved, [scope]);
      expect(tuner.targets, [
        (
          scope == TunerPresetScope.band || scope == TunerPresetScope.song
              ? 'b1'
              : null,
          scope == TunerPresetScope.song ? 's1' : null,
        ),
      ]);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('band viewer keeps account but not band or band-song scope', (
    tester,
  ) async {
    await pumpEditor(tester, _Identity(authorized));
    expect(offered(tester), [TunerPresetScope.local, TunerPresetScope.account]);
  });
  testWidgets('personal song permits same-identity account and song scopes', (
    tester,
  ) async {
    await pumpEditor(tester, _Identity(authorized), bandId: null);
    expect(offered(tester), [
      TunerPresetScope.local,
      TunerPresetScope.account,
      TunerPresetScope.song,
    ]);
  });
  for (final state in ['loading', 'error', 'revoked']) {
    testWidgets('band $state removes shared scopes and rejects retained Save', (
      tester,
    ) async {
      final changes = StreamController<List<Band>>.broadcast();
      addTearDown(changes.close);
      final tuner = await pumpEditor(
        tester,
        _Identity(authorized),
        bandStream: changes.stream,
      );
      expect(offered(tester), [
        TunerPresetScope.local,
        TunerPresetScope.account,
      ]);
      changes.add([band]);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<TunerPresetScope>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Current song').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Shared tuning');
      final save = tester
          .widget<ElevatedButton>(find.byType(ElevatedButton))
          .onPressed!;
      if (state == 'error') {
        changes.addError(StateError('offline'));
      } else if (state == 'revoked') {
        changes.add([]);
      } else {
        final container = ProviderScope.containerOf(
          tester.element(find.byType(CustomTuningEditor)),
        );
        container.invalidate(bandsProvider);
      }
      await tester.pumpAndSettle();
      expect(offered(tester), [
        TunerPresetScope.local,
        TunerPresetScope.account,
      ]);
      save();
      await tester.pumpAndSettle();
      expect(tuner.saved, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('revoked role resets dropdown safely and rejects retained Save', (
    tester,
  ) async {
    final identity = _Identity(authorized);
    final tuner = await pumpEditor(tester, identity, bands: [band]);
    await tester.tap(find.byType(DropdownButton<TunerPresetScope>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Current band').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Band tuning');
    final save = tester
        .widget<ElevatedButton>(find.byType(ElevatedButton))
        .onPressed!;
    identity.change(denied['demo']!);
    await tester.pumpAndSettle();
    expect(offered(tester), [TunerPresetScope.local]);
    expect(
      tester
          .widget<DropdownButton<TunerPresetScope>>(
            find.byType(DropdownButton<TunerPresetScope>),
          )
          .value,
      TunerPresetScope.local,
    );
    save();
    await tester.pumpAndSettle();
    expect(tuner.saved, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'retained account Save cannot switch to another signed-in identity',
    (tester) async {
      final identity = _Identity(authorized);
      final tuner = await pumpEditor(tester, identity);
      await tester.tap(find.byType(DropdownButton<TunerPresetScope>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My account').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Private tuning');
      final save = tester
          .widget<ElevatedButton>(find.byType(ElevatedButton))
          .onPressed!;
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CustomTuningEditor)),
      );
      final other = MockUser();
      when(other.uid).thenReturn('other');
      when(container.read(firebaseAuthProvider).currentUser).thenReturn(other);
      identity.change(denied['identity mismatch']!);
      await tester.pumpAndSettle();
      save();
      await tester.pumpAndSettle();
      expect(tuner.saved, isEmpty);
    },
  );

  testWidgets('saving without a name shows the error inside the sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: CustomTuningEditor())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Custom Tuning'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a name for this tuning'), findsOneWidget);
    // Typing clears it again.
    await tester.enterText(find.byType(TextField), 'My Open G');
    await tester.pump();
    expect(find.text('Please enter a name for this tuning'), findsNothing);
  });
}
