import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/widgets/unified_item/adapters/song_item_adapter.dart';
import 'package:flowgroove/widgets/unified_item/unified_item_card.dart';
import 'package:flowgroove/widgets/unified_item/unified_item_list.dart';
import 'package:flowgroove/widgets/unified_item/unified_item_model.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final item = SongItemAdapter(
    Song(
      id: 'song',
      title: 'Song title',
      artist: 'Artist',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    ),
  );

  testWidgets('card tap and semantics expose the song', (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    var actionTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnifiedItemCard(
            item: item,
            onTap: () => taps++,
            customActions: [
              IconAction(
                icon: Icons.timer,
                tooltip: 'Metronome',
                semanticLabel: 'Metronome for Song title',
                onPressed: () => actionTaps++,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Song title'));
    expect(taps, 1);
    final node = tester.getSemantics(find.text('Song title'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(node.getSemanticsData().hasFlag(SemanticsFlag.isButton), isTrue);
    expect(node.label, contains('Song title'));
    expect(node.label, contains('Artist'));
    expect(find.bySemanticsLabel('Metronome for Song title'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.timer));
    expect(actionTaps, 1);
    expect(taps, 1);
    semantics.dispose();
  });

  testWidgets('list falls back to edit when no tap callback is supplied', (
    tester,
  ) async {
    var edits = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnifiedItemList(items: [item], onEdit: (_) => edits++),
        ),
      ),
    );

    await tester.tap(find.text('Song title'));
    expect(edits, 1);
  });
}
