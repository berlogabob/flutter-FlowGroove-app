/// Screen for selecting songs from personal library to add to a band.
/// Supports multi-select for adding multiple songs at once.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/song.dart';
import '../../../models/band.dart';
import '../../../providers/data/data_providers.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../theme/mono_pulse_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/unified_item/unified_filter_sort_widget.dart';
import '../../../widgets/unified_item/adapters/song_item_adapter.dart';

/// Screen for selecting songs to add to a band.
class SongPickerScreen extends ConsumerStatefulWidget {
  /// The band to add songs to.
  final Band band;

  const SongPickerScreen({super.key, required this.band});

  @override
  ConsumerState<SongPickerScreen> createState() => _SongPickerScreenState();
}

class _SongPickerScreenState extends ConsumerState<SongPickerScreen> {
  String _searchQuery = '';
  SortOption _sortOption = SortOption.alphabetical;
  final Set<String> _selectedSongIds = {};

  /// Get current user's personal songs.
  List<Song> _filterSongs(List<Song> allSongs) {
    var filtered = allSongs;

    // Apply search filter
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      filtered = filtered.where((song) {
        final titleMatch = song.title.toLowerCase().contains(query);
        final artistMatch = song.artist.toLowerCase().contains(query);
        final tagsMatch = song.tags.any(
          (tag) => tag.toLowerCase().contains(query),
        );
        return titleMatch || artistMatch || tagsMatch;
      }).toList();
    }

    // Apply sorting
    switch (_sortOption) {
      case SortOption.alphabetical:
        filtered.sort((a, b) => a.title.compareTo(b.title));
        break;
      case SortOption.dateAdded:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.manual:
      case SortOption.dateModified:
        break;
    }

    return filtered;
  }

  /// Add selected songs to band.
  Future<void> _addSelectedToBand() async {
    if (_selectedSongIds.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    if (!mounted) return;
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 16),
            Text('Adding songs to band...'),
          ],
        ),
        duration: Duration(seconds: 2),
        backgroundColor: MonoPulseColors.accentOrange,
      ),
    );

    try {
      final firestore = ref.read(firestoreProvider);
      int successCount = 0;
      int failCount = 0;

      // Add each selected song to band
      for (final songId in _selectedSongIds) {
        try {
          await firestore.addSongToBandById(songId, widget.band.id);
          successCount++;
        } catch (e) {
          failCount++;
          debugPrint('❌ Failed to add song $songId to band: $e');
        }
      }

      if (!mounted) return;

      if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failCount > 0
                  ? 'Added $successCount song(s). $failCount failed.'
                  : 'Successfully added $successCount song(s) to ${widget.band.name}!',
            ),
            backgroundColor: failCount > 0
                ? Colors.orange
                : Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      if (failCount == 0) {
        Navigator.pop(context, true); // Indicate success
      }
    } catch (e) {
      if (!mounted) return;
      
      String errorMessage = 'Failed to add songs. ';
      
      // Check for timeout or network error
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('timeout')) {
        errorMessage = 'Request timed out. Please check your internet connection and try again.';
      } else if (errorStr.contains('permission')) {
        errorMessage = 'You do not have permission to add songs to this band.';
      } else if (errorStr.contains('network') || errorStr.contains('connection')) {
        errorMessage = 'Network error. Please check your connection and try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'RETRY',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(cachedUserSongsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Add Songs to ${widget.band.name}'),
        actions: [
          if (_selectedSongIds.isNotEmpty)
            TextButton(
              onPressed: _addSelectedToBand,
              child: Text(
                'Add (${_selectedSongIds.length})',
                style: const TextStyle(
                  color: MonoPulseColors.accentOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: songsAsync.when(
        data: (songs) => _buildContent(context, songs),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<Song> songs) {
    final filteredSongs = _filterSongs(songs);

    return Column(
      children: [
        // Search and sort
        Padding(
          padding: const EdgeInsets.all(16),
          child: UnifiedFilterSortWidget(
            currentSort: _sortOption,
            onSortChanged: (option) {
              if (option != null) {
                setState(() => _sortOption = option);
              }
            },
            filterText: _searchQuery.isEmpty ? null : _searchQuery,
            onFilterChanged: (value) {
              setState(() => _searchQuery = value ?? '');
            },
          ),
        ),
        // Songs list with checkboxes
        Expanded(
          child: filteredSongs.isEmpty
              ? _buildEmptyState(songs.isEmpty)
              : ListView.builder(
                  itemCount: filteredSongs.length,
                  itemBuilder: (context, index) {
                    final song = filteredSongs[index];
                    final isSelected = _selectedSongIds.contains(song.id);
                    final adapter = SongItemAdapter(song);
                    
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedSongIds.add(song.id);
                          } else {
                            _selectedSongIds.remove(song.id);
                          }
                        });
                      },
                      title: Text(adapter.title),
                      subtitle: adapter.subtitle != null
                          ? Text(adapter.subtitle!)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isEmpty) {
    if (isEmpty) {
      return EmptyState(
        icon: Icons.music_note,
        message: 'No songs available',
        hint: 'Create some songs in your personal library first.',
        actionLabel: 'Create Song',
        onAction: () => Navigator.pushNamed(context, '/songs/add'),
      );
    }
    return EmptyState.search(query: _searchQuery);
  }
}

/// Provider for current user's personal songs (cached).
final cachedUserSongsProvider =
    NotifierProvider<CachedUserSongsNotifier, AsyncValue<List<Song>>>(() {
      return CachedUserSongsNotifier();
    });

class CachedUserSongsNotifier extends Notifier<AsyncValue<List<Song>>> {
  @override
  AsyncValue<List<Song>> build() {
    return const AsyncValue.loading();
  }

  void loadSongs() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      debugPrint('⚠️ NO USER: Cannot load songs, user not authenticated');
      state = const AsyncValue.data([]);
      return;
    }

    try {
      debugPrint('🌐 LOADING: Fetching songs for user ${user.uid}');
      final songs = await ref
          .read(firestoreProvider)
          .watchSongs(user.uid)
          .first;
      debugPrint('✅ LOADED: ${songs.length} songs for user ${user.uid}');
      state = AsyncValue.data(songs);
    } catch (e, stack) {
      debugPrint('❌ ERROR: Failed to load songs for user ${user.uid}: $e');
      state = AsyncValue.error(e, stack);
    }
  }
}
