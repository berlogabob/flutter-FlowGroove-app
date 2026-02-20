/// Subdivision types for metronome
enum SubdivisionType {
  /// Quarter notes (1 beat)
  quarter,
  
  /// Eighth notes (1/2 beat)
  eighth,
  
  /// Triplets (1/3 beat)
  triplet,
  
  /// Sixteenth notes (1/4 beat)
  sixteenth,
}

/// Extension to get subdivision multiplier
extension SubdivisionMultiplier on SubdivisionType {
  /// How many subdivisions per beat
  int get multiplier {
    switch (this) {
      case SubdivisionType.quarter:
        return 1;
      case SubdivisionType.eighth:
        return 2;
      case SubdivisionType.triplet:
        return 3;
      case SubdivisionType.sixteenth:
        return 4;
    }
  }
  
  /// Display label
  String get label {
    switch (this) {
      case SubdivisionType.quarter:
        return '1/4';
      case SubdivisionType.eighth:
        return '1/8';
      case SubdivisionType.triplet:
        return '1/8T';
      case SubdivisionType.sixteenth:
        return '1/16';
    }
  }
}
