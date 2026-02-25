import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/models/song.dart';
import 'package:flutter_repsync_app/models/band.dart';
import 'package:flutter_repsync_app/models/setlist.dart';
import 'package:flutter_repsync_app/repositories/repositories.dart';

/// Mock SongRepository for testing.
///
/// Provides in-memory storage for song operations,
/// enabling unit tests without Firebase dependencies.
class MockSongRepository implements SongRepository {
  final _songs = <String, Song>{};
  final _bandSongs = <String, Map<String, Song>>{};

  @override
  Future<void> saveSong(Song song, {String? uid}) async {
    _songs[song.id] = song;
  }

  @override
  Future<void> deleteSong(String songId, {String? uid}) async {
    _songs.remove(songId);
  }

  @override
  Future<void> updateSong(Song song, {String? uid}) async {
    if (!_songs.containsKey(song.id)) {
      throw Exception('Song not found');
    }
    _songs[song.id] = song;
  }

  @override
  Stream<List<Song>> watchSongs(String uid) {
    return Stream.value(_songs.values.toList());
  }

  @override
  Future<void> addSongToBand({
    required Song song,
    required String bandId,
    String? contributorId,
    String? contributorName,
  }) async {
    _bandSongs.putIfAbsent(bandId, () => {});
    _bandSongs[bandId]![song.id] = song;
  }

  @override
  Future<void> addSongToBandById(String songId, String bandId) async {
    final song = _songs[songId];
    if (song == null) {
      throw Exception('Song not found');
    }
    await addSongToBand(song: song, bandId: bandId);
  }

  @override
  Future<void> saveBandSong(Song song, String bandId) async {
    _bandSongs.putIfAbsent(bandId, () => {});
    _bandSongs[bandId]![song.id] = song;
  }

  @override
  Stream<List<Song>> watchBandSongs(String bandId) {
    final songs = _bandSongs[bandId]?.values.toList() ?? [];
    return Stream.value(songs);
  }

  @override
  Future<void> deleteBandSong(String bandId, String songId) async {
    _bandSongs[bandId]?.remove(songId);
  }

  @override
  Future<void> updateBandSong(Song song, String bandId) async {
    if (_bandSongs[bandId]?[song.id] == null) {
      throw Exception('Song not found in band');
    }
    _bandSongs[bandId]![song.id] = song;
  }

  /// Helper method to get songs for testing.
  List<Song> get songs => _songs.values.toList();

  /// Helper method to get band songs for testing.
  List<Song> getBandSongs(String bandId) =>
      _bandSongs[bandId]?.values.toList() ?? [];
}

/// Mock BandRepository for testing.
class MockBandRepository implements BandRepository {
  final _bands = <String, Band>{};
  final _userBands = <String, Set<String>>{};

  @override
  Future<void> saveBand(Band band, {String? uid}) async {
    _bands[band.id] = band;
    if (uid != null) {
      _userBands.putIfAbsent(uid, () => {});
      _userBands[uid]!.add(band.id);
    }
  }

  @override
  Future<void> deleteBand(String bandId, {String? uid}) async {
    _bands.remove(bandId);
    if (uid != null) {
      _userBands[uid]?.remove(bandId);
    }
  }

  @override
  Stream<List<Band>> watchBands(String uid) {
    final bandIds = _userBands[uid] ?? {};
    final bands = bandIds.map((id) => _bands[id]!).whereType<Band>().toList();
    return Stream.value(bands);
  }

  @override
  Future<void> saveBandToGlobal(Band band) async {
    _bands[band.id] = band;
  }

  @override
  Future<Band?> getBandByInviteCode(String code) async {
    try {
      return _bands.values.firstWhere(
        (band) => band.inviteCode == code,
      );
    } on StateError {
      return null;
    }
  }

  @override
  Future<bool> isInviteCodeTaken(String code) async {
    return _bands.values.any((band) => band.inviteCode == code);
  }

  @override
  Future<void> addUserToBand(String bandId, {String? userId}) async {
    if (userId == null) return;
    _userBands.putIfAbsent(userId, () => {});
    _userBands[userId]!.add(bandId);
  }

  @override
  Future<void> removeUserFromBand(String bandId, {String? userId}) async {
    if (userId == null) return;
    _userBands[userId]?.remove(bandId);
  }

  /// Helper method to get bands for testing.
  List<Band> get bands => _bands.values.toList();
}

/// Mock SetlistRepository for testing.
class MockSetlistRepository implements SetlistRepository {
  final _setlists = <String, Setlist>{};

  @override
  Future<void> saveSetlist(Setlist setlist, {String? uid}) async {
    _setlists[setlist.id] = setlist;
  }

  @override
  Future<void> deleteSetlist(String setlistId, {String? uid}) async {
    _setlists.remove(setlistId);
  }

  @override
  Stream<List<Setlist>> watchSetlists(String uid) {
    return Stream.value(_setlists.values.toList());
  }

  /// Helper method to get setlists for testing.
  List<Setlist> get setlists => _setlists.values.toList();
}
