import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/data/data_providers.dart';
import '../utils/analytics_debug.dart';
import '../widgets/dashboard_grid.dart';
import '../widgets/practice_dashboard_card.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/standard_screen_scaffold.dart';
import '../widgets/tool_button.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Log screen view once per navigation, not on every rebuild.
    try {
      AnalyticsDebug.logScreenView(
        screenName: 'HomeScreen',
        screenClass: 'HomeScreen',
      );
    } catch (_) {}
    try {
      if (Firebase.apps.isNotEmpty) {
        FirebaseAnalytics.instance.logScreenView(
          screenName: 'HomeScreen',
          screenClass: 'HomeScreen',
        );
      }
    } catch (_) {
      // Ignore in test environment when Firebase is not initialized
    }
  }

  @override
  Widget build(BuildContext context) {
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
            QuickActionButton(
              icon: Icons.menu_book,
              label: 'Practice',
              onTap: () => context.pushNamed('practice'),
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
      ],
    );
  }

  /// Tools entry point for rehearsal schedules: one band goes straight to its
  /// schedule, several bands show a picker first.
  void _openRehearsals(BuildContext context, WidgetRef ref) {
    final bands = ref.read(bandsProvider).value ?? [];
    if (bands.isEmpty) {
      context.goNamed('bands');
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
            const ListTile(title: Text('Choose band')),
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

}
