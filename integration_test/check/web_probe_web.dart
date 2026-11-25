import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Whether `getUserMedia` resolves within a few seconds. Under chromedriver on this Mac it never does,
/// with or without the app: the recorder then waits forever for its stream.
Future<bool> microphoneStreamWorks() async {
  try {
    final stream = await web.window.navigator.mediaDevices
        .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
        .toDart
        .timeout(const Duration(seconds: 6));
    final tracks = stream.getTracks().toDart;
    for (final t in tracks) {
      t.stop();
    }
    return true;
  } on TimeoutException {
    return false;
  } catch (_) {
    return false;
  }
}
