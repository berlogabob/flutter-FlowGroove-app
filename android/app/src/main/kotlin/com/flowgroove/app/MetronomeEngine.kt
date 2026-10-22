package com.flowgroove.app

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTimestamp
import android.media.AudioTrack
import android.os.Build
import android.os.Handler
import android.os.PowerManager
import android.os.Process
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean
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
    val frequency: Double,
    // Relative loudness of this cell (subdivision boost); 1.0 for main/accent.
    val gain: Double = 1.0
)

internal data class NativeMetronomeConfig(
    val initialTick: Int,
    val intervalMicros: Long,
    val waveType: String,
    val volume: Float,
    val hapticsEnabled: Boolean,
    val ticks: List<NativeMetronomeTick>,
    val bpm: Double = 120.0,
    val ticksPerBar: Int = 4,
    val latencyOffsetFrames: Long = 0L
) {
    companion object {
        fun from(args: Map<*, *>): NativeMetronomeConfig {
            val ticks = (args["ticks"] as? List<*>)?.mapNotNull { rawTick ->
                val tickMap = rawTick as? Map<*, *> ?: return@mapNotNull null
                NativeMetronomeTick(
                    index = (tickMap["index"] as? Number)?.toInt() ?: 0,
                    shouldPlay = tickMap["shouldPlay"] as? Boolean ?: true,
                    frequency = (tickMap["frequency"] as? Number)?.toDouble() ?: 880.0,
                    gain = (tickMap["gain"] as? Number)?.toDouble() ?: 1.0
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
                ticks = ticks,
                bpm = ((args["bpm"] as? Number)?.toDouble() ?: 120.0)
                    .also { require(it.isFinite() && it > 0) { "Invalid bpm" } },
                ticksPerBar = ((args["ticksPerBar"] as? Number)?.toInt() ?: ticks.size)
                    .also { require(it > 0) { "Invalid ticksPerBar" } },
                latencyOffsetFrames = (args["latencyOffsetFrames"] as? Number)?.toLong() ?: 0L
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
    private val backing = backingFor(context)
    private val sampleRate = backing.sampleRate
    private val renderer = ClickRenderer(sampleRate)
    private val burstFrames = (context.getSystemService(Context.AUDIO_SERVICE) as AudioManager)
        .getProperty(AudioManager.PROPERTY_OUTPUT_FRAMES_PER_BUFFER)
        ?.toIntOrNull()
        ?.takeIf { it > 0 } ?: 256
    private val bufferFrames = burstFrames * 2
    private val chunkFrames = burstFrames

    private class PlaybackLatency(val running: AtomicBoolean) {
        @Volatile var millis = -1
    }

    @Volatile private var pendingConfig: NativeMetronomeConfig? = null
    // Per-session running flag captured by the render thread, which is the sole
    // releaser of its own track. A new start() can't revive an old thread, and
    // stop() never races a track release against a blocked write.
    @Volatile private var running: AtomicBoolean? = null
    private var renderThread: Thread? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var focusRequest: AudioFocusRequest? = null
    private var legacyFocusRequested = false

    private val audioManager: AudioManager by lazy {
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }

    // Permanent or transient loss (e.g. an incoming call) stops playback so
    // Dart state stays in sync; ducking requests keep the click running — a
    // metronome the user is playing along to must not silently duck away.
    // Runs on the main thread, so it must NOT join the render thread like
    // stop() does (an 800ms main-thread block right as the call UI appears);
    // signalling is enough — the render thread releases its own track.
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        when (change) {
            AudioManager.AUDIOFOCUS_LOSS,
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> stopWithoutJoin()
            else -> Unit
        }
    }

    private fun stopWithoutJoin() {
        running?.set(false)
        running = null
        renderThread = null
        releaseWakeLock()
        abandonAudioFocus()
        mainHandler.post { onStopped() }
    }

    private val vibrator: Vibrator by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }

    fun start(args: Map<*, *>) {
        stop(notifyFlutter = false)
        val parsed = NativeMetronomeConfig.from(args)
        pendingConfig = null
        val track = buildTrack() ?: run {
            Log.e(TAG, "AudioTrack init failed")
            return
        }
        acquireWakeLock()
        requestAudioFocus()
        val sessionRunning = AtomicBoolean(true)
        val latency = PlaybackLatency(sessionRunning)
        playbackLatency = latency
        running = sessionRunning
        renderThread = Thread(
            { renderLoop(track, sessionRunning, parsed, latency) },
            "FlowGrooveMetronomeAudio"
        ).also { it.start() }
    }

    fun update(args: Map<*, *>) {
        if (running?.get() == true) {
            // Picked up at the next chunk boundary; keeps playback gapless.
            pendingConfig = NativeMetronomeConfig.from(args)
        }
    }

    fun stop(notifyFlutter: Boolean) {
        running?.set(false)
        running = null
        renderThread?.let { thread ->
            try {
                thread.join(800)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
            }
        }
        renderThread = null
        releaseWakeLock()
        abandonAudioFocus()
        // The render thread releases its own track in renderLoop's finally; stop()
        // never touches the track, so a timed-out join can't race a release.
        if (notifyFlutter) {
            mainHandler.post { onStopped() }
        }
    }

    private fun acquireWakeLock() {
        try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "FlowGroove:MetronomeAudio"
            ).apply {
                setReferenceCounted(false)
                // ponytail: 2h ceiling instead of open-ended; longest realistic
                // practice session before the user touches the transport again.
                acquire(2 * 60 * 60 * 1000L)
            }
        } catch (e: Exception) {
            Log.w(TAG, "wakelock acquire failed", e)
        }
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.takeIf { it.isHeld }?.release()
        } catch (e: Exception) {
            Log.w(TAG, "wakelock release failed", e)
        }
        wakeLock = null
    }

    @Suppress("DEPRECATION")
    private fun requestAudioFocus() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                            .build()
                    )
                    .setOnAudioFocusChangeListener(focusListener)
                    .build()
                focusRequest = request
                audioManager.requestAudioFocus(request)
            } else {
                legacyFocusRequested = true
                audioManager.requestAudioFocus(
                    focusListener,
                    AudioManager.STREAM_MUSIC,
                    AudioManager.AUDIOFOCUS_GAIN
                )
            }
        } catch (e: Exception) {
            Log.w(TAG, "audio focus request failed", e)
        }
    }

    @Suppress("DEPRECATION")
    private fun abandonAudioFocus() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
            } else if (legacyFocusRequested) {
                audioManager.abandonAudioFocus(focusListener)
            }
        } catch (e: Exception) {
            Log.w(TAG, "audio focus abandon failed", e)
        }
        focusRequest = null
        legacyFocusRequested = false
    }

    fun dispose() {
        stop(notifyFlutter = false)
    }

    private fun renderLoop(
        initialTrack: AudioTrack,
        running: AtomicBoolean,
        initial: NativeMetronomeConfig,
        latency: PlaybackLatency
    ) {
        var track = initialTrack
        val channelCount = track.channelCount
        // Frames played by tracks that were replaced after a route change; the new
        // track's head restarts at 0 but the UI queues are keyed by absolute frame.
        var headBase = 0L
        var rebuilds = 0
        val scratch = DoubleArray(chunkFrames)
        val pcm = ShortArray(chunkFrames * channelCount)
        // (audibleFrame, tickIndex, shouldVibrate) for ticks awaiting UI dispatch.
        val uiQueue = ArrayDeque<Triple<Long, Int, Boolean>>()
        val barQueue = ArrayDeque<Pair<Long, Int>>()

        var active = initial
        var intervalFrames = active.intervalMicros * sampleRate / 1_000_000.0
        var framesWritten = 0L
        var epochFrame = -active.latencyOffsetFrames
        var nextBar = 0

        try {
            // Default-priority threads get starved by aggressive vendor CPU
            // governors (measured: isolated ~100ms-late beats on Android 10 /
            // Huawei). Urgent-audio priority is what audio pipelines use.
            try {
                Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
            } catch (e: Exception) {
                Log.w(TAG, "setThreadPriority failed", e)
            }
            track.play()
            val playbackStartedNanos = System.nanoTime()
            var nextTimestampNanos = playbackStartedNanos + 1_000_000_000L
            val timestamp = AudioTimestamp()
            var tsValid = false
            var nextLeadLogNanos = playbackStartedNanos + 3_000_000_000L
            while (running.get()) {
                pendingConfig?.let { pend ->
                pendingConfig = null
                active = pend
                intervalFrames = active.intervalMicros * sampleRate / 1_000_000.0
                epochFrame = framesWritten - active.latencyOffsetFrames // restart the grid, gaplessly
                nextBar = 0
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
                    val tickFrame = absoluteTickFrame(j, active.intervalMicros.toDouble(), sampleRate, epochFrame)
                    if (tickFrame + renderer.voiceLen > chunkStart && tickFrame < chunkEnd) {
                        val listIndex = ((active.initialTick + 1 + j).mod(size.toLong())).toInt()
                        val tick = active.ticks[listIndex]
                        if (tick.shouldPlay) {
                            renderer.mixVoice(
                                scratch,
                                (tickFrame - chunkStart).toInt(),
                                tick.frequency,
                                (active.volume.toDouble() * tick.gain).coerceIn(0.0, 1.0),
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

            synchronized(backing) {
                backing.mix(
                    scratch, chunkStart, active.bpm, epochFrame,
                    active.ticksPerBar, active.intervalMicros.toDouble()
                )
            }
            while (true) {
                val barFrame = barStartFrame(
                    nextBar, active.ticksPerBar, active.intervalMicros.toDouble(),
                    sampleRate, epochFrame
                )
                if (barFrame >= chunkEnd) break
                if (barFrame >= chunkStart) barQueue.addLast(barFrame to nextBar)
                nextBar++
            }

            for (i in 0 until chunkFrames) {
                val sample = (scratch[i].coerceIn(-1.0, 1.0) * 32767.0).toInt().toShort()
                for (channel in 0 until channelCount) {
                    pcm[i * channelCount + channel] = sample
                }
            }
            var offset = 0
            var stalls = 0
            while (offset < pcm.size && running.get()) {
                val written = track.write(pcm, offset, pcm.size - offset)
                if (written > 0) {
                    offset += written
                    stalls = 0
                    continue
                }
                // 0 = the system is re-creating the track after a route change
                // (Bluetooth drop/connect); the same frames are retried, so the
                // click and backing stay one stream. Negative = a dead track:
                // rebuild it once per event, then give up.
                if (written == 0 && stalls < MAX_WRITE_STALLS) {
                    stalls++
                    Thread.sleep(WRITE_STALL_SLEEP_MS)
                    continue
                }
                if (rebuilds < MAX_TRACK_REBUILDS) {
                    val replacement = buildTrack(
                        if (channelCount == 1) AudioFormat.CHANNEL_OUT_MONO else AudioFormat.CHANNEL_OUT_STEREO
                    )
                    if (replacement != null && replacement.channelCount == channelCount) {
                        Log.w(TAG, "AudioTrack write returned $written; rebuilt track after route change")
                        rebuilds++
                        releaseTrack(track)
                        track = replacement
                        headBase = framesWritten + offset / channelCount
                        tsValid = false
                        track.play()
                        stalls = 0
                        continue
                    }
                    replacement?.release()
                }
                Log.e(TAG, "AudioTrack write error: $written")
                running.set(false)
                break
            }
            framesWritten += offset / channelCount

                val now = System.nanoTime()
                if (now >= nextTimestampNanos) {
                    tsValid = track.getTimestamp(timestamp)
                    latency.millis = if (tsValid) {
                        // Project the timestamp's presentation frame to now.
                        val queuedMillis = (framesWritten - (headBase + timestamp.framePosition)) * 1000.0 / sampleRate -
                            (now - timestamp.nanoTime) / 1_000_000.0
                        queuedMillis.roundToInt().coerceAtLeast(0)
                    } else {
                        -1
                    }
                    nextTimestampNanos = now + TIMESTAMP_REFRESH_NANOS
                }

                // Fire UI ticks + haptics once the sound is actually presented, so
                // the beat highlight and vibration line up with what is heard.
                // The hardware-presented frame (getTimestamp, projected to now) lags the
                // playback head by the HAL/Bluetooth delay when the HAL reports it; never
                // fire earlier than the head. Falls back to the head without a timestamp.
                // ponytail: 32-bit head masked; sync would only hiccup after ~24h
                // continuous play (audio unaffected). Wrap accounting if anyone cares.
                val rawHead = headBase + (track.playbackHeadPosition.toLong() and 0xFFFFFFFFL)
                val head = if (tsValid) {
                    val presented = headBase + timestamp.framePosition +
                        (System.nanoTime() - timestamp.nanoTime) * sampleRate / 1_000_000_000L
                    minOf(rawHead, presented)
                } else {
                    rawHead
                }
                if (now >= nextLeadLogNanos) {
                    Log.i(TAG, "ui lead behind head: ${(rawHead - head) * 1000 / sampleRate} ms (timestamp=$tsValid)")
                    nextLeadLogNanos = now + 5_000_000_000L
                }
                while (barQueue.isNotEmpty() && barQueue.first().first <= head) {
                    val (_, index) = barQueue.removeFirst()
                    mainHandler.post { onBar?.invoke(index) }
                }
                while (uiQueue.isNotEmpty() && uiQueue.first().first <= head) {
                    val (_, index, vibrate) = uiQueue.removeFirst()
                    mainHandler.post { onTick(index) }
                    if (vibrate) vibrate()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "render loop error", e)
        } finally {
            running.set(false)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                try {
                    Log.i(TAG, "session AudioTrack underruns: ${track.underrunCount}")
                } catch (_: Exception) {
                }
            }
            releaseTrack(track)
        }
    }

    private fun buildTrack(): AudioTrack? {
        val mono = buildTrack(AudioFormat.CHANNEL_OUT_MONO) ?: return null
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            Log.w(TAG, "FAST denied: performance mode unavailable before API 26")
            return mono
        }
        if (mono.performanceMode == AudioTrack.PERFORMANCE_MODE_LOW_LATENCY) {
            Log.i(TAG, "FAST granted mono")
            return mono
        }

        // Keep the working mono track if the device cannot initialize stereo.
        val stereo = buildTrack(AudioFormat.CHANNEL_OUT_STEREO)
        if (stereo == null) {
            Log.w(TAG, "FAST denied: mono performanceMode=${mono.performanceMode}; stereo init failed")
            return mono
        }
        mono.release()
        if (stereo.performanceMode == AudioTrack.PERFORMANCE_MODE_LOW_LATENCY) {
            Log.i(TAG, "FAST granted stereo")
        } else {
            Log.w(TAG, "FAST denied: mono and stereo low latency denied; performanceMode=${stereo.performanceMode}")
        }
        return stereo
    }

    private fun buildTrack(channelMask: Int): AudioTrack? {
        val channelCount = if (channelMask == AudioFormat.CHANNEL_OUT_MONO) 1 else 2
        val bufferBytes = bufferFrames * channelCount * 2 // 16-bit PCM

        return try {
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
                        .setChannelMask(channelMask)
                        .build()
                )
                .setBufferSizeInBytes(bufferBytes)
                .setTransferMode(AudioTrack.MODE_STREAM)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                builder.setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
            }

            val track = builder.build()
            if (track.state != AudioTrack.STATE_INITIALIZED) {
                track.release()
                Log.w(TAG, "FAST denied: AudioTrack uninitialized; channelMask=$channelMask")
                null
            } else {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    track.setBufferSizeInFrames(bufferFrames)
                }
                track
            }
        } catch (e: Exception) {
            Log.e(TAG, "FAST denied: AudioTrack build failed; channelMask=$channelMask", e)
            null
        }
    }

    private fun releaseTrack(track: AudioTrack) {
        try {
            if (track.playState != AudioTrack.PLAYSTATE_STOPPED) track.stop()
            track.flush()
        } catch (e: IllegalStateException) {
            Log.e(TAG, "AudioTrack stop failed", e)
        }
        track.release()
    }

    @Suppress("DEPRECATION")
    private fun vibrate() {
        val durationMillis = 8L
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

    companion object {
        private const val TIMESTAMP_REFRESH_NANOS = 100_000_000L
        private const val MAX_WRITE_STALLS = 300 // x10 ms = 3 s
        private const val WRITE_STALL_SLEEP_MS = 10L
        private const val MAX_TRACK_REBUILDS = 5
        private const val TAG = "FlowGrooveMetronome"
        private var sharedBacking: BackingMixer? = null
        @Volatile private var playbackLatency: PlaybackLatency? = null
        var onBar: ((Int) -> Unit)? = null

        fun engineLatencyMs(): Int {
            val latency = playbackLatency ?: return -1
            return if (latency.running.get()) latency.millis else -1
        }

        // Shared with the Activity because the foreground service owns the engine.
        @Synchronized
        fun backingFor(context: Context): BackingMixer {
            sharedBacking?.let { return it }
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            val rate = audioManager
                ?.getProperty(AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE)
                ?.toIntOrNull()
                ?.takeIf { it > 0 } ?: 48_000
            return BackingMixer(rate).also { sharedBacking = it }
        }
    }
}
