#!/bin/bash
# Seed Demo Data for FlowGroove
# Creates test accounts, demo band, songs, and setlist
#
# Usage: ./scripts/seed_demo_data.sh
#
# PREREQUISITES:
# 1. Firebase CLI installed and authenticated
# 2. Active project set: firebase use <project-id>
# 3. Test accounts created in Firebase Console (see below)
#
# TEST ACCOUNTS TO CREATE MANUALLY:
# Go to Firebase Console → Authentication → Users → Add user
#
# Account 1: Admin (content editing)
#   Email: admin@flowgroove.app
#   Password: admin1234
#   After creation, copy the UID → ADMIN_UID
#
# Account 2: Demo (read-only)
#   Email: demo@flowgroove.app
#   Password: demo1234
#   After creation, copy the UID → DEMO_UID

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "╔═══════════════════════════════════════════════════╗"
echo "║       FlowGroove Demo Data Seeder                 ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""

# Check Firebase CLI
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Install: npm install -g firebase-tools"
    exit 1
fi

# Check active project
echo "📋 Active Firebase project:"
firebase use 2>/dev/null || echo "   ⚠️  No project selected. Run: firebase use --add"
echo ""

# Read UIDs from environment or use defaults
ADMIN_UID="${ADMIN_UID:-olBOGC6HMsZpVyTqLyfLK4GRKyZ2}"
DEMO_UID="${DEMO_UID:-lePjILMinYV4A0UFbg5qePv6VBg2}"

echo "🔑 Using UIDs:"
echo "   ADMIN_UID: $ADMIN_UID"
echo "   DEMO_UID:  $DEMO_UID"
echo ""
read -p "   Correct? (yes/no): " -r
echo ""
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    read -p "   Enter ADMIN_UID: " ADMIN_UID
    read -p "   Enter DEMO_UID: " DEMO_UID
fi
echo ""

echo "⚠️  This will write demo data to your active Firebase project."
echo "   Make sure you are NOT on production!"
echo ""
read -p "   Continue? (yes/no): " -r
echo ""
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "   ❌ Aborted."
    exit 0
fi

# Create temporary directory for JSON files
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

NOW=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
NEXT_WEEK=$(date -u -v+7d +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || date -u -d "+7 days" +"%Y-%m-%dT%H:%M:%S.000Z")

echo "📦 Creating user documents..."

# Users
cat > "$TEMP_DIR/users.json" << EOF
{
  "users": {
    "$ADMIN_UID": {
      "uid": "$ADMIN_UID",
      "email": "admin@flowgroove.app",
      "displayName": "Admin Tester",
      "accessRole": "admin",
      "musicRoles": ["drummer", "sound_engineer"],
      "systemTags": ["test", "demo_seeder"],
      "bandIds": ["demo_band_001"],
      "createdAt": "$NOW"
    },
    "$DEMO_UID": {
      "uid": "$DEMO_UID",
      "email": "demo@flowgroove.app",
      "displayName": "Demo User",
      "accessRole": "demo",
      "musicRoles": ["guitarist", "vocalist"],
      "systemTags": ["demo", "test"],
      "bandIds": ["demo_band_001"],
      "createdAt": "$NOW"
    }
  }
}
EOF

# Band
cat > "$TEMP_DIR/bands.json" << EOF
{
  "bands": {
    "demo_band_001": {
      "id": "demo_band_001",
      "name": "The Cover Collective",
      "description": "Demo band for testing all FlowGroove features.",
      "createdBy": "$ADMIN_UID",
      "members": [
        {
          "uid": "$ADMIN_UID",
          "role": "admin",
          "displayName": "Admin Tester",
          "email": "admin@flowgroove.app",
          "musicRoles": ["drummer", "sound_engineer"]
        },
        {
          "uid": "$DEMO_UID",
          "role": "viewer",
          "displayName": "Demo User",
          "email": "demo@flowgroove.app",
          "musicRoles": ["guitarist", "vocalist"]
        }
      ],
      "memberUids": ["$ADMIN_UID", "$DEMO_UID"],
      "adminUids": ["$ADMIN_UID"],
      "editorUids": [],
      "tags": ["rock", "pop", "covers", "demo"],
      "inviteCode": "DEMO2026",
      "createdAt": "$NOW"
    }
  }
}
EOF

