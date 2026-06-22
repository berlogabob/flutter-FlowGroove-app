/// Beat mode for individual beat customization
enum BeatMode {
  normal, // Default (normal sound)
  accent, // Plays the dedicated accent (cyan) pitch
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

/// Single source of truth for the pitch of one metronome cell.
///
/// The metronome exposes three independent pitch tiers, all resolved here so
/// every playback path (PCM timeline, native Android, and the sample-accurate
/// `PcmClickRenderer` engine) agrees on the frequency for a given cell:
///
///  - [primaryFrequency]: the main beat — the first subdivision of each beat
///    (the "downbeat"). Used only when [accentEnabled] is true.
///  - [subdivisionFrequency]: every other subdivision in the beat.
///  - [accentFrequency]: cells explicitly marked [BeatMode.accent] in the beat
///    map (rendered cyan in the UI). Takes precedence over position.
double resolveClickFrequency({
  required BeatMode mode,
  required bool isMainBeat,
  required bool accentEnabled,
  required double primaryFrequency,
  required double subdivisionFrequency,
  required double accentFrequency,
}) {
  if (mode == BeatMode.accent) return accentFrequency;
  if (isMainBeat && accentEnabled) return primaryFrequency;
  return subdivisionFrequency;
}
