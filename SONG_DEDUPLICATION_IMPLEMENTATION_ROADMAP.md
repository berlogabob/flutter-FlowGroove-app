# Song Deduplication Implementation Roadmap

**Document Version:** 1.0
**Date:** February 28, 2026
**Author:** RepSync Development Team
**Status:** Ready for Implementation

---

## Executive Summary

This roadmap outlines a phased implementation plan for song deduplication in RepSync, combining research findings from architecture analysis, API testing, audio fingerprinting research, and community database design. The plan prioritizes quick wins while building toward advanced audio recognition capabilities.

### Research Sources
- **@mr-architect**: Deduplication strategies + Music API research
- **@mr-senior-developer**: API testing results (8 APIs tested)
- **@mr-android-debug**: Audio fingerprinting research (Chromaprint, ACRCloud, Audd.io)
- **@mr-planner**: Community database design (reputation system, merge workflows)

---

## Phase Overview

| Phase | Name | Duration | Effort | Cost | Priority |
|-------|------|----------|--------|------|----------|
| **Phase 1** | Quick Wins | 1-2 weeks | 13 SP | $0 | CRITICAL |
| **Phase 2** | API Enrichment | 2-3 weeks | 21 SP | $0 | HIGH |
| **Phase 3** | Community Features | 3-4 weeks | 26 SP | $0 | HIGH |
| **Phase 4** | Audio Recognition | 4-6 weeks | 40 SP | $50-200/mo | MEDIUM |
| **Phase 5** | Advanced Features | Ongoing | Variable | $0-100/mo | LOW |

---

## Phase 1: Quick Wins (1-2 Weeks)

**Goal:** Immediate deduplication with no external dependencies

### Business Case
- **Problem:** Users create duplicate songs due to typos and formatting variations
- **Impact:** Fragmented setlists, inaccurate practice tracking
- **Solution:** String normalization + fuzzy matching catches obvious duplicates

### Tasks

| # | Task | Agent | Effort (SP) | Dependencies | Status |
|---|------|-------|-------------|--------------|--------|
| 1.1 | Implement string normalization pipeline | @mr-coder | 3 | - | pending |
| 1.2 | Add normalized fields to Song model | @mr-coder | 2 | 1.1 | pending |
| 1.3 | Implement Levenshtein distance algorithm | @mr-coder | 3 | - | pending |
| 1.4 | Implement Jaro-Winkler algorithm | @mr-coder | 3 | - | pending |
| 1.5 | Implement Token Sort Ratio | @mr-coder | 2 | 1.3 | pending |
| 1.6 | Implement Soundex phonetic matching | @mr-coder | 2 | - | pending |
| 1.7 | Create multi-factor scoring system | @mr-coder | 3 | 1.3-1.6 | pending |
| 1.8 | Build "Did you mean?" suggestion dialog | @mr-ux-agent | 5 | 1.7 | pending |
| 1.9 | Create Firestore indexes for matching | @mr-coder | 2 | - | pending |
| 1.10 | Write unit tests for matching algorithms | @mr-tester | 4 | 1.3-1.7 | pending |
| 1.11 | Integration testing + QA | @mr-tester | 3 | 1.8-1.10 | pending |

**Total Effort:** 32 story points (adjusted for parallel work: 13 SP)

### Technical Specification

#### 1.1 String Normalization Pipeline
**File:** `/lib/services/song_normalizer.dart`

```dart
class SongNormalizer {
  static String normalize(String input) {
    if (input.isEmpty) return '';
    
    return input
      // Step 1: Unicode normalization (NFKC)
      .normalize(NormalizationForm.nfkc)
      // Step 2: Lowercase
      .toLowerCase()
      // Step 3: Remove special characters
      .replaceAll(RegExp(r'[^\w\s\-]'), ' ')
      // Step 4: Whitespace normalization
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      // Step 5: Remove "The" prefix
      .replaceFirst(RegExp(r'^the\s+'), '')
      // Step 6: Remove features
      .replaceAll(RegExp(r'\s+feat\.?\s+.*$'), '')
      .replaceAll(RegExp(r'\s+ft\.?\s+.*$'), '')
      // Step 7: Remove version suffixes
      .replaceAll(RegExp(r'\s*-\s*remastered\s*(\d{4})?\s*$'), '')
      .replaceAll(RegExp(r'\s*-\s*remix\s*$'), '')
      // Step 8: Remove parenthetical content
      .replaceAll(RegExp(r'\s*\(live\)?'), '')
      .replaceAll(RegExp(r'\s*\(acoustic\)?'), '')
      .replaceAll(RegExp(r'\s*\(remix\)'), '')
      .replaceAll(RegExp(r'\s*\(remastered\)'), '')
      // Final cleanup
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  }
}
```

