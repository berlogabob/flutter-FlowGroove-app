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

String laneLabel(DrumLane lane) {
  return switch (lane) {
    DrumLane.kick => 'Kick',
    DrumLane.snare => 'Snare',
    DrumLane.hatClosed => 'Closed hat',
    DrumLane.hatOpen => 'Open hat',
    DrumLane.tomHigh => 'High tom',
    DrumLane.tomMid => 'Mid tom',
    DrumLane.tomFloor => 'Floor tom',
    DrumLane.crash => 'Crash',
    DrumLane.ride => 'Ride',
  };
}

String lanePadLabel(DrumLane lane) {
  return switch (lane) {
    DrumLane.kick => 'Kick',
    DrumLane.snare => 'Snare',
    DrumLane.hatClosed => 'C-hat',
    DrumLane.hatOpen => 'O-hat',
    DrumLane.tomHigh => 'Hi',
    DrumLane.tomMid => 'Mid',
    DrumLane.tomFloor => 'Floor',
    DrumLane.crash => 'Crash',
    DrumLane.ride => 'Ride',
  };
}
