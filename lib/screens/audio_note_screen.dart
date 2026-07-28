import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';

import '../models/song_lab.dart';
import '../providers/data/data_providers.dart';
import '../services/audio/audio_note_edit.dart';
import '../theme/mono_pulse_theme.dart';
import '../utils/snackbar.dart';
import '../widgets/app_menu_sheet.dart';
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
  }

  Future<void> _load() async {
    final url = _url;
    if (url == null) return;
    try {
      final duration = await _player.setUrl(url);
      if (!mounted) return;
      setState(() => _duration = duration ?? Duration.zero);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, "Couldn't load audio: $e", error: true);
      }
      return;
    }
    _subs.addAll([
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
        ),
      ),
    );
  }

  Future<void> _deleteMarker(AudioMarker marker) async {
    final kept = [..._markers]..removeWhere((m) => m.ms == marker.ms);
    await _save(_entry.copyWith(body: formatMarkers(kept)));
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
      final bytes = await ref.read(audioBytesFetcherProvider)(url);
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
      // Re-upload under the SOURCE extension: a different one would write a
      // second object and orphan the original rather than replacing it.
      final ext = _extOf(url);
      final newUrl = await ref
          .read(storageServiceProvider)
          .uploadLabAudio(
            trimmed,
            bandId: widget.bandId,
            songId: _entry.songId,
            entryId: _entry.id,
            ext: ext,
            contentType: _mimeOf(ext),
          );
      final newDurationMs = audioDurationMs(trimmed) ?? (endMs - startMs);
      await _save(
        _entry.copyWith(
          // Overwriting a Storage object mints a fresh download token, so the
          // old URL 403s — always take the one the upload handed back.
          attachmentIds: [newUrl],
          body: formatMarkers(
            shiftMarkers(_markers, startMs: startMs, durationMs: newDurationMs),
          ),
          peaks: trimPeaks(_entry.peaks, _trimStart, _trimEnd),
        ),
      );
      if (!mounted) return;
      setState(() {
        _trimStart = 0;
        _trimEnd = 1;
        _position = Duration.zero;
      });
      await _player.setUrl(newUrl);
      if (!mounted) return;
      setState(() => _duration = Duration(milliseconds: newDurationMs));
      showAppSnackBar(context, 'Trimmed');
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Trim failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    final url = _url;
    if (url == null || _busy) return;
    setState(() => _busy = true);
    try {
      var bytes = await ref.read(audioBytesFetcherProvider)(url);
      final ext = _extOf(url);
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
        message: 'The take and its notes are removed.',
        confirmLabel: 'Delete',
      ),
    );
    if (confirmed != true || !mounted) return;
    final repo = ref.read(labRepositoryProvider);
    await repo.deleteEntry(_entry.songId, _entry.id, bandId: widget.bandId);
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
          icon: Icons.add_comment_outlined,
          label: 'Add note at playhead',
          onTap: _addMarkerAtPlayhead,
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
                      painter: _WaveformPainter(
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

/// Bars, dimmed outside the trim window, with marker ticks and a playhead.
class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.peaks,
    required this.trimStart,
    required this.trimEnd,
    required this.playhead,
    required this.markerFractions,
    required this.dim,
  });

  final List<int> peaks;
  final double trimStart;
  final double trimEnd;
  final double playhead;
  final List<double> markerFractions;
  final Color dim;

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty) return;
    final step = size.width / peaks.length;
    final mid = size.height / 2;
    final bar = Paint()
      ..strokeWidth = (step * 0.6).clamp(1.0, 6.0)
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < peaks.length; i++) {
      final fraction = (i + 0.5) / peaks.length;
      final inside = fraction >= trimStart && fraction <= trimEnd;
      bar.color = inside
          ? MonoPulseColors.accentOrange
          : dim.withValues(alpha: 0.3);
      // Keep silence visible as a hairline rather than nothing at all.
      final h = (peaks[i] / 255).clamp(0.03, 1.0) * mid;
      final x = i * step + step / 2;
      canvas.drawLine(Offset(x, mid - h), Offset(x, mid + h), bar);
    }

    final tick = Paint()..color = dim;
    for (final f in markerFractions) {
      final x = f * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, 6), tick);
    }

    canvas.drawLine(
      Offset(playhead * size.width, 0),
      Offset(playhead * size.width, size.height),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.playhead != playhead ||
      old.trimStart != trimStart ||
      old.trimEnd != trimEnd ||
      old.peaks != peaks ||
      old.markerFractions.length != markerFractions.length;
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
