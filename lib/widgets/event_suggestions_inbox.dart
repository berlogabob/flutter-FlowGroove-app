import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/event_suggestion.dart';
import '../providers/data/data_providers.dart';
import '../theme/mono_pulse_theme.dart';
import '../utils/snackbar.dart';

/// The band's side of event sharing: what guests asked for, and the two
/// buttons that answer them.
///
/// Guests could submit from the day sharing shipped and nothing rendered the
/// result, so every request went into a void — the callable existed, the tests
/// passed, and no screen ever called `resolveSuggestion`.
///
/// Renders nothing at all when the inbox is empty, so a setlist nobody has
/// commented on looks exactly as it did before.
class EventSuggestionsInbox extends ConsumerStatefulWidget {
  const EventSuggestionsInbox({
    required this.bandId,
    required this.setlistId,
    required this.canResolve,
    super.key,
  });

  final String bandId;
  final String setlistId;

  /// Accepting or declining needs band editor/admin — the callable enforces it
  /// too, so a plain member sees the requests read-only rather than buttons
  /// that fail.
  final bool canResolve;

  @override
  ConsumerState<EventSuggestionsInbox> createState() =>
      _EventSuggestionsInboxState();
}

class _EventSuggestionsInboxState extends ConsumerState<EventSuggestionsInbox> {
  /// Ids currently in flight, so a double-tap cannot send two answers.
  final _busy = <String>{};

  Future<void> _resolve(EventSuggestion s, {required bool accept}) async {
    if (_busy.contains(s.id)) return;
    setState(() => _busy.add(s.id));
    try {
      await ref
          .read(eventShareServiceProvider)
          .resolveSuggestion(
            bandId: widget.bandId,
            setlistId: widget.setlistId,
            suggestionId: s.id,
            accept: accept,
          );
      // The stream carries the new status back, so nothing to set here.
    } catch (e) {
      // showGlobalSnackBar, not the local one: resolving can outlive this
      // widget if the user navigates away mid-call.
      showGlobalSnackBar('Could not answer that request: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(s.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestions =
        ref
            .watch(setlistSuggestionsProvider((widget.bandId, widget.setlistId)))
            .value ??
        const <EventSuggestion>[];
    if (suggestions.isEmpty) return const SizedBox.shrink();

    final open = suggestions.where((s) => s.isOpen).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: MonoPulseSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.mark_email_unread_outlined,
                size: 18,
                color: MonoPulseColors.accentOrange,
              ),
              const SizedBox(width: MonoPulseSpacing.sm),
              Text(
                open > 0 ? 'Requests ($open open)' : 'Requests',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: MonoPulseColors.accentOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: MonoPulseSpacing.sm),
          for (final s in suggestions)
            _SuggestionCard(
              suggestion: s,
              busy: _busy.contains(s.id),
              canResolve: widget.canResolve,
              onAccept: () => _resolve(s, accept: true),
              onDecline: () => _resolve(s, accept: false),
            ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.busy,
    required this.canResolve,
    required this.onAccept,
    required this.onDecline,
  });

  final EventSuggestion suggestion;
  final bool busy;
  final bool canResolve;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final s = suggestion;
    final who = s.authorName.isEmpty ? 'Someone' : s.authorName;
    return Container(
      margin: const EdgeInsets.only(bottom: MonoPulseSpacing.sm),
      padding: const EdgeInsets.all(MonoPulseSpacing.md),
      decoration: BoxDecoration(
        color: s.isOpen
            ? MonoPulseColors.accentOrange10
            : Colors.transparent,
        borderRadius: BorderRadius.circular(MonoPulseRadius.small),
        border: Border.all(
          color: MonoPulseColors.accentOrange.withValues(
            alpha: s.isOpen ? 0.4 : 0.15,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$who ${s.action}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (s.text.isNotEmpty) ...[
            const SizedBox(height: MonoPulseSpacing.xs),
            Text(s.text),
          ],
          const SizedBox(height: MonoPulseSpacing.sm),
          if (!s.isOpen)
            Text(
              s.status == 'accepted' ? 'Accepted' : 'Declined',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            )
          else if (!canResolve)
            const Text('Waiting for a band editor')
          else if (busy)
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onDecline, child: const Text('Decline')),
                const SizedBox(width: MonoPulseSpacing.sm),
                FilledButton(
                  onPressed: onAccept,
                  child: const Text('Accept'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
