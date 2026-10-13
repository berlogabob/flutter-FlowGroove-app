import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/band.dart';
import '../../models/event_access.dart';
import '../../models/event_kit.dart';
import '../../models/lineup.dart';
import '../../models/setlist.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/data/data_providers.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/member_label.dart';
import '../../utils/music_role_icon.dart';
import '../../utils/snackbar.dart';
import '../../utils/stage_gear.dart';
import '../../widgets/bottom_nav_or_action_bar.dart';
import '../../widgets/user_avatar.dart';

/// Event Kit editor (#53): who stands where (3×3 stage zone grid), crew &
/// guests, and the rider checklist. Every mutation autosaves the setlist.
// ponytail: zone grid, not a free-drag canvas — upgrade if beta asks.
class EventKitEditorScreen extends ConsumerStatefulWidget {
  const EventKitEditorScreen({
    required this.setlist,
    this.bandId,
    this.ownerUid,
    this.access = const {},
    this.isMember = true,
    super.key,
  });

  final Setlist setlist;
  final String? bandId;
  final String? ownerUid;

  /// Which areas this viewer may see and change (`area -> view|edit`).
  ///
  /// A band member arrives with every area at `edit`; a claimed sound engineer
  /// with `stage: edit` and `rider: view`. A personal owner has everything;
  /// a personal guest keeps the access returned by the event callable.
  final Map<String, String> access;

  /// The roster is not an area — it is what the grants are DERIVED from, and
  /// the rules refuse an area editor's write to it. So crew management and the
  /// share links belong to band members or the personal owner.
  final bool isMember;

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

  bool get _isOwner =>
      widget.bandId == null &&
      (widget.ownerUid == null ||
          widget.ownerUid == ref.read(currentUserProvider).value?.uid);

  bool get _isMember => widget.bandId == null ? _isOwner : widget.isMember;

  Map<String, String> get _access =>
      _isOwner || (widget.bandId != null && widget.access.isEmpty)
      ? {for (final a in EventArea.all) a: EventAccessLevel.edit}
      : widget.access;

  bool _canView(String area) => canViewArea(_access, area);
  bool _canEdit(String area) => canEditArea(_access, area);

  /// Which songs each person is assigned to (set in the setlist editor).
  Map<String, List<int>> get _songNumbers =>
      songNumbersByPerformer(widget.setlist.effectiveItems);

  /// Saves ONE area through a dotted field path.
  ///
  /// Not a whole-setlist save: stage and rider have their own permissions and
  /// their own editors (a sound engineer moving speakers, the band reordering
  /// the set), so a full-document write would erase whoever saved first.
  Future<void> _save(String area) async {
    try {
      await ref
          .read(firestoreProvider)
          .updateEventKitArea(
            setlistId: widget.setlist.id,
            area: area,
            // Reuse EventKit's own serializer rather than re-encoding here.
            value: _kit.toJson()[area],
            bandId: widget.bandId,
            uid: widget.ownerUid ?? ref.read(currentUserProvider).value?.uid,
          );
    } catch (e) {
      // Root messenger: this autosave often completes after the editor was
      // closed, where a context-bound snackbar would silently drop the error.
      if (mounted) {
        showAppSnackBar(context, 'Save failed: $e');
      } else {
        showGlobalSnackBar('Event kit save failed: $e', error: true);
      }
    }
  }

  void _mutate(EventKit next, String area) {
    setState(() => _kit = next);
    _save(area);
  }

  // ---- stage ----

