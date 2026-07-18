import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/mono_pulse_theme.dart';
import '../../utils/snackbar.dart';
import 'unified_item_model.dart';

/// The setlist-card action catalog: key → (label, icon). Mirrors the song-card
/// quick-action system so setlist cards show ONE pinned action + an overflow.
const setlistQuickActions = <String, (String, IconData)>{
  'metronome': ('Open in metronome', Icons.av_timer),
  'eventkit': ('Event kit', Icons.theater_comedy_outlined),
  'edit': ('Edit setlist', Icons.edit_outlined),
  'share': ('Share', Icons.share),
  'copylinks': ('Copy links', Icons.link),
  'pdf': ('Export PDF', Icons.picture_as_pdf),
};

/// Which action is pinned on setlist cards ('metronome' default). Persisted.
class SetlistQuickActionNotifier extends Notifier<String> {
  static const prefsKey = 'setlists.quick_action';

  @override
  String build() {
    unawaited(_load());
    return 'metronome';
  }

  Future<void> _load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(prefsKey);
      if (saved != null && setlistQuickActions.containsKey(saved)) {
        state = saved;
      }
    } catch (_) {
      // No prefs backend (first run / tests) — the default stands.
    }
  }

  Future<void> set(String action) async {
    state = action;
    try {
      await (await SharedPreferences.getInstance()).setString(prefsKey, action);
    } catch (_) {
      // Persisting is best-effort; the in-memory choice still applies.
    }
  }
}

/// Provider for the pinned setlist-card quick action.
final setlistQuickActionProvider =
    NotifierProvider<SetlistQuickActionNotifier, String>(
      SetlistQuickActionNotifier.new,
    );

/// Quick-action picker sheet — shared by the setlist-card overflow and Settings.
Future<void> showSetlistQuickActionPicker(
  BuildContext context,
  WidgetRef ref,
) async {
  final current = ref.read(setlistQuickActionProvider);
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: RadioGroup<String>(
        groupValue: current,
        onChanged: (v) => Navigator.pop(context, v),
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Quick action'),
              subtitle: Text('Sets what the pinned button on setlist cards does'),
            ),
            for (final MapEntry(: key, : value) in setlistQuickActions.entries)
              RadioListTile<String>(
                value: key,
                title: Text(value.$1),
                secondary: Icon(value.$2),
              ),
          ],
        ),
      ),
    ),
  );
  if (choice != null && choice != current) {
    await ref.read(setlistQuickActionProvider.notifier).set(choice);
    if (!context.mounted) return;
    final (label, _) = setlistQuickActions[choice]!;
    showAppSnackBar(context, 'Quick action set to $label');
  }
}

/// Builds the setlist card's trailing actions: ONE pinned quick-action icon
/// (the configured action, or a metronome fallback when a canEdit-only action
/// is pinned but the user can't edit) + an overflow with everything. The screen
/// passes its own handlers so the personal and band lists behave identically.
List<UnifiedItemAction> buildSetlistActions({
  required String quick,
  required bool canEdit,
  required VoidCallback onMetronome,
  required VoidCallback onEdit,
  required VoidCallback onEventKit,
  required VoidCallback onShare,
  required VoidCallback onCopyLinks,
  required VoidCallback onExportPdf,
  required VoidCallback onPickQuickAction,
}) {
  VoidCallback handlerFor(String key) => switch (key) {
    'eventkit' => onEventKit,
    'edit' => onEdit,
    'share' => onShare,
    'copylinks' => onCopyLinks,
    'pdf' => onExportPdf,
    _ => onMetronome,
  };

  // Edit / Event kit need edit rights; fall back to metronome otherwise.
  var pinned = setlistQuickActions.containsKey(quick) ? quick : 'metronome';
  if ((pinned == 'edit' || pinned == 'eventkit') && !canEdit) {
    pinned = 'metronome';
  }
  final (pinnedLabel, pinnedIcon) = setlistQuickActions[pinned]!;

  return [
    IconAction(
      icon: pinnedIcon,
      tooltip: pinnedLabel,
      color: MonoPulseColors.accentOrange,
      onPressed: handlerFor(pinned),
    ),
    OverflowMenuAction(
      entries: [
        if (canEdit) ('Edit setlist', Icons.edit_outlined, onEdit),
        if (canEdit) ('Event kit', Icons.theater_comedy_outlined, onEventKit),
        ('Share', Icons.share, onShare),
        ('Copy links', Icons.link, onCopyLinks),
        ('Export PDF', Icons.picture_as_pdf, onExportPdf),
        ('Quick action…', Icons.push_pin_outlined, onPickQuickAction),
      ],
    ),
  ];
}
