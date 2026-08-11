import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../haptics_provider.dart';
import '../../models/beat_mode.dart';
import '../../models/metronome_preset.dart';
import '../../models/metronome_runtime_state.dart';
import '../../models/metronome_session.dart';
import '../../models/metronome_state.dart';
import '../../models/metronome_tempo_range.dart';
import '../../models/setlist.dart';
import '../../models/song.dart';
import '../../models/tempo_ramp.dart';
import '../../models/time_signature.dart';
import '../../providers/metronome_runtime_providers.dart';
import '../../providers/wakelock_provider.dart';
import '../../repositories/metronome_session_repository.dart';
import '../../services/analytics_service.dart';
import '../../services/audio/audio_focus_manager.dart';
import '../../services/metronome_preferences.dart';
import '../../services/wakelock_controller.dart';
import 'data_providers.dart';

/// Metronome Notifier class
///
/// Manages metronome state and provides methods to control it.
/// Uses Riverpod Notifier pattern for state management.
class MetronomeNotifier extends Notifier<MetronomeState> {
  /// Default constructor
  MetronomeNotifier();
  late MetronomeAudioClient _audioClient;
  late MetronomePlaybackClient _playbackClient;
  late WakelockController _wakelock;
  final TempoRampController _tempoRampController = TempoRampController();
  final MetronomeSessionRepository _sessionRepository =
      MetronomeSessionRepository();
  final MetronomePreferences _preferences = MetronomePreferences();

  Timer? _debounceTimer;
  bool _debouncePending = false;
  Timer? _rampTimer;
  MetronomeSession? _activeSession;
  Stopwatch? _sessionStopwatch;

  /// Fresh setlist+songs waiting to be applied. Set when a live update arrives
  /// while the metronome is playing; consumed on stop / next / prev so the queue
  /// doesn't reshuffle mid-rehearsal. See [syncLoadedSetlist].
  (Setlist, List<Song>)? _pendingSync;

  /// Live subscriptions to the source setlist/song providers for the loaded
  /// setlist, so reorders and tempo-map edits propagate into the loaded queue.
  ProviderSubscription<AsyncValue<List<Setlist>>>? _setlistSub;
  ProviderSubscription<AsyncValue<List<Song>>>? _songsSub;

  @override
  MetronomeState build() {
    _audioClient = ref.read(metronomeAudioClientProvider);
    _playbackClient = ref.read(metronomePlaybackClientProvider);
    _wakelock = ref.read(wakelockProvider);
    ref.onDispose(_cleanup);

    // Global haptics preference is the single source of truth (#129): the
    // engine state follows it, both now and on later Settings toggles.
    ref.listen<bool>(hapticsEnabledProvider, (_, enabled) {
      if (state.hapticsEnabled != enabled) setHapticsEnabled(enabled);
    });

    return MetronomeState.initial().copyWith(
      hapticsEnabled: ref.read(hapticsEnabledProvider),
    );
  }

  /// Start the metronome
  void start() {
    if (state.isPlaying) return;

    state = state.copyWith(
      isPlaying: true,
      currentBeat: -1, // Will be 0 on first tick
      playbackPhase: state.countInBars > 0
          ? MetronomePlaybackPhase.countIn
          : MetronomePlaybackPhase.playing,
      completedBars: 0,
    );

    _startSession();

    // Request audio focus for metronome playback
    unawaited(AudioFocusManager().requestFocus());

    unawaited(_startPlaybackSafely(initialTick: -1));

    // Enable wakelock to keep screen on during practice
    unawaited(_wakelock.enable());
  }

  /// Stop the metronome
  void stop() {
    if (!state.isPlaying) return;

    unawaited(_playbackClient.stop());

    state = state.copyWith(
      isPlaying: false,
      currentBeat: 0,
      playbackPhase: MetronomePlaybackPhase.stopped,
    );
    _finishSession(MetronomeSessionCompletion.stopped);

    // Apply any live setlist update that arrived while we were playing.
    _applyPendingSyncIfAny();

    // Release audio focus when metronome stops
    unawaited(AudioFocusManager().releaseFocus());

    // Disable wakelock when metronome stops
    unawaited(_wakelock.disable());
  }

