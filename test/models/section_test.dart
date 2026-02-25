import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/models/section.dart';

void main() {
  group('Section', () {
    test('fromJson/toJson serialization', () {
      final section = Section(
        id: 'test-id',
        name: 'Verse',
        notes: 'Am C G',
        duration: 2,
        colorValue: 0xFFFF5350,
      );

      final json = section.toJson();
      final restored = Section.fromJson(json);

      expect(restored.id, equals(section.id));
      expect(restored.name, equals(section.name));
      expect(restored.notes, equals(section.notes));
      expect(restored.duration, equals(section.duration));
      expect(restored.colorValue, equals(section.colorValue));
    });

    test('fromJson handles missing optional fields', () {
      final json = <String, dynamic>{'id': 'test-id', 'name': 'Chorus'};

      final section = Section.fromJson(json);

      expect(section.id, equals('test-id'));
      expect(section.name, equals('Chorus'));
      expect(section.notes, equals(''));
      expect(section.duration, equals(1));
      expect(section.colorValue, isNull);
    });

    test('copyWith creates new instance', () {
      final original = Section(id: '1', name: 'Intro');
      final copy = original.copyWith(name: 'Verse', duration: 2);

      expect(copy.id, equals(original.id));
      expect(copy.name, equals('Verse'));
      expect(copy.duration, equals(2));
      expect(original.name, equals('Intro')); // Original unchanged
    });

    test('templates list contains expected values', () {
      expect(Section.templates, contains('Intro'));
      expect(Section.templates, contains('Verse'));
      expect(Section.templates, contains('Chorus'));
      expect(Section.templates, contains('Bridge'));
      expect(Section.templates, contains('Pre-Chorus'));
      expect(Section.templates, contains('Outro'));
      expect(Section.templates, contains('Instrumental'));
      expect(Section.templates, contains('Solo'));
      expect(Section.templates, contains('Pause'));
    });

    test('color returns custom color when set', () {
      const customColor = Color(0xFFFF5350);
      final section = Section(
        id: '1',
        name: 'Verse',
        colorValue: customColor.value,
      );

      expect(section.color, equals(customColor));
    });

    test('color returns generated color when custom not set', () {
      final section = Section(id: '1', name: 'Test Section');

      expect(section.color, isNotNull);
      expect(section.color, isA<Color>());
    });

    test('contrastingTextColor returns appropriate color', () {
      // Dark color should return white text
      final darkSection = Section(
        id: '1',
        name: 'Dark',
        colorValue: const Color(0xFF000000).value,
      );
      expect(darkSection.contrastingTextColor, equals(Colors.white));

      // Light color should return black text
      final lightSection = Section(
        id: '2',
        name: 'Light',
        colorValue: const Color(0xFFFFFFFF).value,
      );
      expect(lightSection.contrastingTextColor, equals(Colors.black));
    });

    test('colorIndex is consistent for same name', () {
      final section1 = Section(id: '1', name: 'Verse');
      final section2 = Section(id: '2', name: 'Verse');

      expect(section1.colorIndex, equals(section2.colorIndex));
    });

    test('toJson includes colorValue only when set', () {
      final sectionWithColor = Section(
        id: '1',
        name: 'Verse',
        colorValue: 0xFFFF5350,
      );
      final sectionWithoutColor = Section(id: '2', name: 'Verse');

      final jsonWithColor = sectionWithColor.toJson();
      final jsonWithoutColor = sectionWithoutColor.toJson();

      expect(jsonWithColor.containsKey('colorValue'), isTrue);
      expect(jsonWithoutColor.containsKey('colorValue'), isFalse);
    });
  });
}
