import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../models/band.dart';
import '../../../models/rehearsal.dart';
import '../../../models/setlist.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../providers/data/data_providers.dart';
import '../../../theme/mono_pulse_theme.dart';
import '../../../utils/snackbar.dart';
import '../../../widgets/standard_screen_scaffold.dart';
import 'rehearsal_format.dart';

/// Create or edit a rehearsal proposal (candidate slots + members + setlist).
class RehearsalEditScreen extends ConsumerStatefulWidget {
  const RehearsalEditScreen({required this.band, this.rehearsal, super.key});

  final Band band;
  final Rehearsal? rehearsal;

  @override
  ConsumerState<RehearsalEditScreen> createState() =>
      _RehearsalEditScreenState();
}

class _RehearsalEditScreenState extends ConsumerState<RehearsalEditScreen> {
  static const _uuid = Uuid();

  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _notes;

  final List<CandidateSlot> _slots = [];
  // uid -> 'required' | 'optional' (absent = not invited)
  final Map<String, String> _roles = {};
  String? _setlistId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.rehearsal;
    _title = TextEditingController(text: r?.title ?? '');
    _location = TextEditingController(text: r?.location ?? '');
    _notes = TextEditingController(text: r?.notes ?? '');
    if (r != null) {
      _slots.addAll(r.candidateSlots);
      for (final uid in r.requiredMemberUids) {
        _roles[uid] = 'required';
      }
      for (final uid in r.optionalMemberUids) {
        _roles[uid] = 'optional';
      }
      _setlistId = r.setlistId;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _addSlot() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 19, minute: 0),
      helpText: 'Start time',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (start.hour + 2) % 24, minute: start.minute),
      helpText: 'End time',
    );
    if (end == null) return;

    final startDt =
        DateTime(date.year, date.month, date.day, start.hour, start.minute);
    var endDt = DateTime(date.year, date.month, date.day, end.hour, end.minute);
    if (!endDt.isAfter(startDt)) {
      endDt = startDt.add(const Duration(hours: 2));
    }
    setState(() {
      _slots.add(CandidateSlot(id: _uuid.v4(), startTime: startDt, endTime: endDt));
      _slots.sort((a, b) => a.startTime.compareTo(b.startTime));
    });
  }

  void _cycleRole(String uid) {
    setState(() {
      final current = _roles[uid];
      if (current == null) {
        _roles[uid] = 'required';
      } else if (current == 'required') {
        _roles[uid] = 'optional';
      } else {
        _roles.remove(uid);
      }
    });
  }

  Future<void> _save() async {
    // Title is optional — date/time identifies a rehearsal well enough.
    final title = _title.text.trim().isEmpty ? 'Rehearsal' : _title.text.trim();
    if (_slots.isEmpty) {
      _snack('Add at least one time option');
      return;
    }
    final uid = ref.read(currentUserProvider).value?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    final existing = widget.rehearsal;
    final now = DateTime.now();
    final rehearsal = Rehearsal(
      id: existing?.id ?? _uuid.v4(),
      bandId: widget.band.id,
      createdBy: existing?.createdBy ?? uid,
      title: title,
      candidateSlots: _slots,
      requiredMemberUids: [
        for (final e in _roles.entries)
          if (e.value == 'required') e.key,
      ],
      optionalMemberUids: [
        for (final e in _roles.entries)
          if (e.value == 'optional') e.key,
      ],
      setlistId: _setlistId,
      setlistScope: _setlistId == null ? null : Rehearsal.scopeBand,
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      status: existing?.status ?? Rehearsal.statusCollecting,
      confirmedSlotId: existing?.confirmedSlotId,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      await ref.read(rehearsalRepositoryProvider).saveRehearsal(rehearsal);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Save failed: $e');
    }
  }

  void _snack(String msg) => showAppSnackBar(context, msg);

  @override
  Widget build(BuildContext context) {
    final setlistsAsync = ref.watch(bandSetlistsProvider(widget.band.id));

    return StandardScreenScaffold(
      title: widget.rehearsal == null ? 'New Rehearsal' : 'Edit Rehearsal',
      body: ListView(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title (optional)'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          _sectionLabel('Time options'),
          for (final slot in _slots)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.schedule),
              title: Text(formatSlotRange(slot)),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _slots.remove(slot)),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add time option'),
              onPressed: _addSlot,
            ),
          ),
          const SizedBox(height: 16),
          _sectionLabel('Members (tap: Required → Optional → off)'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in widget.band.members)
                FilterChip(
                  label: Text(
                    '${m.displayName ?? m.email ?? m.uid}'
                    '${_roles[m.uid] == null ? '' : ' · ${_roles[m.uid]}'}',
                  ),
                  selected: _roles[m.uid] != null,
                  onSelected: (_) => _cycleRole(m.uid),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _sectionLabel('Setlist (optional)'),
          setlistsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const Text('Could not load setlists'),
            data: (setlists) => DropdownButton<String?>(
              isExpanded: true,
              value: _setlistId,
              hint: const Text('No setlist'),
              items: [
                const DropdownMenuItem(value: null, child: Text('No setlist')),
                for (final Setlist s in setlists)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() => _setlistId = v),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _location,
            decoration: const InputDecoration(
              labelText: 'Location (optional)',
              hintText: 'e.g. Studio A',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: MonoPulseSpacing.sm),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}
