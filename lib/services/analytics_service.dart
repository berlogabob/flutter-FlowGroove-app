// FlowGroove Analytics Service
// Centralized service for all Firebase Analytics tracking
//
// This service provides a type-safe, centralized interface for logging
// analytics events throughout the FlowGroove application.
//
// Usage:
//   await AnalyticsService.logBandCreated(bandName: 'My Band', memberCount: 1);
//   await AnalyticsService.setUserProperties(user: user);

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/song.dart';
import '../models/band.dart';
import '../models/setlist.dart';
import 'analytics_events.dart';

/// Centralized analytics service for FlowGroove
///
/// Provides type-safe methods for logging all analytics events.
/// All events are logged to Firebase Analytics with consistent parameter naming.
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static bool _debugMode = kDebugMode;

  /// Enable or disable debug mode (logs events to console)
  static void setDebugMode(bool enabled) {
    _debugMode = enabled;
    if (enabled) {
      debugPrint('📊 Analytics Debug Mode: ENABLED');
    }
  }

  /// Initialize analytics service
  static Future<void> initialize() async {
    try {
      // Enable analytics collection
      await _analytics.setAnalyticsCollectionEnabled(true);

      // Set session timeout for better session tracking
      // Note: setSessionTimeoutDuration is not supported on Web
      if (!kIsWeb) {
        await _analytics.setSessionTimeoutDuration(const Duration(minutes: 30));
      }

      if (_debugMode) {
        debugPrint('✅ Analytics Service initialized');
        if (!kIsWeb) {
          final appId = await _analytics.appInstanceId;
          debugPrint('📱 App Instance ID: $appId');
        } else {
          debugPrint('🌐 Web platform detected - using Google Analytics 4');
        }
      }
    } catch (e) {
      debugPrint('❌ Analytics Service initialization failed: $e');
      if (kDebugMode) rethrow;
    }
  }

  // ============================================================
  // AUTHENTICATION EVENTS
  // ============================================================

  /// Log user login
  static Future<void> logLogin({required String loginMethod}) async {
    try {
      await _analytics.logLogin(loginMethod: loginMethod);
      if (_debugMode) {
        debugPrint('📊 Event: login (method: $loginMethod)');
      }
    } catch (e) {
      _logError('logLogin', e);
    }
  }

  /// Log successful login
  static Future<void> logLoginSuccess({required String loginMethod}) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.loginSuccess,
        parameters: {'method': loginMethod},
      );
      if (_debugMode) {
        debugPrint('📊 Event: login_success (method: $loginMethod)');
      }
    } catch (e) {
      _logError('logLoginSuccess', e);
    }
  }

  /// Log user logout
  static Future<void> logLogout() async {
    try {
      await _analytics.logEvent(name: AnalyticsEvents.logout);
      if (_debugMode) {
        debugPrint('📊 Event: logout');
      }
    } catch (e) {
      _logError('logLogout', e);
    }
  }

  /// Log user signup
  static Future<void> logSignup({required String signupMethod}) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.signup,
        parameters: {'method': signupMethod},
      );
      if (_debugMode) {
        debugPrint('📊 Event: signup (method: $signupMethod)');
      }
    } catch (e) {
      _logError('logSignup', e);
    }
  }

  // ============================================================
  // BAND MANAGEMENT EVENTS
  // ============================================================

  /// Log band creation
  static Future<void> logBandCreated({
    required String bandId,
    required String bandName,
    required int memberCount,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.bandCreated,
        parameters: {
          AnalyticsParams.bandId: bandId,
          AnalyticsParams.bandName: bandName,
          AnalyticsParams.memberCount: memberCount,
        },
      );
      if (_debugMode) {
        debugPrint(
          '📊 Event: band_created (name: $bandName, members: $memberCount)',
        );
      }
    } catch (e) {
      _logError('logBandCreated', e);
    }
  }

  /// Log band creation from Band object
  static Future<void> logBandCreatedFromBand(Band band) async {
    await logBandCreated(
      bandId: band.id,
      bandName: band.name,
      memberCount: band.members.length,
    );
  }

  /// Log band joined via invite
  static Future<void> logBandJoined({
    required String bandId,
    required String bandName,
    required String inviteCode,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.bandJoined,
        parameters: {
          AnalyticsParams.bandId: bandId,
          AnalyticsParams.bandName: bandName,
          AnalyticsParams.inviteCode: inviteCode,
        },
      );
      if (_debugMode) {
        debugPrint('📊 Event: band_joined (name: $bandName)');
      }
    } catch (e) {
      _logError('logBandJoined', e);
    }
  }

  /// Log band left
  static Future<void> logBandLeft({
    required String bandId,
    required String bandName,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.bandLeft,
        parameters: {
          AnalyticsParams.bandId: bandId,
          AnalyticsParams.bandName: bandName,
        },
      );
      if (_debugMode) {
        debugPrint('📊 Event: band_left (name: $bandName)');
      }
    } catch (e) {
      _logError('logBandLeft', e);
    }
  }

  /// Log band deletion
  static Future<void> logBandDeleted({
    required String bandId,
    required String bandName,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.bandDeleted,
        parameters: {
          AnalyticsParams.bandId: bandId,
          AnalyticsParams.bandName: bandName,
        },
      );
      if (_debugMode) {
        debugPrint('📊 Event: band_deleted (name: $bandName)');
      }
    } catch (e) {
      _logError('logBandDeleted', e);
    }
  }

  /// Log band update
  static Future<void> logBandUpdated({
    required String bandId,
    required List<String> fieldsChanged,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.bandUpdated,
        parameters: {
          AnalyticsParams.bandId: bandId,
          AnalyticsParams.fieldsChanged: fieldsChanged.join(','),
        },
      );
      if (_debugMode) {
        debugPrint('📊 Event: band_updated (fields: ${fieldsChanged.join(', ')})');
      }
    } catch (e) {
      _logError('logBandUpdated', e);
    }
  }

  /// Log member invited
  static Future<void> logMemberInvited({
    required String bandId,
    required String memberRole,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.memberInvited,
        parameters: {
          AnalyticsParams.bandId: bandId,
          AnalyticsParams.memberRole: memberRole,
        },
      );
      if (_debugMode) {
        debugPrint('📊 Event: member_invited (role: $memberRole)');
      }
    } catch (e) {
      _logError('logMemberInvited', e);
    }
  }

  /// Log member joined
  static Future<void> logMemberJoined({
    required String bandId,
    required String memberRole,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.memberJoined,
        parameters: {
          AnalyticsParams.bandId: bandId,
          AnalyticsParams.memberRole: memberRole,
        },
      );
      if (_debugMode) {
        debugPrint('📊 Event: member_joined (role: $memberRole)');
      }
    } catch (e) {
      _logError('logMemberJoined', e);
    }
  }

  /// Log member removed
  static Future<void> logMemberRemoved({
    required String bandId,
    required String memberRole,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.memberRemoved,
        parameters: {
          AnalyticsParams.bandId: bandId,
          AnalyticsParams.memberRole: memberRole,
        },
      );
      if (_debugMode) {
        debugPrint('📊 Event: member_removed (role: $memberRole)');
      }
    } catch (e) {
      _logError('logMemberRemoved', e);
    }
  }

  // ============================================================
  // SONG MANAGEMENT EVENTS
  // ============================================================

  /// Log song added
  static Future<void> logSongAdded({
    required String songId,
    required String songTitle,
    required String artistName,
    required bool hasLyrics,
    required bool hasChords,
    int? bpm,
    String? timeSignature,
    String? bandId,
  }) async {
    try {
      final params = <String, Object>{
        AnalyticsParams.songId: songId,
        AnalyticsParams.songTitle: songTitle,
        AnalyticsParams.artistName: artistName,
        AnalyticsParams.hasLyrics: hasLyrics,
        AnalyticsParams.hasChords: hasChords,
      };

      if (bpm != null) params[AnalyticsParams.bpm] = bpm;
      if (timeSignature != null) {
        params[AnalyticsParams.timeSignature] = timeSignature;
      }
      if (bandId != null) params[AnalyticsParams.bandId] = bandId;

      await _analytics.logEvent(
        name: AnalyticsEvents.songAdded,
        parameters: params,
      );
      if (_debugMode) {
        debugPrint(
          '📊 Event: song_added (title: $songTitle, artist: $artistName)',
        );
      }
    } catch (e) {
      _logError('logSongAdded', e);
    }
  }

  /// Log song added from Song object
  static Future<void> logSongAddedFromSong(Song song) async {
    await logSongAdded(
      songId: song.id,
      songTitle: song.title,
      artistName: song.artist,
      hasLyrics: false, // Would need actual content check
      hasChords: false, // Would need actual content check
      bpm: song.originalBPM ?? song.ourBPM,
      timeSignature: '${song.accentBeats}/${song.regularBeats}',
      bandId: song.bandId,
    );
  }

  /// Log song edited
  static Future<void> logSongEdited({
    required String songId,
    required List<String> fieldsChanged,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.songEdited,
        parameters: {
          AnalyticsParams.songId: songId,
          AnalyticsParams.fieldsChanged: fieldsChanged.join(','),
        },
      );
      if (_debugMode) {
        debugPrint(
          '📊 Event: song_edited (id: $songId, fields: ${fieldsChanged.join(', ')})',
        );
      }
    } catch (e) {
      _logError('logSongEdited', e);
    }
  }

  /// Log song deleted
  static Future<void> logSongDeleted({
    required String songId,
    required String songTitle,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.songDeleted,
        parameters: {
          AnalyticsParams.songId: songId,
          AnalyticsParams.songTitle: songTitle,
        },
      );
      if (_debugMode) {
        debugPrint('📊 Event: song_deleted (title: $songTitle)');
      }
    } catch (e) {
      _logError('logSongDeleted', e);
    }
  }

  /// Log song shared
  static Future<void> logSongShared({
    required String songId,
    required String shareMethod,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.songShared,
        parameters: {
          AnalyticsParams.songId: songId,
          'share_method': shareMethod,
        },
      );
      if (_debugMode) {
        debugPrint('📊 Event: song_shared (method: $shareMethod)');
      }
    } catch (e) {
      _logError('logSongShared', e);
    }
  }

  /// Log song matched with external database
  static Future<void> logSongMatched({
    required String songId,
    required String matchSource,
    required bool isExactMatch,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.songMatched,
        parameters: {
          AnalyticsParams.songId: songId,
          'match_source': matchSource,
          'is_exact_match': isExactMatch,
        },
      );
      if (_debugMode) {
        debugPrint('📊 Event: song_matched (source: $matchSource)');
      }
    } catch (e) {
      _logError('logSongMatched', e);
    }
  }

  // ============================================================
  // SETLIST MANAGEMENT EVENTS
  // ============================================================

  /// Log setlist created
  static Future<void> logSetlistCreated({
    required String setlistId,
    required String setlistName,
    required String bandId,
    required int songCount,
    bool hasEventDate = false,
    bool hasLocation = false,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.setlistCreated,
        parameters: {
          AnalyticsParams.setlistId: setlistId,
          AnalyticsParams.setlistName: setlistName,
          AnalyticsParams.bandId: bandId,
          AnalyticsParams.songCount: songCount,
          AnalyticsParams.hasEventDate: hasEventDate,
          AnalyticsParams.hasLocation: hasLocation,
        },
      );
      if (_debugMode) {
        debugPrint('📊 Event: setlist_created (name: $setlistName)');
      }
    } catch (e) {
      _logError('logSetlistCreated', e);
    }
  }

  /// Log setlist created from Setlist object
  static Future<void> logSetlistCreatedFromSetlist(Setlist setlist) async {
    await logSetlistCreated(
      setlistId: setlist.id,
      setlistName: setlist.name,
      bandId: setlist.bandId,
      songCount: setlist.songIds.length,
      hasEventDate: setlist.eventDateTime != null,
      hasLocation: setlist.eventLocation != null,
    );
  }

  /// Log setlist edited
  static Future<void> logSetlistEdited({
    required String setlistId,
    required List<String> fieldsChanged,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.setlistEdited,
        parameters: {
          AnalyticsParams.setlistId: setlistId,
          AnalyticsParams.fieldsChanged: fieldsChanged.join(','),
        },
      );
      if (_debugMode) {
        debugPrint(
          '📊 Event: setlist_edited (fields: ${fieldsChanged.join(', ')})',
        );
      }
    } catch (e) {
      _logError('logSetlistEdited', e);
    }
  }

  /// Log setlist deleted
  static Future<void> logSetlistDeleted({
    required String setlistId,
    required String setlistName,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.setlistDeleted,
        parameters: {
          AnalyticsParams.setlistId: setlistId,
          AnalyticsParams.setlistName: setlistName,
        },
      );
      if (_debugMode) {
        debugPrint('📊 Event: setlist_deleted (name: $setlistName)');
      }
    } catch (e) {
      _logError('logSetlistDeleted', e);
    }
  }

  /// Log setlist exported
  static Future<void> logSetlistExported({
    required String setlistId,
    required String format,
    required int songCount,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.setlistExported,
        parameters: {
          AnalyticsParams.setlistId: setlistId,
          AnalyticsParams.exportFormat: format,
          AnalyticsParams.songCount: songCount,
        },
      );
      if (_debugMode) {
        debugPrint('📊 Event: setlist_exported (format: $format)');
      }
    } catch (e) {
      _logError('logSetlistExported', e);
    }
  }

  /// Log setlist shared
  static Future<void> logSetlistShared({
    required String setlistId,
    required String shareMethod,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.setlistShared,
        parameters: {
          AnalyticsParams.setlistId: setlistId,
          'share_method': shareMethod,
        },
      );
      if (_debugMode) {
        debugPrint('📊 Event: setlist_shared (method: $shareMethod)');
      }
    } catch (e) {
      _logError('logSetlistShared', e);
    }
  }

  // ============================================================
  // TOOLS USAGE EVENTS
  // ============================================================

  /// Log metronome started
  static Future<void> logMetronomeStarted({
    required int bpm,
    required String timeSignature,
    int subdivision = 1,
    String soundType = 'digital',
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.metronomeStarted,
        parameters: {
          AnalyticsParams.bpm: bpm,
          AnalyticsParams.timeSignature: timeSignature,
          AnalyticsParams.subdivision: subdivision,
          AnalyticsParams.soundType: soundType,
        },
      );
      if (_debugMode) {
        debugPrint(
          '📊 Event: metronome_started (bpm: $bpm, time: $timeSignature)',
        );
      }
    } catch (e) {
      _logError('logMetronomeStarted', e);
    }
  }

  /// Log metronome stopped
  static Future<void> logMetronomeStopped({
    required int durationSeconds,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.metronomeStopped,
        parameters: {'duration_seconds': durationSeconds},
      );
      if (_debugMode) {
        debugPrint('📊 Event: metronome_stopped (duration: ${durationSeconds}s)');
      }
    } catch (e) {
      _logError('logMetronomeStopped', e);
    }
  }

  /// Log tuner used
  static Future<void> logTunerUsed({
    required String mode,
    String? targetNote,
    String? detectedNote,
    int? cents,
  }) async {
    try {
      final params = <String, Object>{
        AnalyticsParams.mode: mode,
      };

      if (targetNote != null) params[AnalyticsParams.targetNote] = targetNote;
      if (detectedNote != null) {
        params[AnalyticsParams.detectedNote] = detectedNote;
      }
      if (cents != null) params[AnalyticsParams.cents] = cents;

      await _analytics.logEvent(
        name: AnalyticsEvents.tunerUsed,
        parameters: params,
      );
      if (_debugMode) {
        debugPrint('📊 Event: tuner_used (mode: $mode)');
      }
    } catch (e) {
      _logError('logTunerUsed', e);
    }
  }

  // ============================================================
  // NAVIGATION EVENTS
  // ============================================================

  /// Log screen view
  static Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
      if (_debugMode) {
        debugPrint('📊 Screen View: $screenName (${screenClass ?? 'unknown'})');
      }
    } catch (e) {
      _logError('logScreenView', e);
    }
  }

  /// Log app open
  static Future<void> logAppOpen() async {
    try {
      await _analytics.logAppOpen();
      if (_debugMode) {
        debugPrint('📊 Event: app_open');
      }
    } catch (e) {
      _logError('logAppOpen', e);
    }
  }

  // ============================================================
  // EXPORT EVENTS
  // ============================================================

  /// Log PDF export
  static Future<void> logPdfExported({
    required String itemType,
    required int itemCount,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.pdfExported,
        parameters: {
          'item_type': itemType,
          AnalyticsParams.itemCount: itemCount,
        },
      );
      if (_debugMode) {
        debugPrint('📊 Event: pdf_exported (type: $itemType, count: $itemCount)');
      }
    } catch (e) {
      _logError('logPdfExported', e);
    }
  }

  /// Log CSV export
  static Future<void> logCsvExported({
    required String itemType,
    required int itemCount,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.csvExported,
        parameters: {
          'item_type': itemType,
          AnalyticsParams.itemCount: itemCount,
        },
      );
      if (_debugMode) {
        debugPrint('📊 Event: csv_exported (type: $itemType, count: $itemCount)');
      }
    } catch (e) {
      _logError('logCsvExported', e);
    }
  }

  /// Log Spotify linked
  static Future<void> logSpotifyLinked() async {
    try {
      await _analytics.logEvent(name: AnalyticsEvents.spotifyLinked);
      if (_debugMode) {
        debugPrint('📊 Event: spotify_linked');
      }
    } catch (e) {
      _logError('logSpotifyLinked', e);
    }
  }

  // ============================================================
  // USER PROPERTIES
  // ============================================================

  /// Set user properties for segmentation
  static Future<void> setUserProperties({
    required AppUser user,
    int? bandCount,
    int? songCount,
    int? setlistCount,
  }) async {
    try {
      // Set user properties
      await _analytics.setUserProperty(
        name: AnalyticsUserProperties.role,
        value: 'musician',
      );

      if (bandCount != null) {
        await _analytics.setUserProperty(
          name: AnalyticsUserProperties.bandCount,
          value: bandCount.toString(),
        );
      }

      if (songCount != null) {
        await _analytics.setUserProperty(
          name: AnalyticsUserProperties.songCount,
          value: songCount.toString(),
        );
      }

      if (setlistCount != null) {
        await _analytics.setUserProperty(
          name: AnalyticsUserProperties.setlistCount,
          value: setlistCount.toString(),
        );
      }

      // Account age in days
      final accountAgeDays = DateTime.now().difference(user.createdAt).inDays;
      await _analytics.setUserProperty(
        name: AnalyticsUserProperties.accountAge,
        value: accountAgeDays.toString(),
      );

      // Has bands
      await _analytics.setUserProperty(
        name: AnalyticsUserProperties.hasBands,
        value: (user.bandIds.isNotEmpty).toString(),
      );

      if (_debugMode) {
        debugPrint(
          '📊 User Properties: bands=$bandCount, songs=$songCount, setlists=$setlistCount',
        );
      }
    } catch (e) {
      _logError('setUserProperties', e);
    }
  }

  /// Clear user properties (on logout)
  static Future<void> clearUserProperties() async {
    try {
      await _analytics.setUserProperty(
        name: AnalyticsUserProperties.role,
        value: null,
      );
      await _analytics.setUserProperty(
        name: AnalyticsUserProperties.bandCount,
        value: null,
      );
      await _analytics.setUserProperty(
        name: AnalyticsUserProperties.songCount,
        value: null,
      );
      await _analytics.setUserProperty(
        name: AnalyticsUserProperties.setlistCount,
        value: null,
      );

      if (_debugMode) {
        debugPrint('📊 User Properties cleared');
      }
    } catch (e) {
      _logError('clearUserProperties', e);
    }
  }

  // ============================================================
  // UTILITY METHODS
  // ============================================================

  /// Get app instance ID for debugging
  static Future<String?> getAppInstanceId() async {
    try {
      return await _analytics.appInstanceId;
    } catch (e) {
      _logError('getAppInstanceId', e);
      return null;
    }
  }

  /// Enable analytics collection
  static Future<void> setAnalyticsCollectionEnabled(
    bool enabled,
  ) async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(enabled);
      if (_debugMode) {
        debugPrint('📊 Analytics collection ${enabled ? 'enabled' : 'disabled'}');
      }
    } catch (e) {
      _logError('setAnalyticsCollectionEnabled', e);
    }
  }

  /// Log error helper
  static void _logError(String method, dynamic error) {
    debugPrint('❌ Analytics Error in $method: $error');
  }
}
