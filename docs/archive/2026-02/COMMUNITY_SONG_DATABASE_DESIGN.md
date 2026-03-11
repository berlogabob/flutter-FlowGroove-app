# Community Song Database Design

**Document Version:** 1.0
**Date:** February 28, 2026
**Author:** System Architecture Team
**Status:** Design Specification

---

## Executive Summary

This document specifies a comprehensive community-driven song database system for RepSync, combining crowdsourced contributions with API enrichment and local audio analysis. The design draws from successful community platforms (Genius, Setlist.fm, MusicBrainz, Discogs, Wikipedia) while addressing the unique needs of band practice management.

**Key Design Principles:**
1. **Community-first**: Users contribute and maintain song data
2. **Quality through verification**: Multi-layer validation system
3. **Hybrid enrichment**: Combine community data with API sources
4. **Gamified participation**: Incentivize quality contributions
5. **Graceful degradation**: Work offline, enrich when connected

---

## 1. Research: Successful Crowdsourcing Models

### 1.1 Genius (Lyrics + Annotations)

**Duplicate Prevention:**
- One account per person (alternate accounts prohibited)
- Song page tampering results in immediate permanent ban
- Songpage spamming (duplicate comments) is removed

**Quality Control:**
- **Sourcing Protocol**: Users must quote and link sources for unreleased content
- **Plagiarism Prevention**: Copying without attribution = post-warning permanent ban
- **IQ Gaming Prevention**: Tampering with metadata to game the system is prohibited
- **Pageview Boosting Prevention**: Fake pageviews = immediate permanent ban

**Moderation System:**
- **3-Strike Penalty System**:
  - Warning (first offense)
  - 1 strike = 24-hour suspension
  - 2 strikes = 7-day suspension
  - 3 strikes = permanent ban
- **Severity Tiers**:
  - Full Strikes: Harassment, spam, alternate accounts
  - Post-Warning Bans: Plagiarism, self-promotion, account sharing
  - Immediate Bans: Pageview boosting, CSAM, severe harassment

**User Reputation Levels:**
- Verified Artists
- Transcribers
- Editors
- Mediators
- Moderators
- Community Staff

**Dispute Resolution:**
- Dedicated Mediator role
- Report via @genius-moderation tag
- Discord server for community help
- Help forum for questions

---

### 1.2 Setlist.fm (Concert Setlists)

**Duplicate Prevention:**
- Multiple shows on same day require explicit identification
- Required: set times, clear identifiers ("First show", "Evening show")
- Assumed setlists based on tour patterns are deleted
- Posthumous cover band setlists immediately deleted

