import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/metronome_session.dart';
import '../models/song.dart';
import '../models/song_lab.dart';
import '../providers/data/data_providers.dart';
import '../providers/homework_provider.dart';
import '../providers/practice_stats_provider.dart';
import '../screens/songs/components/lab_recording_sheet.dart';
import '../services/idea_recorder.dart';
import '../theme/mono_pulse_theme.dart';
import '../utils/snackbar.dart';
import '../widgets/practice_dashboard_card.dart';
import '../widgets/tools/tool_scaffold.dart';

/// Practice screen v1 (#133): the workbook-lite — weekly stats, where the
/// time went per song, homework (open Song Lab tasks across the library),
/// and the session logbook. Exercises/goals wait for the teacher-workbook
/// vision (AUDIT_addition.md); mood/reflection lives in Song Lab notes.
class PracticeScreen extends ConsumerWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats =
        ref.watch(practiceStatsProvider).asData?.value ?? PracticeStats.empty;
    final sessions =
        ref.watch(practiceSessionsProvider).asData?.value ??
        const <MetronomeSession>[];
    final homework =
        ref.watch(myHomeworkProvider).asData?.value ?? const <HomeworkItem>[];
    final songs = ref.watch(songsProvider).asData?.value ?? const <Song>[];
    final titles = {for (final s in songs) s.id: s.title};

    return ToolScreenScaffold(
      title: 'Practice',
      mainWidget: ListView(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        children: [
          const PracticeDashboardCard(tappable: false),
          if (!stats.isEmptyWeek) ...[
            const SizedBox(height: MonoPulseSpacing.lg),
            _sectionTitle(context, 'Where your time went'),
            _TimePerSong(stats: stats, titles: titles),
          ],
          const SizedBox(height: MonoPulseSpacing.lg),
          _sectionTitle(context, 'Homework'),
          if (homework.isEmpty)
            _quietText(
              'Nothing open. Add tasks to a song from its Lab '
              '(song card → Song Lab).',
            )
          else
            for (final item in homework.take(10)) _homeworkRow(context, item),
          const SizedBox(height: MonoPulseSpacing.lg),
          _IdeasSection(songs: songs),
          const SizedBox(height: MonoPulseSpacing.lg),
          _sectionTitle(context, 'Quick start'),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => context.pushNamed('metronome'),
                  icon: const Icon(Icons.speed),
                  label: const Text('Metronome'),
                ),
              ),
              const SizedBox(width: MonoPulseSpacing.md),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => context.pushNamed('tuner'),
                  icon: const Icon(Icons.tune),
                  label: const Text('Tuner'),
                ),
              ),
              const SizedBox(width: MonoPulseSpacing.md),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => captureIdea(context, ref),
                  icon: const Icon(Icons.mic),
                  label: const Text('Idea'),
                ),
              ),
            ],
          ),
          const SizedBox(height: MonoPulseSpacing.lg),
          _sectionTitle(context, 'Recent sessions'),
          if (sessions.isEmpty)
            _quietText(
              'No sessions yet — every metronome run lands here '
              'automatically.',
            )
          else
            ..._logbook(context, sessions.take(30).toList(), titles),
          const SizedBox(height: 96),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(bottom: MonoPulseSpacing.sm),
    child: Text(title, style: MonoPulseTypography.titleMedium),
  );

  Widget _quietText(String text) => Padding(
    padding: const EdgeInsets.only(bottom: MonoPulseSpacing.sm),
    child: Text(
      text,
      style: MonoPulseTypography.bodySmall.copyWith(
        color: MonoPulseColors.textSecondary,
      ),
    ),
  );

  Widget _homeworkRow(BuildContext context, HomeworkItem item) {
    final due = item.task.dueAt;
    return Card(
      margin: const EdgeInsets.only(bottom: MonoPulseSpacing.xs),
      child: ListTile(
        dense: true,
        leading: const Icon(
          Icons.check_circle_outline,
          color: MonoPulseColors.accentOrange,
        ),
        title: Text(item.task.title),
        subtitle: Text(
          [
            item.song.title,
            if (due != null) 'due ${due.day}/${due.month}',
          ].join(' · '),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.pushNamed(
          'song-lab',
          pathParameters: {'id': item.song.id},
          extra: {'song': item.song, 'bandId': null},
        ),
      ),
    );
  }

  List<Widget> _logbook(
    BuildContext context,
    List<MetronomeSession> sessions,
    Map<String, String> titles,
  ) {
    final rows = <Widget>[];
    DateTime? lastDay;
    final today = DateTime.now();
    for (final s in sessions) {
      final day = DateTime(
        s.startedAt.year,
        s.startedAt.month,
        s.startedAt.day,
      );
      if (day != lastDay) {
        lastDay = day;
        final label = day == DateTime(today.year, today.month, today.day)
            ? 'Today'
            : day ==
                  DateTime(
                    today.year,
                    today.month,
                    today.day,
                  ).subtract(const Duration(days: 1))
            ? 'Yesterday'
            : '${day.day}/${day.month}/${day.year}';
        rows.add(
          Padding(
            padding: const EdgeInsets.only(
              top: MonoPulseSpacing.sm,
              bottom: MonoPulseSpacing.xs,
            ),
            child: Text(
              label,
              style: MonoPulseTypography.bodySmall.copyWith(
                color: MonoPulseColors.textSecondary,
              ),
            ),
          ),
        );
      }
      final song = s.songId == null
          ? 'Freestyle'
          : titles[s.songId] ?? 'Removed song';
      rows.add(
        Row(
          children: [
            const Icon(
              Icons.music_note,
              size: 16,
              color: MonoPulseColors.textSecondary,
            ),
            const SizedBox(width: MonoPulseSpacing.sm),
            Expanded(child: Text(song, overflow: TextOverflow.ellipsis)),
            Text(
              '${PracticeDashboardCard.formatMinutes(s.elapsedSeconds)}'
              ' · ${s.startBpm} BPM',
              style: MonoPulseTypography.bodySmall.copyWith(
                color: MonoPulseColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    return rows;
  }
}

/// Horizontal proportion bar + rows: this week's practice per song, the
/// "where your time goes" view (the differentiator competitors gate behind
/// premium — our sessions carry songId already).
class _TimePerSong extends StatelessWidget {
  const _TimePerSong({required this.stats, required this.titles});

  final PracticeStats stats;
  final Map<String, String> titles;

  // Sequential emphasis, same validated pair as the week bars.
  static const _colors = [
    MonoPulseColors.accentOrange,
    Color(0xFFD9B49A),
    Color(0xFF8A6A50),
    MonoPulseColors.borderDefault,
  ];

  @override
  Widget build(BuildContext context) {
    final entries = stats.perSongSeconds.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(3).toList();
    final restSeconds = entries.skip(3).fold<int>(0, (sum, e) => sum + e.value);

    String name(String id) =>
        id.isEmpty ? 'Freestyle' : titles[id] ?? 'Removed song';

    final segments = [
      for (final e in top) (name(e.key), e.value),
      if (restSeconds > 0) ('Other', restSeconds),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                for (var i = 0; i < segments.length; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(
                    flex: segments[i].$2,
                    child: ColoredBox(color: _colors[i]),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: MonoPulseSpacing.sm),
        for (var i = 0; i < segments.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _colors[i],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: MonoPulseSpacing.sm),
                Expanded(
                  child: Text(
                    segments[i].$1,
                    overflow: TextOverflow.ellipsis,
                    style: MonoPulseTypography.bodySmall,
                  ),
                ),
                Text(
                  PracticeDashboardCard.formatMinutes(segments[i].$2),
                  style: MonoPulseTypography.bodySmall.copyWith(
                    color: MonoPulseColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Ideas inbox (#145): unlinked recordings captured from Home/Practice —
/// play them and link each to a song, or delete.
class _IdeasSection extends ConsumerWidget {
  const _IdeasSection({required this.songs});

  final List<Song> songs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ideas =
        ref.watch(labEntriesProvider((ideaInboxSongId, null))).asData?.value ??
        const <SongLabEntry>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: MonoPulseSpacing.sm),
          child: Text('Ideas', style: MonoPulseTypography.titleMedium),
        ),
        if (ideas.isEmpty)
          Text(
            'Riffs without a home yet — record one from Home or the Idea '
            'button below, link it to a song when it finds one.',
            style: MonoPulseTypography.bodySmall.copyWith(
              color: MonoPulseColors.textSecondary,
            ),
          )
        else
          for (final idea in ideas)
            Card(
              margin: const EdgeInsets.only(bottom: MonoPulseSpacing.xs),
              child: ListTile(
                dense: true,
                leading: const Icon(
                  Icons.mic_outlined,
                  color: MonoPulseColors.accentOrange,
                ),
                title: Text(idea.title ?? 'Idea'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (idea.body?.isNotEmpty == true)
                      Text(
                        idea.body!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (idea.attachmentIds.isNotEmpty)
                      LabAudioPlayer(url: idea.attachmentIds.first),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) => switch (v) {
                    'link' => _linkToSong(context, ref, idea),
                    'delete' => _delete(context, ref, idea),
                    _ => null,
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'link', child: Text('Link to song…')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Future<void> _linkToSong(
    BuildContext context,
    WidgetRef ref,
    SongLabEntry idea,
  ) async {
    final songId = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Link idea to song')),
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
    await linkIdeaToSong(ref, idea, songId: songId);
    if (context.mounted) {
      showAppSnackBar(context, "Idea linked — see the song's Lab timeline");
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    SongLabEntry idea,
  ) async {
    final repo = ref.read(labRepositoryProvider);
    await repo.deleteEntry(ideaInboxSongId, idea.id);
    if (context.mounted) {
      showAppSnackBar(
        context,
        'Idea deleted',
        actionLabel: 'Undo',
        onAction: () => repo.saveEntry(idea),
      );
    }
  }
}
