enum PadState { idle, queued, playing }

PadState padStateFor({
  required String sectionId,
  String? queuedId,
  String? playingId,
}) {
  if (queuedId == sectionId) return PadState.queued;
  if (playingId == sectionId) return PadState.playing;
  return PadState.idle;
}

String padStateLabel(PadState state) => switch (state) {
  PadState.idle => 'Idle',
  PadState.queued => 'Starts next bar',
  PadState.playing => 'Playing',
};
