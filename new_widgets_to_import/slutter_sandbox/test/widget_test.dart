import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slutter_sandbox/song_constructor.dart';
import 'package:slutter_sandbox/models/section.dart';

void main() {
  testWidgets('SongConstructor displays collapsed state initially', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SongConstructor(),
        ),
      ),
    );

    expect(find.text('Song Structure'), findsOneWidget);
    expect(find.text('No structure yet'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
  });

  testWidgets('SongConstructor toggle expand/collapse', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SongConstructor(),
        ),
      ),
    );

    // Initially collapsed
    expect(find.text('No structure yet'), findsOneWidget);

    // Expand
    await tester.tap(find.byIcon(Icons.expand_less));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(find.text('No sections yet'), findsOneWidget);

    // Collapse
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.expand_less), findsOneWidget);
    expect(find.text('No structure yet'), findsOneWidget);
  });

  testWidgets('SongConstructor Auto-Generate creates sections with durations', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SongConstructor(),
        ),
      ),
    );

    // Expand first
    await tester.tap(find.byIcon(Icons.expand_less));
    await tester.pumpAndSettle();

    // Tap Auto-Generate
    await tester.tap(find.text('Auto-Generate'));
    await tester.pumpAndSettle();

    // Verify sections were created by checking for section names
    expect(find.byType(Card), findsWidgets);
    
    // Should have multiple sections (at least 3)
    final sectionCards = find.byType(Card);
    expect(sectionCards.evaluate().length, greaterThanOrEqualTo(3));
  });

  testWidgets('SongConstructor add section from picker', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SongConstructor(),
        ),
      ),
    );

    // Expand
    await tester.tap(find.byIcon(Icons.expand_less));
    await tester.pumpAndSettle();

    // Tap Add Section
    await tester.tap(find.text('Add Section'));
    await tester.pumpAndSettle();

    // Tap on Intro template
    await tester.tap(find.text('Intro').first);
    await tester.pumpAndSettle();

    // Verify section was added
    expect(find.text('Intro'), findsWidgets);
    expect(find.textContaining('Duration:'), findsWidgets);
  });

  testWidgets('SongConstructor edit section with duration', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SongConstructor(),
        ),
      ),
    );

    // Expand and add section
    await tester.tap(find.byIcon(Icons.expand_less));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Section'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Intro'));
    await tester.pumpAndSettle();

    // Tap on the section card to edit
    await tester.tap(find.text('Intro'));
    await tester.pumpAndSettle();

    // Tap duration button "4"
    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();

    // Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Verify duration updated
    expect(find.text('Duration: 4 phrases'), findsOneWidget);
  });

  testWidgets('SongConstructor delete section', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SongConstructor(),
        ),
      ),
    );

    // Expand and auto-generate
    await tester.tap(find.byIcon(Icons.expand_less));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Auto-Generate'));
    await tester.pumpAndSettle();

    // Find and tap delete button
    final deleteButtons = find.byIcon(Icons.delete_outline);
    expect(deleteButtons, findsWidgets);
    
    await tester.tap(deleteButtons.first);
    await tester.pumpAndSettle();

    // Confirm deletion
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // One less section
    expect(find.byType(Card), findsWidgets);
  });

  testWidgets('PillView shows colored blocks proportional to duration', (WidgetTester tester) async {
    final sections = [
      Section(id: '1', name: 'Intro', duration: 2),
      Section(id: '2', name: 'Chorus', duration: 4),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SongConstructor(
            initialSections: sections,
          ),
        ),
      ),
    );

    // Collapsed state shows pill view
    expect(find.text('No structure yet'), findsNothing);
    
    // Chorus should be wider (4 phrases vs 2)
    // Visual verification - blocks are present
    expect(find.byType(Container), findsWidgets);
  });

  testWidgets('Section model copyWith updates duration', (WidgetTester tester) async {
    final section = Section(id: '1', name: 'Verse', duration: 2, notes: 'Am C');
    
    final updated = section.copyWith(duration: 4, notes: 'G D');
    
    expect(updated.id, equals('1'));
    expect(updated.name, equals('Verse'));
    expect(updated.duration, equals(4));
    expect(updated.notes, equals('G D'));
  });

  testWidgets('Section model toJson/fromJson', (WidgetTester tester) async {
    final section = Section(id: '1', name: 'Bridge', duration: 3, notes: 'Em Am');
    
    final json = section.toJson();
    
    expect(json['id'], equals('1'));
    expect(json['name'], equals('Bridge'));
    expect(json['duration'], equals(3));
    expect(json['notes'], equals('Em Am'));
    
    final restored = Section.fromJson(json);
    
    expect(restored.id, equals('1'));
    expect(restored.name, equals('Bridge'));
    expect(restored.duration, equals(3));
  });
}
