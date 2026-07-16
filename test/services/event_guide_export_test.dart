import 'package:flowgroove/services/export/pdf_service.dart';
import 'package:flowgroove/services/export/setlist_export_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final results = <Future<SetlistPdfLayout?>>[];

  Future<void> pumpAndOpen(
    WidgetTester tester, {
    required bool withEventGuide,
  }) async {
    results.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              results.add(
                pickSetlistPdfLayout(
                  context,
                  withEventGuide: withEventGuide,
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('Event guide export option (#55)', () {
    testWidgets('picker offers Event guide when the kit exists', (
      tester,
    ) async {
      await pumpAndOpen(tester, withEventGuide: true);

      expect(find.text('Event guide'), findsOneWidget);
      await tester.tap(find.text('Event guide'));
      await tester.pumpAndSettle();
      expect(await results.single, SetlistPdfLayout.eventGuide);
    });

    testWidgets('picker hides Event guide without a kit', (tester) async {
      await pumpAndOpen(tester, withEventGuide: false);

      expect(find.text('Event guide'), findsNothing);
      expect(find.text('SetlistPack'), findsOneWidget);
    });
  });
}
