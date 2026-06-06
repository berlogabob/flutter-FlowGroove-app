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
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.sin

class MainActivity : FlutterActivity() {
    private var metronomeEngine: AndroidMetronomeEngine? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.flowgroove/metronome"
        )
        metronomeEngine = AndroidMetronomeEngine(this, channel)
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
    }

    override fun onPause() {
        metronomeEngine?.stop(notifyFlutter = true)
        super.onPause()
    }

    override fun onDestroy() {
        metronomeEngine?.dispose()
        metronomeEngine = null
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

private data class NativeMetronomeTick(
    val index: Int,
    val shouldPlay: Boolean,
    val frequency: Double
)

private data class NativeMetronomeConfig(
    val initialTick: Int,
    val intervalMicros: Long,
    val waveType: String,
    val volume: Float,
    val hapticsEnabled: Boolean,
    val ticks: List<NativeMetronomeTick>
) {
    companion object {
        fun from(args: Map<*, *>): NativeMetronomeConfig {
            val ticks = (args["ticks"] as? List<*>)?.mapNotNull { rawTick ->
                val tickMap = rawTick as? Map<*, *> ?: return@mapNotNull null
                NativeMetronomeTick(
                    index = (tickMap["index"] as? Number)?.toInt() ?: 0,
                    shouldPlay = tickMap["shouldPlay"] as? Boolean ?: true,
                    frequency = (tickMap["frequency"] as? Number)?.toDouble() ?: 880.0
                )
            }.orEmpty().ifEmpty {
                listOf(
                    NativeMetronomeTick(index = 0, shouldPlay = true, frequency = 1600.0),
                    NativeMetronomeTick(index = 1, shouldPlay = true, frequency = 800.0),
                    NativeMetronomeTick(index = 2, shouldPlay = true, frequency = 800.0),
                    NativeMetronomeTick(index = 3, shouldPlay = true, frequency = 800.0)
                )
            }

            return NativeMetronomeConfig(
                initialTick = (args["initialTick"] as? Number)?.toInt() ?: -1,
                intervalMicros = ((args["intervalMicros"] as? Number)?.toLong() ?: 500_000L)
                    .coerceIn(1_000L, 1_500_000L),
                waveType = args["waveType"] as? String ?: "sine",
                volume = ((args["volume"] as? Number)?.toFloat() ?: 0.5f)
                    .coerceIn(0f, 1f),
                hapticsEnabled = args["hapticsEnabled"] as? Boolean ?: true,
                ticks = ticks
            )
        }
    }
}

private class AndroidMetronomeEngine(
    private val context: Context,
    private val channel: MethodChannel
) {
    private val mainHandler = Handler(context.mainLooper)
    private val workerThread = HandlerThread("FlowGrooveMetronome").also { it.start() }
    private val workerHandler = Handler(workerThread.looper)
    private val sampleGenerator = ClickSampleGenerator()

    private var soundPool: SoundPool? = null
    private var fallbackTone: ToneGenerator? = null
    private val soundIdsByFrequency = mutableMapOf<Double, Int>()
    private val frequenciesBySoundId = mutableMapOf<Int, Double>()
    private val failedFrequencies = mutableSetOf<Double>()
    private var config: NativeMetronomeConfig? = null
    private var tickIndex = -1
    private var nextTickAtNanos = 0L
    @Volatile private var playing = false

    fun start(args: Map<*, *>) {
        val parsedConfig = NativeMetronomeConfig.from(args)
        stop(notifyFlutter = false)
        config = parsedConfig
        tickIndex = parsedConfig.initialTick
        prepareSounds(parsedConfig) {
            playing = true
            nextTickAtNanos = SystemClock.elapsedRealtimeNanos()
            workerHandler.post(tickRunnable)
        }
    }

    fun update(args: Map<*, *>) {
        val wasPlaying = playing
        val parsedConfig = NativeMetronomeConfig.from(args)
        stop(notifyFlutter = false)
        config = parsedConfig
        tickIndex = parsedConfig.initialTick
        if (wasPlaying) {
            prepareSounds(parsedConfig) {
                playing = true
                nextTickAtNanos = SystemClock.elapsedRealtimeNanos()
                workerHandler.post(tickRunnable)
            }
        }
    }

    fun stop(notifyFlutter: Boolean) {
        playing = false
        workerHandler.removeCallbacksAndMessages(null)
        releaseSoundPool()
        if (notifyFlutter) {
            mainHandler.post { channel.invokeMethod("stopped", null) }
        }
    }

    fun dispose() {
        stop(notifyFlutter = false)
        workerThread.quitSafely()
    }

    private val tickRunnable = object : Runnable {
        override fun run() {
            val activeConfig = config ?: return
            if (!playing || activeConfig.ticks.isEmpty()) return

            tickIndex = (tickIndex + 1).floorMod(activeConfig.ticks.size)
            val tick = activeConfig.ticks[tickIndex]

            if (tick.shouldPlay) {
                playTick(activeConfig, tick)
                if (activeConfig.hapticsEnabled) {
                    vibrate()
                }
            }

            mainHandler.post {
                channel.invokeMethod("tick", mapOf("index" to tick.index))
            }

            nextTickAtNanos += activeConfig.intervalMicros * 1_000L
            val delayMillis = ((nextTickAtNanos - SystemClock.elapsedRealtimeNanos()) / 1_000_000L)
                .coerceAtLeast(0L)
            workerHandler.postDelayed(this, delayMillis)
        }
    }

    private fun prepareSounds(config: NativeMetronomeConfig, onReady: () -> Unit) {
        releaseSoundPool()

        val frequencies = config.ticks
            .filter { it.shouldPlay }
            .map { it.frequency }
            .distinct()

        if (frequencies.isEmpty()) {
            onReady()
            return
        }

        val pool = SoundPool.Builder()
            .setMaxStreams(2)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            .build()
        soundPool = pool
        fallbackTone = ToneGenerator(AudioManager.STREAM_MUSIC, (config.volume * 100).toInt())

        var pendingLoads = frequencies.size
        pool.setOnLoadCompleteListener { _, sampleId, status ->
            val frequency = frequenciesBySoundId[sampleId]
            if (status != 0 && frequency != null) {
                failedFrequencies.add(frequency)
            }
            pendingLoads -= 1
            if (pendingLoads <= 0) {
                workerHandler.post { onReady() }
            }
        }

        frequencies.forEach { frequency ->
            val sampleFile = File(
                context.cacheDir,
                "metronome_${config.waveType}_${frequency.toInt()}.wav"
            )
            sampleFile.writeBytes(sampleGenerator.generateWav(frequency, config.waveType))
            val soundId = pool.load(sampleFile.absolutePath, 1)
            soundIdsByFrequency[frequency] = soundId
            frequenciesBySoundId[soundId] = frequency
        }
    }

    private fun playTick(config: NativeMetronomeConfig, tick: NativeMetronomeTick) {
        val pool = soundPool ?: run {
            playFallbackTone()
            return
        }
        val soundId = soundIdsByFrequency[tick.frequency] ?: run {
            playFallbackTone()
            return
        }
        if (failedFrequencies.contains(tick.frequency)) {
            playFallbackTone()
            return
        }

        val streamId = pool.play(soundId, config.volume, config.volume, 1, 0, 1f)
        if (streamId == 0) {
            playFallbackTone()
        }
    }

    private fun playFallbackTone() {
        fallbackTone?.startTone(ToneGenerator.TONE_PROP_BEEP, 35)
    }

    @Suppress("DEPRECATION")
    private fun vibrate() {
        val durationMillis = 8L
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.defaultVibrator
        } else {
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(
                VibrationEffect.createOneShot(
                    durationMillis,
                    VibrationEffect.DEFAULT_AMPLITUDE
                )
            )
        } else {
            vibrator.vibrate(durationMillis)
        }
    }

    private fun releaseSoundPool() {
        soundPool?.release()
        soundPool = null
        fallbackTone?.release()
        fallbackTone = null
        soundIdsByFrequency.clear()
        frequenciesBySoundId.clear()
        failedFrequencies.clear()
    }

    private fun Int.floorMod(modulus: Int): Int {
        val result = this % modulus
        return if (result < 0) result + modulus else result
    }
}

