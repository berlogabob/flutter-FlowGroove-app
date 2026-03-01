import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/widgets/tools/tool_scaffold.dart';

void main() {
  group('ToolSpacing Responsive Breakpoints', () {
    testWidgets('xs spacing adapts to compact breakpoint', (
      WidgetTester tester,
    ) async {
      double? spacingValue;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(300, 600)),
            child: Builder(
              builder: (context) {
                spacingValue = ToolSpacing.xs(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(spacingValue, equals(4));
    });

    testWidgets('xs spacing adapts to medium breakpoint', (
      WidgetTester tester,
    ) async {
      double? spacingValue;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 600)),
            child: Builder(
              builder: (context) {
                spacingValue = ToolSpacing.xs(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(spacingValue, equals(4));
    });

    testWidgets('xs spacing adapts to expanded breakpoint', (
      WidgetTester tester,
    ) async {
      double? spacingValue;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: Builder(
              builder: (context) {
                spacingValue = ToolSpacing.xs(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(spacingValue, equals(4));
    });

    testWidgets('xs spacing adapts to desktop breakpoint', (
      WidgetTester tester,
    ) async {
      double? spacingValue;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1200, 800)),
            child: Builder(
              builder: (context) {
                spacingValue = ToolSpacing.xs(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(spacingValue, equals(4));
    });

    testWidgets('sm spacing is consistent across breakpoints', (
      WidgetTester tester,
    ) async {
      final testCases = [
        {'width': 300.0, 'expected': 8.0},
        {'width': 400.0, 'expected': 8.0},
        {'width': 800.0, 'expected': 8.0},
        {'width': 1200.0, 'expected': 8.0},
      ];

      for (final testCase in testCases) {
        double? spacingValue;

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: Size(testCase['width']!, 600)),
              child: Builder(
                builder: (context) {
                  spacingValue = ToolSpacing.sm(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(spacingValue, equals(testCase['expected']));
      }
    });

    testWidgets('md spacing increases at desktop', (WidgetTester tester) async {
      final testCases = [
        {'width': 300.0, 'expected': 12.0},
        {'width': 400.0, 'expected': 12.0},
        {'width': 800.0, 'expected': 12.0},
        {'width': 1200.0, 'expected': 16.0},
      ];

      for (final testCase in testCases) {
        double? spacingValue;

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: Size(testCase['width']!, 600)),
              child: Builder(
                builder: (context) {
                  spacingValue = ToolSpacing.md(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(spacingValue, equals(testCase['expected']));
      }
    });

    testWidgets('lg spacing scales with breakpoints', (
      WidgetTester tester,
    ) async {
      final testCases = [
        {'width': 300.0, 'expected': 16.0},
        {'width': 400.0, 'expected': 16.0},
        {'width': 800.0, 'expected': 20.0},
        {'width': 1200.0, 'expected': 24.0},
      ];

      for (final testCase in testCases) {
        double? spacingValue;

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: Size(testCase['width']!, 600)),
              child: Builder(
                builder: (context) {
                  spacingValue = ToolSpacing.lg(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(spacingValue, equals(testCase['expected']));
      }
    });

    testWidgets('xl spacing scales with breakpoints', (
      WidgetTester tester,
    ) async {
      final testCases = [
        {'width': 300.0, 'expected': 20.0},
        {'width': 400.0, 'expected': 24.0},
        {'width': 800.0, 'expected': 28.0},
        {'width': 1200.0, 'expected': 32.0},
      ];

      for (final testCase in testCases) {
        double? spacingValue;

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: Size(testCase['width']!, 600)),
              child: Builder(
                builder: (context) {
                  spacingValue = ToolSpacing.xl(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(spacingValue, equals(testCase['expected']));
      }
    });

    testWidgets('xxl spacing scales with breakpoints', (
      WidgetTester tester,
    ) async {
      final testCases = [
        {'width': 300.0, 'expected': 24.0},
        {'width': 400.0, 'expected': 32.0},
        {'width': 800.0, 'expected': 40.0},
        {'width': 1200.0, 'expected': 48.0},
      ];

      for (final testCase in testCases) {
        double? spacingValue;

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: Size(testCase['width']!, 600)),
              child: Builder(
                builder: (context) {
                  spacingValue = ToolSpacing.xxl(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(spacingValue, equals(testCase['expected']));
      }
    });

    testWidgets('xxxl spacing scales with breakpoints', (
      WidgetTester tester,
    ) async {
      final testCases = [
        {'width': 300.0, 'expected': 32.0},
        {'width': 400.0, 'expected': 40.0},
        {'width': 800.0, 'expected': 48.0},
        {'width': 1200.0, 'expected': 64.0},
      ];

      for (final testCase in testCases) {
        double? spacingValue;

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: Size(testCase['width']!, 600)),
              child: Builder(
                builder: (context) {
                  spacingValue = ToolSpacing.xxxl(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(spacingValue, equals(testCase['expected']));
      }
    });

    testWidgets('spacing follows 4-point grid system', (
      WidgetTester tester,
    ) async {
      final allSpacingMethods = [
        (BuildContext ctx) => ToolSpacing.xs(ctx),
        (BuildContext ctx) => ToolSpacing.sm(ctx),
        (BuildContext ctx) => ToolSpacing.md(ctx),
        (BuildContext ctx) => ToolSpacing.lg(ctx),
        (BuildContext ctx) => ToolSpacing.xl(ctx),
        (BuildContext ctx) => ToolSpacing.xxl(ctx),
        (BuildContext ctx) => ToolSpacing.xxxl(ctx),
      ];

      final testWidths = [300.0, 400.0, 800.0, 1200.0];

      for (final width in testWidths) {
        for (final method in allSpacingMethods) {
          double? spacingValue;

          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(size: Size(width, 600)),
                child: Builder(
                  builder: (context) {
                    spacingValue = method(context);
                    return const SizedBox();
                  },
                ),
              ),
            ),
          );

          expect(
            spacingValue! % 4,
            equals(0),
            reason:
                'Spacing $spacingValue at width $width is not a multiple of 4',
          );
        }
      }
    });
  });

  group('ToolTouchTarget Adaptive Sizing', () {
    testWidgets('small touch target adapts to compact breakpoint', (
      WidgetTester tester,
    ) async {
      double? touchSize;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(300, 600)),
            child: Builder(
              builder: (context) {
                touchSize = ToolTouchTarget.small(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(touchSize, equals(40));
    });

    testWidgets('small touch target adapts to medium breakpoint', (
      WidgetTester tester,
    ) async {
      double? touchSize;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 600)),
            child: Builder(
              builder: (context) {
                touchSize = ToolTouchTarget.small(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(touchSize, equals(44));
    });

    testWidgets('small touch target adapts to expanded breakpoint', (
      WidgetTester tester,
    ) async {
      double? touchSize;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: Builder(
              builder: (context) {
                touchSize = ToolTouchTarget.small(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(touchSize, equals(48));
    });

    testWidgets('small touch target adapts to desktop breakpoint', (
      WidgetTester tester,
    ) async {
      double? touchSize;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1200, 800)),
            child: Builder(
              builder: (context) {
                touchSize = ToolTouchTarget.small(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(touchSize, equals(56));
    });

    testWidgets('medium touch target scales with breakpoints', (
      WidgetTester tester,
    ) async {
      final testCases = [
        {'width': 300.0, 'expected': 44.0},
        {'width': 400.0, 'expected': 48.0},
        {'width': 800.0, 'expected': 56.0},
        {'width': 1200.0, 'expected': 64.0},
      ];

      for (final testCase in testCases) {
        double? touchSize;

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: Size(testCase['width']!, 600)),
              child: Builder(
                builder: (context) {
                  touchSize = ToolTouchTarget.medium(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(touchSize, equals(testCase['expected']));
      }
    });

    testWidgets('large touch target scales with breakpoints', (
      WidgetTester tester,
    ) async {
      final testCases = [
        {'width': 300.0, 'expected': 48.0},
        {'width': 400.0, 'expected': 56.0},
        {'width': 800.0, 'expected': 64.0},
        {'width': 1200.0, 'expected': 72.0},
      ];

      for (final testCase in testCases) {
        double? touchSize;

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: Size(testCase['width']!, 600)),
              child: Builder(
                builder: (context) {
                  touchSize = ToolTouchTarget.large(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(touchSize, equals(testCase['expected']));
      }
    });

    testWidgets('touch targets increase with screen size', (
      WidgetTester tester,
    ) async {
      final widths = [300.0, 400.0, 800.0, 1200.0];

      for (final width in widths) {
        double? smallSize, mediumSize, largeSize;

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: Size(width, 600)),
              child: Builder(
                builder: (context) {
                  smallSize = ToolTouchTarget.small(context);
                  mediumSize = ToolTouchTarget.medium(context);
                  largeSize = ToolTouchTarget.large(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(
          smallSize! < mediumSize!,
          isTrue,
          reason: 'Small should be less than medium at width $width',
        );
        expect(
          mediumSize! < largeSize!,
          isTrue,
          reason: 'Medium should be less than large at width $width',
        );
      }
    });
  });

  group('Accessibility - Touch Target Minimum 48px', () {
    testWidgets('small touch target meets 48px minimum on expanded+', (
      WidgetTester tester,
    ) async {
      double? expandedSize;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: Builder(
              builder: (context) {
                expandedSize = ToolTouchTarget.small(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(expandedSize, greaterThanOrEqualTo(48));

      double? desktopSize;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1200, 800)),
            child: Builder(
              builder: (context) {
                desktopSize = ToolTouchTarget.small(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(desktopSize, greaterThanOrEqualTo(48));
    });

    testWidgets('medium touch target meets 48px minimum on medium+', (
      WidgetTester tester,
    ) async {
      double? mediumSize;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 600)),
            child: Builder(
              builder: (context) {
                mediumSize = ToolTouchTarget.medium(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(mediumSize, greaterThanOrEqualTo(48));

      double? expandedSize;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: Builder(
              builder: (context) {
                expandedSize = ToolTouchTarget.medium(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(expandedSize, greaterThanOrEqualTo(48));

      double? desktopSize;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1200, 800)),
            child: Builder(
              builder: (context) {
                desktopSize = ToolTouchTarget.medium(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(desktopSize, greaterThanOrEqualTo(48));
    });

    testWidgets('large touch target meets 48px minimum on all breakpoints', (
      WidgetTester tester,
    ) async {
      final widths = [300.0, 400.0, 800.0, 1200.0];

      for (final width in widths) {
        double? touchSize;

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: Size(width, 600)),
              child: Builder(
                builder: (context) {
                  touchSize = ToolTouchTarget.large(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(
          touchSize,
          greaterThanOrEqualTo(48),
          reason: 'Large touch target should be >= 48px at width $width',
        );
      }
    });

    testWidgets('compact breakpoint small target is 40px (below 48)', (
      WidgetTester tester,
    ) async {
      double? touchSize;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(300, 600)),
            child: Builder(
              builder: (context) {
                touchSize = ToolTouchTarget.small(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(touchSize, equals(40));
    });
  });

  group('ToolBreakpoint Edge Cases', () {
    testWidgets('handles exact breakpoint boundaries', (
      WidgetTester tester,
    ) async {
      expect(ToolBreakpoint.fromWidth(374), equals(ToolBreakpoint.compact));
      expect(ToolBreakpoint.fromWidth(375), equals(ToolBreakpoint.medium));
      expect(ToolBreakpoint.fromWidth(599), equals(ToolBreakpoint.medium));
      expect(ToolBreakpoint.fromWidth(600), equals(ToolBreakpoint.expanded));
      expect(ToolBreakpoint.fromWidth(1023), equals(ToolBreakpoint.expanded));
      expect(ToolBreakpoint.fromWidth(1024), equals(ToolBreakpoint.desktop));
    });

    testWidgets('handles zero width', (WidgetTester tester) async {
      expect(ToolBreakpoint.fromWidth(0), equals(ToolBreakpoint.compact));
    });

    testWidgets('handles very large width', (WidgetTester tester) async {
      expect(ToolBreakpoint.fromWidth(3840), equals(ToolBreakpoint.desktop));
    });

    testWidgets('handles negative width gracefully', (
      WidgetTester tester,
    ) async {
      expect(ToolBreakpoint.fromWidth(-100), equals(ToolBreakpoint.compact));
    });

    testWidgets('handles fractional widths', (WidgetTester tester) async {
      expect(ToolBreakpoint.fromWidth(374.9), equals(ToolBreakpoint.compact));
      expect(ToolBreakpoint.fromWidth(375.1), equals(ToolBreakpoint.medium));
      expect(ToolBreakpoint.fromWidth(599.5), equals(ToolBreakpoint.medium));
      expect(ToolBreakpoint.fromWidth(600.5), equals(ToolBreakpoint.expanded));
    });
  });

  group('Responsive Layout Integration', () {
    testWidgets('ToolSpacing works in actual widget tree', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: Builder(
              builder: (context) {
                return Column(
                  children: [
                    SizedBox(height: ToolSpacing.sm(context)),
                    SizedBox(height: ToolSpacing.md(context)),
                    SizedBox(height: ToolSpacing.lg(context)),
                    SizedBox(height: ToolSpacing.xl(context)),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.byType(Column), findsOneWidget);
      expect(find.byType(SizedBox), findsNWidgets(4));
    });

    testWidgets('ToolTouchTarget works in actual widget tree', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: Builder(
              builder: (context) {
                return Row(
                  children: [
                    SizedBox(
                      width: ToolTouchTarget.small(context),
                      height: ToolTouchTarget.small(context),
                    ),
                    SizedBox(
                      width: ToolTouchTarget.medium(context),
                      height: ToolTouchTarget.medium(context),
                    ),
                    SizedBox(
                      width: ToolTouchTarget.large(context),
                      height: ToolTouchTarget.large(context),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.byType(Row), findsOneWidget);
      expect(find.byType(SizedBox), findsNWidgets(3));
    });

    testWidgets('spacing values change when widget rebuilds with new width', (
      WidgetTester tester,
    ) async {
      double? currentSpacing;
      double currentWidth = 400;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(currentWidth, 600)),
            child: Builder(
              builder: (context) {
                currentSpacing = ToolSpacing.lg(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(currentSpacing, equals(16));

      currentWidth = 800;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(currentWidth, 600)),
            child: Builder(
              builder: (context) {
                currentSpacing = ToolSpacing.lg(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(currentSpacing, equals(20));
    });
  });

  group('MonoPulse Theme Integration', () {
    testWidgets('spacing values align with MonoPulseSpacing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: Builder(
              builder: (context) {
                expect(ToolSpacing.sm(context), equals(8));
                expect(ToolSpacing.lg(context), equals(20));
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('touch targets use appropriate sizes for theme', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: Builder(
              builder: (context) {
                final largeTarget = ToolTouchTarget.large(context);
                expect(largeTarget, equals(64));
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });
  });

  group('Breakpoint Detection from Context', () {
    testWidgets('ToolBreakpoint.of returns correct value for compact', (
      WidgetTester tester,
    ) async {
      ToolBreakpoint? breakpoint;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(300, 600)),
            child: Builder(
              builder: (context) {
                breakpoint = ToolBreakpoint.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(breakpoint, equals(ToolBreakpoint.compact));
    });

    testWidgets('ToolBreakpoint.of returns correct value for medium', (
      WidgetTester tester,
    ) async {
      ToolBreakpoint? breakpoint;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(500, 600)),
            child: Builder(
              builder: (context) {
                breakpoint = ToolBreakpoint.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(breakpoint, equals(ToolBreakpoint.medium));
    });

    testWidgets('ToolBreakpoint.of returns correct value for expanded', (
      WidgetTester tester,
    ) async {
      ToolBreakpoint? breakpoint;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: Builder(
              builder: (context) {
                breakpoint = ToolBreakpoint.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(breakpoint, equals(ToolBreakpoint.expanded));
    });

    testWidgets('ToolBreakpoint.of returns correct value for desktop', (
      WidgetTester tester,
    ) async {
      ToolBreakpoint? breakpoint;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1200, 800)),
            child: Builder(
              builder: (context) {
                breakpoint = ToolBreakpoint.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(breakpoint, equals(ToolBreakpoint.desktop));
    });
  });

  group('Real-world Usage Patterns', () {
    testWidgets('can be used for button padding', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: Builder(
              builder: (context) {
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: ToolSpacing.lg(context),
                      vertical: ToolSpacing.md(context),
                    ),
                  ),
                  onPressed: () {},
                  child: const Text('Button'),
                );
              },
            ),
          ),
        ),
      );

      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('Button'), findsOneWidget);
    });

    testWidgets('can be used for container margins', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: Builder(
              builder: (context) {
                return Container(
                  margin: EdgeInsets.all(ToolSpacing.xl(context)),
                  child: const Text('Content'),
                );
              },
            ),
          ),
        ),
      );

      expect(find.byType(Container), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('can be used for touch target sizing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: Builder(
              builder: (context) {
                return GestureDetector(
                  onTap: () {},
                  child: SizedBox(
                    width: ToolTouchTarget.large(context),
                    height: ToolTouchTarget.large(context),
                    child: const Icon(Icons.add),
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.byType(GestureDetector), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('can be used for list item spacing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: Builder(
              builder: (context) {
                return ListView(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: ToolSpacing.lg(context),
                        vertical: ToolSpacing.sm(context),
                      ),
                      title: const Text('Item 1'),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: ToolSpacing.lg(context),
                        vertical: ToolSpacing.sm(context),
                      ),
                      title: const Text('Item 2'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
    });
  });
}
