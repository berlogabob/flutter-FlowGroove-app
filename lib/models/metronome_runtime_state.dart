enum BpmSource { manual, song, setlist, preset, tapTempo, tempoRamp }

enum MetronomePlaybackPhase {
  stopped,
  countIn,
  playing,
  pausedByLifecycle,
  error,
}

enum MetronomeEngineMode { pcmTimeline, legacy }
