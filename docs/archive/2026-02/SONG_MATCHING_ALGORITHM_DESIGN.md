# Song Matching Algorithm Design

**Document Version:** 1.0  
**Date:** February 28, 2026  
**Author:** System Architecture Team  
**Status:** Design Specification

---

## Executive Summary

This document specifies a comprehensive fuzzy matching algorithm for identifying duplicate songs in the RepSync application. The algorithm handles typos, variations in formatting, and different naming conventions while providing an intuitive user experience for confirming matches.

**Problem Statement:**  
User types "Queen - Bohemian Rapsody" (typo) → should match existing "Queen - Bohemian Rhapsody"

---

## 1. String Normalization Pipeline

### 1.1 Overview

The normalization pipeline transforms input strings into a canonical form for comparison. This reduces false negatives caused by superficial differences.

### 1.2 Normalization Steps (Ordered Pipeline)

```
Input String
    ↓
[1] Unicode Normalization (NFKC)
    ↓
[2] Lowercase Conversion
    ↓
[3] Remove Special Characters
    ↓
[4] Handle "The" Prefix
    ↓
[5] Handle Features/Collaborations
    ↓
[6] Handle Version Suffixes
    ↓
[7] Handle Parenthetical Content
    ↓
[8] Whitespace Normalization
    ↓
Normalized String
```

### 1.3 Detailed Implementation

#### Step 1: Unicode Normalization (NFKC)
```dart
String normalizeUnicode(String input) {
  // NFKC: Compatibility Composition
  // Converts compatibility characters to their canonical forms
  // Example: "ﬁ" → "fi", "½" → "1/2"
  return input.normalize(NormalizationForm.nfkc);
}
```

#### Step 2: Lowercase Conversion
```dart
String toLowerCase(String input) {
  return input.toLowerCase();
}
```

#### Step 3: Remove Special Characters
```dart
String removeSpecialCharacters(String input) {
  // Keep only alphanumeric, spaces, and basic punctuation
  return input
    .replaceAll(RegExp(r'[^\w\s\-]'), ' ')  // Replace special chars with space
    .replaceAll(RegExp(r'\s+'), ' ');        // Collapse multiple spaces
}
```

#### Step 4: Handle "The" Prefix
```dart
String removeThePrefix(String input) {
  // Remove leading "the " from artist names
  return input.replaceFirst(RegExp(r'^the\s+'), '');
}

// Examples:
// "The Beatles" → "beatles"
// "The Rolling Stones" → "rolling stones"
// "There Is A Mountain" → "there is a mountain" (not affected)
```

#### Step 5: Handle Features/Collaborations
```dart
String removeFeatures(String input) {
  // Remove "feat.", "ft.", "featuring", "with", "vs.", "x"
  final patterns = [
    RegExp(r'\s+feat\.?\s+.*$', caseSensitive: false),
    RegExp(r'\s+ft\.?\s+.*$', caseSensitive: false),
    RegExp(r'\s+featuring\s+.*$', caseSensitive: false),
    RegExp(r'\s+with\s+.*$', caseSensitive: false),
    RegExp(r'\s+vs\.?\s+.*$', caseSensitive: false),
    RegExp(r'\s+x\s+.*$', caseSensitive: false),
    RegExp(r'\s+&\s+.*$', caseSensitive: false),  // Handle "Artist & Other"
  ];
  
  String result = input;
  for (final pattern in patterns) {
    result = result.replaceAll(pattern, '');
  }
  return result.trim();
}

// Examples:
// "Song feat. Artist" → "song"
// "Song ft. John" → "song"
// "Song featuring Mary" → "song"
```

#### Step 6: Handle Version Suffixes
```dart
String removeVersionSuffixes(String input) {
  final patterns = [
    RegExp(r'\s*-\s*remastered\s*(\d{4})?\s*$', caseSensitive: false),
    RegExp(r'\s*-\s*remix\s*$', caseSensitive: false),
    RegExp(r'\s*-\s*radio\s+edit\s*$', caseSensitive: false),
    RegExp(r'\s*-\s*album\s+version\s*$', caseSensitive: false),
    RegExp(r'\s*-\s*single\s+version\s*$', caseSensitive: false),
    RegExp(r'\s*-\s*extended\s+mix\s*$', caseSensitive: false),
    RegExp(r'\s*-\s*clean\s+version\s*$', caseSensitive: false),
    RegExp(r'\s*-\s*explicit\s+version\s*$', caseSensitive: false),
  ];
  
  String result = input;
  for (final pattern in patterns) {
    result = result.replaceAll(pattern, '');
  }
  return result.trim();
}

// Examples:
// "Song - Remastered 2011" → "song"
// "Song - Remaster" → "song"
// "Song - Radio Edit" → "song"
```

#### Step 7: Handle Parenthetical Content
```dart
String removeParentheticalContent(String input) {
  // Remove common parenthetical suffixes
  final patterns = [
    RegExp(r'\s*\(live\)', caseSensitive: false),
    RegExp(r'\s*\(live\s+version\)', caseSensitive: false),
    RegExp(r'\s*\(live\s+at\s+.*\)', caseSensitive: false),
    RegExp(r'\s*\(acoustic\)', caseSensitive: false),
    RegExp(r'\s*\(acoustic\s+version\)', caseSensitive: false),
    RegExp(r'\s*\(unplugged\)', caseSensitive: false),
    RegExp(r'\s*\(instrumental\)', caseSensitive: false),
    RegExp(r'\s*\(karaoke\s+version\)', caseSensitive: false),
    RegExp(r'\s*\(cover\)', caseSensitive: false),
    RegExp(r'\s*\(demo\)', caseSensitive: false),
    RegExp(r'\s*\(radio\s+edit\)', caseSensitive: false),
    RegExp(r'\s*\(album\s+version\)', caseSensitive: false),
    RegExp(r'\s*\(single\s+version\)', caseSensitive: false),
    RegExp(r'\s*\(remix\)', caseSensitive: false),
    RegExp(r'\s*\(remastered\)', caseSensitive: false),
    RegExp(r'\s*\(re-recording\)', caseSensitive: false),
    RegExp(r'\s*\(re-recorded\)', caseSensitive: false),
    RegExp(r'\s*\(version\s+.*\)', caseSensitive: false),
    RegExp(r'\s*\(feat\.?\s+.*\)', caseSensitive: false),
    RegExp(r'\s*\(ft\.?\s+.*\)', caseSensitive: false),
  ];
  
  String result = input;
  for (final pattern in patterns) {
    result = result.replaceAll(pattern, '');
  }
  
  // Remove empty parentheses
  result = result.replaceAll(RegExp(r'\s*\(\s*\)'), '');
  
  return result.trim();
}

// Examples:
// "Song (Live)" → "song"
// "Song (Live at Wembley)" → "song"
// "Song (Acoustic Version)" → "song"
// "Song (Remastered 2011)" → "song"
```

