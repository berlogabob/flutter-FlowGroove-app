/// Migration script to add normalized fields to existing songs.
///
/// Run this script once to populate the new normalizedTitle, normalizedArtist,
/// titleSoundex, and artistSoundex fields for all existing songs.
///
/// Usage: dart scripts/migrate_songs_add_normalized_fields.dart
library;

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../lib/firebase_options.dart';
import '../lib/services/matching/song_normalizer.dart';
import '../lib/services/matching/fuzzy_matcher.dart';

/// Migrates all songs to include normalized fields.
Future<void> main() async {
  print('╔═══════════════════════════════════════════════════════════╗');
  print('║     Song Normalization Fields Migration                   ║');
  print('╚═══════════════════════════════════════════════════════════╝\n');

  // Initialize Firebase
  print('🔥 Initializing Firebase...');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('✅ Firebase initialized\n');

  final firestore = FirebaseFirestore.instance;
  var totalMigrated = 0;
  var totalErrors = 0;

  try {
    // Migrate user songs
    print('📂 Migrating user songs...');
    final usersSnapshot = await firestore.collection('users').get();
    print('   Found ${usersSnapshot.docs.length} users\n');

    for (final userDoc in usersSnapshot.docs) {
      final userId = userDoc.id;

      try {
        final songsSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('songs')
            .get();

        if (songsSnapshot.docs.isEmpty) continue;

        final batch = firestore.batch();
        var batchCount = 0;

        for (final songDoc in songsSnapshot.docs) {
          try {
            final data = songDoc.data() as Map<String, dynamic>;
            final title = data['title'] as String? ?? '';
            final artist = data['artist'] as String? ?? '';

            // Check if already normalized
            if (data.containsKey('normalizedTitle') &&
                data['normalizedTitle'] != null) {
              continue; // Already migrated
            }

            batch.update(songDoc.reference, {
              'normalizedTitle': SongNormalizer.normalizeTitle(title),
              'normalizedArtist': SongNormalizer.normalizeArtist(artist),
              'titleSoundex': Soundex.encode(title),
              'artistSoundex': Soundex.encode(artist),
              'updatedAt': FieldValue.serverTimestamp(),
            });

            batchCount++;

            // Firestore batch limit is 500
            if (batchCount >= 500) {
              await batch.commit();
              totalMigrated += batchCount;
              batchCount = 0;
            }
          } catch (e) {
            totalErrors++;
            print('   ⚠️ Error processing song ${songDoc.id}: $e');
          }
        }

        // Commit remaining
        if (batchCount > 0) {
          await batch.commit();
          totalMigrated += batchCount;
        }

        print('   ✅ User $userId: Migrated ${songsSnapshot.docs.length} songs');
      } catch (e) {
        totalErrors++;
        print('   ⚠️ Error processing user $userId: $e');
      }
    }

    print('\n📂 Migrating band songs...');
    final bandsSnapshot = await firestore.collection('bands').get();
    print('   Found ${bandsSnapshot.docs.length} bands\n');

    for (final bandDoc in bandsSnapshot.docs) {
      final bandId = bandDoc.id;

      try {
        final songsSnapshot = await firestore
            .collection('bands')
            .doc(bandId)
            .collection('songs')
            .get();

        if (songsSnapshot.docs.isEmpty) continue;

        final batch = firestore.batch();
        var batchCount = 0;

        for (final songDoc in songsSnapshot.docs) {
          try {
            final data = songDoc.data() as Map<String, dynamic>;
            final title = data['title'] as String? ?? '';
            final artist = data['artist'] as String? ?? '';

            // Check if already normalized
            if (data.containsKey('normalizedTitle') &&
                data['normalizedTitle'] != null) {
              continue; // Already migrated
            }

            batch.update(songDoc.reference, {
              'normalizedTitle': SongNormalizer.normalizeTitle(title),
              'normalizedArtist': SongNormalizer.normalizeArtist(artist),
              'titleSoundex': Soundex.encode(title),
              'artistSoundex': Soundex.encode(artist),
              'updatedAt': FieldValue.serverTimestamp(),
            });

            batchCount++;

            // Firestore batch limit is 500
            if (batchCount >= 500) {
              await batch.commit();
              totalMigrated += batchCount;
              batchCount = 0;
            }
          } catch (e) {
            totalErrors++;
            print('   ⚠️ Error processing song ${songDoc.id}: $e');
          }
        }

        // Commit remaining
        if (batchCount > 0) {
          await batch.commit();
          totalMigrated += batchCount;
        }

        print('   ✅ Band $bandId: Migrated ${songsSnapshot.docs.length} songs');
      } catch (e) {
        totalErrors++;
        print('   ⚠️ Error processing band $bandId: $e');
      }
    }

    print('\n╔═══════════════════════════════════════════════════════════╗');
    print('║ Migration Complete!                                       ║');
    print('╠═══════════════════════════════════════════════════════════╣');
    print('║ Total songs migrated: $totalMigrated');
    print('║ Total errors: $totalErrors');
    print('╚═══════════════════════════════════════════════════════════╝\n');
  } catch (e) {
    print('\n❌ Migration failed: $e\n');
    exit(1);
  }

  exit(0);
}
