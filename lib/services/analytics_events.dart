// FlowGroove Analytics Events Definition
// Centralized event definitions for Firebase Analytics
// 
// This file defines all analytics events used in the FlowGroove app.
// Each event is strongly typed with required and optional parameters.

import '../models/song.dart';
import '../models/band.dart';
import '../models/setlist.dart';
import '../models/user.dart';

/// Analytics event names - single source of truth
class AnalyticsEvents {
  // Authentication
  static const String login = 'login';
  static const String loginSuccess = 'login_success';
  static const String logout = 'logout';
  static const String signup = 'signup';

  // Band Management
  static const String bandCreated = 'band_created';
  static const String bandJoined = 'band_joined';
  static const String bandLeft = 'band_left';
  static const String bandDeleted = 'band_deleted';
  static const String bandUpdated = 'band_updated';
  static const String memberInvited = 'member_invited';
  static const String memberJoined = 'member_joined';
  static const String memberRemoved = 'member_removed';

  // Song Management
  static const String songAdded = 'song_added';
  static const String songEdited = 'song_edited';
  static const String songDeleted = 'song_deleted';
  static const String songShared = 'song_shared';
  static const String songMatched = 'song_matched';

  // Setlist Management
  static const String setlistCreated = 'setlist_created';
  static const String setlistEdited = 'setlist_edited';
  static const String setlistDeleted = 'setlist_deleted';
  static const String setlistExported = 'setlist_exported';
  static const String setlistShared = 'setlist_shared';

  // Tools Usage
  static const String metronomeStarted = 'metronome_started';
  static const String metronomeStopped = 'metronome_stopped';
  static const String tunerUsed = 'tuner_used';

  // Navigation
  static const String screenView = 'screen_view';
  static const String appOpen = 'app_open';

  // Features
  static const String pdfExported = 'pdf_exported';
  static const String csvExported = 'csv_exported';
  static const String spotifyLinked = 'spotify_linked';
}

/// User property names
class AnalyticsUserProperties {
  static const String role = 'role';
  static const String bandCount = 'band_count';
  static const String songCount = 'song_count';
  static const String setlistCount = 'setlist_count';
  static const String accountAge = 'account_age_days';
  static const String hasSpotify = 'has_spotify_linked';
  static const String hasBands = 'has_bands';
  static const String hasSetlists = 'has_setlists';
}

/// Event parameter keys for consistency
class AnalyticsParams {
  // Common
  static const String timestamp = 'timestamp';
  static const String platform = 'platform';
  static const String appVersion = 'app_version';

  // Band
  static const String bandId = 'band_id';
  static const String bandName = 'band_name';
  static const String memberCount = 'member_count';
  static const String inviteCode = 'invite_code';
  static const String memberRole = 'member_role';

  // Song
  static const String songId = 'song_id';
  static const String songTitle = 'song_title';
  static const String artistName = 'artist_name';
  static const String hasLyrics = 'has_lyrics';
  static const String hasChords = 'has_chords';
  static const String bpm = 'bpm';
  static const String timeSignature = 'time_signature';
  static const String fieldsChanged = 'fields_changed';
  static const String isCopy = 'is_copy';
  static const String originalSongId = 'original_song_id';

  // Setlist
  static const String setlistId = 'setlist_id';
  static const String setlistName = 'setlist_name';
  static const String songCount = 'song_count';
  static const String exportFormat = 'export_format';
  static const String hasEventDate = 'has_event_date';
  static const String hasLocation = 'has_location';
  static const String participantCount = 'participant_count';

  // Metronome
  static const String subdivision = 'subdivision';
  static const String soundType = 'sound_type';
  static const String volume = 'volume';

  // Tuner
  static const String mode = 'mode';
  static const String targetNote = 'target_note';
  static const String detectedNote = 'detected_note';
  static const String cents = 'cents';

  // Screen
  static const String screenName = 'screen_name';
  static const String screenClass = 'screen_class';

  // Export
  static const String format = 'format';
  static const String itemCount = 'item_count';

  // User
  static const String userId = 'user_id';
  static const String email = 'email';
  static const String createdAt = 'created_at';
}

/// Type-safe analytics event data
abstract class AnalyticsEventData {
  final String eventName;
  final Map<String, Object> parameters;

  const AnalyticsEventData({
    required this.eventName,
    required this.parameters,
  });

  Map<String, Object> toParameters() => parameters;
}

// Authentication Events
class LoginEventData extends AnalyticsEventData {
  LoginEventData({required String loginMethod})
      : super(
          eventName: AnalyticsEvents.login,
          parameters: {'method': loginMethod},
        );
}

class LoginSuccessEventData extends AnalyticsEventData {
  LoginSuccessEventData({required String loginMethod})
      : super(
          eventName: AnalyticsEvents.loginSuccess,
          parameters: {'method': loginMethod},
        );
}

// Band Events
class BandCreatedEventData extends AnalyticsEventData {
  BandCreatedEventData({
    required String bandId,
    required String bandName,
    required int memberCount,
  }) : super(
          eventName: AnalyticsEvents.bandCreated,
          parameters: {
            AnalyticsParams.bandId: bandId,
            AnalyticsParams.bandName: bandName,
            AnalyticsParams.memberCount: memberCount,
          },
        );

  factory BandCreatedEventData.fromBand(Band band) {
    return BandCreatedEventData(
      bandId: band.id,
      bandName: band.name,
      memberCount: band.members.length,
    );
  }
}

class BandJoinedEventData extends AnalyticsEventData {
  BandJoinedEventData({
    required String bandId,
    required String bandName,
    required String inviteCode,
  }) : super(
          eventName: AnalyticsEvents.bandJoined,
          parameters: {
            AnalyticsParams.bandId: bandId,
            AnalyticsParams.bandName: bandName,
            AnalyticsParams.inviteCode: inviteCode,
          },
        );
}