#### 1.2 Song Model Updates
**File:** `/lib/models/song.dart`

```dart
class Song {
  // Add these fields:
  final String? normalizedTitle;
  final String? normalizedArtist;
  final String? titleSoundex;
  final String? artistSoundex;
  final int? durationMs;
  final String? album;
  final String? spotifyId;
  final String? musicbrainzId;
  final String? isrc;
}
```

#### 1.3 Match Scoring System
**File:** `/lib/services/song_matcher.dart`

```dart
class MatchScorer {
  static MatchScore calculate(Song input, Song existing) {
    // Title similarity (weighted average)
    final titleScore = (
      Levenshtein.similarity(input.normalizedTitle, existing.normalizedTitle) * 0.35 +
      JaroWinkler.similarity(input.normalizedTitle, existing.normalizedTitle) * 0.35 +
      TokenSortRatio.similarity(input.normalizedTitle, existing.normalizedTitle) * 0.20 +
      (Soundex.isSimilar(input.normalizedTitle, existing.normalizedTitle) ? 0.10 : 0.0)
    );
    
    // Artist similarity
    final artistScore = (
      Levenshtein.similarity(input.normalizedArtist, existing.normalizedArtist) * 0.40 +
      JaroWinkler.similarity(input.normalizedArtist, existing.normalizedArtist) * 0.40 +
      TokenSortRatio.similarity(input.normalizedArtist, existing.normalizedArtist) * 0.20
    );
    
    // Duration similarity (if available)
    final durationScore = input.durationMs != null && existing.durationMs != null
      ? max(0, 1.0 - ((input.durationMs! - existing.durationMs!).abs() / 10000))
      : 0.0;
    
    // Final score
    final totalScore = (
      titleScore * 0.40 +
      artistScore * 0.40 +
      durationScore * 0.10 +
      0.10  // Album similarity (optional)
    ) * 100;
    
    return MatchScore(total: totalScore, matchedSong: existing);
  }
}
```

### Success Metrics

| Metric | Baseline | Target | Measurement |
|--------|----------|--------|-------------|
| Duplicate detection rate | 0% | 70% | % of duplicates caught on creation |
| False positive rate | N/A | <5% | % of incorrect match suggestions |
| Match calculation time | N/A | <100ms | Average time to score all candidates |
| User acceptance rate | N/A | >80% | % of suggestions accepted by users |

### Go/No-Go Criteria

**Proceed to Phase 2 if:**
- [ ] Duplicate detection rate >= 60%
- [ ] False positive rate < 10%
- [ ] No critical bugs in production
- [ ] User feedback is neutral or positive

**Stop and iterate if:**
- False positive rate > 15% (causes user frustration)
- Performance issues (>500ms per match calculation)
- Critical bugs in song creation flow

### Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| False positives annoy users | Medium | High | Set conservative thresholds (85%+), allow user override |
| Performance degradation | Low | Medium | Cache normalized values, index Firestore fields |
| Edge cases not handled | High | Low | Log mismatches, iterate based on user reports |
| Unicode normalization issues | Low | Low | Comprehensive test suite with international characters |

---

## Phase 2: API Enrichment (2-3 Weeks)

**Goal:** Auto-fill metadata and reduce manual entry errors

### Business Case
- **Problem:** Manual data entry leads to inconsistent metadata and duplicates
- **Impact:** Poor search experience, incorrect BPM/key for practice
- **Solution:** Integrate free music APIs to auto-fill song metadata

### Tasks

| # | Task | Agent | Effort (SP) | Dependencies | Status |
|---|------|-------|-------------|--------------|--------|
| 2.1 | Set up Deezer API integration (primary search) | @mr-coder | 5 | - | pending |
| 2.2 | Set up MusicBrainz API integration (fallback) | @mr-coder | 5 | - | pending |
| 2.3 | Implement Spotify OAuth 2.0 (Client Credentials) | @mr-coder | 8 | - | pending |
| 2.4 | Create API search service with fallback chain | @mr-coder | 5 | 2.1-2.3 | pending |
| 2.5 | Build song search UI with API results | @mr-ux-agent | 5 | 2.4 | pending |
| 2.6 | Auto-fill BPM/key from Spotify Audio Features | @mr-coder | 3 | 2.3 | pending |
| 2.7 | Store external IDs (Spotify, MusicBrainz, ISRC) | @mr-coder | 3 | 2.1-2.3 | pending |
| 2.8 | Implement API response caching (24h) | @mr-coder | 3 | 2.4 | pending |
| 2.9 | Handle rate limiting (MusicBrainz 1 req/sec) | @mr-coder | 2 | 2.2 | pending |
| 2.10 | Add API key management (flutter_dotenv) | @mr-coder | 2 | - | pending |
| 2.11 | Write integration tests for API calls | @mr-tester | 5 | 2.1-2.9 | pending |
| 2.12 | Error handling + offline fallback | @mr-coder | 4 | 2.4 | pending |

