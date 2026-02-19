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
  return ref.watch(authStateProvider).value;
});

final appUserProvider = NotifierProvider<AppUserNotifier, AsyncValue<AppUser?>>(
  () {
    return AppUserNotifier();
  },
);

class AppUserNotifier extends Notifier<AsyncValue<AppUser?>> {
  @override
  AsyncValue<AppUser?> build() {
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
    return const AsyncValue.loading();
  }

  Future<void> signOut() async {
    await ref.read(firebaseAuthProvider).signOut();
    state = const AsyncValue.data(null);
  }
}
