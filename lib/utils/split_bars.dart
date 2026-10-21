/// Splits bars evenly, assigning any remainder to the first parts.
List<int> splitBars(int bars, int parts) {
  if (parts <= 0 || bars <= 0) return [];

  final base = bars ~/ parts;
  final remainder = bars % parts;
  return List<int>.generate(parts, (i) => base + (i < remainder ? 1 : 0));
}
