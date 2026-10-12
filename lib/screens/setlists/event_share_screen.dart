import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/event_access.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../services/event_share_service.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/music_role_icon.dart';
import '../../utils/snackbar.dart';

/// What someone opening a shared event link sees — a venue's art director, a
/// wedding couple, a sound engineer, a guest musician.
///
/// Renders ONLY what [EventView] contains. It is not filtering: the server
/// already omitted every area this viewer was not granted, so there is nothing
/// sensitive in memory to accidentally show. A missing section here means the
/// data never arrived.
///
/// Works signed out on purpose. Suggesting needs no account — a client or a
/// venue will not complete a signup — while anyone who *edits* signs in first.
class EventShareScreen extends ConsumerStatefulWidget {
  const EventShareScreen({required this.token, super.key});

  final String token;

  @override
  ConsumerState<EventShareScreen> createState() => _EventShareScreenState();
}

class _EventShareScreenState extends ConsumerState<EventShareScreen> {
  EventView? _view;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final view = await ref
          .read(eventShareServiceProvider)
          .getEventView(token: widget.token);
      if (!mounted) return;
      setState(() {
        _view = view;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'This link is not valid any more. Ask the band for a new one.';
        _loading = false;
      });
    }
  }

  /// Via the app's own auth provider, not FirebaseAuth.instance: this page is
  /// the one screen reachable with no Firebase session at all, and reaching for
  /// the singleton in build() throws when there is no app.
  bool get _signedIn => ref.watch(currentUserProvider).value != null;

  /// Stash the token, then send them to login. `_afterLoginSuccess` claims it
  /// and opens the event — the same shape the band invite code already uses.
  Future<void> _signInToEdit() async {
    await ref
        .read(pendingEventTokenStoreProvider)
        .setPendingEventToken(widget.token);
    if (!mounted) return;
    context.go('/login');
  }

  Future<void> _suggest() async {
    final view = _view;
    if (view == null) return;
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SuggestSheet(),
    );
    if (text == null || text.trim().isEmpty) return;
    try {
      await ref.read(eventShareServiceProvider).submitSuggestion(
        token: widget.token,
        type: 'note',
        text: text,
      );
      if (mounted) showAppSnackBar(context, 'Sent to the band. Thanks!');
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Could not send that: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final view = _view;
    if (view == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(MonoPulseSpacing.xl),
            child: Text(
              _error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: MonoPulseTypography.bodyMedium,
            ),
          ),
        ),
      );
    }

    // Anyone granted an EDIT level has to sign in before they can use it —
    // editing carries an author, reading and suggesting never do. Without this
    // the link is a dead end for exactly the people given the most access.
    final needsSignIn = !_signedIn &&
        EventArea.all.any((a) => canEditArea(view.access, a));

    return Scaffold(
      appBar: AppBar(title: Text(view.name)),
      floatingActionButton: needsSignIn
          ? FloatingActionButton.extended(
              onPressed: _signInToEdit,
              icon: const Icon(Icons.login),
              label: const Text('Sign in to edit'),
            )
          : view.canSuggest
          ? FloatingActionButton.extended(
              onPressed: _suggest,
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Suggest a change'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(MonoPulseSpacing.lg),
          children: [
            if (view.viewerName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: MonoPulseSpacing.md),
                child: Text(
                  'Shared with ${view.viewerName}',
                  style: MonoPulseTypography.bodySmall.copyWith(
                    color: context.mp.textSecondary,
                  ),
                ),
              ),
            if (view.canSee(EventArea.eventInfo)) ..._eventInfo(view),
            if (view.canSee(EventArea.runningOrder)) ..._runningOrder(view),
            if (view.stage != null) ..._stage(view),
            if (view.rider != null) ..._rider(view),
            ..._myRequests(view),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  /// What this person asked for, and what the band decided.
  ///
  /// Submitting used to be a one-way door: the suggestions subcollection is
  /// members-only, so the person who asked never learned the answer. These come
  /// back on the scoped payload, which works for an anonymous link holder too.
  List<Widget> _myRequests(EventView view) {
    if (view.mySuggestions.isEmpty) return const [];
    return [
      const SizedBox(height: MonoPulseSpacing.lg),
      _title('Your requests'),
      for (final s in view.mySuggestions)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: MonoPulseSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                switch (s.status) {
                  'accepted' => Icons.check_circle_outline,
                  'declined' => Icons.cancel_outlined,
                  _ => Icons.schedule,
                },
                size: 18,
                color: context.mp.textSecondary,
              ),
              const SizedBox(width: MonoPulseSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.text.isEmpty ? s.action : s.text,
                      style: MonoPulseTypography.bodyMedium,
                    ),
                    Text(
                      switch (s.status) {
                        'accepted' => 'Accepted by the band',
                        'declined' => 'Declined',
                        _ => 'Waiting for the band',
                      },
                      style: MonoPulseTypography.bodySmall.copyWith(
                        color: context.mp.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _eventInfo(EventView view) => [
    _title('Event'),
    if (view.eventDateTime != null)
      _row(Icons.event, _formatDate(view.eventDateTime!)),
    if (view.eventLocation != null)
      _row(Icons.place_outlined, view.eventLocation!),
    if (view.description != null && view.description!.isNotEmpty)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: MonoPulseSpacing.sm),
        child: Text(view.description!, style: MonoPulseTypography.bodyMedium),
      ),
    if (view.people.isNotEmpty) ...[
      const SizedBox(height: MonoPulseSpacing.md),
      _title('Line-up'),
      for (final p in view.people)
        _row(
          Icons.person_outline,
          '${p['name']}'
          '${(p['role'] as String? ?? '').isEmpty ? '' : ' — ${MusicRoleIcon.getDisplayName(p['role'] as String)}'}',
        ),
    ],
    const SizedBox(height: MonoPulseSpacing.lg),
  ];

  List<Widget> _runningOrder(EventView view) {
    final byId = {for (final s in view.songs) s['id'] as String? ?? '': s};
    final detailed = view.canSee(EventArea.songDetail);
    var n = 0;
    return [
      _title('Running order'),
      for (final item in view.items)
        if (item['type'] == 'break')
          Padding(
            padding: const EdgeInsets.symmetric(vertical: MonoPulseSpacing.sm),
            child: Text(
              '— ${(item['breakLabel'] as String? ?? 'Break').toUpperCase()} —',
              style: MonoPulseTypography.labelSmall.copyWith(
                color: context.mp.textSecondary,
              ),
            ),
          )
        else
          Builder(
            builder: (context) {
              final song = byId[item['songId'] as String? ?? ''];
              if (song == null) return const SizedBox.shrink();
              n++;
              // Key and BPM appear only when songDetail was granted — a client
              // asked for their first dance, not a transposition.
              final meta = detailed
                  ? [
                      if (song['ourKey'] != null) '${song['ourKey']}',
                      if (song['ourBPM'] != null) '${song['ourBPM']} BPM',
                    ].join(' · ')
                  : '';
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Text('$n', style: MonoPulseTypography.bodySmall),
                title: Text('${song['title']}'),
                subtitle: Text(
                  [song['artist'], if (meta.isNotEmpty) meta]
                      .where((s) => s != null && '$s'.isNotEmpty)
                      .join(' · '),
                ),
              );
            },
          ),
      const SizedBox(height: MonoPulseSpacing.lg),
    ];
  }

  List<Widget> _stage(EventView view) => [
    _title('Stage plot'),
    for (final entry in view.stage!.entries)
      if (entry.value is List && (entry.value as List).isNotEmpty)
        _row(
          Icons.grid_view_outlined,
          '${entry.key}: '
          '${(entry.value as List).map((p) => (p as Map)['label']).join(', ')}',
        ),
    const SizedBox(height: MonoPulseSpacing.lg),
  ];

  List<Widget> _rider(EventView view) => [
    _title('Equipment'),
    for (final item in view.rider!)
      _row(
        Icons.check_box_outline_blank,
        '${item['label']}${item['qty'] != null ? ' ×${item['qty']}' : ''}',
      ),
    const SizedBox(height: MonoPulseSpacing.lg),
  ];

  Widget _title(String text) => Padding(
    padding: const EdgeInsets.only(bottom: MonoPulseSpacing.sm),
    child: Text(
      text,
      style: MonoPulseTypography.titleMedium.copyWith(
        color: MonoPulseColors.accentOrange,
      ),
    ),
  );

  Widget _row(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: context.mp.textSecondary),
        const SizedBox(width: MonoPulseSpacing.sm),
        Expanded(child: Text(text, style: MonoPulseTypography.bodyMedium)),
      ],
    ),
  );

  static String _formatDate(DateTime d) {
    final local = d.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} at $hh:$mm';
  }
}

class _SuggestSheet extends StatefulWidget {
  const _SuggestSheet();

  @override
  State<_SuggestSheet> createState() => _SuggestSheetState();
}

class _SuggestSheetState extends State<_SuggestSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Padding(
      padding: const EdgeInsets.all(MonoPulseSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggest a change',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: MonoPulseSpacing.sm),
          Text(
            'Ask for a different order, a song added or dropped, or a word '
            'changed. The band decides — nothing changes automatically.',
            style: MonoPulseTypography.bodySmall,
          ),
          const SizedBox(height: MonoPulseSpacing.md),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 4,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: MonoPulseSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: MonoPulseSpacing.sm),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, _controller.text),
                child: const Text('Send'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
