import 'package:material_ui/material_ui.dart';

import '../models/audio_region.dart';
import '../models/section.dart';
import '../services/audio/audio_analysis.dart';
import '../services/audio/audio_markers.dart';
import '../services/audio/song_structure.dart' show SongStructure;
import '../theme/mono_pulse_theme.dart';

class PracticeSetupResult {
  const PracticeSetupResult({this.grid, this.regions, this.markByEar = false});

  final AudioGrid? grid;
  final List<AudioRegion>? regions;
  final bool markByEar;
}

Future<PracticeSetupResult?> showPracticeSetupWizard(
  BuildContext context, {
  required int durationMs,
  required Future<({double bpm, int firstDownbeatMs})?> Function() detectGrid,
  required Future<List<FileMarker>> Function() fileMarkers,
  required Future<void> Function(AudioGrid grid) previewGrid,
  required String Function() newId,
  Future<List<({int ms, double strength})>> Function(AudioGrid? grid)?
  findSections,
  Future<SongStructure?> Function(AudioGrid grid)? findStructure,
  List<String> songSectionNames = const [],
}) => showModalBottomSheet<PracticeSetupResult>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: context.mp.surface,
  builder: (_) => _SetupWizard(
    durationMs: durationMs,
    detectGrid: detectGrid,
    fileMarkers: fileMarkers,
    previewGrid: previewGrid,
    findSections: findSections,
    findStructure: findStructure,
    songSectionNames: songSectionNames,
    newId: newId,
  ),
);

class _SetupWizard extends StatefulWidget {
  const _SetupWizard({
    required this.durationMs,
    required this.detectGrid,
    required this.fileMarkers,
    required this.previewGrid,
    required this.findSections,
    required this.findStructure,
    required this.songSectionNames,
    required this.newId,
  });

  final int durationMs;
  final Future<({double bpm, int firstDownbeatMs})?> Function() detectGrid;
  final Future<List<FileMarker>> Function() fileMarkers;
  final Future<void> Function(AudioGrid grid) previewGrid;
  final Future<List<({int ms, double strength})>> Function(AudioGrid? grid)?
  findSections;
  final Future<SongStructure?> Function(AudioGrid grid)? findStructure;
  final List<String> songSectionNames;
  final String Function() newId;

  @override
  State<_SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends State<_SetupWizard> {
  int _step = 0;
  bool _listening = true;
  bool _loadingMarkers = true;
  bool _adjusting = false;
  bool _previewing = false;
  AudioGrid? _grid;
  List<FileMarker> _markers = [];
  String _source = 'ear';
  int _bars = 8;
  List<({int ms, double strength})> _found = [];
  int _foundCuts = 0;
  bool _finding = false;
  List<AudioRegion> _regions = [];
  SongStructure? _structure;
  List<String> _bases = [];
  final _names = <TextEditingController>[];

  @override
  void initState() {
    super.initState();
    _detect();
    _readMarkers();
  }

  Future<void> _detect() async {
    AudioGrid? grid;
    try {
      final detected = await widget.detectGrid();
      if (detected != null && detected.bpm.isFinite && detected.bpm > 0) {
        grid = AudioGrid(
          bpm: detected.bpm,
          offsetMs: detected.firstDownbeatMs.clamp(0, widget.durationMs),
        );
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _grid = grid;
      _listening = false;
    });
  }

  Future<void> _readMarkers() async {
    List<FileMarker> markers = [];
    try {
      markers =
          (await widget.fileMarkers())
              .where((m) => m.ms >= 0 && m.ms < widget.durationMs)
              .toList()
            ..sort((a, b) => a.ms.compareTo(b.ms));
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _markers = markers;
      _loadingMarkers = false;
    });
  }

  @override
  void dispose() {
    for (final name in _names) {
      name.dispose();
    }
    super.dispose();
  }

  String _time(int ms) =>
      '${ms ~/ 60000}:${(ms ~/ 1000 % 60).toString().padLeft(2, '0')}.${(ms % 1000).toString().padLeft(3, '0')}';

  List<AudioRegion> _buildRegions({bool assignIds = false}) {
    if (_source == 'ear' || widget.durationMs <= 0) return [];
    if (_source == 'detected' && _structure != null) {
      return regionsFromStructure(
        _structure!,
        newId: assignIds ? widget.newId : () => '',
      );
    }
    final cuts = _source == 'markers'
        ? _markers.map((m) => m.ms)
        : _source == 'detected'
        ? topSectionCuts(_found, _foundCuts)
        : gridCuts(_grid!, everyBars: _bars, durationMs: widget.durationMs);
    // Keep the pickup before the downbeat, even when shorter than an edit region.
    final boundaries = {0, ...cuts, widget.durationMs}.toList()..sort();
    final names = {for (final marker in _markers) marker.ms: marker.name};
    return [
      for (var i = 0; i < boundaries.length - 1; i++)
        AudioRegion(
          id: assignIds ? widget.newId() : '',
          name: _source == 'markers' ? names[boundaries[i]] ?? '' : '',
          startMs: boundaries[i],
          endMs: boundaries[i + 1],
        ),
    ];
  }

