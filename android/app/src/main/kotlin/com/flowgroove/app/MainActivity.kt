package com.flowgroove.app

import android.content.Context
import android.content.Intent
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.flowgroove/battery"
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "oemFamily" -> result.success(OemPowerSettings.family())
                    "openOemSettings" -> result.success(OemPowerSettings.open(this))
                    "isIgnoringBatteryOptimizations" ->
                        result.success(isIgnoringBatteryOptimizations())
                    "requestIgnoreBatteryOptimizations" -> {
                        requestIgnoreBatteryOptimizations()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("battery_optimization_error", error.message, null)
            }
        }

        val ch = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.flowgroove/metronome"
        )
        channel = ch
        val backing = AndroidMetronomeEngine.backingFor(applicationContext)
        val mainHandler = Handler(mainLooper)
        synchronized(backing) {
            backing.onState = { token, state, bar ->
                mainHandler.post {
                    channel?.invokeMethod("backingState", mapOf(
                        "token" to if (token.startsWith("n:")) token.substring(2).toLong()
                            else token.removePrefix("s:"),
                        "state" to state, "bar" to bar
                    ))
                }
            }
        }
        AndroidMetronomeEngine.onBar = { index ->
            channel?.invokeMethod("bar", mapOf("index" to index))
        }
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "engineSampleRate" -> result.success(backing.sampleRate)
                "engineLatencyMs" -> result.success(AndroidMetronomeEngine.engineLatencyMs())
                "backingLoad" -> handleMetronomeCall(call, result) { args ->
                    val sampleRate = (args["sampleRate"] as? Number)?.toInt()
                    require(sampleRate == backing.sampleRate) { "Backing sampleRate must match engine rate" }
                    val paths = requireNotNull(args["paths"] as? List<*>) { "Expected paths list" }
                    val stems = paths.mapIndexed { index, path ->
                        val bytes = File(requireNotNull(path as? String) { "Invalid backing path" }).readBytes()
                        require(bytes.size % 2 == 0) { "Expected raw Int16 mono PCM" }
                        val buffer = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
                        index.toString() to ShortArray(buffer.remaining()).also { buffer.get(it) }
                    }.toMap()
                    val renderBpm = requireNotNull(args["renderBpm"] as? Number) { "Missing renderBpm" }.toDouble()
                    val ticksPerBar = requireNotNull(args["ticksPerBar"] as? Number) { "Missing ticksPerBar" }.toInt()
                    val intervalMicros = requireNotNull(args["intervalMicros"] as? Number) { "Missing intervalMicros" }.toDouble()
                    synchronized(backing) {
                        backing.load(stems, renderBpm, ticksPerBar, intervalMicros)
                    }
                }
                "backingCommand" -> handleMetronomeCall(call, result) { args ->
                    val token = requireNotNull(args["token"]) { "Missing token" }
                    require(token is String || token is Int || token is Long) { "Invalid token" }
                    val kind = requireNotNull(args["kind"] as? String) { "Missing kind" }
                    val atBar = requireNotNull(args["atBar"] as? Number) { "Missing atBar" }.toInt()
                    synchronized(backing) {
                        backing.command(
                            (if (token is String) "s:$token" else "n:$token"), kind,
                            (args["fromBar"] as? Number)?.toInt() ?: 0,
                            (args["bars"] as? Number)?.toInt() ?: 0,
                            args["loop"] as? Boolean ?: true, atBar
                        )
                    }
                }
                "backingGain" -> handleMetronomeCall(call, result) { args ->
                    val stem = requireNotNull(args["stem"]) { "Missing stem" }.toString()
                    val gain = requireNotNull(args["gain"] as? Number) { "Missing gain" }.toDouble()
                    synchronized(backing) { backing.setGain(stem, gain) }
                }
                "backingClear" -> {
                    synchronized(backing) { backing.load(emptyMap(), 120.0, 4, 500_000.0) }
                    result.success(null)
                }
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

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        return powerManager.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !isIgnoringBatteryOptimizations()) {
            startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
            })
        }
    }

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
        val backing = AndroidMetronomeEngine.backingFor(applicationContext)
        synchronized(backing) { backing.onState = null }
        AndroidMetronomeEngine.onBar = null
        channel = null
        super.onDestroy()
    }

    private fun handleMetronomeCall(
        call: MethodCall,
        result: MethodChannel.Result,
        action: (Map<*, *>) -> Unit
    ) {
        val args = call.arguments as? Map<*, *>
        if (args == null) {
            result.error("invalid_args", "Expected metronome config map", null)
            return
        }

        try {
            action(args)
            result.success(null)
        } catch (error: Exception) {
            result.error("metronome_error", error.message, null)
        }
    }
}

/**
 * Emits the active audio output route ("bluetooth" | "wired" | "speaker") over an
 * [EventChannel] whenever the set of connected audio devices changes, so the Dart
 * metronome scheduler can recover its stream when Bluetooth connects/disconnects.
 */
private class AudioRouteEmitter(
    private val context: Context
) : EventChannel.StreamHandler {
    private val mainHandler = Handler(context.mainLooper)
    private val callbackThread = HandlerThread("FlowGrooveAudioRoute").also { it.start() }
    private val callbackHandler = Handler(callbackThread.looper)
    private var deviceCallback: AudioDeviceCallback? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        if (audioManager == null) {
            mainHandler.post { events.success("speaker") }
            return
        }

        val callback = object : AudioDeviceCallback() {
            override fun onAudioDevicesAdded(addedDevices: Array<AudioDeviceInfo>) {
                emitCurrentRoute(audioManager, events)
            }

            override fun onAudioDevicesRemoved(removedDevices: Array<AudioDeviceInfo>) {
                emitCurrentRoute(audioManager, events)
            }
        }
        deviceCallback = callback
        audioManager.registerAudioDeviceCallback(callback, callbackHandler)

        emitCurrentRoute(audioManager, events)
    }

    override fun onCancel(arguments: Any?) {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        deviceCallback?.let { callback ->
            audioManager?.unregisterAudioDeviceCallback(callback)
        }
        deviceCallback = null
    }

    fun dispose() {
        callbackThread.quitSafely()
    }

    private fun emitCurrentRoute(audioManager: AudioManager, events: EventChannel.EventSink) {
        val route = classifyRoute(audioManager)
        mainHandler.post { events.success(route) }
    }

    private fun classifyRoute(audioManager: AudioManager): String {
        val outputs = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)

        val isBluetooth = outputs.any { device ->
            device.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                device.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO
        }
        if (isBluetooth) return "bluetooth"

        val isWired = outputs.any { device ->
            device.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES ||
                device.type == AudioDeviceInfo.TYPE_WIRED_HEADSET ||
                device.type == AudioDeviceInfo.TYPE_USB_HEADSET ||
                device.type == AudioDeviceInfo.TYPE_USB_DEVICE
        }
        if (isWired) return "wired"

        return "speaker"
    }
}