**Total Effort:** 50 story points (adjusted for parallel work: 21 SP)

### Technical Specification

#### 2.1 API Integration Architecture
**File:** `/lib/services/music_api_service.dart`

```dart
class MusicApiService {
  final DeezerApi _deezerApi;
  final MusicBrainzApi _musicBrainzApi;
  final SpotifyApi _spotifyApi;
  final ApiCache _cache;

  // Search with fallback chain
  Future<ApiSearchResult> search(String query) async {
    // Try cache first
    final cached = await _cache.get(query);
    if (cached != null) return cached;

    // Primary: Deezer (fastest, no auth)
    try {
      final result = await _deezerApi.search(query);
      if (result.tracks.isNotEmpty) {
        await _cache.set(query, result);
        return result;
      }
    } catch (e) {
      // Fall through to next API
    }

    // Fallback: MusicBrainz (rich metadata, rate limited)
    try {
      final result = await _musicBrainzApi.search(query);
      if (result.tracks.isNotEmpty) {
        await _cache.set(query, result);
        return result;
      }
    } catch (e) {
      // Fall through to next API
    }

    return ApiSearchResult.empty();
  }

  // Get audio features (BPM, key)
  Future<AudioFeatures?> getAudioFeatures(String spotifyId) async {
    try {
      return await _spotifyApi.getAudioFeatures(spotifyId);
    } catch (e) {
      return null;
    }
  }
}
```

#### 2.2 Spotify OAuth Implementation
**File:** `/lib/services/spotify_auth_service.dart`

```dart
class SpotifyAuthService {
  final String _clientId;
  final String _clientSecret;
  final FlutterSecureStorage _storage;

  Future<String> getClientCredentialsToken() async {
    // Check cached token
    final cached = await _storage.read(key: 'spotify_token');
    final expires = await _storage.read(key: 'spotify_token_expires');
    
    if (cached != null && expires != null) {
      final expiry = DateTime.parse(expires);
      if (DateTime.now().isBefore(expiry)) {
        return cached;
      }
    }

    // Request new token
    final response = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Basic ${base64Encode(utf8.encode('$_clientId:$_clientSecret'))}',
      },
      body: {'grant_type': 'client_credentials'},
    );

    final data = jsonDecode(response.body);
    final token = data['access_token'];
    final expiresIn = data['expires_in'];

    // Cache token
    await _storage.write(key: 'spotify_token', value: token);
    await _storage.write(
      key: 'spotify_token_expires',
      value: DateTime.now().add(Duration(seconds: expiresIn - 300)).toIso8601String(),
    );

    return token;
  }
}
```

#### 2.3 API Response Caching
**File:** `/lib/services/api_cache.dart`

```dart
class ApiCache {
  final Hive.Box _box;
  static const Duration cacheDuration = Duration(hours: 24);

  Future<ApiSearchResult?> get(String query) async {
    final normalized = query.toLowerCase().trim();
    final cached = await _box.get(normalized);
    
    if (cached != null) {
      final timestamp = DateTime.parse(cached['timestamp']);
      if (DateTime.now().difference(timestamp) < cacheDuration) {
        return ApiSearchResult.fromJson(cached['data']);
      }
      await _box.delete(normalized);
    }
    return null;
  }

  Future<void> set(String query, ApiSearchResult result) async {
    final normalized = query.toLowerCase().trim();
    await _box.put(normalized, {
      'timestamp': DateTime.now().toIso8601String(),
      'data': result.toJson(),
    });
  }
}
```

### API Cost Projections

| User Base | Monthly API Calls | Deezer | MusicBrainz | Spotify | Total Cost |
|-----------|-------------------|--------|-------------|---------|------------|
| **Development** | 100 | Free | Free | Free | **$0** |
| **1,000 users** | 10,000 | Free | Free | Free | **$0** |
| **10,000 users** | 100,000 | Free | Free | Free | **$0** |
| **100,000 users** | 1,000,000 | Free* | Free | Free | **$0** |

*Note: Deezer has undisclosed query quota but is generous for non-commercial use. If limits are hit, MusicBrainz serves as backup.

### Success Metrics

