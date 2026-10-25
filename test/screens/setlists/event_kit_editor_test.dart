import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// Firebase Core's installed test mocks; no production dependency is needed.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flowgroove/models/event_kit.dart';
import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/models/user.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';

import 'package:flowgroove/screens/setlists/event_kit_editor_screen.dart';
import 'package:flowgroove/services/analytics_service.dart';
import 'package:flowgroove/services/event_share_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../helpers/mocks.mocks.dart';
import '../../helpers/routed_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

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
    AppUser? appUser,
    bool bandWriter = false,
    bool authenticated = true,
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
          currentUserProvider.overrideWithValue(
            AsyncValue<User?>.data(authenticated ? user : null),
          ),
          appUserProvider.overrideWith(
            () => TestAppUserNotifier(
              appUser ?? AppUser(uid: 'u1', createdAt: DateTime(2026)),
            ),
          ),
          bandsProvider.overrideWith(
            (ref) => Stream.value([
              Band(
                id: 'band-1',
                name: 'Band',
                createdBy: 'other',
                createdAt: DateTime(2026),
                memberUids: const ['u1'],
                adminUids: const [],
                editorUids: bandWriter ? const ['u1'] : const [],
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          home: EventKitEditorScreen(
            setlist: withSetlist ?? setlist,
            // A band id makes this a shared event, which is what makes the
            // access map meaningful — a personal setlist has no grants.
            bandId: personal
                ? null
                : (access != null || bandWriter ? 'band-1' : null),
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

  for (final scenario in [
    'member',
    'guest',
    'demo',
    'non-owner',
    'signed-out',
  ]) {
    testWidgets('share inventory hidden for $scenario without a service call', (
      tester,
    ) async {
      var calls = 0;
      await pump(
        tester,
        access: const {'crew': 'edit'},
        personal: scenario != 'member' && scenario != 'guest',
        ownerUid: scenario == 'non-owner' ? 'other' : 'u1',
        isMember: scenario != 'guest',
        authenticated: scenario != 'signed-out',
        appUser: AppUser(
          uid: 'u1',
          createdAt: DateTime(2026),
          accessRole: scenario == 'demo' ? 'demo' : 'member',
        ),
        shareService: EventShareService(
          invoker: (name, args) async {
            calls++;
            return {};
          },
        ),
      );
      expect(find.text('Share links inventory'), findsNothing);
      expect(calls, 0);
    });
  }

  testWidgets(
    'share inventory initial loading and failed load retry never imply empty data',
    (tester) async {
      final first = Completer<Map<String, dynamic>>();
      var calls = 0;
      await pump(
        tester,
        personal: true,
        ownerUid: 'u1',
        shareService: EventShareService(
          invoker: (name, args) async {
            expect(name, 'listEventShares');
            calls++;
            if (calls == 1) return first.future;
            return {
              'shares': <Object?>[],
              'hasMore': false,
              'nextCursor': null,
            };
          },
        ),
      );
      await tester.ensureVisible(find.text('Share links inventory'));
      await tester.tap(find.text('Share links inventory'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('No share links yet.'), findsNothing);
      first.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.textContaining('offline'), findsOneWidget);
      expect(find.text('No share links yet.'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('No share links yet.'), findsOneWidget);
      expect(calls, 2);
    },
  );

  testWidgets('share inventory owner loads metadata without minting a link', (
    tester,
  ) async {
    final calls = <Map<String, dynamic>>[];
    await pump(
      tester,
      personal: true,
      ownerUid: 'u1',
      shareService: EventShareService(
        invoker: (name, args) async {
          expect(name, 'listEventShares');
          calls.add(args);
          return {'shares': <Object?>[], 'hasMore': false, 'nextCursor': null};
        },
      ),
    );
    expect(find.text('Share links inventory'), findsOneWidget);
    await tester.ensureVisible(find.text('Share links inventory'));
    await tester.tap(find.text('Share links inventory'));
    await tester.pumpAndSettle();
    expect(find.text('No share links yet.'), findsOneWidget);
    expect(calls, [
      {'ownerUid': 'u1', 'setlistId': 'sl1'},
    ]);
  });

  Map<String, dynamic> shareRow(
    String id,
    String name, {
    String state = 'active',
  }) => {
    'tokenId': id,
    'participantId': 'p-$id',
    'name': name,
    'role': 'Photographer',
    'access': {'eventInfo': 'view'},
    'createdAt': '2026-10-25T12:00:00.000Z',
    'expiresAt': null,
    'state': state,
  };

  testWidgets(
    'share inventory pages preserve rows on failure and retry exact cursor',
    (tester) async {
      final calls = <Map<String, dynamic>>[];
      var failed = false;
      await pump(
        tester,
        bandWriter: true,
        shareService: EventShareService(
          invoker: (name, args) async {
            expect(name, 'listEventShares');
            calls.add(args);
            if (args['cursor'] == 'a' && !failed) {
              failed = true;
              throw StateError('offline');
            }
            return {
              'shares': [
                args['cursor'] == null
                    ? shareRow('a', 'Ana')
                    : shareRow('b', 'Bob', state: 'expired'),
              ],
              'hasMore': args['cursor'] == null,
              'nextCursor': args['cursor'] == null ? 'a' : null,
            };
          },
        ),
      );
      await tester.ensureVisible(find.text('Share links inventory'));
      await tester.tap(find.text('Share links inventory'));
      await tester.pumpAndSettle();
      expect(find.text('Ana'), findsOneWidget);
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(find.text('Ana'), findsOneWidget);
      expect(find.textContaining('offline'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
      expect(find.textContaining('expired'), findsOneWidget);
      expect(find.textContaining('2026-10-25'), findsNWidgets(2));
      expect(calls, [
        {'bandId': 'band-1', 'setlistId': 'sl1'},
        {'bandId': 'band-1', 'setlistId': 'sl1', 'cursor': 'a'},
        {'bandId': 'band-1', 'setlistId': 'sl1', 'cursor': 'a'},
      ]);
    },
  );

  testWidgets(
    'share inventory revoke cancel failure and success isolate selected link',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final revoked = <String>[];
      await pump(
        tester,
        personal: true,
        ownerUid: 'u1',
        shareService: EventShareService(
          invoker: (name, args) async {
            if (name == 'listEventShares')
              return {
                'shares': [shareRow('a', 'Ana'), shareRow('b', 'Bob')],
                'hasMore': false,
                'nextCursor': null,
              };
            expect(name, 'revokeEventShare');
            expect(args, {'tokenId': 'a'});
            revoked.add(args['tokenId'] as String);
            if (revoked.length == 1) throw StateError('offline');
            return {};
          },
        ),
      );
      await tester.ensureVisible(find.text('Share links inventory'));
      await tester.tap(find.text('Share links inventory'));
      await tester.pumpAndSettle();
      Future<void> confirm(String action) async {
        await tester.tap(find.byTooltip('Revoke Ana'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
      }

      await confirm('Cancel');
      expect(revoked, isEmpty);
      await confirm('Revoke');
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.textContaining('Could not revoke'), findsOneWidget);
      await confirm('Revoke');
      expect(revoked, ['a', 'a']);
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.textContaining('revoked'), findsOneWidget);
      expect(find.byTooltip('Revoke Ana'), findsNothing);
      expect(find.byTooltip('Revoke Bob'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'personal owner shares with free-form people without band members',
    (tester) async {
      const analyticsChannel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.firebase_analytics_platform_interface.FirebaseAnalyticsHostApi.logEvent',
        StandardMessageCodec(),
      );
      final analyticsEvents = <Object?>[];
      AnalyticsService.enabled = true;
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(analyticsChannel, (
            message,
          ) async {
            analyticsEvents.add(message);
            return <Object?>[null];
          });
      addTearDown(() {
        AnalyticsService.enabled = true;
        tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(analyticsChannel, null);
      });
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
      await tester.scrollUntilVisible(find.text('Add rider item'), 150);
      expect(find.text('Add rider item'), findsOneWidget);
      await tester.ensureVisible(find.text('Add person'));
      await tester.tap(find.text('Add person'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Ana');
      await tester.enterText(
        find.widgetWithText(TextField, 'Role (Photographer, Manager, +1…)'),
        'Photographer',
      );
      await tester.ensureVisible(find.text('Add'));
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
      expect(analyticsEvents, [
        [
          {'eventName': 'event_share_created', 'parameters': null},
        ],
      ]);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Ana'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Ana Maria',
      );
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final edited =
          (writesTo(firestore, 'people').single! as List).single as Map;
      expect(edited['name'], 'Ana Maria');
      expect(edited['id'], added['id']);
      expect(edited['access'], added['access']);
    },
  );

  for (final scenario in [
    'service failure',
    'clipboard failure',
    'consent off',
    'analytics failure',
    'no access',
    'guest',
  ]) {
    testWidgets('share analytics respects $scenario', (tester) async {
      const channel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.firebase_analytics_platform_interface.FirebaseAnalyticsHostApi.logEvent',
        StandardMessageCodec(),
      );
      final events = <Object?>[];
      var creates = 0;
      String? copied;
      AnalyticsService.enabled = scenario != 'consent off';
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(channel, (message) async {
            events.add(message);
            if (scenario == 'analytics failure') {
              return <Object?>['unavailable', 'SDK unavailable', null];
            }
            return <Object?>[null];
          });
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            if (scenario == 'clipboard failure') {
              throw PlatformException(code: 'clipboard-unavailable');
            }
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(() {
        AnalyticsService.enabled = true;
        tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(channel, null);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      await pump(
        tester,
        personal: true,
        ownerUid: scenario == 'guest' ? 'another-owner' : 'u1',
        isMember: false,
        access: const {'rider': 'view'},
        withSetlist: setlist.copyWith(
          eventKit: EventKit(
            people: [
              EventPerson(
                id: 'p1',
                name: 'Ana',
                role: 'client',
                access: scenario == 'no access'
                    ? const {}
                    : const {'eventInfo': 'view'},
              ),
            ],
          ),
        ),
        shareService: EventShareService(
          invoker: (name, args) async {
            creates++;
            if (scenario == 'service failure') {
              throw PlatformException(code: 'permission-denied');
            }
            return {'token': 'private.secret'};
          },
        ),
      );
      final share = find.byTooltip('Share this event with Ana');
      if (scenario == 'guest') {
        expect(share, findsNothing);
      } else {
        await tester.ensureVisible(share);
        await tester.tap(share);
        await tester.pumpAndSettle();
      }
      expect(creates, scenario == 'guest' || scenario == 'no access' ? 0 : 1);
      if (scenario == 'analytics failure' || scenario == 'consent off') {
        expect(copied, 'https://app.flowgroove.app/#/event?t=private.secret');
        expect(find.textContaining('Link for Ana copied'), findsOneWidget);
      } else {
        expect(copied, isNull);
      }
      expect(
        events,
        scenario == 'analytics failure'
            ? [
                [
                  {'eventName': 'event_share_created', 'parameters': null},
                ],
              ]
            : isEmpty,
      );
      if (scenario == 'service failure' || scenario == 'clipboard failure') {
        expect(
          find.textContaining('Could not create the link:'),
          findsOneWidget,
        );
      }
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  }

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
    testWidgets('person access is editable and saved per area', (tester) async {
      final firestore = await pump(tester);
      await tester.tap(find.text('Add person'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Ana');
      await tester.enterText(
        find.widgetWithText(TextField, 'Role (Photographer, Manager, +1…)'),
        'client',
      );
      expect(
        find.text('+ Event info (date, venue, call time)'),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('access-eventInfo')),
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('access-eventInfo')),
          matching: find.text('Edit'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('+ Event info (date, venue, call time)  — can edit'),
        findsOneWidget,
      );
      expect(
        find.text('Role changes reset custom access to the role defaults.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Add'));
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      final person =
          (writesTo(firestore, 'people').single! as List).single as Map;
      expect(person['access'], {'eventInfo': 'edit', 'runningOrder': 'view'});
      expect(person['canSuggest'], isTrue);
    });

    testWidgets(
      'saved overrides drive preview, preserve identity and cancel safely',
      (tester) async {
        final firestore = await pump(
          tester,
          withSetlist: setlist.copyWith(
            eventKit: const EventKit(
              people: [
                EventPerson(
                  id: 'p1',
                  uid: 'guest1',
                  name: 'Ana',
                  role: 'client',
                  notes: 'Keep this',
                  access: {'stage': 'edit'},
                  canSuggest: false,
                ),
              ],
            ),
          ),
        );
        await tester.tap(find.widgetWithText(ListTile, 'Ana'));
        await tester.pumpAndSettle();
        expect(find.text('+ Stage plot  — can edit'), findsOneWidget);
        expect(
          find.text('Can suggest changes (the band decides).'),
          findsNothing,
        );
        for (final area in [
          'eventInfo',
          'runningOrder',
          'songDetail',
          'stage',
          'rider',
        ]) {
          final control = find.byKey(ValueKey('access-$area'));
          await tester.ensureVisible(control);
          await tester.tap(
            find.descendant(of: control, matching: find.text('View')),
          );
          await tester.pumpAndSettle();
        }
        final stage = find.byKey(const ValueKey('access-stage'));
        await tester.ensureVisible(stage);
        await tester.tap(
          find.descendant(of: stage, matching: find.text('Hidden')),
        );
        await tester.pumpAndSettle();
        expect(find.text('− Stage plot'), findsOneWidget);
        await tester.ensureVisible(find.text('Save'));
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        final saved =
            (writesTo(firestore, 'people').single! as List).single as Map;
        expect(saved, containsPair('id', 'p1'));
        expect(saved, containsPair('uid', 'guest1'));
        expect(saved, containsPair('notes', 'Keep this'));
        expect(saved.containsKey('canSuggest'), isFalse);
        expect(saved['access'], {
          'eventInfo': 'view',
          'runningOrder': 'view',
          'songDetail': 'view',
          'rider': 'view',
        });
        await tester.tap(find.widgetWithText(ListTile, 'Ana'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Name'),
          'Discard me',
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        verifyNever(
          firestore.updateEventKitArea(
            setlistId: anyNamed('setlistId'),
            area: 'people',
            value: anyNamed('value'),
            bandId: anyNamed('bandId'),
            uid: anyNamed('uid'),
          ),
        );
        expect(find.widgetWithText(ListTile, 'Ana'), findsOneWidget);
      },
    );

    testWidgets(
      'typed and chip role changes reset overrides without changing next person defaults',
      (tester) async {
        final firestore = await pump(tester);
        await tester.tap(find.text('Add person'));
        await tester.pumpAndSettle();
        await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Ana');
        final role = find.widgetWithText(
          TextField,
          'Role (Photographer, Manager, +1…)',
        );
        await tester.enterText(role, 'client');
        await tester.pumpAndSettle();
        expect(
          find.text('Can suggest changes (the band decides).'),
          findsOneWidget,
        );
        final eventInfo = find.byKey(const ValueKey('access-eventInfo'));
        await tester.ensureVisible(eventInfo);
        await tester.tap(
          find.descendant(of: eventInfo, matching: find.text('Hidden')),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(role);
        await tester.enterText(role, 'Photographer');
        await tester.pumpAndSettle();
        expect(
          find.text('+ Event info (date, venue, call time)'),
          findsOneWidget,
        );
        expect(find.text('+ Equipment / rider  — can edit'), findsOneWidget);
        expect(
          find.text('Can suggest changes (the band decides).'),
          findsNothing,
        );
        final manager = find.byWidgetPredicate(
          (w) =>
              w is ActionChip &&
              w.label is Text &&
              ((w.label as Text).data?.contains('Manager') ?? false),
        );
        await tester.ensureVisible(manager);
        await tester.tap(manager);
        await tester.pumpAndSettle();
        expect(find.text('+ Lyrics, chords, key & BPM'), findsOneWidget);
        expect(
          find.text('Can suggest changes (the band decides).'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Add'));
        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();
        final saved =
            (writesTo(firestore, 'people').single! as List).single as Map;
        expect(saved['access'], {
          'eventInfo': 'view',
          'runningOrder': 'view',
          'songDetail': 'view',
          'stage': 'view',
          'rider': 'view',
        });
        expect(saved['canSuggest'], isTrue);
        await tester.tap(find.text('Add person'));
        await tester.pumpAndSettle();
        expect(
          find.text('+ Event info (date, venue, call time)'),
          findsOneWidget,
        );
        expect(find.text('− Stage plot'), findsOneWidget);
        expect(
          find.text('Can suggest changes (the band decides).'),
          findsNothing,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        verifyNever(
          firestore.updateEventKitArea(
            setlistId: anyNamed('setlistId'),
            area: 'people',
            value: anyNamed('value'),
            bandId: anyNamed('bandId'),
            uid: anyNamed('uid'),
          ),
        );
      },
    );

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
      await tester.ensureVisible(find.text('Add'));
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
