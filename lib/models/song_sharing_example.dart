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
    // Sharing fields are optional - defaults apply
    // originalOwnerId: null (not set, this is the original)
    // bandId: null (personal song)
    // isCopy: false (default)
  );

  print('Personal Song:');
  print('  Title: ${personalSong.title}');
  print('  Is Copy: ${personalSong.isCopy}');
  print('  Original Owner: ${personalSong.originalOwnerId}');
  print('');

  // Example 2: Copy a personal song to a band bank
  final bandSong = Song(
    id: 'band_song_001',
    title: personalSong.title,
    artist: personalSong.artist,
    originalKey: personalSong.originalKey,
    originalBPM: personalSong.originalBPM,
    links: personalSong.links,
    tags: personalSong.tags,
    bandId: 'band_123', // Now belongs to a band
    originalOwnerId: 'user_456', // Original creator
    contributedBy: 'user_789', // User who added to band
    isCopy: true, // This is a copy in the band's bank
    contributedAt: DateTime.now(), // When it was added
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  print('Band Song (Copy):');
  print('  Title: ${bandSong.title}');
  print('  Band ID: ${bandSong.bandId}');
  print('  Original Owner: ${bandSong.originalOwnerId}');
  print('  Contributed By: ${bandSong.contributedBy}');
  print('  Is Copy: ${bandSong.isCopy}');
  print('  Contributed At: ${bandSong.contributedAt}');
  print('');

  // Example 3: Using copyWith to convert a personal song to a band copy
  final copiedSong = personalSong.copyWith(
    id: 'band_song_002',
    bandId: 'band_123',
    originalOwnerId: 'user_456',
    contributedBy: 'user_789',
    isCopy: true,
    contributedAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  print('Copied Song (using copyWith):');
  print('  Title: ${copiedSong.title}');
  print('  Band ID: ${copiedSong.bandId}');
  print('  Is Copy: ${copiedSong.isCopy}');
  print('');

  // Example 4: Serialization to JSON
  final json = bandSong.toJson();
  print('Serialized to JSON:');
  print('  Keys: ${json.keys.join(', ')}');
  print('  Has originalOwnerId: ${json.containsKey('originalOwnerId')}');
  print('  Has isCopy: ${json.containsKey('isCopy')}');
  print('');

  // Example 5: Deserialization from JSON (backward compatible)
  final oldFormatJson = {
    'id': 'old_song_001',
    'title': 'Yesterday',
    'artist': 'The Beatles',
    'originalKey': 'F',
    'links': [],
    'tags': ['classic'],
    'createdAt': DateTime.now().toIso8601String(),
    'updatedAt': DateTime.now().toIso8601String(),
    // No sharing fields - simulating old format
  };

  final oldFormatSong = Song.fromJson(oldFormatJson);
  print('Old Format Song (backward compatible):');
  print('  Title: ${oldFormatSong.title}');
  print('  Is Copy: ${oldFormatSong.isCopy} (default: false)');
  print('  Original Owner: ${oldFormatSong.originalOwnerId} (default: null)');
  print('  Contributed By: ${oldFormatSong.contributedBy} (default: null)');
  print('');

  // Example 6: Check if a song is from a personal bank
  bool isFromPersonalBank(Song song) {
    return song.originalOwnerId != null && song.isCopy;
  }

  print('Song Origin Checks:');
  print(
    '  personalSong is from personal bank: ${isFromPersonalBank(personalSong)}',
  );
  print('  bandSong is from personal bank: ${isFromPersonalBank(bandSong)}');
  print('');

  // Example 7: Get the original owner's ID
  String? getOriginalOwner(Song song) {
    if (song.isCopy) {
      return song.originalOwnerId;
    }
    // If it's not a copy, the owner is the creator
    return null; // Or handle based on your auth system
  }

  print('Original Owner Lookup:');
  print('  personalSong original owner: ${getOriginalOwner(personalSong)}');
  print('  bandSong original owner: ${getOriginalOwner(bandSong)}');
}
