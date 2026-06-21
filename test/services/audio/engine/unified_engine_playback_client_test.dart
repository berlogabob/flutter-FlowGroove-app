import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flowgroove/providers/metronome_runtime_providers.dart'
    show MetronomePlaybackClient;
import 'package:flowgroove/services/audio/engine/unified_engine_playback_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('satisfies the MetronomePlaybackClient contract', () {
    final client = UnifiedEnginePlaybackClient();
    expect(client, isA<MetronomePlaybackClient>());
    // Dispose immediately; must not throw. (No real audio is started, so the
    // SoLoud sink is never opened here.)
    expect(client.dispose, returnsNormally);
  });

  test('construct + dispose without starting does not throw', () {
    expect(() => UnifiedEnginePlaybackClient()..dispose(), returnsNormally);
  });
}
