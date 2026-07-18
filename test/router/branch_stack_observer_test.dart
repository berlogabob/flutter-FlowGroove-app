import 'dart:async';

import 'package:flowgroove/router/branch_stack_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A single-branch navigator wired with [obs], mirroring how a shell branch
/// navigator is observed. `key` lets us dispose + remount the SAME navigator
/// state (or a fresh one) to reproduce the logout→login teardown.
Widget _app(BranchStackObserver obs, GlobalKey<NavigatorState> navKey) =>
    MaterialApp(
      home: Navigator(
        key: navKey,
        observers: [obs],
        onGenerateRoute: (_) =>
            MaterialPageRoute<void>(builder: (_) => const SizedBox()),
      ),
    );

void main() {
  group('BranchStackObserver', () {
    setUp(BranchStackObserver.reset);

    testWidgets('root = depth 0, pushed child = depth 1, pop = depth 0', (
      tester,
    ) async {
      final obs = BranchStackObserver(0);
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(_app(obs, navKey));
      await tester.pumpAndSettle();
      expect(BranchStackObserver.depths.value[0], 0);

      unawaited(
        navKey.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const SizedBox()),
        ),
      );
      await tester.pumpAndSettle();
      expect(BranchStackObserver.depths.value[0], 1);

      navKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(BranchStackObserver.depths.value[0], 0);
    });

    testWidgets(
      'a re-mounted branch navigator heals a leaked count (logout→login)',
      (tester) async {
        // Same observer instance reused across mounts, like the singleton that
        // lives for the whole process.
        final obs = BranchStackObserver(0);

        await tester.pumpWidget(_app(obs, GlobalKey<NavigatorState>()));
        await tester.pumpAndSettle();
        expect(BranchStackObserver.depths.value[0], 0);

        // Logout: the navigator is disposed. Flutter does NOT fire didPop on
        // observers during teardown, so the count leaks (stays 1).
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();

        // Login: a fresh branch navigator mounts and re-pushes its root.
        await tester.pumpWidget(_app(obs, GlobalKey<NavigatorState>()));
        await tester.pumpAndSettle();
        expect(
          BranchStackObserver.depths.value[0],
          0,
          reason: 'leaked count must reset when the branch root re-mounts',
        );
      },
    );
  });
}