  /// Update BPM while playing
  void setBpm(int bpm, {BpmSource source = BpmSource.manual}) {
    final clampedBpm = _clampBpm(bpm);
    if (source != BpmSource.tempoRamp) stopTempoRamp();
    state = state.copyWith(bpm: clampedBpm, bpmSource: source);
    _syncPlaybackConfig();
    _persistManualSettings();
  }

  /// Set number of BEATS (top row, first number of time signature)
  /// Examples: 4/4 → 4 beats, 2/2 → 2 beats, 6/8 → 2 beats
  /// INDEPENDENT: Does NOT affect subdivisions count
  void setAccentBeats(int count) {
    final clampedCount = count.clamp(1, 12);
    state = state.copyWith(accentBeats: clampedCount);
    _syncPlaybackConfig();
  }

  /// Set number of SUBDIVISIONS per beat (bottom row)
  /// Examples: 1 → HHHH, 2 → HlHlHlHl, 3 → HllHllHllHll
  /// Where H = High pitch (1760 Hz), l = Low pitch (880 Hz)
  /// INDEPENDENT: Does NOT affect beats count
  void setRegularBeats(int count) {
    final clampedCount = count.clamp(1, 12);
    state = state.copyWith(regularBeats: clampedCount);
    _syncPlaybackConfig();
  }

  /// Set beat mode for individual beat (normal, accent, silent)
  /// [beatIndex] - index of the beat (0-based)
  /// [subdivisionIndex] - index of the subdivision within the beat (0-based)
  /// [mode] - BeatMode (normal, accent, silent)
  void setBeatMode(int beatIndex, int subdivisionIndex, BeatMode mode) {
    final newBeatModes = List<List<BeatMode>>.from(
      state.beatModes.map(List<BeatMode>.from),
    );

    // Extend outer list if needed (add new beats)
    while (newBeatModes.length <= beatIndex) {
      newBeatModes.add([]);
    }

    // Extend inner list if needed (add subdivisions to this beat)
    while (newBeatModes[beatIndex].length <= subdivisionIndex) {
      newBeatModes[beatIndex].add(BeatMode.normal);
    }

    // Set the mode for this specific subdivision
    newBeatModes[beatIndex][subdivisionIndex] = mode;

    state = state.copyWith(beatModes: List.unmodifiable(newBeatModes));
    _syncPlaybackConfig();
  }

  /// Rotate tempo using rotary dial gesture
  void rotateTempo(double degrees) {
    final bpmChange = (degrees / 288)
        .round(); // 288 degrees = 1 BPM (4x slower than 72)
    final newBpm = _clampBpm(state.bpm + bpmChange);

    // Stop at limits - don't wrap around
    if (newBpm == state.bpm &&
        (state.bpm == MetronomeTempoRange.minimum ||
            state.bpm == MetronomeTempoRange.maximum)) {
      return; // At limit, don't update
    }

    stopTempoRamp();
    state = state.copyWith(bpm: newBpm, bpmSource: BpmSource.manual);
    _syncPlaybackConfig();
  }

  /// Fine adjustment for tempo (+1, +5, +10 buttons)
  void adjustTempoFine(int delta) {
    final newBpm = _clampBpm(state.bpm + delta);
    stopTempoRamp();
    state = state.copyWith(bpm: newBpm, bpmSource: BpmSource.manual);
    _syncPlaybackConfig();
  }

