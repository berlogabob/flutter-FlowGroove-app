/// "Paste a list": paste text, review the recognised songs, add them.
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../../../models/api_error.dart';
import '../../../../models/song.dart';
import '../../../../providers/auth/auth_provider.dart';
import '../../../../providers/data/data_providers.dart';
import '../../../../services/paste/pasted_song_parser.dart';
import '../../../../theme/mono_pulse_theme.dart';
import '../../../../utils/snackbar.dart';
import '../../../../widgets/app_badge.dart';
import '../../../../widgets/app_card.dart';
import '../../../../widgets/custom_button.dart';
import '../../../../widgets/custom_text_field.dart';

/// A reviewed row: [existing] is the library song it matched, if any.
class ReviewedSong {
  const ReviewedSong(this.title, this.artist, this.existing);

  final String title;
  final String artist;
  final Song? existing;
}

String _norm(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Library song with the same title and artist. A row without an artist
/// matches on title alone.
Song? matchLibrarySong(List<Song> library, String title, String artist) {
  final t = _norm(title);
  if (t.isEmpty) return null;
  final a = _norm(artist);
  for (final s in library) {
    if (_norm(s.title) == t && (a.isEmpty || _norm(s.artist) == a)) return s;
  }
  return null;
}

const _sheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(
    top: Radius.circular(MonoPulseRadius.xlarge),
  ),
);

Widget _framed(BuildContext context, Widget child) => Padding(
  padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
  child: SafeArea(child: child),
);

/// Paste -> review -> save. Returns the songs in pasted order (matched library
/// songs plus newly saved ones), or null when cancelled or nothing was added.
Future<List<Song>?> pasteSongs({
  required BuildContext context,
  required WidgetRef ref,
  required List<Song> library,
  String? bandId,
}) async {
  final text = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.mp.surfaceRaised,
    shape: _sheetShape,
    builder: (context) => _framed(context, const PasteListInputSheet()),
  );
  if (text == null || !context.mounted) return null;
  final reviewed = await showModalBottomSheet<List<ReviewedSong>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.mp.surfaceRaised,
    shape: _sheetShape,
    builder: (context) => _framed(
      context,
      ReviewPastedSongsSheet(
        pasted: parsePastedSongs(text),
        library: library,
        toBand: bandId != null,
      ),
    ),
  );
  if (reviewed == null || reviewed.isEmpty) return null;

  final uid = ref.read(currentUserProvider).value?.uid;
  if (uid == null) {
    showGlobalSnackBar('Please login to save songs.', error: true);
    return null;
  }
  final repo = ref.read(songRepositoryProvider);
  final songs = <Song>[];
  var failed = 0;
  for (final row in reviewed) {
    final existing = row.existing;
    if (existing != null) {
      songs.add(existing);
      continue;
    }
    final now = DateTime.now();
    final song = Song(
      id: const Uuid().v4(),
      title: row.title,
      artist: row.artist,
      bandId: bandId,
      createdAt: now,
      updatedAt: now,
    );
    try {
      if (bandId != null) {
        await repo.saveBandSong(song, bandId);
      } else {
        await repo.saveSong(song, uid: uid);
      }
      songs.add(song);
    } catch (e, stackTrace) {
      // Offline: the write sits in Firestore's queue and syncs later.
      if (ApiError.fromException(e, stackTrace: stackTrace).isNetwork) {
        songs.add(song);
      } else {
        failed++;
      }
    }
  }
  if (failed > 0) {
    showGlobalSnackBar(
      failed == 1 ? "Couldn't save 1 song" : "Couldn't save $failed songs",
      error: true,
    );
  }
  return songs.isEmpty ? null : songs;
}

String songsAddedMessage(int n) => n == 1 ? '1 song added' : '$n songs added';

class PasteListInputSheet extends StatefulWidget {
  const PasteListInputSheet({super.key});

  @override
  State<PasteListInputSheet> createState() => _PasteListInputSheetState();
}