#### Step 8: Whitespace Normalization
```dart
String normalizeWhitespace(String input) {
  return input
    .replaceAll(RegExp(r'\s+'), ' ')  // Collapse multiple spaces
    .trim();                           // Remove leading/trailing
}
```

### 1.4 Complete Normalization Function

```dart
class SongNormalizer {
  static String normalize(String input) {
    if (input.isEmpty) return '';
    
    return input
      // Step 1: Unicode normalization
      .normalize(NormalizationForm.nfkc)
      // Step 2: Lowercase
      .toLowerCase()
      // Step 3: Remove special characters
      .replaceAll(RegExp(r'[^\w\s\-]'), ' ')
      // Step 8: Whitespace normalization (early to clean up)
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      // Step 4: Remove "The" prefix
      .replaceFirst(RegExp(r'^the\s+'), '')
      // Step 5: Remove features
      .replaceAll(RegExp(r'\s+feat\.?\s+.*$'), '')
      .replaceAll(RegExp(r'\s+ft\.?\s+.*$'), '')
      .replaceAll(RegExp(r'\s+featuring\s+.*$'), '')
      // Step 6: Remove version suffixes
      .replaceAll(RegExp(r'\s*-\s*remastered\s*(\d{4})?\s*$'), '')
      .replaceAll(RegExp(r'\s*-\s*remix\s*$'), '')
      .replaceAll(RegExp(r'\s*-\s*radio\s+edit\s*$'), '')
      // Step 7: Remove parenthetical content
      .replaceAll(RegExp(r'\s*\(live\)?'), '')
      .replaceAll(RegExp(r'\s*\(acoustic\)?'), '')
      .replaceAll(RegExp(r'\s*\(unplugged\)'), '')
      .replaceAll(RegExp(r'\s*\(instrumental\)'), '')
      .replaceAll(RegExp(r'\s*\(remix\)'), '')
      .replaceAll(RegExp(r'\s*\(remastered\)'), '')
      .replaceAll(RegExp(r'\s*\(cover\)'), '')
      .replaceAll(RegExp(r'\s*\(demo\)'), '')
      .replaceAll(RegExp(r'\s*\(feat\.?\s+.*\)'), '')
      .replaceAll(RegExp(r'\s*\(ft\.?\s+.*\)'), '')
      // Final cleanup
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  }
  
  static String normalizeTitle(String title) => normalize(title);
  
  static String normalizeArtist(String artist) {
    // Additional artist-specific normalization
    return normalize(artist)
      .replaceAll(RegExp(r'\s+and\s+'), ' & ')  // "Simon and Garfunkel" → "simon & garfunkel"
      .replaceAll(RegExp(r'\s*&\s*'), '&');     // Normalize ampersand
  }
}
```

---

## 2. Fuzzy Matching Algorithms

### 2.1 Algorithm Selection

We implement a multi-algorithm approach for robust matching:

| Algorithm | Use Case | Weight |
|-----------|----------|--------|
| **Levenshtein Distance** | Typo tolerance (insertions, deletions, substitutions) | 35% |
| **Jaro-Winkler Distance** | Similar strings with common prefixes | 30% |
| **Token Sort Ratio** | Word order variations | 25% |
| **Phonetic Matching (Soundex)** | Homophones and pronunciation variants | 10% |

### 2.2 Levenshtein Distance

**Purpose:** Measures minimum edit distance between two strings.

**Formula:**
```
lev(a, b) = minimum number of single-character edits
            (insertions, deletions, substitutions)
            required to change string a into string b
```

**Implementation:**
```dart
class Levenshtein {
  static int distance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;
    
    final matrix = List.generate(
      s2.length + 1,
      (i) => List.filled(s1.length + 1, 0),
    );
    
    for (var i = 0; i <= s1.length; i++) matrix[0][i] = i;
    for (var j = 0; j <= s2.length; j++) matrix[j][0] = j;
    
    for (var j = 1; j <= s2.length; j++) {
      for (var i = 1; i <= s1.length; i++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[j][i] = [
          matrix[j][i - 1] + 1,      // deletion
          matrix[j - 1][i] + 1,      // insertion
          matrix[j - 1][i - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
        
        // Damerau extension: transposition
        if (i > 1 && j > 1 &&
            s1[i - 1] == s2[j - 2] &&
            s1[i - 2] == s2[j - 1]) {
          matrix[j][i] = min(matrix[j][i], matrix[j - 2][i - 2] + cost);
        }
      }
    }
    
    return matrix[s2.length][s1.length];
  }
  
  static double similarity(String s1, String s2) {
    final maxLen = max(s1.length, s2.length);
    if (maxLen == 0) return 1.0;
    return 1.0 - (distance(s1, s2) / maxLen);
  }
}
```

**Example:**
```
"bohemian rhapsody" vs "bohemian rapsody"
Levenshtein Distance: 1 (one substitution: h → s)
Similarity: 1 - (1/17) = 0.941 (94.1%)
```

### 2.3 Jaro-Winkler Distance

**Purpose:** Better for short strings with common prefixes (like song titles).

**Formula:**
```
Jaro(a, b) = (1/3) * (m/|a| + m/|b| + (m-t)/m)

Where:
  m = number of matching characters
  t = number of transpositions
  |a|, |b| = lengths of strings

Jaro-Winkler(a, b) = Jaro(a, b) + (l * p * (1 - Jaro(a, b)))

Where:
  l = length of common prefix (max 4)
  p = prefix weight (typically 0.1)
```

**Implementation:**
```dart
class JaroWinkler {
  static const double _prefixWeight = 0.1;
  static const int _maxPrefixLength = 4;
  
  static double similarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    
    final searchRange = (max(s1.length, s2.length) ~/ 2) - 1;
    if (searchRange < 0) return 0.0;
    
    final s1Matches = List.filled(s1.length, false);
    final s2Matches = List.filled(s2.length, false);
    
    int matches = 0;
    double transpositions = 0.0;
    
    // Find matches
    for (var i = 0; i < s1.length; i++) {
      final start = max(0, i - searchRange);
      final end = min(i + searchRange + 1, s2.length);
      
      for (var j = start; j < end; j++) {
        if (s2Matches[j] || s1[i] != s2[j]) continue;
        s1Matches[i] = true;
        s2Matches[j] = true;
        matches++;
        break;
      }
    }
    
    if (matches == 0) return 0.0;
    
    // Count transpositions
    var k = 0;
    for (var i = 0; i < s1.length; i++) {
      if (!s1Matches[i]) continue;
      while (!s2Matches[k]) k++;
      if (s1[i] != s2[k]) transpositions++;
      k++;
    }
    transpositions /= 2;
    
    // Calculate Jaro similarity
    final jaro = (matches / s1.length + 
                  matches / s2.length + 
                  (matches - transpositions) / matches) / 3;
    
    // Calculate common prefix length
    int prefixLength = 0;
    for (var i = 0; i < min(_maxPrefixLength, min(s1.length, s2.length)); i++) {
      if (s1[i] == s2[i]) prefixLength++;
      else break;
    }
    
    // Apply Winkler modification
    return jaro + (prefixLength * _prefixWeight * (1 - jaro));
  }
}
```

