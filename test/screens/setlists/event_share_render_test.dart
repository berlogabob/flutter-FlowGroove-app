// Rendering EventShareScreen for real, rather than asserting a helper that
// mirrors its gating expression.
//
// The audit ticked "view-only recipients never prompted" and "a venue sees no
// chart data" on the strength of mirror tests — functions in the test file that
// duplicated the widget's condition. Those pass just as well if the widget
// stops using the condition. These render the page instead.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// Firebase Core's installed test mocks; no production dependency is needed.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flowgroove/models/event_access.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/screens/setlists/event_share_screen.dart';
import 'package:flowgroove/services/analytics_service.dart';
import 'package:flowgroove/services/event_share_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../helpers/mocks.mocks.dart';

/// Returns whatever the test asks for; records what was sent back.
class FakeEventShareService implements EventShareService {
  FakeEventShareService(this.view);

  final EventView view;
  final List<String> suggestions = [];
  final List<Map<String, dynamic>> submissions = [];
  bool failSubmit = false;
  bool failLoad = false;
  int loads = 0;

  @override
  Future<EventView> getEventView({
    String? token,
    String? bandId,
    String? ownerUid,
    String? setlistId,
  }) async {
    loads++;
    if (failLoad) throw StateError('denied');
    return view;
  }

  @override
  Future<Map<String, dynamic>> claimShare(String token) async => {
    'ownerUid': 'owner',
  };

