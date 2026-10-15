class MidiHit {
  const MidiHit({required this.step, required this.note, required this.vel});

  factory MidiHit.fromJson(Map<String, dynamic> json) => MidiHit(
    step: (json['step'] as num?)?.toInt() ?? 0,
    note: (json['note'] as num?)?.toInt() ?? 0,
    vel: (json['vel'] as num?)?.toInt() ?? 0,
  );

  final int step;
  final int note;
  final int vel;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'step': step,
    'note': note,
    'vel': vel,
  };
}

class MidiPattern {
  MidiPattern({
    required this.name,
    required this.bars,
    required this.beatsPerBar,
    required this.stepsPerBeat,
    required this.hits,
  });

  factory MidiPattern.fromJson(Map<String, dynamic> json) => MidiPattern(
    name: json['name'] as String? ?? '',
    bars: (json['bars'] as num?)?.toInt() ?? 1,
    beatsPerBar: (json['beatsPerBar'] as num?)?.toInt() ?? 4,
    stepsPerBeat: (json['stepsPerBeat'] as num?)?.toInt() ?? 4,
    hits:
        (json['hits'] as List<dynamic>?)
            ?.map((hit) => MidiHit.fromJson(hit as Map<String, dynamic>))
            .toList() ??
        <MidiHit>[],
  );

  final String name;
  int bars;
  int beatsPerBar;
  int stepsPerBeat;
  List<MidiHit> hits;

  int get totalSteps => bars * beatsPerBar * stepsPerBeat;

  MidiPattern withName(String name) => MidiPattern(
    name: name,
    bars: bars,
    beatsPerBar: beatsPerBar,
    stepsPerBeat: stepsPerBeat,
    hits: List<MidiHit>.of(hits),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'bars': bars,
    'beatsPerBar': beatsPerBar,
    'stepsPerBeat': stepsPerBeat,
    'hits': hits.map((hit) => hit.toJson()).toList(),
  };
}
