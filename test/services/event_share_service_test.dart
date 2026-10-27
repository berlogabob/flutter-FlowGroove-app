import 'package:flowgroove/models/event_access.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/services/event_share_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every callable invocation and replies with a canned payload.
class _RecordingInvoker {
  _RecordingInvoker([this.reply = const <String, dynamic>{}]);

  final Map<String, dynamic> reply;
  final calls = <({String name, Map<String, dynamic> args})>[];
  Object? throwThis;

  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> args,
  ) async {
    calls.add((name: name, args: args));
    if (throwThis != null) throw throwThis!;
    return reply;
  }
}

void main() {
  test('EventView retains typed own requests with their status and note', () {
    final view = EventView.fromMap({
      'mySuggestions': [
        {
          'type': 'add',
          'status': 'accepted',
          'text': 'First dance',
          'candidate': {'id': 'new', 'title': 'Snapshot title'},
          'proposal': {
            'version': 1,
            'kind': 'add',
            'baseFingerprint': 'f' * 64,
            'songId': 'new',
          },
        },
      ],
    });
    final request = view.mySuggestions.single;
    expect(request.description(), 'Add "Snapshot title"');
    expect(request.status, 'accepted');
    expect(request.text, 'First dance');
  });

  for (final scope in [
    {'bandId': 'b1'},
    {'ownerUid': 'u1'},
  ]) {
    test('publishes and unpublishes a candidate in $scope', () async {
      final recorder = _RecordingInvoker();
      final service = EventShareService(invoker: recorder.call);
      for (final published in [true, false]) {
        await service.setSuggestionCandidate(
          bandId: scope['bandId'],
          ownerUid: scope['ownerUid'],
          setlistId: 'sl1',
          songId: 's1',
          published: published,
        );
        expect(recorder.calls.last.name, 'setEventSuggestionCandidate');
        expect(recorder.calls.last.args, {
          ...scope,
          'setlistId': 'sl1',
          'songId': 's1',
          'published': published,
        });
      }
    });
  }

  test('EventView decodes published candidates and defaults to empty', () {
    const candidates = [
      {'id': 's1', 'title': 'Open song', 'artist': 'Artist'},
    ];
    expect(
      EventView.fromMap({
        'suggestionCandidates': candidates,
      }).suggestionCandidates,
      candidates,
    );
    expect(EventView.fromMap({}).suggestionCandidates, isEmpty);
  });

  group('songFromEventView', () {
    test('keeps the chart when songDetail was granted', () {
      final song = songFromEventView({
        'id': 's1',
        'title': 'visto',
        'artist': 'Flor Damico',
        'ourKey': 'Bm',
        'ourBPM': 96,
        'sections': [
          {'id': 'sec1', 'name': 'Verse 1', 'chordChart': '[Am]Ya no necesito'},
        ],
      });
      expect(song.ourKey, 'Bm');
      expect(song.ourBPM, 96);
      expect(song.sections.single.chordChart, '[Am]Ya no necesito');
    });

    test('a title-only song is scoped, not broken', () {
      // What a wedding couple receives: the server sent no key, BPM or
      // sections at all, so the Song legitimately has none.
      final song = songFromEventView({
        'id': 's1',
        'title': 'visto',
        'artist': 'Flor Damico',
      });
      expect(song.title, 'visto');
      expect(song.ourKey, isNull);
      expect(song.ourBPM, isNull);
      expect(song.sections, isEmpty);
    });

    test('survives a section saved before ids existed', () {
      final song = songFromEventView({
        'id': 's1',
        'title': 'x',
        'artist': 'y',
        'sections': [
          {'name': 'Chorus', 'chordChart': '[C]la'},
        ],
      });
      expect(song.sections.single.id, isNotEmpty);
      expect(song.sections.single.name, 'Chorus');
    });
  });

  group('EventView', () {
    test('decodes running-order readiness and preserves item occurrences', () {
      final fingerprint = 'a' * 64;
      final items = [
        {'id': 'occurrence-1', 'songId': 'same-song', 'type': 'song'},
        {'id': 'break-1', 'type': 'break', 'breakLabel': 'Interval'},
        {'id': 'occurrence-2', 'songId': 'same-song', 'type': 'song'},
      ];
      final ready = EventView.fromMap({
        'setlistId': 'sl1',
        'name': 'Gig',
        'viewer': {'access': <String, dynamic>{}, 'canSuggest': false},
        'items': [
          {'id': 'legacy'},
        ],
        'runningOrder': {
          'ready': true,
          'items': items,
          'baseFingerprint': fingerprint,
        },
      });
      expect(ready.runningOrderReady, isTrue);
      expect(ready.baseFingerprint, fingerprint);
      expect(ready.runningOrderItems, items);
      expect(ready.items, [
        {'id': 'legacy'},
      ]);

      for (final input in [
        <String, dynamic>{},
        {
          'runningOrder': <String, dynamic>{'ready': false},
        },
        {
          'runningOrder': {
            'ready': true,
            'items': items,
            'baseFingerprint': 'invalid',
          },
        },
      ]) {
        final view = EventView.fromMap({
          'setlistId': 'sl1',
          'name': 'Gig',
          'viewer': {'access': <String, dynamic>{}, 'canSuggest': false},
          ...input,
        });
        expect(view.runningOrderReady, isFalse);
        expect(view.runningOrderItems, isNull);
        expect(view.baseFingerprint, isNull);
      }
    });

    test('distinguishes "not shared with you" from empty', () {
      final hidden = EventView.fromMap({
        'setlistId': 'sl1',
        'name': 'Gig',
        'viewer': {'access': <String, dynamic>{}, 'canSuggest': false},
      });
      // Null means the server never sent the area — the UI must not render an
      // empty stage plot as though the plot were simply blank.
      expect(hidden.stage, isNull);
      expect(hidden.rider, isNull);
      expect(hidden.canSee(EventArea.stage), isFalse);

      final empty = EventView.fromMap({
        'setlistId': 'sl1',
        'name': 'Gig',
        'viewer': {
          'access': {EventArea.stage: 'view'},
          'canSuggest': false,
        },
        'stage': <String, dynamic>{},
      });
      expect(empty.stage, isNotNull);
      expect(empty.stage, isEmpty);
      expect(empty.canSee(EventArea.stage), isTrue);
    });

    test('drops an access level the server should never have sent', () {
      final view = EventView.fromMap({
        'setlistId': 'sl1',
        'name': 'Gig',
        'viewer': {
          'access': {EventArea.songDetail: 'owner', 'wholeBand': 'edit'},
          'canSuggest': false,
        },
      });
      expect(view.access, isEmpty);
      expect(view.canSee(EventArea.songDetail), isFalse);
    });
  });

  // The write wrappers had no test at all — the only grep hit was a comment
  // saying so. They are thin, but "thin" is where a wrong callable name or a
  // dropped argument hides: the failure is a runtime not-found on a real
  // device, not a compile error.
  test('personal event callables send ownerUid and omit bandId', () async {
    final invoker = _RecordingInvoker({'token': 'personal.secret'});
    final service = EventShareService(invoker: invoker.call);
    expect(
      await service.createShare(
        ownerUid: 'owner',
        setlistId: 's',
        participantId: 'p',
      ),
      'personal.secret',
    );
    await service.getEventView(ownerUid: 'owner', setlistId: 's');
    await service.submitSuggestion(
      ownerUid: 'owner',
      setlistId: 's',
      type: 'note',
      text: 'hi',
    );
    await service.resolveSuggestion(
      ownerUid: 'owner',
      setlistId: 's',
      suggestionId: 'request',
      accept: false,
    );
    expect(invoker.calls.map((c) => c.name), [
      'createEventShare',
      'getEventView',
      'submitSuggestion',
      'resolveSuggestion',
    ]);
    for (final call in invoker.calls) {
      expect(call.args['ownerUid'], 'owner');
      expect(call.args['setlistId'], 's');
      expect(call.args.containsKey('bandId'), isFalse);
      expect(call.args.containsKey('token'), isFalse);
    }
  });

  test(
    'listShares decodes a safe bounded inventory page and exact scope',
    () async {
      final invoker = _RecordingInvoker({
        'shares': [
          {
            'tokenId': 'link-1',
            'participantId': 'person-1',
            'name': 'Engineer',
            'role': 'Sound',
            'access': {'stage': 'view', 'rider': 'edit', 'secret': 'edit'},
            'createdAt': '2026-10-25T10:00:00.000Z',
            'expiresAt': null,
            'state': 'active',
            'token': 'must-not-retain',
            'uid': 'private',
          },
        ],
        'hasMore': true,
        'nextCursor': 'link-1',
      });
      final service = EventShareService(invoker: invoker.call);
      final page = await service.listShares(
        bandId: 'band-1',
        setlistId: 'event-1',
      );
      expect(invoker.calls.single.name, 'listEventShares');
      expect(invoker.calls.single.args, {
        'bandId': 'band-1',
        'setlistId': 'event-1',
      });
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, 'link-1');
      expect(page.shares.single.tokenId, 'link-1');
      expect(page.shares.single.participantId, 'person-1');
      expect(page.shares.single.name, 'Engineer');
      expect(page.shares.single.role, 'Sound');
      expect(page.shares.single.access, {'stage': 'view', 'rider': 'edit'});
      expect(page.shares.single.createdAt, DateTime.utc(2026, 10, 25, 10));
      expect(page.shares.single.expiresAt, isNull);
      expect(page.shares.single.state, 'active');
    },
  );

  test(
    'listShares rejects malformed inventory instead of silently dropping rows',
    () async {
      final row = <String, dynamic>{
        'tokenId': 'link-2',
        'participantId': '',
        'name': '',
        'role': '',
        'access': <String, String>{},
        'createdAt': null,
        'expiresAt': null,
        'state': 'unavailable',
      };
      final valid = <String, dynamic>{
        'shares': [row],
        'hasMore': false,
        'nextCursor': null,
      };
      for (final bad in <Map<String, dynamic>>[
        {},
        {...valid, 'shares': null},
        {
          ...valid,
          'shares': [null],
        },
        {...valid, 'shares': List.filled(51, row)},
        {
          ...valid,
          'shares': [row, row],
        },
        {...valid, 'hasMore': 'false'},
        {...valid, 'nextCursor': 'unexpected'},
        {...valid, 'hasMore': true, 'nextCursor': null},
        {...valid, 'hasMore': true, 'nextCursor': 'other'},
        {'shares': <Object?>[], 'hasMore': true, 'nextCursor': 'link-2'},
        for (final field in <Map<String, dynamic>>[
          {'tokenId': ''},
          {'tokenId': 'bad/id'},
          {'participantId': 1},
          {'name': null},
          {'role': false},
          {'access': <Object?>[]},
          {
            'access': {'stage': 5},
          },
          {'state': 'unknown'},
          {'createdAt': 'not a date'},
          {'expiresAt': 17},
          {'createdAt': '2026-02-31T10:00:00.000Z'},
        ])
          {
            ...valid,
            'shares': [
              {...row, ...field},
            ],
          },
      ]) {
        final invoker = _RecordingInvoker(bad);
        await expectLater(
          EventShareService(
            invoker: invoker.call,
          ).listShares(ownerUid: 'owner', setlistId: 'event'),
          throwsFormatException,
          reason: '$bad',
        );
      }
    },
  );

  test(
    'listShares traverses both scopes, all states and an empty terminal page',
    () async {
      final calls = <Map<String, dynamic>>[];
      final service = EventShareService(
        invoker: (name, args) async {
          expect(name, 'listEventShares');
          calls.add(args);
          if (args['cursor'] != null)
            return {
              'shares': <Object?>[],
              'hasMore': false,
              'nextCursor': null,
            };
          return {
            'shares': [
              for (final state in [
                'active',
                'revoked',
                'expired',
                'unavailable',
              ])
                {
                  'tokenId': 'link-$state',
                  'participantId': 'person',
                  'name': 'Person',
                  'role': 'Guest',
                  'access': <String, String>{},
                  'createdAt': null,
                  'expiresAt': '2026-10-26T00:00:00.000Z',
                  'state': state,
                },
            ],
            'hasMore': true,
            'nextCursor': 'link-unavailable',
          };
        },
      );
      for (final personal in [false, true]) {
        final page = await service.listShares(
          bandId: personal ? null : 'band',
          ownerUid: personal ? 'owner' : null,
          setlistId: 'event',
        );
        expect(page.shares.map((s) => s.state), [
          'active',
          'revoked',
          'expired',
          'unavailable',
        ]);
        expect(page.shares.last.expiresAt, DateTime.utc(2026, 10, 26));
        expect(() => page.shares.clear(), throwsUnsupportedError);
        expect(() => page.shares.first.access.clear(), throwsUnsupportedError);
        final end = await service.listShares(
          bandId: personal ? null : 'band',
          ownerUid: personal ? 'owner' : null,
          setlistId: 'event',
          cursor: page.nextCursor,
        );
        expect(end.shares, isEmpty);
        expect(end.hasMore, isFalse);
        expect(end.nextCursor, isNull);
        final scope = personal ? {'ownerUid': 'owner'} : {'bandId': 'band'};
        expect(calls[calls.length - 2], {...scope, 'setlistId': 'event'});
        expect(calls.last, {
          ...scope,
          'setlistId': 'event',
          'cursor': 'link-unavailable',
        });
      }
      final failure = StateError('permission denied');
      await expectLater(
        EventShareService(
          invoker: (_, _) async => throw failure,
        ).listShares(ownerUid: 'owner', setlistId: 'event'),
        throwsA(same(failure)),
      );
    },
  );

  test(
    'listShares rejects a page that does not advance the requested cursor',
    () async {
      final invoker = _RecordingInvoker({
        'shares': [
          {
            'tokenId': 'link-2',
            'participantId': '',
            'name': '',
            'role': '',
            'access': <String, String>{},
            'createdAt': null,
            'expiresAt': null,
            'state': 'unavailable',
          },
        ],
        'hasMore': true,
        'nextCursor': 'link-2',
      });
      for (final cursor in ['link-2', 'link-3']) {
        await expectLater(
          EventShareService(
            invoker: invoker.call,
          ).listShares(bandId: 'band', setlistId: 'event', cursor: cursor),
          throwsFormatException,
        );
      }
    },
  );

  group('write wrappers', () {
    ProviderContainer containerWith(_RecordingInvoker invoker) {
      final container = ProviderContainer(
        overrides: [
          eventShareServiceProvider.overrideWithValue(
            EventShareService(invoker: invoker.call),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test(
      'createShare calls createEventShare and returns the raw token',
      () async {
        final invoker = _RecordingInvoker({
          'token': 'tok-1.secret',
          'tokenId': 'tok-1',
        });
        final service = containerWith(invoker).read(eventShareServiceProvider);

        final token = await service.createShare(
          bandId: 'band-1',
          setlistId: 'sl-1',
          participantId: 'p-eng',
        );

        expect(token, 'tok-1.secret');
        expect(invoker.calls.single.name, 'createEventShare');
        expect(invoker.calls.single.args, {
          'bandId': 'band-1',
          'setlistId': 'sl-1',
          'participantId': 'p-eng',
        });
      },
    );

    test(
      'createShare returns empty rather than throwing on a token-less reply',
      () async {
        // Defensive: a deploy skew where the callable stops returning `token`
        // must not crash the share sheet with a null cast.
        final invoker = _RecordingInvoker({'tokenId': 'tok-1'});
        final service = containerWith(invoker).read(eventShareServiceProvider);
        expect(
          await service.createShare(
            bandId: 'b',
            setlistId: 's',
            participantId: 'p',
          ),
          '',
        );
      },
    );

    test('revokeShare calls revokeEventShare with the tokenId', () async {
      final invoker = _RecordingInvoker({'revoked': true});
      final service = containerWith(invoker).read(eventShareServiceProvider);

      await service.revokeShare('tok-1');

      expect(invoker.calls.single.name, 'revokeEventShare');
      expect(invoker.calls.single.args, {'tokenId': 'tok-1'});
    });

    test('claimShare calls claimEventShare and hands back the grant', () async {
      final invoker = _RecordingInvoker({
        'access': {'stage': 'edit'},
      });
      final service = containerWith(invoker).read(eventShareServiceProvider);

      final out = await service.claimShare('tok-1.secret');

      expect(invoker.calls.single.name, 'claimEventShare');
      expect(invoker.calls.single.args, {'token': 'tok-1.secret'});
      expect((out['access'] as Map)['stage'], 'edit');
    });

    test('resolveSuggestion sends the accept flag as a real bool', () async {
      // `accept: false` must survive: the null-stripping in _call drops absent
      // values, and a decline sent as a missing key would read as an accept.
      final invoker = _RecordingInvoker({'status': 'declined'});
      final service = containerWith(invoker).read(eventShareServiceProvider);

      await service.resolveSuggestion(
        bandId: 'band-1',
        setlistId: 'sl-1',
        suggestionId: 'sug-1',
        accept: false,
      );

      expect(invoker.calls.single.name, 'resolveSuggestion');
      expect(invoker.calls.single.args['accept'], false);
    });

    test(
      'submitSuggestion forwards a proposal unchanged in each scope',
      () async {
        final proposal = {
          'version': 1,
          'kind': 'add',
          'baseFingerprint': 'a' * 64,
          'songId': 'song-1',
          'beforeItemId': 'occurrence-2',
        };
        final invoker = _RecordingInvoker();
        final service = containerWith(invoker).read(eventShareServiceProvider);
        await service.submitSuggestion(
          bandId: 'band-1',
          setlistId: 'sl-1',
          type: 'add',
          proposal: proposal,
        );
        expect(invoker.calls.single.args['proposal'], same(proposal));
        expect(invoker.calls.single.args['bandId'], 'band-1');
        expect(invoker.calls.single.args.containsKey('token'), isFalse);

        await service.submitSuggestion(
          ownerUid: 'owner-1',
          setlistId: 'sl-1',
          type: 'add',
          proposal: proposal,
        );
        expect(invoker.calls.last.args['proposal'], same(proposal));
        expect(invoker.calls.last.args['ownerUid'], 'owner-1');
        expect(invoker.calls.last.args.containsKey('bandId'), isFalse);
        expect(invoker.calls.last.args.containsKey('token'), isFalse);

        await service.submitSuggestion(
          token: 'tok.secret',
          type: 'add',
          proposal: proposal,
        );
        expect(invoker.calls.last.args['proposal'], same(proposal));
        expect(invoker.calls.last.args['token'], 'tok.secret');
        expect(invoker.calls.last.args.containsKey('bandId'), isFalse);
        expect(invoker.calls.last.args.containsKey('ownerUid'), isFalse);
        final scopes = [
          {'bandId': 'band-1', 'setlistId': 'sl-1'},
          {'ownerUid': 'owner-1', 'setlistId': 'sl-1'},
          {'token': 'tok.secret'},
        ];
        for (var i = 0; i < scopes.length; i++) {
          expect(invoker.calls[i].name, 'submitSuggestion');
          expect(invoker.calls[i].args, {
            ...scopes[i],
            'type': 'add',
            'proposal': proposal,
          });
        }
        for (final operation in [
          {'kind': 'remove', 'itemId': 'occurrence-2'},
          {
            'kind': 'reorder',
            'itemIds': ['occurrence-2', 'break-1', 'occurrence-1'],
          },
        ]) {
          final typed = {
            'version': 1,
            'baseFingerprint': 'a' * 64,
            ...operation,
          };
          await service.submitSuggestion(
            token: 'tok.secret',
            type: operation['kind']! as String,
            text: 'Please review',
            proposal: typed,
          );
          expect(invoker.calls.last.name, 'submitSuggestion');
          expect(invoker.calls.last.args, {
            'token': 'tok.secret',
            'type': operation['kind'],
            'text': 'Please review',
            'proposal': typed,
          });
        }
        invoker.throwThis = StateError('stale proposal');
        await expectLater(
          service.submitSuggestion(
            token: 'tok.secret',
            type: 'add',
            proposal: proposal,
          ),
          throwsStateError,
        );
      },
    );

    test('submitSuggestion omits the keys it was not given', () async {
      // token vs bandId/setlistId is how the server tells an anonymous link
      // holder from a signed-in member. Sending `token: null` alongside a
      // bandId is a different request from sending no token at all.
      final invoker = _RecordingInvoker();
      final service = containerWith(invoker).read(eventShareServiceProvider);

      await service.submitSuggestion(
        token: 'tok-1.secret',
        type: 'note',
        text: 'hi',
      );

      expect(invoker.calls.single.args.containsKey('bandId'), isFalse);
      expect(invoker.calls.single.args.containsKey('songId'), isFalse);
      expect(invoker.calls.single.args, {
        'token': 'tok-1.secret',
        'type': 'note',
        'text': 'hi',
      });
    });

    test('a callable failure propagates instead of being swallowed', () async {
      final invoker = _RecordingInvoker()..throwThis = StateError('offline');
      final service = containerWith(invoker).read(eventShareServiceProvider);
      await expectLater(service.revokeShare('tok-1'), throwsStateError);
    });
  });

  group('EventView.mySuggestions', () {
    test('carries the status the band decided', () {
      final view = EventView.fromMap({
        'setlistId': 'sl1',
        'name': 'Gig',
        'viewer': {'access': <String, dynamic>{}, 'canSuggest': true},
        'mySuggestions': [
          {
            'id': 'sug-1',
            'type': 'note',
            'text': 'Swap the last song please',
            'status': 'accepted',
          },
        ],
      });
      expect(view.mySuggestions.single.status, 'accepted');
      expect(view.mySuggestions.single.isOpen, isFalse);
      expect(view.mySuggestions.single.text, 'Swap the last song please');
    });

    test('is empty when the server sent none', () {
      final view = EventView.fromMap({
        'setlistId': 'sl1',
        'name': 'Gig',
        'viewer': {'access': <String, dynamic>{}, 'canSuggest': false},
      });
      expect(view.mySuggestions, isEmpty);
    });
  });
}
