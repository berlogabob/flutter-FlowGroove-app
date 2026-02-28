#!/usr/bin/env node

/**
 * Script to fix invalid date formats in Firestore setlists
 * Converts "dd-yy" format to ISO 8601 format
 * 
 * Usage: node scripts/fix_setlist_dates.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function fixSetlistDates() {
  console.log('🔍 Starting date format fix...\n');
  
  const usersSnapshot = await db.collection('users').get();
  let totalFixed = 0;
  let totalProcessed = 0;
  
  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;
    const setlistsRef = db.collection('users').doc(userId).collection('setlists');
    const setlistsSnapshot = await setlistsRef.get();
    
    if (setlistsSnapshot.empty) {
      continue;
    }
    
    console.log(`📁 User ${userId}: ${setlistsSnapshot.size} setlists`);
    
    const batch = db.batch();
    let userFixed = 0;
    
    for (const setlistDoc of setlistsSnapshot.docs) {
      totalProcessed++;
      const data = setlistDoc.data();
      const setlistId = setlistDoc.id;
      
      // Check if eventDate needs fixing
      if (data.eventDate && typeof data.eventDate === 'string') {
        const eventDateStr = data.eventDate;
        
        // Check for "dd-yy" format (e.g., "14-24")
        const ddYyMatch = eventDateStr.match(/^(\d{1,2})-(\d{2})$/);
        if (ddYyMatch) {
          const day = parseInt(ddYyMatch[1]);
          const yearSuffix = parseInt(ddYyMatch[2]);
          const year = 2000 + yearSuffix;
          const month = 1; // Default to January
          
          const newDate = new Date(year, month - 1, day);
          const isoDate = newDate.toISOString();
          
          console.log(`   🔧 Fixing setlist "${data.name || setlistId}": "${eventDateStr}" → "${isoDate}"`);
          
          batch.update(setlistDoc.ref, {
            eventDate: null, // Clear legacy field
            eventDateTime: isoDate // Set new field with ISO date
          });
          
          userFixed++;
          totalFixed++;
        }
        // Check for "dd-mm" format (e.g., "14-02")
        else if (eventDateStr.includes('-')) {
          const parts = eventDateStr.split('-');
          if (parts.length === 2) {
            const part1 = parseInt(parts[0]);
            const part2 = parseInt(parts[1]);
            
            // If both parts could be day/month
            if (part1 <= 31 && part2 <= 12) {
              const day = part1;
              const month = part2;
              const year = new Date().getFullYear();
              
              const newDate = new Date(year, month - 1, day);
              const isoDate = newDate.toISOString();
              
              console.log(`   🔧 Fixing setlist "${data.name || setlistId}": "${eventDateStr}" → "${isoDate}" (dd-mm format)`);
              
              batch.update(setlistDoc.ref, {
                eventDate: null,
                eventDateTime: isoDate
              });
              
              userFixed++;
              totalFixed++;
            }
          }
        }
      }
    }
    
    if (userFixed > 0) {
      await batch.commit();
      console.log(`   ✅ Fixed ${userFixed} setlists for user ${userId}\n`);
    }
  }
  
  console.log('\n===========================================');
  console.log(`✅ Complete!`);
  console.log(`   Total setlists processed: ${totalProcessed}`);
  console.log(`   Total setlists fixed: ${totalFixed}`);
  console.log('===========================================\n');
  
  process.exit(0);
}

fixSetlistDates().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
