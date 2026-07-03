import 'package:flowgroove/services/matching/fuzzy_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'partial autocomplete queries pass the 0.6 suggestion cutoff (#75/#78)',
    () {
      final cases = <(String, String)>[
        ('hit the li', 'Hit the Lights'),
        ('hit the li', 'Hit the Limit'),
        ('hit the road ja', 'Hit the Road Jack'),
        ('wonderw', 'Wonderwall'),
      ];
      for (final (input, target) in cases) {
        final m = FuzzyMatcher.calculateMatchScore(
          inputTitle: input,
          inputArtist: '',
          targetTitle: target,
          targetArtist: 'Some Artist',
        );
        expect(
          m.overall,
          greaterThanOrEqualTo(0.6),
          reason: '"$input" vs "$target" must survive the suggestion filter',
        );
      }
      // And junk must stay filtered out:
      final junk = FuzzyMatcher.calculateMatchScore(
        inputTitle: 'hit the li',
        inputArtist: '',
        targetTitle: 'Надежда на лучшее',
        targetArtist: 'Кино',
      );
      expect(junk.overall, lessThan(0.6));
    },
  );
}
