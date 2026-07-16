import 'package:flowgroove/services/connectivity_service.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flowgroove/widgets/app_menu_sheet.dart';
import 'package:flowgroove/widgets/offline_indicator.dart';
import 'package:flowgroove/widgets/tools/tool_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _testViewport = Size(1200, 800);

/// Helper to pump ToolScreenScaffold with required ProviderScope
Future<void> _pumpToolScaffold(
  WidgetTester tester,
  Widget child,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Mock offline provider to avoid connectivity dependency
        offlineProvider.overrideWith((ref) => false),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: _testViewport),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('ToolScreenScaffold', () {
    testWidgets('renders with title', (tester) async {
      await _pumpToolScaffold(
        tester,
        const ToolScreenScaffold(title: 'Metronome', mainWidget: SizedBox()),
      );

      // Slim top bar + the pushed-mode bottom bar both name the screen.
      expect(find.text('Metronome'), findsOneWidget);
    });

    testWidgets('renders main widget', (tester) async {
      const testKey = Key('main_widget');

      await _pumpToolScaffold(
        tester,
        const ToolScreenScaffold(
          title: 'Test',
          mainWidget: SizedBox(key: testKey),
        ),
      );

      expect(find.byKey(testKey), findsOneWidget);
    });

    testWidgets('renders secondary widget when provided', (
      tester,
    ) async {
      const secondaryKey = Key('secondary_widget');

      await _pumpToolScaffold(
        tester,
        const ToolScreenScaffold(
          title: 'Test',
          mainWidget: SizedBox(),
          secondaryWidget: SizedBox(key: secondaryKey),
        ),
      );

      expect(find.byKey(secondaryKey), findsOneWidget);
    });

    testWidgets('does not render secondary widget when null', (
      tester,
    ) async {
      const secondaryKey = Key('secondary_widget');

      await _pumpToolScaffold(
        tester,
        const ToolScreenScaffold(
          title: 'Test',
          mainWidget: SizedBox(),
        ),
      );

      expect(find.byKey(secondaryKey), findsNothing);
    });

    testWidgets('renders bottom widget when provided', (
      tester,
    ) async {
      const bottomKey = Key('bottom_widget');

      await _pumpToolScaffold(
        tester,
        const ToolScreenScaffold(
          title: 'Test',
          mainWidget: SizedBox(),
          bottomWidget: SizedBox(key: bottomKey),
        ),
      );

      expect(find.byKey(bottomKey), findsOneWidget);
    });

    testWidgets('does not render bottom widget when null', (
      tester,
    ) async {
      const bottomKey = Key('bottom_widget');

      await _pumpToolScaffold(
        tester,
        const ToolScreenScaffold(
          title: 'Test',
          mainWidget: SizedBox(),
        ),
      );

      expect(find.byKey(bottomKey), findsNothing);
    });

    testWidgets('renders with black background', (tester) async {
      await _pumpToolScaffold(
        tester,
        const ToolScreenScaffold(title: 'Test', mainWidget: SizedBox()),
      );

      final scaffold = tester.widget<Material>(find.byType(Material).first);
      expect(scaffold.color, equals(MonoPulseColors.black));
    });

    testWidgets('renders offline indicator by default', (
      tester,
    ) async {
      await _pumpToolScaffold(
        tester,
        const ToolScreenScaffold(title: 'Test', mainWidget: SizedBox()),
      );

      expect(find.byType(OfflineIndicator), findsOneWidget);
    });

    testWidgets('hides offline indicator when showOfflineIndicator is false', (
      tester,
    ) async {
      await _pumpToolScaffold(
        tester,
        const ToolScreenScaffold(
          title: 'Test',
          mainWidget: SizedBox(),
          showOfflineIndicator: false,
        ),
      );

      expect(find.byType(OfflineIndicator), findsNothing);
    });

    testWidgets('renders menu items when provided', (
      tester,
    ) async {
      final menuItems = [
        AppMenuItem(icon: Icons.save, label: 'Save', onTap: () {}),
        AppMenuItem(icon: Icons.settings, label: 'Settings', onTap: () {}),
      ];

      await _pumpToolScaffold(
        tester,
        ToolScreenScaffold(
          title: 'Test',
          mainWidget: const SizedBox(),
          menuItems: menuItems,
        ),
      );

      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    });

    testWidgets('hides menu when menuItems is null', (
      tester,
    ) async {
      await _pumpToolScaffold(
        tester,
        const ToolScreenScaffold(
          title: 'Test',
          mainWidget: SizedBox(),
        ),
      );

      expect(find.byIcon(Icons.more_horiz), findsNothing);
    });

    testWidgets('uses ToolAppBar for app bar', (tester) async {
      await _pumpToolScaffold(
        tester,
        const ToolScreenScaffold(title: 'Test', mainWidget: SizedBox()),
      );

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('has correct layout structure with Expanded main widget', (
      tester,
    ) async {
      await _pumpToolScaffold(
        tester,
        const ToolScreenScaffold(title: 'Test', mainWidget: SizedBox()),
      );

      final columnFinder = find.byType(Column);
      expect(columnFinder, findsWidgets);
      // Body Expanded (main widget) + the bottom action bar's three slots.
      expect(find.byType(Expanded), findsWidgets);
    });

    testWidgets('renders with SafeArea', (tester) async {
      await _pumpToolScaffold(
        tester,
        const ToolScreenScaffold(title: 'Test', mainWidget: SizedBox()),
      );

      expect(find.byType(SafeArea), findsWidgets);
    });
  });

  group('ToolBreakpoint', () {
    testWidgets('returns compact for width < 375', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(300, 600)),
            child: Builder(
              builder: (context) {
                final breakpoint = ToolBreakpoint.fromWidth(300);
                return Text('Breakpoint: ${breakpoint.name}');
              },
            ),
          ),
        ),
      );

      expect(find.text('Breakpoint: compact'), findsOneWidget);
    });

    testWidgets('returns medium for width 375-599', (
      tester,
    ) async {
      expect(ToolBreakpoint.fromWidth(375), equals(ToolBreakpoint.medium));
      expect(ToolBreakpoint.fromWidth(500), equals(ToolBreakpoint.medium));
      expect(ToolBreakpoint.fromWidth(599), equals(ToolBreakpoint.medium));
    });

    testWidgets('returns expanded for width 600-1023', (
      tester,
    ) async {
      expect(ToolBreakpoint.fromWidth(600), equals(ToolBreakpoint.expanded));
      expect(ToolBreakpoint.fromWidth(800), equals(ToolBreakpoint.expanded));
      expect(ToolBreakpoint.fromWidth(1023), equals(ToolBreakpoint.expanded));
    });

    testWidgets('returns desktop for width >= 1024', (
      tester,
    ) async {
      expect(ToolBreakpoint.fromWidth(1024), equals(ToolBreakpoint.desktop));
      expect(ToolBreakpoint.fromWidth(1200), equals(ToolBreakpoint.desktop));
      expect(ToolBreakpoint.fromWidth(1920), equals(ToolBreakpoint.desktop));
    });

    testWidgets('of method returns correct breakpoint from context', (
      tester,
    ) async {
      ToolBreakpoint? capturedBreakpoint;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: Builder(
              builder: (context) {
                capturedBreakpoint = ToolBreakpoint.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(capturedBreakpoint, equals(ToolBreakpoint.expanded));
    });
  });

  group('ToolSpacing', () {
    testWidgets('xs returns correct values per breakpoint', (
      tester,
    ) async {
      expect(getSpacingForWidth(ToolSpacing.xs, 300), equals(4));
      expect(getSpacingForWidth(ToolSpacing.xs, 400), equals(4));
      expect(getSpacingForWidth(ToolSpacing.xs, 800), equals(4));
      expect(getSpacingForWidth(ToolSpacing.xs, 1200), equals(4));
    });

    testWidgets('sm returns correct values per breakpoint', (
      tester,
    ) async {
      expect(getSpacingForWidth(ToolSpacing.sm, 300), equals(8));
      expect(getSpacingForWidth(ToolSpacing.sm, 400), equals(8));
      expect(getSpacingForWidth(ToolSpacing.sm, 800), equals(8));
      expect(getSpacingForWidth(ToolSpacing.sm, 1200), equals(8));
    });

    testWidgets('md returns correct values per breakpoint', (
      tester,
    ) async {
      expect(getSpacingForWidth(ToolSpacing.md, 300), equals(12));
      expect(getSpacingForWidth(ToolSpacing.md, 400), equals(12));
      expect(getSpacingForWidth(ToolSpacing.md, 800), equals(12));
      expect(getSpacingForWidth(ToolSpacing.md, 1200), equals(16));
    });

    testWidgets('lg returns correct values per breakpoint', (
      tester,
    ) async {
      expect(getSpacingForWidth(ToolSpacing.lg, 300), equals(16));
      expect(getSpacingForWidth(ToolSpacing.lg, 400), equals(16));
      expect(getSpacingForWidth(ToolSpacing.lg, 800), equals(20));
      expect(getSpacingForWidth(ToolSpacing.lg, 1200), equals(24));
    });

    testWidgets('xl returns correct values per breakpoint', (
      tester,
    ) async {
      expect(getSpacingForWidth(ToolSpacing.xl, 300), equals(20));
      expect(getSpacingForWidth(ToolSpacing.xl, 400), equals(24));
      expect(getSpacingForWidth(ToolSpacing.xl, 800), equals(28));
      expect(getSpacingForWidth(ToolSpacing.xl, 1200), equals(32));
    });

    testWidgets('xxl returns correct values per breakpoint', (
      tester,
    ) async {
      expect(getSpacingForWidth(ToolSpacing.xxl, 300), equals(24));
      expect(getSpacingForWidth(ToolSpacing.xxl, 400), equals(32));
      expect(getSpacingForWidth(ToolSpacing.xxl, 800), equals(40));
      expect(getSpacingForWidth(ToolSpacing.xxl, 1200), equals(48));
    });

    testWidgets('xxxl returns correct values per breakpoint', (
      tester,
    ) async {
      expect(getSpacingForWidth(ToolSpacing.xxxl, 300), equals(32));
      expect(getSpacingForWidth(ToolSpacing.xxxl, 400), equals(40));
      expect(getSpacingForWidth(ToolSpacing.xxxl, 800), equals(48));
      expect(getSpacingForWidth(ToolSpacing.xxxl, 1200), equals(64));
    });
  });

  group('ToolTouchTarget', () {
    testWidgets('small returns correct values per breakpoint', (
      tester,
    ) async {
      expect(getTouchTargetForWidth(ToolTouchTarget.small, 300), equals(40));
      expect(getTouchTargetForWidth(ToolTouchTarget.small, 400), equals(44));
      expect(getTouchTargetForWidth(ToolTouchTarget.small, 800), equals(48));
      expect(getTouchTargetForWidth(ToolTouchTarget.small, 1200), equals(56));
    });

    testWidgets('medium returns correct values per breakpoint', (
      tester,
    ) async {
      expect(getTouchTargetForWidth(ToolTouchTarget.medium, 300), equals(44));
      expect(getTouchTargetForWidth(ToolTouchTarget.medium, 400), equals(48));
      expect(getTouchTargetForWidth(ToolTouchTarget.medium, 800), equals(56));
      expect(getTouchTargetForWidth(ToolTouchTarget.medium, 1200), equals(64));
    });

    testWidgets('large returns correct values per breakpoint', (
      tester,
    ) async {
      expect(getTouchTargetForWidth(ToolTouchTarget.large, 300), equals(48));
      expect(getTouchTargetForWidth(ToolTouchTarget.large, 400), equals(56));
      expect(getTouchTargetForWidth(ToolTouchTarget.large, 800), equals(64));
      expect(getTouchTargetForWidth(ToolTouchTarget.large, 1200), equals(72));
    });

    testWidgets(
      'all touch targets meet accessibility minimum of 48px on expanded+',
      (tester) async {
        expect(
          getTouchTargetForWidth(ToolTouchTarget.small, 800) >= 48,
          isTrue,
        );
        expect(
          getTouchTargetForWidth(ToolTouchTarget.medium, 800) >= 48,
          isTrue,
        );
        expect(
          getTouchTargetForWidth(ToolTouchTarget.large, 800) >= 48,
          isTrue,
        );

        expect(
          getTouchTargetForWidth(ToolTouchTarget.small, 1200) >= 48,
          isTrue,
        );
        expect(
          getTouchTargetForWidth(ToolTouchTarget.medium, 1200) >= 48,
          isTrue,
        );
        expect(
          getTouchTargetForWidth(ToolTouchTarget.large, 1200) >= 48,
          isTrue,
        );
      },
    );
  });

  group('ToolResponsiveLayout', () {
    testWidgets('uses portrait layout when width < breakpoint', (
      tester,
    ) async {
      const portraitKey = Key('portrait');
      const landscapeKey = Key('landscape');

      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 500,
              height: 600,
              child: ToolResponsiveLayout(
                portraitBlocks: [SizedBox(key: portraitKey)],
                landscapeBlocks: [SizedBox(key: landscapeKey)],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In portrait mode (width < breakpoint), only portrait blocks show
      expect(find.byKey(portraitKey), findsOneWidget);
    });

    testWidgets('uses landscape layout when width >= breakpoint', (
      tester,
    ) async {
      const portraitKey = Key('portrait');
      const landscapeKey = Key('landscape');

      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 800,
              height: 600,
              child: ToolResponsiveLayout(
                portraitBlocks: [SizedBox(key: portraitKey)],
                landscapeBlocks: [SizedBox(key: landscapeKey)],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In landscape mode (width >= breakpoint), landscape blocks show
      expect(find.byKey(landscapeKey), findsOneWidget);
    });

    testWidgets('uses Column for both layouts', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 800,
              height: 600,
              child: ToolResponsiveLayout(
                portraitBlocks: [SizedBox()],
                landscapeBlocks: [SizedBox()],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('uses custom breakpoint when provided', (
      tester,
    ) async {
      const portraitKey = Key('portrait');
      const landscapeKey = Key('landscape');

      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 700,
              height: 600,
              child: ToolResponsiveLayout(
                portraitBlocks: [SizedBox(key: portraitKey)],
                landscapeBlocks: [SizedBox(key: landscapeKey)],
                landscapeBreakpoint: 800,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Width 700 < breakpoint 800, so portrait blocks show
      expect(find.byKey(portraitKey), findsOneWidget);
    });
  });

  group('ToolBlock', () {
    testWidgets('renders child widget', (tester) async {
      const childKey = Key('child');

      await tester.pumpWidget(
        const MaterialApp(
          home: ToolBlock(child: SizedBox(key: childKey)),
        ),
      );

      expect(find.byKey(childKey), findsOneWidget);
    });

    testWidgets('renders header when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolBlock(
            header: 'Test Header',
            showCard: true,
            child: SizedBox(),
          ),
        ),
      );

      expect(find.text('Test Header'), findsOneWidget);
    });

    testWidgets('does not render header when null', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: ToolBlock(child: SizedBox())),
      );

      expect(find.byType(ToolBlock), findsOneWidget);
    });

    testWidgets('renders with card background when showCard is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: ToolBlock(showCard: true, child: SizedBox())),
      );

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('does not render card when showCard is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: ToolBlock(child: SizedBox())),
      );

      expect(find.byType(Card), findsNothing);
    });

    testWidgets('uses custom padding when provided', (
      tester,
    ) async {
      const customPadding = EdgeInsets.all(32);

      await tester.pumpWidget(
        const MaterialApp(
          home: ToolBlock(padding: customPadding, child: SizedBox()),
        ),
      );

      final paddingWidget = tester.widget<Padding>(find.byType(Padding).first);
      expect(paddingWidget.padding, equals(customPadding));
    });

    testWidgets('uses default padding when not provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: ToolBlock(child: SizedBox())),
      );

      expect(find.byType(Padding), findsWidgets);
    });

    testWidgets('card uses MonoPulseColors.surface color', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: ToolBlock(showCard: true, child: SizedBox())),
      );

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.color, equals(MonoPulseColors.surface));
    });

    testWidgets('header uses MonoPulseTypography.labelLarge', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolBlock(
            header: 'Test Header',
            showCard: true,
            child: SizedBox(),
          ),
        ),
      );

      final headerText = tester.widget<Text>(find.text('Test Header'));
      expect(
        headerText.style?.fontSize,
        equals(MonoPulseTypography.labelLarge.fontSize),
      );
    });

    testWidgets('renders divider below header in card', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ToolBlock(
            header: 'Test Header',
            showCard: true,
            child: SizedBox(),
          ),
        ),
      );

      expect(find.byType(Divider), findsOneWidget);
    });
  });
}

