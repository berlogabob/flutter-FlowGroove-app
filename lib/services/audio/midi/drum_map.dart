enum DrumLane {
  kick,
  snare,
  hatClosed,
  hatOpen,
  tomHigh,
  tomMid,
  tomFloor,
  crash,
  ride,
}

DrumLane? laneForNote(int note) {
  return switch (note) {
    35 || 36 => DrumLane.kick,
    37 || 38 || 40 => DrumLane.snare,
    42 || 44 => DrumLane.hatClosed,
    46 => DrumLane.hatOpen,
    41 || 43 => DrumLane.tomFloor,
    45 || 47 => DrumLane.tomMid,
    48 || 50 => DrumLane.tomHigh,
    49 || 57 => DrumLane.crash,
    51 || 53 || 59 => DrumLane.ride,
    _ => null,
  };
}