# Songs (in admin's personal collection + band subcollection)
cat > "$TEMP_DIR/admin_songs.json" << EOF
{
  "users": {
    "$ADMIN_UID": {
      "songs": {
        "demo_song_001": {
          "id": "demo_song_001",
          "title": "Sweet Child O' Mine",
          "artist": "Guns N' Roses",
          "originalKey": "Db",
          "originalBPM": 125,
          "ourKey": "D",
          "ourBPM": 125,
          "links": [
            {"type": "spotify", "url": "https://open.spotify.com/track/7o2CTH4ctstm8TNelqjb51"}
          ],
          "tags": ["rock", "classic rock", "80s"],
          "spotifyId": "7o2CTH4ctstm8TNelqjb51",
          "createdAt": "$NOW",
          "updatedAt": "$NOW"
        },
        "demo_song_002": {
          "id": "demo_song_002",
          "title": "Billie Jean",
          "artist": "Michael Jackson",
          "originalKey": "F#m",
          "originalBPM": 117,
          "ourKey": "F#m",
          "ourBPM": 117,
          "links": [
            {"type": "spotify", "url": "https://open.spotify.com/track/5ChkMS8OtdzJeqyybCc9R5"}
          ],
          "tags": ["pop", "80s", "dance"],
          "spotifyId": "5ChkMS8OtdzJeqyybCc9R5",
          "createdAt": "$NOW",
          "updatedAt": "$NOW"
        },
        "demo_song_003": {
          "id": "demo_song_003",
          "title": "Wonderwall",
          "artist": "Oasis",
          "originalKey": "F#m",
          "originalBPM": 87,
          "ourKey": "G",
          "ourBPM": 90,
          "links": [
            {"type": "spotify", "url": "https://open.spotify.com/track/6Cy0IThCjjhjGzXOwK2m8O"}
          ],
          "tags": ["britpop", "90s", "acoustic"],
          "spotifyId": "6Cy0IThCjjhjGzXOwK2m8O",
          "createdAt": "$NOW",
          "updatedAt": "$NOW"
        },
        "demo_song_004": {
          "id": "demo_song_004",
          "title": "Uptown Funk",
          "artist": "Mark Ronson ft. Bruno Mars",
          "originalKey": "Dm",
          "originalBPM": 115,
          "ourKey": "Dm",
          "ourBPM": 115,
          "links": [
            {"type": "spotify", "url": "https://open.spotify.com/track/32OlwWuMpZ6b0aN2RZOeMS"}
          ],
          "tags": ["funk", "pop", "dance"],
          "spotifyId": "32OlwWuMpZ6b0aN2RZOeMS",
          "createdAt": "$NOW",
          "updatedAt": "$NOW"
        },
        "demo_song_005": {
          "id": "demo_song_005",
          "title": "Mr. Brightside",
          "artist": "The Killers",
          "originalKey": "Db",
          "originalBPM": 148,
          "ourKey": "Db",
          "ourBPM": 148,
          "links": [
            {"type": "spotify", "url": "https://open.spotify.com/track/0eGsygTp906u18L0Oimnem"}
          ],
          "tags": ["rock", "indie", "2000s"],
          "spotifyId": "0eGsygTp906u18L0Oimnem",
          "createdAt": "$NOW",
          "updatedAt": "$NOW"
        }
      }
    }
  }
}
EOF

# Band songs (shared repertoire)
cat > "$TEMP_DIR/band_songs.json" << EOF
{
  "bands": {
    "demo_band_001": {
      "songs": {
        "demo_song_001": {
          "id": "demo_song_001",
          "title": "Sweet Child O' Mine",
          "artist": "Guns N' Roses",
          "originalKey": "Db",
          "originalBPM": 125,
          "ourKey": "D",
          "ourBPM": 125,
          "links": [
            {"type": "spotify", "url": "https://open.spotify.com/track/7o2CTH4ctstm8TNelqjb51"}
          ],
          "tags": ["rock", "classic rock", "80s"],
          "spotifyId": "7o2CTH4ctstm8TNelqjb51",
          "addedBy": "$ADMIN_UID",
          "addedAt": "$NOW",
          "createdAt": "$NOW",
          "updatedAt": "$NOW"
        },
        "demo_song_002": {
          "id": "demo_song_002",
          "title": "Billie Jean",
          "artist": "Michael Jackson",
          "originalKey": "F#m",
          "originalBPM": 117,
          "ourKey": "F#m",
          "ourBPM": 117,
          "links": [
            {"type": "spotify", "url": "https://open.spotify.com/track/5ChkMS8OtdzJeqyybCc9R5"}
          ],
          "tags": ["pop", "80s", "dance"],
          "spotifyId": "5ChkMS8OtdzJeqyybCc9R5",
          "addedBy": "$ADMIN_UID",
          "addedAt": "$NOW",
          "createdAt": "$NOW",
          "updatedAt": "$NOW"
        },
        "demo_song_003": {
          "id": "demo_song_003",
          "title": "Wonderwall",
          "artist": "Oasis",
          "originalKey": "F#m",
          "originalBPM": 87,
          "ourKey": "G",
          "ourBPM": 90,
          "links": [
            {"type": "spotify", "url": "https://open.spotify.com/track/6Cy0IThCjjhjGzXOwK2m8O"}
          ],
          "tags": ["britpop", "90s", "acoustic"],
          "spotifyId": "6Cy0IThCjjhjGzXOwK2m8O",
          "addedBy": "$ADMIN_UID",
          "addedAt": "$NOW",
          "createdAt": "$NOW",
          "updatedAt": "$NOW"
        },
        "demo_song_004": {
          "id": "demo_song_004",
          "title": "Uptown Funk",
          "artist": "Mark Ronson ft. Bruno Mars",
          "originalKey": "Dm",
          "originalBPM": 115,
          "ourKey": "Dm",
          "ourBPM": 115,
          "links": [
            {"type": "spotify", "url": "https://open.spotify.com/track/32OlwWuMpZ6b0aN2RZOeMS"}
          ],
          "tags": ["funk", "pop", "dance"],
          "spotifyId": "32OlwWuMpZ6b0aN2RZOeMS",
          "addedBy": "$ADMIN_UID",
          "addedAt": "$NOW",
          "createdAt": "$NOW",
          "updatedAt": "$NOW"
        },
        "demo_song_005": {
          "id": "demo_song_005",
          "title": "Mr. Brightside",
          "artist": "The Killers",
          "originalKey": "Db",
          "originalBPM": 148,
          "ourKey": "Db",
          "ourBPM": 148,
          "links": [
            {"type": "spotify", "url": "https://open.spotify.com/track/0eGsygTp906u18L0Oimnem"}
          ],
          "tags": ["rock", "indie", "2000s"],
          "spotifyId": "0eGsygTp906u18L0Oimnem",
          "addedBy": "$ADMIN_UID",
          "addedAt": "$NOW",
          "createdAt": "$NOW",
          "updatedAt": "$NOW"
        }
      }
    }
  }
}
EOF