| Metric | Baseline | Target | Measurement |
|--------|----------|--------|-------------|
| Auto-fill rate | 0% | 80% | % of songs with API-sourced metadata |
| BPM/key coverage | 0% | 70% | % of songs with audio features |
| API response time | N/A | <500ms | Average search latency |
| Cache hit rate | 0% | 60% | % of requests served from cache |
| Manual entry reduction | 100% | 40% | Reduction in manual field completion |

### Go/No-Go Criteria

**Proceed to Phase 3 if:**
- [ ] API auto-fill rate >= 70%
- [ ] Average API response time < 1 second
- [ ] No API rate limit violations in production
- [ ] OAuth token management is stable

**Stop and iterate if:**
- API costs exceed projections (unexpected charges)
- Rate limiting causes frequent failures
- OAuth implementation has security issues

### Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| API rate limiting | Medium | Medium | Implement request queuing, respect limits, cache aggressively |
| OAuth token expiration | Low | Medium | Refresh tokens proactively, handle 401 errors gracefully |
| API deprecation | Low | High | Abstract API layer, support multiple providers |
| CORS issues (web) | Medium | Low | Use server-side proxy if needed |
| API key exposure | Medium | High | Use flutter_dotenv, never commit keys, use secure storage |

---

## Phase 3: Community Features (3-4 Weeks)

**Goal:** Leverage community for data quality and self-policing

### Business Case
- **Problem:** Some duplicates slip through automated detection
- **Impact:** Database quality degrades over time
- **Solution:** Community-driven merge suggestions, voting, and reputation system

### Tasks

| # | Task | Agent | Effort (SP) | Dependencies | Status |
|---|------|-------|-------------|--------------|--------|
| 3.1 | Create CommunitySong schema | @mr-coder | 3 | - | pending |
| 3.2 | Create CommunityUser schema | @mr-coder | 3 | - | pending |
| 3.3 | Create Contribution schema | @mr-coder | 3 | - | pending |
| 3.4 | Create Vote schema | @mr-coder | 2 | - | pending |
| 3.5 | Create MergeRequest schema | @mr-coder | 2 | - | pending |
| 3.6 | Create Badge schema | @mr-coder | 2 | - | pending |
| 3.7 | Implement reputation points system | @mr-coder | 5 | 3.2 | pending |
| 3.8 | Implement user level progression | @mr-coder | 3 | 3.7 | pending |
| 3.9 | Build merge suggestion UI | @mr-ux-agent | 8 | 3.5 | pending |
| 3.10 | Build voting UI | @mr-ux-agent | 5 | 3.4 | pending |
| 3.11 | Build contribution workflow | @mr-coder | 5 | 3.3 | pending |
| 3.12 | Implement edit history tracking | @mr-coder | 4 | 3.3 | pending |
| 3.13 | Create audit log system | @mr-coder | 3 | - | pending |
| 3.14 | Build badge earning system | @mr-coder | 4 | 3.6 | pending |
| 3.15 | Implement permission matrix | @mr-coder | 4 | 3.8 | pending |
| 3.16 | Write community feature tests | @mr-tester | 6 | 3.9-3.15 | pending |

**Total Effort:** 66 story points (adjusted for parallel work: 26 SP)

### Technical Specification

#### 3.1 Reputation System
**File:** `/lib/models/community_user.dart`

```dart
enum ReputationLevel {
  newcomer,        // 0-99 points
  contributor,     // 100-499 points
  activeMember,    // 500-1499 points
  trustedEditor,   // 1500-4999 points (auto-approved edits)
  expert,          // 5000-14999 points (can merge duplicates)
  moderator,       // 15000+ points (elected)
  admin            // System admin
}

class ReputationPoints {
  static const int SONG_ADDED = 10;
  static const int EDIT_ACCEPTED = 5;
  static const int CORRECTION_ACCEPTED = 8;
  static const int MERGE_COMPLETED = 15;
  static const int VOTE_CAST = 1;
  static const int HELPFUL_REPORT = 20;
  static const int EDIT_REJECTED = -2;
  static const int SPAM_REPORT = -50;
  static const int VANDALISM_REPORT = -100;
}
```

#### 3.2 Merge Request Workflow
**File:** `/lib/services/merge_service.dart`

