import json
R = "Match surrounding style. Change only the allowed files. No new dependencies. "
T = []
def add(id, title, files, prompt, verify, after=(), timeout=400, must=None):
    t = dict(id=id, executor="pi", finding="QUANT", title=title, files=files, prompt=R + prompt,
             verify=verify, after=list(after), status="pending", timeout=timeout, suite=False)
    if must: t["must_contain"] = must
    T.append(t)

GR = "cd android && ./gradlew testDebugUnitTest --tests 'com.flowgroove.app.BackingMixerTest' 2>&1 | tail -15 | tee /dev/stderr | grep -q 'BUILD SUCCESSFUL'"
add("Q01","BackingKind.cancel",["lib/services/audio/backing_engine.dart"],
"Change `enum BackingKind { launch, stop }` to `enum BackingKind { launch, stop, cancel }` and put above it a doc comment: `/// cancel drops a still-queued command; its token is in BackingCommand.fromBar.`",
"dart analyze lib/services/audio/backing_engine.dart", must=["cancel }"])
add("Q02","portable engine handles cancel",["lib/services/audio/backing_engine_factory.dart"],
"In the command(BackingCommand c) method, as its FIRST statement add: `if (c.kind == BackingKind.cancel) { final index = _pending.indexWhere((other) => other.token == c.fromBar); if (index < 0) return; final dropped = _pending.removeAt(index); _cancelFrom(dropped.atBar); _nextBar = math.min(_nextBar ?? dropped.atBar, dropped.atBar); pump(); return; }`. Change nothing else.",
"dart analyze lib/services/audio/backing_engine_factory.dart", after=["Q01"], must=["BackingKind.cancel"])
add("Q03","Q02 test",["test/services/audio/backing_engine_cancel_test.dart","lib/services/audio/backing_engine_factory.dart","test/providers/backing_transport_test.dart"],
"Do NOT modify lib or the other test file. Create test/services/audio/backing_engine_cancel_test.dart. Look at how existing tests under test/services/audio construct the portable engine from backing_engine_factory.dart (a fake clock and fake sources) and copy that setup. Test: load stems, command a launch with token 1 at bar 4, command a launch with token 2 at bar 8, then command BackingCommand(token: 3, kind: BackingKind.cancel, fromBar: 2, atBar: 0); advance the fake clock past bar 8 and pump; expect no BackingStateKind.playing state was ever emitted for token 2 while token 1 did play.",
"flutter test test/services/audio/backing_engine_cancel_test.dart", after=["Q02"], timeout=900)
add("Q04","platform channel sends cancel",["lib/services/audio/backing_engine_platform.dart"],
"No code change is expected beyond verifying: command() already sends kind: c.kind.name and fromBar. Only add the comment line `// cancel: fromBar carries the token to drop (native side maps it).` directly above `Future<void> command(BackingCommand c) =>`.",
"dart analyze lib/services/audio/backing_engine_platform.dart", after=["Q01"], must=["native side maps it"])
add("Q05","BackingMixer.cancel",["android/app/src/main/kotlin/com/flowgroove/app/BackingMixer.kt"],
"Add a public method to class BackingMixer, directly after fun command(...): `fun cancel(token: String) { commands.removeAll { it.token == token } }`. Change nothing else.",
"cd android && ./gradlew compileDebugKotlin 2>&1 | tail -5 | tee /dev/stderr | grep -q 'BUILD SUCCESSFUL'", timeout=900, must=None)
add("Q06","MainActivity routes cancel",["android/app/src/main/kotlin/com/flowgroove/app/MainActivity.kt"],
"In the `\"backingCommand\" -> handleMetronomeCall(call, result) { args ->` block, right after the line that defines `val atBar = ...`, add: `if (kind == \"cancel\") { val target = requireNotNull(args[\"fromBar\"] as? Number) { \"Missing cancel token\" }.toInt(); synchronized(backing) { backing.cancel(\"n:$target\") }; return@handleMetronomeCall }`. If handleMetronomeCall's lambda does not allow that labelled return, instead wrap the existing synchronized(backing) { backing.command(...) } call in `if (kind == \"cancel\") {...} else {...}`. Change nothing else.",
"cd android && ./gradlew compileDebugKotlin 2>&1 | tail -5 | tee /dev/stderr | grep -q 'BUILD SUCCESSFUL'", after=["Q05"], timeout=900, must=None)
add("Q07","Kotlin cancel test",["android/app/src/test/kotlin/com/flowgroove/app/BackingMixerTest.kt"],
"Add one @Test fun cancelDropsAQueuedLaunchBeforeItStarts() after mixAddsIndependentStemsWithoutClippingOrClearingOutput: val backing = mixer(mapOf(\"drums\" to shortArrayOf(16384, 16384))); backing.command(\"n:1\", \"launch\", 0, 2, true, 0); backing.cancel(\"n:1\"); val out = doubleArrayOf(0.0, 0.0); render(backing, out, 0L); assertArrayEquals(doubleArrayOf(0.0, 0.0), out, 0.0). Change nothing else.",
GR, after=["Q05"], timeout=900)
add("Q08","transport re-times a queued launch when quantize changes",["lib/providers/data/backing_transport_provider.dart"],
"Replace the one-line `void setQuantize(Quantize quantize) => state = state.copyWith(quantize: quantize);` (it may be wrapped over two lines) with: `void setQuantize(Quantize quantize) { final changed = state.quantize != quantize; state = state.copyWith(quantize: quantize); if (changed) _retime(); }` and add method `/// A launch still waiting for its bar moves to the bar the new quantize gives. void _retime() { final id = state.queuedId; if (state.rendering || id == null || !ref.read(metronomeProvider).isPlaying) return; final old = _commands[_token]; if (old == null || old.command.kind != BackingKind.launch || old.id != id || _playing?.token == old.command.token) return; final at = state.quantize == Quantize.block ? _blockBoundaryBar() : _nextBar(state.quantize); if (at == old.command.atBar) return; _commands.remove(old.command.token); unawaited(_engine.command(BackingCommand(token: ++_token, kind: BackingKind.cancel, fromBar: old.command.token, atBar: 0))); unawaited(_launch(id, at)); }` (format it normally over several lines). Change nothing else.",
"dart analyze lib/providers/data/backing_transport_provider.dart", after=["Q01"], must=["_retime","BackingKind.cancel"])
add("Q09","re-time test",["test/providers/backing_transport_test.dart"],
"Add ONE test inside the 'play modes and block quantize' group after the test 'block with nothing playing starts at the next bar': name 'changing quantize re-times a queued launch'. Body: `await transport.attach(entry(), sections); transport.setQuantize(Quantize.block); await transport.launch('verse'); engine.playing(engine.commands.last); engine.barEvents.add(engine.commands.last.atBar + 1); transport.setQuantize(Quantize.bar); await transport.launch('chorus'); final queued = engine.commands.last; final before = engine.commands.length; transport.setQuantize(Quantize.beat); final cancels = engine.commands.sublist(before).where((c) => c.kind == BackingKind.cancel).toList(); expect(cancels.length <= 1, isTrue);` then, if cancels is non-empty also expect cancels.single.fromBar == queued.token and that the last command is a launch of the chorus (fromBar 4) with a different token. Use only helpers that already exist in that file; import backing_engine.dart if BackingKind is not yet imported.",
"flutter test test/providers/backing_transport_test.dart", after=["Q08"], timeout=600)
add("Q10","drop the stems trace",["lib/providers/data/backing_transport_provider.dart"],
"In _applyGains delete the `applied` list, the `applied.add(...)`, the three comment lines starting `// shortcut: always-on trace` and the `print('[backing] stems ...')` with its `// ignore: avoid_print` line. Keep the gain loop and `_engine.setGain(i, gain);`. Change nothing else.",
"dart analyze lib/providers/data/backing_transport_provider.dart", after=["Q09"], must=["_engine.setGain(i, gain)"])
json.dump(dict(branch="fix/quantize-retime", tasks=T), open("docs/plans/quantize/tasks.json","w"), indent=1)
print(len(T), "tasks")
