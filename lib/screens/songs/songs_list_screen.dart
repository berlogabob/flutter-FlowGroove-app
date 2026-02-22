import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/api_error.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/auth/error_provider.dart';
import '../../models/song.dart';
import '../../models/band.dart';
import '../../theme/app_theme.dart';
import '../../widgets/song_attribution_badge.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/offline_indicator.dart';

/// Screen for displaying the list of songs with search functionality and error handling.
class SongsListScreen extends ConsumerStatefulWidget {
  const SongsListScreen({super.key});

  @override
  ConsumerState<SongsListScreen> createState() => _SongsListScreenState();
}

class _SongsListScreenState extends ConsumerState<SongsListScreen> {
  String _searchQuery = '';
  ApiError? _currentError;

  /// Filter songs based on the search query.
  List<Song> _filterSongs(List<Song> songs) {
    if (_searchQuery.trim().isEmpty) {
      return songs;
    }

    final query = _searchQuery.toLowerCase().trim();
    return songs.where((song) {
      final titleMatch = song.title.toLowerCase().contains(query);
      final artistMatch = song.artist.toLowerCase().contains(query);
      final tagsMatch = song.tags.any(
        (tag) => tag.toLowerCase().contains(query),
      );
      return titleMatch || artistMatch || tagsMatch;
    }).toList();
  }

  /// Clears the current error.
  void _clearError() {
    setState(() {
      _currentError = null;
    });
  }

