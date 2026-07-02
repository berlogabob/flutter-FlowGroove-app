import 'package:flowgroove/screens/songs/components/collapsible_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('collapsed inline preview sits on the same line as the title',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const CollapsibleSection(
          title: 'Key & BPM',
          initiallyExpanded: false,
          preview: Text('C · 123 BPM'),
          child: SizedBox(height: 100),
        ),
      ),
    );

    final titleY = tester.getCenter(find.text('Key & BPM')).dy;
    final previewY = tester.getCenter(find.text('C · 123 BPM')).dy;
    expect(previewY, titleY);
  });

  testWidgets('wide preview (inlinePreview: false) renders under the header',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const CollapsibleSection(
          title: 'Song Structure',
          initiallyExpanded: false,
          inlinePreview: false,
          preview: Text('MAP'),
          child: SizedBox(height: 100),
        ),
      ),
    );

    final titleY = tester.getCenter(find.text('Song Structure')).dy;
    final previewY = tester.getCenter(find.text('MAP')).dy;
    expect(previewY, greaterThan(titleY));
  });

  testWidgets('expanded section hides the preview', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const CollapsibleSection(
          title: 'Notes',
          preview: Text('my note'),
          child: SizedBox(height: 100),
        ),
      ),
    );

    expect(find.text('my note'), findsNothing);
  });
}