**Example:**
```
"bohemian rhapsody" vs "bohemian rapsody"
Jaro-Winkler: ~0.97 (boosted by common prefix "bohe")
```

### 2.4 Token Sort Ratio

**Purpose:** Handles word order variations.

**Implementation:**
```dart
class TokenSortRatio {
  static double similarity(String s1, String s2) {
    // Split into tokens and sort
    final tokens1 = s1.split(RegExp(r'\s+'))..sort();
    final tokens2 = s2.split(RegExp(r'\s+'))..sort();
    
    // Join sorted tokens
    final sorted1 = tokens1.join(' ');
    final sorted2 = tokens2.join(' ');
    
    // Calculate Levenshtein similarity on sorted strings
    return Levenshtein.similarity(sorted1, sorted2);
  }
}

// Example:
// "bohemian rhapsody queen" vs "queen bohemian rhapsody"
// After sorting: "bohemian queen rhapsody" vs "bohemian queen rhapsody"
// Similarity: 1.0 (100%)
```

### 2.5 Phonetic Matching (Soundex/Metaphone)

**Purpose:** Catches homophones and pronunciation variants.

**Implementation:**
```dart
class Soundex {
  static String encode(String input) {
    if (input.isEmpty) return '';
    
    input = input.toUpperCase();
    final firstLetter = input[0];
    
    // Mapping: BFPV=1, CGJKQSXZ=2, DT=3, L=4, MN=5, R=6
    final encoding = StringBuffer(firstLetter);
    String? lastCode;
    
    for (var i = 1; i < input.length; i++) {
      final char = input[i];
      String? code;
      
      if ('BFPV'.contains(char)) code = '1';
      else if ('CGJKQSXZ'.contains(char)) code = '2';
      else if ('DT'.contains(char)) code = '3';
      else if ('L'.contains(char)) code = '4';
      else if ('MN'.contains(char)) code = '5';
      else if ('R'.contains(char)) code = '6';
      
      if (code != null && code != lastCode) {
        encoding.write(code);
      }
      lastCode = code;
    }
    
    // Pad to 4 characters
    var result = encoding.toString();
    while (result.length < 4) {
      result += '0';
    }
    return result.substring(0, 4);
  }
  
  static bool isSimilar(String s1, String s2) {
    return encode(s1) == encode(s2);
  }
}

// Example:
// "rhapsody" → R123
// "rapsody" → R123
// Match: true
```

---

## 3. Multi-Factor Scoring System

### 3.1 Scoring Formula

```
Match Score = (
  title_similarity * 0.40 +
  artist_similarity * 0.40 +
  duration_similarity * 0.10 +
  album_similarity * 0.10
) * 100
```

### 3.2 Component Calculations

```dart
class MatchScorer {
  static MatchScore calculate({
    required String inputTitle,
    required String inputArtist,
    required int? inputDuration,
    required String? inputAlbum,
    required Song existingSong,
  }) {
    // Normalize inputs
    final normInputTitle = SongNormalizer.normalizeTitle(inputTitle);
    final normInputArtist = SongNormalizer.normalizeArtist(inputArtist);
    final normExistingTitle = SongNormalizer.normalizeTitle(existingSong.title);
    final normExistingArtist = SongNormalizer.normalizeArtist(existingSong.artist);
    
    // Calculate title similarity (weighted average of algorithms)
    final titleLevenshtein = Levenshtein.similarity(normInputTitle, normExistingTitle);
    final titleJaroWinkler = JaroWinkler.similarity(normInputTitle, normExistingTitle);
    final titleTokenSort = TokenSortRatio.similarity(normInputTitle, normExistingTitle);
    
    final titleSimilarity = (
      titleLevenshtein * 0.35 +
      titleJaroWinkler * 0.35 +
      titleTokenSort * 0.20 +
      (Soundex.isSimilar(normInputTitle, normExistingTitle) ? 0.10 : 0.0)
    );
    
    // Calculate artist similarity
    final artistLevenshtein = Levenshtein.similarity(normInputArtist, normExistingArtist);
    final artistJaroWinkler = JaroWinkler.similarity(normInputArtist, normExistingArtist);
    final artistTokenSort = TokenSortRatio.similarity(normInputArtist, normExistingArtist);
    
    final artistSimilarity = (
      artistLevenshtein * 0.40 +
      artistJaroWinkler * 0.40 +
      artistTokenSort * 0.20
    );
    
    // Calculate duration similarity (if available)
    double durationSimilarity = 0.0;
    if (inputDuration != null && existingSong.durationMs != null) {
      final durationDiff = (inputDuration - existingSong.durationMs!).abs();
      // Within 5 seconds = 100%, within 10 seconds = 80%, etc.
      durationSimilarity = max(0, 1.0 - (durationDiff / 10000));
    }
    
    // Calculate album similarity (if available)
    double albumSimilarity = 0.0;
    if (inputAlbum != null && inputAlbum.isNotEmpty) {
      final normInputAlbum = SongNormalizer.normalize(inputAlbum);
      final normExistingAlbum = SongNormalizer.normalize(existingSong.album ?? '');
      if (normExistingAlbum.isNotEmpty) {
        albumSimilarity = Levenshtein.similarity(normInputAlbum, normExistingAlbum);
      }
    }
    
    // Calculate final score
    final score = (
      titleSimilarity * 0.40 +
      artistSimilarity * 0.40 +
      durationSimilarity * 0.10 +
      albumSimilarity * 0.10
    ) * 100;
    
    return MatchScore(
      total: score,
      titleSimilarity: titleSimilarity * 100,
      artistSimilarity: artistSimilarity * 100,
      durationSimilarity: durationSimilarity * 100,
      albumSimilarity: albumSimilarity * 100,
      matchedSong: existingSong,
    );
  }
}

class MatchScore {
  final double total;
  final double titleSimilarity;
  final double artistSimilarity;
  final double durationSimilarity;
  final double albumSimilarity;
  final Song matchedSong;
  
  MatchScore({
    required this.total,
    required this.titleSimilarity,
    required this.artistSimilarity,
    required this.durationSimilarity,
    required this.albumSimilarity,
    required this.matchedSong,
  });
  
  String get grade {
    if (total >= 95) return 'EXACT';
    if (total >= 85) return 'HIGH';
    if (total >= 70) return 'MEDIUM';
    if (total >= 50) return 'LOW';
    return 'NONE';
  }
}
```

---

## 4. Threshold Recommendations