  /// Handles an error from a stream.
  void _handleStreamError(Object error, StackTrace stackTrace) {
    final apiError = ApiError.fromException(error, stackTrace: stackTrace);
    setState(() {
      _currentError = apiError;
    });
    ref.read(errorNotifierProvider.notifier).handleError(apiError);
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songsProvider);
    final bandsAsync = ref.watch(bandsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Songs'),
        actions: const [OfflineStatusIcon()],
      ),
      body: Column(
        children: [
          const OfflineIndicator(),
          Expanded(child: _buildBody(songsAsync, bandsAsync)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/songs/add'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(
    AsyncValue<List<Song>> songsAsync,
    AsyncValue<List<Band>> bandsAsync,
  ) {
    return songsAsync.when(
      data: (songs) {
        // Clear error when data loads successfully
        if (_currentError != null) {
          _clearError();
        }
        return _buildContent(context, ref, songs, bandsAsync);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, stack) {
        _handleStreamError(e, stack);
        return _buildErrorState();
      },
    );
  }

  Widget _buildErrorState() {
    if (_currentError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorBanner(
            message: _currentError!.message,
            title: _currentError!.title,
            onRetry: () {
              _clearError();
              // Trigger a refresh by re-watching the provider
              ref.invalidate(songsProvider);
            },
            showRetry: _currentError!.isNetwork,
            style: ErrorBannerStyle.card,
          ),
        ),
      );
    }
    return const Center(child: Text('An error occurred'));
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<Song> songs,
    AsyncValue<List<Band>> bandsAsync,
  ) {
    final filteredSongs = _filterSongs(songs);
    final bands = bandsAsync.value ?? [];

    return Column(
      children: [
        // Inline error banner if there's an error but we have cached data
        if (_currentError != null && filteredSongs.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: ErrorBanner(
              message: _currentError!.message,
              title: _currentError!.title,
              onRetry: () {
                _clearError();
                ref.invalidate(songsProvider);
              },
              showRetry: _currentError!.isNetwork,
              style: ErrorBannerStyle.inline,
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.all(16),
          child: CustomTextField(
            hint: 'Search songs...',
            prefixIcon: Icons.search,
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        Expanded(
          child: filteredSongs.isEmpty
              ? _buildEmptyState(songs.isEmpty)
              : ListView.builder(
                  itemCount: filteredSongs.length,
                  itemBuilder: (context, index) {
                    final song = filteredSongs[index];
                    return _buildSongCard(context, ref, song, bands);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isEmpty) {
    if (isEmpty) {
      return EmptyState.songs(
        onAdd: () => Navigator.pushNamed(context, '/songs/add'),
      );
    }
    return EmptyState.search(query: _searchQuery);
  }

  Widget _buildSongCard(
    BuildContext context,
    WidgetRef ref,
    Song song,
    List<Band> bands,
  ) {
    final isShared = song.isCopy || song.bandId != null;

    return Dismissible(
      key: Key(song.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await ConfirmationDialog.showDeleteDialog(
          context,
          title: 'Delete Song',
          message: 'Are you sure you want to delete this song?',
          confirmLabel: 'Delete',
        );
      },
      onDismissed: (direction) async {
        final user = ref.read(currentUserProvider);
        if (user != null) {
          try {
            await ref.read(firestoreProvider).deleteSong(song.id, user.uid);
          } on ApiError catch (e) {
            _handleStreamError(e, StackTrace.current);
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(e.message)));
            }
          } catch (e, stackTrace) {
            final error = ApiError.fromException(e, stackTrace: stackTrace);
            _handleStreamError(error, stackTrace);
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(error.message)));
            }
          }
        }
      },
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          '/songs/${song.id}/edit',
          arguments: song,
        ),
        onLongPress: bands.isNotEmpty
            ? () => _showAddToBandMenu(context, ref, song, bands)
            : null,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isShared
                  ? AppColors.color5.withValues(alpha: 0.3)
                  : AppColors.color1.withValues(alpha: 0.3),
              child: Icon(
                isShared ? Icons.content_copy : Icons.music_note,
                color: isShared ? AppColors.color5 : AppColors.color1,
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    song.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: isShared
                          ? TextDecoration.underline
                          : TextDecoration.none,
                      decorationColor: AppColors.color5,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: AttributionSubtitle(
              subtitle: song.artist,
              contributorName: song.contributedBy,
              isCopy: isShared,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (song.ourKey != null)
                  Text(
                    song.ourKey!,
                    style: const TextStyle(
                      color: AppColors.color5,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                if (song.ourBPM != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${song.ourBPM}',
                    style: const TextStyle(
                      color: AppColors.color5,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (song.spotifyUrl != null)
                  IconButton(
                    icon: const Icon(
                      Icons.play_circle_fill,
                      color: Colors.green,
                      size: 28,
                    ),
                    onPressed: () async {
                      final uri = Uri.parse(song.spotifyUrl!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    tooltip: 'Play on Spotify',
                  ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/songs/${song.id}/edit',
                    arguments: song,
                  ),
                  tooltip: 'Edit',
                ),
                if (bands.isNotEmpty)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.add_to_queue, size: 20),
                    tooltip: 'Add to Band',
                    onSelected: (bandId) =>
                        _addToBand(context, ref, song, bandId),
                    itemBuilder: (context) => [
                      ...bands.map(
                        (band) => PopupMenuItem<String>(
                          value: band.id,
                          child: Row(
                            children: [
                              Icon(Icons.groups, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  band.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Show a menu to select a band for adding the song.
  void _showAddToBandMenu(
    BuildContext context,
    WidgetRef ref,
    Song song,
    List<Band> bands,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add to Band',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${song.title} - ${song.artist}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ...bands.map(
              (band) => ListTile(
                leading: const CircleAvatar(child: Icon(Icons.groups)),
                title: Text(band.name),
                subtitle: Text('${band.members.length} members'),
                onTap: () {
                  Navigator.pop(context);
                  _addToBand(context, ref, song, band.id);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Add a song to a band.
  Future<void> _addToBand(
    BuildContext context,
    WidgetRef ref,
    Song song,
    String bandId,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      await ref
          .read(firestoreProvider)
          .addSongToBand(
            song: song,
            bandId: bandId,
            contributorId: user.uid,
            contributorName: user.displayName ?? user.email ?? 'Unknown',
          );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${song.title}" to band'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ApiError catch (e) {
      _handleStreamError(e, StackTrace.current);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e, stackTrace) {
      final error = ApiError.fromException(e, stackTrace: stackTrace);
      _handleStreamError(error, stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}
