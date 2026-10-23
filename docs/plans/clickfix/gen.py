import json
R = "Match surrounding style. Change only the allowed files. No new dependencies. "
T = []
def add(id, title, files, prompt, verify, after=(), timeout=300, must=None):
    t = dict(id=id, executor="pi", finding="CLICKFIX", title=title, files=files, prompt=R + prompt,
             verify=verify, after=list(after), status="pending", timeout=timeout, suite=False)
    if must: t["must_contain"] = must
    T.append(t)

add("K01", "send bpm and ticksPerBar to native click engine", ["lib/providers/metronome_runtime_providers.dart"],
"In class MetronomePlaybackConfig, method toPlatformMap, add two entries to the returned map: `'bpm': bpm.toDouble(),` and `'ticksPerBar': _safeAccentBeats * _safeRegularBeats,`. Change nothing else.",
"dart analyze lib/providers/metronome_runtime_providers.dart", must=["'ticksPerBar'", "'bpm': bpm.toDouble()"])
add("K02", "toPlatformMap bpm test", ["test/providers/metronome_platform_map_test.dart", "lib/providers/metronome_runtime_providers.dart"],
"Create test/providers/metronome_platform_map_test.dart (package:flutter_test). Do NOT modify the lib file. Build `const MetronomePlaybackConfig(bpm: 97, accentBeats: 4, regularBeats: 2, beatModes: [], waveType: 'sine', volume: 0.5, accentEnabled: true, accentFrequency: 1000, beatFrequency: 800, accentBeatFrequency: 1200, hapticsEnabled: false)` and call toPlatformMap(initialTick: 0). Expect map['bpm'] == 97.0, map['ticksPerBar'] == 8, map['intervalMicros'] == config.interval.inMicroseconds. Import with package:flowgroove/providers/metronome_runtime_providers.dart.",
"flutter test test/providers/metronome_platform_map_test.dart", after=["K01"])
add("K03", "file tempo drives the metronome, render at metronome bpm", ["lib/providers/data/backing_transport_provider.dart"],
"In BackingTransportNotifier.attach, immediately before the final line `await _render(_beginRender());` add: `if (entry.midiSong?.useFileTempo == true) { ref.read(metronomeProvider.notifier).setBpm(entry.midiSong!.initialBpm.round()); }`. In _render replace the `final bpm = entry.midiSong?.useFileTempo == true ? song.initialBpm : metro.bpm.toDouble();` statement with `final bpm = metro.bpm.toDouble();`. Do not touch attachPattern or any other method.",
"dart analyze lib/providers/data/backing_transport_provider.dart", after=["K02"], must=["setBpm(entry.midiSong!.initialBpm.round())"])
add("K04", "file tempo sets metronome bpm test", ["test/providers/backing_transport_test.dart"],
"Add ONE new test right after the existing test 'uses mapped spans and file tempo when requested' (same indentation, uses the existing metro, engine, transport, entry(), sections). Test name: 'file tempo sets the metronome bpm and a normal song keeps it'. Body: `metro.tempo(90); await transport.attach(entry(fileTempo: true), sections); expect(container.read(metronomeProvider).bpm, 120); expect(engine.loads.last.renderBpm, 120); metro.tempo(90); await transport.attach(entry(), sections); expect(container.read(metronomeProvider).bpm, 90); expect(engine.loads.last.renderBpm, 90);`. Change nothing else.",
"flutter test test/providers/backing_transport_test.dart", after=["K03"], must=["file tempo sets the metronome bpm"])
json.dump(dict(branch="fix/click-bpm", tasks=T), open("docs/plans/clickfix/tasks.json","w"), indent=1)
print(len(T), "tasks")
