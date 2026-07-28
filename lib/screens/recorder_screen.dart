import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song.dart';
import '../models/song_lab.dart';
import '../providers/data/data_providers.dart';
import '../router/app_router.dart';
import '../services/idea_recorder.dart';
import '../theme/mono_pulse_theme.dart';
import '../utils/snackbar.dart';
import 'songs/components/lab_recording_sheet.dart';
import '../widgets/tools/tool_scaffold.dart';

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
        if (mounted) captureIdea(context, ref, autoStart: true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            onPressed: () => captureIdea(context, ref),
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
              'Nothing here yet — hit Record and catch the riff before it '
              'gets away. Link takes to songs later; linked ones move into '
              "the song's Lab.",
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
        trailing: PopupMenuButton<String>(
          onSelected: (v) => switch (v) {
            'edit' => context.goAudioNote(recording),
            'link' => _linkToSong(context, ref),
            'delete' => _delete(context, ref),
            _ => null,
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
    if (songId == null || !context.mounted) return;
    await linkIdeaToSong(ref, recording, songId: songId);
    if (context.mounted) {
      showAppSnackBar(context, "Linked — see the song's Lab timeline");
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(labRepositoryProvider);
    await repo.deleteEntry(ideaInboxSongId, recording.id);
    if (context.mounted) {
      showAppSnackBar(
        context,
        'Recording deleted',
        actionLabel: 'Undo',
        onAction: () => repo.saveEntry(recording),
      );
    }
  }
}
