import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/band.dart';
import '../../models/event_kit.dart';
import '../../models/lineup.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/music_role_icon.dart';
import '../../widgets/role_picker_widget.dart';

/// What the sheet hands back. The caller owns persistence: it writes
/// `performerIds` onto the song it opened the sheet for, keeps `kit` as the
/// setlist's new Event Kit (the roster lives there), and adds every id in
/// `allSongIds` to *every* song in the setlist.
typedef PerformerSheetResult = ({
  List<String> performerIds,
  EventKit kit,
  Set<String> allSongIds,
});

/// "Who plays this song": a checklist over the event roster, with inline
/// creation of placeholder people (guests who aren't app users) and a manual
/// link from a placeholder to a real band member.
Future<PerformerSheetResult?> showPerformerSheet({
  required BuildContext context,
  required List<String> selected,
  required EventKit kit,
  required List<BandMember> members,
  required int songNumber,
  required String songTitle,
}) {
  return showModalBottomSheet<PerformerSheetResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _PerformerSheet(
      selected: selected,
      kit: kit,
      members: members,
      songNumber: songNumber,
      songTitle: songTitle,
    ),
  );
}

class _PerformerSheet extends StatefulWidget {
  const _PerformerSheet({
    required this.selected,
    required this.kit,
    required this.members,
    required this.songNumber,
    required this.songTitle,
  });

  final List<String> selected;
  final EventKit kit;
  final List<BandMember> members;
  final int songNumber;
  final String songTitle;

  @override
  State<_PerformerSheet> createState() => _PerformerSheetState();
}

class _PerformerSheetState extends State<_PerformerSheet> {
  late final Set<String> _selected = {...widget.selected};
  late EventKit _kit = widget.kit;
  final _allSongIds = <String>{};

  /// Everyone offered: kit roster + band members not on it yet.
  List<EventPerson> get _lineup => lineupFor(_kit, widget.members);

  void _toggle(EventPerson person, bool on) {
    setState(() {
      if (on) {
        _selected.add(person.id);
        _materialise(person);
      } else {
        _selected.remove(person.id);
        _allSongIds.remove(person.id);
      }
    });
  }

  /// A band member is only written into the roster once actually assigned.
  void _materialise(EventPerson person) {
    if (_kit.people.any((p) => p.id == person.id)) return;
    _kit = _kit.copyWith(people: [..._kit.people, person]);
  }

  void _setAllSongs(EventPerson person, bool on) {
    setState(() {
      if (on) {
        _allSongIds.add(person.id);
        _selected.add(person.id);
        _materialise(person);
      } else {
        _allSongIds.remove(person.id);
      }
    });
  }

  Future<void> _linkToMember(EventPerson person) async {
    final member = await showModalBottomSheet<BandMember>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Link to band member')),
            for (final m in widget.members)
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(m.displayName ?? m.email ?? m.uid),
                onTap: () => Navigator.pop(context, m),
              ),
          ],
        ),
      ),
    );
    if (member == null) return;
    setState(() {
      _kit = _kit.copyWith(
        people: [
          for (final p in _kit.people)
            if (p.id == person.id)
              p.copyWith(
                uid: member.uid,
                name: p.name.isEmpty ? member.displayName : null,
              )
            else
              p,
        ],
      );
    });
  }

  Future<void> _addPerson() async {
    final result = await showModalBottomSheet<({String name, String role, bool all})>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _AddPersonForm(),
    );
    if (result == null) return;
    final person = EventPerson(
      id: const Uuid().v4(),
      name: result.name,
      role: result.role,
    );
    setState(() {
      _kit = _kit.copyWith(people: [..._kit.people, person]);
      _selected.add(person.id);
      if (result.all) _allSongIds.add(person.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lineup = _lineup;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Who plays #${widget.songNumber}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              widget.songTitle,
              style: TextStyle(color: context.mp.textSecondary),
            ),
            const SizedBox(height: MonoPulseSpacing.md),
            if (lineup.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: MonoPulseSpacing.lg,
                ),
                child: Text(
                  'No one on the lineup yet — add the musicians playing '
                  'this gig.',
                  style: TextStyle(color: context.mp.textSecondary),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final person in lineup)
                      CheckboxListTile(
                        key: ValueKey('performer_${person.id}'),
                        value: _selected.contains(person.id),
                        onChanged: (on) => _toggle(person, on ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(person.name),
                        subtitle: Text(
                          [
                            if (person.role.isNotEmpty) person.role,
                            if (person.uid == null) 'guest',
                            if (_allSongIds.contains(person.id)) 'every song',
                          ].join(' · '),
                        ),
                        secondary: PopupMenuButton<String>(
                          onSelected: (action) => switch (action) {
                            'all' => _setAllSongs(
                              person,
                              !_allSongIds.contains(person.id),
                            ),
                            'link' => _linkToMember(person),
                            _ => null,
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'all',
                              child: Text(
                                _allSongIds.contains(person.id)
                                    ? 'Only this song'
                                    : 'Plays every song',
                              ),
                            ),
                            if (person.uid == null && widget.members.isNotEmpty)
                              const PopupMenuItem(
                                value: 'link',
                                child: Text('Link to member'),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            const Divider(),
            TextButton.icon(
              onPressed: _addPerson,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Add person'),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, (
                  performerIds: _selected.toList(),
                  kit: _kit,
                  allSongIds: _allSongIds,
                )),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Name + role + "plays every song" for a guest who isn't an app user.
class _AddPersonForm extends StatefulWidget {
  const _AddPersonForm();

  @override
  State<_AddPersonForm> createState() => _AddPersonFormState();
}

class _AddPersonFormState extends State<_AddPersonForm> {
  final _nameController = TextEditingController();
  String _role = '';
  bool _allSongs = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickRole() async {
    final roles = await showRolePicker(
      context: context,
      currentRoles: const [],
      title: 'Role',
    );
    if (roles == null || roles.isEmpty) return;
    setState(() => _role = MusicRoleIcon.getDisplayName(roles.first));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: MonoPulseSpacing.lg,
        right: MonoPulseSpacing.lg,
        top: MonoPulseSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + MonoPulseSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add person', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: MonoPulseSpacing.md),
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Anna',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.md),
          OutlinedButton.icon(
            onPressed: _pickRole,
            icon: const Icon(Icons.music_note),
            label: Text(_role.isEmpty ? 'Pick role' : _role),
          ),
          CheckboxListTile(
            value: _allSongs,
            onChanged: (v) => setState(() => _allSongs = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('Plays every song'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () {
                final name = _nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(context, (
                  name: name,
                  role: _role,
                  all: _allSongs,
                ));
              },
              child: const Text('Add'),
            ),
          ),
        ],
      ),
    );
  }
}
