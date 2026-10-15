import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/song_lab.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/data/drum_practice_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../services/audio/midi/smf_parser.dart';
import '../midi/drum_kit_view.dart';

class DrumPracticePanel extends ConsumerStatefulWidget {
  const DrumPracticePanel({required this.songId, this.bandId, super.key});

  final String songId;
  final String? bandId;

  @override
  ConsumerState<DrumPracticePanel> createState() => _DrumPracticePanelState();
}

class _DrumPracticePanelState extends ConsumerState<DrumPracticePanel> {
  late final DrumPracticeNotifier _practice;

  @override
  void initState() {
    super.initState();
    _practice = ref.read(drumPracticeProvider.notifier);
  }

  SongLabEntry? _preview;
  String? _selectedId;
  bool _busy = false;

  bool get _canImport =>
      widget.bandId == null || ref.read(canEditBandProvider(widget.bandId!));

  @override
  void dispose() {
    unawaited(_practice.stop());
    super.dispose();
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$error')));
  }

  Future<void> _import() async {
    if (!_canImport) return;
    setState(() => _busy = true);
    try {
      // Any file keeps native pickers compatible; the SMF parser validates it.
      // ignore: avoid_redundant_argument_values
      final file = await FilePicker.pickFile(type: FileType.any);
      if (file == null) return;
      final pattern = parseDrumSmf(await file.readAsBytes());
      if (!mounted) return;
      final now = DateTime.now();
      final entry = SongLabEntry(
        id: const Uuid().v4(),
        songId: widget.songId,
        bandId: widget.bandId,
        type: LabEntryType.midi,
        title: file.name,
        authorId: ref.read(firebaseAuthProvider).currentUser?.uid ?? '',
        createdAt: now,
        updatedAt: now,
        midi: pattern.toJson(),
      );
      setState(() {
        _preview = entry;
        _selectedId = entry.id;
      });
      await _practice.loadPattern(entry.id, pattern);
    } on FormatException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final entry = _preview;
    if (entry == null || !_canImport) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(labRepositoryProvider)
          .saveEntry(entry, bandId: widget.bandId);
      if (mounted) setState(() => _preview = null);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(
      labEntriesProvider((widget.songId, widget.bandId)),
    );
    final state = ref.watch(drumPracticeProvider);
    final canImport =
        widget.bandId == null || ref.watch(canEditBandProvider(widget.bandId!));
    final pattern = state.entryId == _selectedId ? state.pattern : null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => SafeArea(
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            Text('Drums', style: Theme.of(context).textTheme.titleLarge),
            entries.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Failed to load drums: $error'),
              data: (entries) {
                final midi = entries.where((e) => e.type == LabEntryType.midi);
                return Column(
                  children: [
                    if (midi.isEmpty) const Text('No MIDI patterns yet'),
                    for (final entry in midi)
                      ListTile(
                        title: Text(entry.title ?? 'MIDI pattern'),
                        selected: _selectedId == entry.id,
                        enabled: !_busy && entry.midi != null,
                        onTap: () {
                          setState(() {
                            _preview = null;
                            _selectedId = entry.id;
                          });
                          unawaited(
                            _practice.loadPattern(entry.id, entry.pattern!),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
            if (_preview != null) Text('Preview: ${_preview!.title}'),
            if (pattern != null)
              DrumKitView(
                currentStep: state.currentStep,
                pattern: pattern,
                muted: state.muted,
                solo: state.solo,
                onToggleMute: _practice.toggleMute,
                onToggleSolo: _practice.toggleSolo,
              ),
            FilledButton.icon(
              onPressed: pattern == null
                  ? null
                  : () => state.playing ? _practice.stop() : _practice.start(),
              icon: Icon(state.playing ? Icons.stop : Icons.play_arrow),
              label: Text(state.playing ? 'Stop' : 'Play'),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final speed in [0.5, 0.75, 1.0])
                  ChoiceChip(
                    label: Text('${(speed * 100).round()}%'),
                    selected: state.speed == speed,
                    onSelected: (_) => _practice.setSpeed(speed),
                  ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: canImport && !_busy ? _import : null,
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('Import .mid'),
            ),
            if (_preview != null)
              FilledButton(
                onPressed: canImport && !_busy ? _save : null,
                child: const Text('Save to Song Lab'),
              ),
          ],
        ),
      ),
    );
  }
}
