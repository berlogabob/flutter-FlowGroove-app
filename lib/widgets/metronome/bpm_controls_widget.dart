import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data/metronome_provider.dart';

/// BPM Controls widget - Slider, input field, and +/- buttons
/// Includes helpful tooltips explaining BPM concept
class BpmControlsWidget extends ConsumerStatefulWidget {
  const BpmControlsWidget({super.key});

  @override
  ConsumerState<BpmControlsWidget> createState() => _BpmControlsWidgetState();
}

class _BpmControlsWidgetState extends ConsumerState<BpmControlsWidget> {
  final _bpmController = TextEditingController();
  int _localBpm = 120;

  @override
  void initState() {
    super.initState();
    final state = ref.read(metronomeProvider);
    _localBpm = state.bpm;
    _bpmController.text = state.bpm.toString();
  }

  @override
  void didUpdateWidget(BpmControlsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final state = ref.read(metronomeProvider);
    if (state.bpm != _localBpm) {
      _localBpm = state.bpm;
      _bpmController.text = state.bpm.toString();
    }
  }

  @override
  void dispose() {
    _bpmController.dispose();
    super.dispose();
  }

  void _setBpm(int value) {
    final bpm = value.clamp(40, 220);
    setState(() {
      _localBpm = bpm;
      _bpmController.text = bpm.toString();
    });
    ref.read(metronomeProvider.notifier).setBpm(bpm);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(metronomeProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: () => _setBpm(_localBpm - 1),
        ),
        Expanded(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('BPM', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Tooltip(
                    message:
                        'Beats Per Minute - Controls the tempo/speed of the metronome. Higher = faster, Lower = slower.',
                    child: Icon(
                      Icons.help_outline,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              Slider(
                value: state.bpm.toDouble(),
                min: 40,
                max: 220,
                divisions: 180,
                onChanged: (value) => _setBpm(value.round()),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${state.bpm}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _bpmController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: 'BPM',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        helperText: '40-220',
                        helperStyle: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      onChanged: (value) {
                        final bpm = int.tryParse(value);
                        if (bpm != null) {
                          _setBpm(bpm);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => _setBpm(_localBpm + 1),
        ),
      ],
    );
  }
}
