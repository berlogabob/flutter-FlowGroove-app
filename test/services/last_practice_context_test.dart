import 'package:flowgroove/services/last_practice_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('last practice survives a store round trip', () async {
    SharedPreferences.setMockInitialValues({});
    final context = LastPracticeContext(
      songId: 's1',
      bandId: 'b1',
      title: 'Blue',
      bpm: 120,
      updatedAt: DateTime.utc(2026),
    );
    await LastPracticeContextStore().save(context);
    final saved = await LastPracticeContextStore().load();
    expect(saved?.songId, 's1');
    expect(saved?.bandId, 'b1');
    expect(saved?.title, 'Blue');
    expect(saved?.bpm, 120);
    expect(saved?.updatedAt, DateTime.utc(2026));
  });
  for (final raw in [
    'broken',
    '{}',
    '{"songId":"s1"}',
    '{"songId":"","title":"Blue"}',
  ]) {
    test('invalid context is absent: $raw', () async {
      SharedPreferences.setMockInitialValues({'practice.last_context': raw});
      expect(await LastPracticeContextStore().load(), isNull);
    });
  }
}
