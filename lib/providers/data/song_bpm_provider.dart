/// Riverpod provider for song BPM data from Spotify.
///
/// Fetches BPM (tempo) from Spotify audio features and caches it in
/// SharedPreferences with a 30-day TTL to avoid redundant API calls.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api/spotify_proxy_service.dart';

/// BPM fetch result with source tracking.
class BpmResult {
  final int? bpm;
  final BpmSource source;
  final String? error;

  const BpmResult({
    this.bpm,
    required this.source,
    this.error,
  });

  const BpmResult.loading()
      : bpm = null,
        source = BpmSource.loading,
        error = null;

  const BpmResult.error(this.error)
      : bpm = null,
        source = BpmSource.error;
}

/// Source of the BPM data.
enum BpmSource { loading, cache, spotify, error, notAvailable }

/// BPM state notifier using Riverpod family pattern.
class BpmStateNotifier extends Notifier<BpmResult> {
  late final String spotifyId;
  static const _cacheKeyPrefix = 'bpm_';
  static const _timestampKeyPrefix = 'bpm_ts_';
  static const _cacheTtlHours = 24 * 30; // 30 days

  @override
  BpmResult build() {
    // Initialized via constructor parameter
    if (spotifyId.isEmpty) {
      return const BpmResult(
        bpm: null,
        source: BpmSource.notAvailable,
      );
    }
    return const BpmResult.loading();
  }

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// Check cache and fetch if needed.
  Future<void> initAndFetch() async {
    if (spotifyId.isEmpty) return;

    final prefs = await _prefs;
    final cachedBpm = prefs.getInt('${_cacheKeyPrefix}$spotifyId');
    final cachedAt = prefs.getInt('${_timestampKeyPrefix}$spotifyId');

    if (cachedBpm != null && cachedAt != null) {
      final age = DateTime.now().millisecondsSinceEpoch - cachedAt;
      if (age < _cacheTtlHours * Duration.millisecondsPerHour) {
        state = BpmResult(
          bpm: cachedBpm,
          source: BpmSource.cache,
        );
        return;
      }
    }

    // Cache miss — fetch from Spotify
    await fetchBpm();
  }

  /// Fetch BPM from Spotify API and cache the result.
  Future<void> fetchBpm() async {
    if (spotifyId.isEmpty) {
      state = const BpmResult(
        bpm: null,
        source: BpmSource.notAvailable,
      );
      return;
    }

    state = const BpmResult.loading();

    try {
      final bpm = await SpotifyProxyService.getBpmForTrack(spotifyId);

      if (bpm != null) {
        final prefs = await _prefs;
        await prefs.setInt('${_cacheKeyPrefix}$spotifyId', bpm);
        await prefs.setInt(
          '${_timestampKeyPrefix}$spotifyId',
          DateTime.now().millisecondsSinceEpoch,
        );

        state = BpmResult(
          bpm: bpm,
          source: BpmSource.spotify,
        );
      } else {
        state = const BpmResult(
          bpm: null,
          source: BpmSource.notAvailable,
        );
      }
    } catch (e, st) {
      debugPrint('[SongBpm] Failed to fetch BPM: $e\n$st');
      state = BpmResult.error(e.toString());
    }
  }
}

/// Family provider for song BPM.
///
/// Example:
/// ```dart
/// final notifier = ref.read(bpmProviderFor('4uLU6hMCjMI75M1A2tKUQC'));
/// ```
NotifierProvider<BpmStateNotifier, BpmResult> bpmProviderFor(
  String spotifyId,
) {
  return NotifierProvider<BpmStateNotifier, BpmResult>(
    () {
      final notifier = BpmStateNotifier()..spotifyId = spotifyId;
      // Trigger async init after build
      Future.microtask(() => notifier.initAndFetch());
      return notifier;
    },
  );
}
