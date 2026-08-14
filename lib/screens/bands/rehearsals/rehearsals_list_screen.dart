import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/band.dart';
import '../../../models/rehearsal.dart';
import '../../../providers/data/data_providers.dart';
import '../../../providers/permissions_provider.dart';
import '../../../theme/mono_pulse_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/error_banner.dart' show ErrorBanner, ErrorBannerStyle;
import '../../../widgets/fab_variants.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/standard_screen_scaffold.dart';
import 'rehearsal_format.dart';

class RehearsalsListScreen extends ConsumerWidget {
  const RehearsalsListScreen({required this.band, super.key});

  final Band band;

  // Gate on the live adminUids/editorUids arrays (what rules read), not the
  // navigation-snapshot band.members.
  bool _canEdit(WidgetRef ref) => ref.watch(canEditBandProvider(band.id));

  void _create(BuildContext context) {
    context.pushNamed(
      'create-rehearsal',
      pathParameters: {'id': band.id},
      extra: band,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rehearsalsAsync = ref.watch(bandRehearsalsProvider(band.id));
    final canEdit = _canEdit(ref);

    return StandardScreenScaffold(
      title: '${band.name} Rehearsals',
      floatingActionButton: canEdit
          ? SingleFab(
              icon: Icons.add,
              onPressed: () => _create(context),
              heroTag: 'rehearsals_fab_${band.id}',
            )
          : null,
      body: rehearsalsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(
          child: ErrorBanner(
            message: e.toString(),
            onRetry: () => ref.invalidate(bandRehearsalsProvider(band.id)),
            showRetry: true,
            style: ErrorBannerStyle.card,
          ),
        ),
        data: (rehearsals) {
          if (rehearsals.isEmpty) {
            return EmptyState(
              icon: Icons.event_available,
              message: 'No rehearsals yet',
              hint: canEdit
                  ? 'Propose a time and let the band vote'
                  : 'Proposed rehearsals will appear here',
              actionLabel: canEdit ? 'New rehearsal' : null,
              onAction: canEdit ? () => _create(context) : null,
            );
          }
          final sorted = [...rehearsals]
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return ListView.builder(
            padding: const EdgeInsets.all(MonoPulseSpacing.md),
            itemCount: sorted.length,
            itemBuilder: (context, i) =>
                _RehearsalTile(band: band, rehearsal: sorted[i]),
          );
        },
      ),
    );
  }
}

class _RehearsalTile extends StatelessWidget {
  const _RehearsalTile({required this.band, required this.rehearsal});

  final Band band;
  final Rehearsal rehearsal;

  @override
  Widget build(BuildContext context) {
    final confirmed = rehearsal.confirmedSlot;
    final relevantSlots = confirmed == null
        ? rehearsal.candidateSlots
        : [confirmed];
    final isPast =
        relevantSlots.isNotEmpty &&
        relevantSlots.every((slot) => slot.endTime.isBefore(DateTime.now()));
    final subtitle = confirmed != null
        ? formatSlotRange(confirmed)
        : '${rehearsal.candidateSlots.length} proposed time'
              '${rehearsal.candidateSlots.length == 1 ? '' : 's'}';

    return Opacity(
      opacity: isPast ? 0.6 : 1,
      child: Card(
        child: ListTile(
          leading: Icon(_statusIcon(rehearsal.status)),
          title: Text(rehearsal.title),
          subtitle: Text(subtitle),
          trailing: Chip(
            label: Text(
              isPast ? 'Past' : _statusLabel(rehearsal.status),
              style: isPast ? TextStyle(color: context.mp.textSecondary) : null,
            ),
            backgroundColor: isPast ? context.mp.surfaceRaised : null,
            visualDensity: VisualDensity.compact,
          ),
          onTap: () => context.pushNamed(
            'rehearsal-detail',
            pathParameters: {'id': band.id, 'rid': rehearsal.id},
            extra: band,
          ),
        ),
      ),
    );
  }

  IconData _statusIcon(String status) => switch (status) {
    Rehearsal.statusConfirmed => Icons.event_available,
    Rehearsal.statusCancelled => Icons.event_busy,
    Rehearsal.statusDone => Icons.check_circle_outline,
    _ => Icons.how_to_vote,
  };

  String _statusLabel(String status) => switch (status) {
    Rehearsal.statusConfirmed => 'Confirmed',
    Rehearsal.statusCancelled => 'Cancelled',
    Rehearsal.statusDone => 'Done',
    _ => 'Voting',
  };
}
