import 'package:firebase_auth/firebase_auth.dart';
import 'package:flowgroove/models/rehearsal.dart';
import 'package:flowgroove/models/user.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/permissions_provider.dart';
import 'package:flowgroove/repositories/rehearsal_repository.dart';
import 'package:flowgroove/screens/bands/rehearsals/rehearsal_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../helpers/mocks.dart';
import '../../../helpers/mocks.mocks.dart';
import '../../../helpers/routed_test_harness.dart';
import '../../../helpers/test_helpers.dart';

class _VoteRepository extends Fake implements RehearsalRepository {
  final votes = <(String, String, RehearsalVote)>[];

  @override
  Future<void> saveVote(
    String bandId,
    String rehearsalId,
    RehearsalVote vote,
  ) async {
    votes.add((bandId, rehearsalId, vote));
  }
}

void main() {
  final band = MockDataHelper.createMockBand();
  final member = MockDataHelper.createMockAppUser();
  final rehearsal = Rehearsal(
    id: 'rehearsal-1',
    bandId: band.id,
    createdBy: member.uid,
    title: 'Rehearsal proposal',
    candidateSlots: [
      CandidateSlot(
        id: 'slot-1',
        startTime: DateTime(2027, 1, 1, 18),
        endTime: DateTime(2027, 1, 1, 20),
      ),
    ],
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  const suggestLabel = 'None of these work — suggest a time';

  Future<void> pumpScreen(
    WidgetTester tester,
    AppUser user,
    _VoteRepository repository,
  ) async {
    final firebaseUser = MockUser();
    when(firebaseUser.uid).thenReturn(user.uid);
    final key = (band.id, rehearsal.id);
    await pumpAppWidget(
      tester,
      RehearsalDetailScreen(band: band, rehearsalId: rehearsal.id),
      overrides: [
        rehearsalProvider(key).overrideWith((ref) => Stream.value(rehearsal)),
        rehearsalVotesProvider(key).overrideWith((ref) => Stream.value({})),
        currentUserProvider.overrideWithValue(
          AsyncValue<User?>.data(firebaseUser),
        ),
        appUserProvider.overrideWith(() => TestAppUserNotifier(user)),
        canEditBandProvider(band.id).overrideWithValue(false),
        rehearsalRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('demo users cannot vote or suggest a time', (tester) async {
    final repository = _VoteRepository();
    await pumpScreen(tester, member.copyWith(accessRole: 'demo'), repository);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Can'));
    await tester.pump();

    expect(repository.votes, isEmpty);
    expect(find.text(suggestLabel), findsNothing);
    for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
      expect(chip.onSelected, isNull);
    }
  });

  testWidgets('members can vote and suggest a time', (tester) async {
    final repository = _VoteRepository();
    await pumpScreen(tester, member, repository);

    expect(find.text(suggestLabel), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Can'));
    await tester.pump();

    expect(repository.votes, hasLength(1));
    final (bandId, rehearsalId, vote) = repository.votes.single;
    expect(bandId, band.id);
    expect(rehearsalId, rehearsal.id);
    expect(vote.uid, member.uid);
    expect(vote.answers, {'slot-1': RehearsalVote.answerCan});
  });
}
