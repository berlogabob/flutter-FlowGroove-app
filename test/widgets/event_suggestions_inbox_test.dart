import 'package:flowgroove/models/event_suggestion.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/services/event_share_service.dart';
import 'package:flowgroove/widgets/event_suggestions_inbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what the inbox sent, so the test asserts the answer that reaches
/// the server rather than that a button merely existed.
class _Recorder {
  final calls = <({String suggestionId, bool accept})>[];

  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> args,
  ) async {
    if (name == 'resolveSuggestion') {
      calls.add((
        suggestionId: args['suggestionId'] as String,
        accept: args['accept'] as bool,
      ));
    }
    return {'status': 'ok'};
  }
}

void main() {
  testWidgets('personal owner resolves a request with ownerUid and no bandId', (
    tester,
  ) async {
    Map<String, dynamic>? payload;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalSetlistSuggestionsProvider(('owner', 'sl1')).overrideWith(
            (ref) => Stream.value([
              const EventSuggestion(
                id: 'request',
                type: 'note',
                text: 'Encore',
                status: 'open',
              ),
            ]),
          ),
          eventShareServiceProvider.overrideWithValue(
            EventShareService(
              invoker: (name, args) async {
                expect(name, 'resolveSuggestion');
                payload = args;
                return {};
              },
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: EventSuggestionsInbox(
              ownerUid: 'owner',
              setlistId: 'sl1',
              canResolve: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(payload, {
      'ownerUid': 'owner',
      'setlistId': 'sl1',
      'suggestionId': 'request',
      'accept': true,
    });
  });

  EventSuggestion suggestion({
    String id = 'sug-1',
    String status = 'open',
    String text = 'Please play our first dance',
  }) => EventSuggestion(
    id: id,
    type: 'add',
    text: text,
    status: status,
    authorName: 'Ana & Rui',
  );

  Future<_Recorder> pump(
    WidgetTester tester, {
    required List<EventSuggestion> suggestions,
    bool canResolve = true,
  }) async {
    final recorder = _Recorder();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          setlistSuggestionsProvider((
            'band-1',
            'sl-1',
          )).overrideWith((ref) => Stream.value(suggestions)),
          eventShareServiceProvider.overrideWithValue(
            EventShareService(invoker: recorder.call),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: EventSuggestionsInbox(
              bandId: 'band-1',
              setlistId: 'sl-1',
              canResolve: canResolve,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return recorder;
  }

  testWidgets('renders nothing when nobody has asked for anything', (
    tester,
  ) async {
    await pump(tester, suggestions: const []);
    expect(find.textContaining('Requests'), findsNothing);
  });

  testWidgets('shows a guest request attributed to the assigned name', (
    tester,
  ) async {
    await pump(tester, suggestions: [suggestion()]);
    expect(find.text('Requests (1 open)'), findsOneWidget);
    expect(find.text('Ana & Rui asked to add a song'), findsOneWidget);
    expect(find.text('Please play our first dance'), findsOneWidget);
  });

  testWidgets('accepting sends accept:true for that suggestion', (
    tester,
  ) async {
    final recorder = await pump(tester, suggestions: [suggestion()]);
    await tester.tap(find.text('Accept'));
    await tester.pump();
    expect(recorder.calls, [(suggestionId: 'sug-1', accept: true)]);
  });

  testWidgets('declining sends accept:false, not a missing flag', (
    tester,
  ) async {
    final recorder = await pump(tester, suggestions: [suggestion()]);
    await tester.tap(find.text('Decline'));
    await tester.pump();
    expect(recorder.calls, [(suggestionId: 'sug-1', accept: false)]);
  });

  testWidgets('an already-answered request shows its outcome, not buttons', (
    tester,
  ) async {
    await pump(tester, suggestions: [suggestion(status: 'accepted')]);
    expect(find.text('Accepted'), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
    expect(find.text('Decline'), findsNothing);
  });

  testWidgets('a plain member sees the request but cannot answer it', (
    tester,
  ) async {
    // resolveSuggestion needs band editor/admin; the callable refuses anyone
    // else, so offering the buttons would only produce a failure snackbar.
    await pump(tester, suggestions: [suggestion()], canResolve: false);
    expect(find.text('Waiting for a band editor'), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
  });

  testWidgets('open requests sort above answered ones', (tester) async {
    await pump(
      tester,
      suggestions: [
        suggestion(id: 'a', status: 'open', text: 'still open'),
        suggestion(id: 'b', status: 'declined', text: 'already declined'),
      ],
    );
    final open = tester.getTopLeft(find.text('still open'));
    final done = tester.getTopLeft(find.text('already declined'));
    expect(open.dy, lessThan(done.dy));
  });
}
