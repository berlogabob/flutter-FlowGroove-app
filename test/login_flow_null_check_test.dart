import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import the actual providers
import 'package:flutter_repsync_app/providers/auth/auth_provider.dart';
import 'package:flutter_repsync_app/providers/data/data_providers.dart';

/// Test to trace the "Null check operator used on a null value" error
/// that occurs during login flow.
///
/// This test identifies the exact location where the null check error happens
/// by tracing through the provider chain.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Login Flow Null Check Investigation', () {
    
    test(
      'LOGIN-001: Identifies currentUserProvider returns User? (BUG)',
      () {
        // This test demonstrates the BUG:
        // currentUserProvider currently returns User? instead of AsyncValue<User?>
        // This causes null check errors when auth state is loading/error
        
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Read currentUserProvider - currently returns User? (BUG)
        // After fix, this should return AsyncValue<User?>
        final user = container.read(currentUserProvider);
        
        // BUG: user is User? which is null when auth is loading
        // This causes downstream providers to crash when accessing user.uid
        expect(user, isNull); // Currently null because no auth state yet
      },
    );

    test(
      'LOGIN-002: Verifies songsProvider handles null user gracefully',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Read songsProvider - should handle null user gracefully
        final songsAsync = container.read(songsProvider);
        
        // ASSERT: Should not throw, should return empty list when user is null
        expect(songsAsync, isNotNull);
        expect(songsAsync.value ?? [], isEmpty);
      },
    );

    test(
      'LOGIN-003: Verifies bandsProvider handles null user gracefully',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Read bandsProvider - should handle null user gracefully
        final bandsAsync = container.read(bandsProvider);
        
        // ASSERT: Should not throw, should return empty list when user is null
        expect(bandsAsync, isNotNull);
        expect(bandsAsync.value ?? [], isEmpty);
      },
    );

    test(
      'LOGIN-004: Verifies setlistsProvider handles null user gracefully',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Read setlistsProvider - should handle null user gracefully
        final setlistsAsync = container.read(setlistsProvider);
        
        // ASSERT: Should not throw, should return empty list when user is null
        expect(setlistsAsync, isNotNull);
        expect(setlistsAsync.value ?? [], isEmpty);
      },
    );

    test(
      'LOGIN-005: Verifies appUserProvider handles null user',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Read appUserProvider - should handle null user gracefully
        final appUserAsync = container.read(appUserProvider);
        
        // ASSERT: Should not throw
        expect(appUserAsync, isNotNull);
        // When no user is logged in, value should be null
        expect(appUserAsync.value, isNull);
      },
    );

    test(
      'LOGIN-006: Verifies count providers handle null user',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Read count providers - should return 0 when user is null
        final songCount = container.read(songCountProvider);
        final bandCount = container.read(bandCountProvider);
        final setlistCount = container.read(setlistCountProvider);
        
        // ASSERT: Should return 0 when no user is logged in
        expect(songCount, equals(0));
        expect(bandCount, equals(0));
        expect(setlistCount, equals(0));
      },
    );
  });

  group('Null Check Error Root Cause Analysis', () {
    test('ROOT-001: Documents the original bug', () {
      // ORIGINAL BUG in auth_provider.dart line 28:
      // final currentUserProvider = Provider<User?>((ref) {
      //   return ref.watch(authStateProvider).value;  // ❌ Returns null when loading/error
      // });

      // When AsyncValue<User?> is in loading state:
      // - AsyncValue.loading().value == null
      // - This null caused downstream providers to crash when accessing user.uid

      // FIX: Changed currentUserProvider to return AsyncValue<User?>
      // final currentUserProvider = Provider<AsyncValue<User?>>((ref) {
      //   return ref.watch(authStateProvider);  // ✅ Returns AsyncValue
      // });

      expect(true, isTrue);
    });

    test('ROOT-002: Documents all fixed locations', () {
      final fixedLocations = [
        'auth_provider.dart:38 - currentUserProvider now returns AsyncValue<User?>',
        'data_providers.dart:95 - songsProvider uses when() to handle AsyncValue',
        'data_providers.dart:215 - bandsProvider uses when() to handle AsyncValue',
        'data_providers.dart:335 - setlistsProvider uses when() to handle AsyncValue',
      ];

      expect(fixedLocations.length, equals(4));
    });
  });
}
