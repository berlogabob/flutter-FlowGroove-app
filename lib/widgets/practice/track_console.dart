import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/midi_song.dart';
import '../../providers/data/backing_transport_provider.dart';
import '../../services/audio/midi/gm_names.dart';
import '../../theme/mono_pulse_theme.dart';

const _profileKey = 'my_instrument_role';
const _profileRoles = [
  MidiRole.drums,
  MidiRole.bass,
  MidiRole.guitar,
  MidiRole.keys,
  MidiRole.vocal,
];

/// Stem names exactly as the stem builder derives them (duplicates get ' 2').
List<String> consoleStemNames(List<MidiTrackMeta> tracks) {
  final seen = <String, int>{};
  return [
    for (final track in tracks)
      () {
        final count = seen.update(track.name, (n) => n + 1, ifAbsent: () => 1);
        return count == 1 ? track.name : '${track.name} $count';
      }(),
  ];
}

/// Mixer console: one strip per MIDI track, live on the backing mixer.
class TrackConsole extends ConsumerStatefulWidget {
  const TrackConsole({
    required this.tracks,
    required this.onChanged,
    required this.onProgramChanged,
    required this.onEdit,
    super.key,
  });

  /// Tracks that have notes, in file order.
  final List<MidiTrackMeta> tracks;

  /// Mute, volume or role changes to persist (no re-render needed).
  final void Function(List<MidiTrackMeta> tracks) onChanged;

  /// Instrument changes: persist and re-render.
  final void Function(List<MidiTrackMeta> tracks) onProgramChanged;

  final void Function(MidiTrackMeta track) onEdit;

  @override
  ConsumerState<TrackConsole> createState() => _TrackConsoleState();
}

class _TrackConsoleState extends ConsumerState<TrackConsole> {
  late List<MidiTrackMeta> _tracks = widget.tracks;
  String? _solo;
  String? _minusOne;
  MidiRole? _profile;

  List<String> get _names => consoleStemNames(_tracks);

  @override
  void initState() {
    super.initState();
    unawaited(_loadProfile());
  }

  @override
  void didUpdateWidget(TrackConsole oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tracks.length != widget.tracks.length) {
      _tracks = widget.tracks;
      return;
    }
    for (var i = 0; i < widget.tracks.length; i++) {
      final old = oldWidget.tracks[i];
      final track = widget.tracks[i];
      if (old.index != track.index ||
          old.channel != track.channel ||
          old.name != track.name ||
          old.mute != track.mute ||
          old.volume != track.volume ||
          old.programOverride != track.programOverride ||
          old.roleOverride != track.roleOverride ||
          old.editedNotes?.length != track.editedNotes?.length) {
        _tracks = widget.tracks;
        break;
      }
    }
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_profileKey);
      if (!mounted || saved == null) return;
      setState(() => _profile = MidiRole.parse(saved));
      _autoMinusOne();
    } catch (_) {
      // Preference storage is a convenience; the console works without it.
    }
  }

  Future<void> _setProfile(MidiRole? role) async {
    setState(() => _profile = role);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (role == null) {
        await prefs.remove(_profileKey);
      } else {
        await prefs.setString(_profileKey, role.name);
      }
    } catch (_) {}
    if (!mounted) return;
    _setMinusOne(null);
    _autoMinusOne();
  }

  void _autoMinusOne() {
    final role = _profile;
    if (role == null || _minusOne != null) return;
    final i = _tracks.indexWhere((t) => t.effectiveRole == role);
    if (i >= 0) _setMinusOne(_names[i]);
  }

  BackingTransportNotifier get _transport =>
      ref.read(backingTransportProvider.notifier);

  void _setMinusOne(String? name) {
    final previous = _minusOne;
    setState(() => _minusOne = name);
    if (previous != null) {
      final i = _names.indexOf(previous);
      _transport.muteStem(previous, mute: i >= 0 && _tracks[i].mute);
    }
    if (name != null) _transport.muteStem(name);
  }

  /// Re-applies solo and "I play this" after a re-render cleared them.
  void reapplyLive() {
    if (_minusOne != null) _transport.muteStem(_minusOne!);
    if (_solo != null) _transport.soloStem(_solo!);
  }

  void _update(int i, MidiTrackMeta track, {bool program = false}) {
    setState(() => _tracks = [..._tracks]..[i] = track);
    (program ? widget.onProgramChanged : widget.onChanged)(_tracks);
  }

  @override
  Widget build(BuildContext context) {
    final names = _names;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: MonoPulseSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('I am'),
            for (final role in _profileRoles)
              ChoiceChip(
                label: Text(role.name),
                selected: _profile == role,
                onSelected: (on) => unawaited(_setProfile(on ? role : null)),
              ),
          ],
        ),
        for (var i = 0; i < _tracks.length; i++)
          _Strip(
            key: ValueKey('strip-${names[i]}'),
            track: _tracks[i],
            solo: _solo == names[i],
            minusOne: _minusOne == names[i],
            onMute: (mute) {
              _transport.muteStem(
                names[i],
                mute: mute || _minusOne == names[i],
              );
              _update(i, _tracks[i].copyWith(mute: mute));
            },
            onSolo: () {
              final on = _solo != names[i];
              setState(() => _solo = on ? names[i] : null);
              _transport.soloStem(names[i], solo: on);
            },
            onMinusOne: (on) => _setMinusOne(on ? names[i] : null),
            onVolume: (v) {
              _transport.setStemVolume(names[i], v);
              setState(
                () =>
                    _tracks = [..._tracks]
                      ..[i] = _tracks[i].copyWith(volume: v),
              );
            },
            onVolumeDone: () => widget.onChanged(_tracks),
            onEdit: () => widget.onEdit(_tracks[i]),
            onProgram: (program) => _update(
              i,
              _tracks[i].copyWith(programOverride: program),
              program: true,
            ),
          ),
      ],
    );
  }
}

