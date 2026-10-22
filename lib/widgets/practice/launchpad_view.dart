import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/midi_song.dart';
import '../../models/section.dart';
import '../../models/section_span.dart';
import '../../models/song_lab.dart';
import '../../providers/data/backing_transport_provider.dart';
import '../../providers/data/metronome_provider.dart';
import '../../providers/data/midi_song_provider.dart';
import '../../services/audio/midi/midi_song_meta_builder.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/quantize.dart';
import 'instrument_strip.dart';
import 'section_card.dart';
import 'section_pad.dart';

/// A bounded practice surface: only the content scrolls, never the transport.
class LaunchpadView extends ConsumerStatefulWidget {
  const LaunchpadView({
    required this.entry,
    required this.sections,
    this.header,
    super.key,
  });

  final SongLabEntry entry;
  final List<Section> sections;
  final Widget? header;

  @override
  ConsumerState<LaunchpadView> createState() => _LaunchpadViewState();
}

class _LaunchpadViewState extends ConsumerState<LaunchpadView> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scheduleAttach();
  }

  @override
  void didUpdateWidget(LaunchpadView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry != widget.entry ||
        !identical(oldWidget.sections, widget.sections)) {
      _scheduleAttach();
    }
  }

  void _scheduleAttach() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) return;
    _error = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_attach());
    });
  }

  Future<void> _attach() async {
    final entry = widget.entry;
    final sections = widget.sections;
    try {
      final song = await ref.read(midiSongProvider(entry).future);
      if (!mounted || widget.entry != entry) return;
      final beats = ref.read(metronomeProvider).timeSignature.numerator;
      final bars = _songBars(song, beats) ?? 0;
      await ref
          .read(backingTransportProvider.notifier)
          .attach(
            entry,
            sections.isEmpty
                ? [Section(id: 'song', name: 'Song', duration: bars)]
                : sections,
          );
    } catch (error) {
      if (mounted && widget.entry == entry) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }
    final state = ref.watch(backingTransportProvider);
    final transport = ref.read(backingTransportProvider.notifier);
    final metro = ref.watch(metronomeProvider);
    final song = ref.watch(midiSongProvider(widget.entry)).value;
    final sections = {for (final s in widget.sections) s.id: s};
    final bars = _songBars(song, metro.timeSignature.numerator);
    final spans = state.spans.isEmpty
        ? [SectionSpan(sectionId: 'song', startBar: 0, bars: bars ?? 0)]
        : state.spans;
    final totalBars = spans.fold<int>(
      0,
      (end, span) => math.max(end, span.startBar + span.bars),
    );
    final bpm = widget.entry.midiSong?.useFileTempo == true
        ? song?.initialBpm ?? widget.entry.midiSong!.initialBpm
        : metro.bpm.toDouble();
    final names = <String>{};
    if (song != null) {
      final settings = buildMidiSongMeta(song, previous: widget.entry.midiSong);
      for (final track in settings.tracks) {
        if (track.mute || track.noteCount == 0) continue;
        names.add(switch (track.effectiveRole) {
          MidiRole.drums => 'Drums',
          MidiRole.bass => 'Bass',
          MidiRole.vocal || MidiRole.lead => 'Lead',
          _ => 'Harmony',
        });
      }
    }
    final current = sections[state.queuedId ?? state.playingId];
    final disabled = state.rendering || song == null || _error != null;

    void launch(String id) {
      if (!disabled) unawaited(transport.launch(id));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('launchpad-content'),
            padding: const EdgeInsets.all(MonoPulseSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.header != null) widget.header!,
                Text(
                  bars == null
                      ? 'Loading MIDI…'
                      : 'MIDI ${bpm.round()} BPM · $bars bars',
                  style: MonoPulseTypography.bodySmall,
                ),
                if (bars != null && bars < totalBars)
                  Text('Covers $bars of $totalBars bars'),
                if (state.rendering) Text('Rendering ${bpm.round()} BPM…'),
                if (_error != null) const Text('Unable to load MIDI backing'),
                const SizedBox(height: MonoPulseSpacing.sm),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns =
                        constraints.maxWidth >= 390 &&
                            MediaQuery.textScalerOf(context).scale(1) <= 1.3
                        ? 3
                        : 2;
                    final width =
                        (constraints.maxWidth -
                            MonoPulseSpacing.sm * (columns - 1)) /
                        columns;
                    return Wrap(
                      spacing: MonoPulseSpacing.sm,
                      runSpacing: MonoPulseSpacing.sm,
                      children: [
                        for (final span in spans)
                          SizedBox(
                            width: width,
                            child: IgnorePointer(
                              ignoring: disabled,
                              child: SectionPad(
                                name: sections[span.sectionId]?.name ?? 'Song',
                                bars: span.bars,
                                color:
                                    sections[span.sectionId]?.color ??
                                    MonoPulseColors.accentOrange,
                                state: state.padState(span.sectionId),
                                loop: state.loop,
                                onTap: () => launch(span.sectionId),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: MonoPulseSpacing.md),
                InstrumentStrip(
                  key: ObjectKey(widget.entry),
                  names: names.toList(),
                ),
                if (current != null)
                  SectionCard(section: current, queued: state.queuedId != null),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(MonoPulseSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Three equal columns that never move: Play/Stop, Loop, Quantize.
                Row(
                  key: const ValueKey('launchpad-transport'),
                  children: [
                    Expanded(
                      child: state.playingId == null && state.queuedId == null
                          ? FilledButton.icon(
                              style: _transportStyle,
                              onPressed: disabled
                                  ? null
                                  : () => launch(spans.first.sectionId),
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Play'),
                            )
                          : Tooltip(
                              message: 'Hold to stop at the next bar',
                              child: FilledButton.tonalIcon(
                                style: _transportStyle,
                                // Tap stops everything (click + backing); hold
                                // stops the backing at the next bar and leaves
                                // the click running.
                                onPressed: () {
                                  unawaited(transport.stop());
                                  ref.read(metronomeProvider.notifier).stop();
                                },
                                onLongPress: () =>
                                    unawaited(transport.stop(atBar: true)),
                                icon: const Icon(Icons.stop),
                                label: const Text('Stop'),
                              ),
                            ),
                    ),
                    const SizedBox(width: MonoPulseSpacing.sm),
                    Expanded(
                      child: state.loop
                          ? FilledButton.tonalIcon(
                              style: _transportStyle,
                              onPressed: () => transport.setLoop(false),
                              icon: const Icon(Icons.check),
                              label: const Text('Loop'),
                            )
                          : OutlinedButton(
                              style: _transportStyle,
                              onPressed: () => transport.setLoop(true),
                              child: const Text('Loop'),
                            ),
                    ),
                    const SizedBox(width: MonoPulseSpacing.sm),
                    Expanded(
                      child: OutlinedButton(
                        style: _transportStyle,
                        onPressed: () => transport.setQuantize(
                          state.quantize == Quantize.bar
                              ? Quantize.beat
                              : Quantize.bar,
                        ),
                        child: Text(
                          'Quantize: ${state.quantize == Quantize.beat ? 'Beat' : 'Bar'}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
                if (kDebugMode)
                  OutlinedButton(
                    onPressed: state.rendering
                        ? null
                        : () => unawaited(transport.launchDiagnostic()),
                    child: const Text('Sync test'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

final _transportStyle = ButtonStyle(
  minimumSize: WidgetStateProperty.all(const Size.fromHeight(52)),
  padding: WidgetStateProperty.all(
    const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.sm),
  ),
);

int? _songBars(MidiSongData? song, int beatsPerBar) {
  if (song == null) return null;
  var endTick = 0;
  for (final track in song.tracks) {
    for (final note in track.notes) {
      if (note.tick >= 0 && note.dur > 0) {
        endTick = math.max(endTick, note.tick + note.dur);
      }
    }
  }
  return (endTick / song.ppq / beatsPerBar).ceil();
}
