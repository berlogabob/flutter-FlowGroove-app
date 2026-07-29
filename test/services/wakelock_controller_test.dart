import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/services/wakelock_controller.dart';

// Platform (WakelockPlus) calls throw MissingPluginException in the test env and
// are swallowed by the controller, so these tests only exercise the pure
// alwaysOn / disable-guard branch logic — no device needed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
