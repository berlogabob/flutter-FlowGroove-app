import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/midi_song.dart';
import '../../models/section.dart';
import '../../models/section_span.dart';
import '../../models/song_lab.dart';
import '../../providers/data/backing_transport_provider.dart';
import '../../providers/data/metronome_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/data/midi_song_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../services/audio/midi/midi_song_meta_builder.dart';
import '../../services/audio/midi/note_edit.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../providers/data/midi_hidden_provider.dart';
import '../midi/arrangement_sheet.dart';
import '../midi/midi_import_flow.dart';
import 'note_editor_sheet.dart';
import 'section_card.dart';
import 'section_pad.dart';
import 'track_console.dart';

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
  String? _attachedKey;
  MidiSongData? _lastSong;
  Timer? _saveDebounce;
  SongLabEntry? _working;
  final _console = GlobalKey<State<TrackConsole>>();

  // Only what changes the rendered audio; mute/volume edits must not re-render.
  static String _renderKey(SongLabEntry e) {
    final m = e.midiSong;
    if (m == null) return e.id;
    return [
      e.id,
      m.fileUrl,
      m.startBar,
      m.useFileTempo,
      m.sectionMap.map((s) => '${s.sectionId}.${s.startBar}.${s.bars}').join(),
      for (final t in m.tracks)
        if (t.roleOverride != null || t.programOverride != null)
          '${t.index}.${t.channel}.${t.roleOverride?.name}.${t.programOverride}',
    ].join('|');
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  SongLabEntry _withTracks(List<MidiTrackMeta> visible, {SongLabEntry? base}) {
    final entry =
        base ?? (_working?.id == widget.entry.id ? _working! : widget.entry);
    final all = [...entry.midiSong!.tracks];
    for (final t in visible) {
      final i = all.indexWhere(
        (a) => a.index == t.index && a.channel == t.channel,
      );
      i >= 0 ? all[i] = t : all.add(t);
    }
    return entry.copyWith(midiSong: entry.midiSong!.copyWith(tracks: all));
  }

  void _persist(SongLabEntry updated) {
    final bandId = updated.bandId;
    final canEdit = bandId == null
        ? ref.read(canEditProvider)
        : ref.read(canEditBandProvider(bandId));
    if (!canEdit) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), () {
      unawaited(
        ref.read(labRepositoryProvider).saveEntry(updated, bandId: bandId),
      );
    });
  }

  Future<void> _reRender(SongLabEntry updated) async {
    _working = updated;
    _attachedKey = _renderKey(updated);
    _persist(updated);
    final transport = ref.read(backingTransportProvider.notifier);
    final resume =
        ref.read(backingTransportProvider).playingId ??
        ref.read(backingTransportProvider).queuedId;
    await transport.attach(
      updated,
      widget.sections.isEmpty
          ? [Section(id: 'song', name: 'Song', duration: 0)]
          : widget.sections,
    );
    if (resume != null && mounted) await transport.launch(resume);
    (_console.currentState as dynamic)?.reapplyLive();
  }

  @override
  void initState() {
    super.initState();
    _scheduleAttach();
  }

  @override
  void didUpdateWidget(LaunchpadView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.id != widget.entry.id) _lastSong = null;
    if (_renderKey(oldWidget.entry) != _renderKey(widget.entry)) {
      _working = null;
    }
    if (_renderKey(oldWidget.entry) != _renderKey(widget.entry) &&
            _renderKey(widget.entry) != _attachedKey ||
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
    _attachedKey = _renderKey(entry);
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
    // Keep the last parsed song while an edited entry reloads, so the strips
    // stay mounted and the page does not jump.
    final loaded = ref.watch(midiSongProvider(widget.entry)).value;
    if (loaded != null) _lastSong = loaded;
    final song = loaded ?? _lastSong;
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
    final consoleTracks = <MidiTrackMeta>[];
    if (song != null) {
      final settings = buildMidiSongMeta(song, previous: widget.entry.midiSong);
      consoleTracks.addAll(settings.tracks.where((t) => t.noteCount > 0));
    }
    // Play starts where the music starts, not on a silent lead-in section.
    var firstId = spans.first.sectionId;
    if (song != null) {
      final ticksPerBar = song.ppq * metro.timeSignature.numerator;
      final firstTick = song.tracks
          .expand((t) => t.notes)
          .fold<int?>(
            null,
            (min, n) => min == null || n.tick < min ? n.tick : min,
          );
      if (firstTick != null && ticksPerBar > 0) {
        final bar = firstTick ~/ ticksPerBar;
        firstId = spans
            .firstWhere(
              (s) => s.startBar + s.bars > bar,
              orElse: () => spans.first,
            )
            .sectionId;
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        bars == null
                            ? 'Loading MIDI…'
                            : 'MIDI ${bpm.round()} BPM · $bars bars',
                        style: MonoPulseTypography.bodySmall,
                      ),
                    ),
                    _MidiMenu(entry: widget.entry),
                  ],
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
                                mode: state.mode,
                                queuedLabel:
                                    'Next ${state.quantize.label.toLowerCase()}',
                                onTap: () => launch(span.sectionId),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: MonoPulseSpacing.md),
                if (consoleTracks.isNotEmpty)
                  TrackConsole(
                    key: _console,
                    tracks: consoleTracks,
                    onChanged: (tracks) => _persist(_withTracks(tracks)),
                    onProgramChanged: (tracks) =>
                        unawaited(_reRender(_withTracks(tracks))),
                    onEdit: (track) {
                      final song = ref
                          .read(midiSongProvider(widget.entry))
                          .value;
                      if (song == null) return;
                      final fileTrack = song.tracks
                          .where(
                            (t) =>
                                t.index == track.index &&
                                t.channel == track.channel,
                          )
                          .firstOrNull;
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        builder: (_) => NoteEditorSheet(
                          track: track,
                          notes: track.editedNotes != null
                              ? notesFromFlat(track.editedNotes!)
                              : fileTrack?.notes ?? [],
                          ppq: song.ppq,
                          beatsPerBar: ref
                              .read(metronomeProvider)
                              .timeSignature
                              .numerator,
                          sections: [
                            for (final span in state.spans)
                              (
                                name: sections[span.sectionId]?.name ?? 'Song',
                                startBar: span.startBar,
                                bars: span.bars,
                              ),
                          ],
                          onApply: (flat) => unawaited(
                            _reRender(
                              _withTracks([track.copyWith(editedNotes: flat)]),
                            ),
                          ),
                        ),
                      );
                    },
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
                      child:
                          state.playingId == null &&
                              state.queuedId == null &&
                              !metro.isPlaying
                          ? FilledButton.icon(
                              style: _transportStyle,
                              onPressed: disabled
                                  ? null
                                  : () => launch(firstId),
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Play'),
                            )
                          : Tooltip(
                              message: 'Hold to stop at the next bar',
                              child: FilledButton.icon(
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
                      child: _TransportChoice(
                        title: 'Mode',
                        value: state.mode.label,
                        tooltip: 'Once, Loop, or play on through the song',
                        onPressed: () => transport.setMode(state.mode.next),
                      ),
                    ),
                    const SizedBox(width: MonoPulseSpacing.sm),
                    Expanded(
                      child: _TransportChoice(
                        title: 'Quantize',
                        value: state.quantize.label,
                        tooltip: 'Block waits for the playing section to end',
                        onPressed: () =>
                            transport.setQuantize(state.quantize.next),
                      ),
                    ),
                  ],
                ),
                if (kDebugMode || _kSyncTest)
                  OutlinedButton(
                    onPressed: state.rendering
                        ? null
                        : () {
                            unawaited(_startSyncCapture());
                            unawaited(transport.launchDiagnostic());
                          },
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

/// flutter build ... --dart-define=SYNC_TEST=true shows the diagnostic in release.
const _kSyncTest = bool.fromEnvironment('SYNC_TEST');

/// Android sync test: the engine records its exact mixed PCM to
/// <externalFilesDir>/sync_capture.wav (adb pull, then scripts/measure_sync.py).
Future<void> _startSyncCapture() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await const MethodChannel(
      'com.flowgroove/metronome',
    ).invokeMethod<String>('syncCaptureStart', {'seconds': 130});
  } on Object {
    // Diagnostic only.
  }
}

