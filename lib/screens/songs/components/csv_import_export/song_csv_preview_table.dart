/// Preview table for CSV import data.
library;

import 'package:flutter/material.dart';
import 'package:flutter_repsync_app/models/song.dart';
import '../../../../theme/mono_pulse_theme.dart';

/// Widget for displaying CSV import preview with validation errors.
class SongCsvPreviewTable extends StatelessWidget {
  /// List of successfully parsed songs.
  final List<Song> songs;

  /// List of validation errors.
  final List<String> errors;

  const SongCsvPreviewTable({
    super.key,
    required this.songs,
    required this.errors,
  });

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty && errors.isEmpty) {
      return const Center(child: Text('No data found in CSV'));
    }

    if (errors.isNotEmpty && songs.isEmpty) {
      return _buildErrorsOnly();
    }

    return Column(
      children: [
        // Summary
        _buildSummary(),
        // Errors (if any)
        if (errors.isNotEmpty) _buildErrorsSection(),
        // Preview table
        _buildPreviewTable(),
      ],
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(MonoPulseSpacing.lg),
      color: songs.isNotEmpty && errors.isEmpty
          ? MonoPulseColors.successGreenSubtle
          : errors.isNotEmpty && songs.isNotEmpty
          ? MonoPulseColors.warningSubtle
          : MonoPulseColors.errorSubtle,
      child: Row(
        children: [
          Icon(
            songs.isNotEmpty && errors.isEmpty
                ? Icons.check_circle
                : errors.isNotEmpty && songs.isNotEmpty
                ? Icons.warning
                : Icons.error,
            color: songs.isNotEmpty && errors.isEmpty
                ? MonoPulseColors.successGreen
                : errors.isNotEmpty && songs.isNotEmpty
                ? MonoPulseColors.warning
                : MonoPulseColors.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  songs.isNotEmpty
                      ? '${songs.length} song(s) ready to import'
                      : 'No songs to import',
                  style: MonoPulseTypography.titleLarge.copyWith(
                    color: songs.isNotEmpty && errors.isEmpty
                        ? MonoPulseColors.successGreen
                        : errors.isNotEmpty && songs.isNotEmpty
                        ? MonoPulseColors.warning
                        : MonoPulseColors.error,
                  ),
                ),
                if (errors.isNotEmpty)
                  Text(
                    '${errors.length} error(s) found',
                    style: MonoPulseTypography.bodySmall.copyWith(
                      color: songs.isNotEmpty && errors.isNotEmpty
                          ? MonoPulseColors.warning
                          : MonoPulseColors.error,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorsOnly() {
    return Padding(
      padding: const EdgeInsets.all(MonoPulseSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Import Errors:',
            style: MonoPulseTypography.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...errors.map(
            (error) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.error,
                    color: MonoPulseColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error,
                      style: const TextStyle(color: MonoPulseColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorsSection() {
    return ExpansionTile(
      leading: const Icon(Icons.warning, color: MonoPulseColors.warning),
      title: const Text('Validation Errors'),
      subtitle: Text('${errors.length} error(s) found'),
      initiallyExpanded: true,
      children: [
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: errors.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: const Icon(
                  Icons.error_outline,
                  color: MonoPulseColors.error,
                  size: 20,
                ),
                title: Text(
                  errors[index],
                  style: const TextStyle(fontSize: 12),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewTable() {
    return Expanded(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(MonoPulseSpacing.lg),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
              columns: const [
                DataColumn(label: Text('Title')),
                DataColumn(label: Text('Artist')),
                DataColumn(label: Text('Key')),
                DataColumn(label: Text('BPM')),
                DataColumn(label: Text('Sections')),
                DataColumn(label: Text('Tags')),
              ],
              rows: songs.take(10).map((song) {
                return DataRow(
                  cells: [
                    DataCell(Text(song.title, maxLines: 1)),
                    DataCell(Text(song.artist, maxLines: 1)),
                    DataCell(Text(song.ourKey ?? song.originalKey ?? '-')),
                    DataCell(
                      Text(
                        song.ourBPM?.toString() ??
                            song.originalBPM?.toString() ??
                            '-',
                      ),
                    ),
                    DataCell(Text('${song.sections.length}')),
                    DataCell(Text(song.tags.take(3).join(', '))),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
