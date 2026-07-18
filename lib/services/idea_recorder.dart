import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/song_lab.dart';
import '../providers/auth/auth_provider.dart';
import '../providers/data/data_providers.dart';
import '../screens/songs/components/lab_recording_sheet.dart';
import '../services/analytics_service.dart';
import '../services/storage_service.dart';
import '../utils/snackbar.dart';

/// The virtual song id holding unlinked audio ideas (#145). The parent doc
/// is never created, so it can't surface in the library; the deployed
/// Firestore/Storage rules already cover the path (plain songId wildcards).
const ideaInboxSongId = '_inbox';

const _uuid = Uuid();

/// One capture path for everywhere a mic button lives (#69/#145): opens the
/// recording sheet, uploads, and saves a `recording` Lab entry — under a song
/// when [songId] is given, else into the ideas inbox to be linked later.
Future<void> captureIdea(
  BuildContext context,
  WidgetRef ref, {
  String? songId,
  String? bandId,
  bool autoStart = false,
}) async {
  final result = await showModalBottomSheet<LabRecordingResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => LabRecordingSheet(autoStart: autoStart),
  );
  if (result == null || !context.mounted) return;

  final targetSongId = songId ?? ideaInboxSongId;
  final entryId = _uuid.v4();
  try {
    final url = await StorageService().uploadLabAudio(
      result.bytes,
      bandId: bandId,
      songId: targetSongId,
      entryId: entryId,
      ext: result.ext,
      contentType: switch (result.ext) {
        'wav' => 'audio/wav',
        'mp3' => 'audio/mpeg',
        'ogg' => 'audio/ogg',
        _ => 'audio/mp4',
      },
    );
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid ?? '';
    final now = DateTime.now();
    await ref
        .read(labRepositoryProvider)
        .saveEntry(
          SongLabEntry(
            id: entryId,
            songId: targetSongId,
            bandId: bandId,
            type: LabEntryType.recording,
            title: result.title,
            body: result.notes,
            authorId: uid,
            createdAt: now,
            updatedAt: now,
            attachmentIds: [url],
          ),
          bandId: bandId,
        );
    unawaited(
      AnalyticsService.logLabEntryAdded(type: LabEntryType.recording.name),
    );
    if (context.mounted && songId == null) {
      showAppSnackBar(
        context,
        'Saved — link it to a song from the Recorder list',
      );
    }
  } catch (e) {
    if (context.mounted) showAppSnackBar(context, 'Upload failed: $e');
  }
}

/// Links an inbox idea to a song: same entry (and id — the Storage object
/// name still matches) written under the target song, then removed from the
/// inbox. `// ponytail: the audio object stays under _inbox; its URL keeps
/// working — move Storage objects only if it ever matters.`
Future<void> linkIdeaToSong(
  WidgetRef ref,
  SongLabEntry idea, {
  required String songId,
}) async {
  final repo = ref.read(labRepositoryProvider);
  final now = DateTime.now();
  await repo.saveEntry(
    SongLabEntry(
      id: idea.id,
      songId: songId,
      type: idea.type,
      title: idea.title,
      body: idea.body,
      authorId: idea.authorId,
      createdAt: idea.createdAt,
      updatedAt: now,
      attachmentIds: idea.attachmentIds,
    ),
  );
  await repo.deleteEntry(ideaInboxSongId, idea.id);
}