/// Track names default to the instrument name; show role and channel instead.
String _title(MidiTrackMeta track) =>
    track.name.startsWith(gmProgramName(track.program))
    ? '${track.effectiveRole.name} · ch ${track.channel + 1}'
    : track.name;

class _Strip extends StatelessWidget {
  const _Strip({
    required this.track,
    required this.solo,
    required this.minusOne,
    required this.onMute,
    required this.onSolo,
    required this.onMinusOne,
    required this.onVolume,
    required this.onVolumeDone,
    required this.onProgram,
    required this.onEdit,
    super.key,
  });

  final MidiTrackMeta track;
  final bool solo;
  final bool minusOne;
  final ValueChanged<bool> onMute;
  final VoidCallback onSolo;
  final ValueChanged<bool> onMinusOne;
  final ValueChanged<double> onVolume;
  final VoidCallback onVolumeDone;
  final ValueChanged<int?> onProgram;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final drums = track.effectiveRole == MidiRole.drums;
    final program = track.effectiveProgram;
    final auto = track.programOverride == null;
    return Card(
      margin: const EdgeInsets.only(top: MonoPulseSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MonoPulseSpacing.sm,
          vertical: MonoPulseSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    _title(track),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MonoPulseTypography.titleMedium,
                  ),
                ),
                if (drums)
                  const Text('Drum kit')
                else
                  Flexible(
                    flex: 3,
                    child: PopupMenuButton<int>(
                      tooltip: 'Instrument for ${track.name}',
                      onSelected: (value) =>
                          onProgram(value < 0 ? null : value),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: -1,
                          child: Text('Auto (file)'),
                        ),
                        for (var p = 0; p < gmProgramNames.length; p++)
                          PopupMenuItem(
                            value: p,
                            child: Text(gmProgramNames[p]),
                          ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.all(MonoPulseSpacing.sm),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                '${gmProgramName(program)}${auto ? '' : ' *'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Mute ${track.name}',
                  isSelected: track.mute,
                  onPressed: () => onMute(!track.mute),
                  icon: Icon(track.mute ? Icons.volume_off : Icons.volume_up),
                ),
                IconButton.filledTonal(
                  tooltip: 'Solo ${track.name}',
                  isSelected: solo,
                  onPressed: onSolo,
                  icon: const Text('S'),
                ),
                Flexible(
                  flex: 2,
                  child: FilterChip(
                    label: const Text(
                      'I play',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    tooltip: 'Leave ${track.name} to me',
                    selected: minusOne,
                    onSelected: onMinusOne,
                  ),
                ),
                IconButton(
                  tooltip: 'Edit notes of ${track.name}',
                  icon: const Icon(Icons.edit_note),
                  onPressed: onEdit,
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: track.volume,
                    label: '${(track.volume * 100).round()}%',
                    onChanged: onVolume,
                    onChangeEnd: (_) => onVolumeDone(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
