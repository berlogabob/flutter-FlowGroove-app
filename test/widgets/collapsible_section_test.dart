/// Tests for CollapsibleSection widget.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/screens/songs/components/collapsible_section.dart';

void main() {
  testWidgets('CollapsibleSection renders title and content', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollapsibleSection(
            title: 'Test Section',
            child: const Text('Test Content'),
          ),
        ),
      ),
    );

    // Verify title is shown
    expect(find.text('Test Section'), findsOneWidget);
    
    // Verify content is shown (expanded by default)
    expect(find.text('Test Content'), findsOneWidget);
  });

  testWidgets('CollapsibleSection can be collapsed', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollapsibleSection(
            title: 'Test Section',
            child: const Text('Test Content'),
          ),
        ),
      ),
    );

    // Tap header to collapse
    await tester.tap(find.text('Test Section'));
    await tester.pumpAndSettle();

    // Content should be hidden
    expect(find.text('Test Content'), findsNothing);
  });

  testWidgets('CollapsibleSection can be expanded again', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollapsibleSection(
            title: 'Test Section',
            child: const Text('Test Content'),
          ),
        ),
      ),
    );

    // Collapse
    await tester.tap(find.text('Test Section'));
    await tester.pumpAndSettle();
    expect(find.text('Test Content'), findsNothing);

    // Expand again
    await tester.tap(find.text('Test Section'));
    await tester.pumpAndSettle();

    // Content should be visible again
    expect(find.text('Test Content'), findsOneWidget);
  });

  testWidgets('CollapsibleSection with icon shows icon', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollapsibleSection(
            title: 'Test Section',
            icon: Icons.star,
            child: const Text('Test Content'),
          ),
        ),
      ),
    );

    // Verify icon is shown
    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  testWidgets('CollapsibleSection with action shows action', (WidgetTester tester) async {
    bool actionPressed = false;
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollapsibleSection(
            title: 'Test Section',
            action: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => actionPressed = true,
            ),
            child: const Text('Test Content'),
          ),
        ),
      ),
    );

    // Verify action button is shown
    expect(find.byIcon(Icons.add), findsOneWidget);

    // Tap action button
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify action was called
    expect(actionPressed, isTrue);
  });

  testWidgets('CollapsibleSection respects initiallyExpanded', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollapsibleSection(
            title: 'Test Section',
            initiallyExpanded: false,
            child: const Text('Test Content'),
          ),
        ),
      ),
    );

    // Content should be hidden initially
    expect(find.text('Test Content'), findsNothing);
  });
}
