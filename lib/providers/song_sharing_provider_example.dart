import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import 'data_providers.dart';

/// Example usage of FirestoreService methods for song sharing.
///
/// This file demonstrates how to use the new song sharing methods:
/// - addSongToBand: Copy a song from personal bank to band bank
/// - watchBandSongs: Stream songs from a band's collection
/// - deleteBandSong: Remove a song from band's collection
/// - updateBandSong: Update a song in band's collection

// ============================================================
// Provider Definitions
// ============================================================

/// Provider that watches songs for a specific band.
///
/// Usage in widget:
/// ```dart
/// final bandSongs = ref.watch(bandSongsProvider('band_123'));
/// bandSongs.when(
///   data: (songs) => ListView.builder(...),
///   loading: () => CircularProgressIndicator(),
///   error: (e, st) => Text('Error: $e'),
/// );
/// ```
final bandSongsProvider = StreamProvider.family<List<Song>, String>((
  ref,
  bandId,
) {
  return ref.watch(firestoreProvider).watchBandSongs(bandId);
});

/// Provider for the FirestoreService.
///
/// Usage:
/// ```dart
/// final firestore = ref.read(firestoreProvider);
/// await firestore.addSongToBand(...);
/// ```
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return ref.watch(firestoreProvider);
});

// ============================================================
// Example Usage Class
// ============================================================

/// Example class showing how to use song sharing methods.
///
/// This can be used as a reference for implementing song sharing
/// in your widgets or other services.
class SongSharingExample {
  final FirestoreService firestore;
  final String userId;

  SongSharingExample(this.firestore, this.userId);

  /// Example 1: Add a song to a band's collection.
  ///
  /// This creates a copy of a personal song in the band's collection.
  Future<void> exampleAddSongToBand(Song personalSong, String bandId) async {
    await firestore.addSongToBand(
      song: personalSong,
      bandId: bandId,
      contributorId: userId,
      contributorName: 'John Doe', // Get from user profile
    );
    print('Song "${personalSong.title}" added to band!');
  }

  /// Example 2: Watch band songs in real-time.
  ///
  /// Returns a stream that emits updates whenever band songs change.
  Stream<List<Song>> exampleWatchBandSongs(String bandId) {
    return firestore.watchBandSongs(bandId);
  }

  /// Example 3: Delete a song from band's collection.
  ///
  /// Only band members should be able to delete band songs.
  Future<void> exampleDeleteBandSong(String bandId, String songId) async {
    await firestore.deleteBandSong(bandId, songId);
    print('Song deleted from band collection');
  }

  /// Example 4: Update a song in band's collection.
  ///
  /// Useful when band members collaborate on song details.
  Future<void> exampleUpdateBandSong(Song updatedSong, String bandId) async {
    await firestore.updateBandSong(updatedSong, bandId);
    print('Song updated in band collection');
  }

  /// Example 5: Complete workflow - copy song and watch for changes.
  ///
  /// Demonstrates the full song sharing workflow.
  Stream<List<Song>> exampleFullWorkflow(
    Song personalSong,
    String bandId,
  ) async* {
    // Step 1: Add song to band
    await firestore.addSongToBand(
      song: personalSong,
      bandId: bandId,
      contributorId: userId,
      contributorName: 'John Doe',
    );

    // Step 2: Return stream to watch the band's songs
    yield* firestore.watchBandSongs(bandId);
  }
}

// ============================================================
// Widget Usage Examples
// ============================================================

/// Example widget showing how to display band songs.
///
/// ```dart
/// class BandSongsWidget extends ConsumerWidget {
///   final String bandId;
///
///   const BandSongsWidget({required this.bandId});
///
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final bandSongsAsync = ref.watch(bandSongsProvider(bandId));
///
///     return bandSongsAsync.when(
///       data: (songs) => ListView.builder(
///         itemCount: songs.length,
///         itemBuilder: (context, index) {
///           final song = songs[index];
///           return ListTile(
///             title: Text(song.title),
///             subtitle: Text(song.artist),
///             trailing: song.isCopy
///                 ? Icon(Icons.share, color: Colors.blue)
///                 : null,
///           );
///         },
///       ),
///       loading: () => Center(child: CircularProgressIndicator()),
///       error: (error, stack) => Center(child: Text('Error: $error')),
///     );
///   }
/// }
/// ```

/// Example widget showing how to add a song to a band.
///
/// ```dart
/// class AddSongToBandButton extends ConsumerWidget {
///   final Song song;
///   final String bandId;
///
///   const AddSongToBandButton({
///     required this.song,
///     required this.bandId,
///   });
///
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final firestore = ref.read(firestoreProvider);
///     final user = ref.read(currentUserProvider);
///
///     if (user == null) return SizedBox.shrink();
///
///     return ElevatedButton.icon(
///       icon: Icon(Icons.add_to_queue),
///       label: Text('Add to Band'),
///       onPressed: () async {
///         await firestore.addSongToBand(
///           song: song,
///           bandId: bandId,
///           contributorId: user.uid,
///           contributorName: user.displayName ?? 'Anonymous',
///         );
///
///         if (context.mounted) {
///           ScaffoldMessenger.of(context).showSnackBar(
///             SnackBar(content: Text('Song added to band!')),
///           );
///         }
///       },
///     );
///   }
/// }
/// ```
