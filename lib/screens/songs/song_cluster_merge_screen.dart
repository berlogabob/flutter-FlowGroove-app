import 'package:flutter/material.dart';

import '../../models/song.dart';
import '../../services/matching/song_merge_resolver.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../widgets/bottom_nav_or_action_bar.dart';

/// Field × song merge matrix (#81): each row is a field, each block a
/// cluster member's value — tap the block you want in the merged song.
/// Tags and links always union; the keeper (canonical/oldest) holds the
/// surviving id. Pops with the merged Song, or null on back.
class SongClusterMergeScreen extends StatefulWidget {
  const SongClusterMergeScreen({required this.songs, super.key});

  /// Cluster members, oldest first.
  final List<Song> songs;

  @override
  State<SongClusterMergeScreen> createState() => _SongClusterMergeScreenState();
}

class _SongClusterMergeScreenState extends State<SongClusterMergeScreen> {
  static const _resolver = SongMergeResolver();
  late final Song _keeper = _resolver.preferredKeeperOfMany(widget.songs);
  late final int _keeperIndex = widget.songs.indexWhere(
    (s) => s.id == _keeper.id,
  );
  late final Map<ClusterField, int> _picks = {
    for (final f in ClusterField.values) f: _keeperIndex,
  };

  static const _fieldLabels = <ClusterField, String>{
    ClusterField.title: 'Title',
    ClusterField.artist: 'Artist',
    ClusterField.originalKey: 'Original key',
    ClusterField.originalBpm: 'Original BPM',
    ClusterField.ourKey: 'Our key',
    ClusterField.ourBpm: 'Our BPM',
    ClusterField.notes: 'Notes',
    ClusterField.arrangement: 'Arrangement',
  };

  String _valueFor(ClusterField f, Song s) => switch (f) {
    ClusterField.title => s.title,
    ClusterField.artist => s.artist,
    ClusterField.originalKey => s.originalKey ?? '—',
    ClusterField.originalBpm => s.originalBPM?.toString() ?? '—',
    ClusterField.ourKey => s.ourKey ?? '—',
    ClusterField.ourBpm => s.ourBPM?.toString() ?? '—',
    ClusterField.notes =>
      (s.notes?.trim().isNotEmpty ?? false) ? s.notes!.trim() : '—',
    ClusterField.arrangement =>
      s.sections.isEmpty
          ? 'No structure'
          : '${s.sections.length} sections · ${s.accentBeats}/4',
  };

  void _merge() {
    final merged = _resolver.mergeCluster(
      widget.songs,
      keeper: _keeper,
      picks: _picks,
    );
    Navigator.pop(context, merged);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MonoPulseColors.black,
      bottomNavigationBar: AppBottomBar.actions(
        onBack: () => Navigator.pop(context),
        title: 'Merge ${widget.songs.length} songs',
        primaryAction: FilledButton(
          onPressed: _merge,
          child: const Text('Merge'),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(MonoPulseSpacing.lg),
          children: [
            Text(
              'Pick which version each field comes from. Tags and links are '
              'combined from all ${widget.songs.length} songs; the others are '
              'deleted after the merge (setlists are re-pointed).',
              style: MonoPulseTypography.bodySmall.copyWith(
                color: MonoPulseColors.textSecondary,
              ),
            ),
            const SizedBox(height: MonoPulseSpacing.lg),
            for (final f in ClusterField.values) ...[
              Text(_fieldLabels[f]!, style: MonoPulseTypography.titleMedium),
              const SizedBox(height: MonoPulseSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < widget.songs.length; i++) ...[
                      if (i > 0) const SizedBox(width: MonoPulseSpacing.sm),
                      _valueBlock(f, i),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: MonoPulseSpacing.lg),
            ],
            const SizedBox(height: 72),
          ],
        ),
      ),
    );
  }

  Widget _valueBlock(ClusterField f, int index) {
    final selected = _picks[f] == index;
    final song = widget.songs[index];
    return InkWell(
      onTap: () => setState(() => _picks[f] = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(MonoPulseSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? MonoPulseColors.accentOrange10
              : MonoPulseColors.surface,
          border: Border.all(
            color: selected
                ? MonoPulseColors.accentOrange
                : MonoPulseColors.borderDefault,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              index == _keeperIndex
                  ? 'Version ${index + 1} · keeper'
                  : 'Version ${index + 1}',
              style: MonoPulseTypography.bodySmall.copyWith(
                color: selected
                    ? MonoPulseColors.accentOrange
                    : MonoPulseColors.textTertiary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _valueFor(f, song),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: MonoPulseTypography.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
