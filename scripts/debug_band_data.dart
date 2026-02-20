import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Debug script to check band documents and verify adminUids/editorUids fields.
/// 
/// Usage:
///   firebase login
///   dart scripts/debug_band_data.dart
void main() async {
  print('🔍 Debugging Band Data...\n');
  
  // Initialize Firebase (you'll need to run this from a Flutter app or use firebase_admin)
  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  
  try {
    // Get current user
    final user = auth.currentUser;
    if (user == null) {
      print('❌ No user logged in. Please authenticate first.');
      return;
    }
    
    print('✅ Logged in as: ${user.email} (${user.uid})\n');
    
    // Get all bands
    final bandsSnapshot = await firestore.collection('bands').get();
    
    if (bandsSnapshot.docs.isEmpty) {
      print('⚠️  No bands found in Firestore.');
      return;
    }
    
    print('📊 Found ${bandsSnapshot.docs.length} band(s)\n');
    
    // Check each band
    for (final bandDoc in bandsSnapshot.docs) {
      final bandId = bandDoc.id;
      final bandData = bandDoc.data();
      
      print('=' * 60);
      print('Band: ${bandData['name'] ?? 'Unknown'}');
      print('ID: $bandId');
      print('Created By: ${bandData['createdBy']}');
      print('');
      
      // Check members array
      final members = bandData['members'] as List<dynamic>? ?? [];
      print('Members: ${members.length}');
      for (var member in members) {
        print('  - ${member['displayName'] ?? member['uid']} (${member['role']})');
      }
      print('');
      
      // Check uid arrays
      final memberUids = bandData['memberUids'] as List<dynamic>?;
      final adminUids = bandData['adminUids'] as List<dynamic>?;
      final editorUids = bandData['editorUids'] as List<dynamic>?;
      
      print('memberUids: ${memberUids ?? 'MISSING'} (${memberUids?.length ?? 0})');
      print('adminUids: ${adminUids ?? 'MISSING'} (${adminUids?.length ?? 0})');
      print('editorUids: ${editorUids ?? 'MISSING'} (${editorUids?.length ?? 0})');
      print('');
      
      // Check if current user is in adminUids
      if (adminUids != null && adminUids.contains(user.uid)) {
        print('✅ Current user IS in adminUids');
      } else {
        print('❌ Current user is NOT in adminUids');
      }
      
      // Check if current user is in editorUids
      if (editorUids != null && editorUids.contains(user.uid)) {
        print('✅ Current user IS in editorUids');
      } else {
        print('❌ Current user is NOT in editorUids');
      }
      
      // Check if current user is in members
      final isInMembers = members.any((m) => m['uid'] == user.uid);
      if (isInMembers) {
        print('✅ Current user IS in members array');
        final memberRole = members.firstWhere((m) => m['uid'] == user.uid)['role'];
        print('   Role: $memberRole');
      } else {
        print('❌ Current user is NOT in members array');
      }
      
      print('');
      
      // Check for data integrity issues
      final issues = <String>[];
      
      if (memberUids == null || memberUids.isEmpty) {
        issues.add('memberUids is empty or missing');
      }
      
      if (adminUids == null || adminUids.isEmpty) {
        issues.add('adminUids is empty or missing');
      }
      
      // Check if adminUids matches members with admin role
      if (adminUids != null) {
        final adminMembers = members.where((m) => m['role'] == 'admin').map((m) => m['uid'] as String).toList();
        final adminUidsSet = Set<String>.from(adminUids.cast<String>());
        final adminMembersSet = Set<String>.from(adminMembers);
        
        if (!adminUidsSet.containsAll(adminMembers)) {
          issues.add('adminUids missing some admins from members: ${adminMembers.toSet().difference(adminUidsSet)}');
        }
        
        if (!adminMembersSet.containsAll(adminUids.cast<String>())) {
          issues.add('adminUids has extra UIDs not in members: ${adminUidsSet.difference(adminMembersSet)}');
        }
      }
      
      if (issues.isNotEmpty) {
        print('⚠️  DATA ISSUES FOUND:');
        for (var issue in issues) {
          print('   - $issue');
        }
      } else {
        print('✅ No data integrity issues detected');
      }
      
      print('');
    }
    
    print('=' * 60);
    print('📊 DEBUG COMPLETE');
    print('=' * 60);
    
  } catch (e, stackTrace) {
    print('\n❌ ERROR: $e');
    print('Stack trace: $stackTrace');
  }
}