```dart
class MergeService {
  Future<MergeRequest> suggestMerge({
    required String sourceSongId,
    required String targetSongId,
    required String userId,
  }) async {
    // Calculate confidence score
    final confidence = await _calculateMergeConfidence(
      sourceSongId,
      targetSongId,
    );

    // Auto-approve if confidence > 95%
    if (confidence >= 0.95) {
      return await _executeMerge(
        sourceSongId,
        targetSongId,
        autoApproved: true,
      );
    }

    // Create merge request for community voting
    final request = MergeRequest(
      id: uuid.v4(),
      sourceSongId: sourceSongId,
      targetSongId: targetSongId,
      requestedBy: userId,
      confidenceScore: confidence,
      status: MergeStatus.pending,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('community/mergeRequests').add(request.toJson());
    return request;
  }

  Future<void> voteOnMerge({
    required String mergeRequestId,
    required String userId,
    required VoteType vote,
  }) async {
    // Update vote counts
    // Check if user has permission (Active Member+)
    // Award reputation points if vote contributes to decision
  }
}
```

#### 3.3 Permission Matrix

| Action | Newcomer | Contributor | Active | Trusted | Expert | Moderator |
|--------|----------|-------------|--------|---------|--------|-----------|
| Add songs | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Edit own songs | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Edit any metadata | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Vote on edits | ✗ | ✗ | ✓ | ✓ | ✓ | ✓ |
| Merge duplicates | ✗ | ✗ | ✗ | ✗ | ✓ | ✓ |
| Review reports | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ |
| Suspend users | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ |

### Success Metrics

| Metric | Baseline | Target | Measurement |
|--------|----------|--------|-------------|
| Community contributions | 0 | 50/week | Merge requests, corrections submitted |
| Merge accuracy | N/A | >90% | % of merges accepted without reversal |
| User participation | 0% | 20% | % of users who vote/contribute |
| Dispute resolution time | N/A | <48 hours | Average time to resolve contested merges |

### Go/No-Go Criteria

**Proceed to Phase 4 if:**
- [ ] At least 10 community members actively contributing
- [ ] Merge accuracy rate >= 85%
- [ ] No abuse of reputation system detected
- [ ] Community self-policing is effective

**Stop and iterate if:**
- Reputation system is being gamed/abused
- Merge conflicts cause community friction
- Vandalism or spam increases significantly

### Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Reputation gaming | Medium | Medium | Monitor for patterns, adjust point values, manual review |
| Edit wars | Low | Medium | Three-revert rule, moderator intervention |
| Low participation | High | Low | Gamification (badges), notification prompts |
| Abuse/spam | Medium | Medium | Strike system (3 strikes = ban), report mechanism |

---

## Phase 4: Audio Recognition (4-6 Weeks)

**Goal:** Identify songs from audio recordings

### Business Case
- **Problem:** Users can't identify songs they're learning by ear
- **Impact:** Manual lookup required, practice sessions lack context
- **Solution:** Record 10 seconds → auto-identify song via audio fingerprinting

### Tasks

| # | Task | Agent | Effort (SP) | Dependencies | Status |
|---|------|-------|-------------|--------------|--------|
| 4.1 | Integrate Chromaprint library (Android) | @mr-android | 8 | - | pending |
| 4.2 | Integrate Chromaprint library (iOS) | @mr-ios | 8 | - | pending |
| 4.3 | Set up AcoustID API integration | @mr-coder | 5 | 4.1-4.2 | pending |
| 4.4 | Evaluate ACRCloud free tier (100/day) | @mr-coder | 3 | - | pending |
| 4.5 | Build audio recording UI | @mr-ux-agent | 5 | - | pending |
| 4.6 | Implement 10-second recording workflow | @mr-coder | 5 | 4.5 | pending |
| 4.7 | Create fingerprint generation service | @mr-coder | 8 | 4.1-4.3 | pending |
| 4.8 | Build song identification workflow | @mr-coder | 5 | 4.7 | pending |
| 4.9 | Auto-fill metadata from recognition result | @mr-coder | 3 | 4.8 | pending |
| 4.10 | Implement BPM/key detection from audio | @mr-coder | 8 | - | pending |
| 4.11 | Handle recognition failures gracefully | @mr-coder | 3 | 4.8 | pending |
| 4.12 | Add confidence score display | @mr-ux-agent | 3 | 4.8 | pending |
| 4.13 | Write audio recognition tests | @mr-tester | 8 | 4.3-4.12 | pending |
| 4.14 | Performance optimization (background processing) | @mr-coder | 5 | 4.7 | pending |

**Total Effort:** 87 story points (adjusted for parallel work: 40 SP)

### Technical Specification

#### 4.1 Audio Recognition Architecture
**File:** `/lib/services/audio_recognition_service.dart`

