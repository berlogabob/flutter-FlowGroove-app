import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../providers/data/data_providers.dart';
import '../providers/auth/auth_provider.dart';
import '../models/user.dart';
import '../theme/mono_pulse_theme.dart';
import '../widgets/standard_screen_scaffold.dart';
import '../widgets/dashboard_grid.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Log screen view for analytics
    FirebaseAnalytics.instance.logScreenView(
      screenName: 'HomeScreen',
      screenClass: 'HomeScreen',
    );

    return StandardScreenScaffold(
      title: 'Home',
      showBackButton: false, // Hide back button for main tabs
      showOfflineIndicator: true,
      body: _HomeDashboard(context, ref),
    );
  }

  Widget _HomeDashboard(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(appUserProvider);
    final songCount = ref.watch(songCountProvider);
    final bandCount = ref.watch(bandCountProvider);
    final setlistCount = ref.watch(setlistCountProvider);

    return DashboardGrid(
      greetingCard: _buildGreetingCard(ref, userAsync),
      statistics: [
        StatCard(
          icon: Icons.music_note,
          label: 'Songs',
          value: songCount.toString(),
          color: MonoPulseColors.accentOrange,
          onTap: () => context.goNamed('songs'),
        ),
        StatCard(
          icon: Icons.groups,
          label: 'Bands',
          value: bandCount.toString(),
          color: MonoPulseColors.textSecondary,
          onTap: () => context.goNamed('bands'),
        ),
        StatCard(
          icon: Icons.queue_music,
          label: 'Setlists',
          value: setlistCount.toString(),
          color: MonoPulseColors.textSecondary,
          onTap: () => context.goNamed('setlists'),
        ),
      ],
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
          icon: Icons.library_music,
          label: 'Bank',
          onTap: () => context.goNamed('songs'),
        ),
      ],
      tools: [
        ToolButton(
          icon: Icons.tune,
          label: 'Tuner',
          onTap: () => context.goNamed('tuner'),
        ),
        ToolButton(
          icon: Icons.speed,
          label: 'Metronome',
          onTap: () => context.goNamed('metronome'),
        ),
      ],
    );
  }

  Widget _buildGreetingCard(WidgetRef ref, AsyncValue<AppUser?> userAsync) {
    return userAsync.when(
      data: (user) => GreetingCard(
        userName: user?.displayName ?? 'User',
        avatarPath: user?.photoURL, // Use photo URL (Telegram or Firebase)
        subtitle: 'Ready to rock?',
      ),
      loading: () => GreetingCard(userName: 'Loading...', subtitle: ''),
      error: (_, __) =>
          GreetingCard(userName: 'User', subtitle: 'Ready to rock?'),
    );
  }
}
