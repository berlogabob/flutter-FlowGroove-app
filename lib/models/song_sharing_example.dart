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

  // Personal Song info:
  //   Title: ${personalSong.title}
  //   Is Copy: ${personalSong.isCopy}
  //   Original Owner: ${personalSong.originalOwnerId}

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

  // Band Song (Copy) info:
  //   Title: ${bandSong.title}
  //   Band ID: ${bandSong.bandId}
  //   Original Owner: ${bandSong.originalOwnerId}
  //   Contributed By: ${bandSong.contributedBy}
  //   Is Copy: ${bandSong.isCopy}
  //   Contributed At: ${bandSong.contributedAt}

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

  // Copied Song (using copyWith) info:
  //   Title: ${copiedSong.title}
  //   Band ID: ${copiedSong.bandId}
  //   Is Copy: ${copiedSong.isCopy}

  // Example 4: Serialization to JSON
  final json = bandSong.toJson();
  // Serialized to JSON info:
  //   Keys: ${json.keys.join(', ')}
  //   Has originalOwnerId: ${json.containsKey('originalOwnerId')}
  //   Has isCopy: ${json.containsKey('isCopy')}

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
  // Old Format Song (backward compatible) info:
  //   Title: ${oldFormatSong.title}
  //   Is Copy: ${oldFormatSong.isCopy} (default: false)
  //   Original Owner: ${oldFormatSong.originalOwnerId} (default: null)
  //   Contributed By: ${oldFormatSong.contributedBy} (default: null)

  // Example 6: Check if a song is from a personal bank
  bool isFromPersonalBank(Song song) {
    return song.originalOwnerId != null && song.isCopy;
  }

  // Song Origin Checks:
  //   personalSong is from personal bank: ${isFromPersonalBank(personalSong)}
  //   bandSong is from personal bank: ${isFromPersonalBank(bandSong)}

  // Example 7: Get the original owner's ID
  String? getOriginalOwner(Song song) {
    if (song.isCopy) {
      return song.originalOwnerId;
    }
    // If it's not a copy, the owner is the creator
    return null; // Or handle based on your auth system
  }

  // Original Owner Lookup:
  //   personalSong original owner: ${getOriginalOwner(personalSong)}
  //   bandSong original owner: ${getOriginalOwner(bandSong)}
}
