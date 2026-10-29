part of '../practice_regions_screen.dart';

extension _RecordingFileActions on _PracticeRegionsScreenState {
  String? get _url => _entry.attachmentIds.firstOrNull;
  bool get _canSplit =>
      _entry.peaks.isNotEmpty && trimmableExtensions.contains(_extOf(_url));
  bool get _hasSkippedEdges => _trimStartMs > 0 || _trimEndMs < _durationMs;
  int get _trimStartMs {
    var start = 0;
    for (final region in _entry.regions) {
      if (!region.skip) break;
      start = region.endMs;
    }
    return start.clamp(0, _durationMs);
  }

  int get _trimEndMs {
    var end = _durationMs;
    for (final region in _entry.regions.reversed) {
      if (!region.skip) break;
      end = region.startMs;
    }
    return end.clamp(0, _durationMs);
  }

  double get _trimStart => _durationMs == 0 ? 0 : _trimStartMs / _durationMs;
  double get _trimEnd => _durationMs == 0 ? 1 : _trimEndMs / _durationMs;

  Future<void> _deleteReplacedAudio(String url) async {
    try {
      final pending = ref.read(pendingStorageDeletesProvider);
      await pending.enqueue(url);
      await pending.flush(url);
    } catch (_) {
      // A failed deletion stays queued for the next sweep.
    }
  }

  Future<void> _pauseForFileEdit() async {
    _auditionTimer?.cancel();
    if (_sync) await _setSync(false);
    await _loopUpdate;
    await _player.pause();
    _flushSession();
  }

  Future<void> _reloadEditedAudio(String url, int durationMs) async {
    if (!mounted) return;
    _changingClip = true;
    try {
      _update(() {
        _selection = null;
        _clipStart = 0;
        _clipEnd = null;
        _seam = null;
        _focus = null;
        _undoRegions = null;
        _analysisPcm = null;
        _analysisPcmLoad = null;
        _uncachedBytes = null;
        _position = Duration.zero;
        _lastPosMs = 0;
      });
      await _player.setLoopMode(LoopMode.off);
      File? file;
      try {
        file = await _cachedFile();
      } catch (_) {}
      _songPath = file?.path;
      _onLoopWav = false;
      if (file == null) {
        await _player.setUrl(url);
      } else {
        await _player.setFilePath(file.path);
      }
      if (!mounted) return;
      await _player.seek(Duration.zero);
      if (mounted) {
        _update(() => _duration = Duration(milliseconds: durationMs));
      }
    } finally {
      _changingClip = false;
    }
  }

  Future<void> _saveTrim() async {
    final url = _url;
    if (url == null || _busy || !_canEdit || !_hasSkippedEdges) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const ConfirmationDialog(
        title: 'Save trim?',
        message:
            'This replaces the original recording. The part outside the '
            'kept sections is gone for good.',
        confirmLabel: 'Trim',
        icon: Icons.content_cut,
      ),
    );
    if (confirmed != true || !mounted || !_canEdit || _busy) return;

