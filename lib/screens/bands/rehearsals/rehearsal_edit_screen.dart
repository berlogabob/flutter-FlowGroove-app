import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../models/band.dart';
import '../../../models/rehearsal.dart';
import '../../../models/setlist.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../providers/data/data_providers.dart';
import '../../../services/analytics_service.dart';
import '../../../theme/mono_pulse_theme.dart';
import '../../../utils/member_label.dart';
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
  DateTime? _responseDeadline;
  late String _venueType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.rehearsal;
    _title = TextEditingController(text: r?.title ?? '');
    _location = TextEditingController(text: r?.location ?? '');
    _notes = TextEditingController(text: r?.notes ?? '');
    _responseDeadline = r?.responseDeadline;
    _venueType = r?.effectiveVenueType ?? Rehearsal.venueUndecided;
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

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _responseDeadline ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _responseDeadline == null
          ? const TimeOfDay(hour: 18, minute: 0)
          : TimeOfDay.fromDateTime(_responseDeadline!),
      helpText: 'Respond by',
    );
    if (time == null) return;
    setState(() {
      _responseDeadline =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
      location: _venueType == Rehearsal.venueCustom &&
              _location.text.trim().isNotEmpty
          ? _location.text.trim()
          : null,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      status: existing?.status ?? Rehearsal.statusCollecting,
      confirmedSlotId: existing?.confirmedSlotId,
      responseDeadline: _responseDeadline,
      venueType: _venueType,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      await ref.read(rehearsalRepositoryProvider).saveRehearsal(rehearsal);
      if (existing == null) {
        AnalyticsService.logRehearsalCreated(bandId: widget.band.id);
      }
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
          const SizedBox(height: MonoPulseSpacing.lg),
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
          const SizedBox(height: MonoPulseSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.alarm),
              label: Text(
                _responseDeadline == null
                    ? 'Set response deadline (optional)'
                    : 'Respond by ${formatDeadline(_responseDeadline!)}',
              ),
              onPressed: _pickDeadline,
            ),
          ),
          if (_responseDeadline != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _responseDeadline = null),
                child: const Text('Clear deadline'),
              ),
            ),
          const SizedBox(height: MonoPulseSpacing.lg),
          _sectionLabel('Members (tap: Required → Optional → off)'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in widget.band.members)
                FilterChip(
                  label: Text(
                    '${memberLabel(displayName: m.displayName, email: m.email)}'
                    '${_roles[m.uid] == null ? '' : ' · ${_roles[m.uid]}'}',
                  ),
                  selected: _roles[m.uid] != null,
                  onSelected: (_) => _cycleRole(m.uid),
                ),
            ],
          ),
          const SizedBox(height: MonoPulseSpacing.lg),
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
          const SizedBox(height: MonoPulseSpacing.lg),
          _sectionLabel('Venue'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Not decided'),
                selected: _venueType == Rehearsal.venueUndecided,
                onSelected: (_) =>
                    setState(() => _venueType = Rehearsal.venueUndecided),
              ),
              ChoiceChip(
                label: const Text('Custom place'),
                selected: _venueType == Rehearsal.venueCustom,
                onSelected: (_) =>
                    setState(() => _venueType = Rehearsal.venueCustom),
              ),
              Tooltip(
                message: 'Coming soon',
                child: ChoiceChip(
                  label: const Text('Rehearsal studio'),
                  selected: _venueType == Rehearsal.venueStudio,
                  onSelected: null,
                ),
              ),
            ],
          ),
          if (_venueType == Rehearsal.venueCustom) ...[
            const SizedBox(height: MonoPulseSpacing.md),
            TextField(
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'Location',
                hintText: 'e.g. Studio A',
              ),
            ),
          ],
          const SizedBox(height: MonoPulseSpacing.lg),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
            maxLines: 3,
          ),
          const SizedBox(height: MonoPulseSpacing.xxl),
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
