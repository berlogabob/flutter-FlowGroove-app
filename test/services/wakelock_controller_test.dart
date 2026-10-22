import 'package:flowgroove/screens/settings/app_settings_screen.dart';
import 'package:flowgroove/services/wakelock_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const toggleChannel =
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle';
  var platformCalls = 0;

  setUp(() {
    platformCalls = 0;
    binding.defaultBinaryMessenger.setMockMessageHandler(toggleChannel, (
      _,
    ) async {
      platformCalls++;
      return const StandardMessageCodec().encodeMessage([null]);
    });
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMessageHandler(toggleChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('screen show and hide acquire and release without playback', () async {
    final controller = WakelockController();
    final screen = Object();
    await controller.setScreenVisible(screen, visible: true);
    expect(controller.isEnabled, isTrue);
    await controller.setScreenVisible(screen, visible: false);
    expect(controller.isEnabled, isFalse);
    expect(platformCalls, 2);
  });

  test(
    'stopping playback or clearing global setting preserves screen lock',
    () async {
      final controller = WakelockController();
      final screen = Object();
      await controller.setScreenVisible(screen, visible: true);
      await controller.disable();
      await controller.setAlwaysOn(value: false);
      expect(controller.isEnabled, isTrue);
      await controller.setScreenVisible(screen, visible: false);
      expect(controller.isEnabled, isFalse);
    },
  );

  test(
    'overlapping screens keep independent locks and resume reacquires',
    () async {
      final controller = WakelockController();
      final first = Object();
      final second = Object();
      await controller.setScreenVisible(first, visible: true);
      await controller.setScreenVisible(second, visible: true);
      await controller.setScreenVisible(first, visible: false);
      expect(controller.isEnabled, isTrue);
      final calls = platformCalls;
      await controller.setScreenVisible(second, visible: true);
      expect(platformCalls, calls + 1);
      await controller.setScreenVisible(second, visible: false);
      expect(controller.isEnabled, isFalse);
    },
  );

  testWidgets('route coverage and lifecycle release idle screen lock', (
    tester,
  ) async {
    final controller = WakelockController();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: ScreenWakelock(
          controller: controller,
          isPlaying: false,
          onWebResume: () => fail('Idle screen must not resync playback'),
          child: const Scaffold(body: Text('Practice')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.isEnabled, isTrue);
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Settings')),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.isEnabled, isFalse);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(controller.isEnabled, isTrue);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(controller.isEnabled, isFalse);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(controller.isEnabled, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(controller.isEnabled, isFalse);
  });

  testWidgets(
    'only the manual setup tile is shown off Android, including web',
    (tester) async {
      debugDefaultTargetPlatformOverride = kIsWeb
          ? TargetPlatform.android
          : TargetPlatform.iOS;
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AppSettingsScreen())),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Audio latency offset'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Keep timing reliable'), findsOneWidget);
      expect(find.textContaining('Checking —'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('Android tile checks state and requests only when tapped', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('com.flowgroove/battery');
    final calls = <String>[];
    var exempt = false;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call.method);
      if (call.method == 'requestIgnoreBatteryOptimizations') {
        exempt = true;
        return null;
      }
      return exempt;
    });
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AppSettingsScreen())),
    );
    await tester.pumpAndSettle();
    expect(calls, ['isIgnoringBatteryOptimizations']);
    await tester.scrollUntilVisible(
      find.textContaining('Battery optimized'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.textContaining('Battery optimized'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Battery optimized'), findsOneWidget);
    await tester.tap(find.textContaining('Battery optimized'));
    await tester.pumpAndSettle();
    expect(calls, contains('requestIgnoreBatteryOptimizations'));
    expect(find.textContaining('Exempt'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  }, skip: kIsWeb);

  testWidgets('web hidden playback warns and resyncs only on return', (
    tester,
  ) async {
    final controller = WakelockController();
    var resyncs = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ScreenWakelock(
          controller: controller,
          isPlaying: true,
          onWebResume: () => resyncs++,
          child: const Scaffold(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(resyncs, 0);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(resyncs, 1);
    expect(find.text('Keep this tab visible for exact timing'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  }, skip: !kIsWeb);

  test('setAlwaysOn(true) latches the global lock', () async {
    final controller = WakelockController();
    await controller.setAlwaysOn(value: true);
    expect(controller.alwaysOn, isTrue);
  });

  test('disable() is a no-op while alwaysOn is set', () async {
    final controller = WakelockController();
    await controller.setAlwaysOn(value: true);

    // Simulates a practice screen releasing its lock on exit — must not drop
    // the global lock.
    final result = await controller.disable();
    expect(result, isTrue);
    expect(controller.alwaysOn, isTrue);
  });

  test('setAlwaysOn(false) clears the global lock', () async {
    final controller = WakelockController();
    await controller.setAlwaysOn(value: true);
    await controller.setAlwaysOn(value: false);
    expect(controller.alwaysOn, isFalse);
  });
}
