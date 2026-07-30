// Key round-tripping through the add/edit song form.
//
// The bug this pins: SongFormData._parseKey used to split blindly on key[0] +
// key.substring(1), so "Abm" became base "A" + modifier "bm" — a value absent
// from the picker's keyModifiers list. DropdownButton asserts that its `value`
// matches exactly one item, so opening the edit form for any song with an
// accidental-and-minor key CRASHED. Three such songs existed in a real library
// (Fire Hive Abm, Wild World C#m, Destroy Them With Lazers Bbm); the picker
// itself cannot produce them, but ChordPro and AI import can.
//
// The second bug: _buildKey lowercased minors ("dm"), making the form the only
// writer of a spelling that functions/src/mcp/song_schema.js then rejected as
// invalid — the app's own output failing its own server-side validator.

import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/screens/songs/components/bpm_selector.dart';
import 'package:flowgroove/screens/songs/models/song_form_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The picker's modifier slot. Any value _parseKey produces must be in here or
/// DropdownButton will assert at build time.
const _pickerModifiers = ['', '#', 'b', 'm', '#m', 'bm'];
const _pickerBases = ['', 'C', 'D', 'E', 'F', 'G', 'A', 'B'];

final _epoch = DateTime.utc(2026, 1, 1);

SongFormData _formFor(String? originalKey, {String? ourKey}) {
  return SongFormData.fromSong(
    Song(
      id: 's1',
      title: 'T',
      artist: 'A',
      createdAt: _epoch,
      updatedAt: _epoch,
      originalKey: originalKey,
      ourKey: ourKey,
    ),
  );
}

Song _saved(SongFormData form) => form.toSong(id: 's1', createdAt: _epoch);

void main() {
  group('key round trip', () {
    // Every one of these must survive form -> string -> form unchanged.
    const lossless = {
      'C': 'C',
      'F#': 'F#',
      'Bb': 'Bb',
      'Am': 'Am',
      'C#m': 'C#m',
      'Abm': 'Abm',
      'Bbm': 'Bbm',
    };

    lossless.forEach((input, expected) {
      test('"$input" round-trips to "$expected"', () {
        final form = _formFor(input);
        expect(form.originalKey, expected);
      });
    });

    // Casing normalises to the uppercase-root convention used by the MCP schema,
    // the CSV schema and the filter chips.
    const normalised = {
      'dm': 'Dm',
      'em': 'Em',
      'c': 'C',
      'f#': 'F#',
      'ABM': 'Abm',
      'c#M': 'C#m',
    };

    normalised.forEach((input, expected) {
      test('"$input" normalises to "$expected"', () {
        expect(_formFor(input).originalKey, expected);
      });
    });
  });

  group('parsed values are always renderable by the picker', () {
    // This is the crash guard. If _parseKey ever emits a base or modifier the
    // dropdown has no item for, the edit form throws.
    const realWorldKeys = [
      'C', 'D', 'E', 'F', 'G', 'A', 'B',
      'F#', 'C#', 'Ab', 'Bb', 'Gb',
      'Am', 'Em', 'dm', 'em',
      'C#m', 'Abm', 'Bbm',
    ];

    for (final key in realWorldKeys) {
      test('"$key" yields picker-safe base and modifier', () {
        final form = _formFor(key, ourKey: key);
        expect(
          _pickerBases,
          contains(form.originalKeyBase),
          reason: 'base "${form.originalKeyBase}" from "$key" has no dropdown item',
        );
        expect(
          _pickerModifiers,
          contains(form.originalKeyModifier),
          reason:
              'modifier "${form.originalKeyModifier}" from "$key" has no dropdown item',
        );
        expect(_pickerModifiers, contains(form.ourKeyModifier));
      });
    }
  });

  group('unparseable input clears the field instead of crashing', () {
    for (final junk in ['Cmaj7', 'C##', 'H', 'x', '???', 'Am7', 'C/G']) {
      test('"$junk" clears rather than producing a junk modifier', () {
        final form = _formFor(junk);
        expect(_pickerBases, contains(form.originalKeyBase));
        expect(_pickerModifiers, contains(form.originalKeyModifier));
        expect(form.originalKey, '');
      });
    }

    test('null and empty stay empty', () {
      expect(_formFor(null).originalKey, '');
      expect(_formFor('').originalKey, '');
      expect(_formFor('   ').originalKey, '');
    });
  });

  group('toSong', () {
    test('an unset key is written as null, not an empty string', () {
      final song = _saved(_formFor(null));
      expect(song.originalKey, isNull);
      expect(song.ourKey, isNull);
    });

    test('a minor key is persisted uppercase', () {
      final song = _saved(_formFor('dm', ourKey: 'em'));
      expect(song.originalKey, 'Dm');
      expect(song.ourKey, 'Em');
    });

    test('an accidental-and-minor key survives a save', () {
      final song = _saved(_formFor('Abm'));
      expect(song.originalKey, 'Abm');
    });
  });

  group('the picker actually builds (the crash reproducer)', () {
    // The unit tests above prove _parseKey emits picker-safe values. This proves
    // the widget itself no longer asserts: DropdownButton requires `value` to
    // match exactly one item, and 'bm' / '#m' had no item before the fix.
    Future<void> pumpWith(WidgetTester tester, String modifier) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KeyBpmGrid(
              originalBase: 'A',
              originalModifier: modifier,
              ourBase: 'B',
              ourModifier: modifier,
              originalBpmController: TextEditingController(),
              ourBpmController: TextEditingController(),
              onOriginalKeyChanged: _noopKey,
              onOurKeyChanged: _noopKey,
            ),
          ),
        ),
      );
    }

    for (final modifier in ['', '#', 'b', 'm', '#m', 'bm']) {
      testWidgets('builds with modifier "$modifier"', (tester) async {
        await pumpWith(tester, modifier);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('survives a modifier with no matching item', (tester) async {
      // Defensive: an import could still deliver something unexpected. The
      // dropdown must degrade to unset rather than take the screen down.
      await pumpWith(tester, 'totally-invalid');
      expect(tester.takeException(), isNull);
    });
  });

  group('KeyBpmGrid defaults', () {
    test('modifier list covers every combination _parseKey can emit', () {
      // Guards against someone trimming the list back to ['', '#', 'b', 'm'],
      // which is what made the dropdown assert in the first place.
      final grid = KeyBpmGrid(
        originalBase: '',
        originalModifier: '',
        ourBase: '',
        ourModifier: '',
        originalBpmController: TextEditingController(),
        ourBpmController: TextEditingController(),
        onOriginalKeyChanged: _noopKey,
        onOurKeyChanged: _noopKey,
      );
      expect(grid.keyModifiers, containsAll(['#m', 'bm']));
      expect(grid.keyBases, contains(''));
    });
  });
}

void _noopKey(String _, String __) {}