### 4.1 Match Confidence Levels

| Score Range | Confidence | Action |
|-------------|------------|--------|
| **95-100%** | EXACT | Auto-suggest with high confidence, show "99% match" |
| **85-94%** | HIGH | Show "Did you mean?" suggestion |
| **70-84%** | MEDIUM | Show suggestion with lower prominence |
| **50-69%** | LOW | Don't auto-suggest, but allow manual review |
| **<50%** | NONE | No match, proceed with new song creation |

### 4.2 Threshold Configuration

```dart
class MatchThresholds {
  // Primary thresholds
  static const double SUGGEST_MATCH = 85.0;    // Show "Did you mean?"
  static const double AUTO_SELECT = 98.0;      // Auto-select (with confirmation)
  static const double REQUIRE_REVIEW = 70.0;   // Minimum for showing in results
  
  // Component-specific thresholds
  static const double MIN_TITLE_SIMILARITY = 60.0;  // Title must be at least 60% similar
  static const double MIN_ARTIST_SIMILARITY = 50.0; // Artist must be at least 50% similar
  
  // Special cases
  static const double EXACT_MATCH = 99.5;      // Consider as duplicate
  static const double PHONETIC_BOOST = 5.0;    // Bonus for phonetic match
}
```

### 4.3 Decision Tree

```
User Input
    ↓
Normalize Input
    ↓
Search Existing Songs
    ↓
Calculate Match Scores
    ↓
┌─────────────────────────────────────────┐
│ Best Match Score?                        │
├─────────────────────────────────────────┤
│ >= 98%: Auto-suggest (with confirmation) │
│ 85-97%: Show "Did you mean?" dialog      │
│ 70-84%: Show in "Possible matches" list  │
│ < 70%: Create new song                   │
└─────────────────────────────────────────┘
```

---

## 5. Database Schema Changes

### 5.1 New Fields for Song Model

```dart
// lib/models/song.dart - Add these fields

class Song {
  // ... existing fields ...
  
  // EXTERNAL IDS (for cross-referencing with music databases)
  final String? spotifyId;        // Spotify track ID
  final String? musicbrainzId;    // MusicBrainz recording ID
  final String? isrc;             // International Standard Recording Code
  final String? deezerId;         // Deezer track ID
  final String? discogsId;        // Discogs release ID
  
  // MATCHING METADATA
  final String? normalizedTitle;  // Cached normalized title for faster search
  final String? normalizedArtist; // Cached normalized artist for faster search
  final String? titleSoundex;     // Soundex code for phonetic matching
  final String? artistSoundex;    // Soundex code for phonetic matching
  
  // DURATION (for matching)
  final int? durationMs;          // Track duration in milliseconds
  
  // ALBUM (for matching)
  final String? album;            // Album name
  
  // MATCH CONFIDENCE TRACKING
  final Map<String, dynamic>? matchHistory;  // Track match confirmations/rejections
  
  // SONG VARIANT INFORMATION
  final String? variantType;      // 'original', 'live', 'acoustic', 'remix', etc.
  final String? variantOf;        // ID of original song if this is a variant
  
  // CROWDSOURCED CORRECTIONS
  final List<Correction> corrections;  // User-submitted corrections
  
  // ... constructor, copyWith, toJson, fromJson updates ...
}

class Correction {
  final String userId;
  final DateTime timestamp;
  final String originalValue;
  final String correctedValue;
  final String field;  // 'title', 'artist', etc.
  final bool accepted;
  
  Correction({
    required this.userId,
    required this.timestamp,
    required this.originalValue,
    required this.correctedValue,
    required this.field,
    this.accepted = false,
  });
  
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'timestamp': timestamp.toIso8601String(),
    'originalValue': originalValue,
    'correctedValue': correctedValue,
    'field': field,
    'accepted': accepted,
  };
  
  factory Correction.fromJson(Map<String, dynamic> json) => Correction(
    userId: json['userId'],
    timestamp: DateTime.parse(json['timestamp']),
    originalValue: json['originalValue'],
    correctedValue: json['correctedValue'],
    field: json['field'],
    accepted: json['accepted'] ?? false,
  );
}
```

### 5.2 Firestore Indexes

```javascript
// firestore.indexes.json - Add these indexes

{
  "indexes": [
    // Normalized title/artist index for fuzzy search
    {
      "collectionGroup": "songs",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "normalizedTitle", "order": "ASCENDING" },
        { "fieldPath": "normalizedArtist", "order": "ASCENDING" }
      ]
    },
    // Soundex index for phonetic search
    {
      "collectionGroup": "songs",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "titleSoundex", "order": "ASCENDING" },
        { "fieldPath": "artistSoundex", "order": "ASCENDING" }
      ]
    },
    // External ID indexes
    {
      "collectionGroup": "songs",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "spotifyId", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "songs",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "isrc", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "songs",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "musicbrainzId", "order": "ASCENDING" }
      ]
    },
    // Band songs with normalized fields
    {
      "collectionGroup": "songs",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "bandId", "order": "ASCENDING" },
        { "fieldPath": "normalizedTitle", "order": "ASCENDING" }
      ]
    }
  ]
}
```

### 5.3 Migration Script

```dart
// scripts/migrate_songs_add_normalized_fields.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../lib/services/song_normalizer.dart';

Future<void> migrateSongs() async {
  final firestore = FirebaseFirestore.instance;
  
  // Get all users
  final usersSnapshot = await firestore.collection('users').get();
  
  for (final userDoc in usersSnapshot.docs) {
    final userId = userDoc.id;
    final songsSnapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('songs')
        .get();
    
    final batch = firestore.batch();
    
    for (final songDoc in songsSnapshot.docs) {
      final data = songDoc.data() as Map<String, dynamic>;
      final title = data['title'] ?? '';
      final artist = data['artist'] ?? '';
      
      batch.update(songDoc.reference, {
        'normalizedTitle': SongNormalizer.normalizeTitle(title),
        'normalizedArtist': SongNormalizer.normalizeArtist(artist),
        'titleSoundex': Soundex.encode(title),
        'artistSoundex': Soundex.encode(artist),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
    print('Migrated ${songsSnapshot.docs.length} songs for user $userId');
  }
  
  // Also migrate band songs
  final bandsSnapshot = await firestore.collection('bands').get();
  
  for (final bandDoc in bandsSnapshot.docs) {
    final bandId = bandDoc.id;
    final songsSnapshot = await firestore
        .collection('bands')
        .doc(bandId)
        .collection('songs')
        .get();
    
    final batch = firestore.batch();
    
    for (final songDoc in songsSnapshot.docs) {
      final data = songDoc.data() as Map<String, dynamic>;
      final title = data['title'] ?? '';
      final artist = data['artist'] ?? '';
      
      batch.update(songDoc.reference, {
        'normalizedTitle': SongNormalizer.normalizeTitle(title),
        'normalizedArtist': SongNormalizer.normalizeArtist(artist),
        'titleSoundex': Soundex.encode(title),
        'artistSoundex': Soundex.encode(artist),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
    print('Migrated ${songsSnapshot.docs.length} songs for band $bandId');
  }
}
```