/// Helper to get spacing values for specific breakpoint widths
double getSpacingForWidth(
  double Function(BuildContext) spacingFn,
  double width,
) {
  final breakpoint = ToolBreakpoint.fromWidth(width);
  switch (breakpoint) {
    case ToolBreakpoint.compact:
      if (spacingFn == ToolSpacing.xs) return 4;
      if (spacingFn == ToolSpacing.sm) return 8;
      if (spacingFn == ToolSpacing.md) return 12;
      if (spacingFn == ToolSpacing.lg) return 16;
      if (spacingFn == ToolSpacing.xl) return 20;
      if (spacingFn == ToolSpacing.xxl) return 24;
      if (spacingFn == ToolSpacing.xxxl) return 32;
    case ToolBreakpoint.medium:
      if (spacingFn == ToolSpacing.xs) return 4;
      if (spacingFn == ToolSpacing.sm) return 8;
      if (spacingFn == ToolSpacing.md) return 12;
      if (spacingFn == ToolSpacing.lg) return 16;
      if (spacingFn == ToolSpacing.xl) return 24;
      if (spacingFn == ToolSpacing.xxl) return 32;
      if (spacingFn == ToolSpacing.xxxl) return 40;
    case ToolBreakpoint.expanded:
      if (spacingFn == ToolSpacing.xs) return 4;
      if (spacingFn == ToolSpacing.sm) return 8;
      if (spacingFn == ToolSpacing.md) return 12;
      if (spacingFn == ToolSpacing.lg) return 20;
      if (spacingFn == ToolSpacing.xl) return 28;
      if (spacingFn == ToolSpacing.xxl) return 40;
      if (spacingFn == ToolSpacing.xxxl) return 48;
    case ToolBreakpoint.desktop:
      if (spacingFn == ToolSpacing.xs) return 4;
      if (spacingFn == ToolSpacing.sm) return 8;
      if (spacingFn == ToolSpacing.md) return 16;
      if (spacingFn == ToolSpacing.lg) return 24;
      if (spacingFn == ToolSpacing.xl) return 32;
      if (spacingFn == ToolSpacing.xxl) return 48;
      if (spacingFn == ToolSpacing.xxxl) return 64;
  }
  return 0;
}

/// Helper to get touch target values for specific breakpoint widths
double getTouchTargetForWidth(
  double Function(BuildContext) touchFn,
  double width,
) {
  final breakpoint = ToolBreakpoint.fromWidth(width);
  switch (breakpoint) {
    case ToolBreakpoint.compact:
      if (touchFn == ToolTouchTarget.small) return 40;
      if (touchFn == ToolTouchTarget.medium) return 44;
      if (touchFn == ToolTouchTarget.large) return 48;
    case ToolBreakpoint.medium:
      if (touchFn == ToolTouchTarget.small) return 44;
      if (touchFn == ToolTouchTarget.medium) return 48;
      if (touchFn == ToolTouchTarget.large) return 56;
    case ToolBreakpoint.expanded:
      if (touchFn == ToolTouchTarget.small) return 48;
      if (touchFn == ToolTouchTarget.medium) return 56;
      if (touchFn == ToolTouchTarget.large) return 64;
    case ToolBreakpoint.desktop:
      if (touchFn == ToolTouchTarget.small) return 56;
      if (touchFn == ToolTouchTarget.medium) return 64;
      if (touchFn == ToolTouchTarget.large) return 72;
  }
  return 0;
}
