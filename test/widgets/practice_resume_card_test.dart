import 'package:flowgroove/services/last_practice_context.dart';
import 'package:flowgroove/widgets/practice_resume_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/metronome_test_runtime.dart';

void main() {
  testWidgets('absent context hides the card', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lastPracticeContextProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(home: Scaffold(body: PracticeResumeCard())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNothing);
    expect(find.text('Continue'), findsNothing);
  });

  for (final bandId in [null, 'band-1']) {
    testWidgets('resume opens song with band $bandId and no playback', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final runtime = MetronomeTestRuntime();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: PracticeResumeCard()),
          ),
          GoRoute(
            path: '/song/:id',
            name: 'song',
            builder: (_, state) => Scaffold(
              body: Text(
                'Song ${state.pathParameters['id']} band ${state.uri.queryParameters['bandId']}',
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...runtime.overrides,
            lastPracticeContextProvider.overrideWith(
              (ref) async => LastPracticeContext(
                songId: 'song-1',
                bandId: bandId,
                title: 'Blue',
                bpm: 120,
                updatedAt: DateTime(2026),
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Blue · 120 BPM'), findsOneWidget);
      expect(find.bySemanticsLabel('Continue Blue · 120 BPM'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Song song-1 band $bandId'), findsOneWidget);
      expect(runtime.playback.startCalls, 0);
      expect(runtime.audio.playClickCalls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      await runtime.dispose();
      semantics.dispose();
    });
  }
}
