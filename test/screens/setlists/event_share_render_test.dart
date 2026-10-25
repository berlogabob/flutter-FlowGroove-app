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
  }

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
