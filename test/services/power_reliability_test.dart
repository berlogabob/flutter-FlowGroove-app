import 'package:flowgroove/services/power_reliability.dart';
import 'package:flowgroove/widgets/metronome/reliability_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/power_reliability');
  late PowerReliability power;
  late List<String> calls;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    power = PowerReliability(channel: channel);
    calls = [];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call.method);
      return switch (call.method) {
        'oemFamily' => 'huawei',
        'isIgnoringBatteryOptimizations' || 'openOemSettings' => true,
        _ => null,
      };
    });
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('uses the existing host methods', () async {
    expect(await power.family(), 'huawei');
    expect(await power.ignoringOptimizations(), isTrue);
    await power.requestIgnoreOptimizations();
    expect(await power.openVendorSettings(), isTrue);
    expect(calls, [
      'oemFamily',
      'isIgnoringBatteryOptimizations',
      'requestIgnoreBatteryOptimizations',
      'openOemSettings',
    ]);
  }, skip: kIsWeb);

  test('missing plugin returns safe defaults', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => throw MissingPluginException(),
    );
    expect(await power.family(), 'other');
    expect(await power.ignoringOptimizations(), isFalse);
    await power.requestIgnoreOptimizations();
    expect(await power.openVendorSettings(), isFalse);
  });

  test('off Android does not call the host', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(await power.family(), 'other');
    expect(await power.ignoringOptimizations(), isFalse);
    await power.requestIgnoreOptimizations();
    expect(await power.openVendorSettings(), isFalse);
    expect(calls, isEmpty);
  });

  test('manual steps cover each family and unknown phones', () {
    expect(PowerReliability.steps('huawei'), contains('Run in background'));
    expect(PowerReliability.steps('xiaomi'), contains('No restrictions'));
    expect(PowerReliability.steps('oppo'), contains('auto-launch'));
    expect(PowerReliability.steps('vivo'), contains('Background power'));
    expect(PowerReliability.steps('samsung'), contains('Never sleeping apps'));
    expect(
      PowerReliability.steps('unknown'),
      'Allow unrestricted battery use for FlowGroove',
    );
  });

  test('setup seen persists across service instances', () async {
    expect(await power.setupSeen(), isFalse);
    await power.markSetupSeen();
    expect(await PowerReliability().setupSeen(), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('power_setup_seen'), isTrue);
  });

  testWidgets('sheet actions run only when tapped and Done records setup', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showReliabilitySheet(context, power: power),
              child: const Text('Setup'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Setup'));
    await tester.pumpAndSettle();
    expect(find.text('Keep timing reliable'), findsOneWidget);
    expect(find.textContaining('Run in background'), findsOneWidget);
    expect(calls, ['oemFamily']);
    await tester.tap(find.text('Allow unrestricted battery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open phone battery settings'));
    await tester.pumpAndSettle();
    expect(calls, [
      'oemFamily',
      'requestIgnoreBatteryOptimizations',
      'openOemSettings',
    ]);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Keep timing reliable'), findsNothing);
    expect(await power.setupSeen(), isTrue);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  }, skip: kIsWeb);
}
