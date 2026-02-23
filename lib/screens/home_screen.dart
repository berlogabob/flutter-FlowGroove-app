import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/data/data_providers.dart';
import '../providers/auth/auth_provider.dart';
import '../theme/mono_pulse_theme.dart';
import '../widgets/offline_indicator.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('RepSync')),
      body: const Column(
        children: [
          OfflineIndicator(),
          Expanded(child: HomeScreenBody()),
        ],
      ),
    );
  }
}

class HomeScreenBody extends ConsumerWidget {
  const HomeScreenBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(appUserProvider);
    final songCount = ref.watch(songCountProvider);
    final bandCount = ref.watch(bandCountProvider);
    final setlistCount = ref.watch(setlistCountProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            userAsync.when(
              data: (user) =>
                  _buildGreeting(context, user?.displayName ?? 'User'),
              loading: () => _buildGreeting(context, 'Loading...'),
              error: (error, stack) => _buildGreeting(context, 'User'),
            ),
            const SizedBox(height: 24),
            _buildStatisticsSection(
              context,
              songCount,
              bandCount,
              setlistCount,
            ),
            const SizedBox(height: MonoPulseSpacing.xxxl),
            _buildQuickActions(context),
            const SizedBox(height: MonoPulseSpacing.xxxl),
            _buildFutureTools(context),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting(BuildContext context, String name) {
    return Container(
      padding: const EdgeInsets.all(MonoPulseSpacing.lg),
      decoration: BoxDecoration(
        color: MonoPulseColors.accentOrangeSubtle,
        borderRadius: BorderRadius.circular(MonoPulseRadius.large),
        border: Border.all(color: MonoPulseColors.borderSubtle),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: MonoPulseColors.surfaceRaised,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: const TextStyle(
                fontSize: 24,
                color: MonoPulseColors.accentOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: MonoPulseSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $name!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: MonoPulseColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ready to rock?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MonoPulseColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection(
    BuildContext context,
    int songs,
    int bands,
    int setlists,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Library',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: MonoPulseColors.textPrimary,
          ),
        ),
        const SizedBox(height: MonoPulseSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.music_note,
                label: 'Songs',
                value: songs.toString(),
                color: MonoPulseColors.accentOrange,
                onTap: () => Navigator.pushNamed(context, '/songs'),
              ),
            ),
            const SizedBox(width: MonoPulseSpacing.md),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.groups,
                label: 'Bands',
                value: bands.toString(),
                color: MonoPulseColors.textSecondary,
                onTap: () => Navigator.pushNamed(context, '/bands'),
              ),
            ),
            const SizedBox(width: MonoPulseSpacing.md),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.queue_music,
                label: 'Setlists',
                value: setlists.toString(),
                color: MonoPulseColors.textSecondary,
                onTap: () => Navigator.pushNamed(context, '/setlists'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        decoration: BoxDecoration(
          color: MonoPulseColors.surface,
          borderRadius: BorderRadius.circular(MonoPulseRadius.large),
          border: Border.all(color: MonoPulseColors.borderSubtle),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: MonoPulseSpacing.md),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: MonoPulseColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: MonoPulseColors.textPrimary,
          ),
        ),
        const SizedBox(height: MonoPulseSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.add,
                label: 'Song',
                onTap: () => Navigator.pushNamed(context, '/songs/add'),
              ),
            ),
            const SizedBox(width: MonoPulseSpacing.md),
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.group_add,
                label: 'Band',
                onTap: () => Navigator.pushNamed(context, '/bands/create'),
              ),
            ),
          ],
        ),
        const SizedBox(height: MonoPulseSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.playlist_add,
                label: 'Setlist',
                onTap: () => Navigator.pushNamed(context, '/setlists/create'),
              ),
            ),
            const SizedBox(width: MonoPulseSpacing.md),
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.library_music,
                label: 'Bank',
                onTap: () => Navigator.pushNamed(context, '/songs'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: MonoPulseColors.surface,
      borderRadius: BorderRadius.circular(MonoPulseRadius.large),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MonoPulseRadius.large),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: MonoPulseSpacing.xxl),
          decoration: BoxDecoration(
            color: MonoPulseColors.surface,
            border: Border.all(color: MonoPulseColors.borderDefault),
            borderRadius: BorderRadius.circular(MonoPulseRadius.large),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: MonoPulseColors.accentOrange),
              const SizedBox(width: MonoPulseSpacing.md),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: MonoPulseColors.accentOrange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFutureTools(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tools',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: MonoPulseColors.textPrimary,
          ),
        ),
        const SizedBox(height: MonoPulseSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildFutureTool(
                context,
                icon: Icons.tune,
                label: 'Tuner',
              ),
            ),
            const SizedBox(width: MonoPulseSpacing.md),
            Expanded(
              child: _buildFutureTool(
                context,
                icon: Icons.speed,
                label: 'Metronome',
                onTap: () => Navigator.pushNamed(context, '/metronome'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFutureTool(
    BuildContext context, {
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: MonoPulseSpacing.xxl),
        decoration: BoxDecoration(
          color: onTap != null
              ? MonoPulseColors.surface
              : MonoPulseColors.surfaceOverlay,
          borderRadius: BorderRadius.circular(MonoPulseRadius.large),
          border: Border.all(color: MonoPulseColors.borderSubtle),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: onTap != null
                  ? MonoPulseColors.accentOrange
                  : MonoPulseColors.textTertiary,
            ),
            const SizedBox(width: MonoPulseSpacing.md),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: onTap != null
                    ? MonoPulseColors.accentOrange
                    : MonoPulseColors.textTertiary,
              ),
            ),
            if (onTap == null) ...[
              const SizedBox(width: MonoPulseSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MonoPulseSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: MonoPulseColors.borderStrong,
                  borderRadius: BorderRadius.circular(MonoPulseRadius.small),
                ),
                child: Text(
                  'Soon',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: MonoPulseColors.textPrimary,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