class _PasteListInputSheetState extends State<PasteListInputSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) return;
    setState(() => _controller.text = text);
  }

  @override
  Widget build(BuildContext context) {
    final hasSongs = parsePastedSongs(_controller.text).songs.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: MonoPulseSpacing.md,
        children: [
          Text(
            'Paste a list',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          CustomTextField(
            hint: 'Paste one song per line',
            controller: _controller,
            maxLines: 6,
            keyboardType: TextInputType.multiline,
            onChanged: (_) => setState(() {}),
          ),
          Row(
            spacing: MonoPulseSpacing.md,
            children: [
              Expanded(
                child: CustomButton(
                  label: 'Paste',
                  icon: Icons.content_paste,
                  variant: ButtonVariant.outline,
                  fullWidth: true,
                  onPressed: _paste,
                ),
              ),
              Expanded(
                child: CustomButton(
                  label: 'Review',
                  fullWidth: true,
                  onPressed: hasSongs
                      ? () => Navigator.pop(context, _controller.text)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: MonoPulseSpacing.sm),
        ],
      ),
    );
  }
}

class _Row {
  _Row(String title, String artist)
    : title = TextEditingController(text: title),
      artist = TextEditingController(text: artist);

  final TextEditingController title;
  final TextEditingController artist;
}

class ReviewPastedSongsSheet extends StatefulWidget {
  const ReviewPastedSongsSheet({
    required this.pasted,
    required this.library,
    this.toBand = false,
    super.key,
  });

  final PastedSongs pasted;
  final List<Song> library;
  final bool toBand;

  @override
  State<ReviewPastedSongsSheet> createState() => _ReviewPastedSongsSheetState();
}

class _ReviewPastedSongsSheetState extends State<ReviewPastedSongsSheet> {
  late final List<_Row> _rows = [
    for (final s in widget.pasted.songs) _Row(s.title, s.artist ?? ''),
  ];

  // Disposed with the sheet: a removed row's fields are still mounted this frame.
  final List<_Row> _removed = [];

  @override
  void dispose() {
    for (final r in [..._rows, ..._removed]) {
      r.title.dispose();
      r.artist.dispose();
    }
    super.dispose();
  }

  Song? _match(_Row r) =>
      matchLibrarySong(widget.library, r.title.text, r.artist.text);

  int get _count => _rows.where((r) => r.title.text.trim().isNotEmpty).length;

  void _confirm() {
    Navigator.pop(context, [
      for (final r in _rows)
        if (r.title.text.trim().isNotEmpty)
          ReviewedSong(r.title.text.trim(), r.artist.text.trim(), _match(r)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final count = _count;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: MonoPulseSpacing.md,
        children: [
          Text(
            'Review $count ${count == 1 ? 'song' : 'songs'}',
            style: theme.textTheme.headlineMedium,
          ),
          if (widget.pasted.truncated)
            Text(
              'Only the first $maxPastedSongs songs were kept.',
              style: MonoPulseTypography.bodyMedium.copyWith(
                color: context.mp.textSecondary,
              ),
            ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (var i = 0; i < _rows.length; i++)
                  Padding(
                    key: ObjectKey(_rows[i]),
                    padding: const EdgeInsets.only(bottom: MonoPulseSpacing.sm),
                    child: _buildRow(i),
                  ),
                TextButton.icon(
                  onPressed: () => setState(() => _rows.add(_Row('', ''))),
                  icon: const Icon(Icons.add),
                  label: const Text('Add another song'),
                ),
                Text(
                  widget.toBand
                      ? "New songs will also be saved to the band's library."
                      : 'New songs will also be saved to your library.',
                  style: MonoPulseTypography.bodySmall.copyWith(
                    color: context.mp.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          CustomButton(
            label: 'Add $count ${count == 1 ? 'song' : 'songs'}',
            fullWidth: true,
            onPressed: count == 0 ? null : _confirm,
          ),
          const SizedBox(height: MonoPulseSpacing.sm),
        ],
      ),
    );
  }

  Widget _buildRow(int i) {
    final row = _rows[i];
    return AppCard(
      padding: const EdgeInsets.all(MonoPulseSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: MonoPulseSpacing.sm,
        children: [
          Expanded(
            child: Column(
              spacing: MonoPulseSpacing.sm,
              children: [
                CustomTextField(
                  hint: 'Title',
                  controller: row.title,
                  onChanged: (_) => setState(() {}),
                ),
                CustomTextField(
                  hint: 'Artist',
                  controller: row.artist,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.close),
                onPressed: () =>
                    setState(() => _removed.add(_rows.removeAt(i))),
              ),
              // The slot is always laid out so editing a title never moves
              // the fields beside it.
              Visibility(
                visible:
                    row.title.text.trim().isNotEmpty && _match(row) == null,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: const AppBadge(
                  label: 'NEW',
                  color: MonoPulseColors.petrol,
                  outlined: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
