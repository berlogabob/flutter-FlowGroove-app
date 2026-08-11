import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/data/data_providers.dart';
import '../theme/mono_pulse_theme.dart';
import '../widgets/dashboard_grid.dart';
import '../widgets/practice_dashboard_card.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/standard_screen_scaffold.dart';
import '../widgets/tool_button.dart';

/// screen_view comes from the router's FirebaseAnalyticsObserver (see
/// createAppRouter) — this screen holds no state of its own.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StandardScreenScaffold(
      title: 'Home',
      showBackButton: false, // Hide back button for main tabs
      body: _HomeDashboard(context, ref),
    );
  }

  Widget _HomeDashboard(BuildContext context, WidgetRef ref) {
    // Home leads with actions (#97): no greeting card, no stat counters —
    // the top slot carries the practice dashboard instead (#133).
    return DashboardGrid(
      greetingCard: const PracticeDashboardCard(),
      statistics: const [],
      quickActions: [
        QuickActionButton(
          icon: Icons.add,
          label: 'Song',
          onTap: () => context.goNamed('add-song'),
        ),
        QuickActionButton(
          icon: Icons.group_add,
          label: 'Band',
          onTap: () => context.goNamed('create-band'),
        ),
        QuickActionButton(
          icon: Icons.playlist_add,
          label: 'Setlist',
          onTap: () => context.goNamed('create-setlist'),
        ),
        // One tap, recording already running (#145 feedback).
        QuickActionButton(
          icon: Icons.mic,
          label: 'Audio note',
          onTap: () => context.pushNamed(
            'recorder',
            queryParameters: {'autostart': '1'},
          ),
        ),
      ],
      tools: [
        ToolButton(
          icon: Icons.tune,
          label: 'Tuner',
          onTap: () => context.pushNamed('tuner'),
        ),
        ToolButton(
          icon: Icons.speed,
          label: 'Metronome',
          onTap: () => context.pushNamed('metronome'),
        ),
        ToolButton(
          icon: Icons.event,
          label: 'Rehearsals',
          onTap: () => _openRehearsals(context, ref),
        ),
        ToolButton(
          icon: Icons.graphic_eq,
          label: 'Recorder',
          onTap: () => context.pushNamed('recorder'),
        ),
      ],
      fullWidthTool: ToolButton(
        icon: Icons.menu_book,
        label: 'Practice',
        onTap: () => context.pushNamed('practice'),
      ),
    );
  }

  /// Tools entry point for rehearsal schedules: one band goes straight to its
  /// schedule, several bands show a titled picker. Rehearsals are band-scoped,
  /// so the destination always identifies itself as "Rehearsals" rather than
  /// silently landing on the plain Bands list (UX audit F-001).
  void _openRehearsals(BuildContext context, WidgetRef ref) {
    final bands = ref.read(bandsProvider).value ?? [];
    if (bands.isEmpty) {
      _showRehearsalsEmptyState(context);
      return;
    }
    if (bands.length == 1) {
      context.goNamed(
        'band-rehearsals',
        pathParameters: {'id': bands.first.id},
        extra: bands.first,
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            _rehearsalsSheetHeader(
              sheetContext,
              subtitle: 'Rehearsals are per band — choose one to see its schedule.',
            ),
            for (final band in bands)
              ListTile(
                leading: const Icon(Icons.event),
                title: Text(band.name),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.goNamed(
                    'band-rehearsals',
                    pathParameters: {'id': band.id},
                    extra: band,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _rehearsalsSheetHeader(BuildContext context, {required String subtitle}) {
    return ListTile(
      title: const Text('Rehearsals — choose a band',
          style: MonoPulseTypography.titleMedium),
      subtitle: Text(subtitle,
          style: MonoPulseTypography.bodySmall
              .copyWith(color: context.mp.textSecondary)),
    );
  }

  void _showRehearsalsEmptyState(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MonoPulseSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Rehearsals', style: MonoPulseTypography.titleMedium),
              const SizedBox(height: MonoPulseSpacing.sm),
              Text(
                'Rehearsals are scheduled per band. Join or create a band first, '
                'then its rehearsal schedule shows up here.',
                style: MonoPulseTypography.bodySmall
                    .copyWith(color: context.mp.textSecondary),
              ),
              const SizedBox(height: MonoPulseSpacing.lg),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  context.goNamed('create-band');
                },
                icon: const Icon(Icons.group_add),
                label: const Text('Create a band'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
