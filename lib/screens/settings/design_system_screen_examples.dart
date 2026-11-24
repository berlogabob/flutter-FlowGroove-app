import 'package:material_ui/material_ui.dart';

import '../../models/song.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_filter_chip.dart';
import '../../widgets/chord_chart_view.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/field_label.dart';
import '../../widgets/setlist_break_row.dart';
import '../../widgets/setlist_song_row.dart';

/// Phone-sized, interactive examples that exercise the same shared UI pieces
/// musicians use in the setlist and song flows.
class FlowGrooveScreenExamples extends StatefulWidget {
  const FlowGrooveScreenExamples({super.key});

  @override
  State<FlowGrooveScreenExamples> createState() =>
      _FlowGrooveScreenExamplesState();
}

enum _ScreenExample { setlist, song, addSong }

class _FlowGrooveScreenExamplesState extends State<FlowGrooveScreenExamples> {
  _ScreenExample _selected = _ScreenExample.setlist;
  bool _playing = false;
  final Set<String> _selectedSections = {'Verse', 'Chorus'};

  static final DateTime _sampleDate = DateTime.utc(2026, 10, 29);
  static final List<Song> _songs = [
    _song('awake', 'Awake', 'Roumé', 'C#m', 96),
    _song('viento', 'Viento Helado', 'Sol Vk', 'Am', 120),
    _song('long-way', 'The Long Way', 'Roumé', 'D', 108),
    _song('ocean', 'Ocean Inside', 'Sol Vk', 'Bm', 84),
  ];

