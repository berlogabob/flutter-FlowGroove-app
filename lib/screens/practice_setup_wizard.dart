import 'package:flutter/material.dart';

import '../models/audio_region.dart';
import '../models/section.dart';
import '../services/audio/audio_markers.dart';
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
  List<String> songSectionNames = const [],
  required String Function() newId,
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
    required this.songSectionNames,
    required this.newId,
  });

  final int durationMs;
  final Future<({double bpm, int firstDownbeatMs})?> Function() detectGrid;
  final Future<List<FileMarker>> Function() fileMarkers;
  final Future<void> Function(AudioGrid grid) previewGrid;
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
  List<AudioRegion> _regions = [];
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
    final cuts = _source == 'markers'
        ? _markers.map((m) => m.ms)
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
      }
      if (_step == 1) {
        for (final name in _names) {
          name.dispose();
        }
        _regions = _buildRegions(assignIds: true);
        _names
          ..clear()
          ..addAll(_regions.map((r) => TextEditingController(text: r.name)));
      }
      _step++;
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
      selectedColor: MonoPulseColors.accentOrange,
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
        if (_grid != null) ...[
          _sourceCard('bars', 'Every $_bars bars'),
          Wrap(
            spacing: MonoPulseSpacing.sm,
            children: [
              for (final bars in [4, 8])
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
      for (var i = 0; i < _regions.length; i++) ...[
        Text('${_time(_regions[i].startMs)} – ${_time(_regions[i].endMs)}'),
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
                if (i < _step)
                  Icon(
                    Icons.check,
                    size: 16,
                    color: MonoPulseColors.accentOrange,
                  ),
                Text(
                  ['Tempo', 'Sections', 'Names'][i],
                  style: TextStyle(
                    color: i == _step
                        ? MonoPulseColors.accentOrange
                        : context.mp.textSecondary,
                    fontWeight: i == _step
                        ? FontWeight.bold
                        : FontWeight.normal,
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
                                      _regions[i].copyWith(
                                        name: _names[i].text.trim(),
                                      ),
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
