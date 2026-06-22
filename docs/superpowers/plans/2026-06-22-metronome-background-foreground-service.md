# Metronome Background Foreground Service Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the Android metronome beeping continuously through app-switch, screen-off, and phone calls by running playback in a native foreground service.

**Architecture:** Move the existing native `AndroidMetronomeEngine` out of `MainActivity` into a new `MetronomeForegroundService` (`foregroundServiceType="mediaPlayback"`). The Dart side selects the native `PlatformMetronomePlaybackClient` on Android (instead of the Dart-driven unified engine) and talks to the service over the existing `com.flowgroove/metronome` MethodChannel. The service is a *started* foreground service, so it outlives the Activity and is never suspended by the OS.

**Tech Stack:** Flutter 3.44 / Dart, Kotlin (Android native), Riverpod, `permission_handler` (already a dependency), flutter_soloud (off-Android only after this change).

## Global Constraints

- Scope is **Android only**. Do not modify iOS code. Do not change the unified engine for non-Android platforms.
- Package namespace: `com.flowgroove.app`. MethodChannel name: `com.flowgroove/metronome` (unchanged).
- Foreground service type must be `mediaPlayback`; guard all type/permission APIs with `Build.VERSION.SDK_INT` checks (minSdk is Flutter default 24; the app targets current SDK).
- **Keep beeping through calls:** never abandon/duck on audio-focus loss in the native path.
- Preserve the three-pitch feature: the per-tick `frequency` already shipped by `MetronomePlaybackConfig.toPlatformMap()` must continue to reach the native engine unchanged.
- Native Kotlin is not unit-testable in this repo; native tasks gate on a successful build (`flutter build apk --debug`) plus the listed manual on-device checks. Dart tasks gate on `flutter test`.
- Commit after every task.

---

### Task 1: Extract and decouple the native metronome engine

Move `AndroidMetronomeEngine`, `NativeMetronomeConfig`, `NativeMetronomeTick`, and `ClickSampleGenerator` out of `MainActivity.kt` into their own file, and decouple the engine from `MethodChannel` so a service can own it. No behavior change yet — `MainActivity` still constructs and drives the engine.

**Files:**
- Create: `android/app/src/main/kotlin/com/flowgroove/app/MetronomeEngine.kt`
- Modify: `android/app/src/main/kotlin/com/flowgroove/app/MainActivity.kt`

**Interfaces:**
- Produces: `AndroidMetronomeEngine(context: Context, onTick: (Int) -> Unit, onStopped: () -> Unit)` with methods `start(args: Map<*, *>)`, `update(args: Map<*, *>)`, `stop(notifyFlutter: Boolean)`, `dispose()`. Also `internal` classes `NativeMetronomeConfig`, `NativeMetronomeTick`, `ClickSampleGenerator`.

- [ ] **Step 1: Create `MetronomeEngine.kt` with the moved classes**

Create `android/app/src/main/kotlin/com/flowgroove/app/MetronomeEngine.kt`. Move these four declarations from `MainActivity.kt` **verbatim** into the new file (current `MainActivity.kt` line ranges: `NativeMetronomeTick` 172-176, `NativeMetronomeConfig` 178-216, `AndroidMetronomeEngine` 218-413, `ClickSampleGenerator` 415-468). Add this file header and the imports the moved code needs:

```kotlin
package com.flowgroove.app

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.SoundPool
import android.media.ToneGenerator
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.sin
```

- [ ] **Step 2: Change the engine constructor to take callbacks instead of a MethodChannel**

In the moved `AndroidMetronomeEngine`, replace the class header:

```kotlin
internal class AndroidMetronomeEngine(
    private val context: Context,
    private val onTick: (Int) -> Unit,
    private val onStopped: () -> Unit
) {
```

Replace the tick callback inside `tickRunnable.run()` (was `mainHandler.post { channel.invokeMethod("tick", mapOf("index" to tick.index)) }`):

```kotlin
            mainHandler.post { onTick(tick.index) }
```

Replace the stop notification inside `stop()` (was `mainHandler.post { channel.invokeMethod("stopped", null) }`):

```kotlin
        if (notifyFlutter) {
            mainHandler.post { onStopped() }
        }
```

Mark the helper declarations `internal` so the service can use them: `internal data class NativeMetronomeTick`, `internal data class NativeMetronomeConfig`, `internal class ClickSampleGenerator`.

