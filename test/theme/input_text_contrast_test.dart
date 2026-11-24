import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flowgroove/widgets/app_dropdown_field.dart';
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

    testWidgets('AppBar title contrasts with the bar ($name)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(appBar: AppBar(title: const Text('Create Account'))),
        ),
      );
      final color = DefaultTextStyle.of(
        tester.element(find.text('Create Account')),
      ).style.color!;
      final bar = theme.appBarTheme.backgroundColor!;
      expect(
        _contrast(color, bar),
        greaterThanOrEqualTo(4.5),
        reason: '$name title $color on $bar',
      );
    });

    testWidgets('AppDropdownField value and open menu are readable ($name)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: AppDropdownField<String>(
              initialValue: 'one',
              items: const [
                DropdownMenuItem(value: 'one', child: Text('Alpha')),
                DropdownMenuItem(value: 'two', child: Text('Bravo')),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      );
      final fill = theme.inputDecorationTheme.fillColor!;
      final closed = DefaultTextStyle.of(tester.element(find.text('Alpha')))
          .style
          .color!;
      expect(
        _contrast(closed, fill),
        greaterThanOrEqualTo(4.5),
        reason: '$name closed value $closed on $fill',
      );
      final icon = tester.widget<Icon>(find.byIcon(Icons.arrow_drop_down));
      final iconColor = IconTheme.of(
        tester.element(find.byIcon(Icons.arrow_drop_down)),
      ).color!;
      expect(icon, isNotNull);
      expect(_contrast(iconColor, fill), greaterThanOrEqualTo(3));

      await tester.tap(find.byType(AppDropdownField<String>));
      await tester.pumpAndSettle();
      final item = find.text('Bravo').last;
      final text = DefaultTextStyle.of(tester.element(item)).style.color!;
      // The menu background is painted by the route's own painter.
      final menu =
          (tester
                          .widgetList<CustomPaint>(
                            find.ancestor(
                              of: item,
                              matching: find.byType(CustomPaint),
                            ),
                          )
                          .firstWhere(
                            (c) =>
                                c.painter.runtimeType.toString() ==
                                '_DropdownMenuPainter',
                          )
                          .painter
                      as dynamic)
                  .color
              as Color;
      expect(
        _contrast(text, menu),
        greaterThanOrEqualTo(4.5),
        reason: '$name menu item $text on $menu',
      );
    });
  }
}
