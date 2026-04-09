#!/bin/bash
# Seed Demo Data using Firebase REST API
# Works without firestore:import (which requires extra tools)
#
# Usage: bash scripts/seed_demo_data_rest.sh

set -e

ADMIN_UID="${ADMIN_UID:-olBOGC6HMsZpVyTqLyfLK4GRKyZ2}"
DEMO_UID="${DEMO_UID:-lePjILMinYV4A0UFbg5qePv6VBg2}"

echo "╔═══════════════════════════════════════════════════╗"
echo "║       FlowGroove Demo Data Seeder (REST API)      ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""

# Get Firebase access token
echo "🔑 Getting Firebase access token..."
TOKEN=$(gcloud auth print-access-token 2>/dev/null || echo "")

if [ -z "$TOKEN" ]; then
    echo "❌ Could not get access token."
    echo "   Run: gcloud auth login --update-adc"
    echo ""
    echo "   Alternatively, create data manually in Firebase Console:"
    echo "   1. Go to Firestore → users → Create document"
    echo "   2. Document ID: $ADMIN_UID"
    echo "   3. Add fields from CREATE_TEST_ACCOUNTS.md"
    exit 1
fi

# Get project info
PROJECT_ID="repsync-app-8685c"
BASE_URL="https://firestore.googleapis.com/v1/projects/$PROJECT_ID/databases/(default)/documents"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

echo ""
echo "📦 Creating admin user document..."

# Create admin user
curl -s -X POST "$BASE_URL/users" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"projects/$PROJECT_ID/databases/(default)/documents/users/$ADMIN_UID\",
    \"fields\": {
      \"uid\": {\"stringValue\": \"$ADMIN_UID\"},
      \"email\": {\"stringValue\": \"admin@flowgroove.app\"},
      \"displayName\": {\"stringValue\": \"Admin Tester\"},
      \"accessRole\": {\"stringValue\": \"admin\"},
      \"musicRoles\": {\"arrayValue\": {\"values\": [{\"stringValue\": \"drummer\"}, {\"stringValue\": \"sound_engineer\"}]}},
      \"systemTags\": {\"arrayValue\": {\"values\": [{\"stringValue\": \"test\"}, {\"stringValue\": \"demo_seeder\"}]}},
      \"bandIds\": {\"arrayValue\": {\"values\": []}},
      \"createdAt\": {\"timestampValue\": \"$NOW\"}
    }
  }" > /dev/null 2>&1 && echo "   ✅ Admin user created" || echo "   ⚠️  Admin user may already exist"

echo ""
echo "📦 Creating demo user document..."

# Create demo user
curl -s -X POST "$BASE_URL/users" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"projects/$PROJECT_ID/databases/(default)/documents/users/$DEMO_UID\",
    \"fields\": {
      \"uid\": {\"stringValue\": \"$DEMO_UID\"},
      \"email\": {\"stringValue\": \"demo@flowgroove.app\"},
      \"displayName\": {\"stringValue\": \"Demo User\"},
      \"accessRole\": {\"stringValue\": \"demo\"},
      \"musicRoles\": {\"arrayValue\": {\"values\": [{\"stringValue\": \"guitarist\"}, {\"stringValue\": \"vocalist\"}]}},
      \"systemTags\": {\"arrayValue\": {\"values\": [{\"stringValue\": \"demo\"}, {\"stringValue\": \"test\"}]}},
      \"bandIds\": {\"arrayValue\": {\"values\": []}},
      \"createdAt\": {\"timestampValue\": \"$NOW\"}
    }
  }" > /dev/null 2>&1 && echo "   ✅ Demo user created" || echo "   ⚠️  Demo user may already exist"

echo ""
echo "📦 Creating band..."

# Create band
curl -s -X POST "$BASE_URL/bands?documentId=demo_band_001" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"projects/$PROJECT_ID/databases/(default)/documents/bands/demo_band_001\",
    \"fields\": {
      \"id\": {\"stringValue\": \"demo_band_001\"},
      \"name\": {\"stringValue\": \"The Cover Collective\"},
      \"description\": {\"stringValue\": \"Demo band for testing all FlowGroove features.\"},
      \"createdBy\": {\"stringValue\": \"$ADMIN_UID\"},
      \"members\": {\"arrayValue\": {\"values\": [
        {\"mapValue\": {\"fields\": {
          \"uid\": {\"stringValue\": \"$ADMIN_UID\"},
          \"role\": {\"stringValue\": \"admin\"},
          \"displayName\": {\"stringValue\": \"Admin Tester\"},
          \"email\": {\"stringValue\": \"admin@flowgroove.app\"},
          \"musicRoles\": {\"arrayValue\": {\"values\": [{\"stringValue\": \"drummer\"}, {\"stringValue\": \"sound_engineer\"}]}}
        }}},
        {\"mapValue\": {\"fields\": {
          \"uid\": {\"stringValue\": \"$DEMO_UID\"},
          \"role\": {\"stringValue\": \"viewer\"},
          \"displayName\": {\"stringValue\": \"Demo User\"},
          \"email\": {\"stringValue\": \"demo@flowgroove.app\"},
          \"musicRoles\": {\"arrayValue\": {\"values\": [{\"stringValue\": \"guitarist\"}, {\"stringValue\": \"vocalist\"}]}}
        }}}
      ]}},
      \"memberUids\": {\"arrayValue\": {\"values\": [{\"stringValue\": \"$ADMIN_UID\"}, {\"stringValue\": \"$DEMO_UID\"}]}},
      \"adminUids\": {\"arrayValue\": {\"values\": [{\"stringValue\": \"$ADMIN_UID\"}]}},
      \"editorUids\": {\"arrayValue\": {\"values\": []}},
      \"tags\": {\"arrayValue\": {\"values\": [{\"stringValue\": \"rock\"}, {\"stringValue\": \"pop\"}, {\"stringValue\": \"covers\"}, {\"stringValue\": \"demo\"}]}},
      \"inviteCode\": {\"stringValue\": \"DEMO2026\"},
      \"createdAt\": {\"timestampValue\": \"$NOW\"}
    }
  }" > /dev/null 2>&1 && echo "   ✅ Band created" || echo "   ⚠️  Band may already exist"

