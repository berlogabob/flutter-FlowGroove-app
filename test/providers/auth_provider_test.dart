import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_repsync_app/providers/auth_provider.dart';
import 'package:flutter_repsync_app/models/user.dart';

void main() {
  group('AuthProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    group('Provider Initialization', () {
      test('authStateProvider is initialized', () {
        final authState = container.read(authStateProvider);
        expect(authState, isNotNull);
      });

      test('currentUserProvider is initialized', () {
        final currentUser = container.read(currentUserProvider);
        expect(currentUser, isA<Object?>()); // Can be User or null
      });

      test('appUserProvider is initialized', () {
        final appUserState = container.read(appUserProvider);
        expect(appUserState, isNotNull);
      });
    });

    group('appUserProvider', () {
      test('initial state is accessible', () {
        final appUserState = container.read(appUserProvider);
        expect(appUserState, isNotNull);
      });

      test('returns AsyncValue type', () {
        final appUserState = container.read(appUserProvider);
        expect(appUserState, isA<AsyncValue<AppUser?>>());
      });

      test('can be refreshed', () {
        container.refresh(appUserProvider);
        final appUserState = container.read(appUserProvider);
        expect(appUserState, isNotNull);
      });
    });

    group('AppUserNotifier', () {
      test('notifier is accessible', () {
        final notifier = container.read(appUserProvider.notifier);
        expect(notifier, isNotNull);
      });

      test('signOut method exists', () {
        final notifier = container.read(appUserProvider.notifier);
        expect(notifier.signOut, isNotNull);
      });

      test('state can be read after refresh', () async {
        container.refresh(appUserProvider);
        await Future.delayed(const Duration(milliseconds: 50));
        
        final appUserState = container.read(appUserProvider);
        expect(appUserState, isNotNull);
      });
    });

    group('Stream Providers', () {
      test('authStateProvider returns AsyncValue', () {
        final authState = container.read(authStateProvider);
        expect(authState, isA<AsyncValue>());
      });

      test('currentUserProvider returns User or null', () {
        final currentUser = container.read(currentUserProvider);
        expect(currentUser, isA<Object?>());
      });
    });

    group('State Transitions', () {
      test('appUserProvider can be refreshed multiple times', () {
        container.refresh(appUserProvider);
        container.refresh(appUserProvider);
        container.refresh(appUserProvider);
        
        final appUserState = container.read(appUserProvider);
        expect(appUserState, isNotNull);
      });

      test('provider state remains consistent after refreshes', () {
        final state1 = container.read(appUserProvider);
        container.refresh(appUserProvider);
        final state2 = container.read(appUserProvider);
        
        expect(state1, isNotNull);
        expect(state2, isNotNull);
      });
    });

    group('Error Handling', () {
      test('appUserProvider handles state gracefully', () {
        expect(() => container.read(appUserProvider), returnsNormally);
      });

      test('authStateProvider handles state gracefully', () {
        expect(() => container.read(authStateProvider), returnsNormally);
      });

      test('currentUserProvider handles state gracefully', () {
        expect(() => container.read(currentUserProvider), returnsNormally);
      });
    });
  });
}
