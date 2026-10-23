import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/permissions_provider.dart';
import '../../screens/songs/midi_import_screen.dart';
import '../../services/analytics_service.dart';
import '../../services/midi_song_import.dart';
import '../../utils/picked_file.dart';

const _uuid = Uuid();

/// Import needs a native file picker and edit rights on the song's scope.
bool canImportMidi(WidgetRef ref, String? bandId) =>
    !kIsWeb &&
    (bandId == null
        ? ref.read(canEditProvider)
        : ref.read(canEditBandProvider(bandId)));

/// Pick a MIDI/RMID file, preview it, and save it as a Song Lab entry of
/// [songId]. Shared by Song Lab and the metronome's MIDI menu.
Future<void> pickAndImportMidi(
  BuildContext context,
  WidgetRef ref, {
  required String songId,
  String? bandId,
}) async {
  if (!canImportMidi(ref, bandId)) return;
  Future<void> fail(String message) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Import MIDI'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  try {
    // Any file keeps native pickers compatible; the MIDI parser validates it.
    // ignore: avoid_redundant_argument_values
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null) return;
    final bytes = await readPickedBytes(file);
    final preview = previewMidiImport(bytes);
    if (!context.mounted || !canImportMidi(ref, bandId)) return;
    final entryId = _uuid.v4();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (importContext) => MidiImportScreen(
          preview: preview,
          title: file.name,
          onSave: (meta) async {
            if (!canImportMidi(ref, bandId)) {
              throw StateError('You do not have permission to import MIDI');
            }
            final entry = await saveMidiImport(
              bytes: bytes,
              meta: meta,
              entryId: entryId,
              songId: songId,
              bandId: bandId,
              createdBy: ref.read(firebaseAuthProvider).currentUser?.uid ?? '',
              title: file.name,
              upload: ref.read(storageServiceProvider).uploadLabAudio,
            );
            await ref
                .read(labRepositoryProvider)
                .saveEntry(entry, bandId: bandId);
            unawaited(AnalyticsService.logLabEntryAdded(type: entry.type.name));
            if (importContext.mounted) Navigator.of(importContext).pop();
          },
        ),
      ),
    );
  } on FormatException {
    await fail('Not a valid MIDI file');
  } catch (error) {
    await fail('Could not import MIDI: $error');
  }
}
