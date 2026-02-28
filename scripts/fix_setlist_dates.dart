import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_admin/firebase_admin.dart';

/// Script to fix invalid date formats in Firestore setlists
///
/// Usage: dart scripts/fix_setlist_dates.dart
///
/// This script:
/// 1. Connects to Firebase
/// 2. Finds all setlists with invalid eventDate format (e.g., "14-24")
/// 3. Either fixes the date or removes the field
/// 4. Reports results

void main() async {
  print('🔍 Starting Firestore Setlist Date Fix Script...\n');

  // Initialize Firebase Admin SDK
  final serviceAccountPath =
      Platform.environment['GOOGLE_APPLICATION_CREDENTIALS'] ??
      'serviceAccountKey.json';

  if (!File(serviceAccountPath).existsSync()) {
    print('❌ Service account key not found at: $serviceAccountPath');
    print('');
    print('Please either:');
    print('1. Place serviceAccountKey.json in the project root');
    print('2. Or set GOOGLE_APPLICATION_CREDENTIALS environment variable');
    print('');
    print('To get the service account key:');
    print(
      '1. Go to https://console.firebase.google.com/project/repsync-app-8685c/settings/serviceaccounts/adminsdk',
    );
    print('2. Click "Generate new private key"');
    print('3. Save the JSON file as serviceAccountKey.json');
    exit(1);
  }

  try {
    // Initialize Firebase Admin
    final app = await FirebaseAdmin.initializeApp(
      options: FirebaseOptions(
        apiKey: 'AIzaSyDdYHKbKLrZqFqJqKqKqKqKqKqKqKqKqKq', // Not used for admin
        appId: '1:123456789:android:abcdef',
        messagingSenderId: '123456789',
        projectId: 'repsync-app-8685c',
      ),
      credential: ServiceAccountCredentials.serviceAccount(serviceAccountPath),
    );

    final firestore = FirebaseFirestore.instance;

    print('✅ Connected to Firebase\n');

    // Get all users
    final usersSnapshot = await firestore.collection('users').get();
    print('📁 Found ${usersSnapshot.docs.length} users\n');

    int totalProcessed = 0;
    int totalFixed = 0;
    int totalDeleted = 0;

    for (final userDoc in usersSnapshot.docs) {
      final userId = userDoc.id;
      final setlistsRef = firestore
          .collection('users')
          .doc(userId)
          .collection('setlists');
      final setlistsSnapshot = await setlistsRef.get();

      if (setlistsSnapshot.empty) {
        continue;
      }

      print(
        '📁 User: ${userId.substring(0, 8)}... (${setlistsSnapshot.docs.length} setlists)',
      );

      final batch = firestore.batch();
      int userFixed = 0;
      int userDeleted = 0;

      for (final setlistDoc in setlistsSnapshot.docs) {
        totalProcessed++;
        final data = setlistDoc.data();
        final setlistId = setlistDoc.id;
        final setName = data['name'] ?? 'Unknown';

        // Check if eventDate field exists and is a string
        if (data.containsKey('eventDate') && data['eventDate'] is String) {
          final eventDateStr = data['eventDate'] as String;

          // Check for invalid formats
          bool needsFix = false;
          String? fixedDate;

          // Pattern: "dd-yy" (e.g., "14-24")
          final ddYyMatch = RegExp(
            r'^(\d{1,2})-(\d{2})$',
          ).firstMatch(eventDateStr);
          if (ddYyMatch != null) {
            final day = int.tryParse(ddYyMatch.group(1)!) ?? 1;
            final yearSuffix = int.tryParse(ddYyMatch.group(2)!) ?? 0;
            final year = 2000 + yearSuffix;

            fixedDate = DateTime(year, 1, day).toIso8601String();
            needsFix = true;

            print(
              '   🔧 Fixing "$setName": "$eventDateStr" → "$fixedDate" (dd-yy format)',
            );
          }
          // Pattern: "dd-mm" without year (e.g., "14-02")
          else if (eventDateStr.contains('-')) {
            final parts = eventDateStr.split('-');
            if (parts.length == 2) {
              final part1 = int.tryParse(parts[0]);
              final part2 = int.tryParse(parts[1]);

              if (part1 != null &&
                  part2 != null &&
                  part1 <= 31 &&
                  part2 <= 12) {
                final day = part1;
                final month = part2;
                final year = DateTime.now().year;

                fixedDate = DateTime(year, month, day).toIso8601String();
                needsFix = true;

                print(
                  '   🔧 Fixing "$setName": "$eventDateStr" → "$fixedDate" (dd-mm format)',
                );
              }
            }
          }

          if (needsFix && fixedDate != null) {
            // Update the document with fixed date
            batch.update(setlistDoc.ref, {
              'eventDate': null, // Remove legacy field
              'eventDateTime': Timestamp.fromDate(
                DateTime.parse(fixedDate),
              ), // Add new field
            });
            userFixed++;
            totalFixed++;
          } else {
            // Can't fix - delete the document
            print('   ❌ Deleting "$setName": Cannot parse "$eventDateStr"');
            batch.delete(setlistDoc.ref);
            userDeleted++;
            totalDeleted++;
          }
        }
      }

      if (userFixed > 0 || userDeleted > 0) {
        await batch.commit();
        print('   ✅ Fixed: $userFixed, Deleted: $userDeleted\n');
      }
    }

    print('\n===========================================');
    print('✅ Complete!');
    print('   Total setlists processed: $totalProcessed');
    print('   Total setlists fixed: $totalFixed');
    print('   Total setlists deleted: $totalDeleted');
    print('===========================================\n');

    await FirebaseAdmin.instance.close();
    exit(0);
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}
