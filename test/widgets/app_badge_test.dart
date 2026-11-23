import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flowgroove/widgets/app_badge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

BoxDecoration _decoration(WidgetTester tester) =>
    tester
            .widget<Container>(
              find.descendant(
                of: find.byType(AppBadge),
                matching: find.byType(Container),
              ),
            )
            .decoration!
        as BoxDecoration;

void main() {
  testWidgets('tint badge keeps the 10% fill and tinted label', (tester) async {
    await tester.pumpWidget(
      _wrap(const AppBadge(label: 'Fact', color: MonoPulseColors.section5)),
    );
    expect(
      _decoration(tester).color,
      MonoPulseColors.section5.withValues(alpha: 0.1),
    );
    expect(
      tester.widget<Text>(find.text('Fact')).style!.color,
      MonoPulseColors.section5,
    );
  });

  testWidgets('solid badge fills with the colour and uses the label colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const AppBadge.solid(
          label: 'A',
          color: MonoPulseColors.section1,
          labelColor: MonoPulseColors.textHighEmphasis,
        ),
      ),
    );
    expect(_decoration(tester).color, MonoPulseColors.section1);
    expect(
      tester.widget<Text>(find.text('A')).style!.color,
      MonoPulseColors.textHighEmphasis,
    );
  });
}
