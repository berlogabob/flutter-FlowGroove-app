# Music API Quick Reference

**For:** RepSync Development Team  
**Last Updated:** February 28, 2026  

---

## 🚀 Quick Start

### Best API for Each Use Case

| Use Case | API | Auth Required | Cost |
|----------|-----|---------------|------|
| **Song Search** | Deezer | ❌ No | Free |
| **BPM/Key Detection** | Spotify | ✅ OAuth | Free |
| **Rich Metadata** | MusicBrainz | ❌ No | Free |
| **Audio Recognition** | AcoustID | ✅ API Key | Free |
| **Physical Releases** | Discogs | ❌ No (search) | Free |
| **Popularity Data** | Last.fm | ✅ API Key | Free |

---

## 📊 API Comparison (Tested Results)

| API | Avg Response | Success Rate | Rate Limit |
|-----|--------------|--------------|------------|
| **Deezer** | 143ms | 100% | Undisclosed |
| **MusicBrainz** | 183ms | 100% | 1 req/sec |
| **Discogs** | 244ms | 100% | 25/min (unauth) |

---

## 🔑 API Keys Needed

| API | Key Required | Setup Time | Get Key At |
|-----|--------------|------------|------------|
| MusicBrainz | ❌ No | 0 min | N/A |
| Deezer | ❌ No (search) | 0 min | N/A |
| Discogs | ❌ No (search) | 0 min | N/A |
| Last.fm | ✅ Yes | 5 min | https://www.last.fm/api/account/create |
| Spotify | ✅ OAuth | 15 min | https://developer.spotify.com/dashboard |
| AcoustID | ✅ Yes | 5 min | https://acoustid.org/api-key |
| ACRCloud | ✅ Yes | 10 min | https://www.acrcloud.com/ |
| Audd.io | ✅ Yes | 5 min | https://audd.io/ |

---

## 🎯 Recommended Implementation Order

### Phase 1: Core Search (Week 1-2)
```dart
// 1. Deezer (primary)
final deezerResults = await deezer.search('Queen Bohemian Rhapsody');

// 2. MusicBrainz (fallback)
final mbResults = await musicBrainz.search('Queen Bohemian Rhapsody');
```

### Phase 2: Audio Features (Week 3-4)
```dart
// Spotify OAuth + Audio Features
final token = await spotify.getClientCredentialsToken();
final audioFeatures = await spotify.getAudioFeatures(trackId);
// Returns: BPM, Key, Mode, Danceability, Energy, etc.
```

### Phase 3: Audio Recognition (Week 5-6)
```dart
// AcoustID + Chromaprint
final fingerprint = await chromaprint.generate(audioFile);
final result = await acoustid.lookup(fingerprint);
// Returns: MusicBrainz ID, then fetch metadata from MusicBrainz
```

---

## 📦 Data Fields Available

| Field | Deezer | MusicBrainz | Spotify | Last.fm | Discogs |
|-------|--------|-------------|---------|---------|---------|
| Title | ✅ | ✅ | ✅ | ✅ | ✅ |
| Artist | ✅ | ✅ | ✅ | ✅ | ✅ |
| Album | ✅ | ✅ | ✅ | ⚠️ | ✅ |
| Duration | ✅ | ✅ | ✅ | ❌ | ❌ |
| ISRC | ✅ | ✅ | ✅ | ❌ | ❌ |
| **BPM** | ❌ | ❌ | ✅ | ❌ | ❌ |
| **Key** | ❌ | ❌ | ✅ | ❌ | ❌ |
| Preview | ✅ | ❌ | ✅ | ❌ | ❌ |
| Cover Art | ✅ | ⚠️ | ✅ | ✅ | ✅ |
| Popularity | ✅ | ❌ | ✅ | ✅ | ⚠️ |

---

## 🔒 Security Best Practices

### Environment Variables
```env
# .env file (NEVER commit!)
LASTFM_API_KEY=your_key_here
SPOTIFY_CLIENT_ID=your_client_id
SPOTIFY_CLIENT_SECRET=your_client_secret
ACOUSTID_API_KEY=your_key_here
```

### Flutter Implementation
```dart
// Use flutter_dotenv
import 'package:flutter_dotenv/flutter_dotenv.dart';
final apiKey = dotenv.env['LASTFM_API_KEY'];

// Use flutter_secure_storage for tokens
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
await storage.write(key: 'spotify_token', value: token);
```

---

## ⚠️ Rate Limits

| API | Limit | Handling Strategy |
|-----|-------|-------------------|
| MusicBrainz | 1 req/sec | Queue requests, 1s delay |
| Deezer | Undisclosed | Cache results 24h |
| Discogs | 25/min (unauth) | Cache results 24h |
| Spotify | Undisclosed | Token caching, batch requests |
| Last.fm | ~5 req/sec | Cache results 24h |
| AcoustID | 3 req/sec | Queue requests |

---

## 🧪 Testing

### Run Test Script
```bash
cd /Users/berloga/Documents/GitHub/flutter_repsync_app
dart scripts/test_music_apis.dart
```

### Manual Testing
```bash
# Deezer
curl "https://api.deezer.com/search?q=Queen%20Bohemian%20Rhapsody&limit=1"

# MusicBrainz
curl -H "User-Agent: RepSync-Test/1.0" \
  "https://musicbrainz.org/ws/2/recording?query=Queen+Bohemian+Rhapsody&limit=1&fmt=json"

# Discogs
curl "https://api.discogs.com/database/search?q=Queen+Bohemian+Rhapsody&type=release&limit=1"
```

---

## 💰 Cost Estimates

| Tier | Monthly Cost | APIs Included |
|------|--------------|---------------|
| **Free** | $0 | Deezer, MusicBrainz, Discogs, Last.fm, AcoustID |
| **Basic** | $0 | Free + Spotify OAuth |
| **Premium** | $20-150 | Free + ACRCloud/Audd.io for recognition |

---

## 📚 Documentation

- **Full Analysis:** `docs/MUSIC_API_DEEP_ANALYSIS.md`
- **Test Script:** `scripts/test_music_apis.dart`
- **API Setup Guide:** See Section 7 in full documentation

---

## 🎯 Quick Decisions

### Need to search for songs?
→ **Use Deezer** (fast, no auth, ISRC included)

### Need BPM and key for DJ mixing?
→ **Use Spotify** (only API with audio features)

### Need to identify a recording?
→ **Use AcoustID** (free, open source)

### Need vinyl/CD release info?
→ **Use Discogs** (physical release database)

### Need popularity/listener counts?
→ **Use Last.fm** (scrobbling database)

### Need rich metadata relationships?
→ **Use MusicBrainz** (community-maintained)

---

## 📞 Support

| API | Support Channel | Response Time |
|-----|-----------------|---------------|
| MusicBrainz | Forum/IRC | Hours |
| Spotify | Email | Days |
| Deezer | Forum | Days |
| Last.fm | Forum | Days |
| Discogs | Forum | Days |
| AcoustID | Email | Days |

---

**End of Quick Reference**

For detailed analysis, see: `docs/MUSIC_API_DEEP_ANALYSIS.md`
