import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Comprehensive script to export and analyze all band data from Firestore.
///
/// This script:
/// 1. Fetches all band documents from Firestore
/// 2. Analyzes data structure for each band
/// 3. Identifies potential issues that could cause gray screen
/// 4. Exports data to JSON file for comparison
/// 5. Provides side-by-side comparison summary
///
/// USAGE:
/// ======
/// Option 1 - From Flutter app (recommended):
///   flutter run --target=scripts/export_band_data.dart
///
/// Option 2 - As standalone Dart script (requires Firebase Admin SDK):
///   dart scripts/export_band_data.dart
///
/// Option 3 - From Firebase Console:
///   1. Go to https://console.firebase.google.com/
///   2. Select your project → Firestore Database
///   3. Navigate to /bands collection
///   4. Click each document → View JSON
///   5. Copy and compare manually
///
/// OUTPUT:
/// =======
/// - Console output with detailed analysis
/// - JSON file: scripts/band_export_YYYYMMDD_HHMMSS.json
/// - Summary comparison table
///
void main() async {
  print('╔' + '═' * 68 + '╗');
  print('║' + centerText('FIRESTORE BAND DATA EXPORT & ANALYSIS', 68) + '║');
  print('╚' + '═' * 68 + '╝');
  print('');

  // Initialize Firebase
  FirebaseApp? app;
  try {
    app = await Firebase.initializeApp();
    print('✅ Firebase initialized: ${app.name}');
    print('');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
    print('');
    print('   TROUBLESHOOTING:');
    print('   1. Make sure you run this from Flutter app context:');
    print('      flutter run --target=scripts/export_band_data.dart');
    print('');
    print('   2. Or use Firebase Console manually:');
    print('      https://console.firebase.google.com/');
    print('');
    print('   3. Or use Firebase CLI:');
    print('      firebase firestore:get /bands');
    print('');
    return;
  }

  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  try {
    // Get current user
    final user = auth.currentUser;
    if (user == null) {
      print('⚠️  No user logged in.');
      print('   Some data may be inaccessible without authentication.');
      print('');
    } else {
      print('✅ Authenticated as: ${user.email} (${user.uid})');
      print('');
    }

    // Fetch all bands
    print('📥 Fetching bands from Firestore...');
    print('');

    final bandsSnapshot = await firestore.collection('bands').get();

    if (bandsSnapshot.docs.isEmpty) {
      print('⚠️  No bands found in /bands collection.');
      print('');
      print('   Check:');
      print('   1. Are there any bands created?');
      print('   2. Do you have read permissions?');
      print('   3. Check Firestore rules for bands collection');
      return;
    }

    print('📊 Found ${bandsSnapshot.docs.length} band(s)');
    print('');

    // Analyze and export
    final exportData = _analyzeBands(bandsSnapshot.docs);

    // Print detailed analysis
    _printDetailedAnalysis(exportData);

    // Print comparison summary
    _printComparisonSummary(exportData);

    // Save to file
    _saveToFile(exportData);

    // Print recommendations
    _printRecommendations(exportData);
  } catch (e, stackTrace) {
    print('');
    print('❌ ERROR: $e');
    print('');
    print('Stack trace:');
    print(stackTrace);
  }
}

Map<String, dynamic> _analyzeBands(List<QueryDocumentSnapshot> docs) {
  final exportData = {
    'exportedAt': DateTime.now().toIso8601String(),
    'totalBands': docs.length,
    'bands': <Map<String, dynamic>>[],
    'summary': {
      'bandsWithIssues': 0,
      'totalIssues': 0,
      'commonIssues': <String, int>{},
    },
  };

  for (final bandDoc in docs) {
    final bandId = bandDoc.id;
    final bandData = bandDoc.data() as Map<String, dynamic>;
    final analysis = _analyzeBand(bandId, bandData);
    exportData['bands'].add(analysis);

    // Update summary
    final issues = analysis['issues'] as List?;
    if (issues != null && issues.isNotEmpty) {
      exportData['summary']['bandsWithIssues'] =
          ((exportData['summary']['bandsWithIssues'] as int?) ?? 0) + 1;
      exportData['summary']['totalIssues'] =
          ((exportData['summary']['totalIssues'] as int?) ?? 0) + issues.length;

      for (final issue in issues) {
        final issueType = issue.split(':')[0];
        final commonIssues =
            exportData['summary']['commonIssues'] as Map<String, int>?;
        if (commonIssues != null) {
          commonIssues[issueType] = (commonIssues[issueType] ?? 0) + 1;
        }
      }
    }
  }

  return exportData;
}