# Setlist
cat > "$TEMP_DIR/admin_setlists.json" << EOF
{
  "users": {
    "$ADMIN_UID": {
      "setlists": {
        "demo_setlist_001": {
          "id": "demo_setlist_001",
          "name": "Friday Gig Set",
          "description": "5-song set for the Friday bar gig. ~25 minutes.",
          "songs": [
            {"songId": "demo_song_003", "position": 0, "key": "G", "bpm": 90},
            {"songId": "demo_song_002", "position": 1, "key": "F#m", "bpm": 117},
            {"songId": "demo_song_001", "position": 2, "key": "D", "bpm": 125},
            {"songId": "demo_song_004", "position": 3, "key": "Dm", "bpm": 115},
            {"songId": "demo_song_005", "position": 4, "key": "Db", "bpm": 148}
          ],
          "eventDate": "$NEXT_WEEK",
          "eventLocation": "The Local Pub",
          "createdAt": "$NOW"
        }
      }
    }
  }
}
EOF

echo "📤 Importing data to Firestore..."
echo ""

# Import using Firebase CLI
echo "  1/4 Importing users..."
firebase firestore:import "$TEMP_DIR/users.json" --collection users 2>&1 | sed 's/^/     /' || echo "     ⚠️  Users import may have failed — check manually"

echo "  2/4 Importing band..."
firebase firestore:import "$TEMP_DIR/bands.json" --collection bands 2>&1 | sed 's/^/     /' || echo "     ⚠️  Band import may have failed — check manually"

echo "  3/4 Importing admin songs + setlist..."
firebase firestore:import "$TEMP_DIR/admin_songs.json" 2>&1 | sed 's/^/     /' || echo "     ⚠️  Songs import may have failed — check manually"
firebase firestore:import "$TEMP_DIR/admin_setlists.json" 2>&1 | sed 's/^/     /' || echo "     ⚠️  Setlist import may have failed — check manually"

echo "  4/4 Importing band songs..."
firebase firestore:import "$TEMP_DIR/band_songs.json" 2>&1 | sed 's/^/     /' || echo "     ⚠️  Band songs import may have failed — check manually"

echo ""
echo "╔═══════════════════════════════════════════════════╗"
echo "║       ✅ Demo Data Seeded                         ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""
echo "📊 Summary:"
echo "   Users:       2 (admin + demo)"
echo "   Band:        1 (The Cover Collective)"
echo "   Songs:       5 (with Spotify URIs + BPM)"
echo "   Setlists:    1 (Friday Gig Set)"
echo ""
echo "🎮 Test the demo:"
echo "   - Login with: demo@flowgroove.app / demo1234"
echo "   - You should see the band and songs (read-only)"
echo "   - Orange banner: 'Demo mode — changes are not saved'"
echo "   - Try to edit — changes should be blocked"
echo ""
echo "🔧 Test admin:"
echo "   - Login with: admin@flowgroove.app / admin1234"
echo "   - Full access: create/edit/delete songs, bands, setlists"
echo ""
