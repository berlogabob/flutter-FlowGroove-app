import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/practice_stats_provider.dart';
import '../theme/mono_pulse_theme.dart';

/// Home dashboard card (#133): this week's practice minutes + streak with a
/// 7-day mini bar chart, computed from the metronome session log. Tapping
/// opens the Practice screen (unless [tappable] is false — the Practice
/// screen reuses the card as its own header).
class PracticeDashboardCard extends ConsumerWidget {
  const PracticeDashboardCard({super.key, this.tappable = true});

  final bool tappable;

  // Single-series chart with an emphasis accent (dataviz-validated pair):
  // today = brand orange, past days = quiet warm sand; both >= 3:1 on the
  // dark surface, deltaE 19 apart. Today is also encoded by position
  // (rightmost) and its highlighted weekday letter — never color alone.
  static const _todayBar = MonoPulseColors.accentOrange;
  static const _pastBar = MonoPulseColors.chartWarmSecondary;

  static String formatMinutes(int seconds) {
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(practiceStatsProvider);
    final stats = statsAsync.asData?.value ?? PracticeStats.empty;

    final card = Card(
      child: InkWell(
        onTap: tappable ? () => context.pushNamed('practice') : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(MonoPulseSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _headline(context, stats)),
              const SizedBox(width: MonoPulseSpacing.lg),
              _WeekBars(dailySeconds: stats.dailySeconds),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      label: stats.isEmptyWeek
          ? 'No practice yet this week. Tap to start practicing.'
          : 'Practiced ${formatMinutes(stats.totalSecondsThisWeek)} this '
                'week across ${stats.sessionCountThisWeek} sessions, '
                '${stats.streakDays} day streak.',
      button: tappable,
      child: card,
    );
  }

  Widget _headline(BuildContext context, PracticeStats stats) {
    if (stats.isEmptyWeek) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This week',
            style: MonoPulseTypography.bodySmall.copyWith(
              color: context.mp.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text('No practice yet', style: MonoPulseTypography.titleMedium),
          Text(
            tappable ? 'Tap to start' : 'Start the metronome to log time',
            style: MonoPulseTypography.bodySmall.copyWith(
              color: context.mp.textSecondary,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This week',
          style: MonoPulseTypography.bodySmall.copyWith(
            color: context.mp.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatMinutes(stats.totalSecondsThisWeek),
          style: MonoPulseTypography.headlineLarge.copyWith(
            color: context.mp.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          [
            '${stats.sessionCountThisWeek} '
                'session${stats.sessionCountThisWeek == 1 ? '' : 's'}',
            if (stats.streakDays > 1) '${stats.streakDays}-day streak 🔥',
          ].join(' · '),
          style: MonoPulseTypography.bodySmall.copyWith(
            color: context.mp.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.dailySeconds});

  final List<int> dailySeconds;

  static const _chartHeight = 44.0;
  static const _barWidth = 10.0;

  @override
  Widget build(BuildContext context) {
    final maxSeconds = dailySeconds.fold<int>(0, (m, v) => v > m ? v : m);
    final today = DateTime.now().weekday; // 1=Mon..7=Sun
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 7; i++) ...[
              if (i > 0) const SizedBox(width: 2), // surface gap between bars
              _bar(context, i, maxSeconds),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            for (var i = 0; i < 7; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              SizedBox(
                width: _barWidth,
                child: Text(
                  // dailySeconds is oldest→today; today is index 6. Dart's %
                  // is non-negative for a positive divisor.
                  letters[(today - 1 - (6 - i)) % 7],
                  textAlign: TextAlign.center,
                  style: MonoPulseTypography.bodySmall.copyWith(
                    fontSize: 9,
                    color: i == 6
                        ? MonoPulseColors.accentOrange
                        : context.mp.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _bar(BuildContext context, int index, int maxSeconds) {
    final seconds = dailySeconds[index];
    // Zero days keep a 2px baseline stub so the week reads as 7 slots.
    final height = maxSeconds == 0 || seconds == 0
        ? 2.0
        : (_chartHeight * seconds / maxSeconds).clamp(2.0, _chartHeight);
    return Container(
      width: _barWidth,
      height: height,
      decoration: BoxDecoration(
        color: seconds == 0
            ? context.mp.borderDefault
            : index == 6
            ? PracticeDashboardCard._todayBar
            : PracticeDashboardCard._pastBar,
        // Rounded data-end only; flat at the baseline.
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    );
  }
}
