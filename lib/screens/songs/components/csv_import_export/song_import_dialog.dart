/// Batch CSV import analysis and confirmation UI.
library;

import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/song_import_plan.dart';
import 'package:flowgroove/services/csv/song_csv_parser.dart';
import 'package:flowgroove/services/csv/song_csv_service.dart';
import 'package:flowgroove/services/csv/song_import_analyzer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/mono_pulse_theme.dart';
import '../../../../widgets/loading_indicator.dart';

class SongImportDialog extends StatefulWidget {
  const SongImportDialog({required this.librarySongs, super.key});

  final List<Song> librarySongs;

  @override
  State<SongImportDialog> createState() => _SongImportDialogState();
}

class _SongImportDialogState extends State<SongImportDialog> {
  final SongCsvService _service = SongCsvService();
  final SongImportAnalyzer _analyzer = const SongImportAnalyzer();
  bool _isLoading = false;
  SongImportAnalysis? _analysis;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final content = Column(
      children: [
        _buildHeader(isMobile),
        const Divider(height: 1),
        Expanded(child: _buildContent()),
        const Divider(height: 1),
        _buildFooter(),
      ],
    );

    if (isMobile) return Dialog.fullscreen(child: SafeArea(child: content));
    return Dialog(child: SizedBox(width: 720, height: 680, child: content));
  }

  Widget _buildHeader(bool isMobile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          const Icon(Icons.upload_file),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Import songs from CSV',
              style:
                  (isMobile
                          ? MonoPulseTypography.titleLarge
                          : MonoPulseTypography.headlineSmall)
                      .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const LoadingIndicator();
    if (_analysis != null) return _buildAnalysis(_analysis!);
    return _buildImportOptions();
  }

  Widget _buildImportOptions() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            children: [
              const Icon(Icons.table_view_outlined, size: 56),
              const SizedBox(height: 20),
              Text(
                'Choose a CSV file or paste CSV data. The complete file will be compared with your library before anything is saved.',
                textAlign: TextAlign.center,
                style: MonoPulseTypography.bodyLarge,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _importFromFile,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Select CSV file'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _importFromClipboard,
                  icon: const Icon(Icons.content_paste),
                  label: const Text('Paste from clipboard'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysis(SongImportAnalysis analysis) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Ready to import',
          style: MonoPulseTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Library values are preserved. CSV data fills blank fields and combines tags and links.',
          style: MonoPulseTypography.bodyMedium.copyWith(
            color: MonoPulseColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _countChip(Icons.table_rows, '${analysis.rowsRead} rows'),
            _countChip(
              Icons.add_circle_outline,
              '${analysis.songsToCreate.length} to add',
            ),
            _countChip(Icons.merge_type, '${analysis.mergedRowCount} to merge'),
            if (analysis.errors.isNotEmpty)
              _countChip(
                Icons.error_outline,
                '${analysis.errors.length} invalid',
              ),
          ],
        ),
        const SizedBox(height: 16),
        _resultSection(
          title: 'Added',
          count: analysis.songsToCreate.length,
          icon: Icons.add,
          children: analysis.songsToCreate
              .map((song) => _songRow(song.title, song.artist))
              .toList(),
        ),
        _resultSection(
          title: 'Merged',
          count: analysis.mergedRowCount,
          icon: Icons.merge_type,
          children: analysis.updates
              .map(
                (update) => ListTile(
                  dense: true,
                  title: Text(update.merged.title),
                  subtitle: Text(
                    '${update.sources.length} CSV row(s) -> ${update.original.artist.isEmpty ? 'Unknown artist' : update.original.artist}',
                  ),
                ),
              )
              .toList(),
        ),
        if (analysis.errors.isNotEmpty || analysis.warnings.isNotEmpty)
          _resultSection(
            title: 'Problems',
            count: analysis.errors.length + analysis.warnings.length,
            icon: Icons.warning_amber,
            children: [...analysis.errors, ...analysis.warnings]
                .map(
                  (message) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.info_outline, size: 20),
                    title: Text(message),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _countChip(IconData icon, String label) =>
      Chip(avatar: Icon(icon, size: 18), label: Text(label));

  Widget _resultSection({
    required String title,
    required int count,
    required IconData icon,
    required List<Widget> children,
  }) {
    return ExpansionTile(
      leading: Icon(icon),
      title: Text('$title ($count)'),
      initiallyExpanded: title == 'Problems' && count > 0,
      children: children.isEmpty
          ? [const ListTile(title: Text('None'))]
          : children,
    );
  }

  Widget _songRow(String title, String artist) => ListTile(
    dense: true,
    title: Text(title),
    subtitle: Text(artist.isEmpty ? 'Unknown artist' : artist),
  );

  Widget _buildFooter() {
    final analysis = _analysis;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (analysis != null)
            TextButton(onPressed: _reset, child: const Text('Back')),
          const Spacer(),
          if (analysis != null)
            FilledButton.icon(
              onPressed: analysis.hasWork
                  ? () => Navigator.pop(context, analysis)
                  : null,
              icon: const Icon(Icons.download_done),
              label: Text(
                'Import ${analysis.songsToCreate.length + analysis.updates.length} changes',
              ),
            )
          else
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
        ],
      ),
    );
  }

  Future<void> _importFromFile() async {
    setState(() => _isLoading = true);
    final result = await _service.importFromFile();
    if (!mounted) return;
    _setResult(result);
  }

  Future<void> _importFromClipboard() async {
    setState(() => _isLoading = true);
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final content = data?.text ?? '';
      final result = content.trim().isEmpty
          ? SongParseResult(
              successful: const [],
              errors: ['Clipboard is empty'],
            )
          : await _service.importFromString(content);
      if (!mounted) return;
      _setResult(result);
    } catch (error) {
      if (!mounted) return;
      _setResult(
        SongParseResult(
          successful: const [],
          errors: ['Failed to read clipboard: $error'],
        ),
      );
    }
  }

  void _setResult(SongParseResult result) {
    setState(() {
      _analysis = _analyzer.analyze(
        importedSongs: result.successful,
        librarySongs: widget.librarySongs,
        errors: result.errors,
        warnings: result.warnings,
      );
      _isLoading = false;
    });
  }

  void _reset() => setState(() => _analysis = null);
}
