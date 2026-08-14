import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/user.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/permissions_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/routed_test_harness.dart';

/// The band gates must read the derived `adminUids`/`editorUids` arrays —
/// exactly what Firestore rules enforce — never `members[].role`, which can
/// drift on legacy docs. Regression for "editor can't edit band songs".
void main() {
  AppUser user({String role = 'member'}) => AppUser(
    uid: 'u1',
    email: 'u1@example.com',
    accessRole: role,
    createdAt: DateTime(2024),
  );

  ProviderContainer container({
    required List<Band> bands,
    String accessRole = 'member',
  }) {
    final c = ProviderContainer(
      overrides: [
        appUserProvider.overrideWith(
          () => TestAppUserNotifier(user(role: accessRole)),
        ),
        bandsProvider.overrideWith((ref) => Stream.value(bands)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle(ProviderContainer c) async {
    // Let the bands stream emit.
    c.listen(bandsProvider, (_, _) {});
    await c.read(bandsProvider.future);
  }

  Band band({
    List<String> adminUids = const [],
    List<String> editorUids = const [],
    List<BandMember> members = const [],
  }) => Band(
    id: 'b1',
    name: 'Band',
    createdBy: 'owner',
    createdAt: DateTime(2024),
    members: members,
    memberUids: const ['u1'],
    adminUids: adminUids,
    editorUids: editorUids,
  );

  test('editor via arrays can edit even when members[].role is stale', () async {
    // The drift case: doc says viewer, arrays (= server truth) say editor.
    final c = container(
      bands: [
        band(
          editorUids: const ['u1'],
          members: [BandMember(uid: 'u1', role: BandMember.roleViewer)],
        ),
      ],
    );
    await settle(c);

    expect(c.read(canEditBandProvider('b1')), isTrue);
    expect(c.read(isBandAdminProvider('b1')), isFalse);
  });

  test('admin via arrays gets both gates', () async {
    final c = container(bands: [band(adminUids: const ['u1'])]);
    await settle(c);

    expect(c.read(canEditBandProvider('b1')), isTrue);
    expect(c.read(isBandAdminProvider('b1')), isTrue);
    expect(c.read(canManageBandMembersProvider('b1')), isTrue);
  });

  test('viewer (absent from both arrays) cannot edit', () async {
    final c = container(bands: [band()]);
    await settle(c);

    expect(c.read(canEditBandProvider('b1')), isFalse);
    expect(c.read(isBandAdminProvider('b1')), isFalse);
  });

  test('demo user is denied regardless of band role', () async {
    final c = container(
      bands: [band(adminUids: const ['u1'])],
      accessRole: 'demo',
    );
    await settle(c);

    expect(c.read(canEditBandProvider('b1')), isFalse);
    expect(c.read(isBandAdminProvider('b1')), isFalse);
  });

  test('unknown band and loading stream are fail-closed', () async {
    final c = container(bands: [band(adminUids: const ['u1'])]);
    // Before the stream emits: closed.
    expect(c.read(canEditBandProvider('b1')), isFalse);
    await settle(c);
    expect(c.read(canEditBandProvider('nope')), isFalse);
  });
}
