import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/band.dart';
import '../../models/event_kit.dart';
import '../../models/setlist.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/member_label.dart';
import '../../utils/snackbar.dart';
import '../../widgets/bottom_nav_or_action_bar.dart';
import '../../widgets/user_avatar.dart';

/// Event Kit editor (#53): who stands where (3×3 stage zone grid), crew &
/// guests, and the rider checklist. Every mutation autosaves the setlist.
// ponytail: zone grid, not a free-drag canvas — upgrade if beta asks.
class EventKitEditorScreen extends ConsumerStatefulWidget {
  const EventKitEditorScreen({required this.setlist, this.bandId, super.key});

  final Setlist setlist;
  final String? bandId;

  @override
  ConsumerState<EventKitEditorScreen> createState() =>
      _EventKitEditorScreenState();
}

class _EventKitEditorScreenState extends ConsumerState<EventKitEditorScreen> {
  late EventKit _kit = widget.setlist.eventKit ?? const EventKit();

  List<BandMember> get _members {
    if (widget.bandId == null) return const [];
    final bands = ref.read(bandsProvider).value ?? [];
    return bands.where((b) => b.id == widget.bandId).firstOrNull?.members ??
        const [];
  }

  Future<void> _save() async {
    final updated = widget.setlist.copyWith(
      eventKit: _kit,
      updatedAt: DateTime.now(),
    );
    try {
      final firestore = ref.read(firestoreProvider);
      if (widget.bandId != null) {
        await firestore.saveBandSetlist(updated, widget.bandId!);
      } else {
        final uid = ref.read(currentUserProvider).value?.uid;
        if (uid == null) return;
        await firestore.saveSetlist(updated, uid: uid);
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Save failed: $e');
    }
  }

  void _mutate(EventKit next) {
    setState(() => _kit = next);
    _save();
  }

  // ---- stage ----

  Future<void> _addToZone(String zoneId) async {
    final placement = await showModalBottomSheet<StagePlacement>(
      context: context,
      builder: (_) => _AddPlacementSheet(members: _members),
    );
    if (placement == null) return;
    final zone = [..._kit.stage[zoneId] ?? const <StagePlacement>[], placement];
    _mutate(_kit.copyWith(stage: {..._kit.stage, zoneId: zone}));
  }

  void _removeFromZone(String zoneId, StagePlacement p) {
    final zone = [..._kit.stage[zoneId] ?? const <StagePlacement>[]]..remove(p);
    _mutate(_kit.copyWith(stage: {..._kit.stage, zoneId: zone}));
  }

  // ---- people / rider ----

  Future<void> _addPerson() async {
    final person = await showModalBottomSheet<EventPerson>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddPersonSheet(),
    );
    if (person == null) return;
    _mutate(_kit.copyWith(people: [..._kit.people, person]));
  }

