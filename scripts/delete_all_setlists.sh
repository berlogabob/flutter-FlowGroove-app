#!/bin/bash

# Script to delete all setlists from Firestore
# This will fix the "Invalid date format 14-24" error
#
# Usage: ./scripts/delete_all_setlists.sh

echo "🔥 Firestore Setlist Cleanup Script"
echo "===================================="
echo ""
echo "This script will DELETE ALL SETLISTS from your Firestore database."
echo ""
echo "Project: repsync-app-8685c"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Aborted"
    exit 0
fi

echo ""
echo "🗑️  Deleting all setlists..."
echo ""

# Get all users
users=$(firebase firestore:get /users --output json 2>/dev/null | jq -r '.[] | .id')

total_deleted=0

for userId in $users; do
    echo "📁 Processing user: $userId"
    
    # Get all setlists for this user
    setlists=$(firebase firestore:get /users/$userId/setlists --output json 2>/dev/null | jq -r '.[] | .id' 2>/dev/null)
    
    user_count=0
    for setlistId in $setlists; do
        # Delete the setlist
        firebase firestore:delete /users/$userId/setlists/$setlistId --yes 2>/dev/null
        ((user_count++))
        ((total_deleted++))
    done
    
    if [ $user_count -gt 0 ]; then
        echo "   ✅ Deleted $user_count setlists"
    fi
done

echo ""
echo "==========================================="
echo "✅ Complete!"
echo "   Total setlists deleted: $total_deleted"
echo "==========================================="
echo ""
echo "You can now open the app and create new setlists with proper date format."
