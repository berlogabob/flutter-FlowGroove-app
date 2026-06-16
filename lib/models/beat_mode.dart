/// Beat mode for individual beat customization
enum BeatMode {
  normal, // Default (normal sound)
  accent, // +300 Hz
  silent, // No sound, visual only
}

extension BeatModeExtension on BeatMode {
  /// Get next mode in cycle (normal → accent → silent → normal)
  BeatMode next() {
    switch (this) {
      case BeatMode.normal:
        return BeatMode.accent;
      case BeatMode.accent:
        return BeatMode.silent;
      case BeatMode.silent:
        return BeatMode.normal;
    }
  }
}
