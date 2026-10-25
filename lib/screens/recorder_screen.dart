import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song.dart';
import '../models/song_lab.dart';
import '../providers/data/data_providers.dart';
import '../providers/auth/auth_provider.dart';

import '../router/app_router.dart';
import '../services/idea_recorder.dart';
import '../services/pending_storage_deletes.dart';
import '../theme/mono_pulse_theme.dart';
import '../utils/snackbar.dart';
import 'songs/components/lab_recording_sheet.dart';
import '../widgets/tools/tool_scaffold.dart';

String? _editableUid(WidgetRef ref) {
  final user = ref.read(appUserProvider);
  if (user.isLoading || user.hasError) return null;
  final value = user.value;
  if (value == null || value.accessRole == 'demo') return null;
  return ref.read(firebaseAuthProvider).currentUser?.uid == value.uid
      ? value.uid
      : null;
}

/// Recorder (#145): the one home for audio captures. Record on top, every
/// unlinked take listed below — play it, link it to a song (it moves into
/// that song's Lab timeline), or delete it. Linked recordings live in their
/// song's Lab, not here.
class RecorderScreen extends ConsumerStatefulWidget {
  const RecorderScreen({this.autoStart = false, super.key});

  /// Open the capture sheet immediately with recording running (the Home
  /// "Audio note" quick action).
  final bool autoStart;

  @override
  ConsumerState<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends ConsumerState<RecorderScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _editableUid(ref) != null) {
          captureIdea(context, ref, autoStart: true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appUserProvider);
    ref.watch(firebaseAuthProvider);
    final uid = _editableUid(ref);
    final recordings =
        ref.watch(labEntriesProvider((ideaInboxSongId, null))).asData?.value ??
        const <SongLabEntry>[];
    final songs = ref.watch(songsProvider).asData?.value ?? const <Song>[];

    return ToolScreenScaffold(
      title: 'Recorder',
      mainWidget: ListView(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: MonoPulseColors.accentOrange,
              padding: const EdgeInsets.symmetric(
                vertical: MonoPulseSpacing.lg,
              ),
            ),
            onPressed: uid == null
                ? null
                : () {
                    if (context.mounted && _editableUid(ref) == uid) {
                      captureIdea(context, ref);
                    }
                  },
            icon: const Icon(Icons.mic),
            label: const Text('Record'),
          ),
          const SizedBox(height: MonoPulseSpacing.lg),
          Padding(
            padding: const EdgeInsets.only(bottom: MonoPulseSpacing.sm),
            child: Text('Recordings', style: MonoPulseTypography.titleMedium),
          ),
          if (recordings.isEmpty)
            Text(
              'Hit Record to capture an idea. You can attach recordings '
              'to a song later. Your phone asks for microphone access the '
              'first time you record.',
              style: MonoPulseTypography.bodySmall.copyWith(
                color: context.mp.textSecondary,
              ),
            )
          else
            for (final rec in recordings)
              _RecordingCard(recording: rec, songs: songs),
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}

/// One take: same card shape as the song library list.
class _RecordingCard extends ConsumerWidget {
  const _RecordingCard({required this.recording, required this.songs});

  final SongLabEntry recording;
  final List<Song> songs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appUserProvider);
    ref.watch(firebaseAuthProvider);
    final uid = _editableUid(ref);
    final d = recording.createdAt;
    return Card(
      margin: const EdgeInsets.only(bottom: MonoPulseSpacing.sm),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: ListTile(
        onTap: () => context.goAudioNote(recording),
        title: Text(
          recording.title ?? 'Take · ${d.day}/${d.month}',
          style: MonoPulseTypography.titleLarge.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${d.day}/${d.month}/${d.year}'
              '${recording.body?.isNotEmpty == true ? ' · ${recording.body}' : ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: MonoPulseTypography.bodySmall,
            ),
            if (recording.attachmentIds.isNotEmpty)
              LabAudioPlayer(url: recording.attachmentIds.first),
          ],
        ),
        trailing: uid == null
            ? null
            : PopupMenuButton<String>(
                onSelected: (v) {
                  if (!context.mounted || _editableUid(ref) != uid) return;
                  switch (v) {
                    case 'edit':
                      context.goAudioNote(recording);
                    case 'link':
                      _linkToSong(context, ref);
                    case 'delete':
                      _delete(context, ref);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Trim & notes…')),
                  PopupMenuItem(value: 'link', child: Text('Link to song…')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
      ),
    );
  }

  Future<void> _linkToSong(BuildContext context, WidgetRef ref) async {
    final uid = _editableUid(ref);
    if (uid == null) return;
    final songId = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Link recording to song')),
            for (final song in songs)
              ListTile(
                dense: true,
                leading: const Icon(Icons.music_note),
                title: Text(song.title),
                subtitle: Text(song.artist),
                onTap: () => Navigator.pop(sheetContext, song.id),
              ),
          ],
        ),
      ),
    );
    if (songId == null || !context.mounted || _editableUid(ref) != uid) return;
    await linkIdeaToSong(ref, recording, songId: songId);
    if (context.mounted) {
      showAppSnackBar(context, "Linked — see the song's Lab timeline");
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final uid = _editableUid(ref);
    if (uid == null) return;
    // The card disappears on deletion; Undo must read the surviving scope.
    final container = ProviderScope.containerOf(context, listen: false);
    final auth = ref.read(firebaseAuthProvider);
    final repo = ref.read(labRepositoryProvider);
    final pending = ref.read(pendingStorageDeletesProvider);
    // Undo restores the document, and its audio URL only still resolves
    // because the object outlives the snackbar. Queue the object now, delete
    // it when the undo window shuts, and drop it from the queue if Undo wins.
    final url = recording.attachmentIds.isEmpty
        ? null
        : recording.attachmentIds.first;
    try {
      if (url != null) await pending.enqueue(url);
      if (!context.mounted || _editableUid(ref) != uid) {
        if (url != null) await pending.cancel(url);
        return;
      }
      await repo.deleteEntry(ideaInboxSongId, recording.id);
    } catch (_) {
      if (url != null) {
        try {
          await pending.cancel(url);
        } catch (_) {
          // shortcut: persistence failure can leave the URL queued; REC-S5 must address recovery.
        }
      }
      if (context.mounted) {
        showAppSnackBar(context, 'Could not delete recording');
      }
      return;
    }
    if (url != null) unawaited(pending.flushAfter(url, undoGracePeriod));
    if (context.mounted) {
      showAppSnackBar(
        context,
        'Recording deleted',
        actionLabel: 'Undo',
        onAction: () {
          final user = container.read(appUserProvider);
          if (user.isLoading ||
              user.hasError ||
              user.value?.uid != uid ||
              user.value?.accessRole == 'demo' ||
              auth.currentUser?.uid != uid)
            return;
          repo.saveEntry(recording);
          if (url != null) pending.cancel(url);
        },
      );
    }
  }
}
