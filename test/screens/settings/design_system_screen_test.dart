import 'package:flowgroove/screens/settings/design_system_screen.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows brand tokens and instrument component patterns', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DesignSystemScreen()));

    expect(find.text('FlowGroove / field guide'), findsOneWidget);
    expect(find.text('Made for the room.'), findsOneWidget);
    expect(find.text('01 / Palette'), findsOneWidget);
    expect(find.text('Paper'), findsOneWidget);
    expect(find.text('Signal orange'), findsOneWidget);
    expect(find.text('02 / Type'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('03 / Controls'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('03 / Controls'), findsOneWidget);
    expect(find.text('Play set'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('05 / Rules'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('05 / Rules'), findsOneWidget);
    expect(
      find.text(
        'Orange marks the main action. Stone and Fog mark selections; gray keeps secondary details quiet.',
      ),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('06 / Screen examples'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text('Song view'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Song view'));
    await tester.pumpAndSettle();
    expect(find.text('Setlist view'), findsOneWidget);
    expect(find.text('Song view'), findsOneWidget);
    await tester.tap(find.text('Song view'));
    await tester.pumpAndSettle();
    expect(find.text('Viento Helado'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Add song'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Add song'));
    await tester.pumpAndSettle();
    expect(find.text('Add a song'), findsOneWidget);
    expect(find.text('Song title', findRichText: true), findsOneWidget);
    expect(find.text('Save song'), findsOneWidget);
    await tester.tap(find.text('Song view'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Lyrics + chords'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Lyrics + chords'), findsOneWidget);
  });

  test('exposes the approved FlowGroove palette and type roles', () {
    expect(MonoPulseColors.paper, const Color(0xFFF6F5F0));
    expect(MonoPulseColors.accentOrange, const Color(0xFFFF5A36));
    expect(MonoPulseTypography.headlineLarge.fontFamily, 'Marcellus');
    expect(MonoPulseTypography.bodyLarge.fontFamily, 'Source Serif 4');
    expect(MonoPulseTypography.labelLarge.fontFamily, 'Arial');
  });
}