---

## 6. UI Mockup Description

### 6.1 "Did You Mean?" Dialog

```
┌─────────────────────────────────────────────────────────────┐
│  ⚠️ Possible Match Found                                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  We found a similar song in your library:                   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  🎵 Bohemian Rhapsody                               │   │
│  │     Queen                                           │   │
│  │     Album: A Night at the Opera                     │   │
│  │     Duration: 5:55                                  │   │
│  │     Match Confidence: 94%                           │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Your input: "Bohemian Rapsody" by Queen                    │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Differences detected:                               │   │
│  │ • Title: "Rapsody" → "Rhapsody" (typo)              │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │  ✓ Use Existing  │  │  ✗ Create New    │                │
│  └──────────────────┘  └──────────────────┘                │
│                                                             │
│  [ ] Don't ask again for this song                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 6.2 Multiple Matches List

```
┌─────────────────────────────────────────────────────────────┐
│  🔍 Search Results                                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Your search: "Hey Jude" by Beatles                         │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  98%  Hey Jude - The Beatles                        │   │
│  │       Album: Hey Jude (Single)                      │   │
│  │       Duration: 7:11                                │   │
│  │       [Select]                                      │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  87%  Hey Jude - The Beatles                        │   │
│  │       Album: 1 (Remastered)                         │   │
│  │       Duration: 7:08                                │   │
│  │       [Select]                                      │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  72%  Hey Jude (Live) - The Beatles                 │   │
│  │       Album: Live at Wembley                        │   │
│  │       Duration: 7:45                                │   │
│  │       [Select]                                      │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌──────────────────┐                                       │
│  │  + Create New    │                                       │
│  └──────────────────┘                                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 6.3 Inline Suggestion (Search Bar)

```
┌─────────────────────────────────────────────────────────────┐
│  Search songs...                                            │
│  └─ Bohemian Rapsody ───────────────────────────────────┘  │
│     └─ Did you mean "Bohemian Rhapsody"? [Use] [Dismiss] ─┘│
└─────────────────────────────────────────────────────────────┘
```

### 6.4 Flutter Widget Implementation

```dart
// lib/widgets/song_match_dialog.dart

class SongMatchDialog extends StatelessWidget {
  final MatchScore matchScore;
  final String userInput;
  
  const SongMatchDialog({
    super.key,
    required this.matchScore,
    required this.userInput,
  });
  
  @override
  Widget build(BuildContext context) {
    final song = matchScore.matchedSong;
    final confidence = matchScore.total;
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            confidence >= 90 ? Icons.check_circle : Icons.info_outline,
            color: confidence >= 90 ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              confidence >= 90 
                ? 'Exact Match Found' 
                : 'Possible Match Found',
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Matched song card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  song.artist,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (song.album != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.album, size: 16),
                      const SizedBox(width: 4),
                      Text(song.album!),
                    ],
                  ),
                ],
                if (song.durationMs != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.timer, size: 16),
                      const SizedBox(width: 4),
                      Text(_formatDuration(song.durationMs!)),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(confidence).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${confidence.toStringAsFixed(0)}% Match',
                    style: TextStyle(
                      color: _getConfidenceColor(confidence),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // User input comparison
          Text(
            'Your input: "$userInput"',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey,
            ),
          ),
          // Differences
          if (confidence < 98) ...[
            const SizedBox(height: 12),
            Text(
              'Differences detected:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            ..._buildDifferencesList(matchScore),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Create New'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confidence >= 98 ? 'Use Match' : 'Use Existing'),
        ),
      ],
    );
  }
  
  Color _getConfidenceColor(double confidence) {
    if (confidence >= 95) return Colors.green;
    if (confidence >= 85) return Colors.lightGreen;
    if (confidence >= 70) return Colors.orange;
    return Colors.red;
  }
  
  String _formatDuration(int ms) {
    final minutes = ms ~/ 60000;
    final seconds = ((ms % 60000) / 1000).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  
  List<Widget> _buildDifferencesList(MatchScore score) {
    final differences = <Widget>[];
    
    if (score.titleSimilarity < 95) {
      differences.add(
        Row(
          children: [
            const Icon(Icons.edit, size: 14),
            const SizedBox(width: 4),
            Text(
              'Title spelling variation',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }
    
    if (score.artistSimilarity < 90) {
      differences.add(
        Row(
          children: [
            const Icon(Icons.person, size: 14),
            const SizedBox(width: 4),
            Text(
              'Artist name variation',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }
    
    return differences;
  }
}
```

---

## 7. Performance Considerations

### 7.1 Query Optimization

#### Problem
Firestore doesn't support full-text search or fuzzy matching natively.

#### Solution: Multi-Tier Search Strategy

```dart
class SongSearchService {
  final FirebaseFirestore _firestore;
  
  // Tier 1: Exact match on normalized fields (fastest)
  Future<List<Song>> searchExact(String title, String artist) async {
    final normTitle = SongNormalizer.normalizeTitle(title);
    final normArtist = SongNormalizer.normalizeArtist(artist);
    
    final snapshot = await _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('songs')
        .where('normalizedTitle', isEqualTo: normTitle)
        .where('normalizedArtist', isEqualTo: normArtist)
        .get();
    
    return snapshot.docs.map((d) => Song.fromJson(d.data())).toList();
  }
  
  // Tier 2: Prefix match (fast)
  Future<List<Song>> searchPrefix(String title, String artist) async {
    final normTitle = SongNormalizer.normalizeTitle(title);
    final normArtist = SongNormalizer.normalizeArtist(artist);
    
    // Use range query for prefix matching
    final snapshot = await _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('songs')
        .where('normalizedTitle', isGreaterThanOrEqualTo: normTitle)
        .where('normalizedTitle', isLessThan: '$normTitle\uf8ff')
        .get();
    
    // Filter by artist prefix in-memory
    return snapshot.docs
        .map((d) => Song.fromJson(d.data()))
        .where((s) => SongNormalizer
            .normalizeArtist(s.artist)
            .startsWith(normArtist))
        .toList();
  }
  
  // Tier 3: Phonetic match (medium)
  Future<List<Song>> searchPhonetic(String title, String artist) async {
    final titleSoundex = Soundex.encode(title);
    final artistSoundex = Soundex.encode(artist);
    
    final snapshot = await _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('songs')
        .where('titleSoundex', isEqualTo: titleSoundex)
        .where('artistSoundex', isEqualTo: artistSoundex)
        .get();
    
    return snapshot.docs.map((d) => Song.fromJson(d.data())).toList();
  }
  
  // Tier 4: Full fuzzy search (slowest, in-memory)
  Future<List<MatchScore>> searchFuzzy(String title, String artist) async {
    // Get all songs (or use pagination for large collections)
    final allSongs = await _getAllSongs();
    
    // Calculate match scores in-memory
    final scores = <MatchScore>[];
    for (final song in allSongs) {
      final score = MatchScorer.calculate(
        inputTitle: title,
        inputArtist: artist,
        existingSong: song,
      );
      if (score.total >= MatchThresholds.REQUIRE_REVIEW) {
        scores.add(score);
      }
    }
    
    // Sort by score descending
    scores.sort((a, b) => b.total.compareTo(a.total));
    
    return scores;
  }
  
  // Combined search with fallback
  Future<List<MatchScore>> search(String title, String artist) async {
    // Try exact match first
    var results = await searchExact(title, artist);
    if (results.isNotEmpty) {
      return results.map((s) => MatchScore(
        total: 100,
        titleSimilarity: 100,
        artistSimilarity: 100,
        durationSimilarity: 100,
        albumSimilarity: 100,
        matchedSong: s,
      )).toList();
    }
    
    // Try prefix match
    results = await searchPrefix(title, artist);
    if (results.isNotEmpty) {
      return results.map((s) => MatchScorer.calculate(
        inputTitle: title,
        inputArtist: artist,
        existingSong: s,
      )).toList();
    }
    
    // Try phonetic match
    results = await searchPhonetic(title, artist);
    if (results.isNotEmpty) {
      return results.map((s) => MatchScorer.calculate(
        inputTitle: title,
        inputArtist: artist,
        existingSong: s,
      )).toList();
    }
    
    // Fall back to full fuzzy search
    return searchFuzzy(title, artist);
  }
}
```