private class ClickSampleGenerator {
    private val sampleRate = 44_100
    private val clickDurationSeconds = 0.04

    fun generateWav(frequency: Double, waveType: String): ByteArray {
        val sampleCount = (sampleRate * clickDurationSeconds).toInt()
        val dataSize = sampleCount * 2
        val buffer = ByteBuffer.allocate(44 + dataSize)
        buffer.order(ByteOrder.LITTLE_ENDIAN)

        buffer.put("RIFF".toByteArray(Charsets.US_ASCII))
        buffer.putInt(36 + dataSize)
        buffer.put("WAVE".toByteArray(Charsets.US_ASCII))
        buffer.put("fmt ".toByteArray(Charsets.US_ASCII))
        buffer.putInt(16)
        buffer.putShort(1)
        buffer.putShort(1)
        buffer.putInt(sampleRate)
        buffer.putInt(sampleRate * 2)
        buffer.putShort(2)
        buffer.putShort(16)
        buffer.put("data".toByteArray(Charsets.US_ASCII))
        buffer.putInt(dataSize)

        for (i in 0 until sampleCount) {
            val time = i.toDouble() / sampleRate
            val phase = (frequency * time) % 1.0
            val sample = wave(phase, waveType) * envelope(time)
            val pcm = (sample.coerceIn(-1.0, 1.0) * Short.MAX_VALUE).toInt().toShort()
            buffer.putShort(pcm)
        }

        return buffer.array()
    }

    private fun wave(phase: Double, waveType: String): Double {
        return when (waveType.lowercase()) {
            "square" -> if (phase < 0.5) 1.0 else -1.0
            "triangle" -> 4.0 * abs(phase - 0.5) - 1.0
            "sawtooth" -> 2.0 * phase - 1.0
            else -> sin(2.0 * PI * phase)
        }
    }

    private fun envelope(time: Double): Double {
        val attackSeconds = 0.001
        val decaySeconds = 0.039
        return if (time < attackSeconds) {
            time / attackSeconds
        } else {
            exp(-3.0 * ((time - attackSeconds) / decaySeconds))
        }
    }
}