**Quality Control:**
- **Source Requirements** (ranked by validity):
  1. Complete audio/video recordings (archive.org)
  2. Artist's official website/social media
  3. Concert reviews by credible sources
  4. Photos of artist's paper setlist
  5. Social media content (fans' photos/videos)
  6. Videos (YouTube, Facebook, Instagram)
  7. Photos of ticket stubs/merchandise
  8. "I was there" (venue corrections, individual songs)
- **Invalid Sources**: AI chatbots, unconfirmed Wikipedia lists, hearsay

**Community Editing:**
- Wiki-like service (anyone can edit after signup)
- Guidelines page defines standards
- Forum for dispute resolution

**Moderation:**
- Edits without proper sources can be deleted
- Forum-based discussion for disputes
- "Post to forum" for edge cases

---

### 1.3 MusicBrainz (Community Metadata)

**Duplicate Merging:**
- Merging is the correct way to resolve duplicates
- Navigate to recordings and press "Merge" link
- Merge candidates identified by title and length

**Voting System:**
- **Edit Voting Process**:
  - Edits stay open for 7 days
  - Auto-editors can approve immediately
  - 3 "No" votes = rejection (after 72 hours from first No)
  - If no votes: automatically accepted
  - If votes exist: accepted if more "Yes" than "No"
- **Auto-Editor Privileges**:
  - Edits automatically approved without voting
  - Can approve/reject other users' edits
  - Elected by nomination + 2 seconders + majority vote

**Quality Control:**
- Auto-editors earn privileges through reputation
- Bot automation for routine edits
- Community voting for contested edits

---

### 1.4 Discogs (Community Discography)

**Duplicate Prevention:**
- Duplicate detection during submission
- "Possible duplicate releases" warning shown
- User can override if confident it's not a duplicate
- Submissions can be merged via community vote

**Quality Control:**
- **Database Guidelines**: Strict formatting rules
- **Submission Review**: Community can flag suspicious submissions
- **Removal Votes**: Community votes on removal of incorrect entries
- **Protection Policy**: Staff can protect data from damaging edits

**Contributor System:**
- Contributor Improvement Program
- Messages when submissions have problems
- Rating system based on submission quality

---

### 1.5 Wikipedia (General Knowledge)

**Edit History:**
- Every edit recorded in page history
- Shows: timestamp, editor, edit summary, permanent URL
- Diffs compare any two versions
- All edits permanently retained (even reverted ones)

**Revert Mechanism:**
- **Manual Reverting**: Copy/paste from previous version
- **Undo**: Removes undesirable edit while keeping later edits
- **Rollback**: One-click revert (admins/rollbackers only)
- **Twinkle**: Gadget with rollback options (AGF, neutral, vandalism)
- **Three-Revert Rule**: Max 3 reversions per page per 24 hours

**Vandalism Prevention:**
- Rollback tool for quick reverts
- Bot rollback during "flood vandalism"
- Automated tools: Huggle, STiki, WPCleaner
- Edit filters detect vandalism patterns

**Dispute Resolution:**
- Three-revert rule prevents edit wars
- Talk page discussions required
- Partial reversion preferred over complete reversal
- Administrative action for rule violations

---

## 2. RepSync Community Database Design

### 2.1 Contribution Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER ADDS SONG                               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              SEARCH EXISTING (FUZZY MATCH)                      │
│  - Normalized title/artist comparison                           │
│  - Levenshtein + Jaro-Winkler + Token Sort                      │
│  - Soundex phonetic matching                                    │
│  - External ID lookup (Spotify, MusicBrainz, ISRC)              │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    ┌───────┴───────┐
                    │               │
              MATCH FOUND       NO MATCH
                    │               │
                    ↓               ↓
    ┌───────────────────────────┐   ┌───────────────────────────┐
    │    USER CAN:              │   │    CREATE NEW SONG        │
    │  - Use existing (upvote)  │   │  → Community can:         │
    │  - Add variant            │   │    - Merge duplicates     │
    │    (live, cover, remix)   │   │    - Correct metadata     │
    │  - Suggest corrections    │   │    - Add missing info     │
    └───────────────────────────┘   │    - Vote on accuracy     │
                                    └───────────────────────────┘
```

### 2.2 Duplicate Detection Algorithm

**Multi-Stage Matching:**

```dart
class DuplicateDetector {
  static MatchResult detectDuplicate(Song input, List<Song> existing) {
    // Stage 1: Exact external ID match (100% confidence)
    if (input.spotifyId != null) {
      final spotifyMatch = existing.firstWhere(
        (s) => s.spotifyId == input.spotifyId,
        orElse: () => null,
      );
      if (spotifyMatch != null) return MatchResult.exact(spotifyMatch);
    }

    if (input.isrc != null) {
      final isrcMatch = existing.firstWhere(
        (s) => s.isrc == input.isrc,
        orElse: () => null,
      );
      if (isrcMatch != null) return MatchResult.exact(isrcMatch);
    }

    // Stage 2: Normalized fuzzy match
    final candidates = existing.where((s) =>
      _titleSimilarity(input, s) > 0.6 &&
      _artistSimilarity(input, s) > 0.5
    ).toList();

    // Stage 3: Score and rank
    for (final candidate in candidates) {
      candidate.matchScore = _calculateMatchScore(input, candidate);
    }
    candidates.sort((a, b) => b.matchScore.compareTo(a.matchScore));

    // Stage 4: Return best match if above threshold
    if (candidates.isNotEmpty && candidates.first.matchScore >= 85) {
      return MatchResult.suggested(candidates.first);
    }

    return MatchResult.none();
  }

  static double _calculateMatchScore(Song a, Song b) {
    return (
      _titleSimilarity(a, b) * 0.40 +
      _artistSimilarity(a, b) * 0.40 +
      _durationSimilarity(a, b) * 0.10 +
      _albumSimilarity(a, b) * 0.10
    ) * 100;
  }
}
```

**Match Confidence Levels:**

| Score Range | Confidence | Action |
|-------------|------------|--------|
| 95-100% | EXACT | Auto-suggest with high confidence |
| 85-94% | HIGH | Show "Did you mean?" dialog |
| 70-84% | MEDIUM | Show in "Possible matches" list |
| 50-69% | LOW | Don't auto-suggest, allow manual review |
| <50% | NONE | Proceed with new song creation |

---

## 3. Database Schema

### 3.1 Core Collections

```
┌─────────────────────────────────────────────────────────────────┐
│ Firestore Database Structure                                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  /users/{userId}                                                │
│    ├── profile: UserProfile                                     │
│    ├── songs/{songId}: Song                                     │
│    ├── setlists/{setlistId}: Setlist                            │
│    └── contributions/{contributionId}: Contribution             │
│                                                                 │
│  /bands/{bandId}                                                │
│    ├── band: Band                                               │
│    ├── songs/{songId}: Song                                     │
│    └── members/{memberId}: BandMember                           │
│                                                                 │
│  /community                                                     │
│    ├── songs/{songId}: CommunitySong                            │
│    ├── users/{userId}: CommunityUser                            │
│    ├── contributions/{contributionId}: Contribution             │
│    ├── votes/{voteId}: Vote                                     │
│    ├── reports/{reportId}: Report                               │
│    └── mergeRequests/{mergeId}: MergeRequest                    │
│                                                                 │
│  /system                                                        │
│    ├── badges/{badgeId}: Badge                                  │
│    ├── reputationLevels/{levelId}: ReputationLevel              │
│    └── auditLogs/{logId}: AuditLog                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 CommunitySong Schema

```dart
@JsonSerializable()
class CommunitySong {
  // Core identification
  final String id;
  final String title;
  final String artist;
  final String? album;
  final int? durationMs;

  // Musical properties
  final String? key;           // Musical key (e.g., "C", "Am")
  final int? bpm;              // Beats per minute
  final String? timeSignature; // e.g., "4/4", "3/4"

  // External IDs (for API enrichment)
  final String? spotifyId;
  final String? musicbrainzId;
  final String? isrc;
  final String? deezerId;
  final String? discogsId;

  // Normalized fields (for search)
  final String? normalizedTitle;
  final String? normalizedArtist;
  final String? titleSoundex;
  final String? artistSoundex;

  // Variant tracking
  final String? variantType;   // 'original', 'live', 'acoustic', 'remix', 'cover'
  final String? variantOf;     // ID of original song

  // Community metadata
  final String createdBy;      // User ID of creator
  final DateTime createdAt;
  final DateTime updatedAt;
  final int editCount;         // Number of edits

  // Quality indicators
  final int upvotes;           // Net upvotes
  final int downvotes;
  final double confidenceScore; // System-calculated confidence (0-1)
  final VerificationStatus verificationStatus;

  // Data sources
  final DataSource primarySource;  // Where did this data come from?
  final List<DataSource> enrichmentSources;

  // Links to full data
  final List<Link> links;
  final String? notes;
  final List<String> tags;

  CommunitySong({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.durationMs,
    this.key,
    this.bpm,
    this.timeSignature,
    this.spotifyId,
    this.musicbrainzId,
    this.isrc,
    this.deezerId,
    this.discogsId,
    this.normalizedTitle,
    this.normalizedArtist,
    this.titleSoundex,
    this.artistSoundex,
    this.variantType,
    this.variantOf,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.editCount = 0,
    this.upvotes = 0,
    this.downvotes = 0,
    this.confidenceScore = 0.5,
    this.verificationStatus = VerificationStatus.unverified,
    this.primarySource = DataSource.community,
    this.enrichmentSources = const [],
    this.links = const [],
    this.notes,
    this.tags = const [],
  });
}

enum VerificationStatus {
  unverified,      // New submission, not reviewed
  communityVerified, // Verified by community votes
  apiVerified,     // Verified by external API match
  moderatorVerified, // Verified by moderator
  disputed,        // Under dispute
  merged,          // Merged into another song
  deleted          // Deleted (soft delete)
}

enum DataSource {
  community,       // User-submitted
  spotify,         // From Spotify API
  musicbrainz,     // From MusicBrainz API
  lastfm,          // From Last.fm API
  audioAnalysis,   // From local audio analysis
  manualEntry      // Manually entered by user
}
```

### 3.3 CommunityUser Schema

```dart
@JsonSerializable()
class CommunityUser {
  final String uid;
  final String displayName;
  final String? email;
  final String? photoURL;

  // Reputation system
  final int reputationPoints;
  final ReputationLevel level;
  final List<String> badges;  // Badge IDs earned

  // Contribution stats
  final int songsAdded;
  final int editsMade;
  final int correctionsMade;
  final int mergesCompleted;
  final int votesCast;
  final int reportsSubmitted;

  // Quality metrics
  final int acceptedContributions;
  final int rejectedContributions;
  final double contributionAccuracy; // accepted / (accepted + rejected)

  // Permissions
  final List<Permission> permissions;
  final DateTime? suspensionUntil;
  final int strikeCount;

  // Timestamps
  final DateTime createdAt;
  final DateTime lastActiveAt;

  CommunityUser({
    required this.uid,
    required this.displayName,
    this.email,
    this.photoURL,
    this.reputationPoints = 0,
    this.level = ReputationLevel.newcomer,
    this.badges = const [],
    this.songsAdded = 0,
    this.editsMade = 0,
    this.correctionsMade = 0,
    this.mergesCompleted = 0,
    this.votesCast = 0,
    this.reportsSubmitted = 0,
    this.acceptedContributions = 0,
    this.rejectedContributions = 0,
    this.contributionAccuracy = 0.0,
    this.permissions = const [],
    this.suspensionUntil,
    this.strikeCount = 0,
    required this.createdAt,
    required this.lastActiveAt,
  });
}

enum ReputationLevel {
  newcomer,        // 0-99 points
  contributor,     // 100-499 points
  activeMember,    // 500-1499 points
  trustedEditor,   // 1500-4999 points
  expert,          // 5000-14999 points
  moderator,       // 15000+ points (elected)
  admin            // System admin
}

enum Permission {
  addSongs,
  editSongs,
  voteOnEdits,
  mergeDuplicates,
  reportIssues,
  moderateReports,
  suspendUsers,
  systemAdmin
}
```

### 3.4 Contribution Schema

```dart
@JsonSerializable()
class Contribution {
  final String id;
  final String userId;
  final String songId;
  final ContributionType type;
  final ContributionStatus status;

  // Change details
  final Map<String, dynamic> changes;  // {field: {old, new}}
  final String? comment;  // User's explanation

  // Voting (for edits requiring approval)
  final int yesVotes;
  final int noVotes;
  final List<String> voters;  // User IDs who voted

  // Review
  final String? reviewerId;
  final String? reviewComment;
  final DateTime? reviewedAt;

  // Auto-merge
  final double autoMergeConfidence;  // Confidence score if auto-merged
  final bool isAutoMerged;

  // Timestamps
  final DateTime createdAt;
  final DateTime? resolvedAt;

  Contribution({
    required this.id,
    required this.userId,
    required this.songId,
    required this.type,
    this.status = ContributionStatus.pending,
    this.changes = const {},
    this.comment,
    this.yesVotes = 0,
    this.noVotes = 0,
    this.voters = const [],
    this.reviewerId,
    this.reviewComment,
    this.reviewedAt,
    this.autoMergeConfidence = 0.0,
    this.isAutoMerged = false,
    required this.createdAt,
    this.resolvedAt,
  });
}

enum ContributionType {
  addSong,
  editMetadata,      // Title, artist, album
  editMusicalData,   // BPM, key, time signature
  addVariant,        // Live version, cover, remix
  mergeDuplicate,
  splitSong,         // Split incorrectly merged songs
  addExternalId,     // Add Spotify/ISRC/etc.
  deleteSong
}

enum ContributionStatus {
  pending,         // Awaiting review/votes
  approved,        // Approved and applied
  rejected,        // Rejected
  autoApproved,    // Auto-approved (high confidence)
  merged,          // Merged with another contribution
  superseded,      // Superseded by newer contribution
  escalated        // Escalated to moderator
}
```

### 3.5 Vote Schema

```dart
@JsonSerializable()
class Vote {
  final String id;
  final String userId;
  final String contributionId;
  final VoteType voteType;
  final String? comment;
  final DateTime createdAt;

  Vote({
    required this.id,
    required this.userId,
    required this.contributionId,
    required this.voteType,
    this.comment,
    required this.createdAt,
  });
}

enum VoteType {
  yes,
  no,
  abstain
}
```

### 3.6 Report Schema

```dart
@JsonSerializable()
class Report {
  final String id;
  final String reporterId;
  final String targetType;  // 'song', 'user', 'contribution'
  final String targetId;
  final ReportReason reason;
  final String details;
  final ReportStatus status;
  final String? assignedModeratorId;
  final String? resolutionNotes;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  Report({
    required this.id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.details,
    this.status = ReportStatus.open,
    this.assignedModeratorId,
    this.resolutionNotes,
    required this.createdAt,
    this.resolvedAt,
  });
}

enum ReportReason {
  incorrectData,
  duplicateContent,
  spam,
  inappropriateContent,
  vandalism,
  copyrightViolation,
  other
}

enum ReportStatus {
  open,
  underReview,
  resolved,
  dismissed,
  escalated
}
```

### 3.7 MergeRequest Schema

```dart
@JsonSerializable()
class MergeRequest {
  final String id;
  final String sourceSongId;  // Will be merged INTO target
  final String targetSongId;
  final String requestedBy;
  final MergeStatus status;
  final double confidenceScore;
  final String justification;

  // Voting
  final int yesVotes;
  final int noVotes;
  final List<String> voters;

  // Resolution
  final String? resolvedBy;
  final String? resolutionNotes;
  final DateTime? resolvedAt;

  final DateTime createdAt;

  MergeRequest({
    required this.id,
    required this.sourceSongId,
    required this.targetSongId,
    required this.requestedBy,
    this.status = MergeStatus.pending,
    this.confidenceScore = 0.0,
    this.justification = '',
    this.yesVotes = 0,
    this.noVotes = 0,
    this.voters = const [],
    this.resolvedBy,
    this.resolutionNotes,
    this.resolvedAt,
    required this.createdAt,
  });
}

enum MergeStatus {
  pending,
  autoApproved,    // Auto-approved (>95% confidence)
  communityApproved, // Approved by community votes
  moderatorApproved,
  rejected,
  cancelled
}
```

### 3.8 Badge Schema

```dart
@JsonSerializable()
class Badge {
  final String id;
  final String name;
  final String description;
  final String iconUrl;
  final BadgeCategory category;
  final int pointsValue;
  final BadgeCriteria criteria;

  Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.category,
    required this.pointsValue,
    required this.criteria,
  });
}

enum BadgeCategory {
  contribution,    // Songs added, edits made
  quality,         // High accuracy contributions
  community,       // Votes, helpful reports
  expertise,       // BPM/key corrections
  milestone        // Special achievements
}

@JsonSerializable()
class BadgeCriteria {
  final String metric;      // 'songsAdded', 'accuracy', etc.
  final int threshold;      // Required value
  final String? additionalCondition;

  BadgeCriteria({
    required this.metric,
    required this.threshold,
    this.additionalCondition,
  });
}

// Example badges:
// - "First Step": Add first song (contribution)
// - "Century Club": Add 100 songs (milestone)
// - "Eagle Eye": 50 accurate corrections (quality)
// - "Music Theory Master": 100 BPM/key corrections (expertise)
// - "Community Guardian": 25 helpful reports (community)
// - "Trusted Editor": Reach trusted editor level (milestone)
```

### 3.9 AuditLog Schema

```dart
@JsonSerializable()
class AuditLog {
  final String id;
  final String userId;
  final String action;
  final String targetType;
  final String targetId;
  final Map<String, dynamic> changes;
  final String? reason;
  final String? ipAddress;
  final DateTime timestamp;

  AuditLog({
    required this.id,
    required this.userId,
    required this.action,
    required this.targetType,
    required this.targetId,
    this.changes = const {},
    this.reason,
    this.ipAddress,
    required this.timestamp,
  });
}
```

---

## 4. Reputation System

### 4.1 Points Allocation

```dart
class ReputationPoints {
  // Contribution points
  static const int SONG_ADDED = 10;
  static const int EDIT_ACCEPTED = 5;
  static const int CORRECTION_ACCEPTED = 8;
  static const int MERGE_COMPLETED = 15;

  // Quality bonuses
  static const int HIGH_ACCURACY_BONUS = 50;  // 95%+ accuracy after 50 contributions
  static const int EXPERT_BONUS = 100;        // Recognized expert in domain

  // Community participation
  static const int VOTE_CAST = 1;
  static const int HELPFUL_REPORT = 20;
  static const int EDIT_REVIEWED = 2;

  // Penalties
  static const int EDIT_REJECTED = -2;
  static const int SPAM_REPORT = -50;
  static const int VANDALISM_REPORT = -100;
}
```

### 4.2 Level Progression

```
┌─────────────────────────────────────────────────────────────────┐
│ Reputation Level Progression                                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Newcomer        (0-99 pts)     → Can add songs                │
│      ↓                                                          │
│  Contributor     (100-499 pts)  → Can edit metadata             │
│      ↓                                                          │
│  Active Member   (500-1499 pts) → Can vote on edits            │
│      ↓                                                          │
│  Trusted Editor  (1500-4999 pts)→ Edits auto-approved          │
│      ↓                                                          │
│  Expert          (5000-14999 pts)→ Can merge duplicates         │
│      ↓                                                          │
│  Moderator       (15000+ pts)   → Elected, can review reports  │
│      ↓                                                          │
│  Admin           (System)       → Full access                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 4.3 Permission Matrix

| Action | Newcomer | Contributor | Active | Trusted | Expert | Moderator |
|--------|----------|-------------|--------|---------|--------|-----------|
| Add songs | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Edit own songs | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Edit any metadata | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Vote on edits | ✗ | ✗ | ✓ | ✓ | ✓ | ✓ |
| Merge duplicates | ✗ | ✗ | ✗ | ✗ | ✓ | ✓ |
| Review reports | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ |
| Suspend users | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ |

### 4.4 Badge System

```dart
class BadgeDefinitions {
  static final List<Badge> allBadges = [
    // Contribution badges
    Badge(
      id: 'first_song',
      name: 'First Step',
      description: 'Add your first song to the community database',
      iconUrl: '/badges/first_song.png',
      category: BadgeCategory.contribution,
      pointsValue: 10,
      criteria: BadgeCriteria(metric: 'songsAdded', threshold: 1),
    ),
    Badge(
      id: 'century_club',
      name: 'Century Club',
      description: 'Add 100 songs to the community database',
      iconUrl: '/badges/century_club.png',
      category: BadgeCategory.milestone,
      pointsValue: 500,
      criteria: BadgeCriteria(metric: 'songsAdded', threshold: 100),
    ),
    Badge(
      id: 'song_master',
      name: 'Song Master',
      description: 'Add 500 songs to the community database',
      iconUrl: '/badges/song_master.png',
      category: BadgeCategory.milestone,
      pointsValue: 2500,
      criteria: BadgeCriteria(metric: 'songsAdded', threshold: 500),
    ),

    // Quality badges
    Badge(
      id: 'eagle_eye',
      name: 'Eagle Eye',
      description: 'Make 50 accurate corrections',
      iconUrl: '/badges/eagle_eye.png',
      category: BadgeCategory.quality,
      pointsValue: 250,
      criteria: BadgeCriteria(
        metric: 'correctionsMade',
        threshold: 50,
        additionalCondition: 'accuracy >= 0.90',
      ),
    ),
    Badge(
      id: 'perfectionist',
      name: 'Perfectionist',
      description: 'Maintain 98%+ accuracy over 100 contributions',
      iconUrl: '/badges/perfectionist.png',
      category: BadgeCategory.quality,
      pointsValue: 1000,
      criteria: BadgeCriteria(
        metric: 'acceptedContributions',
        threshold: 100,
        additionalCondition: 'accuracy >= 0.98',
      ),
    ),

    // Expertise badges
    Badge(
      id: 'bpm_expert',
      name: 'BPM Expert',
      description: 'Contribute 100 accurate BPM values',
      iconUrl: '/badges/bpm_expert.png',
      category: BadgeCategory.expertise,
      pointsValue: 300,
      criteria: BadgeCriteria(
        metric: 'bpmCorrections',
        threshold: 100,
        additionalCondition: 'accuracy >= 0.90',
      ),
    ),
    Badge(
      id: 'key_master',
      name: 'Key Master',
      description: 'Contribute 100 accurate musical keys',
      iconUrl: '/badges/key_master.png',
      category: BadgeCategory.expertise,
      pointsValue: 300,
      criteria: BadgeCriteria(
        metric: 'keyCorrections',
        threshold: 100,
        additionalCondition: 'accuracy >= 0.90',
      ),
    ),

    // Community badges
    Badge(
      id: 'community_guardian',
      name: 'Community Guardian',
      description: 'Submit 25 helpful reports',
      iconUrl: '/badges/guardian.png',
      category: BadgeCategory.community,
      pointsValue: 200,
      criteria: BadgeCriteria(
        metric: 'helpfulReports',
        threshold: 25,
      ),
    ),
    Badge(
      id: 'active_voter',
      name: 'Active Voter',
      description: 'Cast 500 votes on community edits',
      iconUrl: '/badges/voter.png',
      category: BadgeCategory.community,
      pointsValue: 150,
      criteria: BadgeCriteria(metric: 'votesCast', threshold: 500),
    ),
  ];
}
```

### 4.5 Leaderboards

```dart
class LeaderboardService {
  // Global leaderboards
  Future<List<CommunityUser>> getTopContributors({
    int limit = 100,
    LeaderboardTimeRange timeRange = LeaderboardTimeRange.allTime,
  }) async {
    // Query users sorted by reputation points
    // Filter by time range if needed
  }

  Future<List<CommunityUser>> getTopAccuracy({
    int limit = 100,
    int minContributions = 50,  // Minimum contributions to qualify
  }) async {
    // Query users with highest contribution accuracy
  }

  // Category-specific leaderboards
  Future<List<CommunityUser>> getTopBpmContributors({int limit = 50}) async;
  Future<List<CommunityUser>> getTopKeyContributors({int limit = 50}) async;
  Future<List<CommunityUser>> getTopEditors({int limit = 50}) async;
}

enum LeaderboardTimeRange {
  daily,
  weekly,
  monthly,
  allTime
}
```

---

## 5. Quality Control System

### 5.1 Edit History

```dart
class EditHistoryService {
  /// Records every edit with full before/after state
  Future<void> recordEdit({
    required String songId,
    required String userId,
    required Map<String, dynamic> changes,
    required String contributionId,
  }) async {
    await firestore.collection('system').collection('editHistory').add({
      'songId': songId,
      'userId': userId,
      'changes': changes,  // {field: {old: x, new: y}}
      'contributionId': contributionId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Get full history for a song
  Future<List<EditRecord>> getSongHistory(String songId) async {
    // Returns chronological list of all edits
  }

  /// Compare any two versions
  Future<VersionDiff> compareVersions({
    required String songId,
    required DateTime version1,
    required DateTime version2,
  }) async {
    // Returns detailed diff between versions
  }
}
```

### 5.2 Revert Mechanism

```dart
class RevertService {
  /// Revert song to a previous version
  Future<Contribution> revertToVersion({
    required String songId,
    required String targetVersionId,
    required String userId,
    required String reason,
  }) async {
    // 1. Get the target version
    final targetVersion = await _getVersion(songId, targetVersionId);

    // 2. Get current version
    final currentVersion = await _getCurrentVersion(songId);

    // 3. Create revert contribution
    final revert = Contribution(
      id: firestore.collection('contributions').doc().id,
      userId: userId,
      songId: songId,
      type: ContributionType.editMetadata,
      status: ContributionStatus.pending,
      changes: _calculateDiff(currentVersion, targetVersion),
      comment: 'Revert to version $targetVersionId: $reason',
      createdAt: DateTime.now(),
    );

    // 4. Submit for approval (or auto-approve for trusted users)
    return await _submitContribution(revert);
  }

  /// Quick revert for vandalism (trusted users only)
  Future<void> quickRevert({
    required String songId,
    required String targetVersionId,
    required String userId,
  }) async {
    final user = await _getUser(userId);
    if (user.level < ReputationLevel.trustedEditor) {
      throw PermissionDeniedException();
    }

    // Directly restore without voting
    await _restoreVersion(songId, targetVersionId);
  }
}
```

### 5.3 Moderation Tools

```dart
class ModerationService {
  /// Submit a report
  Future<Report> submitReport({
    required String reporterId,
    required String targetType,
    required String targetId,
    required ReportReason reason,
    required String details,
  }) async {
    final report = Report(
      id: firestore.collection('reports').doc().id,
      reporterId: reporterId,
      targetType: targetType,
      targetId: targetId,
      reason: reason,
      details: details,
      status: ReportStatus.open,
      createdAt: DateTime.now(),
    );

    await firestore.collection('reports').doc(report.id).set(report.toJson());

    // Auto-assign to moderator based on workload
    await _autoAssignModerator(report);

    return report;
  }

  /// Review a report
  Future<void> reviewReport({
    required String reportId,
    required String moderatorId,
    required bool action,  // true = uphold, false = dismiss
    required String notes,
  }) async {
    final report = await _getReport(reportId);

    // Update report status
    await firestore.collection('reports').doc(reportId).update({
      'status': action ? ReportStatus.resolved : ReportStatus.dismissed,
      'assignedModeratorId': moderatorId,
      'resolutionNotes': notes,
      'resolvedAt': FieldValue.serverTimestamp(),
    });

    // Take action if upheld
    if (action) {
      await _takeActionOnReport(report);
    }

    // Award reputation to reporter if helpful
    if (action && report.reason != ReportReason.other) {
      await _awardReputation(report.reporterId, ReputationPoints.HELPFUL_REPORT);
    }
  }

  /// Issue a strike to a user
  Future<void> issueStrike({
    required String userId,
    required String reason,
    required int strikeSeverity,
  }) async {
    final user = await _getUser(userId);
    final newStrikeCount = user.strikeCount + 1;

    // Calculate suspension
    DateTime? suspensionUntil;
    if (newStrikeCount >= 3) {
      // Permanent ban
      suspensionUntil = DateTime(2099);
    } else if (newStrikeCount == 2) {
      // 7-day suspension
      suspensionUntil = DateTime.now().add(Duration(days: 7));
    } else if (newStrikeCount == 1) {
      // 24-hour suspension
      suspensionUntil = DateTime.now().add(Duration(hours: 24));
    }

    await firestore.collection('community').collection('users').doc(userId).update({
      'strikeCount': newStrikeCount,
      'suspensionUntil': suspensionUntil?.toIso8601String(),
    });

    // Log the action
    await _logModerationAction(userId, 'strike_issued', {
      'reason': reason,
      'severity': strikeSeverity,
      'strikeCount': newStrikeCount,
    });
  }
}
```

### 5.4 Auto-Merge System

```dart
class AutoMergeService {
  /// Check if a merge can be auto-approved
  Future<bool> canAutoMerge(Song source, Song target) async {
    final confidence = _calculateMergeConfidence(source, target);

    // Auto-merge if confidence > 95%
    return confidence >= 0.95;
  }

  /// Calculate merge confidence score
  double _calculateMergeConfidence(Song a, Song b) {
    double score = 0.0;
    int factors = 0;

    // External ID match (definitive)
    if (a.spotifyId != null && a.spotifyId == b.spotifyId) {
      score += 1.0;
      factors++;
    }
    if (a.isrc != null && a.isrc == b.isrc) {
      score += 1.0;
      factors++;
    }
    if (a.musicbrainzId != null && a.musicbrainzId == b.musicbrainzId) {
      score += 1.0;
      factors++;
    }

    // Title/artist similarity
    if (factors == 0) {
      score += _titleSimilarity(a, b) * 0.5;
      score += _artistSimilarity(a, b) * 0.5;
      factors += 2;
    }

    // Duration match
    if (a.durationMs != null && b.durationMs != null) {
      final durationDiff = (a.durationMs! - b.durationMs!).abs();
      if (durationDiff < 1000) {  // Within 1 second
        score += 1.0;
        factors++;
      }
    }

    // Album match
    if (a.album != null && a.album == b.album) {
      score += 1.0;
      factors++;
    }

    return factors > 0 ? score / factors : 0.0;
  }

  /// Execute auto-merge
  Future<MergeRequest> autoMerge({
    required Song source,
    required Song target,
  }) async {
    final confidence = _calculateMergeConfidence(source, target);

    if (confidence < 0.95) {
      throw Exception('Confidence too low for auto-merge');
    }

    // Create merge request with auto-approved status
    final mergeRequest = MergeRequest(
      id: firestore.collection('mergeRequests').doc().id,
      sourceSongId: source.id,
      targetSongId: target.id,
      requestedBy: 'system',
      status: MergeStatus.autoApproved,
      confidenceScore: confidence,
      justification: 'Auto-merged with ${confidence.toStringAsFixed(2)} confidence',
      createdAt: DateTime.now(),
      resolvedAt: DateTime.now(),
      resolvedBy: 'system',
    );

    await firestore.collection('mergeRequests').doc(mergeRequest.id).set(mergeRequest.toJson());

    // Execute the merge
    await _executeMerge(source, target);

    return mergeRequest;
  }
}
```

### 5.5 Manual Review Queue

```dart
class ReviewQueueService {
  /// Get items pending review
  Future<List<ReviewItem>> getPendingReviews({
    required String moderatorId,
    int limit = 50,
  }) async {
    // Prioritize by:
    // 1. Age (oldest first)
    // 2. Report severity
    // 3. User reputation (lower rep = higher priority)

    return await firestore
        .collection('reviews')
        .where('status', isEqualTo: ReviewStatus.pending)
        .orderBy('priority', descending: true)
        .orderBy('createdAt', descending: false)
        .limit(limit)
        .get();
  }

  /// Review a contribution
  Future<void> reviewContribution({
    required String contributionId,
    required String reviewerId,
    required bool approved,
    required String? comment,
  }) async {
    final contribution = await _getContribution(contributionId);

    // Update contribution status
    await firestore.collection('contributions').doc(contributionId).update({
      'status': approved ? ContributionStatus.approved : ContributionStatus.rejected,
      'reviewerId': reviewerId,
      'reviewComment': comment,
      'reviewedAt': FieldValue.serverTimestamp(),
      'resolvedAt': FieldValue.serverTimestamp(),
    });

    // Apply or reject changes
    if (approved) {
      await _applyContribution(contribution);
      await _awardReputation(contribution.userId, ReputationPoints.EDIT_ACCEPTED);
    } else {
      await _awardReputation(contribution.userId, ReputationPoints.EDIT_REJECTED);
    }
  }
}
```

---

## 6. Hybrid Approach: API Integration

### 6.1 Integration Points

```dart
class HybridEnrichmentService {
  /// Enrich song data from multiple sources
  Future<EnrichedSongData> enrichSong(Song song) async {
    final results = <DataSource, SongData>{};

    // Priority 1: External IDs (definitive match)
    if (song.spotifyId != null) {
      final spotifyData = await _fetchFromSpotify(song.spotifyId!);
      if (spotifyData != null) {
        results[DataSource.spotify] = spotifyData;
      }
    }

    if (song.isrc != null) {
      final isrcData = await _fetchByIsrc(song.isrc!);
      if (isrcData != null) {
        results[DataSource.spotify] = isrcData;  // ISRC usually resolves to Spotify
      }
    }

    // Priority 2: Search by title/artist
    if (results.isEmpty) {
      final searchResults = await Future.wait([
        _searchSpotify(song.title, song.artist),
        _searchMusicBrainz(song.title, song.artist),
      ]);

      for (final result in searchResults.where((r) => r != null)) {
        results[result!.source] = result;
      }
    }

    // Priority 3: Local audio analysis (if file available)
    if (song.audioFile != null) {
      final audioAnalysis = await _analyzeAudio(song.audioFile!);
      results[DataSource.audioAnalysis] = audioAnalysis;
    }

    // Merge results with confidence weighting
    return _mergeEnrichmentResults(results, song);
  }

  /// When to call external APIs
  ///
  /// API calls are made when:
  /// 1. User adds song without external IDs
  /// 2. Community data has low confidence (< 0.7)
  /// 3. BPM/key missing and audio file available
  /// 4. User explicitly requests enrichment
  ///
  /// API calls are skipped when:
  /// 1. Community data has high confidence (> 0.9)
  /// 2. Rate limit exceeded
  /// 3. User offline (use cached data)
  /// 4. Song already enriched recently (< 30 days)
  Future<bool> shouldCallApi(Song song, EnrichmentType type) async {
    // Check confidence
    if (song.confidenceScore > 0.9) return false;

    // Check rate limits
    if (await _isRateLimited()) return false;

    // Check cache age
    final lastEnriched = await _getLastEnrichmentDate(song.id, type);
    if (lastEnriched != null &&
        DateTime.now().difference(lastEnriched) < Duration(days: 30)) {
      return false;
    }

    return true;
  }
}
```

### 6.2 API Priority Matrix

```
┌─────────────────────────────────────────────────────────────────┐
│ API Integration Priority                                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Data Type      │ Primary Source  │ Fallback      │ Last Resort│
│  ───────────────┼─────────────────┼───────────────┼────────────│
│  BPM            │ Spotify API     │ Community     │ Audio      │
│                 │                 │ Corrections   │ Analysis   │
│  ───────────────┼─────────────────┼───────────────┼────────────│
│  Key            │ Spotify API     │ Community     │ Audio      │
│                 │                 │ Corrections   │ Analysis   │
│  ───────────────┼─────────────────┼───────────────┼────────────│
│  Duration       │ Spotify API     │ MusicBrainz   │ Community  │
│  ───────────────┼─────────────────┼───────────────┼────────────│
│  Album          │ Spotify API     │ MusicBrainz   │ Community  │
│  ───────────────┼─────────────────┼───────────────┼────────────│
│  ISRC           │ Spotify API     │ MusicBrainz   │ N/A        │
│  ───────────────┼─────────────────┼───────────────┼────────────│
│  Release Date   │ Spotify API     │ MusicBrainz   │ Community  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 6.3 Audio Analysis Integration

```dart
class AudioAnalysisService {
  /// Analyze audio file for BPM and key
  Future<AudioAnalysisResult> analyze(File audioFile) async {
    // Use librosa-based analysis (via Python backend or Flutter plugin)
    final bpm = await _detectBpm(audioFile);
    final key = await _detectKey(audioFile);
    final timeSignature = await _detectTimeSignature(audioFile);

    return AudioAnalysisResult(
      bpm: bpm,
      key: key,
      timeSignature: timeSignature,
      confidence: _calculateAnalysisConfidence(bpm, key),
    );
  }

  /// BPM Detection Algorithm
  ///
  /// Three-stage process:
  /// 1. Onset Detection: Identify sudden energy changes
  /// 2. Tempo Estimation: Find repeating patterns via autocorrelation
  /// 3. Beat Tracking: Refine to precise BPM
  Future<int> _detectBpm(File audioFile) async {
    // Analyze 60 seconds of audio
    // Return BPM rounded to 1 decimal place
    // Accuracy: ±1 BPM for most commercial music
  }

  /// Key Detection Algorithm
  ///
  /// Four-stage process:
  /// 1. Chroma Feature Extraction: 12-dimensional pitch class features
  /// 2. Temporal Averaging: Average across segment for stability
  /// 3. Key Profile Correlation: Compare to Krumhansl-Schmuckler profiles
  /// 4. Mode Selection: Select major/minor by correlation strength
  Future<String> _detectKey(File audioFile) async {
    // Analyze 120 seconds of audio
    // Return key signature (e.g., "C", "Am", "F#")
    // Accuracy: 85-95% for standard pop/rock/electronic
  }
}
```

### 6.4 Conflict Resolution

```dart
class ConflictResolutionService {
  /// Resolve conflicts between data sources
  Future<ResolvedData> resolve({
    required Song communityData,
    required SongData? apiData,
    required AudioAnalysisResult? audioData,
  }) async {
    final resolved = <String, dynamic>{};
    final sources = <String, DataSource>{};

    // BPM resolution
    if (apiData?.bpm != null && audioData?.bpm != null) {
      if ((apiData!.bpm - audioData!.bpm).abs() <= 2) {
        // Within tolerance: use API (more reliable)
        resolved['bpm'] = apiData.bpm;
        sources['bpm'] = DataSource.spotify;
      } else {
        // Conflict: use community if high confidence, else API
        if (communityData.confidenceScore > 0.8 &&
            (communityData.bpm - apiData.bpm).abs() <= 2) {
          resolved['bpm'] = communityData.bpm;
          sources['bpm'] = DataSource.community;
        } else {
          resolved['bpm'] = apiData.bpm;
          sources['bpm'] = DataSource.spotify;
        }
      }
    } else if (apiData?.bpm != null) {
      resolved['bpm'] = apiData!.bpm;
      sources['bpm'] = DataSource.spotify;
    } else if (audioData?.bpm != null) {
      resolved['bpm'] = audioData!.bpm;
      sources['bpm'] = DataSource.audioAnalysis;
    } else {
      resolved['bpm'] = communityData.bpm;
      sources['bpm'] = DataSource.community;
    }

    // Similar logic for key, duration, etc.

    return ResolvedData(data: resolved, sources: sources);
  }
}
```

---

## 7. Migration Plan

### 7.1 Phase 1: Infrastructure Setup (Weeks 1-2)

```dart
// Tasks:
// 1. Create new Firestore collections
// 2. Deploy security rules
// 3. Set up indexes
// 4. Create admin tools

class MigrationPhase1 {
  Future<void> execute() async {
    // Create community collections
    await _createCommunityCollections();

    // Deploy updated security rules
    await _deploySecurityRules();

    // Create indexes
    await _createIndexes();

    // Initialize system documents
    await _initializeBadges();
    await _initializeReputationLevels();
  }
}
```

### 7.2 Phase 2: Data Migration (Weeks 3-4)

```dart
class MigrationPhase2 {
  Future<void> execute() async {
    // Migrate existing songs to community format
    await _migratePersonalSongs();
    await _migrateBandSongs();

    // Add normalized fields
    await _addNormalizedFields();

    // Calculate initial confidence scores
    await _calculateConfidenceScores();

    // Create initial user profiles
    await _createCommunityUserProfiles();
  }

  Future<void> _migratePersonalSongs() async {
    final users = await firestore.collection('users').get();

    for (final userDoc in users.docs) {
      final userId = userDoc.id;
      final songs = await firestore
          .collection('users')
          .doc(userId)
          .collection('songs')
          .get();

      final batch = firestore.batch();

      for (final songDoc in songs.docs) {
        final songData = songDoc.data();

        // Create community song entry
        final communitySongRef = firestore
            .collection('community')
            .collection('songs')
            .doc();

        batch.set(communitySongRef, {
          ...songData,
          'createdBy': userId,
          'verificationStatus': 'unverified',
          'primarySource': 'community',
          'confidenceScore': 0.5,  // Initial low confidence
          'upvotes': 0,
          'downvotes': 0,
          'editCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    }
  }
}
```

### 7.3 Phase 3: Feature Rollout (Weeks 5-8)

```dart
class MigrationPhase3 {
  Future<void> execute() async {
    // Week 5-6: Beta testing with trusted users
    await _enableBetaFeatures();

    // Week 7: Reputation system activation
    await _activateReputationSystem();

    // Week 8: Full rollout
    await _fullRollout();
  }
}
```

### 7.4 Rollback Plan

```dart
class RollbackPlan {
  /// Rollback if critical issues found
  Future<void> rollback() async {
    // 1. Disable new community features
    await _disableCommunityFeatures();

    // 2. Revert to original data
    await _restoreOriginalData();

    // 3. Notify users
    await _notifyUsersOfRollback();
  }
}
```

---

## 8. Implementation Checklist

### 8.1 Database Schema
- [ ] Create CommunitySong collection
- [ ] Create CommunityUser collection
- [ ] Create Contribution collection
- [ ] Create Vote collection
- [ ] Create Report collection
- [ ] Create MergeRequest collection
- [ ] Create AuditLog collection
- [ ] Create Badge collection
- [ ] Set up Firestore indexes
- [ ] Deploy security rules

### 8.2 Reputation System
- [ ] Implement points calculation
- [ ] Implement level progression
- [ ] Implement badge system
- [ ] Create leaderboard service
- [ ] Implement permission checks

### 8.3 Quality Control
- [ ] Implement edit history tracking
- [ ] Implement revert mechanism
- [ ] Create moderation tools
- [ ] Implement auto-merge system
- [ ] Create manual review queue
- [ ] Implement strike system

### 8.4 API Integration
- [ ] Implement Spotify API integration
- [ ] Implement MusicBrainz API integration
- [ ] Implement audio analysis service
- [ ] Create conflict resolution logic
- [ ] Implement rate limiting
- [ ] Create caching layer

### 8.5 Migration
- [ ] Create migration scripts
- [ ] Test migration on staging
- [ ] Execute Phase 1 (infrastructure)
- [ ] Execute Phase 2 (data migration)
- [ ] Execute Phase 3 (feature rollout)
- [ ] Monitor and iterate

---

## 9. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Duplicate rate | < 2% | Songs with duplicate reports / total songs |
| Data accuracy | > 90% | Community corrections / total fields |
| User participation | > 30% | Active contributors / total users |
| Edit approval time | < 24 hours | Average time from submission to resolution |
| User satisfaction | > 4.0/5.0 | App store ratings, surveys |

---

## Appendix A: Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }

    function isCommunityUser() {
      return isAuthenticated() &&
        exists(/databases/$(database)/documents/community/users/$(request.auth.uid));
    }

    function getUserLevel() {
      let user = get(/databases/$(database)/documents/community/users/$(request.auth.uid)).data;
      return user != null ? user.level : 0;
    }

    function isTrustedEditor() {
      return getUserLevel() >= 3;  // trustedEditor = 3
    }

    function isModerator() {
      return getUserLevel() >= 5;  // moderator = 5
    }

    function isNotSuspended() {
      let user = get(/databases/$(database)/documents/community/users/$(request.auth.uid)).data;
      return user == null || user.suspensionUntil == null ||
        timestamp.fromString(user.suspensionUntil) < request.time;
    }

    // Community Songs
    match /community/songs/{songId} {
      allow read: if isAuthenticated();

      // Newcomers can add songs
      allow create: if isCommunityUser() && isNotSuspended();

      // Contributors can edit metadata
      allow update: if isCommunityUser() && isNotSuspended() && getUserLevel() >= 1;

      // Only moderators can delete
      allow delete: if isModerator();
    }

    // Community Users
    match /community/users/{userId} {
      allow read: if isAuthenticated();
      allow update: if isAuthenticated() && request.auth.uid == userId;
    }

    // Contributions
    match /community/contributions/{contributionId} {
      allow read: if isAuthenticated();
      allow create: if isCommunityUser() && isNotSuspended();
      allow update: if isModerator() ||
        (isAuthenticated() && request.auth.uid == resource.data.userId &&
         request.resource.data.status == 'pending');
    }

    // Votes
    match /community/votes/{voteId} {
      allow read: if isAuthenticated();
      allow create: if isCommunityUser() && isNotSuspended() && getUserLevel() >= 2;
    }

    // Reports
    match /community/reports/{reportId} {
      allow read: if isAuthenticated() &&
        (request.auth.uid == resource.data.reporterId || isModerator());
      allow create: if isCommunityUser() && isNotSuspended();
      allow update: if isModerator();
    }

    // Merge Requests
    match /community/mergeRequests/{mergeId} {
      allow read: if isAuthenticated();
      allow create: if isCommunityUser() && isNotSuspended() && getUserLevel() >= 4;
      allow update: if isModerator();
    }

    // System collections (badges, audit logs)
    match /system/{collection}/{docId} {
      allow read: if isAuthenticated();
      allow write: if false;  // Only server-side functions can write
    }
  }
}
```

---

## Appendix B: API Rate Limits

| API | Free Tier | Paid Tier | Notes |
|-----|-----------|-----------|-------|
| Spotify | 100 requests/day | 10,000 requests/day | Requires app registration |
| MusicBrainz | 1 request/second | 1 request/second | Strict rate limiting |
| Last.fm | 5 calls/second | 5 calls/second | More lenient |

**Recommendation**: Implement caching layer with 30-day TTL for API responses.

---

## Appendix C: Glossary

| Term | Definition |
|------|------------|
| **Auto-editor** | Trusted user whose edits are automatically approved |
| **Contribution** | Any user-submitted change to community data |
| **Edit war** | Repeated conflicting edits between users |
| **External ID** | Identifier from external service (Spotify ID, ISRC, etc.) |
| **Merge request** | Proposal to combine two duplicate songs |
| **Normalized field** | Standardized version of text for comparison |
| **Reputation level** | User's standing in the community |
| **Verification status** | Confidence level in song data accuracy |
