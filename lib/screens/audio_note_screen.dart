import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/audio_region.dart';
import '../models/song_lab.dart';
import '../providers/data/data_providers.dart';
import '../router/app_router.dart';
import '../services/audio/audio_file_cache.dart';
import '../services/audio/audio_note_edit.dart';
import '../services/audio/m4a_muxer.dart';
import '../services/audio/mp3_encoder.dart';
import '../theme/mono_pulse_theme.dart';
import '../utils/snackbar.dart';
import '../widgets/app_menu_sheet.dart';
import '../widgets/audio/waveform_painter.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/tools/tool_scaffold.dart';

/// The audio note editor: trim the dead air off a take, see its waveform, hang
/// timestamped comments off it, and send it to a messenger.
///
/// Trimming is only offered for WAV takes — every recording made by this app
/// since the WAV switch. Legacy m4a and attached files still play, seek and
/// carry comments; they just can't be sliced (see [trimWav]).
class AudioNoteScreen extends ConsumerStatefulWidget {
  const AudioNoteScreen({
    required this.entry,
    this.bandId,
    @visibleForTesting this.player,
    super.key,
  });

  final SongLabEntry entry;
  final String? bandId;

  /// Test seam — a real [AudioPlayer] needs platform plugins.
  final AudioPlayer? player;

  @override
  ConsumerState<AudioNoteScreen> createState() => _AudioNoteScreenState();
}

class _AudioNoteScreenState extends ConsumerState<AudioNoteScreen> {
  late AudioPlayer _player;
  late SongLabEntry _entry;
  late final TextEditingController _title;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;

  /// Trim window as fractions of the whole take; (0, 1) means untrimmed.
  double _trimStart = 0;
  double _trimEnd = 1;

  /// Blocks the transport while bytes are moving, so a double-tap can't fire
  /// two uploads at the same object.
  bool _busy = false;

  final List<StreamSubscription<dynamic>> _subs = [];

  String? get _url =>
      _entry.attachmentIds.isEmpty ? null : _entry.attachmentIds.first;

  bool get _canTrim =>
      _entry.peaks.isNotEmpty && trimmableExtensions.contains(_extOf(_url));

  bool get _isTrimmed => _trimStart > 0.001 || _trimEnd < 0.999;

  int get _trimStartMs => (_trimStart * _duration.inMilliseconds).round();
  int get _trimEndMs => (_trimEnd * _duration.inMilliseconds).round();