/// A two-line cycling button: small title over the current value.
class _TransportChoice extends StatelessWidget {
  const _TransportChoice({
    required this.title,
    required this.value,
    required this.tooltip,
    required this.onPressed,
  });

  final String title;
  final String value;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: OutlinedButton(
      style: _transportStyle,
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: MonoPulseTypography.labelSmall),
          Text(value, style: MonoPulseTypography.bodyLarge),
        ],
      ),
    ),
  );
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

/// Edit / add / hide for the MIDI song under the launchpad.
class _MidiMenu extends ConsumerWidget {
  const _MidiMenu({required this.entry});

  final SongLabEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bandId = entry.bandId;
    return PopupMenuButton<String>(
      key: const ValueKey('midi-menu'),
      tooltip: 'MIDI',
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            unawaited(
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => ArrangementSheet(entry: entry, bandId: bandId),
              ),
            );
          case 'add':
            unawaited(
              pickAndImportMidi(
                context,
                ref,
                songId: entry.songId,
                bandId: bandId,
              ),
            );
          case 'hide':
            ref.read(midiHiddenProvider.notifier).hide(entry.id);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: Text('Edit arrangement')),
        if (canImportMidi(ref, bandId))
          const PopupMenuItem(value: 'add', child: Text('Add MIDI file')),
        const PopupMenuItem(value: 'hide', child: Text('Hide MIDI')),
      ],
    );
  }
}
