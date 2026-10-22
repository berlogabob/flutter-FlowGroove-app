package com.flowgroove.app

import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min

/** Uses the same absolute tick grid as MetronomeEngine, without accumulating drift. */
fun barStartFrame(
    bar: Int,
    ticksPerBar: Int,
    intervalMicros: Double,
    sampleRate: Int,
    epochFrame: Long
): Long = epochFrame + Math.round(bar.toLong() * ticksPerBar * (intervalMicros * sampleRate / 1_000_000.0))

/** Mono, additive backing playback on the engine's absolute frame grid. */
class BackingMixer(val sampleRate: Int) {
    init {
        require(sampleRate > 0) { "Invalid sampleRate" }
    }

    var onState: ((token: String, state: String, transportBar: Int) -> Unit)? = null

    /** Set before a stopped callback; `epoch` means the engine grid changed. */
    var stopReason: String? = null
        private set

    private var stems: Map<String, ShortArray> = emptyMap()
    private val gains = mutableMapOf<String, Gain>()
    private val commands = mutableListOf<Command>()
    private var playing: Command? = null
    private var renderBpm = 0.0
    private var renderInterval = 0.0
    private var renderTicks = 0
    private var epoch: Long? = null
    private var interval: Double? = null
    private var nextFrame: Long? = null

    fun load(
        stems: Map<String, ShortArray>,
        renderBpm: Double,
        ticksPerBar: Int,
        intervalMicros: Double
    ) {
        validateGrid(ticksPerBar, intervalMicros)
        require(renderBpm.isFinite() && renderBpm > 0) { "Invalid renderBpm" }
        this.stems = stems.toMap()
        gains.clear()
        stems.keys.forEach { gains[it] = Gain() }
        this.renderBpm = renderBpm
        renderTicks = ticksPerBar
        renderInterval = intervalMicros
        commands.clear()
        playing = null
        epoch = null
        interval = null
        nextFrame = null
        stopReason = null
    }

    // Commands sharing a bar take effect in submission order.
    fun command(token: String, kind: String, fromBar: Int, bars: Int, loop: Boolean, atBar: Int) {
        require(kind == "launch" || kind == "stop") { "Invalid command kind" }
        require(atBar >= 0 && (kind != "launch" || (fromBar >= 0 && bars > 0))) {
            "Invalid backing bar range"
        }
        val command = Command(token, kind, fromBar, bars, loop, atBar)
        val index = commands.indexOfFirst { it.atBar > atBar }
        commands.add(if (index < 0) commands.size else index, command)
        onState?.invoke(token, "queued", atBar)
    }

    fun setGain(stem: String, gain: Double) {
        val envelope = requireNotNull(gains[stem]) { "Unknown stem: $stem" }
        require(gain.isFinite()) { "Invalid gain" }
        envelope.target = gain
        envelope.remaining = max(1L, Math.round(sampleRate * 0.005))
    }

    fun mix(
        out: DoubleArray,
        chunkStart: Long,
        engineBpm: Double,
        epochFrame: Long,
        ticksPerBar: Int,
        intervalMicros: Double
    ) {
        validateGrid(ticksPerBar, intervalMicros)
        fun start(bar: Int) = barStartFrame(bar, ticksPerBar, intervalMicros, sampleRate, epochFrame)
        fun barAt(frame: Long): Int {
            var bar = floor(
                (frame - epochFrame) / (ticksPerBar * (intervalMicros * sampleRate / 1_000_000.0))
            ).toInt()
            while (start(bar) > frame) bar--
            while (start(bar + 1) <= frame) bar++
            return bar
        }

        if (epoch != null && (epoch != epochFrame || interval != intervalMicros)) {
            val cancelled = listOfNotNull(playing) + commands
            playing = null
            commands.clear()
            for (command in cancelled) stopped(command.token, barAt(chunkStart), "epoch")
        }
        epoch = epochFrame
        interval = intervalMicros
        val skipped = max(0L, chunkStart - (nextFrame ?: chunkStart))
        gains.values.forEach { it.advance(skipped) }
        val audible = kotlin.math.abs(renderBpm - engineBpm) < 0.001 && renderInterval == intervalMicros
        var offset = 0
        while (offset < out.size) {
            val frame = chunkStart + offset
            val bar = barAt(frame)
            advance(bar)
            val count = min((out.size - offset).toLong(), start(bar + 1) - frame).toInt()
            val active = playing
            if (audible && active != null) {
                val elapsed = bar - active.atBar
                val songBar = active.fromBar + if (active.loop) elapsed % active.bars else elapsed
                fun songStart(b: Int) = barStartFrame(b, renderTicks, renderInterval, sampleRate, 0L)
                val sourceStart = songStart(songBar)
                val sourceEnd = songStart(songBar + 1)
                val source = sourceStart + frame - start(bar)
                for ((stem, pcm) in stems) {
                    val gain = gains.getValue(stem)
                    for (i in 0 until count) {
                        val sample = source + i
                        if (sample >= sourceStart && sample < sourceEnd && sample < pcm.size) {
                            out[offset + i] += pcm[sample.toInt()] * gain.at(i.toLong()) / 32768.0
                        }
                    }
                }
            }
            gains.values.forEach { it.advance(count.toLong()) }
            offset += count
        }
        nextFrame = chunkStart + out.size
    }

    private fun advance(bar: Int) {
        while (commands.isNotEmpty() && commands.first().atBar <= bar) {
            val command = commands.removeAt(0)
            finish(command.atBar)
            if (command.kind == "stop") {
                playing = null
                stopped(command.token, command.atBar, "command")
            } else {
                playing = command
                stopReason = null
                onState?.invoke(command.token, "playing", command.atBar)
            }
        }
        finish(bar)
    }

    private fun finish(bar: Int) {
        val active = playing
        if (active != null && !active.loop && bar >= active.atBar + active.bars) {
            playing = null
            stopped(active.token, active.atBar + active.bars, "ended")
        }
    }

    private fun stopped(token: String, bar: Int, reason: String) {
        stopReason = reason
        onState?.invoke(token, "stopped", bar)
    }

    private fun validateGrid(ticks: Int, interval: Double) {
        require(ticks > 0 && interval.isFinite() && interval > 0 &&
            ticks * (interval * sampleRate / 1_000_000.0) >= 1) { "Invalid backing grid" }
    }

    private data class Command(
        val token: String,
        val kind: String,
        val fromBar: Int,
        val bars: Int,
        val loop: Boolean,
        val atBar: Int
    )

    private class Gain {
        var value = 1.0
        var target = 1.0
        var remaining = 0L

        // The first frame retains the current gain; the target is reached at 5 ms.
        fun at(offset: Long): Double = if (remaining == 0L || offset >= remaining) target
            else value + (target - value) * offset / remaining

        fun advance(frames: Long) {
            value = at(frames)
            remaining = max(0L, remaining - frames)
        }
    }
}