Map<String, dynamic> _analyzeBand(String bandId, Map<String, dynamic> data) {
  final issues = <String>[];
  final members = data['members'] as List<dynamic>? ?? [];
  final memberUids = data['memberUids'] as List<dynamic>?;
  final adminUids = data['adminUids'] as List<dynamic>?;
  final editorUids = data['editorUids'] as List<dynamic>?;

  // Analyze members array
  final memberAnalysis = _analyzeMembers(members);
  issues.addAll(memberAnalysis['issues'] as List<String>);

  // Check uid arrays
  if (memberUids == null) {
    issues.add('DATA_STRUCTURE: memberUids field is missing');
  } else if (memberUids.isEmpty && members.isNotEmpty) {
    issues.add(
      'DATA_INTEGRITY: memberUids is empty but members has ${members.length} entries',
    );
  } else if (memberUids.length != members.length) {
    issues.add(
      'DATA_INTEGRITY: memberUids length (${memberUids.length}) != members length (${members.length})',
    );
  }

  if (adminUids == null) {
    issues.add('DATA_STRUCTURE: adminUids field is missing');
  } else {
    final adminMembers = members
        .where((m) => m['role'] == 'admin')
        .map((m) => m['uid'] as String?)
        .whereType<String>()
        .toList();

    if (adminUids.length != adminMembers.length) {
      issues.add(
        'DATA_INTEGRITY: adminUids length (${adminUids.length}) != admin members count (${adminMembers.length})',
      );
    }
  }

  if (editorUids == null) {
    issues.add('DATA_STRUCTURE: editorUids field is missing');
  }

  // Check for empty strings in critical fields
  final name = data['name'];
  if (name == null || name == '') {
    issues.add('DATA_QUALITY: Band name is null or empty');
  }

  return {
    'id': bandId,
    'name': name ?? 'Unknown',
    'createdBy': data['createdBy'],
    'createdAt': data['createdAt'],
    'inviteCode': data['inviteCode'],
    'members': members,
    'memberUids': memberUids,
    'adminUids': adminUids,
    'editorUids': editorUids,
    'tags': data['tags'],
    'memberCount': members.length,
    'issues': issues,
    'hasCriticalIssues': issues.any((i) => i.startsWith('CRITICAL:')),
    'hasHighPriorityIssues': issues.any((i) => i.startsWith('HIGH_PRIORITY:')),
  };
}

Map<String, dynamic> _analyzeMembers(List<dynamic> members) {
  final issues = <String>[];

  if (members.isEmpty) {
    return {'issues': issues, 'emptyMembers': true};
  }

  for (int i = 0; i < members.length; i++) {
    final member = members[i];
    final uid = member['uid'];
    final role = member['role'];
    final displayName = member['displayName'];
    final email = member['email'];
    final musicRoles = member['musicRoles'];

    // CRITICAL: Missing or empty UID
    if (uid == null || uid == '') {
      issues.add('CRITICAL: Member[$i] has null or empty UID');
    }

    // CRITICAL: Both displayName and email are empty strings
    if ((displayName == '' || displayName == null) &&
        (email == '' || email == null)) {
      issues.add(
        'CRITICAL: Member[$i] has empty displayName AND empty email - avatar will crash!',
      );
    }

    // HIGH_PRIORITY: Empty or invalid role
    if (role == null || role == '') {
      issues.add('HIGH_PRIORITY: Member[$i] has null or empty role');
    } else if (!['admin', 'editor', 'viewer'].contains(role)) {
      issues.add('HIGH_PRIORITY: Member[$i] has invalid role: "$role"');
    }

    // MEDIUM: Empty displayName (but has email)
    if (displayName == '' && email != null && email != '') {
      issues.add(
        'MEDIUM: Member[$i] has empty displayName (using email fallback)',
      );
    }

    // MEDIUM: Empty email (but has displayName)
    if (email == '' && displayName != null && displayName != '') {
      issues.add(
        'MEDIUM: Member[$i] has empty email (using displayName fallback)',
      );
    }

    // INFO: Missing musicRoles
    if (musicRoles == null) {
      // Not an issue, just informational
    }
  }

  return {'issues': issues, 'emptyMembers': false};
}

