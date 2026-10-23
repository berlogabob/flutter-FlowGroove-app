import json
R = "Match surrounding style. Change only the allowed files. No new dependencies. "
T = []
def add(id, ex, title, files, prompt, verify, after=(), timeout=300, suite=False, must=None):
    t = dict(id=id, executor=ex, finding="CONSOLE", title=title, files=files, prompt=R + prompt,
             verify=verify, after=list(after), status="pending", timeout=timeout, suite=suite)
    if must: t["must_contain"] = must
    T.append(t)

add("C01","pi","MidiTrackMeta.programOverride",["lib/models/midi_song.dart"],
"In class MidiTrackMeta add optional field `final int? programOverride;` (ctor named param, default null). fromJson reads json['programOverride'] as num? -> int, clamped 0..127, null when absent. toJson emits 'programOverride' only when non-null. copyWith gets `Object? programOverride = _unchanged` using the same identical(...) pattern as roleOverride. Add getter `int get effectiveProgram => programOverride ?? program;`.",
"dart analyze lib/models/midi_song.dart", must=["programOverride","effectiveProgram"])
add("C02","pi","programOverride test",["test/models/midi_track_meta_test.dart","lib/models/midi_song.dart"],
"Create test/models/midi_track_meta_test.dart (package:flutter_test): toJson/fromJson round trip keeps programOverride 19; fromJson of a map without the key gives null and omits the key in toJson; effectiveProgram is override when set else program; copyWith(programOverride: null) clears it; fromJson clamps 200 to 127.",
"flutter test test/models/midi_track_meta_test.dart",["C01"])
add("C03","codex","meta builder keeps programOverride",["lib/services/audio/midi/midi_song_meta_builder.dart","test/services/audio/midi/meta_builder_program_override_test.dart"],
"In buildMidiSongMeta carry `programOverride: saved?.programOverride` into the rebuilt MidiTrackMeta (same place roleOverride is carried). Add test file test/services/audio/midi/meta_builder_program_override_test.dart: build a MidiSongData with one pitched track, call buildMidiSongMeta, then again with previous: the first result with tracks[0].copyWith(programOverride: 19); assert the second result keeps 19.",
"flutter test test/services/audio/midi/meta_builder_program_override_test.dart",["C01"])
add("C04","codex","voice timbres by GM program",["lib/services/audio/midi/voice_synth.dart","test/services/audio/midi/voice_synth_program_test.dart"],
"Add optional named param `int? program` to addVoice (default null). When null or outside the ranges below, output must stay bit-identical to today. Ranges (GM zero-based): 16..23 organ = harmonics 1..6 equal-ish weights 1/n with NO decay and 0.01 s attack; 56..63 brass = harmonics 1..8 weights 1/n with 0.04 s attack; 88..95 pad = existing bowed timbre but 0.15 s attack; 8..15 mallet/bell = partials 1 and 2.76 with exp(-t*6) decay. Only apply when role is not drums. Add test file test/services/audio/midi/voice_synth_program_test.dart: same pitch/velocity/role keys, program 19 vs program null render different buffers; program null equals program 0 render (bit-identical); all outputs finite and non-silent.",
"flutter test test/services/audio/midi/voice_synth_program_test.dart",["C01"], timeout=600, must=["int? program"])
add("C05","codex","renderer and stems pass program",["lib/services/audio/midi/midi_track_renderer.dart","lib/services/audio/midi/backing_stem_builder.dart","test/services/audio/midi/render_program_test.dart"],
"renderMidiTrack gets optional `int? program` and forwards it to addVoice. In backing_stem_builder the per-note render call passes `program: setting.effectiveProgram` (setting is the MidiTrackMeta). Add test/services/audio/midi/render_program_test.dart: renderMidiTrack of one note with role keys, program 19 vs 0 gives different PCM; buildBackingStems for a song whose only track has programOverride 19 differs from the same song with no override.",
"flutter test test/services/audio/midi/render_program_test.dart",["C04","C03"], timeout=900)
add("C06","codex","one stem per track option",["lib/services/audio/midi/backing_stem_builder.dart","test/services/audio/midi/per_track_stems_test.dart"],
"Add optional named param `bool perTrack = false` to buildBackingStems. Default behaviour (4 role groups, muted tracks skipped) must not change. When perTrack is true: each non-empty track gets its own stem named by its MidiTrackMeta.name (if two names collide append ' 2', ' 3'); muted tracks are NOT skipped (mute is applied live later) and the per-track volume is still applied. Add test/services/audio/midi/per_track_stems_test.dart: 3 tracks (drums ch 9, bass, keys) -> perTrack gives 3 stems with distinct names, default gives groups named Drums/Bass/Harmony; a track with mute=true is present in perTrack and absent in default.",
"flutter test test/services/audio/midi/per_track_stems_test.dart",["C05"], timeout=900)
add("C07","codex","transport uses per-track stems + initial mutes",["lib/providers/data/backing_transport_provider.dart"],
"In the MIDI-song load path (the buildBackingStems call) pass perTrack: true. After the engine load and before _applyGains, seed the muted set from the entry's meta: for each name/index in stems that corresponds to a MidiTrackMeta with mute == true add its stem name to _muted (stems are in meta.tracks order filtered to tracks that have notes; match by name). Do not touch the drum-pattern load path. Keep existing tests passing.",
"flutter test test/providers",["C06"], timeout=1200, suite=True)
json.dump(dict(branch="feat/console", tasks=T), open("docs/plans/console/tasks.json","w"), indent=1)
print(len(T), "tasks")
