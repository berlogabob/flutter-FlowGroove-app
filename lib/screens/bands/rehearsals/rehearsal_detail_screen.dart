import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/band.dart';
import '../../../models/rehearsal.dart';
import '../../../models/song.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../providers/data/data_providers.dart';
import '../../../providers/permissions_provider.dart';
import '../../../theme/mono_pulse_theme.dart';
import '../../../utils/ics_export.dart';
import '../../../utils/member_label.dart';
import '../../../utils/rehearsal_scoring.dart';
import '../../../utils/snackbar.dart';
import '../../../widgets/error_banner.dart' show ErrorBanner, ErrorBannerStyle;
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/standard_screen_scaffold.dart';
import 'rehearsal_format.dart';

class RehearsalDetailScreen extends ConsumerWidget {
  const RehearsalDetailScreen({
    required this.band,
    required this.rehearsalId,
    super.key,
  });

  final Band band;
  final String rehearsalId;

  bool _canEdit(WidgetRef ref) {
    if (ref.read(isDemoUserProvider)) return false;
    final user = ref.read(currentUserProvider).value;
    if (user == null) return false;
    final member = band.members.firstWhere(
      (m) => m.uid == user.uid,
      orElse: () => BandMember(uid: '', role: ''),
    );
    return member.role == BandMember.roleAdmin ||
        member.role == BandMember.roleEditor;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (band.id, rehearsalId);
    final rehearsalAsync = ref.watch(rehearsalProvider(key));

    return StandardScreenScaffold(
      title: 'Rehearsal',
      body: rehearsalAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(
          child: ErrorBanner(
            message: e.toString(),
            style: ErrorBannerStyle.card,
          ),
        ),
        data: (rehearsal) {
          if (rehearsal == null) {
            return const Center(child: Text('Rehearsal not found'));
          }
          final votesAsync = ref.watch(rehearsalVotesProvider(key));
          return votesAsync.when(
            loading: () => const LoadingIndicator(),
            error: (e, _) => Center(child: Text('$e')),
            data: (votes) => _Body(
              band: band,
              rehearsal: rehearsal,
              votes: votes,
              canEdit: _canEdit(ref),
            ),
          );
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.band,
    required this.rehearsal,
    required this.votes,
    required this.canEdit,
  });

  final Band band;
  final Rehearsal rehearsal;
  final Map<String, RehearsalVote> votes;
  final bool canEdit;

  Future<void> _vote(
    WidgetRef ref,
    String uid,
    String slotId,
    String answer,
  ) async {
    final existing = votes[uid];
    final answers = {...?existing?.answers, slotId: answer};
    await ref.read(rehearsalRepositoryProvider).saveVote(
          band.id,
          rehearsal.id,
          RehearsalVote(uid: uid, answers: answers, updatedAt: DateTime.now()),
        );
  }

  Future<void> _confirm(WidgetRef ref, String slotId) async {
    await ref.read(rehearsalRepositoryProvider).saveRehearsal(
          rehearsal.copyWith(
            status: Rehearsal.statusConfirmed,
            confirmedSlotId: slotId,
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<void> _setStatus(WidgetRef ref, String status) async {
    await ref.read(rehearsalRepositoryProvider).saveRehearsal(
          rehearsal.copyWith(status: status, updatedAt: DateTime.now()),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.read(currentUserProvider).value?.uid;
    final scores = {
      for (final s in scoreSlots(rehearsal, votes)) s.slotId: s,
    };
    final best = bestSlot(rehearsal, votes);
    final confirmed = rehearsal.status == Rehearsal.statusConfirmed;

    return ListView(
      padding: const EdgeInsets.all(MonoPulseSpacing.lg),
      children: [
        Text(rehearsal.title, style: Theme.of(context).textTheme.headlineSmall),
        if (rehearsal.location != null) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.place, size: 16),
            const SizedBox(width: 4),
            Expanded(child: Text(rehearsal.location!)),
          ]),
        ],
        if (rehearsal.notes != null) ...[
          const SizedBox(height: 8),
          Text(rehearsal.notes!),
        ],
        const SizedBox(height: 16),

        if (confirmed)
          _ConfirmedCard(band: band, rehearsal: rehearsal, votes: votes)
        else ...[
          for (final slot in rehearsal.candidateSlots)
            _SlotCard(
              slot: slot,
              score: scores[slot.id],
              isBest: best?.slotId == slot.id,
              myAnswer: uid == null ? null : votes[uid]?.answers[slot.id],
              band: band,
              votes: votes,
              onVote: uid == null
                  ? null
                  : (answer) => _vote(ref, uid, slot.id, answer),
              onConfirm:
                  canEdit ? () => _confirm(ref, slot.id) : null,
            ),
          const SizedBox(height: 12),
          _notVotedNotice(context, uid),
        ],

        const SizedBox(height: 24),
        if (canEdit) ...[
          if (confirmed)
            OutlinedButton.icon(
              icon: const Icon(Icons.event_busy),
              label: const Text('Reopen voting'),
              onPressed: () => _setStatus(ref, Rehearsal.statusCollecting),
            )
          else
            OutlinedButton.icon(
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel rehearsal'),
              onPressed: () => _setStatus(ref, Rehearsal.statusCancelled),
            ),
          TextButton.icon(
            icon: const Icon(Icons.edit),
            label: const Text('Edit details'),
            onPressed: () => context.pushNamed(
              'edit-rehearsal',
              pathParameters: {'id': band.id, 'rid': rehearsal.id},
              extra: rehearsal,
            ),
          ),
        ],
      ],
    );
  }

  Widget _notVotedNotice(BuildContext context, String? uid) {
    final invited = {
      ...rehearsal.requiredMemberUids,
      ...rehearsal.optionalMemberUids,
    };
    final pool = invited.isEmpty
        ? band.members.map((m) => m.uid).toSet()
        : invited;
    final notVoted = pool.where((u) => votes[u] == null).toList();
    if (notVoted.isEmpty) return const SizedBox.shrink();
    final names = notVoted.map((u) {
      final m = band.members.firstWhere(
        (m) => m.uid == u,
        orElse: () => BandMember(uid: u, role: ''),
      );
      return memberLabel(displayName: m.displayName, email: m.email);
    }).join(', ');
    return Text(
      'Waiting on: $names',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.score,
    required this.isBest,
    required this.myAnswer,
    required this.band,
    required this.votes,
    required this.onVote,
    required this.onConfirm,
  });

  final CandidateSlot slot;
  final RehearsalSlotScore? score;
  final bool isBest;
  final String? myAnswer;
  final Band band;
  final Map<String, RehearsalVote> votes;
  final void Function(String answer)? onVote;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final blocked = score?.blocked ?? false;
    final blockingNames = (score?.blockingUids ?? []).map((u) {
      final m = band.members.firstWhere(
        (m) => m.uid == u,
        orElse: () => BandMember(uid: u, role: ''),
      );
      return memberLabel(displayName: m.displayName, email: m.email);
    }).join(', ');

    return Card(
      shape: isBest
          ? RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(MonoPulseSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatSlotRange(slot),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (isBest)
                  const Chip(
                    label: Text('Best'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (blocked)
              Padding(
                padding: const EdgeInsets.only(top: MonoPulseSpacing.xs),
                child: Text(
                  "Can't make it: $blockingNames",
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                _voteButton('Can', RehearsalVote.answerCan,
                    MonoPulseColors.successGreen),
                _voteButton('Maybe', RehearsalVote.answerMaybe,
                    MonoPulseColors.warning),
                _voteButton("Can't", RehearsalVote.answerCant,
                    MonoPulseColors.error),
              ],
            ),
            if (onConfirm != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onConfirm,
                  child: const Text('Confirm this time'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _voteButton(String label, String answer, Color color) {
    final selected = myAnswer == answer;
    return Padding(
      padding: const EdgeInsets.only(right: MonoPulseSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: color.withValues(alpha: 0.3),
        onSelected: onVote == null ? null : (_) => onVote!(answer),
      ),
    );
  }
}

class _ConfirmedCard extends ConsumerWidget {
  const _ConfirmedCard({
    required this.band,
    required this.rehearsal,
    required this.votes,
  });

  final Band band;
  final Rehearsal rehearsal;
  final Map<String, RehearsalVote> votes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slot = rehearsal.confirmedSlot;
    final setlists = ref.watch(bandSetlistsProvider(band.id)).value ?? [];
    final setlist = rehearsal.setlistId == null
        ? null
        : setlists.where((s) => s.id == rehearsal.setlistId).firstOrNull;
    final songs = ref.watch(bandSongsProvider(band.id)).value ?? [];
    final songsById = {for (final s in songs) s.id: s};

    final attendees = [
      for (final entry in votes.entries)
        if (entry.value.answers[slot?.id] == RehearsalVote.answerCan)
          _memberName(entry.key),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.event_available),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  slot == null ? 'Confirmed' : formatSlotRange(slot),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            if (attendees.isNotEmpty) Text('Coming: ${attendees.join(', ')}'),
            if (setlist != null) ...[
              const Divider(height: 24),
              Text('Setlist: ${setlist.name}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              for (final item in setlist.effectiveItems)
                _songLine(songsById[item.songId]),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.calendar_month),
              label: const Text('Add to calendar'),
              onPressed: () async {
                final ok = await shareRehearsalIcs(
                  rehearsal,
                  setlistName: setlist?.name,
                );
                if (!ok && context.mounted) {
                  showAppSnackBar(context, 'Could not create calendar file');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _songLine(Song? song) {
    if (song == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MonoPulseSpacing.xxs),
      child: Text('• ${song.title} — ${song.artist}'),
    );
  }

  String _memberName(String uid) {
    final m = band.members.firstWhere(
      (m) => m.uid == uid,
      orElse: () => BandMember(uid: uid, role: ''),
    );
    return memberLabel(displayName: m.displayName, email: m.email);
  }
}
