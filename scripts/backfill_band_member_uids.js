#!/usr/bin/env node

/**
 * Backfill Script: Resync band derived UID arrays from `members`.
 *
 * Recomputes memberUids / adminUids / editorUids from each band's `members`
 * array so they can never drift out of sync (the drift was the root cause of
 * the "permission-denied" join bug). Also ensures the band's `createdBy` user
 * is present in `members` as an admin.
 *
 * Usage:
 *   cd functions && npm install firebase-admin   # firebase-admin is available here
 *   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccountKey.json
 *   node scripts/backfill_band_member_uids.js [--dry-run]
 */

const admin = require("firebase-admin");

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

const db = admin.firestore();
const dryRun = process.argv.includes("--dry-run");

function deriveUidArrays(members) {
  return {
    memberUids: members.map((m) => m.uid),
    adminUids: members.filter((m) => m.role === "admin").map((m) => m.uid),
    editorUids: members.filter((m) => m.role === "editor").map((m) => m.uid),
  };
}

function arraysEqual(a, b) {
  if (!Array.isArray(a) || !Array.isArray(b) || a.length !== b.length) {
    return false;
  }
  const sortedA = [...a].sort();
  const sortedB = [...b].sort();
  return sortedA.every((value, i) => value === sortedB[i]);
}

async function backfill() {
  console.log(`🚀 Backfilling band member UID arrays${dryRun ? " (dry run)" : ""}...\n`);

  let total = 0;
  let updated = 0;
  let errors = 0;

  try {
    const snapshot = await db.collection("bands").get();
    total = snapshot.size;
    console.log(`📊 Found ${total} band documents\n`);

    for (const doc of snapshot.docs) {
      const band = doc.data();
      try {
        let members = Array.isArray(band.members) ? [...band.members] : [];

        // Ensure the creator is present as an admin.
        if (band.createdBy) {
          const creator = members.find((m) => m && m.uid === band.createdBy);
          if (!creator) {
            members.push({
              uid: band.createdBy,
              role: "admin",
              displayName: null,
              email: null,
              musicRoles: [],
            });
          } else if (creator.role !== "admin") {
            // Only promote if no admin exists at all (avoid silently changing roles).
            const hasAdmin = members.some((m) => m && m.role === "admin");
            if (!hasAdmin) creator.role = "admin";
          }
        }

        const derived = deriveUidArrays(members);
        const membersChanged = members.length !== (band.members || []).length;
        const needsUpdate =
          membersChanged ||
          !arraysEqual(band.memberUids, derived.memberUids) ||
          !arraysEqual(band.adminUids, derived.adminUids) ||
          !arraysEqual(band.editorUids, derived.editorUids);

        if (!needsUpdate) {
          console.log(`⏭️  "${band.name || doc.id}" already consistent`);
          continue;
        }

        if (!dryRun) {
          await doc.ref.update({ members, ...derived });
        }
        updated++;
        console.log(
          `✅ ${dryRun ? "Would update" : "Updated"} "${band.name || doc.id}": ` +
            `${derived.memberUids.length} members, ${derived.adminUids.length} admins, ` +
            `${derived.editorUids.length} editors`,
        );
      } catch (error) {
        errors++;
        console.error(`❌ Error on "${doc.id}": ${error.message}`);
      }
    }

    console.log("\n" + "=".repeat(50));
    console.log(`Total: ${total} | ${dryRun ? "Would update" : "Updated"}: ${updated} | Errors: ${errors}`);
    console.log("=".repeat(50));
  } catch (error) {
    console.error("\n❌ Backfill failed:", error.message);
    process.exit(1);
  } finally {
    await db.terminate();
    process.exit(errors > 0 ? 1 : 0);
  }
}

backfill();