  Future<void> _addRiderItem() async {
    final label = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddRiderSheet(),
    );
    if (label == null || label.isEmpty) return;
    _mutate(
      _kit.copyWith(
        rider: [
          ..._kit.rider,
          RiderItem(label: label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mp.black,
      bottomNavigationBar: AppBottomBar.actions(
        onBack: () => Navigator.pop(context, _kit),
        title: 'Event kit',
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(MonoPulseSpacing.lg),
          children: [
            _sectionTitle('Stage plot'),
            Text(
              'Tap a zone to place people and gear. Long-press a chip to '
              'remove it. Top row is the back of the stage.',
              style: MonoPulseTypography.bodySmall.copyWith(
                color: context.mp.textSecondary,
              ),
            ),
            const SizedBox(height: MonoPulseSpacing.md),
            _stageGrid(),
            const SizedBox(height: 4),
            Center(
              child: Text(
                '▼ audience ▼',
                style: MonoPulseTypography.bodySmall.copyWith(
                  color: context.mp.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: MonoPulseSpacing.lg),
            _sectionTitle('Crew & guests'),
            for (final p in _kit.people)
              ListTile(
                dense: true,
                leading: const Icon(Icons.badge_outlined),
                title: Text(p.name),
                subtitle: Text(
                  [p.role, if (p.notes != null) p.notes!].join(' · '),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => _mutate(
                    _kit.copyWith(people: [..._kit.people]..remove(p)),
                  ),
                ),
              ),
            ActionChip(
              avatar: const Icon(Icons.person_add_alt, size: 18),
              label: const Text('Add person'),
              onPressed: _addPerson,
            ),
            const SizedBox(height: MonoPulseSpacing.lg),
            _sectionTitle('Rider / equipment'),
            for (final r in _kit.rider)
              CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  '${r.label}${r.qty != null ? ' ×${r.qty}' : ''}',
                  style: r.done
                      ? TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: context.mp.textSecondary,
                        )
                      : null,
                ),
                value: r.done,
                onChanged: (v) => _mutate(
                  _kit.copyWith(
                    rider: [
                      for (final item in _kit.rider)
                        item == r ? item.copyWith(done: v ?? false) : item,
                    ],
                  ),
                ),
                secondary: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () =>
                      _mutate(_kit.copyWith(rider: [..._kit.rider]..remove(r))),
                ),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Add rider item'),
              onPressed: _addRiderItem,
            ),
            const SizedBox(height: MonoPulseSpacing.lg),
            _sectionTitle('Role cards'),
            Text(
              'Everyone involved in this event — band, crew and guests. '
              'These print in the event-guide PDF.',
              style: MonoPulseTypography.bodySmall.copyWith(
                color: context.mp.textSecondary,
              ),
            ),
            const SizedBox(height: MonoPulseSpacing.md),
            _roleCards(),
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: MonoPulseSpacing.sm),
    child: Text(t, style: MonoPulseTypography.titleMedium),
  );

  /// Role cards (#54): band members + crew/guests, initials-avatar cards.
  Widget _roleCards() {
    final cards = <({String name, String role, String? notes})>[
      for (final m in _members)
        (
          name: memberLabel(displayName: m.displayName, email: m.email),
          role: m.musicRoles.isEmpty ? 'Band' : m.musicRoles.join(', '),
          notes: null,
        ),
      for (final p in _kit.people) (name: p.name, role: p.role, notes: p.notes),
    ];
    if (cards.isEmpty) {
      return Text(
        'No people yet — band members appear here automatically for band '
        'setlists; add crew above.',
        style: MonoPulseTypography.bodySmall.copyWith(
          color: context.mp.textTertiary,
        ),
      );
    }
    return Wrap(
      spacing: MonoPulseSpacing.md,
      runSpacing: MonoPulseSpacing.md,
      children: [for (final c in cards) _roleCard(c)],
    );
  }

  Widget _roleCard(({String name, String role, String? notes}) c) {
    return SizedBox(
      width: 150,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(MonoPulseSpacing.md),
          child: Column(
            children: [
              UserAvatar(photoURL: null, displayName: c.name, radius: 22),
              const SizedBox(height: MonoPulseSpacing.sm),
              Text(
                c.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MonoPulseTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                c.role,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MonoPulseTypography.bodySmall.copyWith(
                  color: MonoPulseColors.accentOrange,
                ),
              ),
              if (c.notes != null)
                Text(
                  c.notes!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MonoPulseTypography.bodySmall.copyWith(
                    color: context.mp.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stageGrid() {
    return Column(
      children: [
        for (var row = 0; row < 3; row++)
          // IntrinsicHeight equalizes cell heights per row; a bare `stretch`
          // would demand infinite height inside the ListView.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var col = 0; col < 3; col++)
                  Expanded(child: _zoneCell(stageZoneIds[row * 3 + col])),
              ],
            ),
          ),
      ],
    );
  }

  Widget _zoneCell(String zoneId) {
    final placements = _kit.stage[zoneId] ?? const <StagePlacement>[];
    return Padding(
      padding: const EdgeInsets.all(1),
      child: InkWell(
        onTap: () => _addToZone(zoneId),
        child: Container(
          constraints: const BoxConstraints(minHeight: 84),
          padding: const EdgeInsets.all(MonoPulseSpacing.xs),
          decoration: BoxDecoration(
            color: context.mp.surface,
            border: Border.all(color: context.mp.borderDefault),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Wrap(
            spacing: 2,
            runSpacing: 2,
            children: [
              if (placements.isEmpty)
                Icon(Icons.add, size: 14, color: context.mp.textTertiary),
              for (final p in placements)
                GestureDetector(
                  onLongPress: () => _removeFromZone(zoneId, p),
                  child: Chip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    avatar: Icon(
                      p.kind == 'member' ? Icons.person : Icons.speaker,
                      size: 12,
                    ),
                    label: Text(
                      p.label,
                      style: const TextStyle(fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddPlacementSheet extends StatelessWidget {
  const _AddPlacementSheet({required this.members});

  final List<BandMember> members;

  @override
  Widget build(BuildContext context) {
    final equipment = TextEditingController();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(MonoPulseSpacing.lg),
          children: [
            Text(
              'Place in zone',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: MonoPulseSpacing.sm),
            for (final m in members)
              ListTile(
                dense: true,
                leading: const Icon(Icons.person),
                title: Text(
                  memberLabel(displayName: m.displayName, email: m.email),
                ),
                subtitle: m.musicRoles.isEmpty
                    ? null
                    : Text(m.musicRoles.join(', ')),
                onTap: () => Navigator.pop(
                  context,
                  StagePlacement(
                    kind: 'member',
                    uid: m.uid,
                    label: memberLabel(
                      displayName: m.displayName,
                      email: m.email,
                    ),
                  ),
                ),
              ),
            TextField(
              controller: equipment,
              decoration: InputDecoration(
                labelText: 'Equipment (e.g. Amp, Drum kit, Monitor)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    final label = equipment.text.trim();
                    if (label.isEmpty) return;
                    Navigator.pop(
                      context,
                      StagePlacement(kind: 'equipment', label: label),
                    );
                  },
                ),
              ),
              onSubmitted: (v) {
                final label = v.trim();
                if (label.isEmpty) return;
                Navigator.pop(
                  context,
                  StagePlacement(kind: 'equipment', label: label),
                );
              },
            ),
            const SizedBox(height: MonoPulseSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _AddPersonSheet extends StatefulWidget {
  const _AddPersonSheet();

  @override
  State<_AddPersonSheet> createState() => _AddPersonSheetState();
}

class _AddPersonSheetState extends State<_AddPersonSheet> {
  final _name = TextEditingController();
  final _role = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add crew / guest',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: MonoPulseSpacing.md),
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: MonoPulseSpacing.md),
            TextField(
              controller: _role,
              decoration: const InputDecoration(
                labelText: 'Role (Photographer, Manager, +1…)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: MonoPulseSpacing.md),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
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
                  onPressed: () {
                    final name = _name.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(
                      context,
                      EventPerson(
                        name: name,
                        role: _role.text.trim(),
                        notes: _notes.text.trim().isEmpty
                            ? null
                            : _notes.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddRiderSheet extends StatelessWidget {
  const _AddRiderSheet();

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        child: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Rider item (e.g. XLR cables ×4)',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
      ),
    );
  }
}
