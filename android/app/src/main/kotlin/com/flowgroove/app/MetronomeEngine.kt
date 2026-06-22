package com.flowgroove.app

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Build
import android.os.Handler
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import kotlin.math.PI
import kotlin.math.asin
import kotlin.math.exp
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin

internal data class NativeMetronomeTick(
    val index: Int,
    val shouldPlay: Boolean,
    val frequency: Double
)

internal data class NativeMetronomeConfig(
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

/**
 * Sample-accurate click renderer — a Kotlin port of the Dart `PcmClickRenderer`
 * (lib/services/audio/engine/pcm_click_renderer.dart). Generates a 40 ms
 * exp-decayed click at a given frequency and wave type so the native
 * background engine sounds identical to the foreground engine.
 */
internal class ClickRenderer(private val sampleRate: Int) {
    /** 40 ms click length in samples. */
    val voiceLen: Int = (sampleRate * 0.04).roundToInt().coerceAtLeast(1)

    // Output gain applied before clamping so a full-scale click is perceptibly
    // loud at volume 1.0 (a bare decaying sine peaks at 1.0 only momentarily).
    private val outputGain = 2.2

    private fun oscillator(waveType: String, phase: Double): Double = when (waveType) {
        "square" -> if (sin(phase) >= 0) 1.0 else -1.0
        "triangle" -> 2.0 / PI * asin(sin(phase))
        "sawtooth" -> {
            val cycles = phase / (2 * PI)
            2.0 * (cycles - floor(cycles + 0.5))
        }
        else -> sin(phase)
    }

    /**
     * Mix one 40 ms click into [out] (mono scratch, samples in [-1, 1]) starting
     * at sample [at]. [at] may be negative when the click began in a previous
     * chunk and only its tail lands here.
     */
    fun mixVoice(
        out: DoubleArray,
        at: Int,
        frequency: Double,
        volume: Double,
        waveType: String
    ) {
        val start = max(0, at)
        val count = min(voiceLen, out.size - start)
        if (count <= 0) return
        val skip = start - at // when the click began before this chunk
        for (i in 0 until count) {
            val k = i + skip
            val env = if (k < 44) {
                k / 44.0
            } else {
                exp(-4.0 * (k - 44) / max(1, voiceLen - 44))
            }
            val phase = 2 * PI * frequency * k / sampleRate
            val v = oscillator(waveType, phase) * env * volume * outputGain
            out[start + i] = (out[start + i] + v).coerceIn(-1.0, 1.0)
        }
    }
}

/**
 * Drives metronome playback through a single [AudioTrack] in MODE_STREAM. A
 * worker thread renders a continuous PCM timeline with every click placed at its
 * exact sample offset and writes it with blocking writes, so playback timing is
 * the audio sample clock — no Handler/SoundPool jitter, no drift, and no
 * SoundPool resampling noise. AudioTrack on USAGE_MEDIA follows the system
 * output route (Bluetooth/wired) automatically.
 */
internal class AndroidMetronomeEngine(
    private val context: Context,
    private val onTick: (Int) -> Unit,
    private val onStopped: () -> Unit
) {
    private val mainHandler = Handler(context.mainLooper)
    private val sampleRate = resolveSampleRate(context)
    private val renderer = ClickRenderer(sampleRate)
    private val chunkFrames = max(256, sampleRate / 50) // ~20 ms

    private var config: NativeMetronomeConfig? = null
    @Volatile private var pendingConfig: NativeMetronomeConfig? = null
    @Volatile private var playing = false
    private var audioTrack: AudioTrack? = null
    private var renderThread: Thread? = null

    fun start(args: Map<*, *>) {
        stop(notifyFlutter = false)
        val parsed = NativeMetronomeConfig.from(args)
        config = parsed
        pendingConfig = null
        val track = buildTrack() ?: run {
            Log.e(TAG, "AudioTrack init failed")
            return
        }
        audioTrack = track
        playing = true
        renderThread = Thread({ renderLoop(parsed) }, "FlowGrooveMetronomeAudio").also {
            it.start()
        }
    }

    fun update(args: Map<*, *>) {
        val parsed = NativeMetronomeConfig.from(args)
        config = parsed
        if (playing) {
            // Picked up at the next chunk boundary; keeps playback gapless.
            pendingConfig = parsed
        }
    }

    fun stop(notifyFlutter: Boolean) {
        playing = false
        renderThread?.let { thread ->
            try {
                thread.join(500)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
            }
        }
        renderThread = null
        releaseTrack()
        if (notifyFlutter) {
            mainHandler.post { onStopped() }
        }
    }

    fun dispose() {
        stop(notifyFlutter = false)
    }

    private fun renderLoop(initial: NativeMetronomeConfig) {
        val track = audioTrack ?: return
        val scratch = DoubleArray(chunkFrames)
        val pcm = ShortArray(chunkFrames)
        // (audibleFrame, tickIndex, shouldVibrate) for ticks awaiting UI dispatch.
        val uiQueue = ArrayDeque<Triple<Long, Int, Boolean>>()

        var active = initial
        var intervalFrames = active.intervalMicros * sampleRate / 1_000_000.0
        var framesWritten = 0L
        var epochFrame = 0L

        try {
            track.play()
        } catch (e: IllegalStateException) {
            Log.e(TAG, "AudioTrack play failed", e)
            return
        }

        while (playing) {
            pendingConfig?.let { pend ->
                pendingConfig = null
                active = pend
                intervalFrames = active.intervalMicros * sampleRate / 1_000_000.0
                epochFrame = framesWritten // restart the tick grid here, gaplessly
            }

            java.util.Arrays.fill(scratch, 0.0)
            val chunkStart = framesWritten
            val chunkEnd = framesWritten + chunkFrames

            if (active.ticks.isNotEmpty() && intervalFrames > 0) {
                val size = active.ticks.size
                val firstJ = floor(
                    (chunkStart - epochFrame - renderer.voiceLen) / intervalFrames
                ).toLong().coerceAtLeast(0L)
                val lastJ = floor((chunkEnd - epochFrame) / intervalFrames).toLong()
                var j = firstJ
                while (j <= lastJ) {
                    val tickFrame = epochFrame + Math.round(j * intervalFrames)
                    if (tickFrame + renderer.voiceLen > chunkStart && tickFrame < chunkEnd) {
                        val listIndex = ((active.initialTick + 1 + j).mod(size.toLong())).toInt()
                        val tick = active.ticks[listIndex]
                        if (tick.shouldPlay) {
                            renderer.mixVoice(
                                scratch,
                                (tickFrame - chunkStart).toInt(),
                                tick.frequency,
                                active.volume.toDouble(),
                                active.waveType
                            )
                            // Enqueue UI/haptic dispatch only for the onset chunk.
                            if (tickFrame >= chunkStart) {
                                uiQueue.addLast(Triple(tickFrame, tick.index, active.hapticsEnabled))
                            }
                        }
                    }
                    j++
                }
            }

            for (i in 0 until chunkFrames) {
                pcm[i] = (scratch[i].coerceIn(-1.0, 1.0) * 32767.0).toInt().toShort()
            }
            val written = track.write(pcm, 0, chunkFrames)
            if (written < 0) {
                Log.e(TAG, "AudioTrack write error: $written")
                break
            }
            framesWritten += chunkFrames

            // Fire UI ticks + haptics once the audible head reaches them, so the
            // beat highlight and vibration line up with what is actually playing.
            val head = track.playbackHeadPosition.toLong() and 0xFFFFFFFFL
            while (uiQueue.isNotEmpty() && uiQueue.first().first <= head) {
                val (_, index, vibrate) = uiQueue.removeFirst()
                mainHandler.post { onTick(index) }
                if (vibrate) vibrate()
            }
        }
    }

    private fun buildTrack(): AudioTrack? {
        val minBuf = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        if (minBuf <= 0) return null
        val bufferBytes = max(minBuf, chunkFrames * 2 * 4) // ~4 chunks of 16-bit mono

        val builder = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(sampleRate)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setBufferSizeInBytes(bufferBytes)
            .setTransferMode(AudioTrack.MODE_STREAM)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder.setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
        }

        return try {
            val track = builder.build()
            if (track.state != AudioTrack.STATE_INITIALIZED) {
                track.release()
                null
            } else {
                track
            }
        } catch (e: Exception) {
            Log.e(TAG, "AudioTrack build failed", e)
            null
        }
    }

    private fun releaseTrack() {
        audioTrack?.let { track ->
            try {
                if (track.playState != AudioTrack.PLAYSTATE_STOPPED) track.stop()
                track.flush()
            } catch (e: IllegalStateException) {
                Log.e(TAG, "AudioTrack stop failed", e)
            }
            track.release()
        }
        audioTrack = null
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

    private fun resolveSampleRate(context: Context): Int {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        val rate = audioManager
            ?.getProperty(AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE)
            ?.toIntOrNull()
        return rate?.takeIf { it > 0 } ?: 48_000
    }

    companion object {
        private const val TAG = "FlowGrooveMetronome"
    }
}