  void _next() {
    setState(() {
      if (_step == 0) {
        _source = _markers.isNotEmpty
            ? 'markers'
            : _grid != null
            ? 'bars'
            : 'ear';
        _findSections();
      }
      if (_step == 1) {
        for (final name in _names) {
          name.dispose();
        }
        _regions = _buildRegions(assignIds: true);
        _bases = _source == 'detected' && _structure != null
            ? _structure!.sections
                  .map((s) => s.name.replaceFirst(RegExp(r' \d+$'), ''))
                  .toSet()
                  .toList()
            : [];
        _names
          ..clear()
          ..addAll(
            (_bases.isNotEmpty ? _bases : _regions.map((r) => r.name)).map(
              (name) => TextEditingController(text: name),
            ),
          );
      }
      _step++;
    });
  }

  Future<void> _findSections() async {
    final find = widget.findSections;
    if (find == null && widget.findStructure == null) return;
    final grid = _grid;
    _finding = true;
    var found = <({int ms, double strength})>[];
    SongStructure? structure;
    try {
      if (grid != null && widget.findStructure != null) {
        structure = await widget.findStructure!(grid);
      }
      if (structure == null && find != null) found = await find(grid);
    } catch (_) {}
    if (!mounted || grid != _grid) return;
    setState(() {
      _finding = false;
      _structure = structure;
      _found = found;
      _foundCuts = suggestedSectionCuts(
        found,
        songSections: widget.songSectionNames.length,
      );
      if (_step == 1 &&
          _markers.isEmpty &&
          (structure != null || _foundCuts > 0)) {
        _source = 'detected';
      }
    });
  }

  Future<void> _preview() async {
    setState(() => _previewing = true);
    try {
      await widget.previewGrid(_grid!);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not preview audio.')),
        );
      }
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Widget _stepper(String label, VoidCallback minus, VoidCallback plus) => Row(
    children: [
      IconButton(
        tooltip: 'Decrease $label',
        onPressed: minus,
        icon: const Icon(Icons.remove),
      ),
      Expanded(child: Text(label, textAlign: TextAlign.center)),
      IconButton(
        tooltip: 'Increase $label',
        onPressed: plus,
        icon: const Icon(Icons.add),
      ),
    ],
  );

