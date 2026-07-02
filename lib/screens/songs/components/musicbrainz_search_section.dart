import 'package:flutter/material.dart';
import '../../../models/musicbrainz_recording.dart';
import '../../../services/musicbrainz_service.dart';
import '../../../theme/mono_pulse_theme.dart';

/// A bottom sheet widget for searching and selecting recordings from MusicBrainz.
///
/// This widget displays search results from MusicBrainz with BPM information
/// when available. Users can select a recording to populate song information.
class MusicBrainzSearchSection extends StatefulWidget {

  const MusicBrainzSearchSection({
    required this.query,
    required this.scrollController,
    required this.onSelect,
    super.key,
  });
  /// The search query string.
  final String query;

  /// Scroll controller for the draggable sheet.
  final ScrollController scrollController;

  /// Callback when a recording is selected.
  final void Function(MusicBrainzRecording recording) onSelect;

  @override
  State<MusicBrainzSearchSection> createState() =>
      _MusicBrainzSearchSectionState();
}

class _MusicBrainzSearchSectionState extends State<MusicBrainzSearchSection> {
  late Future<List<MusicBrainzRecording>> _searchResults;

  @override
  void initState() {
    super.initState();
    _searchResults = MusicBrainzService().searchFlexible(widget.query);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(MonoPulseSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'MusicBrainz: ${widget.query}',
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<MusicBrainzRecording>>(
            future: _searchResults,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: MonoPulseColors.error,
                      ),
                      const SizedBox(height: 16),
                      const Text('Search error'),
                      const SizedBox(height: 8),
                      Text(
                        'Try again later',
                        style: MonoPulseTypography.bodySmall.copyWith(
                          color: MonoPulseColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final results = snapshot.data ?? [];

              if (results.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 48,
                        color: MonoPulseColors.textTertiary,
                      ),
                      const SizedBox(height: 16),
                      const Text('No results found'),
                      const SizedBox(height: 8),
                      Text(
                        'Try different keywords',
                        style: MonoPulseTypography.bodySmall.copyWith(
                          color: MonoPulseColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: widget.scrollController,
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final recording = results[index];
                  return ListTile(
                    title: Text(recording.displayTitle),
                    subtitle: Text(recording.artist),
                    trailing: recording.lengthMs != null
                        ? Text(
                            recording.formattedDuration,
                            style: MonoPulseTypography.bodySmall.copyWith(
                              color: MonoPulseColors.textSecondary,
                            ),
                          )
                        : null,
                    onTap: () => widget.onSelect(recording),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
