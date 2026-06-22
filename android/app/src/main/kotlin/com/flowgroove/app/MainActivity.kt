package com.flowgroove.app

import android.content.Context
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Handler
import android.os.HandlerThread
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var metronomeEngine: AndroidMetronomeEngine? = null
    private var audioRouteEmitter: AudioRouteEmitter? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.flowgroove/metronome"
        )
        metronomeEngine = AndroidMetronomeEngine(
            context = this,
            onTick = { index ->
                channel.invokeMethod("tick", mapOf("index" to index))
            },
            onStopped = {
                channel.invokeMethod("stopped", null)
            }
        )
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> handleMetronomeCall(call, result) { args ->
                    metronomeEngine?.start(args)
                }
                "update" -> handleMetronomeCall(call, result) { args ->
                    metronomeEngine?.update(args)
                }
                "stop" -> {
                    metronomeEngine?.stop(notifyFlutter = false)
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

    override fun onPause() {
        metronomeEngine?.stop(notifyFlutter = true)
        super.onPause()
    }

    override fun onDestroy() {
        metronomeEngine?.dispose()
        metronomeEngine = null
        audioRouteEmitter?.dispose()
        audioRouteEmitter = null
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
