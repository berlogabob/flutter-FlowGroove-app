import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/api_error.dart';
import '../../models/band.dart';
import '../../models/song.dart';
import '../../models/tuner_launch_context.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/data/metronome_provider.dart';
import '../../screens/performance_sheet_screen.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/snackbar.dart';
import 'unified_item_model.dart';

/// Which action is pinned on song cards ('practice' default). Persisted.
class SongQuickActionNotifier extends Notifier<String> {
  static const prefsKey = 'songs.quick_action';

  @override
  String build() {
    unawaited(_load());
    return 'practice';
  }

  Future<void> _load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(prefsKey);
      if (saved != null) state = saved;
    } catch (_) {
      // No prefs backend (first run / tests) — the default stands.
    }
  }

  Future<void> set(String action) async {
    state = action;
    try {
      await (await SharedPreferences.getInstance()).setString(prefsKey, action);
    } catch (_) {
      // Persisting is best-effort; the in-memory choice still applies.
    }
  }
}

/// Provider for the pinned song-card quick action.
final songQuickActionProvider =
    NotifierProvider<SongQuickActionNotifier, String>(
      SongQuickActionNotifier.new,
    );

/// The song-card action set (pinned quick action + overflow menu) shared by
/// every screen that renders songs as unified item cards, so the cards behave
/// identically in the personal and band libraries.
/// Quick-action picker sheet — shared by the song-card overflow and the
/// Settings screen (#129).
Future<void> showQuickActionPicker(BuildContext context, WidgetRef ref) async {
  final current = ref.read(songQuickActionProvider);
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: RadioGroup<String>(
        groupValue: current,
        onChanged: (v) => Navigator.pop(context, v),
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Quick action'),
              subtitle: Text(
                'Sets what the pinned button on song cards does',
              ),
            ),
            for (final MapEntry(: key, : value)
                in SongCardActions.quickActions.entries)
              RadioListTile<String>(
                value: key,
                title: Text(value.$1),
                secondary: Icon(value.$2),
              ),
          ],
        ),
      ),
    ),
  );
  if (choice != null && choice != current) {
    await ref.read(songQuickActionProvider.notifier).set(choice);
    if (!context.mounted) return;
    final (label, _) = SongCardActions.quickActions[choice]!;
    showAppSnackBar(context, 'Quick action set to $label');
  }
}

mixin SongCardActions<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// Band the songs on this screen belong to; null in the personal library.
  /// Drives where the metronome/tuner persist song changes.
  String? get songActionsBandId => null;

  /// Pinned-quick-action catalog: key → (label, icon).
  static const quickActions = <String, (String, IconData)>{
    'practice': ('Metronome', Icons.speed),
    'tuner': ('Open in Tuner', Icons.tune),
    'sheet': ('Performance sheet', Icons.queue_music),
    'spotify': ('Play on Spotify', Icons.play_circle_fill),
    'band': ('Add to band…', Icons.add_to_queue),
  };

  bool _quickActionAvailable(String key, Song song, List<Band> bands) =>
      switch (key) {
        'sheet' => song.hasSheetContent,
        'spotify' => song.spotifyUrl != null,
        'band' => bands.isNotEmpty,
        _ => true,
      };

  void _runQuickAction(String key, Song song, List<Band> bands) {
    switch (key) {
      case 'tuner':
        openInTuner(song);
      case 'sheet':
        openPerformanceSheet(song);
      case 'spotify':
        unawaited(openSpotify(song));
      case 'band':
        unawaited(pickBandAndAdd(song, bands));
      default:
        openInMetronome(song);
    }
  }

  List<UnifiedItemAction> buildSongActions(
    Song song, {
    required List<Band> bands,
  }) {
    // ponytail: chosen action missing on this song (no sheet/Spotify/bands)
    // falls back to Practice rather than an empty slot.
    var quick = ref.watch(songQuickActionProvider);
    if (!_quickActionAvailable(quick, song, bands)) quick = 'practice';
    final (quickLabel, quickIcon) = quickActions[quick]!;
    return [
      IconAction(
        icon: quickIcon,
        tooltip: quickLabel,
        color: MonoPulseColors.accentOrange,
        onPressed: () => _runQuickAction(quick, song, bands),
      ),
      OverflowMenuAction(
        entries: [
          ('Metronome', Icons.speed, () => openInMetronome(song)),
          if (song.spotifyUrl != null)
            ('Play on Spotify', Icons.play_circle_fill, () => openSpotify(song)),
          if (song.hasSheetContent)
            (
              'Performance sheet',
              Icons.queue_music,
              () => openPerformanceSheet(song),
            ),
          ('Open in Tuner', Icons.tune, () => openInTuner(song)),
          if (bands.isNotEmpty)
            (
              'Add to band…',
              Icons.add_to_queue,
              () => unawaited(pickBandAndAdd(song, bands)),
            ),
          ('Quick action…', Icons.push_pin_outlined, () {
            unawaited(pickQuickAction());
          }),
        ],
      ),
    ];
  }

  /// Let the user choose which action is pinned on song cards.
  Future<void> pickQuickAction() => showQuickActionPicker(context, ref);

  /// One "Add to band…" entry instead of one per band — opens a picker.
  Future<void> pickBandAndAdd(Song song, List<Band> bands) async {
    final bandId = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final band in bands)
              ListTile(
                leading: const Icon(Icons.groups),
                title: Text(band.name),
                onTap: () => Navigator.pop(context, band.id),
              ),
          ],
        ),
      ),
    );
    if (bandId != null) await _addToBand(song, bandId);
  }

  Future<void> _addToBand(Song song, String bandId) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    try {
      await ref
          .read(songRepositoryProvider)
          .addSongToBand(
            song: song,
            bandId: bandId,
            contributorId: user.uid,
            contributorName: user.displayName ?? user.email ?? 'Unknown',
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${song.title}" to band'),
          backgroundColor: MonoPulseColors.success,
        ),
      );
    } on ApiError catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message);
    } catch (e, stackTrace) {
      final error = ApiError.fromException(e, stackTrace: stackTrace);
      if (!mounted) return;
      showAppSnackBar(context, error.message);
    }
  }

  Future<void> openSpotify(Song song) async {
    final uri = Uri.parse(song.spotifyUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void openPerformanceSheet(Song song) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PerformanceSheetScreen(
          title: song.title.trim().isEmpty ? 'Song' : song.title.trim(),
          sections: song.sections,
          song: song,
          songKey: song.ourKey,
          bpm: song.ourBPM,
          timeTop: song.accentBeats,
        ),
      ),
    );
  }

  void openInMetronome(Song song) {
    final metronome = ref.read(metronomeProvider.notifier);
    if (ref.read(metronomeProvider).isPlaying) {
      metronome.stop();
    }
    metronome.loadSongTempo(song, sourceBandId: songActionsBandId);
    context.pushNamed('metronome');
  }

  void openInTuner(Song song) {
    final user = ref.read(currentUserProvider).value;
    final bandId = songActionsBandId;
    unawaited(
      context.pushNamed<void>(
        'tuner',
        extra: TunerLaunchContext(
          song: song,
          saveSong: user == null
              ? null
              : (updatedSong) async {
                  final repo = ref.read(songRepositoryProvider);
                  if (bandId != null) {
                    // Band songs are copies — save to the band copy, not the
                    // personal library.
                    await repo.updateBandSong(updatedSong, bandId);
                  } else {
                    await repo.saveSong(updatedSong, uid: user.uid);
                    ref.invalidate(songsProvider);
                  }
                },
        ),
      ),
    );
  }
}