  /// Load tempo and metronome settings from a song
  void loadSongTempo(Song song, {String? sourceBandId}) {
    _cancelLiveSources();
    _pendingSync = null;
    state = state.copyWith(
      loadedSong: song,
      loadedSetlist: null,
      loadedSetlistSongs: const [],
      sourceBandId: sourceBandId,
      currentSetlistIndex: 0,
      bpmSource: BpmSource.song,
      activePresetId: null,
      activePresetName: null,
    );

    _applySongSettings(song);
  }

  void _applySongSettings(Song song, {bool resetPhase = false}) {
    // Load BPM from song (prefer ourBPM, fallback to originalBPM)
    final songBpm = song.ourBPM ?? song.originalBPM;
    if (songBpm != null) {
      final clampedBpm = _clampBpm(songBpm);
      state = state.copyWith(bpm: clampedBpm);
    }

    // Load metronome settings from song
    state = state.copyWith(
      accentBeats: song.accentBeats,
      regularBeats: song.regularBeats,
      beatModes: song.beatModes.isNotEmpty ? song.beatModes : state.beatModes,
    );

    // Update time signature to match loaded accentBeats
    final timeSignature = TimeSignature(
      numerator: song.accentBeats,
      denominator: state.timeSignature.denominator,
    );
    state = state.copyWith(timeSignature: timeSignature);

    if (resetPhase && state.isPlaying) {
      unawaited(
        _playbackClient.resetPhase(MetronomePlaybackConfig.fromState(state)),
      );
    } else {
      _syncPlaybackConfig();
    }
  }

  /// Save current metronome settings to the loaded song
  ///
  /// Returns the updated song with metronome settings applied.
  /// The caller is responsible for persisting the song to Firestore.
  Song? saveMetronomeToSong() {
    final song = state.activeSong;
    if (song == null) return null;

    // Create updated song with current metronome settings
    final updatedSong = song.copyWith(
      accentBeats: state.accentBeats,
      regularBeats: state.regularBeats,
      beatModes: state.beatModes,
      ourBPM: state.bpm, // Save current BPM as ourBPM
      updatedAt: DateTime.now(),
    );

    // Update loaded song in state
    replaceActiveSong(updatedSong);

    return updatedSong;
  }

  /// Resolve a setlist into an ordered song queue, skipping entries whose
  /// songId can't be matched in [availableSongs] instead of failing the whole
  /// queue — an unresolvable entry (deleted/unavailable song) shouldn't block
  /// the rest of the setlist from loading. Returns null only when the
  /// setlist has zero resolvable entries (empty, or every entry unresolved).
  List<Song>? _resolveQueue(Setlist setlist, List<Song>? availableSongs) {
    final items = setlist.effectiveItems;
    if (items.isEmpty) return null;

    final resolvedSongs =
        availableSongs ??
        items
            .map(
              (item) => Song(
                id: item.songId,
                title: item.songId,
                artist: '',
                createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
              ),
            )
            .toList(growable: false);
    final songsById = {for (final song in resolvedSongs) song.id: song};
    final queue = [
      for (final item in items)
        if (songsById[item.songId] case final song?) song,
    ];
    if (queue.isEmpty) return null;
    return queue;
  }

  /// Load tempo from a setlist
  bool loadSetlistQueue(
    Setlist setlist, {
    List<Song>? availableSongs,
    String? sourceBandId,
    int startIndex = 0,
  }) {
    final resolvedQueue = _resolveQueue(setlist, availableSongs);
    if (resolvedQueue == null) return false;

    _pendingSync = null;
    final index = startIndex.clamp(0, resolvedQueue.length - 1);
    state = state.copyWith(
      loadedSong: null,
      loadedSetlist: setlist,
      loadedSetlistSongs: List.unmodifiable(resolvedQueue),
      sourceBandId: sourceBandId,
      currentSetlistIndex: index,
      bpmSource: BpmSource.setlist,
      activePresetId: null,
      activePresetName: null,
    );
    _applySongSettings(resolvedQueue[index], resetPhase: true);
    _watchLiveSources(sourceBandId);
    return true;
  }

