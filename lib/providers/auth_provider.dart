import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

final appUserProvider =
    StateNotifierProvider<AppUserNotifier, AsyncValue<AppUser?>>((ref) {
      return AppUserNotifier(ref);
    });

class AppUserNotifier extends StateNotifier<AsyncValue<AppUser?>> {
  final Ref ref;

  AppUserNotifier(this.ref) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    ref.listen(authStateProvider, (previous, next) {
      next.whenData((user) {
        if (user != null) {
          String displayName = user.displayName ?? '';
          if (displayName.isEmpty && user.email != null) {
            displayName = user.email!.split('@').first;
          }
          state = AsyncValue.data(
            AppUser(
              uid: user.uid,
              email: user.email,
              displayName: displayName.isNotEmpty ? displayName : 'User',
              photoURL: user.photoURL,
              createdAt: DateTime.now(),
            ),
          );
        } else {
          state = const AsyncValue.data(null);
        }
      });
    }, fireImmediately: true);
  }

  Future<void> signOut() async {
    await ref.read(firebaseAuthProvider).signOut();
    state = const AsyncValue.data(null);
  }
}
