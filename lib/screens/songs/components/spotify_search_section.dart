import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/api/spotify_proxy_service.dart';
import '../../../services/api/spotify_service.dart' show SpotifyTrack, SpotifyAudioFeatures;
import '../../../theme/mono_pulse_theme.dart';

/// A bottom sheet widget for searching and selecting tracks from Spotify.
///
/// This widget displays search results from Spotify with audio features
/// (BPM, key) when available. Users can select a track to populate
/// song information.
class SpotifySearchSection extends StatefulWidget {

  const SpotifySearchSection({
    required this.query,
    required this.scrollController,
    required this.onSelect,
    super.key,
  });
  /// The search query string.
  final String query;

  /// Scroll controller for the draggable sheet.
  final ScrollController scrollController;

  /// Callback when a track is selected.
  ///
  /// Returns the selected track and its audio features (if available).
  final void Function(SpotifyTrack track, SpotifyAudioFeatures? features) onSelect;

  @override
  State<SpotifySearchSection> createState() => _SpotifySearchSectionState();
}

class _SpotifySearchSectionState extends State<SpotifySearchSection> {
  late Future<List<SpotifyTrack>> _searchResults;
  String? _loadingTrackId;

  @override
  void initState() {
    super.initState();
    _searchResults = _loadResults();
  }

  // Use the proxy so search works on web (CORS/auth). Audio-features are NOT
  // fetched here — that's an N+1; we fetch them lazily for the chosen track.
  Future<List<SpotifyTrack>> _loadResults() async {
    try {
      return await SpotifyProxyService.search(widget.query);
    } catch (e) {
      return [];
    }
  }

  Future<void> _select(SpotifyTrack track) async {
    setState(() => _loadingTrackId = track.id);
    SpotifyAudioFeatures? features;
    try {
      features = await SpotifyProxyService.getAudioFeatures(track.id);
    } catch (_) {
      features = null; // best-effort; selection still works without BPM/key
    }
    if (!mounted) return;
    setState(() => _loadingTrackId = null);
    widget.onSelect(track, features);
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
                        color: isPremiumError ? MonoPulseColors.warning : MonoPulseColors.error,
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
                        style: const TextStyle(color: MonoPulseColors.textSecondary, fontSize: 12),
                      ),
                      if (isPremiumError) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final encodedQuery = Uri.encodeComponent(
                              widget.query,
                            );
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
                      Icon(Icons.music_off, size: 48, color: MonoPulseColors.textTertiary),
                      SizedBox(height: 16),
                      Text('No results found'),
                      SizedBox(height: 8),
                      Text(
                        'Spotify API not configured.\nSee lib/services/spotify_service.dart',
                        style: TextStyle(color: MonoPulseColors.textTertiary, fontSize: 12),
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
                  final isLoading = _loadingTrackId == track.id;

                  return ListTile(
                    title: Text(track.name),
                    subtitle: Text(
                      track.album != null
                          ? '${track.artist} • ${track.album}'
                          : track.artist,
                    ),
                    trailing: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add, color: MonoPulseColors.accentOrange),
                    onTap: _loadingTrackId == null ? () => _select(track) : null,
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
