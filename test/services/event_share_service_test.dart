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

  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> args) async {
    calls.add((name: name, args: args));
    if (throwThis != null) throw throwThis!;
    return reply;
  }
}

void main() {
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

    test('createShare calls createEventShare and returns the raw token', () async {
      final invoker = _RecordingInvoker({'token': 'tok-1.secret', 'tokenId': 'tok-1'});
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
    });

    test('createShare returns empty rather than throwing on a token-less reply', () async {
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
    });

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

    test('submitSuggestion omits the keys it was not given', () async {
      // token vs bandId/setlistId is how the server tells an anonymous link
      // holder from a signed-in member. Sending `token: null` alongside a
      // bandId is a different request from sending no token at all.
      final invoker = _RecordingInvoker();
      final service = containerWith(invoker).read(eventShareServiceProvider);

      await service.submitSuggestion(token: 'tok-1.secret', type: 'note', text: 'hi');

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
