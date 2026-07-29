import 'dart:async';

import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Band band(String id, String name) => Band(
    id: id,
    name: name,
    createdBy: 'u1',
    createdAt: DateTime(2024),
  );

  Future<void> pump(
    WidgetTester tester, {
    required Stream<List<Band>> bands,
    Band? extra,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [bandsProvider.overrideWith((ref) => bands)],
        child: MaterialApp(
          home: BandRouteResolver(
            bandId: 'b1',
            extra: extra,
            builder: (b) => Text(b.name),
          ),
        ),
      ),
    );
  }

  testWidgets('prefers the live band over the navigation snapshot', (
    tester,
  ) async {
    await pump(
      tester,
      bands: Stream.value([band('b1', 'Live Name')]),
      extra: band('b1', 'Snapshot Name'),
    );
    await tester.pump(); // let the stream emit

    expect(find.text('Live Name'), findsOneWidget);
    expect(find.text('Snapshot Name'), findsNothing);
  });

  testWidgets('falls back to the snapshot while the stream is loading', (
    tester,
  ) async {
    // A stream that never emits keeps the provider in the loading state.
    await pump(
      tester,
      bands: Stream<List<Band>>.fromFuture(Completer<List<Band>>().future),
      extra: band('b1', 'Snapshot Name'),
    );
    await tester.pump();

    expect(find.text('Snapshot Name'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows error when band not found and no snapshot', (tester) async {
    await pump(tester, bands: Stream.value([band('other', 'Other')]));
    await tester.pump();

    expect(find.text('Failed to load band data'), findsOneWidget);
  });
}
