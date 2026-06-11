/// Dialog for importing songs from CSV.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flowgroove/services/csv/song_csv_parser.dart';
import 'package:flowgroove/services/csv/song_csv_service.dart';
import '../../../../models/song.dart';
import '../../../../models/song_import_plan.dart';
import '../../../../services/matching/song_duplicate_detector.dart';
import '../../../../theme/mono_pulse_theme.dart';
import '../../../../widgets/loading_indicator.dart';
import '../../song_merge_dialog.dart';
import 'song_csv_preview_table.dart';

/// Dialog for importing songs from CSV file or clipboard.
class SongImportDialog extends StatefulWidget {
  const SongImportDialog({required this.librarySongs, super.key});

  final List<Song> librarySongs;

  @override
  State<SongImportDialog> createState() => _SongImportDialogState();
}

class _SongImportDialogState extends State<SongImportDialog> {
  final SongCsvService _service = SongCsvService();
  bool _isLoading = false;
  SongParseResult? _result;
  final _detector = const SongDuplicateDetector();
  final Map<String, SongImportMerge?> _decisions = {};

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.file_upload),
                  SizedBox(width: 12),
                  Text(
                    'Import Songs from CSV',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: MonoPulseColors.textHighEmphasis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content
            Expanded(child: _buildContent()),

            // Footer
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const LoadingIndicator();
    }

    if (_result != null) {
      return _buildPreview();
    }

    return _buildImportOptions();
  }

  Widget _buildImportOptions() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Choose how to import songs:',
            style: MonoPulseTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w500,
              color: MonoPulseColors.textHighEmphasis,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Import from file
              ElevatedButton.icon(
                onPressed: _importFromFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('Select CSV File'),
              ),
              const SizedBox(width: 16),
              // Import from clipboard
              ElevatedButton.icon(
                onPressed: _importFromClipboard,
                icon: const Icon(Icons.content_paste),
                label: const Text('Paste from Clipboard'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Supports CSV files from Google Sheets, Excel, or other apps',
            style: MonoPulseTypography.bodyMedium.copyWith(
              color: MonoPulseColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_result == null) {
      return const SizedBox.shrink();
    }

    final matched = _result!.successful.where(_bestMatchExists).toList();
    return Column(
      children: [
        if (_result!.warnings.isNotEmpty || _result!.errors.isNotEmpty)
          Expanded(
            child: SongCsvPreviewTable(
              songs: const [],
              errors: [..._result!.warnings, ..._result!.errors],
            ),
          ),
        if (matched.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '${matched.length} possible duplicate(s) require review.',
            ),
          ),
        Expanded(
          flex: 2,
          child: ListView(
            children: _result!.successful.map(_buildImportRow).toList(),
          ),
        ),
      ],
    );
  }

  bool _bestMatchExists(Song song) =>
      _detector.findMatches(song, widget.librarySongs).isNotEmpty;

  Widget _buildImportRow(Song song) {
    final matches = _detector.findMatches(song, widget.librarySongs);
    final best = matches.isEmpty ? null : matches.first;
    final decisionSet = _decisions.containsKey(song.id);
    final decision = _decisions[song.id];
    return ListTile(
      title: Text(song.title),
      subtitle: Text(
        best == null
            ? (song.artist.isEmpty ? 'Unknown artist' : song.artist)
            : 'Possible match: ${best.match.title} - ${best.match.artist} (${best.score.toStringAsFixed(0)}%)',
      ),
      trailing: best == null
          ? const Text('Add new')
          : Wrap(
              children: [
                TextButton(
                  onPressed: () => setState(() => _decisions[song.id] = null),
                  child: Text(
                    decisionSet && decision == null ? 'Skipped' : 'Skip',
                  ),
                ),
                OutlinedButton(
                  onPressed: () => setState(() => _decisions.remove(song.id)),
                  child: const Text('Add new'),
                ),
                FilledButton(
                  onPressed: () => _reviewMerge(song, best.match),
                  child: Text(
                    decision != null ? 'Merge ready' : 'Review merge',
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _reviewMerge(Song imported, Song existing) async {
    final result = await showDialog<(Song, Song, Song)>(
      context: context,
      builder: (_) => SongMergeDialog(first: existing, second: imported),
    );
    if (result == null || !mounted) return;
    setState(() {
      _decisions[imported.id] = SongImportMerge(
        keeper: result.$1,
        duplicate: result.$2,
        merged: result.$3,
      );
    });
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_result != null) ...[
            TextButton(
              onPressed: _isLoading ? null : _reset,
              child: const Text('Back'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _isLoading ? null : _confirmImport,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: Text('Import ${_result!.successful.length} Songs'),
            ),
          ] else ...[
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _importFromFile() async {
    setState(() => _isLoading = true);
    final result = await _service.importFromFile();
    if (!mounted) return;
    setState(() {
      _result = result;
      _isLoading = false;
    });
  }

  Future<void> _importFromClipboard() async {
    setState(() => _isLoading = true);
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) return;
      final content = clipboardData?.text ?? '';
      if (content.isEmpty) {
        setState(() {
          _result = SongParseResult(
            successful: [],
            errors: ['Clipboard is empty'],
          );
          _isLoading = false;
        });
        return;
      }
      final result = await _service.importFromString(content);
      if (!mounted) return;
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = SongParseResult(
          successful: [],
          errors: ['Failed to read clipboard: $e'],
        );
        _isLoading = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _result = null;
    });
  }

  void _confirmImport() {
    if (_result == null) return;

    // Return imported songs to parent
    final unresolved = _result!.successful.any(
      (song) => _bestMatchExists(song) && !_decisions.containsKey(song.id),
    );
    if (unresolved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review every possible duplicate first.')),
      );
      return;
    }
    final songsToCreate = _result!.successful
        .where((song) => !_decisions.containsKey(song.id))
        .toList();
    final merges = _decisions.values.whereType<SongImportMerge>().toList();
    Navigator.of(
      context,
    ).pop(SongImportPlan(songsToCreate: songsToCreate, merges: merges));
  }
}
