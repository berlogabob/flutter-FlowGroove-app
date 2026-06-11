import 'song.dart';

enum SongDuplicateConfidence { exact, strong, possible }

class SongDuplicateCandidate {
  const SongDuplicateCandidate({
    required this.source,
    required this.match,
    required this.score,
    required this.confidence,
    this.variantMismatch = false,
  });

  final Song source;
  final Song match;
  final double score;
  final SongDuplicateConfidence confidence;
  final bool variantMismatch;

  String get pairKey {
    final ids = [source.id, match.id]..sort();
    return ids.join('__');
  }
}
