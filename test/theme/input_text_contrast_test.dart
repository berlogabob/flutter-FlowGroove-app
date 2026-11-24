import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  setUpAll(() => TestWidgetsFlutterBinding.ensureInitialized());

  for (final (name, theme) in [
    ('dark', MonoPulseTheme.theme),
    ('light', MonoPulseTheme.lightTheme),
  ]) {
    testWidgets('typed text in a plain TextField/TextFormField contrasts with '
        'the white fill ($name)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Column(
              children: [
                TextField(
                  key: const Key('plain'),
                  controller: TextEditingController(text: 'Test Band'),
                ),
                TextFormField(
                  key: const Key('form'),
                  initialValue: 'Gig Setlist',
                ),
              ],
            ),
          ),
        ),
      );
      final fill = theme.inputDecorationTheme.fillColor!;
      for (final key in const [Key('plain'), Key('form')]) {
        final editable = tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(key),
            matching: find.byType(EditableText),
          ),
        );
        final color = editable.style.color!;
        expect(
          _contrast(color, fill),
          greaterThanOrEqualTo(4.5),
          reason: '$name $key text $color on $fill',
        );
      }
    });
  }
}
