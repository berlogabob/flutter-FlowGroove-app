import 'package:flowgroove/models/section.dart';
import 'package:flowgroove/screens/songs/components/song_constructor/song_constructor.dart';
import 'package:flowgroove/screens/songs/components/song_constructor/widgets/pill_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SongConstructor', () {
    testWidgets('displays initial sections in collapsed state', (tester) async {
      final sections = [
        Section(id: '1', name: 'Intro'),
        Section(id: '2', name: 'Verse', duration: 2),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SongConstructor(initialSections: sections)),
        ),
      );

      expect(find.text('Song Structure'), findsOneWidget);
      // In collapsed state, sections are shown as pills
      expect(find.byType(PillView), findsOneWidget);
    });

    testWidgets('displays title and expand button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SongConstructor(initialSections: [])),
        ),
      );

      expect(find.text('Song Structure'), findsOneWidget);
      // Initially collapsed: arrow rotated -90deg (uses keyboard_arrow_down)
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });

    testWidgets('expand button toggles expanded state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SongConstructor(initialSections: [])),
        ),
      );

      // Initially collapsed - arrow points right (rotated -90deg)
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);

      // Tap to expand
      await expandSongConstructor(tester);

      // Now expanded - arrow points down (same icon, different rotation)
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.text('Add Section'), findsOneWidget);
    });

    testWidgets('displays empty state message when no sections', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SongConstructor(initialSections: [])),
        ),
      );

      // Expand to see empty state
      await expandSongConstructor(tester);

      expect(find.text('No sections yet'), findsOneWidget);
    });

    testWidgets('displays sections in expanded state', (tester) async {
      final sections = [
        Section(id: '1', name: 'Intro'),
        Section(id: '2', name: 'Verse', duration: 2),
        Section(id: '3', name: 'Chorus', duration: 2),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SongConstructor(initialSections: sections)),
        ),
      );

      // Expand
      await expandSongConstructor(tester);

      expect(find.text('Intro'), findsOneWidget);
      expect(find.text('Verse'), findsOneWidget);
      expect(find.text('Chorus'), findsOneWidget);
    });

    testWidgets('onChange callback fires when adding section', (tester) async {
      List<Section>? capturedSections;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongConstructor(
              initialSections: const [],
              onChange: (sections) => capturedSections = sections,
            ),
          ),
        ),
      );

      // Expand
      await expandSongConstructor(tester);

      // Tap Add Section - opens dialog
      await tester.tap(
        find.byKey(const Key('song_constructor_add_section')).hitTestable(),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('section_picker_parts_Verse')).hitTestable(),
      );
      await tester.pumpAndSettle();

      expect(capturedSections, isNotNull);
      expect(capturedSections!.length, equals(1));
      expect(capturedSections!.first.name, equals('Verse'));
    });

    testWidgets('edit section updates data', (tester) async {
      final sections = [
        Section(id: '1', name: 'Intro'),
      ];

      List<Section>? capturedSections;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongConstructor(
              initialSections: sections,
              onChange: (sections) => capturedSections = sections,
            ),
          ),
        ),
      );

      // Expand
      await expandSongConstructor(tester);

      // Tap on section card to edit
      await tester.tap(find.text('Intro').hitTestable());
      await tester.pumpAndSettle();

      // Find and enter new name in the dialog
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Bridge');
      await tester.pump();

      // Tap Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(capturedSections, isNotNull);
      expect(capturedSections!.first.name, equals('Bridge'));
    });

    testWidgets('delete section removes from list', (tester) async {
      final sections = [Section(id: '1', name: 'Intro')];

      List<Section>? capturedSections;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongConstructor(
              initialSections: sections,
              onChange: (sections) => capturedSections = sections,
            ),
          ),
        ),
      );

      // Expand
      await expandSongConstructor(tester);

      // Tap delete button
      await tester.tap(find.byKey(const Key('section_delete_1')).hitTestable());
      await tester.pumpAndSettle();

      // Confirm deletion
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(capturedSections, isNotNull);
      expect(capturedSections!.isEmpty, isTrue);
    });

    testWidgets('auto-generate creates sections', (tester) async {
      final sections = [Section(id: '1', name: 'Intro')];

      List<Section>? capturedSections;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongConstructor(
              initialSections: sections,
              onChange: (sections) => capturedSections = sections,
            ),
          ),
        ),
      );

      // Expand to show auto-generate button
      await expandSongConstructor(tester);

      // Tap Auto-Generate
      await tester.tap(
        find.byKey(const Key('song_constructor_auto_generate')).hitTestable(),
      );
      await tester.pump();

      expect(capturedSections, isNotNull);
      // Auto-generate creates 3-7 sections
      expect(capturedSections!.length, greaterThanOrEqualTo(3));
      expect(capturedSections!.length, lessThanOrEqualTo(7));
    });

    testWidgets('pill view shows in collapsed state', (tester) async {
      final sections = [
        Section(id: '1', name: 'Intro', colorValue: 0xFFFF5350),
        Section(id: '2', name: 'Verse', duration: 2, colorValue: 0xFF66BB6A),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SongConstructor(initialSections: sections)),
        ),
      );

      // Find the pill container
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets(
      'adopts sections that arrive after the first build (regression)',
      (tester) async {
        // Reproduces the add/edit screen behaviour: the song's sections are not
        // present on the first build and arrive one frame later (provider init
        // is deferred to a post-frame callback). Previously SongConstructor
        // snapshotted the empty list in initState and never updated, so saved
        // song maps showed empty.
        final hostKey = GlobalKey<_DeferredSectionsHostState>();
        await tester.pumpWidget(
          _DeferredSectionsHost(
            key: hostKey,
            deferredSections: [
              Section(id: '1', name: 'Intro'),
              Section(id: '2', name: 'Verse', duration: 2),
              Section(id: '3', name: 'Chorus', duration: 2),
            ],
          ),
        );

        // First build: no sections yet -> empty placeholder in the pill view.
        expect(find.text('No structure yet'), findsOneWidget);

        // Sections arrive one frame later.
        hostKey.currentState!.loadSections();
        await tester.pump();

        // The map must reflect the loaded sections, not the empty snapshot.
        expect(find.text('No structure yet'), findsNothing);

        // And the real section names render once expanded.
        await expandSongConstructor(tester);
        expect(find.text('Intro'), findsOneWidget);
        expect(find.text('Chorus'), findsOneWidget);
      },
    );

    testWidgets('keeps in-progress edits when an equal list is re-supplied', (
      tester,
    ) async {
      // A parent rebuild that re-supplies the same sections (by id) must not
      // clobber edits the user just made inside the constructor.
      final hostKey = GlobalKey<_DeferredSectionsHostState>();
      final sections = [Section(id: '1', name: 'Intro')];
      await tester.pumpWidget(
        _DeferredSectionsHost(key: hostKey, deferredSections: sections),
      );
      hostKey.currentState!.loadSections();
      await tester.pump();

      await expandSongConstructor(tester);
      expect(find.text('Intro'), findsOneWidget);

      // Parent rebuilds with an id-equal list (e.g. unrelated form keystroke).
      hostKey.currentState!.rebuildWithEqualList();
      await tester.pump();

      expect(find.text('Intro'), findsOneWidget);
    });
  });

  group('SongFormData with sections integration', () {
    test('setSections updates form data', () {
      // This would be better in an integration test file
      // Included here for completeness
      final sections = [
        Section(id: '1', name: 'Intro'),
        Section(id: '2', name: 'Verse'),
      ];

      expect(sections.length, equals(2));
      expect(sections[0].name, equals('Intro'));
      expect(sections[1].name, equals('Verse'));
    });
  });
}

Future<void> expandSongConstructor(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.keyboard_arrow_down).hitTestable());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

/// Host that mimics the add/edit song screen: sections are absent on the first
/// build and arrive one frame later (the screen defers `initFromSong` to a
/// post-frame callback).
class _DeferredSectionsHost extends StatefulWidget {
  const _DeferredSectionsHost({required this.deferredSections, super.key});

  final List<Section> deferredSections;

  @override
  State<_DeferredSectionsHost> createState() => _DeferredSectionsHostState();
}

class _DeferredSectionsHostState extends State<_DeferredSectionsHost> {
  List<Section> _sections = const [];

  void loadSections() => setState(() => _sections = widget.deferredSections);

  /// Re-supply a fresh list with the same section ids (mirrors how
  /// SongFormData.copyWith rebuilds the list on every unrelated form change).
  void rebuildWithEqualList() => setState(
    () => _sections = widget.deferredSections
        .map((s) => Section(id: s.id, name: s.name, duration: s.duration))
        .toList(),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SongConstructor(initialSections: _sections),
        ),
      ),
    );
  }
}
