// Analytics Service Unit Tests
// Tests for the centralized analytics service

import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/services/analytics_events.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnalyticsService', () {
    group('Event Data Classes', () {
      test('BandCreatedEventData creates correct event', () {
        final band = Band(
          id: 'test-band',
          name: 'Test Band',
          createdBy: 'user-123',
          createdAt: DateTime.now(),
          members: [
            BandMember(
              uid: 'user-123',
              role: BandMember.roleAdmin,
              displayName: 'Test User',
            ),
          ],
        );

        final eventData = BandCreatedEventData.fromBand(band);

        expect(eventData.eventName, AnalyticsEvents.bandCreated);
        expect(eventData.parameters['band_id'], equals('test-band'));
        expect(eventData.parameters['band_name'], equals('Test Band'));
        expect(eventData.parameters['member_count'], equals(1));
      });

      test('SongAddedEventData creates correct event', () {
        final song = Song(
          id: 'test-song',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          originalBPM: 120,
        );

        final eventData = SongAddedEventData.fromSong(song);

        expect(eventData.eventName, AnalyticsEvents.songAdded);
        expect(eventData.parameters['song_id'], equals('test-song'));
        expect(eventData.parameters['song_title'], equals('Test Song'));
        expect(eventData.parameters['artist_name'], equals('Test Artist'));
      });

      test('SetlistCreatedEventData creates correct event', () {
        final setlist = Setlist(
          id: 'test-setlist',
          bandId: 'test-band',
          name: 'Test Setlist',
          songIds: ['song1', 'song2', 'song3'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final eventData = SetlistCreatedEventData.fromSetlist(setlist);

        expect(eventData.eventName, AnalyticsEvents.setlistCreated);
        expect(eventData.parameters['setlist_id'], equals('test-setlist'));
        expect(eventData.parameters['setlist_name'], equals('Test Setlist'));
        expect(eventData.parameters['band_id'], equals('test-band'));
        expect(eventData.parameters['song_count'], equals(3));
        expect(eventData.parameters['has_event_date'], isFalse);
      });
    });

    group('Analytics Constants', () {
      test('AnalyticsEvents has all required event names', () {
        // Authentication
        expect(AnalyticsEvents.login, equals('login'));
        expect(AnalyticsEvents.loginSuccess, equals('login_success'));
        expect(AnalyticsEvents.logout, equals('logout'));

        // Band management
        expect(AnalyticsEvents.bandCreated, equals('band_created'));
        expect(AnalyticsEvents.bandJoined, equals('band_joined'));
        expect(AnalyticsEvents.bandDeleted, equals('band_deleted'));

        // Song management
        expect(AnalyticsEvents.songAdded, equals('song_added'));
        expect(AnalyticsEvents.songEdited, equals('song_edited'));
        expect(AnalyticsEvents.songDeleted, equals('song_deleted'));

        // Setlist management
        expect(AnalyticsEvents.setlistCreated, equals('setlist_created'));
        expect(AnalyticsEvents.setlistExported, equals('setlist_exported'));

        // Tools
        expect(AnalyticsEvents.metronomeStarted, equals('metronome_started'));
        expect(AnalyticsEvents.tunerUsed, equals('tuner_used'));
      });

      test('AnalyticsUserProperties has all required properties', () {
        expect(AnalyticsUserProperties.role, equals('role'));
        expect(AnalyticsUserProperties.bandCount, equals('band_count'));
        expect(AnalyticsUserProperties.songCount, equals('song_count'));
        expect(AnalyticsUserProperties.setlistCount, equals('setlist_count'));
        expect(AnalyticsUserProperties.accountAge, equals('account_age_days'));
      });

      test('AnalyticsParams has all required parameter names', () {
        expect(AnalyticsParams.bandId, equals('band_id'));
        expect(AnalyticsParams.bandName, equals('band_name'));
        expect(AnalyticsParams.songId, equals('song_id'));
        expect(AnalyticsParams.songTitle, equals('song_title'));
        expect(AnalyticsParams.setlistId, equals('setlist_id'));
        expect(AnalyticsParams.bpm, equals('bpm'));
        expect(AnalyticsParams.timeSignature, equals('time_signature'));
      });
    });
  });
}
