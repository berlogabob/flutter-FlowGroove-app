#!/usr/bin/env node

/**
 * Migration Script: Add editorUids to Existing Band Documents
 * 
 * This script adds the `editorUids` field to all existing band documents
 * that don't have it, based on their members array.
 * 
 * Usage:
 *   npm install firebase-admin
 *   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccountKey.json
 *   node scripts/migrate_editor_uids.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.applicationDefault()
});

const db = admin.firestore();

async function migrateEditorUids() {
  console.log('🚀 Starting editorUids migration...\n');
  
  let totalBands = 0;
  let updatedBands = 0;
  let errorCount = 0;
  
  try {
    // Get all band documents
    const bandsSnapshot = await db.collection('bands').get();
    totalBands = bandsSnapshot.size;
    
    console.log(`📊 Found ${totalBands} band documents\n`);
    
    // Process each band
    for (const bandDoc of bandsSnapshot.docs) {
      const bandId = bandDoc.id;
      const bandData = bandDoc.data();
      
      try {
        // Skip if editorUids already exists
        if (bandData.editorUids && Array.isArray(bandData.editorUids)) {
          console.log(`⏭️  Skipping "${bandData.name || bandId}" - editorUids already exists`);
          continue;
        }
        
        // Get members array
        const members = bandData.members || [];
        
        // Extract editor UIDs (members with role 'editor', excluding admins)
        const editorUids = members
          .filter(member => member.role === 'editor')
          .map(member => member.uid);
        
        // Extract admin UIDs for verification
        const adminUids = members
          .filter(member => member.role === 'admin')
          .map(member => member.uid);
        
        // Extract all member UIDs
        const memberUids = members.map(member => member.uid);
        
        // Update the band document
        await bandDoc.ref.update({
          memberUids: memberUids,
          adminUids: adminUids,
          editorUids: editorUids
        });
        
        updatedBands++;
        console.log(`✅ Updated "${bandData.name || bandId}": ${editorUids.length} editors, ${adminUids.length} admins, ${memberUids.length} total members`);
        
      } catch (error) {
        errorCount++;
        console.error(`❌ Error updating "${bandId}": ${error.message}`);
      }
    }
    
    // Summary
    console.log('\n' + '='.repeat(50));
    console.log('📊 MIGRATION SUMMARY');
    console.log('='.repeat(50));
    console.log(`Total bands processed: ${totalBands}`);
    console.log(`Bands updated: ${updatedBands}`);
    console.log(`Bands skipped (already had editorUids): ${totalBands - updatedBands}`);
    console.log(`Errors: ${errorCount}`);
    console.log('='.repeat(50));
    
    if (updatedBands > 0) {
      console.log('\n✅ Migration completed successfully!');
      console.log('📝 Note: You may need to restart your app to see the changes.');
    } else {
      console.log('\n✅ All bands already have editorUids field!');
    }
    
  } catch (error) {
    console.error('\n❌ Migration failed:', error.message);
    console.error('Stack trace:', error.stack);
    process.exit(1);
  } finally {
    // Clean up
    await db.terminate();
    process.exit(errorCount > 0 ? 1 : 0);
  }
}

// Run the migration
migrateEditorUids();
