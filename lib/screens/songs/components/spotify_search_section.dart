import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/spotify_service.dart';
import '../../../theme/app_theme.dart';

/// A bottom sheet widget for searching and selecting tracks from Spotify.
///
/// This widget displays search results from Spotify with audio features
/// (BPM, key) when available. Users can select a track to populate
/// song information.
class SpotifySearchSection extends StatefulWidget {
  /// The search query string.
  final String query;

  /// Scroll controller for the draggable sheet.
  final ScrollController scrollController;

  /// Callback when a track is selected.
  ///
  /// Returns the selected track and its audio features (if available).
  final Function(SpotifyTrack track, SpotifyAudioFeatures? features) onSelect;

  const SpotifySearchSection({
    super.key,
    required this.query,
    required this.scrollController,
    required this.onSelect,
  });

  @override
  State<SpotifySearchSection> createState() => _SpotifySearchSectionState();
}

class _SpotifySearchSectionState extends State<SpotifySearchSection> {
  late Future<List<SpotifyTrack>> _searchResults;
  final Map<String, SpotifyAudioFeatures> _audioFeatures = {};

  @override
  void initState() {
    super.initState();
    _searchResults = _loadResults();
  }

  Future<List<SpotifyTrack>> _loadResults() async {
    try {
      final tracks = await SpotifyService.search(widget.query);
      for (final track in tracks) {
        final features = await SpotifyService.getAudioFeatures(track.id);
        if (features != null) {
          _audioFeatures[track.id] = features;
        }
      }
      return tracks;
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Spotify: ${widget.query}',
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
          child: FutureBuilder<List<SpotifyTrack>>(
            future: _searchResults,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                final errorMsg = snapshot.error.toString();
                final isPremiumError = errorMsg.contains('Premium');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isPremiumError ? Icons.lock : Icons.error_outline,
                        size: 48,
                        color: isPremiumError ? Colors.orange : Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isPremiumError
                            ? 'Spotify Premium Required'
                            : 'Search error',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isPremiumError
                            ? 'Spotify API needs Premium subscription'
                            : 'Try again later',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      if (isPremiumError) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final encodedQuery =
                                Uri.encodeComponent(widget.query);
                            final url =
                                'https://open.spotify.com/search/$encodedQuery';
                            await launchUrl(
                              Uri.parse(url),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          icon: const Icon(Icons.open_in_browser),
                          label: const Text('Search on Spotify Web'),
                        ),
                      ],
                    ],
                  ),
                );
              }

              final results = snapshot.data ?? [];

              if (results.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.music_off, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No results found'),
                      SizedBox(height: 8),
                      Text(
                        'Spotify API not configured.\nSee lib/services/spotify_service.dart',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: widget.scrollController,
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final track = results[index];
                  final features = _audioFeatures[track.id];

                  return ListTile(
                    title: Text(track.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(track.artist),
                        if (features != null)
                          Text(
                            '${features.musicalKey} • ${features.bpm} BPM',
                            style: const TextStyle(
                              color: AppColors.color5,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    isThreeLine: features != null,
                    trailing: features != null
                        ? Chip(
                            label: Text('${features.bpm}'),
                            backgroundColor: AppColors.color5.withValues(
                              alpha: 0.2,
                            ),
                          )
                        : null,
                    onTap: () => widget.onSelect(track, features),
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
