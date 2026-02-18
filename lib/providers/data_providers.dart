import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../models/band.dart';
import '../models/setlist.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

final songsProvider = StateNotifierProvider<SongsNotifier, List<Song>>((ref) {
  return SongsNotifier(ref);
});

class SongsNotifier extends StateNotifier<List<Song>> {
  final Ref ref;
  bool _initialized = false;

  SongsNotifier(this.ref) : super([]) {
    _init();
  }

  void _init() {
    ref.listen(currentUserProvider, (previous, next) {
      if (next != null && !_initialized) {
        _initialized = true;
        _loadFromFirestore(next.uid);
      }
    }, fireImmediately: true);
  }

  void _loadFromFirestore(String uid) {
    final firestore = ref.read(firestoreServiceProvider);
    firestore.watchSongs(uid).listen((songs) {
      state = songs;
    });
  }

  Future<void> addSong(Song song) async {
    state = [...state, song];
    final user = ref.read(currentUserProvider);
    if (user != null) {
      await ref.read(firestoreServiceProvider).saveSong(song, user.uid);
    }
  }

  Future<void> updateSong(Song song) async {
    state = state.map((s) => s.id == song.id ? song : s).toList();
    final user = ref.read(currentUserProvider);
    if (user != null) {
      await ref.read(firestoreServiceProvider).saveSong(song, user.uid);
    }
  }

  Future<void> deleteSong(String id) async {
    state = state.where((s) => s.id != id).toList();
    final user = ref.read(currentUserProvider);
    if (user != null) {
      await ref.read(firestoreServiceProvider).deleteSong(id, user.uid);
    }
  }

  int get songCount => state.length;
}

final bandsProvider = StateNotifierProvider<BandsNotifier, List<Band>>((ref) {
  return BandsNotifier(ref);
});

class BandsNotifier extends StateNotifier<List<Band>> {
  final Ref ref;
  bool _initialized = false;

  BandsNotifier(this.ref) : super([]) {
    _init();
  }

  void _init() {
    ref.listen(currentUserProvider, (previous, next) {
      if (next != null && !_initialized) {
        _initialized = true;
        _loadFromFirestore(next.uid);
      }
    }, fireImmediately: true);
  }

  void _loadFromFirestore(String uid) {
    final firestore = ref.read(firestoreServiceProvider);
    firestore.watchBands(uid).listen((bands) {
      state = bands;
    });
  }

  Future<void> addBand(Band band) async {
    state = [...state, band];
    final user = ref.read(currentUserProvider);
    if (user != null) {
      await ref.read(firestoreServiceProvider).saveBand(band, user.uid);
    }
  }

  Future<void> updateBand(Band band) async {
    state = state.map((b) => b.id == band.id ? band : b).toList();
    final user = ref.read(currentUserProvider);
    if (user != null) {
      await ref.read(firestoreServiceProvider).saveBand(band, user.uid);
    }
  }

  Future<void> deleteBand(String id) async {
    state = state.where((b) => b.id != id).toList();
    final user = ref.read(currentUserProvider);
    if (user != null) {
      await ref.read(firestoreServiceProvider).deleteBand(id, user.uid);
    }
  }

  int get bandCount => state.length;
}

final setlistsProvider = StateNotifierProvider<SetlistsNotifier, List<Setlist>>(
  (ref) {
    return SetlistsNotifier(ref);
  },
);

class SetlistsNotifier extends StateNotifier<List<Setlist>> {
  final Ref ref;
  bool _initialized = false;

  SetlistsNotifier(this.ref) : super([]) {
    _init();
  }

  void _init() {
    ref.listen(currentUserProvider, (previous, next) {
      if (next != null && !_initialized) {
        _initialized = true;
        _loadFromFirestore(next.uid);
      }
    }, fireImmediately: true);
  }

  void _loadFromFirestore(String uid) {
    final firestore = ref.read(firestoreServiceProvider);
    firestore.watchSetlists(uid).listen((setlists) {
      state = setlists;
    });
  }

  Future<void> addSetlist(Setlist setlist) async {
    state = [...state, setlist];
    final user = ref.read(currentUserProvider);
    if (user != null) {
      await ref.read(firestoreServiceProvider).saveSetlist(setlist, user.uid);
    }
  }

  Future<void> updateSetlist(Setlist setlist) async {
    state = state.map((s) => s.id == setlist.id ? setlist : s).toList();
    final user = ref.read(currentUserProvider);
    if (user != null) {
      await ref.read(firestoreServiceProvider).saveSetlist(setlist, user.uid);
    }
  }

  Future<void> deleteSetlist(String id) async {
    state = state.where((s) => s.id != id).toList();
    final user = ref.read(currentUserProvider);
    if (user != null) {
      await ref.read(firestoreServiceProvider).deleteSetlist(id, user.uid);
    }
  }

  int get setlistCount => state.length;
}

final selectedBandProvider = StateProvider<Band?>((ref) => null);

final songCountProvider = Provider<int>((ref) {
  return ref.watch(songsProvider).length;
});

final bandCountProvider = Provider<int>((ref) {
  return ref.watch(bandsProvider).length;
});

final setlistCountProvider = Provider<int>((ref) {
  return ref.watch(setlistsProvider).length;
});
