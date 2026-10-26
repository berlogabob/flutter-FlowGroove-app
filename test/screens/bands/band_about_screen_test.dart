import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/screens/bands/band_about_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mocks.dart';
import '../../helpers/routed_test_harness.dart';
import '../../helpers/test_helpers.dart';

Future<void> pumpAbout(
  WidgetTester tester, {
  String uid = 'array-admin',
  bool demo = false,
}) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final band = Band(
    id: 'band-123',
    name: 'Band 123',
    createdBy: 'array-admin',
    createdAt: DateTime(2024),
    members: [
      BandMember(
        uid: 'array-admin',
        displayName: 'Array Admin',
        role: 'member',
      ),
      BandMember(uid: 'role-admin', displayName: 'Role Admin', role: 'admin'),
      BandMember(uid: 'other-legacy-admin', role: 'admin'),
    ],
    adminUids: const ['array-admin'],
    editorUids: const [],
  );
  await pumpAppWidget(
    tester,
    // Route metadata can lag behind the live permissions stream.
    BandAboutScreen(band: band.copyWith(adminUids: const ['role-admin'])),
    overrides: [
      bandsProvider.overrideWith((ref) => Stream.value([band])),
      appUserProvider.overrideWith(
        () => TestAppUserNotifier(
          MockDataHelper.createMockAppUser(
            uid: uid,
          ).copyWith(accessRole: demo ? 'demo' : 'user'),
        ),
      ),
    ],
  );
  await tester.pumpAndSettle();
}

Future<void> openMember(WidgetTester tester, String name) async {
  await tester.ensureVisible(find.text(name));
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

void main() {
  for (final action in ['Editor role', 'Viewer role', 'Remove from band']) {
    testWidgets('sole live array admin is protected from $action', (
      tester,
    ) async {
      await pumpAbout(tester);
      await openMember(tester, 'Array Admin');
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Admin role'))
            .leading,
        isA<Icon>().having(
          (icon) => icon.icon,
          'selected',
          Icons.radio_button_checked,
        ),
      );
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      expect(
        find.text(
          action == 'Remove from band'
              ? 'You cannot remove the last admin.'
              : 'A band must keep at least one admin.',
        ),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsNothing);
    });
  }

  testWidgets('role-only admin can be removed by the array admin', (
    tester,
  ) async {
    await pumpAbout(tester);
    await openMember(tester, 'Role Admin');
    await tester.tap(find.text('Remove from band'));
    await tester.pumpAndSettle();
    expect(find.text('Remove member'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  for (final demo in [false, true]) {
    testWidgets(
      '${demo ? 'demo array' : 'role-only'} admin cannot manage members',
      (tester) async {
        await pumpAbout(
          tester,
          uid: demo ? 'array-admin' : 'role-admin',
          demo: demo,
        );
        expect(find.byIcon(Icons.more_vert), findsNothing);
        expect(
          tester
              .widget<ListTile>(find.widgetWithText(ListTile, 'Array Admin'))
              .onTap,
          isNull,
        );
      },
    );
  }
}
