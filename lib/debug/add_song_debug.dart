import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/song.dart';

/// Debug function to check WHY addSongToBand is failing.
/// 
/// Call this BEFORE trying to add a song to band.
/// 
/// Usage:
/// ```dart
/// await debugCheckBandPermissions(bandId: 'YOUR_BAND_ID');
/// ```
Future<void> debugCheckBandPermissions({
  required String bandId,
}) async {
  print('🔍 DEBUG: Checking band permissions...');
  print('=' * 60);
  
  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  
  // Check 1: Authentication
  final user = auth.currentUser;
  if (user == null) {
    print('❌ ERROR: User not logged in!');
    return;
  }
  print('✅ User logged in: ${user.email}');
  print('   UID: ${user.uid}');
  print('');
  
  // Check 2: Band document exists
  final bandDoc = await firestore.collection('bands').doc(bandId).get();
  if (!bandDoc.exists) {
    print('❌ ERROR: Band document does not exist!');
    return;
  }
  print('✅ Band document exists');
  print('   Band ID: $bandId');
  print('');
  
  // Check 3: Band data
  final bandData = bandDoc.data()!;
  print('📊 Band Data:');
  print('   Name: ${bandData['name']}');
  print('   adminUids: ${bandData['adminUids']}');
  print('   editorUids: ${bandData['editorUids']}');
  print('   memberUids: ${bandData['memberUids']}');
  print('   Members count: ${(bandData['members'] as List?)?.length ?? 0}');
  print('');
  
  // Check 4: Is user in adminUids?
  final adminUids = bandData['adminUids'] as List<dynamic>?;
  final isInAdminUids = adminUids?.contains(user.uid) ?? false;
  print('👑 Admin Check:');
  print('   User UID in adminUids: $isInAdminUids');
  if (!isInAdminUids) {
    print('   ❌ USER IS NOT IN adminUids!');
  } else {
    print('   ✅ User IS in adminUids');
  }
  print('');
  
  // Check 5: Is user in editorUids?
  final editorUids = bandData['editorUids'] as List<dynamic>?;
  final isInEditorUids = editorUids?.contains(user.uid) ?? false;
  print('✏️ Editor Check:');
  print('   User UID in editorUids: $isInEditorUids');
  print('');
  
  // Check 6: Is user in members array?
  final members = bandData['members'] as List<dynamic>? ?? [];
  final memberEntry = members.firstWhere(
    (m) => m['uid'] == user.uid,
    orElse: () => null,
  );
  print('👥 Members Array Check:');
  if (memberEntry != null) {
    print('   ✅ User found in members array');
    print('   Role: ${memberEntry['role']}');
  } else {
    print('   ❌ User NOT found in members array');
  }
  print('');
  
  // Check 7: Try to evaluate rules logic
  print('📋 Rules Logic Simulation:');
  final isAuthenticated = user != null;
  final isAdmin = isInAdminUids;
  final isEditor = isInEditorUids;
  final isEditorOrAdmin = isAdmin || isEditor;
  
  print('   isAuthenticated: $isAuthenticated');
  print('   isAdmin: $isAdmin');
  print('   isEditor: $isEditor');
  print('   isEditorOrAdmin: $isEditorOrAdmin');
  print('');
  
  // Final verdict
  print('⚖️ FINAL VERDICT:');
  if (isAuthenticated && isEditorOrAdmin) {
    print('   ✅ Rules SHOULD allow create!');
    print('   If it still fails, the issue is:');
    print('   - Rules not deployed');
    print('   - Firestore caching issue');
    print('   - Database location mismatch');
  } else {
    print('   ❌ Rules would DENY create');
    if (!isAuthenticated) print('      → User not authenticated');
    if (!isEditorOrAdmin) print('      → User is not editor or admin');
  }
  print('');
  print('=' * 60);
  
  // Check 8: Try actual add
  print('🧪 ATTEMPTING TO ADD SONG...');
  try {
    final testSong = Song(
      id: firestore.collection('bands').doc().id,
      title: 'Debug Test Song',
      artist: 'Test',
      bandId: bandId,
      originalOwnerId: user.uid,
      contributedBy: user.uid,
      isCopy: true,
      contributedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    await firestore
        .collection('bands')
        .doc(bandId)
        .collection('songs')
        .doc(testSong.id)
        .set(testSong.toJson());
    
    print('✅ SUCCESS! Song added!');
    print('   Song ID: ${testSong.id}');
    print('');
    print('🎉 THE ISSUE WAS TEMPORARY - MAYBE RULES CACHING');
    
  } catch (e) {
    print('❌ FAILED to add song');
    print('   Error: $e');
    print('');
    print('🔍 NEXT STEPS:');
    print('   1. Check Firebase Rules Logs:');
    print('      https://console.firebase.google.com/project/repsync-app-8685c/firestore/rules/logs');
    print('   2. Look for the denied write');
    print('   3. See which condition failed');
  }
  print('');
  print('=' * 60);
}