void _printDetailedAnalysis(Map<String, dynamic> exportData) {
  print('╔' + '═' * 68 + '╗');
  print('║' + centerText('DETAILED BAND ANALYSIS', 68) + '║');
  print('╚' + '═' * 68 + '╝');
  print('');

  for (final band in exportData['bands'] as List<Map<String, dynamic>>) {
    print('─' * 70);
    print('📁 BAND: ${band['name']}');
    print('   ID: ${band['id']}');
    print('   Created By: ${band['createdBy']}');
    print('');

    // Members
    print('   👥 MEMBERS (${band['memberCount']}):');
    final members = band['members'] as List<dynamic>;
    if (members.isEmpty) {
      print('      (empty)');
    } else {
      for (int i = 0; i < members.length; i++) {
        final m = members[i];
        final displayName = m['displayName'] ?? '(no name)';
        final email = m['email'] ?? '(no email)';
        final role = m['role'] ?? '(no role)';
        final uid = m['uid'] ?? '(no uid)';

        print('      [$i] $displayName ($email)');
        print('          UID: $uid | Role: $role');

        // Check for empty strings
        if (displayName == '')
          print('          ⚠️  displayName is EMPTY STRING (not null!)');
        if (email == '')
          print('          ⚠️  email is EMPTY STRING (not null!)');
        if (uid == '') print('          ⚠️  uid is EMPTY STRING (not null!)');
        if (role == '') print('          ⚠️  role is EMPTY STRING (not null!)');
      }
    }
    print('');

    // UID Arrays
    print('   📋 UID ARRAYS:');
    print('      memberUids: ${_formatArray(band['memberUids'])}');
    print('      adminUids: ${_formatArray(band['adminUids'])}');
    print('      editorUids: ${_formatArray(band['editorUids'])}');
    print('');

    // Issues
    final issues = band['issues'] as List<String>;
    if (issues.isEmpty) {
      print('   ✅ No issues detected');
    } else {
      print('   ⚠️  ISSUES (${issues.length}):');
      for (final issue in issues) {
        final severity = issue.split(':')[0];
        String icon;
        switch (severity) {
          case 'CRITICAL':
            icon = '🔴';
            break;
          case 'HIGH_PRIORITY':
            icon = '🟠';
            break;
          case 'MEDIUM':
            icon = '🟡';
            break;
          default:
            icon = '🔵';
        }
        print('      $icon $issue');
      }
    }
    print('');
  }
}

void _printComparisonSummary(Map<String, dynamic> exportData) {
  print('╔' + '═' * 68 + '╗');
  print('║' + centerText('BAND COMPARISON SUMMARY', 68) + '║');
  print('╚' + '═' * 68 + '╝');
  print('');

  print(
    '┌' +
        '─' * 10 +
        '┬' +
        '─' * 20 +
        '┬' +
        '─' * 10 +
        '┬' +
        '─' * 10 +
        '┬' +
        '─' * 10 +
        '┐',
  );
  print(
    '│' +
        centerText('Band', 10) +
        '│' +
        centerText('Name', 20) +
        '│' +
        centerText('Members', 10) +
        '│' +
        centerText('Issues', 10) +
        '│' +
        centerText('Status', 10) +
        '│',
  );
  print(
    '├' +
        '─' * 10 +
        '┼' +
        '─' * 20 +
        '┼' +
        '─' * 10 +
        '┼' +
        '─' * 10 +
        '┼' +
        '─' * 10 +
        '┤',
  );

  for (final band in exportData['bands'] as List<Map<String, dynamic>>) {
    final issueCount = (band['issues'] as List).length;
    final hasCritical = band['hasCriticalIssues'] as bool;
    final hasHighPriority = band['hasHighPriorityIssues'] as bool;

    String status;
    if (hasCritical) {
      status = '🔴 CRITICAL';
    } else if (hasHighPriority) {
      status = '🟠 HIGH';
    } else if (issueCount > 0) {
      status = '🟡 WARN';
    } else {
      status = '✅ OK';
    }

    final name = band['name'].toString().length > 18
        ? band['name'].toString().substring(0, 17) + '…'
        : band['name'];

    print(
      '│' +
          centerText(band['id'].substring(0, 8), 10) +
          '│' +
          centerText(name, 20) +
          '│' +
          centerText('${band['memberCount']}', 10) +
          '│' +
          centerText('$issueCount', 10) +
          '│' +
          centerText(status, 10) +
          '│',
    );
  }

  print(
    '└' +
        '─' * 10 +
        '┴' +
        '─' * 20 +
        '┴' +
        '─' * 10 +
        '┴' +
        '─' * 10 +
        '┴' +
        '─' * 10 +
        '┘',
  );
  print('');

  // Summary stats
  final summary = exportData['summary'] as Map<String, dynamic>;
  print('📊 SUMMARY:');
  print('   Total Bands: ${exportData['totalBands']}');
  print('   Bands with Issues: ${summary['bandsWithIssues']}');
  print('   Total Issues: ${summary['totalIssues']}');
  print('');

  if ((summary['commonIssues'] as Map<String, int>).isNotEmpty) {
    print('   Most Common Issues:');
    final sortedIssues =
        (summary['commonIssues'] as Map<String, int>).entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedIssues) {
      print('      - ${entry.key}: ${entry.value} occurrence(s)');
    }
    print('');
  }
}

