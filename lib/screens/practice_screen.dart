import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/metronome_session.dart';
import '../models/song.dart';
import '../providers/data/data_providers.dart';
import '../providers/homework_provider.dart';
import '../providers/practice_stats_provider.dart';
import '../theme/mono_pulse_theme.dart';
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
              context,
              'Nothing open. Add tasks to a song from its Lab '
              '(song card → Song Lab).',
            )
          else
            for (final item in homework.take(10)) _homeworkRow(context, item),
          const SizedBox(height: MonoPulseSpacing.lg),
          _sectionTitle(context, 'Quick start'),
          Row(
            children: [
              _quickStartButton(
                context,
                icon: Icons.speed,
                label: 'Metronome',
                route: 'metronome',
              ),
              const SizedBox(width: MonoPulseSpacing.md),
              _quickStartButton(
                context,
                icon: Icons.tune,
                label: 'Tuner',
                route: 'tuner',
              ),
              const SizedBox(width: MonoPulseSpacing.md),
              _quickStartButton(
                context,
                icon: Icons.mic,
                label: 'Recorder',
                route: 'recorder',
              ),
            ],
          ),
          const SizedBox(height: MonoPulseSpacing.lg),
          _sectionTitle(context, 'Recent sessions'),
          if (sessions.isEmpty)
            _quietText(
              context,
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

  /// One-line quick-start button: FittedBox scales the label down instead
  /// of letting "Metronome"/"Recorder" wrap to two lines at phone width.
  Widget _quickStartButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
  }) => Expanded(
    // Dark surface + orange, matching the Home tool tiles, instead of the
    // Material tonal grey pill (secondaryContainer). F-005.
    child: FilledButton.icon(
      onPressed: () => context.pushNamed(route),
      style: FilledButton.styleFrom(
        backgroundColor: context.mp.surfaceRaised,
        foregroundColor: MonoPulseColors.accentOrange,
        side: BorderSide(color: context.mp.borderDefault),
      ),
      icon: Icon(icon),
      label: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)),
    ),
  );

  Widget _sectionTitle(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(bottom: MonoPulseSpacing.sm),
    child: Text(title, style: MonoPulseTypography.titleMedium),
  );

  Widget _quietText(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: MonoPulseSpacing.sm),
    child: Text(
      text,
      style: MonoPulseTypography.bodySmall.copyWith(
        color: context.mp.textSecondary,
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
                color: context.mp.textSecondary,
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
            Icon(Icons.music_note, size: 16, color: context.mp.textSecondary),
            const SizedBox(width: MonoPulseSpacing.sm),
            Expanded(child: Text(song, overflow: TextOverflow.ellipsis)),
            Text(
              '${PracticeDashboardCard.formatMinutes(s.elapsedSeconds)}'
              ' · ${s.startBpm} BPM',
              style: MonoPulseTypography.bodySmall.copyWith(
                color: context.mp.textSecondary,
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

  @override
  Widget build(BuildContext context) {
    final entries = stats.perSongSeconds.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(3).toList();
    final restSeconds = entries.skip(3).fold<int>(0, (sum, e) => sum + e.value);
    // Sequential emphasis, same validated pair as the week bars.
    final colors = [
      MonoPulseColors.accentOrange,
      MonoPulseColors.chartWarmSecondary,
      MonoPulseColors.chartWarmTertiary,
      context.mp.borderDefault,
    ];

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
                    child: ColoredBox(color: colors[i]),
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
                    color: colors[i],
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
                    color: context.mp.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