  Widget _tempo() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_listening) ...[
        const CircularProgressIndicator(),
        const Text('Listening…'),
      ] else ...[
        if (_grid != null) ...[
          Text('We hear ${_grid!.bpm.toStringAsFixed(1)} BPM'),
          Text('First downbeat at ${_time(_grid!.offsetMs)}'),
          Wrap(
            children: [
              TextButton(
                onPressed: () => setState(() => _adjusting = false),
                child: const Text('Sounds right'),
              ),
              TextButton(
                onPressed: () => setState(() => _adjusting = true),
                child: const Text('Adjust'),
              ),
              TextButton(
                onPressed: _previewing ? null : _preview,
                child: const Text('Preview'),
              ),
            ],
          ),
          if (_adjusting) ...[
            _stepper(
              '${_grid!.bpm.toStringAsFixed(1)} BPM',
              () => setState(
                () => _grid = _grid!.copyWith(
                  bpm: (_grid!.bpm - .5).clamp(20, 400).toDouble(),
                ),
              ),
              () => setState(
                () => _grid = _grid!.copyWith(
                  bpm: (_grid!.bpm + .5).clamp(20, 400).toDouble(),
                ),
              ),
            ),
            _stepper(
              'Downbeat ${_time(_grid!.offsetMs)}',
              () => setState(
                () => _grid = _grid!.copyWith(
                  offsetMs: (_grid!.offsetMs - 10).clamp(0, widget.durationMs),
                ),
              ),
              () => setState(
                () => _grid = _grid!.copyWith(
                  offsetMs: (_grid!.offsetMs + 10).clamp(0, widget.durationMs),
                ),
              ),
            ),
          ],
        ] else
          const Text('No steady tempo selected. You can still mark sections.'),
        TextButton(
          onPressed: () => setState(() => _grid = null),
          child: const Text('No steady tempo'),
        ),
      ],
    ],
  );

  Widget _sourceCard(String value, String label) => Card(
    child: ListTile(
      selected: _source == value,
      selectedColor: MonoPulseColors.charcoal,
      selectedTileColor: MonoPulseColors.stone,
      leading: Icon(
        _source == value ? Icons.radio_button_checked : Icons.radio_button_off,
      ),
      title: Text(label),
      onTap: () => setState(() => _source = value),
    ),
  );

  Widget _sections() {
    final regions = _buildRegions();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_markers.isNotEmpty)
          _sourceCard(
            'markers',
            'Use ${_markers.length} markers from the file',
          ),
        if (_finding)
          const ListTile(
            leading: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            title: Text('Listening for section changes…'),
          )
        else if (_structure != null || _found.isNotEmpty) ...[
          _sourceCard('detected', 'Where the music changes'),
          if (_structure == null)
            _stepper(
              '${_foundCuts + 1} sections',
              () => setState(() {
                _foundCuts = (_foundCuts - 1).clamp(0, _found.length);
                _source = 'detected';
              }),
              () => setState(() {
                _foundCuts = (_foundCuts + 1).clamp(0, _found.length);
                _source = 'detected';
              }),
            ),
        ],
        if (_grid != null) ...[
          _sourceCard('bars', 'Every $_bars bars'),
          Wrap(
            spacing: MonoPulseSpacing.sm,
            children: [
              for (final bars in [4, 8, 16, 24, 32])
                ChoiceChip(
                  label: Text('$bars'),
                  selected: _bars == bars,
                  onSelected: (_) => setState(() {
                    _bars = bars;
                    _source = 'bars';
                  }),
                ),
            ],
          ),
        ],
        _sourceCard('ear', "I'll mark them by ear"),
        if (regions.isNotEmpty) ...[
          const SizedBox(height: MonoPulseSpacing.md),
          SizedBox(
            height: 32,
            child: Row(
              children: [
                for (var i = 0; i < regions.length; i++)
                  Expanded(
                    flex: regions[i].lengthMs,
                    child: Container(
                      color:
                          MonoPulseColors.sectionColors[i %
                              MonoPulseColors.sectionColors.length],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _naming() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_source == 'ear')
        const Text('Finish to start marking sections in Edit mode.'),
      if (_regions.isNotEmpty)
        TextButton(
          onPressed: () {
            const pattern = [
              'Intro',
              'Verse',
              'Chorus',
              'Verse',
              'Chorus',
              'Bridge',
              'Chorus',
              'Outro',
            ];
            final suggestions = widget.songSectionNames.isEmpty
                ? pattern
                : widget.songSectionNames;
            for (var i = 0; i < _names.length; i++) {
              _names[i].text = suggestions[i % suggestions.length];
            }
          },
          child: const Text('Suggest names'),
        ),
      for (var i = 0; i < _names.length; i++) ...[
        Text(
          _bases.isNotEmpty
              ? _bases[i]
              : '${_time(_regions[i].startMs)} – ${_time(_regions[i].endMs)}',
        ),
        TextField(
          controller: _names[i],
          decoration: InputDecoration(labelText: 'Section ${i + 1} name'),
        ),
        Wrap(
          spacing: MonoPulseSpacing.sm,
          children: [
            for (final name in Section.templates)
              ActionChip(
                label: Text(name),
                onPressed: () => _names[i].text = name,
              ),
          ],
        ),
        const SizedBox(height: MonoPulseSpacing.md),
      ],
    ],
  );

  AudioRegion _renameRegion(AudioRegion region) {
    for (var i = 0; i < _bases.length; i++) {
      if (region.section!.replaceFirst(RegExp(r' \d+$'), '') == _bases[i]) {
        final name = _names[i].text.trim();
        return name == _bases[i]
            ? region
            : renameSection([region], _bases[i], name).single;
      }
    }
    return region;
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .9,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        MonoPulseSpacing.lg,
        MonoPulseSpacing.lg,
        MonoPulseSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + MonoPulseSpacing.md,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Set up for practice',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Skip'),
              ),
            ],
          ),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const Text(' · '),
                Opacity(
                  opacity: i < _step ? 1 : 0,
                  child: const Icon(
                    Icons.check,
                    size: 16,
                    color: MonoPulseColors.accentOrange,
                  ),
                ),
                Container(
                  color: i == _step ? MonoPulseColors.stone : null,
                  child: Text(
                    ['Tempo', 'Sections', 'Names'][i],
                    style: TextStyle(
                      color: i == _step
                          ? MonoPulseColors.charcoal
                          : context.mp.textSecondary,
                      fontWeight: MonoPulseTypography.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: MonoPulseSpacing.lg),
          Expanded(
            child: SingleChildScrollView(
              child: switch (_step) {
                0 => _tempo(),
                1 => _sections(),
                _ => _naming(),
              },
            ),
          ),
          Row(
            children: [
              if (_step > 0)
                TextButton(
                  onPressed: () => setState(() => _step--),
                  child: const Text('Back'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: (_step == 0 && (_listening || _loadingMarkers))
                    ? null
                    : () {
                        if (_step < 2) {
                          _next();
                          return;
                        }
                        Navigator.pop(
                          context,
                          PracticeSetupResult(
                            grid: _grid,
                            regions: _source == 'ear'
                                ? null
                                : [
                                    for (var i = 0; i < _regions.length; i++)
                                      if (_bases.isEmpty)
                                        _regions[i].copyWith(
                                          name: _names[i].text.trim(),
                                        )
                                      else
                                        _renameRegion(_regions[i]),
                                  ],
                            markByEar: _source == 'ear',
                          ),
                        );
                      },
                child: Text(_step == 2 ? 'Finish' : 'Next'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
