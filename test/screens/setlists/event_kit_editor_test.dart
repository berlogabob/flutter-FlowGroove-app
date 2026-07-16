import 'package:firebase_auth/firebase_auth.dart';
import 'package:flowgroove/models/event_kit.dart';
import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/screens/setlists/event_kit_editor_screen.dart';
import 'package:flutter/material.dart';
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

  Future<MockFirestoreService> pump(WidgetTester tester) async {
    final firestore = MockFirestoreService();
    when(firestore.saveSetlist(any, uid: anyNamed('uid')))
        .thenAnswer((_) async {});
    final user = MockUser();
    when(user.uid).thenReturn('u1');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(firestore),
          currentUserProvider.overrideWithValue(AsyncValue<User?>.data(user)),
        ],
        child: MaterialApp(home: EventKitEditorScreen(setlist: setlist)),
      ),
    );
    await tester.pumpAndSettle();
    return firestore;
  }

  group('EventKitEditorScreen (#53)', () {
    testWidgets('renders the 9-zone grid and sections', (tester) async {
      await pump(tester);
      expect(find.text('Stage plot'), findsOneWidget);
      expect(find.text('Crew & guests'), findsOneWidget);
      expect(find.text('Rider / equipment'), findsOneWidget);
      // 9 empty zones each show a + affordance.
      expect(find.byIcon(Icons.add), findsWidgets);
    });

    testWidgets('placing equipment in a zone saves the setlist', (
      tester,
    ) async {
      final firestore = await pump(tester);

      // Tap the first zone cell (top-left = back-left).
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Equipment (e.g. Amp, Drum kit, Monitor)'),
        'Drum kit',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(Chip, 'Drum kit'), findsOneWidget);
      final saved = verify(
        firestore.saveSetlist(captureAny, uid: anyNamed('uid')),
      ).captured.single as Setlist;
      expect(saved.eventKit!.stage['back-left']!.single.label, 'Drum kit');
      expect(saved.eventKit!.stage['back-left']!.single.kind, 'equipment');
    });

    testWidgets('added crew person appears as a role card (#54)', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('Add person'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Vera',
      );
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

      final saved = verify(
        firestore.saveSetlist(captureAny, uid: anyNamed('uid')),
      ).captured.last as Setlist;
      expect(saved.eventKit!.rider.single.done, isTrue);
    });
  });
}
