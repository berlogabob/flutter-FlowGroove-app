import 'package:flowgroove/widgets/tuner/custom_tuning_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('saving without a name shows the error inside the sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: CustomTuningEditor())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Custom Tuning'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a name for this tuning'), findsOneWidget);
    // Typing clears it again.
    await tester.enterText(find.byType(TextField), 'My Open G');
    await tester.pump();
    expect(find.text('Please enter a name for this tuning'), findsNothing);
  });
}
