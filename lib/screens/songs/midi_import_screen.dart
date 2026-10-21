import 'package:flutter/material.dart';

import '../../models/midi_song.dart';
import '../../services/midi_song_import.dart';
import '../../theme/mono_pulse_theme.dart';

class MidiImportScreen extends StatefulWidget {
  const MidiImportScreen({
    required this.preview,
    required this.title,
    required this.onSave,
    super.key,
  });

  final MidiImportPreview preview;
  final String title;
  final Future<void> Function(MidiSongMeta meta) onSave;

  @override
  State<MidiImportScreen> createState() => _MidiImportScreenState();
}

class _MidiImportScreenState extends State<MidiImportScreen> {
  late MidiSongMeta _meta;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _meta = widget.preview.meta;
  }

  void _updateTrack(int index, MidiTrackMeta track) {
    setState(() {
      final tracks = List<MidiTrackMeta>.of(_meta.tracks);
      tracks[index] = track;
      _meta = _meta.copyWith(tracks: tracks);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_meta);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mp.black,
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(MonoPulseSpacing.md),
                itemCount: _meta.tracks.length,
                itemBuilder: (context, index) => _TrackRow(
                  track: _meta.tracks[index],
                  enabled: !_saving,
                  onChanged: (track) => _updateTrack(index, track),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(MonoPulseSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: MonoPulseTypography.bodyMedium.copyWith(
                          color: MonoPulseColors.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: MonoPulseSpacing.sm),
                  ],
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox.square(
                                dimension: MonoPulseSpacing.lg,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: context.mp.textSecondary,
                                ),
                              ),
                              const SizedBox(width: MonoPulseSpacing.sm),
                              const Text('Saving...'),
                            ],
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.track,
    required this.enabled,
    required this.onChanged,
  });

  final MidiTrackMeta track;
  final bool enabled;
  final ValueChanged<MidiTrackMeta> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MonoPulseSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            track.name,
            style: MonoPulseTypography.titleMedium.copyWith(
              color: context.mp.textPrimary,
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.xs),
          Text(
            '${track.noteCount} notes · Pitch ${track.minPitch}-${track.maxPitch}',
            style: MonoPulseTypography.bodySmall.copyWith(
              color: context.mp.textSecondary,
            ),
          ),
          DropdownButton<MidiRole>(
            value: track.effectiveRole,
            isExpanded: true,
            dropdownColor: context.mp.surface,
            style: MonoPulseTypography.bodyMedium.copyWith(
              color: context.mp.textPrimary,
            ),
            items: [
              for (final role in MidiRole.values)
                DropdownMenuItem(
                  value: role,
                  child: Text(
                    '${role.name[0].toUpperCase()}${role.name.substring(1)}',
                  ),
                ),
            ],
            onChanged: enabled
                ? (role) {
                    if (role != null) {
                      onChanged(track.copyWith(roleOverride: role));
                    }
                  }
                : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('On'),
            value: !track.mute,
            onChanged: enabled
                ? (on) => onChanged(track.copyWith(mute: !on))
                : null,
          ),
          const Text('Volume'),
          Slider(
            value: track.volume,
            label: '${(track.volume * 100).round()}%',
            semanticFormatterCallback: (value) =>
                'Volume ${(value * 100).round()}%',
            onChanged: enabled
                ? (volume) => onChanged(track.copyWith(volume: volume))
                : null,
          ),
        ],
      ),
    );
  }
}