```dart
class AudioRecognitionService {
  final ChromaprintService _chromaprint;
  final AcoustidApi _acoustidApi;
  final AcrCloudApi _acrCloudApi;  // Premium fallback

  Future<RecognitionResult> identifySong({
    required File audioFile,
    Duration duration = const Duration(seconds: 10),
  }) async {
    // Generate fingerprint
    final fingerprint = await _chromaprint.generateFingerprint(
      audioFile: audioFile,
      duration: duration,
    );

    // Try AcoustID first (free)
    try {
      final result = await _acoustidApi.lookup(
        fingerprint: fingerprint,
        includeMetadata: true,
      );
      
      if (result.matches.isNotEmpty && result.matches.first.confidence > 0.7) {
        return RecognitionResult(
          success: true,
          song: result.matches.first.toSong(),
          confidence: result.matches.first.confidence,
          source: RecognitionSource.acoustid,
        );
      }
    } catch (e) {
      // Fall through to ACRCloud
    }

    // Fallback to ACRCloud (if available, uses free tier quota)
    try {
      final result = await _acrCloudApi.identify(audioFile: audioFile);
      
      if (result.status.code == 0) {  // Success
        return RecognitionResult(
          success: true,
          song: result.metadata.music.first.toSong(),
          confidence: result.metadata.music.first.score / 100,
          source: RecognitionSource.acrcloud,
        );
      }
    } catch (e) {
      // Recognition failed
    }

    return RecognitionResult(
      success: false,
      error: 'No match found',
      source: RecognitionSource.none,
    );
  }
}
```

#### 4.2 Chromaprint Integration
**File:** `/lib/services/chromaprint_service.dart`

```dart
class ChromaprintService {
  // Android: Use method channel to call Chromaprint native library
  // iOS: Use method channel to call Chromaprint native library
  
  Future<String> generateFingerprint({
    required File audioFile,
    Duration duration = const Duration(seconds: 10),
  }) async {
    // Extract 10 seconds of audio
    final extracted = await _extractAudioSegment(audioFile, duration);
    
    // Call native Chromaprint library via platform channel
    final fingerprint = await _platformChannel.invokeMethod<String>(
      'generateFingerprint',
      {'audioPath': extracted.path},
    );
    
    return fingerprint!;
  }
}
```

### API Cost Projections

| User Base | Monthly Recognitions | AcoustID | ACRCloud (Free) | ACRCloud (Paid) | Total Cost |
|-----------|---------------------|----------|-----------------|-----------------|------------|
| **Development** | 100 | Free | N/A | N/A | **$0** |
| **1,000 users** | 3,000 | Free | N/A | N/A | **$0** |
| **10,000 users** | 30,000 | Free | 100/day = 3,000/mo | 27,000 remaining | **$20-50** |
| **100,000 users** | 300,000 | Free | 3,000/mo | 297,000 remaining | **$200-500** |

**Cost Optimization Strategy:**
1. Use AcoustID (free) as primary recognition service
2. Use ACRCloud free tier (100 requests/day = 3,000/month) as secondary
3. Only pay for ACRCloud when free quota is exceeded
4. Cache recognition results to avoid duplicate API calls

### Success Metrics

| Metric | Baseline | Target | Measurement |
|--------|----------|--------|-------------|
| Recognition accuracy | N/A | >80% | % of correct song identifications |
| Recognition time | N/A | <10 seconds | Time from recording to result |
| Free tier utilization | 0% | 90% | % of recognitions using free APIs |
| User satisfaction | N/A | >4/5 stars | In-app rating for feature |

### Go/No-Go Criteria

**Proceed to Phase 5 if:**
- [ ] Recognition accuracy >= 75%
- [ ] Monthly API costs within budget (<$100 for 10K users)
- [ ] Recognition completes in <15 seconds
- [ ] User adoption rate > 10%

**Stop and iterate if:**
- API costs exceed budget by >50%
- Recognition accuracy < 50% (poor user experience)
- Performance issues drain battery significantly

### Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| High API costs | Medium | High | Use free AcoustID first, cache results, set daily limits |
| Poor recognition accuracy | Medium | High | Set confidence thresholds, allow manual correction |
| Battery drain | Medium | Medium | Optimize audio processing, use background tasks efficiently |
| Platform-specific issues | High | Medium | Test extensively on both Android and iOS |
| Privacy concerns | Low | Medium | Process audio locally when possible, clear data policies |

---

## Phase 5: Advanced Features (Ongoing)

**Goal:** Best-in-class song management with advanced audio analysis

### Business Case
- **Problem:** Power users want deeper audio analysis and smart features
- **Impact:** Competitive differentiation, user retention
- **Solution:** Local BPM/key detection, cover song detection, smart variants

### Tasks (Backlog)