echo ""
echo "📦 Creating band songs..."

# Create 5 songs in band subcollection
for song_json in \
  '{"id":"demo_song_001","title":"Sweet Child O'"'"' Mine","artist":"Guns N'"'"' Roses","originalKey":"Db","originalBPM":125,"ourKey":"D","ourBPM":125,"links":[{"type":"spotify","url":"https://open.spotify.com/track/7o2CTH4ctstm8TNelqjb51"}],"tags":["rock","classic rock","80s"],"spotifyId":"7o2CTH4ctstm8TNelqjb51"}' \
  '{"id":"demo_song_002","title":"Billie Jean","artist":"Michael Jackson","originalKey":"F#m","originalBPM":117,"ourKey":"F#m","ourBPM":117,"links":[{"type":"spotify","url":"https://open.spotify.com/track/5ChkMS8OtdzJeqyybCc9R5"}],"tags":["pop","80s","dance"],"spotifyId":"5ChkMS8OtdzJeqyybCc9R5"}' \
  '{"id":"demo_song_003","title":"Wonderwall","artist":"Oasis","originalKey":"F#m","originalBPM":87,"ourKey":"G","ourBPM":90,"links":[{"type":"spotify","url":"https://open.spotify.com/track/6Cy0IThCjjhjGzXOwK2m8O"}],"tags":["britpop","90s","acoustic"],"spotifyId":"6Cy0IThCjjhjGzXOwK2m8O"}' \
  '{"id":"demo_song_004","title":"Uptown Funk","artist":"Mark Ronson ft. Bruno Mars","originalKey":"Dm","originalBPM":115,"ourKey":"Dm","ourBPM":115,"links":[{"type":"spotify","url":"https://open.spotify.com/track/32OlwWuMpZ6b0aN2RZOeMS"}],"tags":["funk","pop","dance"],"spotifyId":"32OlwWuMpZ6b0aN2RZOeMS"}' \
  '{"id":"demo_song_005","title":"Mr. Brightside","artist":"The Killers","originalKey":"Db","originalBPM":148,"ourKey":"Db","ourBPM":148,"links":[{"type":"spotify","url":"https://open.spotify.com/track/0eGsygTp906u18L0Oimnem"}],"tags":["rock","indie","2000s"],"spotifyId":"0eGsygTp906u18L0Oimnem"}'; do
  
  SONG_ID=$(echo "$song_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
  
  curl -s -X POST "$BASE_URL/bands/demo_band_001/songs?documentId=$SONG_ID" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"projects/$PROJECT_ID/databases/(default)/documents/bands/demo_band_001/songs/$SONG_ID\",
      \"fields\": {
        $(echo "$song_json" | python3 -c "
import sys, json
data = json.load(sys.stdin)
fields = []
for k, v in data.items():
    if isinstance(v, str):
        fields.append(f'\"{k}\": {{\"stringValue\": \"{v}\"}}')
    elif isinstance(v, int):
        fields.append(f'\"{k}\": {{\"integerValue\": {v}}}')
    elif isinstance(v, list):
        vals = ','.join([f'{{\"mapValue\": {{\"fields\": {{\"type\": {{\"stringValue\": \"{item[\"type\"]}\"}}, \"url\": {{\"stringValue\": \"{item[\"url\"]}\"}}}}}}}}]' for item in v])
        fields.append(f'\"{k}\": {{\"arrayValue\": {{\"values\": [{vals}]}}}}')
print(','.join(fields))
")
        ,
        \"addedBy\": {\"stringValue\": \"$ADMIN_UID\"},
        \"addedAt\": {\"timestampValue\": \"$NOW\"},
        \"createdAt\": {\"timestampValue\": \"$NOW\"},
        \"updatedAt\": {\"timestampValue\": \"$NOW\"}
      }
    }" > /dev/null 2>&1 && echo "   ✅ $SONG_ID" || echo "   ⚠️  $SONG_ID may already exist"
done

echo ""
echo "╔═══════════════════════════════════════════════════╗"
echo "║       ✅ Demo Data Seeded                         ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""
echo "📊 Summary:"
echo "   Users:       2 (admin + demo)"
echo "   Band:        1 (The Cover Collective)"
echo "   Songs:       5 (with Spotify URIs + BPM)"
echo ""
echo "🎮 Test the demo:"
echo "   - Login: demo@flowgroove.app / demo1234"
echo "   - Orange banner should appear"
echo "   - Changes should be blocked"
echo ""
