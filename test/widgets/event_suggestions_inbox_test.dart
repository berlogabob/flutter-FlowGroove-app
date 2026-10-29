import 'dart:async';

import 'package:flowgroove/models/event_suggestion.dart';
import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/models/song.dart';
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
    bool withCachedOrder = false,
  }) async {
    final recorder = _Recorder();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (withCachedOrder) ...[
            bandSetlistsProvider('band-1').overrideWith(
              (ref) => Stream.value([
                Setlist(
                  id: 'sl-1',
                  bandId: 'band-1',
                  name: 'Gig',
                  createdAt: DateTime(2026),
                  updatedAt: DateTime(2026),
                  items: const [
                    SetlistItem(id: 'first', songId: 's1'),
                    SetlistItem(id: 'second', songId: 's2'),
                  ],
                ),
              ]),
            ),
            setlistSongsProvider(('band-1', 'sl-1')).overrideWith(
              (ref) => AsyncValue.data([
                Song(
                  id: 's1',
                  title: 'First song',
                  artist: '',
                  createdAt: DateTime(2026),
                  updatedAt: DateTime(2026),
                ),
                Song(
                  id: 's2',
                  title: 'Second song',
                  artist: '',
                  createdAt: DateTime(2026),
                  updatedAt: DateTime(2026),
                ),
              ]),
            ),
          ],

          setlistSuggestionsProvider((
            'band-1',
            'sl-1',
          )).overrideWith((ref) => Stream.value(suggestions)),
          eventShareServiceProvider.overrideWithValue(
            EventShareService(invoker: recorder.call),
          ),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            if (withCachedOrder) {
              ref
                ..watch(bandSetlistsProvider('band-1'))
                ..watch(setlistSongsProvider(('band-1', 'sl-1')));
            }
            return MaterialApp(
              home: Scaffold(
                body: EventSuggestionsInbox(
                  bandId: 'band-1',
                  setlistId: 'sl-1',
                  canResolve: canResolve,
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    return recorder;
  }

  for (final entry in [
    ({'kind': 'add', 'songId': 'new'}, 'Add "Snapshot title"'),
    ({'kind': 'remove', 'itemId': 'second'}, 'Remove a song'),
    (
      {
        'kind': 'reorder',
        'itemIds': ['second', 'first'],
      },
      'Move running order to: a song → a song',
    ),
  ]) {
    testWidgets(
      'typed inbox renders ${entry.$1['kind']} with actions and note',
      (tester) async {
        final recorder = await pump(
          tester,
          suggestions: [
            EventSuggestion.fromJson({
              'id': 'typed',
              'type': entry.$1['kind'],
              'text': 'Keep note',
              'candidate': {'id': 'new', 'title': 'Snapshot title'},
              'proposal': {
                'version': 1,
                'baseFingerprint': 'f' * 64,
                ...entry.$1,
              },
            }),
          ],
        );
        expect(find.text(entry.$2), findsOneWidget);
        expect(find.text('Keep note'), findsOneWidget);
        expect(find.text('Apply'), findsOneWidget);
        expect(find.text('Dismiss'), findsOneWidget);
        await tester.tap(find.text('Apply'));
        await tester.pump();
        expect(recorder.calls, [(suggestionId: 'typed', accept: true)]);
      },
    );
  }

  for (final entry in [
    ({'kind': 'remove', 'itemId': 'second'}, 'Remove "Second song"'),
    (
      {
        'kind': 'reorder',
        'itemIds': ['second', 'first'],
      },
      'Move running order to: "Second song" → "First song"',
    ),
  ]) {
    testWidgets('inbox uses cached order for ${entry.$1['kind']}', (
      tester,
    ) async {
      final recorder = await pump(
        tester,
        withCachedOrder: true,
        suggestions: [
          EventSuggestion.fromJson({
            'id': 'typed',
            'type': entry.$1['kind'],
            'proposal': {
              'version': 1,
              'baseFingerprint': 'f' * 64,
              ...entry.$1,
            },
          }),
        ],
      );
      await tester.pump();
      expect(find.text(entry.$2), findsOneWidget);
      await tester.tap(find.text('Dismiss'));
      await tester.pump();
      expect(recorder.calls, [(suggestionId: 'typed', accept: false)]);
    });
  }

  testWidgets('renders nothing when nobody has asked for anything', (
    tester,
  ) async {
    await pump(tester, suggestions: const []);
    expect(find.textContaining('Requests'), findsNothing);
  });

  testWidgets('shows loading while requests have not arrived', (tester) async {
    final controller = StreamController<List<EventSuggestion>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          setlistSuggestionsProvider((
            'band-1',
            'sl-1',
          )).overrideWith((ref) => controller.stream),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: EventSuggestionsInbox(
              bandId: 'band-1',
              setlistId: 'sl-1',
              canResolve: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(controller.close());
  });

  for (final personal in [false, true]) {
    testWidgets(
      '${personal ? 'personal' : 'band'} inbox retries its own stream and retains cached requests',
      (tester) async {
        final streams = <StreamController<List<EventSuggestion>>>[];
        final provider = personal
            ? personalSetlistSuggestionsProvider(('owner', 'sl-1'))
            : setlistSuggestionsProvider(('band-1', 'sl-1'));
        final container = ProviderContainer(
          overrides: [
            provider.overrideWith((ref) {
              final stream = StreamController<List<EventSuggestion>>();
              streams.add(stream);
              ref.onDispose(() => unawaited(stream.close()));
              return stream.stream;
            }),
          ],
        );
        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                home: Scaffold(
                  body: EventSuggestionsInbox(
                    bandId: personal ? null : 'band-1',
                    ownerUid: personal ? 'owner' : null,
                    setlistId: 'sl-1',
                    canResolve: false,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(streams, hasLength(1));
          streams[0].addError(StateError('offline'));
          await tester.pump();
          expect(find.text('Unable to load event requests.'), findsOneWidget);
          await tester.tap(find.text('Retry'));
          await tester.pump();
          expect(streams, hasLength(2));
          streams[1].add([suggestion()]);
          await tester.pump();
          expect(find.text('Requests (1 open)'), findsOneWidget);
          expect(find.text('Retry'), findsNothing);
          expect(find.text('Accept'), findsNothing);
          container.invalidate(provider);
          await tester.pump();
          expect(streams, hasLength(3));
          expect(find.text('Please play our first dance'), findsOneWidget);
          expect(find.byType(LinearProgressIndicator), findsOneWidget);
          streams[2].addError(StateError('refresh failed'));
          await tester.pump();
          expect(find.text('Please play our first dance'), findsOneWidget);
          expect(
            find.text('Could not refresh event requests.'),
            findsOneWidget,
          );
          await tester.tap(find.text('Retry'));
          await tester.pump();
          expect(streams, hasLength(4));
          streams[3].add(const []);
          await tester.pump();
          expect(find.textContaining('Requests'), findsNothing);
          expect(find.text('Retry'), findsNothing);
          expect(find.byType(LinearProgressIndicator), findsNothing);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        }
      },
    );
  }

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
