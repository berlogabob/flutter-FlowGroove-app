import 'song.dart';

/// Example usage of the Song model with sharing fields.
///
/// This demonstrates how to copy songs from personal banks to band banks
/// using the new sharing fields: originalOwnerId, contributedBy, isCopy, contributedAt.
void main() {
  // Example 1: Create a new personal song (original)
  final personalSong = Song(
    id: 'song_001',
    title: 'Wonderwall',
    artist: 'Oasis',
    originalKey: 'Em',
    originalBPM: 87,
    links: const [],
    tags: ['rock', '90s'],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  // Example 2: Copy a personal song to a band bank
  final bandSong = Song(
    id: 'band_song_001',
    title: personalSong.title,
    artist: personalSong.artist,
    originalKey: personalSong.originalKey,
    originalBPM: personalSong.originalBPM,
    links: personalSong.links,
    tags: personalSong.tags,
    bandId: 'band_123',
    originalOwnerId: 'user_456',
    contributedBy: 'user_789',
    isCopy: true,
    contributedAt: DateTime.now(),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  // Example 3: Serialization to JSON
  final json = bandSong.toJson();

  // Example 4: Deserialization from JSON (backward compatible)
  final oldFormatJson = <String, dynamic>{
    'id': 'old_song_001',
    'title': 'Yesterday',
    'artist': 'The Beatles',
    'originalKey': 'F',
    'links': [],
    'tags': ['classic'],
    'createdAt': DateTime.now().toIso8601String(),
    'updatedAt': DateTime.now().toIso8601String(),
  };
  final oldFormatSong = Song.fromJson(oldFormatJson);

  // Example 5: Check if a song is from a personal bank
  bool isFromPersonalBank(Song song) {
    return song.originalOwnerId != null && song.isCopy;
  }

  // Example 6: Get the original owner's ID
  String? getOriginalOwner(Song song) {
    if (song.isCopy) {
      return song.originalOwnerId;
    }
    return null;
  }

  // Use the examples to avoid unused warnings
  print('Band Song: ${bandSong.title}');
  print('Old Format Song: ${oldFormatSong.title}');
  print('Is from personal bank: ${isFromPersonalBank(bandSong)}');
  print('Original owner: ${getOriginalOwner(bandSong)}');
  print('JSON keys: ${json.keys.join(', ')}');
}
