import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/data/backing_transport_provider.dart';
import '../../theme/mono_pulse_theme.dart';

class InstrumentStrip extends ConsumerStatefulWidget {
  const InstrumentStrip({required this.names, super.key});

  final List<String> names;

  @override
  ConsumerState<InstrumentStrip> createState() => _InstrumentStripState();
}

class _InstrumentStripState extends ConsumerState<InstrumentStrip> {
  final _muted = <String>{};
  String? _solo;
  String? _minusOne;

  @override
  Widget build(BuildContext context) {
    final transport = ref.read(backingTransportProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final name in widget.names)
          Wrap(
            spacing: MonoPulseSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Tooltip(
                message: 'Tap to mute · Hold to solo',
                child: GestureDetector(
                  onLongPress: () => setState(() {
                    _solo = _solo == name ? null : name;
                    transport.soloStem(name, solo: _solo != null);
                  }),
                  child: InputChip(
                    label: Text('$name${_solo == name ? ' · Solo' : ''}'),
                    avatar: Icon(
                      _muted.contains(name) || _minusOne == name
                          ? Icons.volume_off
                          : Icons.volume_up,
                    ),
                    selected: _solo == name,
                    onPressed: () => setState(() {
                      if (!_muted.remove(name)) _muted.add(name);
                      transport.muteStem(
                        name,
                        mute: _muted.contains(name) || _minusOne == name,
                      );
                    }),
                  ),
                ),
              ),
              FilterChip(
                label: const Text('I play this'),
                tooltip: 'Leave $name to me',
                selected: _minusOne == name,
                onSelected: (selected) => setState(() {
                  final previous = _minusOne;
                  if (previous != null) {
                    transport.muteStem(
                      previous,
                      mute: _muted.contains(previous),
                    );
                  }
                  _minusOne = selected ? name : null;
                  if (selected) transport.minusOne(name);
                }),
              ),
            ],
          ),
      ],
    );
  }
}
