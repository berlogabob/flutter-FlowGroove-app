# Firestore Schema: canonical_songs

## Collection Overview

The `canonical_songs` collection stores global song metadata that serves as the source of truth for all song arrangements across users and bands.

## Collection Path
```
/canonical_songs/{songId}
```

## Document Structure

```typescript
{
  // === Identity ===
  id: string;                    // Document ID (UUID or MusicBrainz ID)
  
  // === Core Metadata ===
  title: string;                 // Song title (canonical form)
  artist: string;                // Primary artist/band name
  artists: string[];             // All artists (featuring, collaborators)
  album?: string;                // Album name
  releaseYear?: number;          // Year of release
  durationMs?: number;           // Duration in milliseconds
  
  // === External IDs ===
  musicBrainzId?: string;        // MusicBrainz Recording ID (UUID)
  musicBrainzWorkId?: string;    // MusicBrainz Work ID (UUID)
  isrc?: string;                 // International Standard Recording Code
  iswc?: string;                 // International Standard Musical Work Code
  spotifyId?: string;            // Spotify Track ID
  
  // === Normalized Fields (for search) ===
  normalizedTitle: string;       // Lowercase, trimmed title
  normalizedArtist: string;      // Lowercase, trimmed artist
  
  // === Additional Metadata ===
  genres: string[];              // Music genres
  disambiguation?: string;       // e.g., "live", "acoustic version"
  
  // === Timestamps ===
  createdAt: Timestamp;          // When created
  updatedAt: Timestamp;          // When last updated
}
```

## Example Document

```json
{
  "id": "b1a9c0e9-d987-4042-ae91-78d6a3267d69",
  "title": "Bohemian Rhapsody",
  "artist": "Queen",
  "artists": ["Queen"],
  "album": "A Night at the Opera",
  "releaseYear": 1975,
  "durationMs": 354000,
  "musicBrainzId": "b1a9c0e9-d987-4042-ae91-78d6a3267d69",
  "musicBrainzWorkId": "99d6f0e9-d987-4042-ae91-78d6a3267d69",
  "isrc": "GBUM71029604",
  "spotifyId": "7tFiyTwD0nx5a1eklYtX2J",
  "normalizedTitle": "bohemian rhapsody",
  "normalizedArtist": "queen",
  "genres": ["rock", "progressive rock", "opera"],
  "disambiguation": null,
  "createdAt": "2026-03-30T12:00:00Z",
  "updatedAt": "2026-03-30T12:00:00Z"
}
```

## Indexes

### Single-Field Indexes

| Field | Order | Purpose |
|-------|-------|---------|
| `normalizedTitle` | ASCENDING | Prefix search by title |
| `normalizedArtist` | ASCENDING | Prefix search by artist |
| `musicBrainzId` | ASCENDING | Lookup by MBID |
| `isrc` | ASCENDING | Lookup by ISRC |
| `createdAt` | DESCENDING | Sort by creation date |

### Composite Indexes

| Fields | Order | Purpose |
|--------|-------|---------|
| `normalizedTitle`, `normalizedArtist` | ASCENDING, ASCENDING | Combined search |
| `artist`, `title` | ASCENDING, ASCENDING | Browse by artist |

## Query Patterns

### Search by Title
```dart
collection('canonical_songs')
  .where('normalizedTitle', isGreaterThanOrEqualTo: 'bohemian')
  .where('normalizedTitle', isLessThanOrEqualTo: 'bohemian\uf8ff')
  .limit(20)
```

### Search by Title + Artist
```dart
collection('canonical_songs')
  .where('normalizedTitle', isGreaterThanOrEqualTo: 'bohemian')
  .where('normalizedTitle', isLessThanOrEqualTo: 'bohemian\uf8ff')
  .where('normalizedArtist', isEqualTo: 'queen')
  .limit(20)
```

### Lookup by MusicBrainz ID
```dart
collection('canonical_songs')
  .where('musicBrainzId', isEqualTo: 'b1a9c0e9-...')
  .limit(1)
```

### Lookup by ISRC
```dart
collection('canonical_songs')
  .where('isrc', isEqualTo: 'GBUM71029604')
  .limit(1)
```

## Access Patterns

### Read Access
- **All authenticated users**: Can read all canonical songs
- **Public data**: No user-specific restrictions

### Write Access
- **Create**: Only via Cloud Functions or admin users
- **Update**: Only via Cloud Functions or admin users  
- **Delete**: Only via Cloud Functions or admin users

### Rationale
Canonical songs are global shared data. Regular users should not modify them directly to prevent:
- Duplicate entries
- Data corruption
- Inconsistent metadata

Updates should go through:
1. MusicBrainz import (automated)
2. Admin review process
3. Cloud Functions with validation

## Relationships

### From Song Arrangements
```
/song_arrangements/{arrangementId}
  └── canonicalSongId → /canonical_songs/{songId}
```

### From Songs (Legacy)
```
/songs/{songId}
  └── canonicalSongId → /canonical_songs/{songId}
```

## Migration Notes

### Creating Canonical Songs from Existing Data

1. **Group similar songs** using fuzzy matching
2. **Create canonical song** with best metadata
3. **Link existing songs** via `canonicalSongId` field
4. **Preserve original data** in arrangements

### Backwards Compatibility

- Existing `Song` documents continue to work
- New `canonicalSongId` field is optional
- Gradual migration recommended

## Security Rules

See `firestore.rules` for complete security configuration.

Key rules:
```javascript
match /canonical_songs/{songId} {
  allow read: if request.auth != null;
  allow write: if false; // Only via Cloud Functions
}
```

## Performance Considerations

### Query Optimization
- Always use `normalizedTitle` for search (indexed)
- Use prefix search with `\uf8ff` sentinel
- Limit results to 20-50 per query

### Caching
- Cache frequently accessed songs locally
- Use Firestore offline persistence
- Consider Redis cache for hot data

### Cost Optimization
- Read-heavy collection (optimize for reads)
- Batch writes when creating multiple songs
- Use field masks for partial updates
