/// Represents a musical time signature for metronome functionality.
/// 
/// Time signatures define the rhythmic structure of music by specifying
/// how many beats are in each measure and what note value gets one beat.
class TimeSignature {
  /// The number of beats per measure (numerator).
  /// Valid range: 2-12
  final int numerator;

  /// The note value that receives one beat (denominator).
  /// Valid values: 4 (quarter note) or 8 (eighth note)
  final int denominator;

  /// Creates a new [TimeSignature] with the specified numerator and denominator.
  const TimeSignature({
    required this.numerator,
    required this.denominator,
  });

  /// Checks if this time signature has valid values.
  /// 
  /// Returns true if:
  /// - numerator is between 2 and 12 (inclusive)
  /// - denominator is either 4 or 8
  bool get isValid =>
      numerator >= 2 &&
      numerator <= 12 &&
      (denominator == 4 || denominator == 8);

  /// Returns a display-friendly string representation.
  /// Format: "X / Y" (e.g., "4 / 4")
  String get displayName => '$numerator / $denominator';

  /// Common time signature: 4/4 (four quarter notes per measure).
  /// Also known as "common time" in musical notation.
  static const commonTime = TimeSignature(numerator: 4, denominator: 4);

  /// Cut time signature: 2/2 (two half notes per measure).
  /// Also known as "alla breve" or "cut common time".
  static const cutTime = TimeSignature(numerator: 2, denominator: 2);

  /// Waltz time signature: 3/4 (three quarter notes per measure).
  /// Characteristic of waltz music.
  static const waltz = TimeSignature(numerator: 3, denominator: 4);

  /// A collection of commonly used time signature presets.
  /// 
  /// Includes:
  /// - Simple duple: 2/4
  /// - Simple triple: 3/4
  /// - Simple quadruple: 4/4
  /// - Simple quintuple: 5/4
  /// - Compound duple: 6/8
  /// - Compound quadruple: 7/8
  /// - Compound triple: 9/8
  /// - Compound quadruple: 12/8
  static const presets = [
    TimeSignature(numerator: 2, denominator: 4),
    TimeSignature(numerator: 3, denominator: 4),
    TimeSignature(numerator: 4, denominator: 4),
    TimeSignature(numerator: 5, denominator: 4),
    TimeSignature(numerator: 6, denominator: 8),
    TimeSignature(numerator: 7, denominator: 8),
    TimeSignature(numerator: 9, denominator: 8),
    TimeSignature(numerator: 12, denominator: 8),
  ];

  /// Parses a time signature from a string in the format "X/Y".
  /// 
  /// Example:
  /// ```dart
  /// TimeSignature.fromString('4/4') // Returns TimeSignature(4, 4)
  /// TimeSignature.fromString('6 / 8') // Returns TimeSignature(6, 8)
  /// TimeSignature.fromString('invalid') // Returns null
  /// ```
  /// 
  /// Returns null if the string cannot be parsed or contains invalid values.
  static TimeSignature? fromString(String str) {
    try {
      final parts = str.split('/');
      if (parts.length != 2) return null;
      return TimeSignature(
        numerator: int.parse(parts[0].trim()),
        denominator: int.parse(parts[1].trim()),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() => displayName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeSignature &&
          runtimeType == other.runtimeType &&
          numerator == other.numerator &&
          denominator == other.denominator;

  @override
  int get hashCode => numerator.hashCode ^ denominator.hashCode;
}