class BandDeletedEventData extends AnalyticsEventData {
  BandDeletedEventData({
    required String bandId,
    required String bandName,
  }) : super(
          eventName: AnalyticsEvents.bandDeleted,
          parameters: {
            AnalyticsParams.bandId: bandId,
            AnalyticsParams.bandName: bandName,
          },
        );
}

class MemberInvitedEventData extends AnalyticsEventData {
  MemberInvitedEventData({
    required String bandId,
    required String memberRole,
  }) : super(
          eventName: AnalyticsEvents.memberInvited,
          parameters: {
            AnalyticsParams.bandId: bandId,
            AnalyticsParams.memberRole: memberRole,
          },
        );
}

// Song Events
class SongAddedEventData extends AnalyticsEventData {
  SongAddedEventData({
    required String songId,
    required String songTitle,
    required String artistName,
    required bool hasLyrics,
    required bool hasChords,
    int? bpm,
    String? timeSignature,
    String? bandId,
  }) : super(
          eventName: AnalyticsEvents.songAdded,
          parameters: {
            AnalyticsParams.songId: songId,
            AnalyticsParams.songTitle: songTitle,
            AnalyticsParams.artistName: artistName,
            AnalyticsParams.hasLyrics: hasLyrics,
            AnalyticsParams.hasChords: hasChords,
            if (bpm != null) AnalyticsParams.bpm: bpm,
            if (timeSignature != null)
              AnalyticsParams.timeSignature: timeSignature,
            if (bandId != null) AnalyticsParams.bandId: bandId,
          },
        );

  factory SongAddedEventData.fromSong(Song song) {
    return SongAddedEventData(
      songId: song.id,
      songTitle: song.title,
      artistName: song.artist,
      hasLyrics: false, // Would need to check actual content
      hasChords: false, // Would need to check actual content
      bpm: song.originalBPM ?? song.ourBPM,
      timeSignature: '${song.accentBeats}/${song.regularBeats}',
      bandId: song.bandId,
    );
  }
}

class SongEditedEventData extends AnalyticsEventData {
  SongEditedEventData({
    required String songId,
    required List<String> fieldsChanged,
  }) : super(
          eventName: AnalyticsEvents.songEdited,
          parameters: {
            AnalyticsParams.songId: songId,
            AnalyticsParams.fieldsChanged: fieldsChanged.join(','),
          },
        );
}

class SongDeletedEventData extends AnalyticsEventData {
  SongDeletedEventData({
    required String songId,
    required String songTitle,
  }) : super(
          eventName: AnalyticsEvents.songDeleted,
          parameters: {
            AnalyticsParams.songId: songId,
            AnalyticsParams.songTitle: songTitle,
          },
        );
}

// Setlist Events
class SetlistCreatedEventData extends AnalyticsEventData {
  SetlistCreatedEventData({
    required String setlistId,
    required String setlistName,
    required String bandId,
    required int songCount,
    bool hasEventDate = false,
    bool hasLocation = false,
  }) : super(
          eventName: AnalyticsEvents.setlistCreated,
          parameters: {
            AnalyticsParams.setlistId: setlistId,
            AnalyticsParams.setlistName: setlistName,
            AnalyticsParams.bandId: bandId,
            AnalyticsParams.songCount: songCount,
            AnalyticsParams.hasEventDate: hasEventDate,
            AnalyticsParams.hasLocation: hasLocation,
          },
        );

  factory SetlistCreatedEventData.fromSetlist(Setlist setlist) {
    return SetlistCreatedEventData(
      setlistId: setlist.id,
      setlistName: setlist.name,
      bandId: setlist.bandId,
      songCount: setlist.songIds.length,
      hasEventDate: setlist.eventDateTime != null,
      hasLocation: setlist.eventLocation != null,
    );
  }
}

class SetlistExportedEventData extends AnalyticsEventData {
  SetlistExportedEventData({
    required String setlistId,
    required String format,
    required int songCount,
  }) : super(
          eventName: AnalyticsEvents.setlistExported,
          parameters: {
            AnalyticsParams.setlistId: setlistId,
            AnalyticsParams.exportFormat: format,
            AnalyticsParams.songCount: songCount,
          },
        );
}

// Metronome Events
class MetronomeStartedEventData extends AnalyticsEventData {
  MetronomeStartedEventData({
    required int bpm,
    required String timeSignature,
    int subdivision = 1,
    String soundType = 'digital',
  }) : super(
          eventName: AnalyticsEvents.metronomeStarted,
          parameters: {
            AnalyticsParams.bpm: bpm,
            AnalyticsParams.timeSignature: timeSignature,
            AnalyticsParams.subdivision: subdivision,
            AnalyticsParams.soundType: soundType,
          },
        );
}

// Tuner Events
class TunerUsedEventData extends AnalyticsEventData {
  TunerUsedEventData({
    required String mode,
    String? targetNote,
    String? detectedNote,
    int? cents,
  }) : super(
          eventName: AnalyticsEvents.tunerUsed,
          parameters: {
            AnalyticsParams.mode: mode,
            if (targetNote != null) AnalyticsParams.targetNote: targetNote,
            if (detectedNote != null)
              AnalyticsParams.detectedNote: detectedNote,
            if (cents != null) AnalyticsParams.cents: cents,
          },
        );
}

// Screen View Events
class ScreenViewEventData extends AnalyticsEventData {
  ScreenViewEventData({
    required String screenName,
    String? screenClass,
  }) : super(
          eventName: AnalyticsEvents.screenView,
          parameters: {
            AnalyticsParams.screenName: screenName,
            AnalyticsParams.screenClass: screenClass ?? screenName,
          },
        );
}