  @override
  Future<void> submitSuggestion({
    String? token,
    String? bandId,
    String? ownerUid,
    String? setlistId,
    required String type,
    String? songId,
    String? text,
    Map<String, dynamic>? proposal,
  }) async {
    if (failSubmit) throw StateError('failed');
    suggestions.add(text ?? '');
    submissions.add({
      'token': token,
      'bandId': bandId,
      'ownerUid': ownerUid,
      'setlistId': setlistId,
      'type': type,
      'text': text,
      'proposal': proposal,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

EventView _view({
  required Map<String, String> access,
  bool canSuggest = false,
  bool withChart = false,
  bool ready = false,
  List<Map<String, dynamic>> candidates = const [],
}) => EventView(
  setlistId: 'sl1',
  ownerUid: 'owner',
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
  suggestionCandidates: candidates,
  runningOrderReady: ready,
  baseFingerprint: ready ? 'f' * 64 : null,
  runningOrderItems: ready
      ? const [
          {'id': 'occ-1', 'songId': 's1', 'type': 'song'},
          {'id': 'break-1', 'type': 'break', 'breakLabel': 'Dinner'},
          {'id': 'occ-2', 'songId': 's1', 'type': 'song'},
        ]
      : null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const analyticsChannel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.firebase_analytics_platform_interface.FirebaseAnalyticsHostApi.logEvent',
    StandardMessageCodec(),
  );
  final analyticsEvents = <Object?>[];
  var failAnalytics = false;
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });
  setUp(() {
    analyticsEvents.clear();
    failAnalytics = false;
    AnalyticsService.enabled = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(analyticsChannel, (
          message,
        ) async {
          analyticsEvents.add(message);
          return failAnalytics
              ? <Object?>['unavailable', 'SDK failure', null]
              : <Object?>[null];
        });
  });
  tearDown(() {
    AnalyticsService.enabled = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(analyticsChannel, null);
  });

  Future<FakeEventShareService> pump(
    WidgetTester tester,
    EventView view, {
    FakeEventShareService? service,
    bool direct = false,
    bool signedIn = false,
  }) async {
    final fake = service ?? FakeEventShareService(view);
    final user = MockUser();
    when(user.uid).thenReturn('guest');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventShareServiceProvider.overrideWithValue(fake),
          songsProvider.overrideWith(
            (ref) => throw StateError('guest read personal library'),
          ),
          bandSongsProvider.overrideWith(
            (ref, id) => throw StateError('guest read band library'),
          ),
          setlistSongsProvider.overrideWith(
            (ref, key) => throw StateError('guest read setlist library'),
          ),

          // Signed out — the state every share link starts in.
          currentUserProvider.overrideWithValue(
            AsyncValue<User?>.data(signedIn ? user : null),
          ),
        ],
        child: MaterialApp(
          home: direct
              ? const EventShareScreen(ownerUid: 'owner', setlistId: 'sl1')
              : const EventShareScreen(token: 't.s'),
        ),
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

  testWidgets('successful token view logs one link open', (tester) async {
    await pump(
      tester,
      _view(access: const {EventArea.eventInfo: EventAccessLevel.view}),
    );
    expect(analyticsEvents, [
      [
        {'eventName': 'event_link_opened', 'parameters': null},
      ],
    ]);
  });

  testWidgets('successful suggestion logs one payload-free event', (
    tester,
  ) async {
    await pump(
      tester,
      _view(
        access: const {EventArea.runningOrder: EventAccessLevel.view},
        canSuggest: true,
      ),
    );
    analyticsEvents.clear();
    await tester.tap(find.text('Suggest a change'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'private suggestion text');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(analyticsEvents, [
      [
        {'eventName': 'event_suggestion_submitted', 'parameters': null},
      ],
    ]);
  });

  testWidgets('failed token load logs nothing', (tester) async {
    final view = _view(access: const {});
    await pump(
      tester,
      view,
      service: FakeEventShareService(view)..failLoad = true,
    );
    expect(find.textContaining('This link is not valid'), findsOneWidget);
    expect(analyticsEvents, isEmpty);
  });

  testWidgets('refresh, rebuild and editor return do not repeat a token open', (
    tester,
  ) async {
    final fake = await pump(
      tester,
      _view(access: const {EventArea.stage: EventAccessLevel.view}),
      signedIn: true,
    );
    expect(fake.loads, 1);
    final refresh = tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await tester.pumpAndSettle();
    await refresh;
    expect(fake.loads, 2);
    tester.element(find.byType(EventShareScreen)).markNeedsBuild();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Event kit'));
    await tester.pumpAndSettle();
    expect(find.text('Back'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(fake.loads, 3);
    expect(analyticsEvents, [
      [
        {'eventName': 'event_link_opened', 'parameters': null},
      ],
      [
        {
          'eventName': 'back_used',
          'parameters': {'source': 'ui'},
        },
      ],
    ]);
  });

  testWidgets('direct owner logs suggestions but not link opens', (
    tester,
  ) async {
    final fake = await pump(
      tester,
      _view(access: const {}, canSuggest: true),
      direct: true,
    );
    expect(analyticsEvents, isEmpty);
    await tester.tap(find.text('Suggest a change'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'private owner note');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(fake.suggestions, ['private owner note']);
    expect(analyticsEvents, [
      [
        {'eventName': 'event_suggestion_submitted', 'parameters': null},
      ],
    ]);
  });

  for (final action in ['cancel', 'blank', 'failure']) {
    testWidgets('$action suggestion sends no analytics', (tester) async {
      final fake = await pump(
        tester,
        _view(access: const {}, canSuggest: true),
      );
      fake.failSubmit = action == 'failure';
      analyticsEvents.clear();
      await tester.tap(find.text('Suggest a change'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        action == 'blank' ? '   ' : 'private note',
      );
      await tester.tap(find.text(action == 'cancel' ? 'Cancel' : 'Send'));
      await tester.pumpAndSettle();
      expect(fake.suggestions, isEmpty);
      expect(analyticsEvents, isEmpty);
      if (action == 'failure')
        expect(find.textContaining('Could not send that:'), findsOneWidget);
    });
  }

  for (final sdkFailure in [false, true]) {
    testWidgets(
      sdkFailure
          ? 'SDK failure does not break viewing or suggesting'
          : 'consent off suppresses both rendered events',
      (tester) async {
        AnalyticsService.enabled = sdkFailure;
        failAnalytics = sdkFailure;
        final fake = await pump(
          tester,
          _view(access: const {}, canSuggest: true),
        );
        expect(find.text('Sputnik Bar'), findsOneWidget);
        await tester.tap(find.text('Suggest a change'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'private consent note');
        await tester.tap(find.text('Send'));
        await tester.pumpAndSettle();
        expect(fake.suggestions, ['private consent note']);
        expect(find.text('Sent to the band. Thanks!'), findsOneWidget);
        expect(
          analyticsEvents,
          sdkFailure
              ? [
                  [
                    {'eventName': 'event_link_opened', 'parameters': null},
                  ],
                  [
                    {
                      'eventName': 'event_suggestion_submitted',
                      'parameters': null,
                    },
                  ],
                ]
              : isEmpty,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

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
    expect(fake.submissions.single, {
      'token': 't.s',
      'bandId': null,
      'ownerUid': null,
      'setlistId': null,
      'type': 'note',
      'text': 'Please drop the last song',
      'proposal': null,
    });
  });

  for (final outcome in ['send', 'cancel', 'failure', 'consent-off']) {
    testWidgets(
      'published add candidate $outcome keeps proposal and note scoped',
      (tester) async {
        final fake = await pump(
          tester,
          _view(
            access: const {EventArea.runningOrder: EventAccessLevel.view},
            canSuggest: true,
            ready: true,
            candidates: const [
              {
                'id': 's2',
                'title': 'Open song',
                'artist': 'Candidate artist',
                'ourKey': 'Secret key',
                'notes': 'Private chart',
              },
            ],
          ),
        );
        fake.failSubmit = outcome == 'failure';
        AnalyticsService.enabled = outcome != 'consent-off';
        analyticsEvents.clear();
        await tester.tap(find.text('Suggest a change'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Optional private note');
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add a song'));
        await tester.pumpAndSettle();
        expect(find.text('Open song'), findsOneWidget);
        expect(find.text('Candidate artist'), findsOneWidget);
        expect(find.text('Secret key'), findsNothing);
        expect(find.text('Private chart'), findsNothing);
        await tester.tap(find.text('Open song'));
        await tester.ensureVisible(
          find.text(outcome == 'cancel' ? 'Cancel' : 'Send'),
        );
        await tester.tap(find.text(outcome == 'cancel' ? 'Cancel' : 'Send'));
        await tester.pumpAndSettle();
        if (outcome == 'send' || outcome == 'consent-off') {
          expect(fake.submissions.single, {
            'token': 't.s',
            'bandId': null,
            'ownerUid': null,
            'setlistId': null,
            'type': 'add',
            'text': 'Optional private note',
            'proposal': {
              'version': 1,
              'kind': 'add',
              'baseFingerprint': 'f' * 64,
              'songId': 's2',
            },
          });
        } else {
          expect(fake.submissions, isEmpty);
        }
        expect(fake.loads, outcome == 'failure' ? 2 : 1);
        expect(
          analyticsEvents,
          outcome == 'send'
              ? [
                  [
                    {
                      'eventName': 'event_suggestion_submitted',
                      'parameters': null,
                    },
                  ],
                ]
              : isEmpty,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'add picker has an empty state and cannot submit without a selection',
    (tester) async {
      final fake = await pump(
        tester,
        _view(
          access: const {EventArea.runningOrder: EventAccessLevel.view},
          canSuggest: true,
          ready: true,
        ),
      );
      await tester.tap(find.text('Suggest a change'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a song'));
      await tester.pumpAndSettle();
      expect(find.text('No songs open to suggest yet'), findsOneWidget);
      await tester.ensureVisible(find.text('Send'));
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(fake.submissions, isEmpty);
      expect(find.text('Cancel'), findsOneWidget);
    },
  );

  testWidgets('legacy order hides Add a song even with candidates', (
    tester,
  ) async {
    await pump(
      tester,
      _view(
        access: const {EventArea.runningOrder: EventAccessLevel.view},
        canSuggest: true,
        candidates: const [
          {'id': 's2', 'title': 'Open song', 'artist': 'Artist'},
        ],
      ),
    );
    await tester.tap(find.text('Suggest a change'));
    await tester.pumpAndSettle();
    expect(find.text('Add a song'), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.text('Open song'), findsNothing);
  });

  testWidgets('ready granted order can propose removing one occurrence', (
    tester,
  ) async {
    final fake = await pump(
      tester,
      _view(
        access: const {EventArea.runningOrder: EventAccessLevel.view},
        canSuggest: true,
        ready: true,
      ),
    );
    await tester.tap(find.text('Suggest a change'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove a song occurrence'));
    await tester.pumpAndSettle();
    expect(find.text('Dinner'), findsNothing);
    expect(find.text('1. visto'), findsOneWidget);
    expect(find.text('3. visto'), findsOneWidget);
    await tester.tap(find.text('1. visto'));
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(fake.submissions.single, {
      'token': 't.s',
      'bandId': null,
      'ownerUid': null,
      'setlistId': null,
      'type': 'remove',
      'text': '',
      'proposal': {
        'version': 1,
        'kind': 'remove',
        'baseFingerprint': 'f' * 64,
        'itemId': 'occ-1',
      },
    });
  });

  testWidgets('reorder submits the dragged permutation including breaks', (
    tester,
  ) async {
    final fake = await pump(
      tester,
      _view(
        access: const {EventArea.runningOrder: EventAccessLevel.view},
        canSuggest: true,
        ready: true,
      ),
      direct: true,
    );
    await tester.tap(find.text('Suggest a change'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reorder').last);
    await tester.pumpAndSettle();
    expect(find.byType(ReorderableListView), findsOneWidget);
    final rows = find.descendant(
      of: find.byType(ReorderableListView),
      matching: find.byType(ListTile),
    );
    final first = rows.at(0);
    final last = rows.at(2);
    final target = tester.getCenter(last) + const Offset(0, 35);
    final gesture = await tester.startGesture(tester.getCenter(first));
    await tester.pump(const Duration(seconds: 1));
    await gesture.moveTo(target);
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Send'));
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(fake.submissions.single, {
      'token': null,
      'bandId': null,
      'ownerUid': 'owner',
      'setlistId': 'sl1',
      'type': 'reorder',
      'text': '',
      'proposal': {
        'version': 1,
        'kind': 'reorder',
        'baseFingerprint': 'f' * 64,
        'itemIds': ['break-1', 'occ-1', 'occ-2'],
      },
    });
    expect(analyticsEvents.last, [
      {'eventName': 'event_suggestion_submitted', 'parameters': null},
    ]);
    expect(tester.takeException(), isNull);
  });

  for (final ready in [false, true]) {
    testWidgets('ungranted order ready=$ready keeps note-only route', (
      tester,
    ) async {
      await pump(
        tester,
        _view(access: const {}, canSuggest: true, ready: ready),
      );
      await tester.tap(find.text('Suggest a change'));
      await tester.pumpAndSettle();
      expect(find.text('Change type'), findsNothing);
      expect(find.textContaining('unavailable'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  }

  for (final outcome in ['send', 'cancel', 'failure']) {
    testWidgets(
      'second duplicate removal $outcome preserves exact occurrence and scope',
      (tester) async {
        final fake = await pump(
          tester,
          _view(
            access: const {EventArea.runningOrder: EventAccessLevel.view},
            canSuggest: true,
            ready: true,
          ),
        );
        fake.failSubmit = outcome == 'failure';
        analyticsEvents.clear();
        await tester.tap(find.text('Suggest a change'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remove a song occurrence'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('3. visto'));
        await tester.tap(find.text(outcome == 'cancel' ? 'Cancel' : 'Send'));
        await tester.pumpAndSettle();
        if (outcome == 'send') {
          expect(fake.submissions.single['proposal'], {
            'version': 1,
            'kind': 'remove',
            'baseFingerprint': 'f' * 64,
            'itemId': 'occ-2',
          });
          expect(fake.submissions.single['token'], 't.s');
          expect(analyticsEvents, [
            [
              {'eventName': 'event_suggestion_submitted', 'parameters': null},
            ],
          ]);
        } else {
          expect(fake.submissions, isEmpty);
          expect(analyticsEvents, isEmpty);
        }
        if (outcome == 'failure')
          expect(find.textContaining('Could not send that:'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('ready order without suggestion permission has no affordance', (
    tester,
  ) async {
    await pump(
      tester,
      _view(
        access: const {EventArea.runningOrder: EventAccessLevel.view},
        ready: true,
      ),
    );
    expect(find.text('Suggest a change'), findsNothing);
  });

  testWidgets(
    'long order remains selectable and sendable on a small viewport',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fake = await pump(
        tester,
        EventView(
          setlistId: 'sl1',
          name: 'Gig',
          access: const {EventArea.runningOrder: EventAccessLevel.view},
          canSuggest: true,
          runningOrderReady: true,
          baseFingerprint: 'f' * 64,
          songs: const [
            {'id': 's1', 'title': 'Song'},
          ],
          runningOrderItems: [
            for (var i = 1; i <= 20; i++)
              {'id': 'occ-$i', 'type': 'song', 'songId': 's1'},
          ],
        ),
      );
      await tester.tap(find.text('Suggest a change'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove a song occurrence'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('20. Song'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20. Song'));
      await tester.ensureVisible(find.text('Send'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect((fake.submissions.single['proposal'] as Map)['itemId'], 'occ-20');
      expect(tester.takeException(), isNull);
    },
  );

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
