import 'package:flowgroove/models/section_span.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SectionSpan', () {
    test('toJson/fromJson round trip preserves equality', () {
      const span = SectionSpan(sectionId: 'verse', startBar: 2, bars: 8);

      final restored = SectionSpan.fromJson(span.toJson());

      expect(restored, equals(span));
    });

    test('fromJson handles missing fields with defaults', () {
      final span = SectionSpan.fromJson(<String, dynamic>{});

      expect(span.sectionId, equals(''));
      expect(span.startBar, equals(0));
      expect(span.bars, equals(0));
    });

    test('equal spans have equal hashCode', () {
      final span1 = SectionSpan(sectionId: 'verse', startBar: 2, bars: 8);
      final span2 = SectionSpan(sectionId: 'verse', startBar: 2, bars: 8);

      expect(span1, equals(span2));
      expect(span1.hashCode, equals(span2.hashCode));
    });
  });
}
