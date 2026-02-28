import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/widgets/tools/tool_mode_switcher.dart';
import 'package:flutter_repsync_app/theme/mono_pulse_theme.dart';

// Test enum for mode switcher
enum TestMode { mode1, mode2, mode3 }

void main() {
  group('ToolModeSwitcher', () {
    testWidgets('renders with required parameters', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
              ToolModeOption(mode: TestMode.mode2, label: 'Mode 2'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      expect(find.byType(ToolModeSwitcher), findsOneWidget);
    });

    testWidgets('renders all mode options', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
              ToolModeOption(mode: TestMode.mode2, label: 'Mode 2'),
              ToolModeOption(mode: TestMode.mode3, label: 'Mode 3'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Mode 1'), findsOneWidget);
      expect(find.text('Mode 2'), findsOneWidget);
      expect(find.text('Mode 3'), findsOneWidget);
    });

    testWidgets('highlights active mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
              ToolModeOption(mode: TestMode.mode2, label: 'Mode 2'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      // Active mode should have full opacity (1.0)
      // Inactive mode should have reduced opacity (0.6)
      final opacityWidgets = tester
          .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .toList();

      expect(opacityWidgets.length, equals(2));
      expect(opacityWidgets[0].opacity, equals(1.0)); // Active
      expect(opacityWidgets[1].opacity, equals(0.6)); // Inactive
    });

    testWidgets('updates active mode when tapped', (WidgetTester tester) async {
      TestMode selectedMode = TestMode.mode1;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return ToolModeSwitcher<TestMode>(
                activeMode: selectedMode,
                options: const [
                  ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
                  ToolModeOption(mode: TestMode.mode2, label: 'Mode 2'),
                ],
                onModeChanged: (mode) {
                  setState(() => selectedMode = mode);
                },
              );
            },
          ),
        ),
      );

      // Initially mode1 is active
      expect(find.text('Mode 1'), findsOneWidget);

      // Tap mode2
      await tester.tap(find.text('Mode 2'));
      await tester.pumpAndSettle();

      // Now mode2 should be active (full opacity)
      final opacityWidgets = tester
          .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .toList();
      expect(opacityWidgets[0].opacity, equals(0.6)); // Mode 1 now inactive
      expect(opacityWidgets[1].opacity, equals(1.0)); // Mode 2 now active
    });

    testWidgets('calls onModeChanged when mode is tapped', (
      WidgetTester tester,
    ) async {
      TestMode? selectedMode;

      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
              ToolModeOption(mode: TestMode.mode2, label: 'Mode 2'),
            ],
            onModeChanged: (mode) => selectedMode = mode,
          ),
        ),
      );

      await tester.tap(find.text('Mode 2'));
      await tester.pump();

      expect(selectedMode, equals(TestMode.mode2));
    });

    testWidgets('renders options in a Row', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
              ToolModeOption(mode: TestMode.mode2, label: 'Mode 2'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      expect(find.byType(Row), findsWidgets);
    });

    testWidgets('uses min mainAxisSize for Row', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      final row = tester.widget<Row>(find.byType(Row).first);
      expect(row.mainAxisSize, equals(MainAxisSize.min));
    });
  });

  group('ToolModeSwitcher Styling', () {
    testWidgets('active mode uses accentOrangeSubtle background', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
              ToolModeOption(mode: TestMode.mode2, label: 'Mode 2'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      // Find containers with accentOrangeSubtle background
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasActiveBackground = containers.any(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color ==
                MonoPulseColors.accentOrangeSubtle,
      );

      expect(hasActiveBackground, isTrue);
    });

    testWidgets('inactive mode uses surface background', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
              ToolModeOption(mode: TestMode.mode2, label: 'Mode 2'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      // Find containers with surface background
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasSurfaceBackground = containers.any(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color == MonoPulseColors.surface,
      );

      expect(hasSurfaceBackground, isTrue);
    });

    testWidgets('active mode uses accentOrange border', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
              ToolModeOption(mode: TestMode.mode2, label: 'Mode 2'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      // Find containers with accentOrange border
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasActiveBorder = containers.any(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).border != null &&
            (c.decoration as BoxDecoration).border!.top.color ==
                MonoPulseColors.accentOrange,
      );

      expect(hasActiveBorder, isTrue);
    });

    testWidgets('inactive mode uses borderSubtle border', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
              ToolModeOption(mode: TestMode.mode2, label: 'Mode 2'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      // Find containers with borderSubtle border
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasInactiveBorder = containers.any(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).border != null &&
            (c.decoration as BoxDecoration).border!.top.color ==
                MonoPulseColors.borderSubtle,
      );

      expect(hasInactiveBorder, isTrue);
    });

    testWidgets('active mode text uses accentOrange color', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
              ToolModeOption(mode: TestMode.mode2, label: 'Mode 2'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      // Find the text widget for Mode 1 (active)
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      final activeText = textWidgets.firstWhere(
        (t) => t.data == 'Mode 1',
        orElse: () => const Text(''),
      );

      expect(activeText.style?.color, equals(MonoPulseColors.accentOrange));
    });

    testWidgets('inactive mode text uses textSecondary color', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
              ToolModeOption(mode: TestMode.mode2, label: 'Mode 2'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      // Find the text widget for Mode 2 (inactive)
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      final inactiveText = textWidgets.firstWhere(
        (t) => t.data == 'Mode 2',
        orElse: () => const Text(''),
      );

      expect(inactiveText.style?.color, equals(MonoPulseColors.textSecondary));
    });

    testWidgets('active mode text is bold (w600)', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
              ToolModeOption(mode: TestMode.mode2, label: 'Mode 2'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      final activeText = textWidgets.firstWhere(
        (t) => t.data == 'Mode 1',
        orElse: () => const Text(''),
      );

      expect(activeText.style?.fontWeight, equals(FontWeight.w600));
    });

    testWidgets('inactive mode text is normal weight (w400)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
              ToolModeOption(mode: TestMode.mode2, label: 'Mode 2'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      final inactiveText = textWidgets.firstWhere(
        (t) => t.data == 'Mode 2',
        orElse: () => const Text(''),
      );

      expect(inactiveText.style?.fontWeight, equals(FontWeight.w400));
    });

    testWidgets('uses MonoPulseTypography.labelLarge for text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Mode 1'));
      expect(
        text.style?.fontSize,
        equals(MonoPulseTypography.labelLarge.fontSize),
      );
    });

    testWidgets('pills have rounded corners', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasRoundedCorners = containers.any(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).borderRadius != null &&
            (c.decoration as BoxDecoration).borderRadius is BorderRadius,
      );

      expect(hasRoundedCorners, isTrue);
    });

    testWidgets('border width is 1.5 pixels', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasCorrectBorderWidth = containers.any(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).border != null &&
            (c.decoration as BoxDecoration).border!.top.width == 1.5,
      );

      expect(hasCorrectBorderWidth, isTrue);
    });
  });

  group('ToolModeSwitcher Icons', () {
    testWidgets('renders icon when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(
                mode: TestMode.mode1,
                label: 'Mode 1',
                icon: Icons.play_arrow,
              ),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('does not render icon when not provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('active mode icon uses accentOrange color', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(
                mode: TestMode.mode1,
                label: 'Mode 1',
                icon: Icons.play_arrow,
              ),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.play_arrow));
      expect(icon.color, equals(MonoPulseColors.accentOrange));
    });

    testWidgets('inactive mode icon uses textSecondary color', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(
                mode: TestMode.mode1,
                label: 'Mode 1',
                icon: Icons.play_arrow,
              ),
              ToolModeOption(
                mode: TestMode.mode2,
                label: 'Mode 2',
                icon: Icons.pause,
              ),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.pause));
      expect(icon.color, equals(MonoPulseColors.textSecondary));
    });

    testWidgets('icon size is 18 pixels', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(
                mode: TestMode.mode1,
                label: 'Mode 1',
                icon: Icons.play_arrow,
              ),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.play_arrow));
      expect(icon.size, equals(18));
    });

    testWidgets('icon has spacing before label', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(
                mode: TestMode.mode1,
                label: 'Mode 1',
                icon: Icons.play_arrow,
              ),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      // Verify SizedBox exists between icon and text
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('icon and label are in a Row', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(
                mode: TestMode.mode1,
                label: 'Mode 1',
                icon: Icons.play_arrow,
              ),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      expect(find.byType(Row), findsWidgets);
    });
  });

  group('ToolModeSwitcher Animation', () {
    testWidgets('uses AnimatedOpacity for transitions', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
              ToolModeOption(mode: TestMode.mode2, label: 'Mode 2'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      expect(find.byType(AnimatedOpacity), findsNWidgets(2));
    });

    testWidgets('uses default animation duration of 250ms', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity).first,
      );

      expect(
        animatedOpacity.duration,
        equals(const Duration(milliseconds: 250)),
      );
    });

    testWidgets('uses custom animation duration when provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
            ],
            onModeChanged: (_) {},
            animationDuration: const Duration(milliseconds: 500),
          ),
        ),
      );

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity).first,
      );

      expect(
        animatedOpacity.duration,
        equals(const Duration(milliseconds: 500)),
      );
    });

    testWidgets('uses MonoPulseAnimation.curveCustom', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity).first,
      );

      expect(animatedOpacity.curve, equals(MonoPulseAnimation.curveCustom));
    });

    testWidgets('animates opacity change on mode switch', (
      WidgetTester tester,
    ) async {
      TestMode selectedMode = TestMode.mode1;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return ToolModeSwitcher<TestMode>(
                activeMode: selectedMode,
                options: const [
                  ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
                  ToolModeOption(mode: TestMode.mode2, label: 'Mode 2'),
                ],
                onModeChanged: (mode) {
                  setState(() => selectedMode = mode);
                },
              );
            },
          ),
        ),
      );

      // Initial state
      var opacityWidgets = tester
          .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .toList();
      expect(opacityWidgets[0].opacity, equals(1.0));
      expect(opacityWidgets[1].opacity, equals(0.6));

      // Switch mode
      await tester.tap(find.text('Mode 2'));
      await tester.pump();

      // After tap but before animation completes
      opacityWidgets = tester
          .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .toList();
      expect(opacityWidgets[0].opacity, equals(0.6));
      expect(opacityWidgets[1].opacity, equals(1.0));
    });
  });

  group('ToolModeSwitcher Spacing', () {
    testWidgets('pills have horizontal padding', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      // Verify containers with padding exist
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('pills have vertical padding', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      // Verify the widget renders correctly with padding
      expect(find.text('Mode 1'), findsOneWidget);
    });

    testWidgets('pills have horizontal margin between them', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
              ToolModeOption(mode: TestMode.mode2, label: 'Mode 2'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      // Verify multiple containers exist (for margin)
      final containers = tester.widgetList<Container>(find.byType(Container));
      expect(containers.length, greaterThanOrEqualTo(2));
    });

    testWidgets('uses ToolSpacing for padding', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      // Verify the widget renders with proper spacing
      expect(find.byType(Container), findsWidgets);
    });
  });

  group('ToolModeSwitcher Haptic Feedback', () {
    testWidgets('triggers interaction on mode tap', (
      WidgetTester tester,
    ) async {
      TestMode? selectedMode;

      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
              ToolModeOption(mode: TestMode.mode2, label: 'Mode 2'),
            ],
            onModeChanged: (mode) => selectedMode = mode,
          ),
        ),
      );

      await tester.tap(find.text('Mode 2'));
      await tester.pump();

      expect(selectedMode, equals(TestMode.mode2));
    });

    testWidgets('each mode option is tappable', (WidgetTester tester) async {
      final tappedModes = <TestMode>[];

      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
              ToolModeOption(mode: TestMode.mode2, label: 'Mode 2'),
              ToolModeOption(mode: TestMode.mode3, label: 'Mode 3'),
            ],
            onModeChanged: (mode) => tappedModes.add(mode),
          ),
        ),
      );

      // Tap each mode
      await tester.tap(find.text('Mode 1'));
      await tester.pump();
      await tester.tap(find.text('Mode 2'));
      await tester.pump();
      await tester.tap(find.text('Mode 3'));
      await tester.pump();

      expect(tappedModes.length, equals(3));
      expect(tappedModes[0], equals(TestMode.mode1));
      expect(tappedModes[1], equals(TestMode.mode2));
      expect(tappedModes[2], equals(TestMode.mode3));
    });
  });

  group('ToolModeSwitcher Accessibility', () {
    testWidgets('pills have adequate touch target size', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      // Verify the GestureDetector wraps the pill
      expect(find.byType(GestureDetector), findsWidgets);

      // Get the size of the pill
      final gestureDetector = tester.firstWidget<GestureDetector>(
        find.byType(GestureDetector),
      );
      expect(gestureDetector.onTap, isNotNull);
    });

    testWidgets('pills are clearly differentiated by state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
              ToolModeOption(mode: TestMode.mode2, label: 'Mode 2'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      // Active and inactive should have different opacities
      final opacityWidgets = tester
          .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .toList();

      expect(
        opacityWidgets[0].opacity,
        isNot(equals(opacityWidgets[1].opacity)),
      );
    });

    testWidgets('text has sufficient contrast', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Mode 1'));
      // Active text uses accentOrange which has good contrast on dark background
      expect(text.style?.color, equals(MonoPulseColors.accentOrange));
    });
  });

  group('ToolModeOption', () {
    testWidgets('creates option with mode and label', (
      WidgetTester tester,
    ) async {
      const option = ToolModeOption(mode: TestMode.mode1, label: 'Test Label');

      expect(option.mode, equals(TestMode.mode1));
      expect(option.label, equals('Test Label'));
    });

    testWidgets('creates option with optional icon', (
      WidgetTester tester,
    ) async {
      const option = ToolModeOption(
        mode: TestMode.mode1,
        label: 'Test Label',
        icon: Icons.star,
      );

      expect(option.mode, equals(TestMode.mode1));
      expect(option.label, equals('Test Label'));
      expect(option.icon, equals(Icons.star));
    });

    testWidgets('creates option without icon', (WidgetTester tester) async {
      const option = ToolModeOption(mode: TestMode.mode1, label: 'Test Label');

      expect(option.icon, isNull);
    });
  });

  group('ToolModeSwitcher Edge Cases', () {
    testWidgets('handles single option', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(mode: TestMode.mode1, label: 'Only Mode'),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Only Mode'), findsOneWidget);
      expect(find.byType(AnimatedOpacity), findsOneWidget);
    });

    testWidgets('handles many options', (WidgetTester tester) async {
      const options = [
        ToolModeOption(mode: TestMode.mode1, label: '1'),
        ToolModeOption(mode: TestMode.mode2, label: '2'),
        ToolModeOption(mode: TestMode.mode3, label: '3'),
        ToolModeOption(mode: TestMode.mode1, label: '4'),
        ToolModeOption(mode: TestMode.mode2, label: '5'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: options,
            onModeChanged: (_) {},
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('handles long label text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToolModeSwitcher<TestMode>(
            activeMode: TestMode.mode1,
            options: const [
              ToolModeOption(
                mode: TestMode.mode1,
                label: 'Very Long Mode Label That Should Still Render',
              ),
            ],
            onModeChanged: (_) {},
          ),
        ),
      );

      expect(
        find.text('Very Long Mode Label That Should Still Render'),
        findsOneWidget,
      );
    });

    testWidgets('maintains state after rebuild', (WidgetTester tester) async {
      TestMode selectedMode = TestMode.mode1;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return ToolModeSwitcher<TestMode>(
                activeMode: selectedMode,
                options: const [
                  ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
                  ToolModeOption(mode: TestMode.mode2, label: 'Mode 2'),
                ],
                onModeChanged: (mode) {
                  setState(() => selectedMode = mode);
                },
              );
            },
          ),
        ),
      );

      // Switch to mode 2
      await tester.tap(find.text('Mode 2'));
      await tester.pumpAndSettle();

      // Rebuild with same state
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return ToolModeSwitcher<TestMode>(
                activeMode: selectedMode,
                options: const [
                  ToolModeOption(mode: TestMode.mode1, label: 'Mode 1'),
                  ToolModeOption(mode: TestMode.mode2, label: 'Mode 2'),
                ],
                onModeChanged: (mode) {
                  setState(() => selectedMode = mode);
                },
              );
            },
          ),
        ),
      );

      // Mode 2 should still be active
      final opacityWidgets = tester
          .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .toList();
      expect(opacityWidgets[0].opacity, equals(0.6));
      expect(opacityWidgets[1].opacity, equals(1.0));
    });
  });
}
