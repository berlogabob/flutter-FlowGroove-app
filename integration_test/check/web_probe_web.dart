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

@JS('eval')
external JSAny? _eval(String code);

/// Patches HTMLMediaElement so every audio element just_audio_web creates (it is never attached to
/// the DOM) is captured, and every src / currentTime / play / pause call is logged with a timestamp.
void installAudioProbe() {
  _eval('''
(function () {
  if (window.__fgProbe) { window.__fgProbe.els = []; window.__fgProbe.log = []; window.__fgProbe.t0 = performance.now(); return; }
  var P = window.__fgProbe = { els: [], log: [], t0: performance.now() };
  function L(s) { P.log.push(Math.round(performance.now() - P.t0) + ' ' + s); }
  var proto = HTMLMediaElement.prototype;
  function reg(el) { if (P.els.indexOf(el) < 0) P.els.push(el); }
  function tail(u) { return String(u).split('?')[0].split('/').pop(); }
  var ct = Object.getOwnPropertyDescriptor(proto, 'currentTime');
  Object.defineProperty(proto, 'currentTime', { configurable: true,
    get: function () { return ct.get.call(this); },
    set: function (v) { reg(this); L('currentTime=' + (+v).toFixed(3) + ' (was ' + ct.get.call(this).toFixed(3) + ')'); ct.set.call(this, v); } });
  var sr = Object.getOwnPropertyDescriptor(proto, 'src');
  Object.defineProperty(proto, 'src', { configurable: true,
    get: function () { return sr.get.call(this); },
    set: function (v) { reg(this); L('src=' + tail(v)); sr.set.call(this, v); } });
  var play = proto.play;
  proto.play = function () { reg(this); L('play() at ' + this.currentTime.toFixed(3)); return play.apply(this, arguments); };
  var pause = proto.pause;
  proto.pause = function () { reg(this); L('pause() at ' + this.currentTime.toFixed(3)); return pause.apply(this, arguments); };
})();
''');
}

({double time, bool paused, String src, double duration})? audioElementNow() {
  final r = _eval('''
(function () {
  var P = window.__fgProbe; if (!P || !P.els.length) return null;
  var e = P.els[P.els.length - 1];
  return JSON.stringify([e.currentTime, e.paused, e.src, isFinite(e.duration) ? e.duration : 0]);
})()
''');
  if (r == null || r.isUndefinedOrNull) return null;
  final j = (r as JSString).toDart;
  final m = RegExp(r'^\[([^,]+),(true|false),"(.*)",([^,]+)\]$').firstMatch(j);
  if (m == null) return null;
  return (
    time: double.parse(m.group(1)!),
    paused: m.group(2) == 'true',
    src: m.group(3)!.split('?').first.split('/').last,
    duration: double.parse(m.group(4)!),
  );
}

List<String> audioElementLog() {
  final r = _eval('JSON.stringify((window.__fgProbe || {log: []}).log)');
  if (r == null || r.isUndefinedOrNull) return const [];
  final s = (r as JSString).toDart;
  return RegExp(r'"([^"]*)"').allMatches(s).map((m) => m.group(1)!).toList();
}