  static Song _song(
    String id,
    String title,
    String artist,
    String key,
    int bpm,
  ) => Song(
    id: id,
    title: title,
    artist: artist,
    ourKey: key,
    ourBPM: bpm,
    createdAt: _sampleDate,
    updatedAt: _sampleDate,
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SegmentedButton<_ScreenExample>(
        segments: const [
          ButtonSegment(
            value: _ScreenExample.setlist,
            label: Text('Setlist view'),
          ),
          ButtonSegment(value: _ScreenExample.song, label: Text('Song view')),
          ButtonSegment(value: _ScreenExample.addSong, label: Text('Add song')),
        ],
        selected: {_selected},
        onSelectionChanged: (selection) => setState(() {
          _selected = selection.first;
          _playing = false;
        }),
      ),
      const SizedBox(height: MonoPulseSpacing.md),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Container(
            height: 600,
            decoration: BoxDecoration(
              color: context.mp.surface,
              border: Border.all(color: MonoPulseColors.charcoal, width: 2),
              borderRadius: BorderRadius.circular(MonoPulseRadius.xlarge),
              boxShadow: [
                BoxShadow(
                  color: context.mp.borderStrong.withValues(alpha: 0.35),
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _statusBar(context),
                _brandBar(context),
                Expanded(
                  child: _selected == _ScreenExample.setlist
                      ? _setlistView(context)
                      : _selected == _ScreenExample.song
                      ? _songView(context)
                      : _addSongView(context),
                ),
                if (_selected == _ScreenExample.addSong)
                  _saveSongBar(context)
                else
                  _transportBar(context),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _statusBar(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(MonoPulseSpacing.mdPlus, MonoPulseSpacing.sm, MonoPulseSpacing.mdPlus, MonoPulseSpacing.xs),
    child: Row(
      children: [
        Text('9:41', style: Theme.of(context).textTheme.labelSmall),
        const Spacer(),
        Icon(
          Icons.signal_cellular_alt,
          size: 15,
          color: context.mp.textPrimary,
        ),
        const SizedBox(width: MonoPulseSpacing.xs),
        Icon(Icons.wifi, size: 15, color: context.mp.textPrimary),
        const SizedBox(width: MonoPulseSpacing.xs),
        Icon(Icons.battery_full, size: 16, color: context.mp.textPrimary),
      ],
    ),
  );

  Widget _brandBar(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(MonoPulseSpacing.mdPlus, MonoPulseSpacing.sm, MonoPulseSpacing.mdPlus, MonoPulseSpacing.sm),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: context.mp.borderDefault)),
    ),
    child: Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: MonoPulseColors.accentOrange,
            border: Border.all(color: MonoPulseColors.charcoal),
            borderRadius: BorderRadius.circular(MonoPulseRadius.button),
          ),
          child: const Icon(
            Icons.graphic_eq,
            size: 18,
            color: MonoPulseColors.charcoal,
          ),
        ),
        const SizedBox(width: MonoPulseSpacing.sm),
        const Text('FlowGroove', style: MonoPulseTypography.labelMedium),
        const Spacer(),
        Icon(Icons.more_horiz, color: context.mp.textSecondary),
      ],
    ),
  );

  Widget _setlistView(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(MonoPulseSpacing.mdPlus, MonoPulseSpacing.md, MonoPulseSpacing.mdPlus, MonoPulseSpacing.md),
    children: [
      Text(
        'Setlist / Lisbon',
        style: MonoPulseTypography.labelSmall.copyWith(
          color: MonoPulseColors.petrol,
        ),
      ),
      const SizedBox(height: MonoPulseSpacing.xs),
      Text('A Fechada', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: MonoPulseSpacing.xs),
      Text(
        '30 Jul 2026  ·  9 songs  ·  48 min',
        style: MonoPulseTypography.labelSmall.copyWith(
          color: context.mp.textTertiary,
        ),
      ),
      const SizedBox(height: MonoPulseSpacing.sm),
      AppCard(
        variant: AppCardVariant.raised,
        padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.md, vertical: MonoPulseSpacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _readout(context, 'Total', '48:10'),
            _readout(context, 'First key', 'C#m'),
            _readout(context, 'Avg bpm', '108'),
          ],
        ),
      ),
      const SizedBox(height: MonoPulseSpacing.sm),
      for (var i = 0; i < _songs.length; i++)
        SetlistSongRow(
          index: i,
          song: _songs[i],
          isCurrent: i == 1,
          trailing: Text(
            '${_songs[i].ourKey}\n${_songs[i].ourBPM} BPM',
            textAlign: TextAlign.right,
            style: MonoPulseTypography.labelSmall.copyWith(
              color: context.mp.textSecondary,
            ),
          ),
        ),
      const SetlistBreakRow(breakType: 'break_pause', label: '10 min break'),
    ],
  );

  Widget _songView(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(MonoPulseSpacing.mdPlus, MonoPulseSpacing.md, MonoPulseSpacing.mdPlus, MonoPulseSpacing.mdPlus),
    children: [
      Text(
        'Song / our version',
        style: MonoPulseTypography.labelSmall.copyWith(
          color: MonoPulseColors.petrol,
        ),
      ),
      const SizedBox(height: MonoPulseSpacing.xs),
      Text('Viento Helado', style: Theme.of(context).textTheme.headlineMedium),
      Text(
        'Sol Vk',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.mp.textSecondary),
      ),
      const SizedBox(height: MonoPulseSpacing.sm),
      const Wrap(
        spacing: 7,
        children: [
          _ReadoutPlate(label: 'Key', value: 'Am'),
          _ReadoutPlate(label: 'Tempo', value: '120 BPM'),
          _ReadoutPlate(label: 'Meter', value: '4/4'),
        ],
      ),
      const SizedBox(height: MonoPulseSpacing.mdPlus),
      const Text('Structure', style: MonoPulseTypography.labelMedium),
      const SizedBox(height: MonoPulseSpacing.xs),
      for (final section in const [
        ('Intro', '8 bars', 'Am'),
        ('Verse 1', '16 bars', 'Am'),
        ('Chorus', '16 bars', 'F'),
        ('Verse 2', '16 bars', 'Am'),
        ('Bridge', '8 bars', 'C'),
      ])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: MonoPulseSpacing.xs),
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.sm, vertical: MonoPulseSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    section.$1,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text(
                  section.$2,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.mp.textTertiary,
                  ),
                ),
                const SizedBox(width: MonoPulseSpacing.sm),
                Text(
                  section.$3,
                  style: MonoPulseTypography.labelLarge.copyWith(
                    color: MonoPulseColors.petrol,
                  ),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: MonoPulseSpacing.md),
      const Text('Lyrics + chords', style: MonoPulseTypography.labelMedium),
      const SizedBox(height: MonoPulseSpacing.xs),
      const AppCard(
        variant: AppCardVariant.raised,
        padding: EdgeInsets.all(MonoPulseSpacing.md),
        child: ChordChartView(
          chart:
              '[Am]Viento helado\nme lleva [F]lejos\n\n[C]Entre la sombra\ny el [G]sol',
          lineSpacing: 4,
        ),
      ),
    ],
  );

  Widget _addSongView(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(MonoPulseSpacing.mdPlus, MonoPulseSpacing.md, MonoPulseSpacing.mdPlus, MonoPulseSpacing.mdPlus),
    children: [
      Text(
        'New song / details',
        style: MonoPulseTypography.labelSmall.copyWith(
          color: MonoPulseColors.petrol,
        ),
      ),
      const SizedBox(height: MonoPulseSpacing.xs),
      Text('Add a song', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: MonoPulseSpacing.sm),
      const CustomTextField(
        label: 'Song title',
        hint: 'e.g. Viento Helado',
        prefixIcon: Icons.music_note,
      ),
      const SizedBox(height: MonoPulseSpacing.sm),
      const CustomTextField(
        label: 'Artist / writer',
        hint: 'Who wrote or performs it?',
        prefixIcon: Icons.person_outline,
      ),
      const SizedBox(height: MonoPulseSpacing.sm),
      Row(
        children: [
          Expanded(
            child: _choiceField(context, 'Key', 'Am', ['Am', 'C', 'F', 'G']),
          ),
          const SizedBox(width: MonoPulseSpacing.sm),
          Expanded(
            child: _choiceField(context, 'Meter', '4/4', ['4/4', '3/4', '6/8']),
          ),
        ],
      ),
      const SizedBox(height: MonoPulseSpacing.sm),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.md, vertical: MonoPulseSpacing.sm),
        child: Row(
          children: [
            Icon(Icons.speed, color: context.mp.textSecondary, size: 19),
            const SizedBox(width: MonoPulseSpacing.sm),
            const Expanded(
              child: Text('Tempo', style: MonoPulseTypography.labelMedium),
            ),
            IconButton(
              tooltip: 'Decrease tempo',
              visualDensity: VisualDensity.compact,
              onPressed: () {},
              icon: const Icon(Icons.remove),
            ),
            const Text('120 BPM', style: MonoPulseTypography.labelLarge),
            IconButton(
              tooltip: 'Increase tempo',
              visualDensity: VisualDensity.compact,
              onPressed: () {},
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
      const SizedBox(height: MonoPulseSpacing.md),
      const Text('Structure', style: MonoPulseTypography.labelMedium),
      const SizedBox(height: MonoPulseSpacing.xs),
      Wrap(
        spacing: 5,
        children: [
          for (final section in ['Intro', 'Verse', 'Chorus', 'Bridge'])
            AppFilterChip(
              label: section,
              selected: _selectedSections.contains(section),
              onSelected: (selected) => setState(() {
                if (selected) {
                  _selectedSections.add(section);
                } else {
                  _selectedSections.remove(section);
                }
              }),
            ),
        ],
      ),
      const SizedBox(height: MonoPulseSpacing.sm),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.md, vertical: MonoPulseSpacing.sm),
        child: Row(
          children: [
            Icon(Icons.drag_indicator, color: context.mp.textTertiary),
            const SizedBox(width: MonoPulseSpacing.xs),
            Expanded(
              child: Text(
                'Verse 1',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Text('16 bars', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: MonoPulseSpacing.sm),
            Text(
              'Am',
              style: MonoPulseTypography.labelMedium.copyWith(
                color: MonoPulseColors.petrol,
              ),
            ),
            const SizedBox(width: MonoPulseSpacing.xs),
            Icon(Icons.more_horiz, color: context.mp.textSecondary),
          ],
        ),
      ),
      const SizedBox(height: MonoPulseSpacing.sm),
      CustomButton(
        label: 'Add recording',
        icon: Icons.add,
        variant: ButtonVariant.secondary,
        onPressed: () {},
      ),
      const SizedBox(height: MonoPulseSpacing.sm),
      Text(
        'Audio, lyrics and links can be added anytime.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.mp.textSecondary),
      ),
    ],
  );

  Widget _choiceField(
    BuildContext context,
    String label,
    String value,
    List<String> choices,
  ) => LabeledField(label: label, child: InputDecorator(
    decoration: const InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.md, vertical: MonoPulseSpacing.xs)),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isDense: true,
        isExpanded: true,
        borderRadius: BorderRadius.circular(MonoPulseRadius.xsmall),
        items: [
          for (final choice in choices)
            DropdownMenuItem(value: choice, child: Text(choice)),
        ],
        onChanged: (_) {},
      ),
    ),
  ));

  Widget _saveSongBar(BuildContext context) => Container(
    padding: const EdgeInsets.all(MonoPulseSpacing.sm),
    decoration: BoxDecoration(
      color: context.mp.surfaceRaised,
      border: Border(top: BorderSide(color: context.mp.borderDefault)),
    ),
    child: CustomButton(
      label: 'Save song',
      icon: Icons.check,
      fullWidth: true,
      onPressed: () {},
    ),
  );

  Widget _transportBar(BuildContext context) => Container(
    padding: const EdgeInsets.all(MonoPulseSpacing.sm),
    decoration: BoxDecoration(
      color: context.mp.surfaceRaised,
      border: Border(top: BorderSide(color: context.mp.borderDefault)),
    ),
    child: Row(
      children: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.skip_previous),
          tooltip: 'Previous',
        ),
        Expanded(
          child: CustomButton(
            label: _playing ? 'Pause' : 'Play set',
            icon: _playing ? Icons.pause : Icons.play_arrow,
            fullWidth: true,
            onPressed: () => setState(() => _playing = !_playing),
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.skip_next),
          tooltip: 'Next',
        ),
      ],
    ),
  );

  Widget _readout(BuildContext context, String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: MonoPulseTypography.labelSmall.copyWith(
          color: context.mp.textTertiary,
        ),
      ),
      Text(value, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}

class _ReadoutPlate extends StatelessWidget {
  const _ReadoutPlate({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.sm, vertical: MonoPulseSpacing.sm),
    decoration: BoxDecoration(
      color: context.mp.surfaceRaised,
      border: Border.all(color: context.mp.borderDefault),
      borderRadius: BorderRadius.circular(MonoPulseRadius.xsmall),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: MonoPulseTypography.labelSmall.copyWith(
            color: context.mp.textTertiary,
          ),
        ),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    ),
  );
}
