/// Whether the browser hands out a microphone stream (always true outside the browser).
Future<bool> microphoneStreamWorks() async => true;

/// Starts recording every audio element call (web only).
void installAudioProbe() {}

/// The real `<audio>` element's state, null outside the browser.
({double time, bool paused, String src, double duration})? audioElementNow() =>
    null;

/// Timestamped log of the audio element's src / currentTime / play / pause calls (web only).
List<String> audioElementLog() => const [];
