import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Light-weight flag for the Metronome screen: name of the drum pattern that is
/// currently playing, or null. Kept separate from `drumPracticeProvider` so the
/// screen never builds the drum player just to show a button state.
class DrumActiveNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  // ignore: use_setters_to_change_properties
  void set(String? name) => state = name;
}

final drumActiveProvider = NotifierProvider<DrumActiveNotifier, String?>(
  DrumActiveNotifier.new,
);
