import 'package:firebase_auth/firebase_auth.dart';
import 'package:flowgroove/models/event_kit.dart';
import 'package:flowgroove/services/event_share_service.dart';
import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/screens/setlists/event_kit_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../helpers/mocks.mocks.dart';

void main() {
  final setlist = Setlist(
    id: 'sl1',
    bandId: '',
    name: 'Club gig',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<MockFirestoreService> pump(
    WidgetTester tester, {
    Setlist? withSetlist,
    Map<String, String>? access,
    bool isMember = true,
    String? ownerUid,
    bool personal = false,
    EventShareService? shareService,
  }) async {
    final firestore = MockFirestoreService();
    when(
      firestore.updateEventKitArea(
        setlistId: anyNamed('setlistId'),
        area: anyNamed('area'),
        value: anyNamed('value'),
        bandId: anyNamed('bandId'),
        uid: anyNamed('uid'),
      ),
    ).thenAnswer((_) async {});
    final user = MockUser();
    when(user.uid).thenReturn('u1');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(firestore),
          if (shareService != null)
            eventShareServiceProvider.overrideWithValue(shareService),
          currentUserProvider.overrideWithValue(AsyncValue<User?>.data(user)),
        ],
        child: MaterialApp(
          home: EventKitEditorScreen(
            setlist: withSetlist ?? setlist,
            // A band id makes this a shared event, which is what makes the
            // access map meaningful — a personal setlist has no grants.
            bandId: personal || access == null ? null : 'band-1',
            ownerUid: ownerUid,
            access: access ?? const {},
            isMember: isMember,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return firestore;
  }

  /// The last value written to [area] through the dotted-field-path writer.
  ///
  /// Asserting per-area (rather than on a whole-setlist save) is the point:
  /// stage and rider have separate editors and separate permissions, so a
  /// full-document write would clobber whoever saved first.
  List<Object?> writesTo(MockFirestoreService firestore, String area) => verify(
    firestore.updateEventKitArea(
      setlistId: anyNamed('setlistId'),
      area: area,
      value: captureAnyNamed('value'),
      bandId: anyNamed('bandId'),
      uid: anyNamed('uid'),
    ),
  ).captured;

  testWidgets(
    'personal owner shares with free-form people without band members',
    (tester) async {
      final calls = <Map<String, dynamic>>[];
      String? copiedLink;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData')
            copiedLink = (call.arguments as Map)['text'] as String;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final firestore = await pump(
        tester,
        personal: true,
        ownerUid: 'u1',
        isMember: false,
        access: const {'stage': 'view'},
        shareService: EventShareService(
          invoker: (name, args) async {
            expect(name, 'createEventShare');
            calls.add(args);
            return {'token': 'personal.secret'};
          },
        ),
      );
      expect(find.text('Add rider item'), findsOneWidget);
      await tester.tap(find.text('Add person'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Ana');
      await tester.enterText(
        find.widgetWithText(TextField, 'Role (Photographer, Manager, +1…)'),
        'Photographer',
      );
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      final added =
          (writesTo(firestore, 'people').single! as List).single as Map;
      expect(added['uid'], isNull);
      await tester.tap(find.byTooltip('Share this event with Ana'));
      await tester.pumpAndSettle();
      expect(calls.single, {
        'ownerUid': 'u1',
        'setlistId': 'sl1',
        'participantId': added['id'],
      });
      expect(
        copiedLink,
        'https://app.flowgroove.app/#/event?t=personal.secret',
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Ana'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Ana Maria',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final edited =
          (writesTo(firestore, 'people').single! as List).single as Map;
      expect(edited['name'], 'Ana Maria');
      expect(edited['id'], added['id']);
      expect(edited['access'], added['access']);
    },
  );

  testWidgets('personal guest keeps their area grant and writes to the owner', (
    tester,
  ) async {
    final firestore = await pump(
      tester,
      personal: true,
      ownerUid: 'another-owner',
      isMember: false,
      access: const {'rider': 'edit'},
    );
    expect(find.text('Stage plot'), findsNothing);
    expect(find.text('Add person'), findsNothing);
    await tester.tap(find.text('Add rider item'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'XLR cables');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    verify(
      firestore.updateEventKitArea(
        setlistId: 'sl1',
        area: 'rider',
        value: anyNamed('value'),
        uid: 'another-owner',
      ),
    );
  });

  group('EventKitEditorScreen (#53)', () {
    testWidgets('renders the 9-zone grid and sections', (tester) async {
      await pump(tester);
      expect(find.text('Stage plot'), findsOneWidget);
      expect(find.text('Crew & guests'), findsOneWidget);
      expect(find.text('Rider / equipment'), findsOneWidget);
      // 9 empty zones each show a + affordance.
      expect(find.byIcon(Icons.add), findsWidgets);
    });

    testWidgets('placing catalog gear in a zone saves the setlist', (
      tester,
    ) async {
      final firestore = await pump(tester);

      // Tap the first zone cell (top-left = back-left).
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Drum kit');
      await tester.pumpAndSettle();
      // Pick it from the catalog results, then confirm the multi-select sheet.
      // `.last` skips the search field's own EditableText, which also matches.
      await tester.tap(find.text('Drum kit').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(Chip, 'Drum kit'), findsOneWidget);
      final stage =
          writesTo(firestore, 'stage').single! as Map<String, dynamic>;
      final placed =
          (stage['back-left']! as List).single as Map<String, dynamic>;
      expect(placed['label'], 'Drum kit');
      expect(placed['kind'], 'equipment');
      // The catalog icon is baked in at add time — this is the fix for every
      // placement rendering the same speaker glyph.
      expect(placed['icon'], '🥁');
      // Nothing but the stage was touched.
      verifyNever(
        firestore.updateEventKitArea(
          setlistId: anyNamed('setlistId'),
          area: 'rider',
          value: anyNamed('value'),
          bandId: anyNamed('bandId'),
          uid: anyNamed('uid'),
        ),
      );
    });

    testWidgets('free-typed gear is still accepted', (tester) async {
      final firestore = await pump(tester);

      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Fog juice');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add "Fog juice"'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final stage =
          writesTo(firestore, 'stage').single! as Map<String, dynamic>;
      expect(
        ((stage['back-left']! as List).single as Map<String, dynamic>)['label'],
        'Fog juice',
      );
    });

    testWidgets('legacy placements without an icon resolve one by label', (
      tester,
    ) async {
      // Plots saved before icons existed have icon == null; they used to all
      // render Icons.speaker.
      await pump(
        tester,
        withSetlist: setlist.copyWith(
          eventKit: const EventKit(
            stage: {
              'back-left': [
                StagePlacement(kind: 'equipment', label: 'Drum kit'),
                StagePlacement(kind: 'equipment', label: 'Unknowable thing'),
              ],
            },
          ),
        ),
      );

      expect(find.text('🥁'), findsOneWidget);
      expect(find.text('🔊'), findsOneWidget);
    });

    testWidgets('added crew person appears as a role card (#54)', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('Add person'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Vera');
      await tester.enterText(
        find.widgetWithText(TextField, 'Role (Photographer, Manager, +1…)'),
        'Photographer',
      );
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Role cards'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // Vera renders in the crew list AND as a role card.
      expect(find.text('Vera'), findsNWidgets(2));
      expect(find.text('Photographer'), findsWidgets);
    });

    testWidgets('a stage editor gets the stage plot and NOT the roster', (
      tester,
    ) async {
      // The door #184 opened. A claimed sound engineer edits the stage plot,
      // may read the rider, and must never be offered the roster: the grants
      // are derived from it and the rules refuse their write to it.
      await pump(
        tester,
        access: const {'stage': 'edit', 'rider': 'view'},
        isMember: false,
      );

      expect(find.text('Stage plot'), findsOneWidget);
      expect(find.text('Rider / equipment'), findsOneWidget);
      expect(find.text('Crew & guests'), findsNothing);
      expect(find.text('Role cards'), findsNothing);
      // Rider is read-only: no way to add to it.
      expect(find.text('Add rider item'), findsNothing);
      // …and no way to add a person, because that section is not there at all.
      expect(find.text('Add person'), findsNothing);
    });

    testWidgets('a rider editor gets no stage plot at all', (tester) async {
      await pump(tester, access: const {'rider': 'edit'}, isMember: false);
      expect(find.text('Rider / equipment'), findsOneWidget);
      expect(find.text('Add rider item'), findsOneWidget);
      expect(find.text('Stage plot'), findsNothing);
      expect(find.text('Crew & guests'), findsNothing);
    });

    testWidgets('a view-only guest can open nothing', (tester) async {
      await pump(
        tester,
        access: const {'eventInfo': 'view', 'runningOrder': 'view'},
        isMember: false,
      );
      expect(find.text('Stage plot'), findsNothing);
      expect(find.text('Rider / equipment'), findsNothing);
      expect(find.text('Crew & guests'), findsNothing);
      expect(find.text('Role cards'), findsNothing);
    });

    testWidgets('a member still sees every section', (tester) async {
      await pump(tester);
      expect(find.text('Stage plot'), findsOneWidget);
      expect(find.text('Crew & guests'), findsOneWidget);
      expect(find.text('Rider / equipment'), findsOneWidget);
      expect(find.text('Add rider item'), findsOneWidget);
      expect(find.text('Add person'), findsOneWidget);
    });

    testWidgets('rider item toggles done and persists', (tester) async {
      final firestore = await pump(tester);

      await tester.scrollUntilVisible(
        find.text('Add rider item'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Add rider item'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'XLR cables');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('XLR cables'), findsOneWidget);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      final rider = writesTo(firestore, 'rider').last! as List;
      expect((rider.single as Map<String, dynamic>)['done'], isTrue);
    });
  });
}