### 7.2 Caching Strategy

```dart
class SongSearchCache {
  final Map<String, _CacheEntry> _cache = {};
  final Duration _ttl = const Duration(minutes: 5);
  
  Future<List<MatchScore>> getOrFetch(
    String query,
    Future<List<MatchScore>> Function() fetcher,
  ) async {
    final entry = _cache[query];
    
    if (entry != null && !entry.isExpired) {
      return entry.scores;
    }
    
    final scores = await fetcher();
    _cache[query] = _CacheEntry(scores: scores, timestamp: DateTime.now());
    
    // Cleanup old entries
    _cache.removeWhere((_, e) => e.isExpired);
    
    return scores;
  }
}

class _CacheEntry {
  final List<MatchScore> scores;
  final DateTime timestamp;
  
  _CacheEntry({required this.scores, required this.timestamp});
  
  bool get isExpired => 
      DateTime.now().difference(timestamp) > const Duration(minutes: 5);
}
```

### 7.3 Debouncing User Input

```dart
class SearchDebouncer {
  Timer? _timer;
  final Duration _delay;
  
  SearchDebouncer({Duration? delay}) : _delay = delay ?? const Duration(milliseconds: 300);
  
  void run(VoidCallback callback) {
    _timer?.cancel();
    _timer = Timer(_delay, callback);
  }
  
  void dispose() => _timer?.cancel();
}

// Usage in search widget
final _debouncer = SearchDebouncer();
final _searchController = TextEditingController();

_searchController.addListener(() {
  _debouncer.run(() {
    _performSearch(_searchController.text);
  });
});
```

### 7.4 Pagination for Large Collections

```dart
class PaginatedSongSearch {
  static const int _pageSize = 50;
  
  Future<PaginatedResult<MatchScore>> searchPage({
    required String title,
    required String artist,
    DocumentSnapshot? startAfter,
  }) async {
    var query = _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('songs')
        .orderBy('normalizedTitle')
        .limit(_pageSize);
    
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    
    final snapshot = await query.get();
    
    final scores = <MatchScore>[];
    for (final doc in snapshot.docs) {
      final song = Song.fromJson(doc.data());
      final score = MatchScorer.calculate(
        inputTitle: title,
        inputArtist: artist,
        existingSong: song,
      );
      if (score.total >= MatchThresholds.REQUIRE_REVIEW) {
        scores.add(score);
      }
    }
    
    return PaginatedResult(
      items: scores,
      hasMore: snapshot.docs.length == _pageSize,
      lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
    );
  }
}
```

---

## 8. Edge Cases Handling

### 8.1 Multiple Matches Scenario

**Problem:** User searches for "Hey Jude" and multiple versions exist.

**Solution:** Ranked list with disambiguation

```dart
class MultipleMatchHandler {
  static Widget buildMatchList(List<MatchScore> scores) {
    // Group by title similarity
    final highConfidence = scores.where((s) => s.total >= 85).toList();
    final mediumConfidence = scores.where((s) => 
        s.total >= 70 && s.total < 85).toList();
    
    if (highConfidence.length > 1) {
      // Multiple high-confidence matches - show all with distinguishing info
      return _buildDisambiguationList(highConfidence);
    }
    
    if (highConfidence.isNotEmpty) {
      // Single clear winner
      return _buildSingleSuggestion(highConfidence.first);
    }
    
    if (mediumConfidence.isNotEmpty) {
      // Show as "possible matches"
      return _buildPossibleMatchesList(mediumConfidence);
    }
    
    // No good matches
    return _buildNoMatchResult();
  }
  
  static Widget _buildDisambiguationList(List<MatchScore> scores) {
    // Sort by: duration match, then album match, then recency
    scores.sort((a, b) {
      if (a.durationSimilarity != b.durationSimilarity) {
        return b.durationSimilarity.compareTo(a.durationSimilarity);
      }
      if (a.albumSimilarity != b.albumSimilarity) {
        return b.albumSimilarity.compareTo(a.albumSimilarity);
      }
      return b.matchedSong.updatedAt.compareTo(a.matchedSong.updatedAt);
    });
    
    return ListView.builder(
      itemCount: scores.length,
      itemBuilder: (context, index) {
        final score = scores[index];
        return _buildSongTile(score, showRank: true);
      },
    );
  }
}
```

### 8.2 Edge Case Matrix

| Scenario | Detection | Handling |
|----------|-----------|----------|
| **Exact duplicate** | Score >= 99% | Auto-detect, show confirmation |
| **Same song, different version** | High title, low album | Group as variants |
| **Cover song** | Same title, different artist | Show both, label as "cover" |
| **Live version** | Title match + "live" in existing | Suggest original + note "live version exists" |
| **Remaster** | Title match + "remaster" suffix | Link to original |
| **Different song, same title** | Title match, low artist match | Show both with artist distinction |
| **Typos in both** | Phonetic match | Show with "similar sounding" label |
| **Empty artist** | Artist field blank | Weight title higher (60/40 split) |
| **Instrumental (no artist)** | Artist = "Various" or empty | Title-only matching |

### 8.3 Special Handling Code

