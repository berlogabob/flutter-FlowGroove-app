part of '../practice_regions_screen.dart';

extension _RecordingNotes on _PracticeRegionsScreenState {
  List<AudioMarker> get _markers => entryNotes(_entry);

  int get _notePositionMs => _sync && _entry.grid != null
      ? _syncGrid.msOfBar(ref.read(backingTransportProvider).songBar)
      : _positionMs;

  Future<void> _seekNote(int ms) async {
    if (_sync) await _setSync(false);
    if (mounted) await _seekTimeline(ms);
  }

  Future<void> _saveTitle() async {
    if (!_canEdit || _busy) return;
    final text = _title.text.trim();
    if (text == (_entry.title ?? '')) return;
    await _save(_entry.copyWith(title: text));
  }

  Future<void> _addMarkerAtPlayhead() async {
    if (!_canEdit || _busy) return;
    final controller = TextEditingController();
    final at = _notePositionMs;
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
    // Not disposed: the dialog still animates out with this controller; it
    // holds no listeners, so GC takes it.
    if (!mounted || !_canEdit || _busy || text == null || text.trim().isEmpty) {
      return;
    }
    await _save(
      _entry.copyWith(
        notes: upsertMarker(_markers, (ms: at, text: text.trim())),
        body: bodyWithoutMarkers(_entry.body),
      ),
    );
  }

  Future<void> _deleteMarker(AudioMarker marker) async {
    if (!_canEdit || _busy) return;
    final kept = [..._markers]..removeWhere((m) => m.ms == marker.ms);
    await _save(
      _entry.copyWith(notes: kept, body: bodyWithoutMarkers(_entry.body)),
    );
  }
}

class _NotesPanel extends StatelessWidget {
  const _NotesPanel({
    required this.markers,
    required this.positionMs,
    required this.onSeek,
    this.onAdd,
    this.onDelete,
  });

  final List<AudioMarker> markers;
  final int positionMs;
  final Future<void> Function(int) onSeek;
  final VoidCallback? onAdd;
  final void Function(AudioMarker)? onDelete;

  @override
  Widget build(BuildContext context) {
    final active = activeMarkerIndex(markers, positionMs);
    return ListView(
      key: const ValueKey('recording-notes'),
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.lg),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Notes', style: MonoPulseTypography.titleMedium),
            if (onAdd != null)
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  'at ${formatTimestamp(positionMs, padMinutes: false)}',
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
              onTap: () => onSeek(markers[i].ms),
              onDelete: onDelete == null ? null : () => onDelete!(markers[i]),
            ),
      ],
    );
  }
}

/// Notes stay in file time; region boundaries and zoom never move them.
class _NoteTicksPainter extends CustomPainter {
  const _NoteTicksPainter({
    required this.markers,
    required this.viewStart,
    required this.viewEnd,
  });

  final List<AudioMarker> markers;
  final int viewStart;
  final int viewEnd;

  @override
  void paint(Canvas canvas, Size size) {
    final span = viewEnd - viewStart;
    if (span <= 0) return;
    final paint = Paint()
      ..color = MonoPulseColors.accentOrange
      ..strokeWidth = 2;
    for (final marker in markers) {
      if (marker.ms < viewStart || marker.ms > viewEnd) continue;
      final dx = (marker.ms - viewStart) / span * size.width;
      canvas.drawLine(Offset(dx, 2), Offset(dx, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_NoteTicksPainter oldDelegate) =>
      markers != oldDelegate.markers ||
      viewStart != oldDelegate.viewStart ||
      viewEnd != oldDelegate.viewEnd;
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
  final VoidCallback? onDelete;

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
      trailing: onDelete == null
          ? null
          : IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18),
              onPressed: onDelete,
            ),
    );
  }
}
