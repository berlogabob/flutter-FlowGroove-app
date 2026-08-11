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

import '../models/band.dart';
import '../models/setlist.dart';
import '../models/song.dart';
import '../models/user.dart';
import 'analytics_events.dart';

/// Centralized analytics service for FlowGroove
///
/// Provides type-safe methods for logging all analytics events.
/// All events are logged to Firebase Analytics with consistent parameter naming.
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final bool _debugMode = kDebugMode;

  /// Whether analytics events are allowed to leave the device. Wired from
  /// `analyticsConsentProvider` at startup and on toggle (mirrors how
  /// `keepScreenOnProvider` drives the wakelock). Defaults to true so
  /// behavior is unchanged until the provider's async load resolves.
  ///
  /// This flag is only the in-Dart half. The consent provider also calls
  /// [setAnalyticsCollectionEnabled], which is what actually stops the
  /// ungated legacy methods below *and* Firebase's automatic events
  /// (session_start, user_engagement) that no Dart-side flag can reach.
  static bool enabled = true;

  /// Test seam: counts every event that passed the [enabled] guard and
  /// reached (or attempted to reach) `FirebaseAnalytics`, regardless of
  /// whether the SDK call itself succeeds. Firebase isn't initialized in the
  /// unit test environment, so tests assert on this counter instead of
  /// mocking `FirebaseAnalytics.instance`.
  @visibleForTesting
  static int debugLogAttempts = 0;

  /// Test seam: the last value passed to [setAnalyticsCollectionEnabled].
  /// Firebase isn't initialized under unit test, so the SDK call itself is a
  /// no-op — tests assert on this instead.
  @visibleForTesting
  static bool? debugCollectionEnabled;

  /// Initialize analytics service
  static Future<void> initialize() async {
    try {
      // Honour stored consent, don't hard-enable. The consent provider's async
      // load races this; both paths write the same stored value, so whichever
      // lands last is still correct.
      await setAnalyticsCollectionEnabled(enabled);

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

  /// Log successful demo login.
  static Future<void> logDemoLogin() async {
    try {
      await _analytics.logLogin(loginMethod: 'demo');
      await _analytics.logEvent(
        name: 'login_demo',
        parameters: {'method': 'demo'},
      );
      if (_debugMode) {
        debugPrint('📊 Event: login_demo (method: demo)');
      }
    } catch (e) {
      _logError('logDemoLogin', e);
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
  /// Logged from the repository choke point, so only the id is available —
  /// the title was dropped rather than plumbed through every confirm dialog
  /// (unbounded free text is a wasted GA4 param anyway).
  static Future<void> logSongDeleted({required String songId}) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.songDeleted,
        parameters: {AnalyticsParams.songId: songId},
      );
      if (_debugMode) {
        debugPrint('📊 Event: song_deleted ($songId)');
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

  /// Log setlist deleted
  /// See [logSongDeleted] for why the name isn't carried.
  static Future<void> logSetlistDeleted({required String setlistId}) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEvents.setlistDeleted,
        parameters: {AnalyticsParams.setlistId: setlistId},
      );
      if (_debugMode) {
        debugPrint('📊 Event: setlist_deleted ($setlistId)');
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

  /// Log a tuner lifecycle event. Parameters must never contain audio data.
  static Future<void> logTunerEvent(
    String name, [
    Map<String, Object>? parameters,
  ]) async {
    const allowedEvents = <String>{
      AnalyticsEvents.tunerOpened,
      AnalyticsEvents.tunerPermissionPrompted,
      AnalyticsEvents.tunerPermissionGranted,
      AnalyticsEvents.tunerPermissionDenied,
      AnalyticsEvents.tunerListenStarted,
      AnalyticsEvents.tunerListenStopped,
      AnalyticsEvents.tunerToneStarted,
      AnalyticsEvents.tunerToneStopped,
      AnalyticsEvents.tunerInTuneReached,
      AnalyticsEvents.tunerPresetSelected,
      AnalyticsEvents.tunerPresetSaved,
      AnalyticsEvents.tunerSongPresetLinked,
    };
    if (!allowedEvents.contains(name)) {
      throw ArgumentError.value(name, 'name', 'Unknown tuner event');
    }
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
      if (_debugMode) debugPrint('📊 Event: $name');
    } catch (error) {
      _logError('logTunerEvent', error);
    }
  }

  // Navigation: `screen_view` comes from the router's FirebaseAnalyticsObserver
  // (see createAppRouter), not from anything in this file.

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
        debugPrint(
          '📊 Event: pdf_exported (type: $itemType, count: $itemCount)',
        );
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
        debugPrint(
          '📊 Event: csv_exported (type: $itemType, count: $itemCount)',
        );
      }
    } catch (e) {
      _logError('logCsvExported', e);
    }
  }

  // ============================================================
  // USER PROPERTIES
  // ============================================================

  /// Set user properties for segmentation.
  ///
  /// song_count / setlist_count were dropped: the caller only has the user
  /// doc, which carries no such totals, so both were always reported as 0.
  /// Counting them would cost two aggregate reads per sign-in for properties
  /// nothing segments on today.
  static Future<void> setUserProperties({
    required AppUser user,
    int? bandCount,
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

      // Account age in days
      final accountAgeDays = DateTime.now().difference(user.createdAt).inDays;
      await _analytics.setUserProperty(
        name: AnalyticsUserProperties.accountAge,
        value: accountAgeDays.toString(),
      );

      // Has bands
      await _analytics.setUserProperty(
        name: AnalyticsUserProperties.hasBands,
        value: user.bandIds.isNotEmpty.toString(),
      );

      if (_debugMode) {
        debugPrint('📊 User Properties: bands=$bandCount');
      }
    } catch (e) {
      _logError('setUserProperties', e);
    }
  }

  // ============================================================
  // HEART FRAMEWORK EVENTS (UX audit, 2026-07)
  // ============================================================
  //
  // The ~40 methods above predate this file's central choke point: each calls
  // `_analytics.logEvent` directly inside its own try/catch and so does not
  // check [enabled]. They are gated at the SDK level instead — the consent
  // provider calls [setAnalyticsCollectionEnabled], which drops everything,
  // including Firebase's automatic events. Every method below routes through
  // [_log] and is gated twice over.

  /// Central choke point for the HEART events below.
  static Future<void> _log(
    String name, [
    Map<String, Object>? parameters,
  ]) async {
    if (!enabled) return;
    debugLogAttempts++;
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
      if (_debugMode) {
        debugPrint(
          '📊 Event: $name${parameters != null ? ' $parameters' : ''}',
        );
      }
    } catch (e) {
      _logError(name, e);
    }
  }

  /// E: a Song Lab entry was created (#67). [type] is the LabEntryType name.
  static Future<void> logLabEntryAdded({required String type}) =>
      _log(AnalyticsEvents.labEntryAdded, {'type': type});

  /// T: back navigation used — the in-app Back button ('ui') or a system
  /// back gesture/button intercepted by a `PopScope` ('system').
  static Future<void> logBackUsed({required String source}) =>
      _log(AnalyticsEvents.backUsed, {'source': source});

  /// T: the app-wide `⋮` menu sheet was opened. [screen] is the sheet's title.
  static Future<void> logMenuOpened({required String screen}) =>
      _log(AnalyticsEvents.menuOpened, {'screen': screen});

  /// T: an undo-capable snackbar was shown for [action].
  static Future<void> logUndoShown({required String action}) =>
      _log(AnalyticsEvents.undoShown, {'action': action});

  /// T: the user tapped Undo on a snackbar shown for [action].
  static Future<void> logUndoUsed({required String action}) =>
      _log(AnalyticsEvents.undoUsed, {'action': action});

  /// T: a key or BPM filter on the songs list produced zero results.
  static Future<void> logFilterZeroResults({
    required String filterType,
    required String value,
  }) => _log(AnalyticsEvents.filterZeroResults, {
    'filter_type': filterType,
    'value': value,
  });

  /// T: a song card was opened while a search query was active.
  static Future<void> logSearchSongOpen() =>
      _log(AnalyticsEvents.searchSongOpen);

  /// A: a band invite (QR/code/link) was generated or shared.
  static Future<void> logInviteGenerated({required String bandId}) =>
      _log(AnalyticsEvents.inviteGenerated, {AnalyticsParams.bandId: bandId});

  /// A: an external invite link/App Link was opened (before join completes).
  static Future<void> logInviteLinkOpened() =>
      _log(AnalyticsEvents.inviteLinkOpened);

  /// A: a band screen was opened. Ponytail version of the audit's
  /// "first open after join" (`joined_band_opened`) — cheaply attributing
  /// "first" isn't available at this call site, so this fires on every open
  /// of `TheBandScreen`; see the report for detail.
  static Future<void> logBandOpened({required String bandId}) =>
      _log(AnalyticsEvents.bandOpened, {AnalyticsParams.bandId: bandId});

  /// E: a tool screen (metronome/tuner/practice) was opened.
  static Future<void> logToolOpened({required String tool}) =>
      _log(AnalyticsEvents.toolOpened, {'tool': tool});

  /// E: a metronome practice segment ran from start to stop/navigate.
  static Future<void> logPracticeSession({required int lengthMs}) =>
      _log(AnalyticsEvents.practiceSession, {'length_ms': lengthMs});

  /// R: a rehearsal proposal was created (not edits).
  static Future<void> logRehearsalCreated({required String bandId}) =>
      _log(AnalyticsEvents.rehearsalCreated, {AnalyticsParams.bandId: bandId});

  /// R: a setlist save completed. Ponytail version of the audit's "second
  /// member" attribution — that needs member context this call site doesn't
  /// cheaply have, so [isBand] (shared band setlist vs. personal) stands in
  /// for it; see the report. Reuses the `setlist_edited` event name already
  /// reserved by the legacy (currently uncalled) `logSetlistEdited` above —
  /// the two are never invoked from the same call site so there's no real
  /// collision, just a shared GA4 event name with a different param shape.
  static Future<void> logSetlistSaved({required bool isBand}) =>
      _log(AnalyticsEvents.setlistEdited, {'is_band': isBand});

  // ============================================================
  // UTILITY METHODS
  // ============================================================

  /// Enable analytics collection
  static Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    debugCollectionEnabled = enabled;
    try {
      await _analytics.setAnalyticsCollectionEnabled(enabled);
      if (_debugMode) {
        debugPrint(
          '📊 Analytics collection ${enabled ? 'enabled' : 'disabled'}',
        );
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
