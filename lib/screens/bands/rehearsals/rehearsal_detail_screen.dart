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

  // Gate on the live adminUids/editorUids arrays (what rules read), not the
  // navigation-snapshot band.members.
  bool _canEdit(WidgetRef ref) => ref.watch(canEditBandProvider(band.id));

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
          RehearsalVote(
            uid: uid,
            answers: answers,
            comment: existing?.comment,
            updatedAt: DateTime.now(),
          ),
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

  Future<void> _suggestTime(
    BuildContext context,
    WidgetRef ref,
    String uid,
  ) async {
    final controller = TextEditingController(text: votes[uid]?.comment ?? '');
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suggest a different time'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Sunday 18:00?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (text == null) return;
    final existing = votes[uid];
    await ref.read(rehearsalRepositoryProvider).saveVote(
          band.id,
          rehearsal.id,
          RehearsalVote(
            uid: uid,
            answers: existing?.answers ?? const {},
            comment: text.isEmpty ? null : text,
            updatedAt: DateTime.now(),
          ),
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
          const SizedBox(height: MonoPulseSpacing.xs),
          Row(children: [
            const Icon(Icons.place, size: 16),
            const SizedBox(width: MonoPulseSpacing.xs),
            Expanded(child: Text(rehearsal.location!)),
          ]),
        ],
        if (!confirmed && rehearsal.responseDeadline != null) ...[
          const SizedBox(height: MonoPulseSpacing.xs),
          Row(children: [
            const Icon(Icons.alarm, size: 16),
            const SizedBox(width: MonoPulseSpacing.xs),
            Text('Respond by ${formatDeadline(rehearsal.responseDeadline!)}'),
          ]),
        ],
        if (rehearsal.notes != null) ...[
          const SizedBox(height: MonoPulseSpacing.sm),
          Text(rehearsal.notes!),
        ],
        const SizedBox(height: MonoPulseSpacing.lg),

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
          const SizedBox(height: MonoPulseSpacing.md),
          _notVotedNotice(context, ref, uid, canEdit),
          _suggestionsSection(context),
          if (uid != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('None of these work — suggest a time'),
                onPressed: () => _suggestTime(context, ref, uid),
              ),
            ),
        ],

        const SizedBox(height: MonoPulseSpacing.xxl),
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

  Widget _notVotedNotice(
    BuildContext context,
    WidgetRef ref,
    String? uid,
    bool canEdit,
  ) {
    final invited = {
      ...rehearsal.requiredMemberUids,
      ...rehearsal.optionalMemberUids,
    };
    final pool = invited.isEmpty
        ? band.members.map((m) => m.uid).toSet()
        : invited;
    // A vote doc can exist with no answers (a member left a suggestion via
    // "suggest a time" without voting on any slot) — that doesn't count as
    // having responded.
    final notVoted =
        pool.where((u) => votes[u]?.answers.isEmpty ?? true).toList();
    if (notVoted.isEmpty) return const SizedBox.shrink();
    final names = notVoted.map((u) {
      final m = band.members.firstWhere(
        (m) => m.uid == u,
        orElse: () => BandMember(uid: u, role: ''),
      );
      return memberLabel(displayName: m.displayName, email: m.email);
    }).join(', ');
    final deadlinePassed = rehearsal.responseDeadline != null &&
        rehearsal.responseDeadline!.isBefore(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Waiting on: $names',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (canEdit && deadlinePassed)
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () async {
                  try {
                    await ref
                        .read(rehearsalFunctionServiceProvider)
                        .remindVoters(
                          bandId: band.id,
                          rehearsalId: rehearsal.id,
                        );
                    if (context.mounted) {
                      showAppSnackBar(context, 'Reminder sent');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      showAppSnackBar(context, 'Could not send reminder: $e');
                    }
                  }
                },
                child: const Text('Remind'),
              ),
              TextButton(
                onPressed: () => context.pushNamed(
                  'edit-rehearsal',
                  pathParameters: {'id': band.id, 'rid': rehearsal.id},
                  extra: rehearsal,
                ),
                child: const Text('Extend deadline'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _suggestionsSection(BuildContext context) {
    final suggestions = votes.values.where(
      (v) => v.comment != null && v.comment!.trim().isNotEmpty,
    );
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: MonoPulseSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Suggestions', style: Theme.of(context).textTheme.titleSmall),
          for (final v in suggestions)
            Padding(
              padding: const EdgeInsets.only(top: MonoPulseSpacing.xs),
              child: Text('${_memberName(v.uid)}: ${v.comment}'),
            ),
        ],
      ),
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
            const SizedBox(height: MonoPulseSpacing.sm),
            Wrap(
              // _voteButton already right-pads each chip; only runSpacing is
              // needed here for the gap when chips wrap to a second line.
              runSpacing: MonoPulseSpacing.xs,
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
              const SizedBox(width: MonoPulseSpacing.sm),
              Expanded(
                child: Text(
                  slot == null ? 'Confirmed' : formatSlotRange(slot),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ]),
            const SizedBox(height: MonoPulseSpacing.md),
            if (attendees.isNotEmpty) Text('Coming: ${attendees.join(', ')}'),
            if (setlist != null) ...[
              const Divider(height: 24),
              Text('Setlist: ${setlist.name}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: MonoPulseSpacing.xs),
              for (final item in setlist.effectiveItems)
                _songLine(ref, songsById[item.songId]),
            ],
            const SizedBox(height: MonoPulseSpacing.lg),
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

  Widget _songLine(WidgetRef ref, Song? song) {
    if (song == null) return const SizedBox.shrink();
    // "What to prepare" (#68): open Song Lab tasks for this band song.
    final openTasks =
        ref.watch(openTaskCountProvider((song.id, band.id))).value ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MonoPulseSpacing.xxs),
      child: Text(
        '• ${song.title} — ${song.artist}'
        '${openTasks > 0 ? '  ·  $openTasks open task${openTasks == 1 ? '' : 's'}' : ''}',
      ),
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
