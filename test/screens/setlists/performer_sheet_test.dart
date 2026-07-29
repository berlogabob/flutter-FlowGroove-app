import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/event_kit.dart';
import 'package:flowgroove/screens/setlists/performer_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens the sheet and returns whatever it pops.
Future<PerformerSheetResult?> _open(
  WidgetTester tester, {
  List<String> selected = const [],
  EventKit kit = const EventKit(),
  List<BandMember> members = const [],
}) async {
  PerformerSheetResult? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showPerformerSheet(
                context: context,
                selected: selected,
                kit: kit,
                members: members,
                songNumber: 2,
                songTitle: 'Song Two',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('lists the band members and the guests already on the kit', (
    tester,
  ) async {
    await _open(
      tester,
      kit: const EventKit(
        people: [EventPerson(id: 'g1', name: 'Lena', role: 'Violin')],
      ),
      members: [
        BandMember(uid: 'u1', role: 'editor', displayName: 'Ivan',
            musicRoles: const ['pianist']),
      ],
    );

    expect(find.text('Who plays #2'), findsOneWidget);
    expect(find.text('Song Two'), findsOneWidget);
    expect(find.text('Lena'), findsOneWidget);
    expect(find.text('Ivan'), findsOneWidget);
  });

  testWidgets('returns the selection and materialises the member', (
    tester,
  ) async {
    PerformerSheetResult? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                captured = await showPerformerSheet(
                  context: context,
                  selected: const [],
                  kit: const EventKit(),
                  members: [
                    BandMember(uid: 'u1', role: 'editor', displayName: 'Ivan'),
                  ],
                  songNumber: 1,
                  songTitle: 'Song One',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('performer_u1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(captured!.performerIds, ['u1']);
    expect(captured!.allSongIds, isEmpty);
    // An assigned member is written into the roster so labels resolve later.
    expect(captured!.kit.people.single.id, 'u1');
    expect(captured!.kit.people.single.uid, 'u1');
  });

  testWidgets('a guest added with "plays every song" comes back in allSongIds', (
    tester,
  ) async {
    PerformerSheetResult? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                captured = await showPerformerSheet(
                  context: context,
                  selected: const [],
                  kit: const EventKit(),
                  members: const [],
                  songNumber: 1,
                  songTitle: 'Song One',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add person'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ivan');
    await tester.tap(find.text('Plays every song'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final person = captured!.kit.people.single;
    expect(person.name, 'Ivan');
    expect(person.uid, isNull, reason: 'a guest is not an app user yet');
    expect(captured!.performerIds, [person.id]);
    expect(captured!.allSongIds, {person.id});
  });
}