  List<AudioMarker> get _markers => parseMarkers(_entry.body);

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _title = TextEditingController(text: _entry.title ?? '');
    _player = widget.player ?? AudioPlayer();
    unawaited(_load());
    // Independent of the player: a take whose audio won't load should still
    // get its waveform, and the backfill has nothing to wait for.
    unawaited(_backfillPeaks());
  }

  Future<Uint8List> _readAudioBytes(String url) async {
    final fetch = ref.read(audioBytesFetcherProvider);
    try {
      final file = await audioFileCache(url, fetch);
      if (file != null) return await file.readAsBytes();
    } catch (_) {}
    return fetch(url);
  }

  Future<Duration?> _setAudioSource(String url) async {
    try {
      final file = await audioFileCache(
        url,
        ref.read(audioBytesFetcherProvider),
      );
      if (file != null) return await _player.setFilePath(file.path);
    } catch (_) {}
    return _player.setUrl(url);
  }

  Future<void> _deleteReplacedAudio(String url) async {
    try {
      final pending = ref.read(pendingStorageDeletesProvider);
      await pending.enqueue(url);
      await pending.flush(url);
    } catch (_) {
      // A failed deletion stays queued for the next sweep.
    }
  }

  Future<void> _load() async {
    final url = _url;
    if (url == null) return;
    try {
      final duration = await _setAudioSource(url);
      if (!mounted) return;
      setState(() => _duration = duration ?? Duration.zero);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, "Couldn't load audio: $e", error: true);
      }
      return;
    }
    _subs.addAll([
      // setUrl only returns a duration when the platform already knows one.
      // Without this the readout can sit at 0:00 and the trim range collapses
      // to nothing, because every offset is a fraction of the duration.
      _player.durationStream.listen((d) {
        if (!mounted || d == null || d == _duration) return;
        setState(() => _duration = d);
      }),
      _player.positionStream.listen((p) {
        if (!mounted) return;
        setState(() => _position = p);
        // Preview honours the trim handles without reloading the source on
        // every drag: just stop at the out point.
        if (_playing && _isTrimmed && p.inMilliseconds >= _trimEndMs) {
          unawaited(_player.pause());
          unawaited(_player.seek(Duration(milliseconds: _trimStartMs)));
        }
      }),
      _player.playerStateStream.listen((s) {
        if (!mounted) return;
        setState(() => _playing = s.playing);
      }),
    ]);
  }

  /// Gives takes recorded before peaks existed a waveform, once.
  ///
  /// Costs a download, so it only runs when there's something to gain: no
  /// stored peaks, and a WAV (AAC would need decoding, and legacy m4a can't be
  /// trimmed anyway so a waveform would only promise something it can't do).
  /// Silent on failure — this is a nicety, not a feature.
  Future<void> _backfillPeaks() async {
    final url = _url;
    if (url == null || _entry.peaks.isNotEmpty) return;
    if (_extOf(url) != 'wav') return;
    try {
      final bytes = await _readAudioBytes(url);
      final peaks = peaksFromWav(bytes);
      if (peaks == null || peaks.isEmpty || !mounted) return;
      await _save(_entry.copyWith(peaks: peaks));
    } catch (_) {
      // Offline, CORS, a truncated object — the plain slider still works.
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _player.dispose();
    _title.dispose();
    super.dispose();
  }

  // --- persistence -------------------------------------------------------

  Future<void> _save(SongLabEntry updated) async {
    setState(() => _entry = updated);
    await ref
        .read(labRepositoryProvider)
        .saveEntry(updated, bandId: widget.bandId);
  }

  Future<void> _saveTitle() async {
    final text = _title.text.trim();
    if (text == (_entry.title ?? '')) return;
    await _save(_entry.copyWith(title: text.isEmpty ? null : text));
  }

  // --- transport ---------------------------------------------------------

  Future<void> _togglePlay() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    final pos = _position.inMilliseconds;
    if (_isTrimmed && (pos < _trimStartMs || pos >= _trimEndMs)) {
      await _player.seek(Duration(milliseconds: _trimStartMs));
    } else if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    unawaited(_player.play());
  }

  Future<void> _seekTo(int ms) => _player.seek(
    Duration(milliseconds: ms.clamp(0, _duration.inMilliseconds)),
  );

  // --- markers -----------------------------------------------------------

  Future<void> _addMarkerAtPlayhead() async {
    final controller = TextEditingController();
    final at = _position.inMilliseconds;
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.mp.surface,
        title: Text(
          'Note at ${formatTimestamp(at, padMinutes: false)}',
          style: TextStyle(color: dialogContext.mp.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. good chorus entry',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty) return;
    await _save(
      _entry.copyWith(
        body: formatMarkers(
          upsertMarker(_markers, (ms: at, text: text.trim())),
          keepTextFrom: _entry.body,
        ),
      ),
    );
  }

  Future<void> _deleteMarker(AudioMarker marker) async {
    final kept = [..._markers]..removeWhere((m) => m.ms == marker.ms);
    await _save(
      _entry.copyWith(body: formatMarkers(kept, keepTextFrom: _entry.body)),
    );
  }

  // --- destructive actions -----------------------------------------------

  Future<void> _saveTrim() async {
    final url = _url;
    if (url == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const ConfirmationDialog(
        title: 'Save trim?',
        message:
            'This replaces the original recording. The part outside the '
            'handles is gone for good.',
        confirmLabel: 'Trim',
        icon: Icons.content_cut,
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final startMs = _trimStartMs;
      final endMs = _trimEndMs;
      final bytes = await _readAudioBytes(url);
      final trimmed = trimAudio(bytes, startMs: startMs, endMs: endMs);
      if (trimmed == null) {
        if (mounted) {
          showAppSnackBar(
            context,
            "This take's format can't be trimmed",
            error: true,
          );
        }
        return;
      }
      final ext = _extOf(url);
      final newUrl = await ref
          .read(storageServiceProvider)
          .uploadLabAudio(
            trimmed,
            bandId: widget.bandId,
            songId: _entry.songId,
            entryId: _entry.id,
            objectSuffix: const Uuid().v4(),
            ext: ext,
            contentType: _mimeOf(ext),
          );
      final newDurationMs = audioDurationMs(trimmed) ?? (endMs - startMs);
      await _save(
        _entry.copyWith(
          attachmentIds: [newUrl],
          body: formatMarkers(
            shiftMarkers(_markers, startMs: startMs, durationMs: newDurationMs),
            keepTextFrom: _entry.body,
          ),
          peaks: trimPeaks(_entry.peaks, _trimStart, _trimEnd),
          regions: cropRegions(_entry.regions, startMs: startMs, endMs: endMs),
          grid: _entry.grid == null ? null : cropGrid(_entry.grid!, startMs),
        ),
      );
      await _deleteReplacedAudio(url);
      if (!mounted) return;
      setState(() {
        _trimStart = 0;
        _trimEnd = 1;
        _position = Duration.zero;
      });
      await _setAudioSource(newUrl);
      if (!mounted) return;
      setState(() => _duration = Duration(milliseconds: newDurationMs));
      showAppSnackBar(context, 'Trimmed');
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Trim failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Cuts the take in two at the playhead: this entry keeps the first part,
  /// a new entry gets the rest (a rehearsal recording → one take per song).
  Future<void> _splitAtPlayhead() async {
    final url = _url;
    final at = _position.inMilliseconds;
    final total = _duration.inMilliseconds;
    if (url == null || _busy || !_canTrim) return;
    if (at < 1000 || total - at < 1000) {
      showAppSnackBar(context, 'Move the playhead into the take to split it');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmationDialog(
        title: 'Split at ${formatTimestamp(at, padMinutes: false)}?',
        message:
            'This take keeps the part before the playhead; the rest becomes '
            'a new recording with its own notes.',
        confirmLabel: 'Split',
        icon: Icons.call_split,
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _player.pause();
      final bytes = await _readAudioBytes(url);
      final first = trimAudio(bytes, startMs: 0, endMs: at);
      final rest = trimAudio(bytes, startMs: at, endMs: total);
      if (first == null || rest == null) {
        if (mounted) {
          showAppSnackBar(
            context,
            "This take's format can't be split",
            error: true,
          );
        }
        return;
      }
      final ext = _extOf(url);
      final storage = ref.read(storageServiceProvider);
      final restId = const Uuid().v4();
      final restUrl = await storage.uploadLabAudio(
        rest,
        bandId: widget.bandId,
        songId: _entry.songId,
        entryId: restId,
        ext: ext,
        contentType: _mimeOf(ext),
      );
      final restMs = audioDurationMs(rest) ?? total - at;
      final split = at / total;
      final now = DateTime.now();
      await ref
          .read(labRepositoryProvider)
          .saveEntry(
            SongLabEntry(
              id: restId,
              songId: _entry.songId,
              bandId: _entry.bandId,
              type: _entry.type,
              title: '${_entry.title ?? 'Audio note'} (2)',
              body: formatMarkers(
                shiftMarkers(_markers, startMs: at, durationMs: restMs),
                keepTextFrom: _entry.body,
              ),
              authorId: _entry.authorId,
              visibility: _entry.visibility,
              createdAt: now,
              updatedAt: now,
              attachmentIds: [restUrl],
              peaks: trimPeaks(_entry.peaks, split, 1),
              regions: cropRegions(_entry.regions, startMs: at, endMs: total),
              grid: _entry.grid == null ? null : cropGrid(_entry.grid!, at),
            ),
            bandId: widget.bandId,
          );
      final firstUrl = await storage.uploadLabAudio(
        first,
        bandId: widget.bandId,
        songId: _entry.songId,
        entryId: _entry.id,
        objectSuffix: const Uuid().v4(),
        ext: ext,
        contentType: _mimeOf(ext),
      );
      final firstMs = audioDurationMs(first) ?? at;
      await _save(
        _entry.copyWith(
          attachmentIds: [firstUrl],
          body: formatMarkers(
            shiftMarkers(_markers, startMs: 0, durationMs: firstMs),
            keepTextFrom: _entry.body,
          ),
          peaks: trimPeaks(_entry.peaks, 0, split),
          regions: cropRegions(_entry.regions, startMs: 0, endMs: at),
        ),
      );
      await _deleteReplacedAudio(url);
      if (!mounted) return;
      setState(() {
        _trimStart = 0;
        _trimEnd = 1;
        _position = Duration.zero;
      });
      await _setAudioSource(firstUrl);
      if (!mounted) return;
      setState(() => _duration = Duration(milliseconds: firstMs));
      showAppSnackBar(context, 'Split — the rest is a new recording');
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Split failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    final url = _url;
    if (url == null || _busy) return;
    setState(() => _busy = true);
    try {
      var bytes = await _readAudioBytes(url);
      var ext = _extOf(url);
      // Share what the handles show, even if the trim was never committed.
      // The format is unchanged by trimming, so the extension stays put.
      if (_isTrimmed) {
        final trimmed = trimAudio(
          bytes,
          startMs: _trimStartMs,
          endMs: _trimEndMs,
        );
        if (trimmed != null) bytes = trimmed;
      }
      // Messengers show raw AAC as a grey document; the same frames in an MP4
      // box get a player. Returns null for anything that isn't ADTS, so legacy
      // m4a and wav takes fall through untouched.
      final m4a = m4aFromAdts(bytes, title: _entry.title, artist: 'FlowGroove');
      if (m4a != null) {
        bytes = m4a;
        ext = 'm4a';
      } else {
        // Web records WAV, which is also a document everywhere. No browser can
        // encode AAC universally (Firefox and desktop Linux have none), so MP3
        // is the format that reaches everyone. Null on native and for anything
        // that isn't WAV, leaving those takes exactly as they were.
        final mp3 = await encodeWavToMp3(bytes);
        if (mp3 != null) {
          bytes = mp3;
          ext = 'mp3';
        }
      }
      final name = '${_safeName(_entry.title ?? 'audio note')}.$ext';
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, name: name, mimeType: _mimeOf(ext))],
          // io ignores XFile.name; this is what actually names the file.
          fileNameOverrides: [name],
          subject: _entry.title ?? 'Audio note',
        ),
      );
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Share failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Extension of the stored object. Download URLs percent-encode the path
  /// separators but leave `.ext` intact, so a plain suffix match works.
  /// Empty for a missing URL, which no format matches.
  static String _extOf(String? url) {
    if (url == null) return '';
    final match = RegExp(r'\.(\w{1,5})\?').firstMatch(url);
    return match?.group(1)?.toLowerCase() ?? '';
  }

  static String _mimeOf(String ext) => switch (ext) {
    'm4a' => 'audio/mp4', // RFC 4337; what a messenger checks for playback
    'aac' => 'audio/aac',
    'wav' => 'audio/wav',
    'mp3' => 'audio/mpeg',
    'ogg' => 'audio/ogg',
    'flac' => 'audio/flac',
    _ => 'audio/mp4',
  };

  static String _safeName(String s) {
    final cleaned = s.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    return cleaned.isEmpty ? 'audio note' : cleaned;
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const ConfirmationDialog(
        title: 'Delete recording?',
        message:
            'The audio and its notes are gone for good — there is no undo '
            'from here.',
        confirmLabel: 'Delete',
      ),
    );
    if (confirmed != true || !mounted) return;
    final url = _url;
    await ref
        .read(labRepositoryProvider)
        .deleteEntry(_entry.songId, _entry.id, bandId: widget.bandId);
    // No undo on this path, so the bytes can go with the document. Queued
    // first, so a failure here is retried at the next launch instead of
    // leaking the object.
    if (url != null) {
      final pending = ref.read(pendingStorageDeletesProvider);
      await pending.enqueue(url);
      unawaited(pending.flush(url));
    }
    if (!mounted) return;
    context.pop();
  }

  // --- ui ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final markers = _markers;
    final active = activeMarkerIndex(markers, _position.inMilliseconds);

    return ToolScreenScaffold(
      title: 'Audio note',
      menuItems: [
        AppMenuItem(
          icon: Icons.repeat,
          label: 'Practice regions',
          onTap: () => context.goPracticeRegions(_entry, bandId: widget.bandId),
        ),
        AppMenuItem(
          icon: Icons.add_comment_outlined,
          label: 'Add note at playhead',
          onTap: _addMarkerAtPlayhead,
        ),
        if (_canTrim)
          AppMenuItem(
            icon: Icons.call_split,
            label: 'Split at playhead',
            onTap: _splitAtPlayhead,
          ),
        AppMenuItem(
          icon: Icons.delete_outline,
          label: 'Delete recording',
          destructive: true,
          onTap: _delete,
        ),
      ],
      mainWidget: ListView(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        children: [
          TextField(
            controller: _title,
            style: MonoPulseTypography.titleLarge,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _saveTitle(),
            onTapOutside: (_) {
              FocusScope.of(context).unfocus();
              unawaited(_saveTitle());
            },
          ),
          const SizedBox(height: MonoPulseSpacing.lg),
          _buildScrubber(markers),
          const SizedBox(height: MonoPulseSpacing.sm),
          _buildTransport(),
          if (_canTrim && _isTrimmed) ...[
            const SizedBox(height: MonoPulseSpacing.md),
            FilledButton.icon(
              onPressed: _busy ? null : _saveTrim,
              style: FilledButton.styleFrom(
                backgroundColor: MonoPulseColors.accentOrange,
              ),
              icon: const Icon(Icons.content_cut),
              label: Text(
                'Save trim · '
                '${formatTimestamp(_trimEndMs - _trimStartMs, padMinutes: false)}',
              ),
            ),
          ],
          const SizedBox(height: MonoPulseSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Notes', style: MonoPulseTypography.titleMedium),
              TextButton.icon(
                onPressed: _busy ? null : _addMarkerAtPlayhead,
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  'at ${formatTimestamp(_position.inMilliseconds, padMinutes: false)}',
                ),
              ),
            ],
          ),
          if (markers.isEmpty)
            Text(
              'No notes yet. Play the take and drop one where something '
              'happens — tap it later to jump straight back.',
              style: MonoPulseTypography.bodySmall.copyWith(
                color: context.mp.textSecondary,
              ),
            )
          else
            for (var i = 0; i < markers.length; i++)
              _MarkerRow(
                marker: markers[i],
                active: i == active,
                onTap: () => _seekTo(markers[i].ms),
                onDelete: () => _deleteMarker(markers[i]),
              ),
          const SizedBox(height: 96),
        ],
      ),
      bottomWidget: Padding(
        padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.lg),
        child: OutlinedButton.icon(
          onPressed: _busy ? null : _share,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.ios_share),
          label: Text(_isTrimmed ? 'Share trimmed' : 'Share'),
        ),
      ),
    );
  }

  Widget _buildTransport() {
    return Row(
      children: [
        IconButton(
          iconSize: 44,
          color: MonoPulseColors.accentOrange,
          icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle),
          onPressed: _duration == Duration.zero ? null : _togglePlay,
        ),
        Text(
          '${formatTimestamp(_position.inMilliseconds, padMinutes: false)}'
          ' / ${formatTimestamp(_duration.inMilliseconds, padMinutes: false)}',
          style: MonoPulseTypography.bodySmall.copyWith(
            color: context.mp.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildScrubber(List<AudioMarker> markers) {
    final totalMs = _duration.inMilliseconds;
    if (_entry.peaks.isEmpty) {
      // No waveform to drag against (legacy m4a or an attached file), so a
      // plain seek bar and no trim.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Slider(
            value: totalMs == 0
                ? 0
                : (_position.inMilliseconds / totalMs).clamp(0.0, 1.0),
            onChanged: totalMs == 0
                ? null
                : (v) => _seekTo((v * totalMs).round()),
          ),
          Text(
            'No waveform for this take — trimming needs a recording made in '
            'the app.',
            style: MonoPulseTypography.bodySmall.copyWith(
              color: context.mp.textSecondary,
            ),
          ),
        ],
      );
    }

    return Padding(
      // The handles sit at the ends of the waveform, and Android's back
      // gesture claims ~20dp at each screen edge — at the list's own 16dp
      // padding the system swallowed the drag and popped the screen. Inset
      // far enough that a touch-down on a handle reaches Flutter.
      padding: const EdgeInsets.symmetric(horizontal: _gestureEdgeInset),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          const height = 96.0;
          return SizedBox(
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) {
                      if (totalMs == 0) return;
                      _seekTo(
                        ((d.localPosition.dx / width).clamp(0.0, 1.0) * totalMs)
                            .round(),
                      );
                    },
                    child: CustomPaint(
                      painter: WaveformPainter(
                        peaks: _entry.peaks,
                        trimStart: _trimStart,
                        trimEnd: _trimEnd,
                        playhead: totalMs == 0
                            ? 0
                            : (_position.inMilliseconds / totalMs).clamp(
                                0.0,
                                1.0,
                              ),
                        markerFractions: totalMs == 0
                            ? const []
                            : [
                                for (final m in markers)
                                  (m.ms / totalMs).clamp(0.0, 1.0),
                              ],
                        dim: context.mp.textSecondary,
                      ),
                    ),
                  ),
                ),
                _TrimHandle(
                  fraction: _trimStart,
                  width: width,
                  onDrag: (dx) => setState(() {
                    _trimStart = (_trimStart + dx / width).clamp(
                      0.0,
                      _trimEnd - 0.02,
                    );
                  }),
                ),
                _TrimHandle(
                  fraction: _trimEnd,
                  width: width,
                  onDrag: (dx) => setState(() {
                    _trimEnd = (_trimEnd + dx / width).clamp(
                      _trimStart + 0.02,
                      1.0,
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Extra horizontal inset for the waveform, on top of the list's own padding,
/// so the trim handles clear Android's ~20dp back-gesture exclusion zone.
/// Knob — widen if a device reserves more.
const double _gestureEdgeInset = 24;

/// Touch target for a trim handle. Centring this on the waveform edge would
/// leave half of it outside the Stack, where hit tests never arrive — at the
/// untrimmed extremes the handle was only half grabbable.
const double _handleTouchWidth = 48;

/// A draggable in/out point sitting on top of the waveform.
class _TrimHandle extends StatelessWidget {
  const _TrimHandle({
    required this.fraction,
    required this.width,
    required this.onDrag,
  });

  final double fraction;
  final double width;
  final void Function(double dx) onDrag;

  @override
  Widget build(BuildContext context) {
    const half = _handleTouchWidth / 2;
    final centre = fraction * width;
    // Keep the whole touch box inside the Stack…
    final left = (centre - half).clamp(
      0.0,
      (width - _handleTouchWidth).clamp(0.0, double.infinity),
    );
    // …but leave the bar itself on the true edge when the box was pushed in.
    final barOffset = centre - (left + half);
    return Positioned(
      left: left,
      top: 0,
      bottom: 0,
      width: _handleTouchWidth,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
        child: Center(
          child: Transform.translate(
            offset: Offset(barOffset, 0),
            child: Container(
              width: 4,
              decoration: const BoxDecoration(
                color: MonoPulseColors.accentOrange,
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One timestamped comment; highlights while the playhead is inside it.
class _MarkerRow extends StatelessWidget {
  const _MarkerRow({
    required this.marker,
    required this.active,
    required this.onTap,
    required this.onDelete,
  });

  final AudioMarker marker;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: Text(
        formatTimestamp(marker.ms, padMinutes: false),
        style: MonoPulseTypography.bodySmall.copyWith(
          color: active
              ? MonoPulseColors.accentOrange
              : context.mp.textSecondary,
          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      title: Text(
        marker.text,
        style: TextStyle(
          color: active ? MonoPulseColors.accentOrange : context.mp.textPrimary,
        ),
      ),
      trailing: IconButton(
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.close, size: 18),
        onPressed: onDelete,
      ),
    );
  }
}