- [ ] **Step 3: Update `MainActivity.kt` to construct the engine with callbacks**

Delete the four moved declarations (lines 172-468) from `MainActivity.kt`. Delete the now-unused imports in `MainActivity.kt` that only the engine used (`AudioAttributes`, `SoundPool`, `ToneGenerator`, `SystemClock`, `VibrationEffect`, `Vibrator`, `VibratorManager`, `File`, `ByteBuffer`, `ByteOrder`, `PI`, `abs`, `exp`, `sin`). Keep `Context`, `AudioManager`, `AudioDeviceCallback`, `AudioDeviceInfo`, `Build`, `Handler`, `HandlerThread` (still used by `AudioRouteEmitter`).

Change the engine construction in `configureFlutterEngine` (was `metronomeEngine = AndroidMetronomeEngine(this, channel)`):

```kotlin
        metronomeEngine = AndroidMetronomeEngine(
            context = this,
            onTick = { index ->
                channel.invokeMethod("tick", mapOf("index" to index))
            },
            onStopped = {
                channel.invokeMethod("stopped", null)
            }
        )
```

- [ ] **Step 4: Build to verify the refactor compiles and behaves identically**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL. (No behavior change — the engine still lives in the Activity and still stops on pause.)

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/flowgroove/app/MetronomeEngine.kt android/app/src/main/kotlin/com/flowgroove/app/MainActivity.kt
git commit -m "refactor(android): extract metronome engine, decouple from MethodChannel

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Create the foreground service, notification, manifest entries

Add a started foreground service that owns the engine and shows a persistent notification with a Stop action. Not yet wired to `MainActivity` (that is Task 3), but it compiles and is declared.

**Files:**
- Create: `android/app/src/main/kotlin/com/flowgroove/app/MetronomeForegroundService.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: `AndroidMetronomeEngine(context, onTick, onStopped)` from Task 1.
- Produces: `MetronomeForegroundService.MetronomeBinder.getService(): MetronomeForegroundService` exposing `startPlayback(args: Map<*, *>)`, `updatePlayback(args: Map<*, *>)`, `stopPlayback()`, and `var tickListener: ((Int) -> Unit)?`, `var stoppedListener: (() -> Unit)?`. Companion: `ACTION_START`, `ACTION_STOP`.

- [ ] **Step 1: Create `MetronomeForegroundService.kt`**

Create `android/app/src/main/kotlin/com/flowgroove/app/MetronomeForegroundService.kt`:

```kotlin
package com.flowgroove.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

class MetronomeForegroundService : Service() {

    private val binder = MetronomeBinder()
    private var engine: AndroidMetronomeEngine? = null
    private var currentBpm: Int = 0

    /** Set by the bound Activity to forward ticks to the Flutter channel. */
    var tickListener: ((Int) -> Unit)? = null
    var stoppedListener: (() -> Unit)? = null