  /// Refresh the currently-loaded setlist from fresh data (e.g. a live Firestore
  /// update after a reorder or tempo-map edit). No-op unless [freshSetlist] is the
  /// setlist currently loaded. Preserves the active song by id. While playing, the
  /// update is stashed and applied on stop / next / prev to avoid reshuffling
  /// mid-rehearsal.
  void syncLoadedSetlist(Setlist freshSetlist, List<Song> freshSongs) {
    final current = state.loadedSetlist;
    if (current == null || current.id != freshSetlist.id) return;
    // Don't replace a working queue with invalid/incomplete data.
    if (_resolveQueue(freshSetlist, freshSongs) == null) return;
    if (state.isPlaying) {
      _pendingSync = (freshSetlist, freshSongs);
      return;
    }
    _applySync(freshSetlist, freshSongs);
  }

  /// Subscribe to the live setlist/song providers for [bandId] (null = personal)
  /// so changes flow into the loaded queue via [syncLoadedSetlist]. Replaces any
  /// existing subscriptions.
  void _watchLiveSources(String? bandId) {
    _cancelLiveSources();
    _setlistSub = ref.listen(
      bandId == null ? setlistsProvider : bandSetlistsProvider(bandId),
      (_, _) => _syncFromLiveSources(),
    );
    _songsSub = ref.listen(
      bandId == null ? songsProvider : bandSongsProvider(bandId),
      (_, _) => _syncFromLiveSources(),
    );
  }

  void _cancelLiveSources() {
    _setlistSub?.close();
    _songsSub?.close();
    _setlistSub = null;
    _songsSub = null;
  }

  void _syncFromLiveSources() {
    final loaded = state.loadedSetlist;
    if (loaded == null) return;
    final bandId = state.sourceBandId;
    final setlists =
        (bandId == null
                ? ref.read(setlistsProvider)
                : ref.read(bandSetlistsProvider(bandId)))
            .value;
    final songs =
        (bandId == null
                ? ref.read(songsProvider)
                : ref.read(bandSongsProvider(bandId)))
            .value;
    if (setlists == null || songs == null) return;
    final fresh = setlists.where((s) => s.id == loaded.id).firstOrNull;
    if (fresh == null) return;
    syncLoadedSetlist(fresh, songs);
  }

  void _applyPendingSyncIfAny() {
    final pending = _pendingSync;
    if (pending == null) return;
    _pendingSync = null;
    _applySync(pending.$1, pending.$2);
  }

  void _applySync(Setlist freshSetlist, List<Song> freshSongs) {
    final resolved = _resolveQueue(freshSetlist, freshSongs);
    if (resolved == null) return;

    final currentId = state.currentSetlistSong?.id;
    var index = currentId == null
        ? state.currentSetlistIndex
        : resolved.indexWhere((song) => song.id == currentId);
    if (index < 0) index = state.currentSetlistIndex;
    index = index.clamp(0, resolved.length - 1);

    // Nothing changed (same order, same per-song settings, same position).
    if (index == state.currentSetlistIndex &&
        _queueEquals(state.loadedSetlistSongs, resolved)) {
      // Metadata-only change (e.g. rename): refresh the setlist object so
      // banners show the new name, without reshuffling or resetting the
      // click (#91).
      if (state.loadedSetlist?.name != freshSetlist.name) {
        state = state.copyWith(loadedSetlist: freshSetlist);
      }
      return;
    }

    state = state.copyWith(
      loadedSetlist: freshSetlist,
      loadedSetlistSongs: List.unmodifiable(resolved),
      currentSetlistIndex: index,
      bpmSource: BpmSource.setlist,
    );
    _applySongSettings(resolved[index], resetPhase: true);
  }

