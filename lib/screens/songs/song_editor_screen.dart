import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/section.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/chordpro.dart';
import 'chordpro_sync_controller.dart';
import 'components/import_lyrics_dialog.dart';
import 'components/song_constructor/widgets/edit_section_dialog.dart';
import 'components/song_constructor/widgets/section_card.dart';
import 'components/song_constructor/widgets/section_picker.dart';

/// Full-screen editor where the visual song map and the ChordPro text are two
/// live-synced views of one store (the song's sections). Reorder/edit the map
/// and the text updates instantly; edit the text and the map reconciles back
/// (see [ChordProSyncController]). Returns the final sections + metadata as an
/// [ImportedSong] so the song form can apply them.
class SongEditorScreen extends StatefulWidget {
  const SongEditorScreen({
    required this.title,
    required this.sections,
    this.artist,
    this.songKey,
    this.bpm,
    this.timeTop,
    super.key,
  });

  final String title;
  final List<Section> sections;
  final String? artist;
  final String? songKey;
  final int? bpm;
  final int? timeTop;

  @override
  State<SongEditorScreen> createState() => _SongEditorScreenState();
}

class _SongEditorScreenState extends State<SongEditorScreen> {
  late final ChordProSyncController _sync;
  late final TextEditingController _textCtrl;
  static const _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _sync = ChordProSyncController(
      sections: widget.sections,
      title: widget.title,
      artist: widget.artist,
      ourKey: widget.songKey,
      ourBpm: widget.bpm,
      timeTop: widget.timeTop,
    );
    _textCtrl = TextEditingController(text: _sync.text);
    _sync.addListener(_onSync);
  }

  void _onSync() {
    // Only push text into the field when it actually changed (a map edit); this
    // avoids yanking the caret while the user is typing in the field itself.
    if (_textCtrl.text != _sync.text) {
      _textCtrl.value = TextEditingValue(
        text: _sync.text,
        selection: TextSelection.collapsed(offset: _sync.text.length),
      );
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sync.removeListener(_onSync);
    _sync.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  ImportedSong _result() {
    final m = _sync.meta;
    return ImportedSong(
      sections: _sync.sections,
      title: m.title,
      artist: m.artist,
      ourKey: m.ourKey,
      ourBpm: m.ourBpm,
      timeTop: m.timeTop,
    );
  }

  void _close() {
    _sync.flushPending();
    Navigator.pop(context, _result());
  }

  Future<void> _editSection(Section s) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditSectionDialog(section: s),
    );
    if (result == null || !mounted) return;
    final updated = _sync.sections
        .map(
          (x) => x.id == s.id
              ? x.copyWith(
                  name: result['name'] as String?,
                  notes: result['notes'] as String?,
                  duration: result['duration'] as int?,
                  chordChart: result['chordChart'] as String?,
                )
              : x,
        )
        .toList();
    _sync.updateFromMap(updated);
  }

  void _addSection() {
    showDialog<void>(
      context: context,
      builder: (dctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SectionPicker(
            onSectionSelected: (name) {
              Navigator.pop(dctx);
              _sync.updateFromMap([
                ..._sync.sections,
                Section(id: _uuid.v4(), name: name, duration: 2),
              ]);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _import() async {
    final imported = await showModalBottomSheet<ImportedSong>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ImportLyricsDialog(),
    );
    if (imported == null || imported.sections.isEmpty || !mounted) return;

    var mode = ImportMode.replace;
    if (_sync.sections.isNotEmpty) {
      final choice = await showDialog<ImportMode>(
        context: context,
        builder: (dctx) => AlertDialog(
          title: const Text('You already have a song map'),
          content: const Text(
            'Replace it with the imported one, or append the imported sections?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dctx, ImportMode.append),
              child: const Text('Append'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dctx, ImportMode.replace),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (choice == null || !mounted) return;
      mode = choice;
    }
    _sync.applyImport(
      imported.sections,
      mode,
      meta: ChordProSyncMeta(
        title: imported.title,
        artist: imported.artist,
        ourKey: imported.ourKey,
        ourBpm: imported.ourBpm,
        timeTop: imported.timeTop,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = _sync.meta;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _close();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _close),
          title: Text(
            (m.title?.isNotEmpty ?? false) ? m.title! : 'Song editor',
          ),
          actions: [
            IconButton(
              tooltip: 'Import ChordPro',
              icon: const Icon(Icons.playlist_add),
              onPressed: _import,
            ),
            IconButton(
              tooltip: 'Add section',
              icon: const Icon(Icons.add),
              onPressed: _addSection,
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _metaBar(m),
            _mapStrip(),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(MonoPulseSpacing.md),
                child: TextField(
                  controller: _textCtrl,
                  onChanged: _sync.updateFromText,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText:
                        '{title: …}\n{key: …}\n{start_of_verse: Verse 1}\n[Am]…\n{end_of_verse}',
                    alignLabelWithHint: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaBar(ChordProSyncMeta m) {
    final bits = <String>[
      if (m.ourKey != null && m.ourKey!.isNotEmpty)
        '${m.ourKey} · ${keyToScale(m.ourKey!).quality}',
      if (m.ourBpm != null) '${m.ourBpm} BPM',
      if (m.timeTop != null) '${m.timeTop}/4',
    ];
    if (bits.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        bits.join('   ·   '),
        style: MonoPulseTypography.bodyMedium.copyWith(
          color: MonoPulseColors.accentOrange,
        ),
      ),
    );
  }

  Widget _mapStrip() {
    final sections = _sync.sections;
    if (sections.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          'No sections yet — type ChordPro below, or use Import / Add.',
          style: TextStyle(color: MonoPulseColors.textSecondary),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text(
            'SONG MAP · ${songMapSummary(sections.map((s) => s.name).toList())}',
            style: MonoPulseTypography.bodySmall.copyWith(
              color: MonoPulseColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.30,
          ),
          child: ReorderableListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: sections.length,
            onReorder: (oldIndex, newIndex) {
              final list = [..._sync.sections];
              var target = newIndex;
              if (target > oldIndex) target -= 1;
              final item = list.removeAt(oldIndex);
              list.insert(target, item);
              _sync.updateFromMap(list);
            },
            itemBuilder: (context, i) {
              final s = sections[i];
              return Dismissible(
                key: ValueKey('dismiss_${s.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: MonoPulseColors.error,
                  child: const Icon(
                    Icons.delete,
                    color: MonoPulseColors.textPrimary,
                  ),
                ),
                onDismissed: (_) => _sync.updateFromMap(
                  _sync.sections.where((x) => x.id != s.id).toList(),
                ),
                child: SectionCard(
                  section: s,
                  enableDrag: true,
                  dragIndex: i,
                  onTap: () => _editSection(s),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