    inner class MetronomeBinder : Binder() {
        fun getService(): MetronomeForegroundService = this@MetronomeForegroundService
    }

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        engine = AndroidMetronomeEngine(
            context = applicationContext,
            onTick = { index -> tickListener?.invoke(index) },
            onStopped = { stoppedListener?.invoke() }
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopPlayback()
                return START_NOT_STICKY
            }
            else -> startForegroundNotification()
        }
        return START_STICKY
    }

    fun startPlayback(args: Map<*, *>) {
        currentBpm = bpmFromArgs(args)
        startForegroundNotification()
        engine?.start(args)
    }

    fun updatePlayback(args: Map<*, *>) {
        currentBpm = bpmFromArgs(args)
        engine?.update(args)
        // Refresh the notification text with the new BPM.
        getSystemService(NotificationManager::class.java)
            ?.notify(NOTIFICATION_ID, buildNotification())
    }

    fun stopPlayback() {
        engine?.stop(notifyFlutter = true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        engine?.dispose()
        engine = null
        tickListener = null
        stoppedListener = null
        super.onDestroy()
    }

    private fun startForegroundNotification() {
        createChannel()
        val notification = buildNotification()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "startForeground failed", e)
        }
    }

    private fun buildNotification(): Notification {
        val openIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
        }
        val contentPi = PendingIntent.getActivity(
            this, 0, openIntent ?: Intent(),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val stopPi = PendingIntent.getService(
            this, 1,
            Intent(this, MetronomeForegroundService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val text = if (currentBpm > 0) "$currentBpm BPM" else "Playing"
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Metronome")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .setSilent(true)
            .setContentIntent(contentPi)
            .addAction(android.R.drawable.ic_media_pause, "Stop", stopPi)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Metronome playback",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Keeps the metronome playing in the background"
            setSound(null, null)
            enableVibration(false)
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun bpmFromArgs(args: Map<*, *>): Int {
        // intervalMicros is per subdivision tick; bpm display is best-effort.
        val intervalMicros = (args["intervalMicros"] as? Number)?.toLong() ?: return 0
        if (intervalMicros <= 0) return 0
        return Math.round(60_000_000.0 / intervalMicros).toInt()
    }

    companion object {
        private const val TAG = "MetronomeFgService"
        private const val CHANNEL_ID = "metronome_playback"
        private const val NOTIFICATION_ID = 7711
        const val ACTION_START = "com.flowgroove.app.METRONOME_START"
        const val ACTION_STOP = "com.flowgroove.app.METRONOME_STOP"
    }
}
```

Note: `bpmFromArgs` returns the *subdivision* tick rate as a rough BPM for the notification label; exact musical BPM is not available in the platform map and is not required for this round.

- [ ] **Step 2: Add permissions and the service declaration to the manifest**

In `android/app/src/main/AndroidManifest.xml`, add these three permissions immediately after the existing `VIBRATE` permission line (`<uses-permission android:name="android.permission.VIBRATE" />`):

```xml
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

Add the service declaration inside `<application>`, immediately before the `<meta-data android:name="flutterEmbedding" android:value="2" />` line:

```xml
        <service
            android:name=".MetronomeForegroundService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="false" />
```

- [ ] **Step 3: Build to verify the service and manifest compile**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL. (`androidx.core.app.NotificationCompat` resolves via the existing AndroidX/Flutter setup.)

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/flowgroove/app/MetronomeForegroundService.kt android/app/src/main/AndroidManifest.xml
git commit -m "feat(android): add metronome foreground service + notification + manifest

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Wire MainActivity to the service and stop killing playback on pause

Route the MethodChannel `start`/`update`/`stop` to the service, start it as a *started* foreground service so it survives Activity death, forward ticks back to Dart, and remove the `onPause` stop.

**Files:**
- Modify: `android/app/src/main/kotlin/com/flowgroove/app/MainActivity.kt`

**Interfaces:**
- Consumes: `MetronomeForegroundService` binder API and `ACTION_START` from Task 2.

- [ ] **Step 1: Replace the engine field and channel handler in `MainActivity`**

In `MainActivity.kt`, remove the `private var metronomeEngine: AndroidMetronomeEngine? = null` field and add service-binding state plus a saved channel reference. Replace the top of the class and `configureFlutterEngine` body so the channel forwards to the service:

```kotlin
class MainActivity : FlutterActivity() {
    private var audioRouteEmitter: AudioRouteEmitter? = null
    private var channel: MethodChannel? = null
    private var service: MetronomeForegroundService? = null
    // True from the moment bindService is requested until unbind, so we never
    // double-bind (which would require matched double-unbind).
    private var bound = false
    // Args captured when 'start' arrives before the service has connected; applied
    // in onServiceConnected. Closes the start/connect race.
    private var pendingStartArgs: Map<*, *>? = null

    private val connection = object : android.content.ServiceConnection {
        override fun onServiceConnected(name: android.content.ComponentName?, binder: android.os.IBinder?) {
            val svc = (binder as? MetronomeForegroundService.MetronomeBinder)?.getService()
            service = svc
            svc?.tickListener = { index ->
                runOnUiThread { channel?.invokeMethod("tick", mapOf("index" to index)) }
            }
            svc?.stoppedListener = {
                runOnUiThread { channel?.invokeMethod("stopped", null) }
            }
            pendingStartArgs?.let { args ->
                svc?.startPlayback(args)
                pendingStartArgs = null
            }
        }

        override fun onServiceDisconnected(name: android.content.ComponentName?) {
            service = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val ch = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.flowgroove/metronome"
        )
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> handleMetronomeCall(call, result) { args ->
                    ensureServiceStartedAndBound()
                    val svc = service
                    if (svc != null) {
                        svc.startPlayback(args)
                    } else {
                        // Service not connected yet — apply on connect.
                        pendingStartArgs = args
                    }
                }
                "update" -> handleMetronomeCall(call, result) { args ->
                    service?.updatePlayback(args)
                }
                "stop" -> {
                    pendingStartArgs = null
                    service?.stopPlayback()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        val routeChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.flowgroove/audio_route"
        )
        audioRouteEmitter = AudioRouteEmitter(this)
        routeChannel.setStreamHandler(audioRouteEmitter)
    }
```

- [ ] **Step 2: Add the start-and-bind helper and fix lifecycle callbacks**

Add this helper method and replace `onPause`/`onDestroy`:

```kotlin
    private fun bindIfNeeded() {
        if (bound) return
        val intent = Intent(this, MetronomeForegroundService::class.java)
        bindService(intent, connection, Context.BIND_AUTO_CREATE)
        bound = true
    }

    private fun ensureServiceStartedAndBound() {
        // Make it a *started* service so it outlives this Activity's binding and
        // keeps playing in the background.
        val intent = Intent(this, MetronomeForegroundService::class.java)
            .setAction(MetronomeForegroundService.ACTION_START)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        bindIfNeeded()
    }

    override fun onStart() {
        super.onStart()
        // Re-bind on return to foreground so tick callbacks reach the UI again
        // (reattaches to a service that may still be playing in the background).
        bindIfNeeded()
    }

    override fun onStop() {
        // Unbind (do NOT stop the service) so playback continues in background.
        if (bound) {
            service?.tickListener = null
            service?.stoppedListener = null
            unbindService(connection)
            bound = false
            service = null
        }
        super.onStop()
    }

    override fun onDestroy() {
        audioRouteEmitter?.dispose()
        audioRouteEmitter = null
        channel = null
        super.onDestroy()
    }
```

Delete the existing `onPause()` override entirely (the `metronomeEngine?.stop(...)` call is what currently kills background playback). Add `import android.os.Build` and `import android.content.Intent` if not already present (`Context` is already imported).

- [ ] **Step 3: Build to verify wiring compiles**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL.

- [ ] **Step 4: Manual on-device verification**

Install on a physical Android device: `flutter install` (or run a debug build). Note: the Dart side does not yet select the native client (Task 4), so to test the native service in isolation, temporarily run with the native path — OR defer manual verification to the end of Task 4 where the full path is active. If verifying now, confirm the app builds and launches without crashing.

Expected: app launches; no crash.

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/flowgroove/app/MainActivity.kt
git commit -m "feat(android): drive metronome via foreground service, stop killing on pause

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Select the native client on Android (Dart) and request notification permission

Make Android use `PlatformMetronomePlaybackClient` (the native service path) instead of the Dart unified engine, and request `POST_NOTIFICATIONS` so the notification is visible. TDD the pure selection predicate.

**Files:**
- Modify: `lib/providers/metronome_runtime_providers.dart`
- Modify: `lib/providers/data/metronome_provider.dart` (request notification permission on first start)
- Create: `test/providers/metronome_playback_client_selection_test.dart`

**Interfaces:**
- Produces: `bool useNativeAndroidPlayback({required bool isWeb, required TargetPlatform platform})` — top-level function in `metronome_runtime_providers.dart`.

- [ ] **Step 1: Write the failing test for the selection predicate**

Create `test/providers/metronome_playback_client_selection_test.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/providers/metronome_runtime_providers.dart';

void main() {
  group('useNativeAndroidPlayback', () {
    test('true on Android (non-web) — uses the native foreground service', () {
      expect(
        useNativeAndroidPlayback(isWeb: false, platform: TargetPlatform.android),
        isTrue,
      );
    });

    test('false on iOS — keeps the unified engine', () {
      expect(
        useNativeAndroidPlayback(isWeb: false, platform: TargetPlatform.iOS),
        isFalse,
      );
    });

    test('false on web even if platform reports android', () {
      expect(
        useNativeAndroidPlayback(isWeb: true, platform: TargetPlatform.android),
        isFalse,
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/providers/metronome_playback_client_selection_test.dart`
Expected: FAIL — `useNativeAndroidPlayback` is not defined.

- [ ] **Step 3: Add the predicate and the Android provider branch**

In `lib/providers/metronome_runtime_providers.dart`, add the predicate above `metronomePlaybackClientProvider`:

```dart
/// Android plays through the native foreground service
/// ([PlatformMetronomePlaybackClient]) so the metronome survives backgrounding,
/// screen-off, and calls. All other native platforms keep the Dart unified
/// engine; web uses the Flutter/Web Audio fallback.
bool useNativeAndroidPlayback({
  required bool isWeb,
  required TargetPlatform platform,
}) =>
    !isWeb && platform == TargetPlatform.android;
```

Then add this branch as the **first** check inside `metronomePlaybackClientProvider`'s callback (before the unified-engine branch):

```dart
  if (useNativeAndroidPlayback(
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
  )) {
    final fallback = FlutterMetronomePlaybackClient(
      audioClient: ref.read(metronomeAudioClientProvider),
      hapticsClient: ref.read(metronomeHapticsProvider),
    );
    final client = PlatformMetronomePlaybackClient(fallback: fallback);
    ref.onDispose(client.dispose);
    return client;
  }
```

Ensure `defaultTargetPlatform` and `TargetPlatform` are imported (the file already imports `package:flutter/foundation.dart` with `TargetPlatform` and `defaultTargetPlatform` — confirm both are in the `show` list at the top; if not, add them).

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/providers/metronome_playback_client_selection_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Request POST_NOTIFICATIONS when starting on Android**

In `lib/providers/data/metronome_provider.dart`, the playback start runs through `Future<void> _startPlaybackSafely({required int initialTick})` (around line 561), which calls `await _playbackClient.start(...)`. Add the imports `import 'package:permission_handler/permission_handler.dart';` and `import 'package:flutter/foundation.dart';` (if `flutter/foundation.dart` is not already imported for `kIsWeb`/`defaultTargetPlatform`).

Add this helper method to the notifier class:

```dart
  /// Best-effort: ask for POST_NOTIFICATIONS on Android 13+ so the foreground
  /// service notification is visible. A denied permission does NOT block
  /// playback — the service still runs.
  Future<void> _ensureNotificationPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    }
  }
```

Then make it the first line inside `_startPlaybackSafely`'s `try` block, before `await _playbackClient.start(`:

```dart
  Future<void> _startPlaybackSafely({required int initialTick}) async {
    try {
      await _ensureNotificationPermission();
      await _playbackClient.start(
        MetronomePlaybackConfig.fromState(state),
        onTick: _handlePlaybackTick,
        onStopped: _handlePlaybackStopped,
        initialTick: initialTick,
      );
    } catch (error) {
      debugPrint('[MetronomeNotifier] Playback start failed: $error');
    }
  }
```

- [ ] **Step 6: Run the full metronome test suite**

Run: `flutter test test/models/ test/services/audio/ test/providers/`
Expected: PASS (no regressions; the new selection test passes).

- [ ] **Step 7: Manual on-device end-to-end verification**

Build and install on a physical device: `flutter install`. Then verify the spec's acceptance checks:
1. Start metronome → switch to another app → **beep continues**.
2. Start metronome → turn screen off → **beep continues**.
3. Start metronome → place/receive a call → **beep continues during and after**.
4. The persistent **notification** shows "Metronome / N BPM"; its **Stop** action stops playback and clears the notification.
5. Change BPM/pattern/pitch while playing → audible change; notification text updates.
6. Kill the app from recents while playing → beep continues; reopen → UI re-syncs to the running beat.

Expected: all six pass.

- [ ] **Step 8: Commit**

```bash
git add lib/providers/metronome_runtime_providers.dart lib/providers/data/metronome_provider.dart test/providers/metronome_playback_client_selection_test.dart
git commit -m "feat(metronome): route Android playback through native foreground service

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Notes for the implementer

- After Task 4, on Android the flutter_soloud unified engine is no longer the playback path. It is still constructed for iOS; do not remove it.
- The native engine already receives the three-pitch per-tick frequencies via `toPlatformMap()`; no native pitch changes are needed.
- If `flutter build apk --debug` is too slow for the inner loop, `cd android && ./gradlew :app:assembleDebug` builds only the native module and surfaces Kotlin errors faster.
- `permission_handler` is already in `pubspec.yaml` (^12.0.1); no dependency change is required.