| # | Task | Agent | Effort (SP) | Dependencies | Status |
|---|------|-------|-------------|--------------|--------|
| 5.1 | Implement local BPM detection (essentia.js) | @mr-coder | 13 | - | backlog |
| 5.2 | Implement local key detection | @mr-coder | 13 | - | backlog |
| 5.3 | Build cover song detection algorithm | @mr-coder | 21 | 5.1-5.2 | backlog |
| 5.4 | Implement live version detection | @mr-coder | 13 | 5.1-5.2 | backlog |
| 5.5 | Create smart variant grouping (remaster, acoustic, live) | @mr-coder | 8 | - | backlog |
| 5.6 | Build practice session audio analysis | @mr-coder | 13 | 5.1-5.2 | backlog |
| 5.7 | Implement tempo tracking during practice | @mr-coder | 8 | 5.1 | backlog |
| 5.8 | Create accuracy scoring (pitch, timing) | @mr-coder | 13 | 5.2 | backlog |

### Technical Considerations

#### 5.1 Local Audio Analysis
**Library Options:**
- **essentia.js**: JavaScript port of Essentia (C++ audio analysis library)
- **librosa**: Python library (requires server-side processing)
- **BeatDetect**: Dart package for BPM detection (limited features)

**Recommendation:** Use essentia.js via Flutter webview or platform channel for local processing.

#### 5.2 Cover Song Detection
**Approach:**
1. Extract melody contour (pitch sequence over time)
2. Extract harmony progression (chord sequence)
3. Compare using dynamic time warping (DTW)
4. Threshold: >70% similarity = potential cover

**Challenge:** Computationally expensive, may require server-side processing.

### Success Metrics

| Metric | Baseline | Target | Measurement |
|--------|----------|--------|-------------|
| Local analysis accuracy | N/A | >85% | Comparison with Spotify Audio Features |
| Cover detection accuracy | N/A | >70% | User confirmation rate |
| Feature adoption | N/A | >30% | % of users trying advanced features |

---

## Summary: Effort Estimates

### Story Points by Phase

| Phase | Total Tasks | Adjusted SP | Duration | Team Size |
|-------|-------------|-------------|----------|-----------|
| **Phase 1** | 11 tasks | 13 SP | 1-2 weeks | 2 developers |
| **Phase 2** | 12 tasks | 21 SP | 2-3 weeks | 2 developers |
| **Phase 3** | 16 tasks | 26 SP | 3-4 weeks | 2 developers |
| **Phase 4** | 14 tasks | 40 SP | 4-6 weeks | 3 developers (incl. mobile) |
| **Phase 5** | 8 tasks | Variable | Ongoing | As needed |

**Total Estimated Effort:** 100 story points (excluding Phase 5)

### Story Point Scale
- **1 SP:** ~2-4 hours of work
- **2 SP:** ~4-8 hours of work
- **3 SP:** ~1-1.5 days of work
- **5 SP:** ~2-3 days of work
- **8 SP:** ~4-5 days of work
- **13 SP:** ~1-2 weeks of work
- **21 SP:** ~2-3 weeks of work

---

## Summary: Cost Projections

### Monthly API Costs by User Base

| User Base | Phase 1-3 | Phase 4 | Phase 5 | Total Monthly |
|-----------|-----------|---------|---------|---------------|
| **Development** | $0 | $0 | $0 | **$0** |
| **1,000 users** | $0 | $0 | $0 | **$0** |
| **10,000 users** | $0 | $20-50 | $0-50 | **$20-100** |
| **100,000 users** | $0 | $200-500 | $50-100 | **$250-600** |

### Cost Breakdown by API

| API | Free Tier | Paid Tier | Use Case |
|-----|-----------|-----------|----------|
| **Deezer** | Unlimited | N/A | Primary search |
| **MusicBrainz** | Unlimited (1 req/sec) | N/A | Fallback search |
| **Spotify** | Unlimited (OAuth) | N/A | BPM/key data |
| **AcoustID** | Unlimited (3 req/sec) | N/A | Audio recognition |
| **ACRCloud** | 100/day | $20-500/mo | Recognition fallback |
| **Audd.io** | 300 total | $5/1,000 | Not recommended |

---

## Overall Risk Assessment

### Technical Risks

| Risk | Probability | Impact | Mitigation Strategy |
|------|-------------|--------|---------------------|
| API rate limiting | Medium | Medium | Aggressive caching, request queuing, multiple providers |
| OAuth complexity | Medium | Low | Use established packages, thorough testing |
| Audio processing performance | High | Medium | Background processing, native libraries |
| Firestore query costs | Medium | Low | Optimize queries, use indexes, cache results |
| Cross-platform compatibility | High | Medium | Extensive testing on both platforms |

### Business Risks