void _saveToFile(Map<String, dynamic> exportData) {
  try {
    final timestamp = DateTime.now().toString().replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final filename = 'band_export_$timestamp.json';
    final filepath = 'scripts/$filename';

    final jsonOutput = JsonEncoder.withIndent('  ').convert(exportData);

    // Try to write to file (may not work in all contexts)
    try {
      final file = File(filepath);
      file.writeAsStringSync(jsonOutput);
      print('💾 Data exported to: $filepath');
      print('');
    } catch (e) {
      print('⚠️  Could not write to file: $e');
      print('   Copy the JSON output below instead:');
      print('');
    }

    // Always print JSON to console
    print('╔' + '═' * 68 + '╗');
    print('║' + centerText('RAW JSON EXPORT', 68) + '║');
    print('╚' + '═' * 68 + '╝');
    print('');
    print(jsonOutput);
    print('');
  } catch (e) {
    print('⚠️  Could not save export: $e');
  }
}

void _printRecommendations(Map<String, dynamic> exportData) {
  print('╔' + '═' * 68 + '╗');
  print('║' + centerText('RECOMMENDATIONS', 68) + '║');
  print('╚' + '═' * 68 + '╝');
  print('');

  final criticalBands = (exportData['bands'] as List)
      .where((b) => b['hasCriticalIssues'] as bool)
      .toList();

  final highPriorityBands = (exportData['bands'] as List)
      .where(
        (b) =>
            b['hasHighPriorityIssues'] as bool &&
            !(b['hasCriticalIssues'] as bool),
      )
      .toList();

  if (criticalBands.isEmpty && highPriorityBands.isEmpty) {
    print('✅ All bands have valid data structures!');
    print('');
    print(
      'If you\'re still experiencing gray screen issues, the cause may be:',
    );
    print('   1. UI rendering bug (check band_songs_screen.dart)');
    print('   2. State management issue');
    print('   3. Permission/firewall rules');
    print('');
  } else {
    if (criticalBands.isNotEmpty) {
      print('🔴 CRITICAL - Fix Immediately:');
      for (final band in criticalBands) {
        print('   - ${band['name']} (${band['id']})');
        for (final issue in band['issues'] as List<String>) {
          if (issue.startsWith('CRITICAL:')) {
            print('     • $issue');
          }
        }
      }
      print('');
    }

    if (highPriorityBands.isNotEmpty) {
      print('🟠 HIGH PRIORITY - Fix Soon:');
      for (final band in highPriorityBands) {
        print('   - ${band['name']} (${band['id']})');
        for (final issue in band['issues'] as List<String>) {
          if (issue.startsWith('HIGH_PRIORITY:')) {
            print('     • $issue');
          }
        }
      }
      print('');
    }
  }

  print('📝 NEXT STEPS:');
  print('');
  print('1. For bands with CRITICAL issues:');
  print('   - Open Firebase Console → Firestore Database');
  print('   - Navigate to /bands/{bandId}');
  print('   - Fix the data issues manually');
  print('   - Or run: dart scripts/fix_band_data.dart');
  print('');
  print('2. Apply code fix to prevent future issues:');
  print('   File: lib/screens/bands/band_songs_screen.dart');
  print('   Line: ~677 (avatar initial calculation)');
  print('');
  print('   Replace:');
  print('     (member.displayName ?? member.email ?? \'\?\')[0]');
  print('');
  print('   With:');
  print('     (() {');
  print('       final name = member.displayName?.isNotEmpty == true');
  print('         ? member.displayName');
  print('         : member.email?.isNotEmpty == true');
  print('           ? member.email');
  print('           : \'\?\';');
  print('       return name.isNotEmpty ? name[0] : \'\?\';');
  print('     })()');
  print('');
}

String _formatArray(dynamic array) {
  if (array == null) return 'MISSING';
  if (array is List) {
    if (array.isEmpty) return '[] (empty)';
    return '[${array.length} items]';
  }
  return 'INVALID TYPE';
}

String centerText(String text, int width) {
  final padding = ((width - text.length) / 2).floor();
  return ' ' * padding + text + ' ' * (width - padding - text.length);
}