    _update(() => _busy = true);
    try {
      await _pauseForFileEdit();
      final startMs = _trimStartMs;
      final endMs = _trimEndMs;
      if (endMs <= startMs) {
        throw StateError('No audio remains after skipped edges');
      }
      final bytes = await _readAudioBytes();
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
          notes: shiftMarkers(
            _markers,
            startMs: startMs,
            durationMs: newDurationMs,
          ),
          body: bodyWithoutMarkers(_entry.body),
          peaks: trimPeaks(_entry.peaks, _trimStart, _trimEnd),
          peaksRms: _entry.peaksRms,
          regions: cropRegions(_entry.regions, startMs: startMs, endMs: endMs),
          grid: _entry.grid == null ? null : cropGrid(_entry.grid!, startMs),
        ),
        requireSuccess: true,
      );
      await _deleteReplacedAudio(url);
      if (!mounted) return;
      await _reloadEditedAudio(newUrl, newDurationMs);
      if (!mounted) return;
      showAppSnackBar(context, 'Trimmed');
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Trim failed: $e', error: true);
    } finally {
      if (mounted) _update(() => _busy = false);
    }
  }

  /// Cuts the take in two at the playhead: this entry keeps the first part,
  /// a new entry gets the rest (a rehearsal recording → one take per song).
  Future<void> _splitAtPlayhead() async {
    final url = _url;
    final at = _notePositionMs;
    final total = _duration.inMilliseconds;
    if (url == null || _busy || !_canEdit || !_canSplit) return;
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
    if (confirmed != true || !mounted || !_canEdit || _busy) return;
    _update(() => _busy = true);
    try {
      await _pauseForFileEdit();
      final bytes = await _readAudioBytes();
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
        objectSuffix: const Uuid().v4(),
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
              notes: shiftMarkers(_markers, startMs: at, durationMs: restMs),
              body: bodyWithoutMarkers(_entry.body),
              authorId: _entry.authorId,
              visibility: _entry.visibility,
              createdAt: now,
              updatedAt: now,
              attachmentIds: [restUrl],
              peaks: trimPeaks(_entry.peaks, split, 1),
              peaksRms: _entry.peaksRms,
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
          notes: shiftMarkers(
            _markers.where((m) => m.ms < at).toList(),
            startMs: 0,
            durationMs: firstMs,
          ),
          body: bodyWithoutMarkers(_entry.body),
          peaks: trimPeaks(_entry.peaks, 0, split),
          peaksRms: _entry.peaksRms,
          regions: cropRegions(_entry.regions, startMs: 0, endMs: at),
        ),
        requireSuccess: true,
      );
      await _deleteReplacedAudio(url);
      if (!mounted) return;
      await _reloadEditedAudio(firstUrl, firstMs);
      if (!mounted) return;
      showAppSnackBar(context, 'Split — the rest is a new recording');
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Split failed: $e', error: true);
    } finally {
      if (mounted) _update(() => _busy = false);
    }
  }

  Future<void> _share({bool withoutSkippedEdges = false}) async {
    final url = _url;
    if (url == null || _busy) return;
    _update(() => _busy = true);
    try {
      var bytes = await _readAudioBytes();
      var ext = _extOf(url);
      if (withoutSkippedEdges) {
        final trimmed = trimAudio(
          bytes,
          startMs: _trimStartMs,
          endMs: _trimEndMs,
        );
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
        bytes = trimmed;
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
      if (mounted) _update(() => _busy = false);
    }
  }

  /// Extension of the stored object. Download URLs percent-encode the path
  /// separators but leave `.ext` intact, so a plain suffix match works.
  /// Empty for a missing URL, which no format matches.
  String _extOf(String? url) {
    if (url == null) return '';
    final path = Uri.tryParse(url)?.path ?? url.split('?').first;
    return RegExp(r'\.(\w{1,5})$').firstMatch(path)?.group(1)?.toLowerCase() ??
        '';
  }

  String _mimeOf(String ext) => switch (ext) {
    'm4a' => 'audio/mp4', // RFC 4337; what a messenger checks for playback
    'aac' => 'audio/aac',
    'wav' => 'audio/wav',
    'mp3' => 'audio/mpeg',
    'ogg' => 'audio/ogg',
    'flac' => 'audio/flac',
    _ => 'audio/mp4',
  };

  String _safeName(String s) {
    final cleaned = s.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    return cleaned.isEmpty ? 'audio note' : cleaned;
  }

  Future<void> _delete() async {
    if (!_canEdit || _busy) return;
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
    if (confirmed != true || !mounted || !_canEdit || _busy) return;
    _update(() => _busy = true);
    try {
      final url = _url;
      await _pauseForFileEdit();
      await ref
          .read(labRepositoryProvider)
          .deleteEntry(_entry.songId, _entry.id, bandId: widget.bandId);
      if (url != null) await _deleteReplacedAudio(url);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Delete failed: $e', error: true);
    } finally {
      if (mounted) _update(() => _busy = false);
    }
  }
}