  bool _queueEquals(List<Song> a, List<Song> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.id != y.id ||
          x.ourBPM != y.ourBPM ||
          x.originalBPM != y.originalBPM ||
          x.accentBeats != y.accentBeats ||
          x.regularBeats != y.regularBeats ||
          !_beatModesEqual(x.beatModes, y.beatModes)) {
        return false;
      }
    }
    return true;
  }

  bool _beatModesEqual(List<List<BeatMode>> a, List<List<BeatMode>> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!listEquals(a[i], b[i])) return false;
    }
    return true;
  }

  /// Move to next song in setlist
  void nextSetlistSong() {
    // Apply any pending live update first so we navigate within the new order.
    _applyPendingSyncIfAny();
    if (!state.canGoToNextSetlistSong) return;
    _activateSetlistSong(state.currentSetlistIndex + 1);
  }

  /// Move to previous song in setlist
  void previousSetlistSong() {
    _applyPendingSyncIfAny();
    if (!state.canGoToPreviousSetlistSong) return;
    _activateSetlistSong(state.currentSetlistIndex - 1);
  }

  void _activateSetlistSong(int index) {
    final song = state.loadedSetlistSongs[index];
    _finishSession(MetronomeSessionCompletion.navigated);
    state = state.copyWith(
      currentSetlistIndex: index,
      bpmSource: BpmSource.setlist,
    );
    _applySongSettings(song, resetPhase: true);
    if (state.isPlaying) _startSession();
  }

  /// Clear loaded song/setlist
  void clearLoadedContent() {
    _cancelLiveSources();
    _pendingSync = null;
    state = state.copyWith(
      loadedSong: null,
      loadedSetlist: null,
      loadedSetlistSongs: const [],
      sourceBandId: null,
      currentSetlistIndex: 0,
    );
  }

  void replaceActiveSong(Song updatedSong) {
    if (state.loadedSetlist != null) {
      final queue = List<Song>.from(state.loadedSetlistSongs);
      if (state.currentSetlistIndex < queue.length) {
        queue[state.currentSetlistIndex] = updatedSong;
        state = state.copyWith(loadedSetlistSongs: List.unmodifiable(queue));
      }
      return;
    }
    state = state.copyWith(loadedSong: updatedSong);
  }

  /// Set tempo directly
  void setTempoDirectly(int bpm) {
    setBpm(bpm);
  }

  /// Update beats per measure (backward compatibility)
  void setBeatsPerMeasure(int beats) {
    final timeSignature = TimeSignature(
      numerator: beats,
      denominator: state.timeSignature.denominator,
    );

    // Auto-generate new accent pattern
    List<bool> accentPattern;
    if (beats == 6 && timeSignature.denominator == 8) {
      accentPattern = [true, true];
    } else {
      accentPattern = List.generate(beats, (index) => index == 0);
    }

    state = state.copyWith(
      timeSignature: timeSignature,
      accentBeats: beats,
      accentPattern: accentPattern,
    );
    _syncPlaybackConfig();
  }

  /// Set time signature with numerator and denominator
  void setTimeSignature(TimeSignature ts) {
    int beatCount;
    List<bool> accentPattern;

    // Special handling for 6/8: 2 beats with subdivisions
    if (ts.numerator == 6 && ts.denominator == 8) {
      beatCount = 2;
      accentPattern = [true, true];
    } else {
      beatCount = ts.numerator;
      accentPattern = List.generate(beatCount, (index) => index == 0);
    }

    state = state.copyWith(
      timeSignature: ts,
      accentBeats: beatCount,
      accentPattern: accentPattern,
    );
    _syncPlaybackConfig();
  }

  /// Set wave type
  void setWaveType(String type) {
    state = state.copyWith(waveType: type);
    _syncPlaybackConfig();
  }

  /// Set volume
  void setVolume(double volume) {
    final clampedVolume = volume.clamp(0.0, 1.0);
    state = state.copyWith(volume: clampedVolume);
    _syncPlaybackConfig();
  }

  /// Toggle accent enabled
  void toggleAccent() {
    state = state.copyWith(accentEnabled: !state.accentEnabled);
    _syncPlaybackConfig();
  }

  /// Set accent enabled state
  void setAccentEnabled(bool enabled) {
    state = state.copyWith(accentEnabled: enabled);
    _syncPlaybackConfig();
  }

  /// Set accent frequency
  void setAccentFrequency(double frequency) {
    state = state.copyWith(accentFrequency: frequency);
    _syncPlaybackConfig();
  }

  /// Set beat frequency
  void setBeatFrequency(double frequency) {
    state = state.copyWith(beatFrequency: frequency);
    _syncPlaybackConfig();
  }

  /// Set the marked-accent (cyan) cell frequency.
  void setAccentBeatFrequency(double frequency) {
    state = state.copyWith(accentBeatFrequency: frequency);
    _syncPlaybackConfig();
  }

  /// Set the relative loudness of subdivision clicks.
  void setSubdivisionGain(double gain) {
    state = state.copyWith(subdivisionGain: gain.clamp(0.5, 2.0));
    _syncPlaybackConfig();
  }

  /// Toggle synchronized haptic feedback during playback.
  void toggleHaptics() {
    setHapticsEnabled(!state.hapticsEnabled);
  }

  /// Set synchronized haptic feedback during playback. Writes through to the
  /// global haptics preference (#129) so Settings and the Sound sheet agree.
  void setHapticsEnabled(bool enabled) {
    state = state.copyWith(hapticsEnabled: enabled);
    _syncPlaybackConfig();
    if (ref.read(hapticsEnabledProvider) != enabled) {
      ref.read(hapticsEnabledProvider.notifier).set(enabled);
    }
  }

  /// Set accent pattern
  void setAccentPattern(List<bool> pattern) {
    state = state.copyWith(accentPattern: List.unmodifiable(pattern));
  }

  /// Set count-in bars (0 = off, 1-4 = number of bars to count in)
  void setCountInBars(int bars) {
    final clampedBars = bars.clamp(0, 4);
    state = state.copyWith(countInBars: clampedBars);
    _syncPlaybackConfig();
    _persistManualSettings();
  }

  void setVisualFlashEnabled(bool enabled) {
    state = state.copyWith(visualFlashEnabled: enabled);
    _persistManualSettings();
  }

  void applyPreset(MetronomePreset preset) {
    stopTempoRamp();
    state = state.copyWith(
      bpm: _clampBpm(preset.bpm),
      bpmSource: BpmSource.preset,
      timeSignature: preset.timeSignature,
      accentBeats: preset.timeSignature.numerator,
      regularBeats: preset.subdivisions,
      beatModes: preset.beatModes,
      waveType: preset.waveType,
      accentEnabled: preset.accentEnabled,
      volume: preset.volume.clamp(0.0, 1.0),
      countInBars: preset.countInBars.clamp(0, 8),
      visualFlashEnabled: preset.visualFlashEnabled,
      hapticsEnabled: preset.hapticsEnabled,
      activePresetId: preset.id,
      activePresetName: preset.name,
    );
    _syncPlaybackConfig();
    unawaited(_preferences.saveLastPresetId(preset.id));
  }

  void startTempoRamp(TempoRamp ramp) {
    final bpm = _tempoRampController.start(ramp);
    state = state.copyWith(
      bpm: bpm,
      bpmSource: BpmSource.tempoRamp,
      activeTempoRamp: ramp,
    );
    _rampTimer?.cancel();
    if (ramp.cadence == TempoRampCadence.seconds) {
      _rampTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        final next = _tempoRampController.onSecond(state.bpm);
        if (next != null) _applyRampBpm(next);
      });
    }
    _syncPlaybackConfig();
  }

  void stopTempoRamp() {
    _rampTimer?.cancel();
    _rampTimer = null;
    _tempoRampController.stop();
    if (state.activeTempoRamp != null) {
      state = state.copyWith(activeTempoRamp: null);
    }
  }

  void _applyRampBpm(int bpm) {
    state = state.copyWith(
      bpm: _clampBpm(bpm),
      bpmSource: BpmSource.tempoRamp,
      activeTempoRamp: _tempoRampController.activeRamp,
    );
    _syncPlaybackConfig();
  }

  /// Update accent pattern from time signature
  void updateAccentPatternFromTimeSignature() {
    final ts = state.timeSignature;
    List<bool> accentPattern;

    if (ts.numerator == 6 && ts.denominator == 8) {
      accentPattern = [true, true];
    } else {
      accentPattern = List.generate(ts.numerator, (index) => index == 0);
    }

    state = state.copyWith(accentPattern: accentPattern);
  }

  /// Play test sound
  Future<void> playTest() async {
    await _audioClient.playTest();
  }

  /// Toggle play/stop
  void toggle() {
    if (state.isPlaying) {
      stop();
    } else {
      start();

      // Log analytics event when starting metronome
      AnalyticsService.logMetronomeStarted(
        bpm: state.bpm,
        timeSignature:
            '${state.timeSignature.numerator}/${state.timeSignature.denominator}',
        subdivision: state.regularBeats,
      );
    }
  }

  /// Dispose resources when the provider is destroyed
  void dispose() {
    _cleanup();
  }

  int _clampBpm(int bpm) {
    return MetronomeTempoRange.clamp(bpm);
  }

  Future<void> _startPlaybackSafely({required int initialTick}) async {
    try {
      await _ensureNotificationPermission();
      await _playbackClient.start(
        MetronomePlaybackConfig.fromState(state),
        onTick: _handlePlaybackTick,
        onStopped: _handlePlaybackStopped,
        initialTick: initialTick,
      );
    } catch (error) {
      debugPrint('[MetronomeNotifier] Playback start failed: $error');
    }
  }

  /// Best-effort: ask for POST_NOTIFICATIONS on Android 13+ so the foreground
  /// service notification is visible. A denied permission does NOT block
  /// playback — the service still runs. Any plugin/platform failure (e.g. no
  /// platform binding in a unit test, or a transient channel error) is
  /// swallowed here so it never prevents `_playbackClient.start(...)` from
  /// running.
  Future<void> _ensureNotificationPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final status = await Permission.notification.status;
      if (status.isDenied) {
        await Permission.notification.request();
      }
    } catch (error) {
      debugPrint(
        '[MetronomeNotifier] Notification permission check failed: $error',
      );
    }
  }

  Future<void> _updatePlaybackSafely() async {
    try {
      await _playbackClient.update(MetronomePlaybackConfig.fromState(state));
    } catch (error) {
      debugPrint('[MetronomeNotifier] Playback update failed: $error');
    }
  }

  void _syncPlaybackConfig() {
    if (!state.isPlaying) return;
    if (_debouncePending) return;
    _debouncePending = true;
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      _debouncePending = false;
      unawaited(_updatePlaybackSafely());
    });
    // Also schedule a microtask to flush after the current frame,
    // so that single calls are processed promptly.
    Future<void>.microtask(() {
      if (_debounceTimer?.isActive ?? false) {
        _debounceTimer?.cancel();
        _debouncePending = false;
        unawaited(_updatePlaybackSafely());
      }
    });
  }

  void _handlePlaybackTick(MetronomePlaybackTick tick) {
    if (!state.isPlaying) return;
    var completedBars = state.completedBars;
    if (tick.index == 0 && state.currentBeat > 0) {
      completedBars++;
      final next = _tempoRampController.onBar(state.bpm);
      if (next != null) _applyRampBpm(next);
    }
    state = state.copyWith(
      currentBeat: tick.index,
      completedBars: completedBars,
      playbackPhase: tick.isCountIn
          ? MetronomePlaybackPhase.countIn
          : MetronomePlaybackPhase.playing,
    );
  }

  void _handlePlaybackStopped() {
    if (!state.isPlaying) return;
    state = state.copyWith(isPlaying: false, currentBeat: 0);
    _finishSession(MetronomeSessionCompletion.playbackError);
    unawaited(_wakelock.disable());
  }

  void _cleanup() {
    _cancelLiveSources();
    _debounceTimer?.cancel();
    _rampTimer?.cancel();
    _debounceTimer = null;
    unawaited(_playbackClient.stop());
    unawaited(AudioFocusManager().releaseFocus());
    if (!_wakelock.isDisposed && _wakelock.isEnabled) {
      unawaited(_wakelock.disable());
    }
    _activeSession = null;
    _sessionStopwatch = null;
  }

  void _startSession() {
    _sessionStopwatch = Stopwatch()..start();
    _activeSession = MetronomeSession(
      id: const Uuid().v4(),
      startedAt: DateTime.now(),
      presetId: state.activePresetId,
      songId: state.activeSong?.id,
      setlistId: state.loadedSetlist?.id,
      startBpm: state.bpm,
      usedCountIn: state.countInBars > 0,
      usedTempoRamp: state.activeTempoRamp != null,
      usedTapTempo: state.bpmSource == BpmSource.tapTempo,
    );
  }

  void _finishSession(MetronomeSessionCompletion completion) {
    final session = _activeSession;
    final stopwatch = _sessionStopwatch;
    if (session == null || stopwatch == null) return;
    stopwatch.stop();
    AnalyticsService.logPracticeSession(lengthMs: stopwatch.elapsedMilliseconds);
    _activeSession = null;
    _sessionStopwatch = null;
    final completedSession = MetronomeSession(
      id: session.id,
      startedAt: session.startedAt,
      endedAt: DateTime.now(),
      presetId: session.presetId,
      songId: session.songId,
      setlistId: session.setlistId,
      startBpm: session.startBpm,
      endBpm: state.bpm,
      elapsedSeconds: stopwatch.elapsed.inSeconds,
      barCount: state.completedBars,
      usedTapTempo: session.usedTapTempo,
      usedTempoRamp: session.usedTempoRamp || state.activeTempoRamp != null,
      usedCountIn: session.usedCountIn,
      completion: completion,
    );
    unawaited(_saveSessionSafely(completedSession));
  }

  Future<void> _saveSessionSafely(MetronomeSession session) async {
    // Signed-out and the read-only demo account both fail the write; swallow
    // it rather than surfacing an error over a finished practice session.
    try {
      await _sessionRepository.save(session);
    } catch (error) {
      debugPrint('Unable to persist metronome session: $error');
    }
  }

  void _persistManualSettings() {
    // Tap tempo is as deliberate as typing a number — persist it too. Only
    // transient sources (song load, setlist, tempo ramp) skip the prefs.
    if (state.bpmSource != BpmSource.manual &&
        state.bpmSource != BpmSource.tapTempo) {
      return;
    }
    unawaited(
      _saveManualSettingsSafely(<String, dynamic>{
        'bpm': state.bpm,
        'accentBeats': state.accentBeats,
        'regularBeats': state.regularBeats,
        'waveType': state.waveType,
        'volume': state.volume,
        'countInBars': state.countInBars,
        'hapticsEnabled': state.hapticsEnabled,
        'visualFlashEnabled': state.visualFlashEnabled,
      }),
    );
  }

  Future<void> _saveManualSettingsSafely(Map<String, dynamic> settings) async {
    if (!MetronomePreferences.storageReady) return;
    try {
      await _preferences.saveManualSettings(settings);
    } catch (error) {
      debugPrint('Unable to persist metronome settings: $error');
    }
  }
}

/// NotifierProvider for metronome state management
final metronomeProvider = NotifierProvider<MetronomeNotifier, MetronomeState>(
  () {
    return MetronomeNotifier();
  },
);