  Future<void> _addToZone(String zoneId) async {
    final placements = await showModalBottomSheet<List<StagePlacement>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddPlacementSheet(
        members: _members,
        placedLabels: {
          for (final list in _kit.stage.values)
            for (final placement in list) placement.label,
        },
      ),
    );
    if (placements == null || placements.isEmpty) return;
    final zone = [
      ..._kit.stage[zoneId] ?? const <StagePlacement>[],
      ...placements,
    ];
    _mutate(_kit.copyWith(stage: {..._kit.stage, zoneId: zone}), 'stage');
  }

  void _removeFromZone(String zoneId, StagePlacement p) {
    final zone = [..._kit.stage[zoneId] ?? const <StagePlacement>[]]..remove(p);
    _mutate(_kit.copyWith(stage: {..._kit.stage, zoneId: zone}), 'stage');
  }

  // ---- people / rider ----

  Future<void> _addPerson() async {
    final person = await showModalBottomSheet<EventPerson>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddPersonSheet(),
    );
    if (person == null) return;
    _mutate(_kit.copyWith(people: [..._kit.people, person]), 'people');
  }

  Future<void> _editPerson(EventPerson person) async {
    final edited = await showModalBottomSheet<EventPerson>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddPersonSheet(person: person),
    );
    if (edited == null) return;
    _mutate(
      _kit.copyWith(
        people: [for (final p in _kit.people) p.id == person.id ? edited : p],
      ),
      'people',
    );
  }

  /// Mint a link for one person and copy it.
  ///
  /// The raw token comes back exactly once — only its hash is stored — so it is
  /// put on the clipboard immediately and shown for as long as the snackbar
  /// lasts. Losing it just means minting another.
  Future<void> _share(EventPerson person) async {
    final bandId = widget.bandId;
    if (person.access.isEmpty) {
      showAppSnackBar(
        context,
        '${person.name} has no access yet — set a role first.',
      );
      return;
    }
    try {
      final token = await ref
          .read(eventShareServiceProvider)
          .createShare(
            bandId: bandId,
            ownerUid: bandId == null
                ? ref.read(currentUserProvider).value?.uid
                : null,
            setlistId: widget.setlist.id,
            participantId: person.id,
          );
      final link = 'https://app.flowgroove.app/#/event?t=$token';
      await Clipboard.setData(ClipboardData(text: link));
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Link for ${person.name} copied — they will see '
        '${_areaSummary(person.access)}.',
      );
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Could not create the link: $e');
    }
  }

  static String _areaSummary(Map<String, String> access) {
    final parts = [
      for (final area in EventArea.all)
        if (canViewArea(access, area))
          canEditArea(access, area)
              ? '${EventArea.label(area)} (can edit)'
              : EventArea.label(area),
    ];
    return parts.isEmpty ? 'nothing yet' : parts.join(', ');
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
      'rider',
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
            if (_canView(EventArea.stage)) ...[
              _sectionTitle('Stage plot'),
              Text(
                _canEdit(EventArea.stage)
                    ? 'Tap a zone to place people and gear. Long-press a chip to '
                          'remove it. Top row is the back of the stage.'
                    : 'Shared with you to read. Top row is the back of the stage.',
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
            ],
            // The roster carries who else is on the gig and, for members, the
            // share links. An area editor has no business reshaping it — and
            // the rules refuse the write anyway, so never offer it.
            if (_isMember) ...[
              _sectionTitle('Crew & guests'),
              for (final p in _kit.people)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(p.name),
                  onTap: widget.bandId == null ? () => _editPerson(p) : null,
                  subtitle: Text(
                    [
                      p.role,
                      if (_songNumbers[p.id] case final songs?
                          when songs.isNotEmpty)
                        songs.map((n) => '#$n').join(', '),
                      if (p.notes != null) p.notes!,
                    ].join(' · '),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.link, size: 18),
                        tooltip: 'Share this event with ${p.name}',
                        onPressed: () => _share(p),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => _mutate(
                          _kit.copyWith(people: [..._kit.people]..remove(p)),
                          'people',
                        ),
                      ),
                    ],
                  ),
                ),
              ActionChip(
                avatar: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('Add person'),
                onPressed: _addPerson,
              ),
              const SizedBox(height: MonoPulseSpacing.lg),
            ],
            if (_canView(EventArea.rider)) ...[
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
                  onChanged: !_canEdit(EventArea.rider)
                      ? null
                      : (v) => _mutate(
                          _kit.copyWith(
                            rider: [
                              for (final item in _kit.rider)
                                item == r
                                    ? item.copyWith(done: v ?? false)
                                    : item,
                            ],
                          ),
                          'rider',
                        ),
                  secondary: !_canEdit(EventArea.rider)
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => _mutate(
                            _kit.copyWith(rider: [..._kit.rider]..remove(r)),
                            'rider',
                          ),
                        ),
                ),
              if (_canEdit(EventArea.rider))
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Add rider item'),
                  onPressed: _addRiderItem,
                ),
              const SizedBox(height: MonoPulseSpacing.lg),
            ],
            if (_isMember) ...[
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
            ],
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
  ///
  /// Built from [lineupFor] rather than by concatenating the two lists: once a
  /// roster entry is linked to a member's account (which is how event guests
  /// work), naive concatenation renders that person twice.
  Widget _roleCards() {
    final cards = <({String name, String role, String? notes})>[
      for (final p in lineupFor(_kit, _members))
        (
          name: p.name.isEmpty ? 'Member' : p.name,
          role: p.role.isEmpty ? 'Band' : p.role,
          notes: p.notes,
        ),
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
        // Inert when the plot is shared read-only — no add affordance at
        // all, rather than a control that taps into a permission error.
        onTap: _canEdit(EventArea.stage) ? () => _addToZone(zoneId) : null,
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
                  onLongPress: _canEdit(EventArea.stage)
                      ? () => _removeFromZone(zoneId, p)
                      : null,
                  child: Chip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    avatar: Text(
                      p.icon ?? StageGear.iconFor(p.label, kind: p.kind),
                      style: const TextStyle(fontSize: 11),
                    ),
                    label: Text(
                      p.displayLabel,
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

class _AddPlacementSheet extends StatefulWidget {
  const _AddPlacementSheet({required this.members, required this.placedLabels});

  final List<BandMember> members;
  final Set<String> placedLabels;

  @override
  State<_AddPlacementSheet> createState() => _AddPlacementSheetState();
}

class _AddPlacementSheetState extends State<_AddPlacementSheet> {
  final _search = TextEditingController();
  final List<({StagePlacement placement, GearEntry? entry})> _picks = [];
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _memberPicked(BandMember member) =>
      _picks.any((pick) => pick.placement.uid == member.uid);

  bool _gearPicked(GearEntry entry) =>
      _picks.any((pick) => pick.entry?.id == entry.id);

  void _toggleMember(BandMember member) {
    final index = _picks.indexWhere((pick) => pick.placement.uid == member.uid);
    setState(() {
      if (index != -1) {
        _picks.removeAt(index);
        return;
      }
      final label = memberLabel(
        displayName: member.displayName,
        email: member.email,
      );
      final icon = member.musicRoles.isEmpty
          ? '🧑'
          : MusicRoleIcon.getIcon(member.musicRoles.first) ?? '🧑';
      _picks.add((
        placement: StagePlacement(
          kind: 'member',
          uid: member.uid,
          label: label,
          icon: icon,
        ),
        entry: null,
      ));
    });
  }

  void _toggleGear(GearEntry entry) {
    final index = _picks.indexWhere((pick) => pick.entry?.id == entry.id);
    setState(() {
      if (index != -1) {
        _picks.removeAt(index);
      } else {
        _picks.add((
          placement: StagePlacement(
            kind: 'equipment',
            label: entry.name,
            icon: entry.icon,
          ),
          entry: entry,
        ));
      }
    });
  }

  void _addCustomGear(String value) {
    final label = value.trim();
    if (label.isEmpty) return;
    final alreadyPicked = _picks.any(
      (pick) =>
          pick.placement.kind == 'equipment' &&
          pick.placement.label.toLowerCase() == label.toLowerCase(),
    );
    setState(() {
      if (!alreadyPicked) {
        _picks.add((
          placement: StagePlacement(
            kind: 'equipment',
            label: label,
            icon: StageGear.iconFor(label),
          ),
          entry: null,
        ));
      }
      _search.clear();
      _query = '';
    });
  }

  Future<void> _editBrand(int index) async {
    final pick = _picks[index];
    final entry = pick.entry;
    if (entry == null || !entry.brandable) return;
    final result = await _pickBrand(
      context,
      entry.category,
      pick.placement.brand,
    );
    if (!mounted || result == null) return;
    final placement = pick.placement;
    setState(() {
      _picks[index] = (
        placement: StagePlacement(
          kind: placement.kind,
          uid: placement.uid,
          label: placement.label,
          icon: placement.icon,
          brand: result.isEmpty ? null : result,
        ),
        entry: entry,
      );
    });
  }

  Future<String?> _pickBrand(
    BuildContext context,
    String category,
    String? current,
  ) async {
    final brands = StageGear.brandsFor(category);
    var selected = current ?? '';
    final custom = TextEditingController(
      text: brands.contains(current) ? '' : current ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Brand (optional)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final brand in brands)
                      ChoiceChip(
                        label: Text(brand),
                        selected: selected == brand,
                        onSelected: (isSelected) => setDialogState(() {
                          selected = isSelected ? brand : '';
                          custom.clear();
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: MonoPulseSpacing.md),
                TextField(
                  controller: custom,
                  decoration: const InputDecoration(
                    labelText: 'Custom brand',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) =>
                      setDialogState(() => selected = value.trim()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('Clear'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selected.trim()),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
    custom.dispose();
    return result;
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(top: MonoPulseSpacing.sm, bottom: 4),
    child: Text(
      label,
      style: MonoPulseTypography.labelSmall.copyWith(
        color: context.mp.textSecondary,
      ),
    ),
  );

  Widget _gearTile(GearEntry entry) {
    final isSelected = _gearPicked(entry);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        onTap: () => _toggleGear(entry),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(
            horizontal: MonoPulseSpacing.md,
            vertical: MonoPulseSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? MonoPulseColors.accentOrange10
                : context.mp.surfaceOverlay,
            borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
            border: Border.all(
              color: isSelected
                  ? MonoPulseColors.accentOrange
                  : context.mp.textTertiary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Text(entry.icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: MonoPulseSpacing.sm),
              Expanded(
                child: Text(
                  entry.name,
                  style: MonoPulseTypography.bodySmall.copyWith(
                    color: isSelected
                        ? MonoPulseColors.accentOrange
                        : context.mp.textHighEmphasis,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check,
                  size: 18,
                  color: MonoPulseColors.accentOrange,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final trimmedQuery = _query.trim();
    final gear = StageGear.search(trimmedQuery);
    final suggestions = trimmedQuery.isEmpty
        ? StageGear.suggestedFor(
                widget.members.expand((member) => member.musicRoles),
              )
              .map(StageGear.byId)
              .whereType<GearEntry>()
              .where(
                (entry) =>
                    !widget.placedLabels.contains(entry.name) &&
                    !_gearPicked(entry),
              )
              .toList()
        : const <GearEntry>[];
    final hasExactGear = StageGear.catalog.any(
      (entry) => entry.name.toLowerCase() == trimmedQuery.toLowerCase(),
    );
    final gearRows = <Widget>[];
    String? category;
    for (final entry in gear) {
      if (trimmedQuery.isEmpty && category != entry.category) {
        category = entry.category;
        gearRows.add(_sectionLabel(category));
      }
      gearRows.add(_gearTile(entry));
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
        child: SizedBox(
          height:
              (mediaQuery.size.height - mediaQuery.viewInsets.bottom) * 0.85,
          child: Padding(
            padding: const EdgeInsets.all(MonoPulseSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add to zone',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: MonoPulseSpacing.sm),
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Search gear or type your own…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _search.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        MonoPulseRadius.small,
                      ),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: MonoPulseSpacing.md,
                      vertical: MonoPulseSpacing.sm,
                    ),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                  // Enter adds the typed text as custom gear, so a quick
                  // "sandbags<enter>" never needs the tap-the-row detour.
                  onSubmitted: _addCustomGear,
                  textInputAction: TextInputAction.search,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(top: MonoPulseSpacing.sm),
                    children: [
                      if (_picks.isNotEmpty) ...[
                        _sectionLabel('Selected'),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (var i = 0; i < _picks.length; i++)
                              InputChip(
                                label: Text(
                                  '${_picks[i].placement.icon ?? StageGear.iconFor(_picks[i].placement.label, kind: _picks[i].placement.kind)} '
                                  '${_picks[i].placement.displayLabel}',
                                ),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () =>
                                    setState(() => _picks.removeAt(i)),
                                selected: true,
                                onSelected: _picks[i].entry?.brandable ?? false
                                    ? (_) => _editBrand(i)
                                    : null,
                                backgroundColor: MonoPulseColors.accentOrange10,
                                selectedColor: MonoPulseColors.accentOrange10,
                                padding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                          ],
                        ),
                        const SizedBox(height: MonoPulseSpacing.sm),
                      ],
                      if (suggestions.isNotEmpty) ...[
                        _sectionLabel('Likely needed'),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final entry in suggestions)
                              ActionChip(
                                label: Text('${entry.icon} ${entry.name}'),
                                onPressed: () => _toggleGear(entry),
                              ),
                          ],
                        ),
                        const SizedBox(height: MonoPulseSpacing.sm),
                      ],
                      if (widget.members.isNotEmpty) ...[
                        _sectionLabel('Band members'),
                        for (final member in widget.members)
                          Builder(
                            builder: (context) {
                              final isSelected = _memberPicked(member);
                              final icon = member.musicRoles.isEmpty
                                  ? '🧑'
                                  : MusicRoleIcon.getIcon(
                                          member.musicRoles.first,
                                        ) ??
                                        '🧑';
                              return ListTile(
                                dense: true,
                                selected: isSelected,
                                selectedColor: MonoPulseColors.accentOrange,
                                selectedTileColor:
                                    MonoPulseColors.accentOrange10,
                                leading: Text(
                                  icon,
                                  style: const TextStyle(fontSize: 18),
                                ),
                                title: Text(
                                  memberLabel(
                                    displayName: member.displayName,
                                    email: member.email,
                                  ),
                                ),
                                subtitle: member.musicRoles.isEmpty
                                    ? null
                                    : Text(
                                        member.musicRoles
                                            .map(MusicRoleIcon.getDisplayName)
                                            .join(', '),
                                      ),
                                trailing: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        size: 18,
                                        color: MonoPulseColors.accentOrange,
                                      )
                                    : null,
                                onTap: () => _toggleMember(member),
                              );
                            },
                          ),
                      ],
                      _sectionLabel('Gear'),
                      ...gearRows,
                      if (trimmedQuery.isNotEmpty && !hasExactGear)
                        ListTile(
                          dense: true,
                          leading: Text(
                            StageGear.iconFor(trimmedQuery),
                            style: const TextStyle(fontSize: 18),
                          ),
                          title: Text('Add "$trimmedQuery"'),
                          onTap: () => _addCustomGear(trimmedQuery),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: MonoPulseSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: MonoPulseSpacing.sm),
                    ElevatedButton(
                      onPressed: _picks.isEmpty
                          ? null
                          : () => Navigator.pop(context, [
                              for (final pick in _picks) pick.placement,
                            ]),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MonoPulseColors.accentOrange,
                        foregroundColor: context.mp.textPrimary,
                      ),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Roles offered as one-tap chips — the ones that actually turn up at a gig
/// and need different things from the event.
const _suggestedRoles = [
  EventRole.venue,
  EventRole.client,
  EventRole.performingGuest,
  'sound_engineer',
  'videographer',
  'photographer',
  'manager',
];

/// "They will see…" for the role currently typed.
class _AccessPreview extends StatelessWidget {
  const _AccessPreview({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final preset = presetForRole(role);
    final granted = [
      for (final area in EventArea.all)
        if (canViewArea(preset.access, area)) area,
    ];
    final hidden = [
      for (final area in EventArea.all)
        if (!canViewArea(preset.access, area)) area,
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MonoPulseSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: context.mp.borderDefault),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('They will see', style: MonoPulseTypography.labelSmall),
          const SizedBox(height: 4),
          for (final area in granted)
            Text(
              canEditArea(preset.access, area)
                  ? '+ ${EventArea.label(area)}  — can edit'
                  : '+ ${EventArea.label(area)}',
              style: MonoPulseTypography.bodySmall,
            ),
          if (granted.isEmpty)
            Text('Nothing yet.', style: MonoPulseTypography.bodySmall),
          for (final area in hidden)
            Text(
              '\u2212 ${EventArea.label(area)}',
              style: MonoPulseTypography.bodySmall.copyWith(
                color: context.mp.textTertiary,
              ),
            ),
          if (preset.canSuggest) ...[
            const SizedBox(height: 4),
            Text(
              'Can suggest changes (the band decides).',
              style: MonoPulseTypography.bodySmall.copyWith(
                color: MonoPulseColors.accentOrange,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddPersonSheet extends StatefulWidget {
  const _AddPersonSheet({this.person});

  final EventPerson? person;

  @override
  State<_AddPersonSheet> createState() => _AddPersonSheetState();
}

class _AddPersonSheetState extends State<_AddPersonSheet> {
  late final _name = TextEditingController(text: widget.person?.name);
  late final _role = TextEditingController(text: widget.person?.role);
  late final _notes = TextEditingController(text: widget.person?.notes);

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
              widget.person == null ? 'Add crew / guest' : 'Edit crew / guest',
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
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Role (Photographer, Manager, +1…)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: MonoPulseSpacing.sm),
            Wrap(
              spacing: MonoPulseSpacing.sm,
              runSpacing: MonoPulseSpacing.xs,
              children: [
                for (final role in _suggestedRoles)
                  ActionChip(
                    label: Text(MusicRoleIcon.getDisplayWithIcon(role)),
                    onPressed: () => setState(() => _role.text = role),
                  ),
              ],
            ),
            const SizedBox(height: MonoPulseSpacing.md),
            // What this person will actually receive, shown BEFORE the link is
            // made. Sharing a whole event with someone who only needs the
            // running order is both a leak and a support call ("I don't
            // understand this"), so the grant is never invisible.
            _AccessPreview(role: _role.text),
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
                      // The role sets the default grant; it can be widened per
                      // person afterwards without redefining the role itself.
                      EventPerson(
                        id: widget.person?.id ?? const Uuid().v4(),
                        uid: widget.person?.uid,
                        access: widget.person?.role == _role.text.trim()
                            ? widget.person!.access
                            : presetForRole(_role.text.trim()).access,
                        canSuggest: widget.person?.role == _role.text.trim()
                            ? widget.person!.canSuggest
                            : presetForRole(_role.text.trim()).canSuggest,
                        name: name,
                        role: _role.text.trim(),
                        notes: _notes.text.trim().isEmpty
                            ? null
                            : _notes.text.trim(),
                      ),
                    );
                  },
                  child: Text(widget.person == null ? 'Add' : 'Save'),
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
