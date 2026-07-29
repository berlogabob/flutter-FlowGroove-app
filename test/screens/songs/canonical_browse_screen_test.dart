import 'package:flowgroove/models/canonical_song.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/repositories/canonical_song_repository.dart';
import 'package:flowgroove/screens/songs/canonical_browse_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCanonicalRepo implements CanonicalSongRepository {
  _FakeCanonicalRepo(this.songs);
  final List<CanonicalSong> songs;
  String? lastQuery;

  @override
  Future<List<CanonicalSong>> search({
    required String query,
    int limit = 20,
  }) async {
    lastQuery = query;
    return songs;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  final canonical = CanonicalSong(
    id: 'c1',
    title: 'Hey Joe',
    artist: 'Jimi Hendrix',
    baseKey: 'Em',
    baseBpm: 82,
  );

  Future<_FakeCanonicalRepo> pump(WidgetTester tester) async {
    final repo = _FakeCanonicalRepo([canonical]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          canonicalSongRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: CanonicalBrowseScreen()),
      ),
    );
    await tester.pump();
    return repo;
  }

  group('CanonicalBrowseScreen (#59)', () {
    testWidgets('shows browse empty state before searching', (tester) async {
      await pump(tester);
      expect(find.text('Browse the shared catalog'), findsOneWidget);
    });

    testWidgets('search renders catalog rows with Add action', (tester) async {
      final repo = await pump(tester);

      await tester.enterText(find.byType(TextField), 'hey joe');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(repo.lastQuery, 'hey joe');
      expect(find.text('Hey Joe'), findsOneWidget);
      expect(find.textContaining('Jimi Hendrix'), findsOneWidget);
      expect(find.textContaining('82 BPM'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
    });
  });
}
