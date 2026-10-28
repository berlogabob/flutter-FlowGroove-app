import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/audio_region.dart';
import '../models/song_lab.dart';
import '../providers/auth/auth_provider.dart';
import '../providers/data/data_providers.dart';
import '../providers/permissions_provider.dart';
import '../screens/songs/components/lab_recording_sheet.dart';
import '../services/analytics_service.dart';
import '../utils/snackbar.dart';

/// The virtual song id holding unlinked audio ideas (#145). The parent doc
/// is never created, so it can't surface in the library; the deployed
/// Firestore/Storage rules already cover the path (plain songId wildcards).
const ideaInboxSongId = '_inbox';

const _uuid = Uuid();

/// Cue points of a converted file become its regions (they're lost from the
/// AAC copy, and the setup wizard reads markers from the stored file).
List<AudioRegion> _regionsFromMarkers(LabRecordingResult result) {
  final durationMs = result.durationMs;
  if (durationMs == null || result.markers.isEmpty) return const [];
  final markers = [
    for (final m in result.markers)
      AudioRegion(
        id: '',
        name: m.name,
        // A marker at the very start names the first region.
        startMs: m.ms < minRegionMs ? 0 : m.ms,
        endMs: 0,
      ),
  ];
  final regions = regionsFromCuts(
    [for (final m in markers) m.startMs],
    durationMs: durationMs,
    newId: _uuid.v4,
    keepNamesFrom: markers,
  );
  return regions.length > 1 ? regions : const [];
}

const _accessChanged =
    'Recording stopped because access changed. Please try again.';

bool _hasAuthority(WidgetRef ref, String? uid, String? bandId) {
  final user = ref.read(appUserProvider);
  final bands = bandId == null ? null : ref.read(bandsProvider);
  return uid != null &&
      uid.isNotEmpty &&
      !user.isLoading &&
      !user.hasError &&
      user.asData?.value?.uid == uid &&
      !ref.read(isDemoUserProvider) &&
      (bandId == null ||
          (!bands!.isLoading &&
              !bands.hasError &&
              ref.read(canEditBandProvider(bandId))));
}

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
  final uid = ref.read(appUserProvider).asData?.value?.uid;
  final targetSongId = songId ?? ideaInboxSongId;
  final targetBandId = bandId;
  bool authorized() {
    if (!context.mounted) return false;
    if (_hasAuthority(ref, uid, targetBandId)) return true;
    showAppSnackBar(context, _accessChanged);
    return false;
  }

  if (!authorized()) return;
  final result = await showModalBottomSheet<LabRecordingResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => LabRecordingSheet(autoStart: autoStart),
  );
  if (result == null || !authorized()) return;
  final parts = result.parts.isEmpty ? [result] : result.parts;
  final multiple = result.parts.isNotEmpty;

  Future<void> uploadPart(int index) async {
    if (!authorized()) return;
    final result = parts[index];
    final partLabel = 'part ${index + 1} of ${parts.length}';
    if (multiple) showAppSnackBar(context, 'Uploading $partLabel…');
    final entryId = _uuid.v4();
    final String url;
    try {
      url = await ref
          .read(storageServiceProvider)
          .uploadLabAudio(
            result.bytes,
            bandId: targetBandId,
            songId: targetSongId,
            entryId: entryId,
            ext: result.ext,
            contentType: switch (result.ext) {
              'aac' => 'audio/aac',
              'wav' => 'audio/wav',
              'mp3' => 'audio/mpeg',
              'ogg' => 'audio/ogg',
              _ => 'audio/mp4',
            },
          );
    } catch (e) {
      if (context.mounted && authorized()) {
        showAppSnackBar(
          context,
          multiple
              ? "Couldn't upload $partLabel (${result.title ?? 'Part ${index + 1}'}). Earlier saved parts are kept."
              : e.toString().contains('larger than')
              ? 'File is too big (100MB max)'
              : "Couldn't upload the recording",
        );
      }
      return;
    }
    if (!authorized()) return;
    final now = DateTime.now();
    final entry = SongLabEntry(
      id: entryId,
      songId: targetSongId,
      bandId: targetBandId,
      type: LabEntryType.recording,
      title: result.title,
      body: result.notes,
      authorId: uid!,
      createdAt: now,
      updatedAt: now,
      attachmentIds: [url],
      peaks: result.peaks,
      regions: _regionsFromMarkers(result),
    );
    // Offline Firestore writes can stay pending indefinitely.
    const confirmationTimeout = Duration(seconds: 10);
    var busy = false;

    Future<void> saved() async {
      unawaited(
        AnalyticsService.logLabEntryAdded(type: LabEntryType.recording.name),
      );
      if (!multiple && songId == null) {
        showAppSnackBar(
          context,
          'Saved — link it to a song from the Recorder list',
        );
      }
      if (index + 1 < parts.length) {
        await uploadPart(index + 1);
      } else if (true) { debugPrint("DBG saved idx=$index mounted=${context.mounted}"); } if (index + 1 >= parts.length && multiple && context.mounted) {
        showAppSnackBar(context, 'Saved ${parts.length} parts');
      }
    }

    Future<void> attempt({bool reconcileOnly = false}) async {
      if (busy || !authorized()) return;
      busy = true;
      try {
        if (!reconcileOnly) {
          var written = false;
          try {
            await ref
                .read(labRepositoryProvider)
                .saveEntry(entry, bandId: targetBandId)
                .timeout(confirmationTimeout);
            written = true;
          } catch (_) {
            if (!authorized()) return;
          }
          if (!authorized()) return;
          if (written) {
            await saved();
            return;
          }
        }
        // A thrown/timed-out write may still have committed. Keep its audio and
        // identity, and never infer absence from cache or a failed server read.
        final SongLabEntry? confirmed;
        try {
          confirmed = await ref
              .read(labRepositoryProvider)
              .readEntryFromServer(targetSongId, entryId, bandId: targetBandId)
              .timeout(confirmationTimeout);
        } catch (_) {
          if (!context.mounted || !authorized()) return;
          showAppSnackBar(
            context,
            multiple
                ? '$partLabel not confirmed — check connection. Earlier saved parts are kept.'
                : 'Not confirmed — check connection',
            actionLabel: 'Retry',
            onAction: () => unawaited(attempt(reconcileOnly: true)),
          );
          return;
        }
        if (!context.mounted || !authorized()) return;
        if (confirmed != null) {
          await saved();
        } else {
          showAppSnackBar(
            context,
            multiple
                ? '$partLabel uploaded but not saved yet. Earlier saved parts are kept.'
                : 'Recording uploaded but not saved yet',
            actionLabel: 'Retry',
            onAction: () => unawaited(attempt()),
          );
        }
      } finally {
        busy = false;
      }
    }

    await attempt();
  }

  await uploadPart(0);
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
  final uid = ref.read(appUserProvider).asData?.value?.uid;
  if (!_hasAuthority(ref, uid, null) || idea.authorId != uid) {
    throw StateError(_accessChanged);
  }
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
      peaks: idea.peaks,
    ),
  );
  if (!_hasAuthority(ref, uid, null)) throw StateError(_accessChanged);
  await repo.deleteEntry(ideaInboxSongId, idea.id);
}