```dart
class EdgeCaseHandler {
  static MatchScore applySpecialRules(MatchScore score, String inputArtist) {
    double adjustedScore = score.total;
    
    // Case 1: Empty artist input
    if (inputArtist.trim().isEmpty) {
      // Weight title higher
      adjustedScore = (
        score.titleSimilarity * 0.70 +
        score.durationSimilarity * 0.15 +
        score.albumSimilarity * 0.15
      );
    }
    
    // Case 2: Live version detection
    if (_isLiveVersion(score.matchedSong)) {
      final inputNorm = SongNormalizer.normalizeTitle(inputArtist);
      if (!inputNorm.contains('live')) {
        // User didn't search for live version - reduce score
        adjustedScore *= 0.85;
      }
    }
    
    // Case 3: Cover song detection
    if (_isPotentialCover(score, inputArtist)) {
      // Don't auto-suggest covers as duplicates
      adjustedScore = min(adjustedScore, 69);
    }
    
    // Case 4: Phonetic match bonus
    if (Soundex.isSimilar(
          SongNormalizer.normalizeTitle(inputArtist),
          SongNormalizer.normalizeTitle(score.matchedSong.title),
        )) {
      adjustedScore += MatchThresholds.PHONETIC_BOOST;
    }
    
    return MatchScore(
      total: min(100, adjustedScore),
      titleSimilarity: score.titleSimilarity,
      artistSimilarity: score.artistSimilarity,
      durationSimilarity: score.durationSimilarity,
      albumSimilarity: score.albumSimilarity,
      matchedSong: score.matchedSong,
    );
  }
  
  static bool _isLiveVersion(Song song) {
    final normTitle = SongNormalizer.normalizeTitle(song.title);
    return normTitle.contains('live') || 
           song.variantType == 'live';
  }
  
  static bool _isPotentialCover(MatchScore score, String inputArtist) {
    final normInputArtist = SongNormalizer.normalizeArtist(inputArtist);
    final normExistingArtist = SongNormalizer.normalizeArtist(score.matchedSong.artist);
    
    // Same title but different artist = potential cover
    return score.titleSimilarity > 90 && 
           score.artistSimilarity < 50 &&
           normInputArtist.isNotEmpty &&
           normExistingArtist.isNotEmpty;
  }
}
```

### 8.4 User Feedback Loop

```dart
class MatchFeedbackService {
  final FirebaseFirestore _firestore;
  
  // Record user's match decision
  Future<void> recordMatchDecision({
    required String inputTitle,
    required String inputArtist,
    required String matchedSongId,
    required bool accepted,
    required double confidence,
  }) async {
    await _firestore.collection('match_feedback').add({
      'userId': _currentUserId,
      'timestamp': FieldValue.serverTimestamp(),
      'inputTitle': inputTitle,
      'inputArtist': inputArtist,
      'matchedSongId': matchedSongId,
      'accepted': accepted,
      'confidence': confidence,
    });
    
    // If rejected, store for later analysis
    if (!accepted) {
      await _firestore.collection('match_rejections').add({
        'userId': _currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'inputTitle': inputTitle,
        'inputArtist': inputArtist,
        'matchedSongId': matchedSongId,
        'suggestedScore': confidence,
      });
    }
  }
  
  // Analyze rejections to improve algorithm
  Future<void> analyzeRejections() async {
    final rejections = await _firestore
        .collection('match_rejections')
        .where('timestamp', isGreaterThan: DateTime.now().subtract(const Duration(days: 30)))
        .get();
    
    // Group by score range to find threshold issues
    final scoreBuckets = <String, int>{};
    for (final doc in rejections.docs) {
      final score = doc.data()['suggestedScore'] as double;
      final bucket = score >= 90 ? '90+' : 
                     score >= 80 ? '80-89' : 
                     score >= 70 ? '70-79' : '<70';
      scoreBuckets[bucket] = (scoreBuckets[bucket] ?? 0) + 1;
    }
    
    // If many rejections in 90+ bucket, consider raising threshold
    if ((scoreBuckets['90+'] ?? 0) > 10) {
      debugPrint('⚠️ High rejection rate for high-confidence matches');
      debugPrint('Consider raising SUGGEST_MATCH threshold');
    }
  }
}
```

---

## 9. Pseudocode Summary

### 9.1 Main Matching Algorithm

```
ALGORITHM FindMatchingSong(inputTitle, inputArtist, existingSongs)
    // Step 1: Normalize input
    normTitle ← NormalizeTitle(inputTitle)
    normArtist ← NormalizeArtist(inputArtist)
    
    // Step 2: Quick exact match check
    FOR each song IN existingSongs DO
        IF song.normalizedTitle = normTitle AND 
           song.normalizedArtist = normArtist THEN
            RETURN Match(score: 100, song: song)
        END IF
    END FOR
    
    // Step 3: Phonetic pre-filter
    inputTitleSoundex ← Soundex(normTitle)
    inputArtistSoundex ← Soundex(normArtist)
    
    candidates ← []
    FOR each song IN existingSongs DO
        IF song.titleSoundex = inputTitleSoundex OR
           song.artistSoundex = inputArtistSoundex THEN
            candidates.ADD(song)
        END IF
    END FOR
    
    // If no phonetic matches, use all songs (slower)
    IF candidates IS EMPTY THEN
        candidates ← existingSongs
    END IF
    
    // Step 4: Calculate match scores
    matchScores ← []
    FOR each song IN candidates DO
        score ← CalculateMatchScore(
            inputTitle, inputArtist,
            song
        )
        
        // Apply edge case adjustments
        score ← ApplySpecialRules(score, inputArtist)
        
        IF score.total ≥ 70 THEN
            matchScores.ADD(score)
        END IF
    END FOR
    
    // Step 5: Sort by score
    SORT matchScores BY score.total DESCENDING
    
    // Step 6: Return results
    IF matchScores IS NOT EMPTY THEN
        RETURN matchScores[0]  // Best match
    ELSE
        RETURN NULL  // No match found
    END IF
END ALGORITHM
```

### 9.2 User Flow

```
PROCEDURE HandleSongCreation(inputTitle, inputArtist)
    // Step 1: Search for matches
    matches ← FindMatchingSong(inputTitle, inputArtist, allSongs)
    
    // Step 2: Decision based on confidence
    IF matches IS NULL THEN
        // No match - create new song
        CREATE NewSong(inputTitle, inputArtist)
        RETURN
    END IF
    
    bestMatch ← matches[0]
    
    IF bestMatch.score ≥ 98 THEN
        // Near-exact match - auto-suggest
        SHOW MatchConfirmationDialog(bestMatch)
        IF user CONFIRMS THEN
            USE existing song
        ELSE
            CREATE NewSong(inputTitle, inputArtist)
        END IF
        
    ELSE IF bestMatch.score ≥ 85 THEN
        // High confidence - show suggestion
        SHOW DidYouMeanDialog(bestMatch)
        IF user ACCEPTS THEN
            USE existing song
        ELSE
            CREATE NewSong(inputTitle, inputArtist)
        END IF
        
    ELSE IF bestMatch.score ≥ 70 THEN
        // Medium confidence - show in results
        SHOW PossibleMatchesList(matches)
        IF user SELECTS match THEN
            USE selected song
        ELSE
            CREATE NewSong(inputTitle, inputArtist)
        END IF
        
    ELSE
        // Low confidence - create new
        CREATE NewSong(inputTitle, inputArtist)
    END IF
END PROCEDURE
```

