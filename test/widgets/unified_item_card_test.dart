import 'package:flowgroove/models/section.dart';
import 'package:flowgroove/screens/songs/components/song_constructor/widgets/pill_view.dart';
import 'package:flowgroove/widgets/unified_item/adapters/song_item_adapter.dart';
import 'package:flowgroove/widgets/unified_item/unified_item_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mocks.dart';

void main() {
  group('UnifiedItemCard song structure pills', () {
    testWidgets('shows a PillView when the song has sections', (tester) async {
      final song = MockDataHelper.createMockSong().copyWith(
        sections: [
          Section(id: '1', name: 'Intro'),
          Section(id: '2', name: 'Verse', duration: 2),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: UnifiedItemCard(item: SongItemAdapter(song))),
        ),
      );

      expect(find.byType(PillView), findsOneWidget);
    });

    testWidgets('shows no PillView when the song has no sections', (
      tester,
    ) async {
      final song = MockDataHelper.createMockSong();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: UnifiedItemCard(item: SongItemAdapter(song))),
        ),
      );

      expect(find.byType(PillView), findsNothing);
    });

    testWidgets('hides pills in compact mode', (tester) async {
      final song = MockDataHelper.createMockSong().copyWith(
        sections: [Section(id: '1', name: 'Intro')],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnifiedItemCard(item: SongItemAdapter(song), showCompact: true),
          ),
        ),
      );

      expect(find.byType(PillView), findsNothing);
    });
  });
}