| Risk | Probability | Impact | Mitigation Strategy |
|------|-------------|--------|---------------------|
| Low user adoption | Medium | High | Gamification, clear value proposition |
| Community abuse | Medium | Medium | Reputation system, moderation tools |
| API cost overrun | Low | High | Monitor usage, set alerts, free tier priority |
| Feature creep | High | Medium | Strict MVP scope, phase gating |

---

## Success Metrics Summary

### Phase 1 (Quick Wins)
- Duplicate detection rate >= 70%
- False positive rate < 5%
- Match calculation time < 100ms

### Phase 2 (API Enrichment)
- Auto-fill rate >= 80%
- BPM/key coverage >= 70%
- API response time < 500ms

### Phase 3 (Community Features)
- Community contributions >= 50/week
- Merge accuracy >= 90%
- User participation >= 20%

### Phase 4 (Audio Recognition)
- Recognition accuracy >= 80%
- Recognition time < 10 seconds
- Free tier utilization >= 90%

### Phase 5 (Advanced Features)
- Local analysis accuracy >= 85%
- Feature adoption >= 30%

---

## Implementation Timeline

```
Week 1-2:  Phase 1 - Quick Wins
           ├── String normalization
           ├── Fuzzy matching algorithms
           └── "Did you mean?" dialog

Week 3-5:  Phase 2 - API Enrichment
           ├── Deezer + MusicBrainz integration
           ├── Spotify OAuth + Audio Features
           └── API caching + rate limiting

Week 6-9:  Phase 3 - Community Features
           ├── Reputation system
           ├── Merge suggestions + voting
           └── Edit history + badges

Week 10-15: Phase 4 - Audio Recognition
            ├── Chromaprint integration
            ├── AcoustID + ACRCloud APIs
            └── Recording UI + workflow

Week 16+:  Phase 5 - Advanced Features
           ├── Local BPM/key detection
           ├── Cover song detection
           └── Smart variants
```

---

## Appendix: File Locations

### Existing Research Documents
- `/agents/mr-architect.md` - Architecture agent specification
- `/agents/mr-senior-developer.md` - Senior developer agent specification
- `/agents/mr-android-debug.md` - Android debug agent specification
- `/agents/mr-planner.md` - Planner agent specification
- `/docs/MUSIC_API_DEEP_ANALYSIS.md` - Comprehensive API analysis
- `/docs/MUSIC_API_TEST_RESULTS.md` - API test results
- `/docs/MUSIC_API_QUICK_REFERENCE.md` - API quick reference
- `/COMMUNITY_SONG_DATABASE_DESIGN.md` - Community database design
- `/SONG_MATCHING_ALGORITHM_DESIGN.md` - Matching algorithm design
- `/FIRESTORE_BAND_DATA_ANALYSIS.md` - Firestore data analysis

### Files to Create

#### Phase 1
- `/lib/services/song_normalizer.dart`
- `/lib/services/song_matcher.dart`
- `/lib/widgets/song_match_dialog.dart`
- `/firestore.indexes.json` (update)

#### Phase 2
- `/lib/services/music_api_service.dart`
- `/lib/services/deezer_api.dart`
- `/lib/services/musicbrainz_api.dart`
- `/lib/services/spotify_api.dart`
- `/lib/services/spotify_auth_service.dart`
- `/lib/services/api_cache.dart`
- `/.env.example` (update with API keys)

#### Phase 3
- `/lib/models/community_song.dart`
- `/lib/models/community_user.dart`
- `/lib/models/contribution.dart`
- `/lib/models/merge_request.dart`
- `/lib/services/merge_service.dart`
- `/lib/services/reputation_service.dart`
- `/lib/screens/community/merge_suggestions_screen.dart`

#### Phase 4
- `/lib/services/audio_recognition_service.dart`
- `/lib/services/chromaprint_service.dart`
- `/lib/services/acoustid_api.dart`
- `/lib/services/acrcloud_api.dart`
- `/lib/widgets/audio_recorder_widget.dart`
- `/android/app/src/main/kotlin/.../ChromaprintPlugin.kt`
- `/ios/Runner/ChromaprintPlugin.swift`

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-02-28 | Use Deezer as primary search API | Fastest response time (143ms avg), no auth required, ISRC included |
| 2026-02-28 | Use AcoustID over ACRCloud for primary recognition | Completely free, no daily limits, open source |
| 2026-02-28 | Implement multi-algorithm fuzzy matching | Single algorithm insufficient for edge cases |
| 2026-02-28 | Community-driven approach for Phase 3 | Draws from successful models (Genius, MusicBrainz, Setlist.fm) |
| 2026-02-28 | Phase-gated implementation | Allows evaluation before committing to expensive features |

---

**Document End**

For questions or updates, contact: RepSync Development Team
