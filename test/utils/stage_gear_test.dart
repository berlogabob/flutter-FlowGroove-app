import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/utils/stage_gear.dart';

void main() {
  const categories = {
    'Drums & percussion',
    'Guitars & bass',
    'Keys',
    'Strings, brass & wind',
    'Vocals & mics',
    'Amps & cabs',
    'Monitoring & PA',
    'DJ & electronic',
    'Stage & misc',
  };
  const icons = {
    '🥁',
    '🪘',
    '🎸',
    '🎻',
    '🎺',
    '🎷',
    '🪈',
    '🎹',
    '🎤',
    '🔊',
    '🎚️',
    '🎛️',
    '🔌',
    '💡',
    '🪑',
    '🎬',
  };

  test('catalog ids, names, and icons are valid', () {
    final ids = StageGear.catalog.map((entry) => entry.id).toList();

    expect(ids.toSet(), hasLength(ids.length));
    for (final entry in StageGear.catalog) {
      expect(entry.name, isNotEmpty);
      expect(entry.icon, isNotEmpty);
      expect(icons, contains(entry.icon));
    }
  });

  test('catalog only uses allowed categories', () {
    for (final entry in StageGear.catalog) {
      expect(categories, contains(entry.category));
    }
  });

  test('search finds bass gear', () {
    final ids = StageGear.search('bass').map((entry) => entry.id);

    expect(ids, containsAll(['bass_amp', 'bass_guitar']));
  });

  test('empty search returns the whole catalog', () {
    expect(StageGear.search(''), same(StageGear.catalog));
  });

  test('search is case-insensitive and ranks name prefixes first', () {
    final lower = StageGear.search('amp');
    final upper = StageGear.search('  AMP  ');

    expect(upper, equals(lower));
    expect(lower.first.id, 'amp_head');
    var passedPrefixes = false;
    for (final entry in lower) {
      final isPrefix = entry.name.toLowerCase().startsWith('amp');
      if (!isPrefix) passedPrefixes = true;
      expect(isPrefix && passedPrefixes, isFalse);
    }
  });

  test('byId returns null for an unknown id', () {
    expect(StageGear.byId('unknown_gear'), isNull);
  });

  test('iconFor resolves names and falls back by kind', () {
    expect(StageGear.iconFor('Drum kit'), '🥁');
    expect(StageGear.iconFor('some random thing'), '🔊');
    expect(StageGear.iconFor('anything', kind: 'member'), '🧑');
  });

  test('brandsFor returns configured and empty brand lists', () {
    expect(StageGear.brandsFor('Amps & cabs'), contains('Orange'));
    expect(StageGear.brandsFor('Stage & misc'), isEmpty);
  });

  test('role suggestions are valid and de-duplicated', () {
    final ids = StageGear.suggestedFor(['drummer', 'bassist']);

    expect(ids, containsAll(['drum_kit', 'bass_amp']));
    expect(ids.toSet(), hasLength(ids.length));
    for (final id in ids) {
      expect(StageGear.byId(id), isNotNull);
    }
  });

  test('empty role suggestions include the always-on tail', () {
    expect(
      StageGear.suggestedFor([]),
      equals(['monitor_wedge', 'power_strip']),
    );
  });
}
