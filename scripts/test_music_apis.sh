#!/bin/bash

# Music API Quick Test Script
# Usage: ./test_music_apis.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test queries
SONG="Queen Bohemian Rhapsody"
SONG_ENCODED="Queen%20Bohemian%20Rhapsody"

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         RepSync Music API Quick Test                      ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Function to test API
test_api() {
    local name=$1
    local url=$2
    local headers=$3
    
    echo -e "${BLUE}Testing $name...${NC}"
    
    if [ -n "$headers" ]; then
        response=$(curl -s -w "\nHTTP_CODE:%{http_code}\nTIME:%{time_total}" $headers "$url")
    else
        response=$(curl -s -w "\nHTTP_CODE:%{http_code}\nTIME:%{time_total}" "$url")
    fi
    
    http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d':' -f2)
    time_taken=$(echo "$response" | grep "TIME:" | cut -d':' -f2)
    body=$(echo "$response" | grep -v "HTTP_CODE:" | grep -v "TIME:")
    
    if [ "$http_code" == "200" ]; then
        echo -e "${GREEN}✓ Success${NC} - HTTP $http_code - ${time_taken}s"
    else
        echo -e "${RED}✗ Failed${NC} - HTTP $http_code - ${time_taken}s"
    fi
    
    echo ""
}

# Test MusicBrainz
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. MusicBrainz (No Auth Required)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}Testing MusicBrainz...${NC}"
mb_response=$(curl -s -w "\nHTTP_CODE:%{http_code}\nTIME:%{time_total}" \
    -H "Accept: application/json" \
    -H "User-Agent: RepSync-Test/1.0" \
    "https://musicbrainz.org/ws/2/recording?query=$SONG_ENCODED&limit=1&fmt=json")
mb_code=$(echo "$mb_response" | grep "HTTP_CODE:" | cut -d':' -f2)
mb_time=$(echo "$mb_response" | grep "TIME:" | cut -d':' -f2)
if [ "$mb_code" == "200" ]; then
    echo -e "${GREEN}✓ Success${NC} - HTTP $mb_code - ${mb_time}s"
else
    echo -e "${RED}✗ Failed${NC} - HTTP $mb_code - ${mb_time}s"
fi
echo ""

# Test Deezer
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. Deezer (No Auth Required)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
test_api "Deezer" \
    "https://api.deezer.com/search?q=$SONG_ENCODED&limit=1"

# Test Discogs
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. Discogs (Unauthenticated)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
test_api "Discogs" \
    "https://api.discogs.com/database/search?q=$SONG_ENCODED&type=release&limit=1"

# Test Last.fm (will fail without API key)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. Last.fm (API Key Required)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
LASTFM_KEY="${LASTFM_API_KEY:-YOUR_API_KEY}"
test_api "Last.fm" \
    "https://ws.audioscrobbler.com/2.0/?method=track.search&track=Bohemian%20Rhapsody&artist=Queen&api_key=$LASTFM_KEY&format=json&limit=1"

# Test AcoustID (will fail without API key)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. AcoustID (API Key Required)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ACOUSTID_KEY="${ACOUSTID_API_KEY:-YOUR_API_KEY}"
test_api "AcoustID" \
    "https://api.acoustid.org/v2/lookup?client=$ACOUSTID_KEY&meta=recordingids&duration=176&fingerprint=AQADtNnXzJGjRIn37N7dO3fu3r179-7du3fv3r179-7du3fv3r17"

# Edge Cases
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. Edge Cases"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo -e "${YELLOW}Edge Case: Misspelling (Bohemian Rapsody)${NC}"
test_api "Deezer (Misspelling)" \
    "https://api.deezer.com/search?q=Queen%20Bohemian%20Rapsody&limit=1"

echo -e "${YELLOW}Edge Case: No 'The' (Beatles)${NC}"
test_api "Deezer (No The)" \
    "https://api.deezer.com/search?q=Beatles%20Hey%20Jude&limit=1"

echo -e "${YELLOW}Edge Case: Rare Song${NC}"
test_api "Deezer (Rare)" \
    "https://api.deezer.com/search?q=local%20band%20cover%20song&limit=1"

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              Test Summary                                 ║"
echo "╠═══════════════════════════════════════════════════════════╣"
echo "║  ✓ MusicBrainz: Free, no auth, 1 req/sec limit           ║"
echo "║  ✓ Deezer: Free, no auth (search), fast (~150ms)         ║"
echo "║  ✓ Discogs: Free, no auth (search), physical releases    ║"
echo "║  ⚠ Last.fm: Free API key required, popularity data       ║"
echo "║  ⚠ Spotify: OAuth required, BPM/Key data                 ║"
echo "║  ⚠ AcoustID: Free API key, audio fingerprinting          ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "For detailed documentation, see: docs/MUSIC_API_DEEP_ANALYSIS.md"
echo ""
