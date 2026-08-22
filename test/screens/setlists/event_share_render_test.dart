// Rendering EventShareScreen for real, rather than asserting a helper that
// mirrors its gating expression.
//
// The audit ticked "view-only recipients never prompted" and "a venue sees no
// chart data" on the strength of mirror tests — functions in the test file that
// duplicated the widget's condition. Those pass just as well if the widget
// stops using the condition. These render the page instead.

import 'package:flowgroove/models/event_access.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/screens/setlists/event_share_screen.dart';
import 'package:flowgroove/services/event_share_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns whatever the test asks for; records what was sent back.
class FakeEventShareService implements EventShareService {
  FakeEventShareService(this.view);

  final EventView view;
  final List<String> suggestions = [];

  @override
  Future<EventView> getEventView({
    String? token,
    String? bandId,
    String? setlistId,
  }) async => view;

  @override
  Future<void> submitSuggestion({
    String? token,
    String? bandId,
    String? setlistId,
    required String type,
    String? songId,
    String? text,
  }) async => suggestions.add(text ?? '');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

EventView _view({
  required Map<String, String> access,
  bool canSuggest = false,
  bool withChart = false,
}) => EventView(
  setlistId: 'sl1',
  name: 'Sputnik Bar',
  access: access,
  canSuggest: canSuggest,
  viewerName: 'Sputnik — Ana',
  eventDateTime: DateTime(2026, 8, 21, 20),
  eventLocation: 'Sputnik Bar, Lisbon',
  items: const [
    {'id': 'i1', 'songId': 's1', 'type': 'song'},
  ],
  songs: [
    {
      'id': 's1',
      'title': 'visto',
      'artist': 'Flor Damico',
      if (withChart) 'ourKey': 'Bm',
      if (withChart) 'ourBPM': 96,
    },
  ],
  people: const [],
);

void main() {
  Future<FakeEventShareService> pump(
    WidgetTester tester,
    EventView view,
  ) async {
    final fake = FakeEventShareService(view);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventShareServiceProvider.overrideWithValue(fake),
          // Signed out — the state every share link starts in.
          currentUserProvider.overrideWithValue(const AsyncValue<User?>.data(null)),
        ],
        child: MaterialApp(home: const EventShareScreen(token: 't.s')),
      ),
    );
    await tester.pumpAndSettle();
    return fake;
  }

  testWidgets('a venue sees titles and NO key or BPM anywhere on the page', (
    tester,
  ) async {
    await pump(
      tester,
      _view(
        access: const {
          EventArea.eventInfo: EventAccessLevel.view,
          EventArea.runningOrder: EventAccessLevel.view,
        },
        canSuggest: true,
      ),
    );

    expect(find.text('visto'), findsOneWidget);
    expect(find.textContaining('Sputnik Bar, Lisbon'), findsOneWidget);
    // The promise of the whole feature, asserted against the rendered tree.
    expect(find.textContaining('Bm'), findsNothing);
    expect(find.textContaining('BPM'), findsNothing);
    expect(find.text('Stage plot'), findsNothing);
    expect(find.text('Equipment'), findsNothing);
  });

  testWidgets('a performer with songDetail does see key and BPM', (
    tester,
  ) async {
    await pump(
      tester,
      _view(
        access: const {
          EventArea.runningOrder: EventAccessLevel.view,
          EventArea.songDetail: EventAccessLevel.view,
        },
        withChart: true,
      ),
    );
    expect(find.textContaining('Bm'), findsOneWidget);
    expect(find.textContaining('96 BPM'), findsOneWidget);
  });

  testWidgets('an edit grant offers Sign in to edit', (tester) async {
    await pump(
      tester,
      _view(access: const {EventArea.stage: EventAccessLevel.edit}),
    );
    expect(find.text('Sign in to edit'), findsOneWidget);
    expect(find.text('Suggest a change'), findsNothing);
  });

  testWidgets('a view-only recipient is never pushed into a signup', (
    tester,
  ) async {
    await pump(
      tester,
      _view(
        access: const {
          EventArea.eventInfo: EventAccessLevel.view,
          EventArea.runningOrder: EventAccessLevel.view,
        },
        canSuggest: true,
      ),
    );
    expect(find.text('Sign in to edit'), findsNothing);
    expect(find.text('Suggest a change'), findsOneWidget);
  });

  testWidgets('a suggestion actually reaches the service', (tester) async {
    final fake = await pump(
      tester,
      _view(
        access: const {EventArea.runningOrder: EventAccessLevel.view},
        canSuggest: true,
      ),
    );

    await tester.tap(find.text('Suggest a change'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Please drop the last song');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(fake.suggestions, ['Please drop the last song']);
  });

  testWidgets('a granted stage plot renders for the person who holds it', (
    tester,
  ) async {
    await pump(
      tester,
      EventView(
        setlistId: 'sl1',
        name: 'Gig',
        access: const {EventArea.stage: EventAccessLevel.view},
        canSuggest: false,
        stage: const {
          'back-left': [
            {'kind': 'equipment', 'label': 'Drum kit'},
          ],
        },
      ),
    );
    expect(find.text('Stage plot'), findsOneWidget);
    expect(find.textContaining('Drum kit'), findsOneWidget);
  });
}