---

## 10. Implementation Checklist

### Phase 1: Core Infrastructure
- [ ] Create `SongNormalizer` class with all normalization steps
- [ ] Implement `Levenshtein` distance algorithm
- [ ] Implement `JaroWinkler` distance algorithm
- [ ] Implement `TokenSortRatio` algorithm
- [ ] Implement `Soundex` phonetic encoding
- [ ] Create `MatchScorer` class with weighted scoring
- [ ] Define `MatchThresholds` constants

### Phase 2: Database Changes
- [ ] Add new fields to `Song` model
- [ ] Create Firestore migration script
- [ ] Add new indexes to `firestore.indexes.json`
- [ ] Update `toJson`/`fromJson` methods
- [ ] Test migration on staging data

### Phase 3: Search Service
- [ ] Create `SongSearchService` with tiered search
- [ ] Implement caching layer
- [ ] Add debouncing for user input
- [ ] Implement pagination for large collections
- [ ] Write unit tests for search algorithms

### Phase 4: UI Components
- [ ] Create `SongMatchDialog` widget
- [ ] Create `MultipleMatchList` widget
- [ ] Add inline suggestion to search bar
- [ ] Implement match confirmation flow
- [ ] Add visual confidence indicators
- [ ] Test on mobile and tablet layouts

### Phase 5: Integration
- [ ] Integrate with `AddSongScreen`
- [ ] Integrate with song search functionality
- [ ] Add feedback collection mechanism
- [ ] Implement rejection tracking
- [ ] End-to-end testing

### Phase 6: Optimization
- [ ] Performance profiling
- [ ] Cache hit rate analysis
- [ ] Threshold tuning based on user feedback
- [ ] Algorithm parameter optimization
- [ ] Documentation updates

---

## 11. Testing Strategy

### 11.1 Unit Tests

```dart
// test/services/song_matcher_test.dart

void main() {
  group('SongNormalizer', () {
    test('removes special characters', () {
      expect(
        SongNormalizer.normalizeTitle("It's Alright!"),
        equals('its alright'),
      );
    });
    
    test('removes The prefix', () {
      expect(
        SongNormalizer.normalizeArtist('The Beatles'),
        equals('beatles'),
      );
    });
    
    test('handles typos', () {
      expect(
        SongNormalizer.normalizeTitle('Bohemian Rapsody'),
        equals('bohemian rapsody'),
      );
    });
    
    test('removes live versions', () {
      expect(
        SongNormalizer.normalizeTitle('Song (Live at Wembley)'),
        equals('song'),
      );
    });
  });
  
  group('Levenshtein', () {
    test('calculates distance correctly', () {
      expect(Levenshtein.distance('kitten', 'sitting'), equals(3));
    });
    
    test('handles typos', () {
      expect(
        Levenshtein.similarity('rhapsody', 'rapsody'),
        closeTo(0.94, 0.01),
      );
    });
  });
  
  group('MatchScorer', () {
    test('high score for exact match', () {
      final score = MatchScorer.calculate(
        inputTitle: 'Bohemian Rhapsody',
        inputArtist: 'Queen',
        existingSong: Song(
          title: 'Bohemian Rhapsody',
          artist: 'Queen',
          // ... other fields
        ),
      );
      
      expect(score.total, greaterThan(95));
    });
    
    test('medium score for typo', () {
      final score = MatchScorer.calculate(
        inputTitle: 'Bohemian Rapsody',
        inputArtist: 'Queen',
        existingSong: Song(
          title: 'Bohemian Rhapsody',
          artist: 'Queen',
          // ... other fields
        ),
      );
      
      expect(score.total, inRange(85, 95));
    });
  });
}
```

### 11.2 Integration Tests

```dart
// test/integration/song_matching_test.dart

void main() {
  testWidgets('Shows match suggestion for typo', (tester) async {
    // Setup: Add existing song
    await testData.addSong('Bohemian Rhapsody', 'Queen');
    
    // Navigate to add song screen
    await tester.pumpWidget(createTestApp());
    await tester.tap(find.text('Add Song'));
    await tester.pumpAndSettle();
    
    // Type typo
    await tester.enterText(
      find.byKey(Key('title_field')),
      'Bohemian Rapsody',
    );
    await tester.enterText(
      find.byKey(Key('artist_field')),
      'Queen',
    );
    await tester.pumpAndSettle();
    
    // Verify suggestion appears
    expect(find.text('Possible Match Found'), findsOneWidget);
    expect(find.text('Bohemian Rhapsody'), findsOneWidget);
  });
}
```

---

## 12. Appendix

### A. Normalization Examples

| Input | Normalized |
|-------|------------|
| "The Beatles" | "beatles" |
| "Bohemian Rhapsody" | "bohemian rhapsody" |
| "Bohemian Rapsody" | "bohemian rapsody" |
| "Song (Live)" | "song" |
| "Song - Remastered 2011" | "song" |
| "Song feat. John" | "song" |
| "Song (Acoustic Version)" | "song" |
| "Hey Jude (Remaster)" | "hey jude" |

### B. Match Score Examples

| Input | Existing | Score | Action |
|-------|----------|-------|--------|
| "Bohemian Rhapsody" - Queen | "Bohemian Rhapsody" - Queen | 100% | Auto-confirm |
| "Bohemian Rapsody" - Queen | "Bohemian Rhapsody" - Queen | 94% | Suggest |
| "Hey Jude" - Beatles | "Hey Jude" - The Beatles | 96% | Suggest |
| "Hotel California" - Eagles | "Hotel California" - Eagles (Live) | 82% | Show in list |
| "Yesterday" - Various | "Yesterday" - The Beatles | 65% | Create new |

### C. API Reference

```dart
// Public API for song matching

/// Find matching songs for the given input
Future<List<MatchScore>> findMatchingSongs({
  required String title,
  required String artist,
  String? bandId,  // Optional: search within band
});

/// Show match confirmation dialog
Future<bool> showMatchDialog({
  required BuildContext context,
  required MatchScore match,
  required String userInput,
});

/// Record user feedback on match suggestion
Future<void> recordMatchFeedback({
  required bool accepted,
  required MatchScore match,
  required String userInput,
});
```

---

**End of Document**
