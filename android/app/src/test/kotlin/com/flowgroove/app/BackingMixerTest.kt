package com.flowgroove.app

import java.io.File
import kotlin.math.abs
import kotlin.math.min
import org.json.JSONObject
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BackingMixerTest {
    private val fixtureFile = File(
        requireNotNull(System.getProperty("user.dir")) + "/../../test/fixtures/backing_golden.json"
    )
    private val fixture = JSONObject(fixtureFile.readText())
    private val sampleRate = fixture.getInt("sampleRate")
    private val interval = fixture.getDouble("intervalMicros")
    private val ticks = fixture.getInt("ticksPerBar")
    private val bpm = fixture.getDouble("renderBpm")
    private val tickFrames = interval * sampleRate / 1_000_000.0

    private fun start(bar: Int) = barStartFrame(bar, ticks, interval, sampleRate, 0L)

    private fun stems(): Map<String, ShortArray> {
        val result = mutableMapOf<String, ShortArray>()
        val rules = fixture.getJSONArray("stems")
        for (i in 0 until rules.length()) {
            val rule = rules.getJSONObject(i)
            val bars = rule.getInt("songBars")
            val pcm = ShortArray(start(bars).toInt())
            for (tick in 0 until bars * ticks) {
                pcm[Math.round(tick * tickFrames).toInt()] = rule.getInt("pcm16").toShort()
            }
            result[rule.getString("name")] = pcm
        }
        return result
    }

    private fun mixer(samples: Map<String, ShortArray> = stems()) = BackingMixer(sampleRate).apply {
        load(samples, bpm, ticks, interval)
    }

    private fun launch(backing: BackingMixer, fromBar: Int = 0, bars: Int = 2) {
        backing.command("test", "launch", fromBar, bars, true, 0)
    }

    private fun render(backing: BackingMixer, out: DoubleArray, frame: Long) {
        backing.mix(out, frame, bpm, 0L, ticks, interval)
    }

    private fun state(data: JSONObject): Map<String, Any> = mutableMapOf<String, Any>(
        "token" to data.getString("token"),
        "state" to data.getString("state"),
        "transportBar" to data.getInt("transportBar")
    ).apply {
        if (data.has("reason")) put("reason", data.getString("reason"))
    }

    @Test
    fun goldenFixtureStaysUnder200KB() {
        assertTrue(fixtureFile.length() < 200 * 1024)
        val rules = fixture.getJSONArray("stems")
        for (i in 0 until rules.length()) {
            val rule = rules.getJSONObject(i)
            assertEquals("impulse_at_every_beat", rule.getString("rule"))
            assertEquals(1.0, rule.getDouble("amplitude"), 0.0)
        }
    }

    @Test
    fun sharedGoldenCases() {
        val cases = fixture.getJSONArray("cases")
        for (caseIndex in 0 until cases.length()) {
            val data = cases.getJSONObject(caseIndex)
            for (chunkSize in listOf(4093, 65536)) {
                val context = "${data.getString("name")} (chunks of $chunkSize)"
                val backing = mixer()
                val states = mutableListOf<Map<String, Any>>()
                backing.onState = { token, state, bar ->
                    states.add(mutableMapOf<String, Any>(
                        "token" to token,
                        "state" to state,
                        "transportBar" to bar
                    ).apply {
                        if (state == "stopped") put("reason", requireNotNull(backing.stopReason))
                    })
                }
                val operations = data.getJSONArray("operations")
                for (opIndex in 0 until operations.length()) {
                    val op = operations.getJSONObject(opIndex)
                    when (op.getString("op")) {
                        "command" -> backing.command(
                            op.getString("token"), op.getString("kind"), op.getInt("fromBar"),
                            op.getInt("bars"), op.getBoolean("loop"), op.getInt("atBar")
                        )
                        "gain" -> backing.setGain(op.getString("stem"), op.getDouble("gain"))
                        "mix" -> {
                            val first = op.getLong("chunkStart")
                            val end = first + op.getLong("frameCount")
                            val actual = mutableListOf<Long>()
                            var frame = first
                            while (frame < end) {
                                val out = DoubleArray(min(chunkSize.toLong(), end - frame).toInt())
                                backing.mix(
                                    out, frame, op.optDouble("engineBpm", bpm),
                                    op.optLong("epochFrame", 0L), ticks,
                                    op.optDouble("intervalMicros", interval)
                                )
                                for (i in out.indices) {
                                    if (out[i] != 0.0) {
                                        actual.add(frame + i)
                                        assertEquals(context, 32767 / 32768.0, out[i], 0.0)
                                    }
                                }
                                frame += out.size
                            }
                            val expected = op.getJSONArray("expectedNonZeroFrames")
                            assertEquals(context, (0 until expected.length()).map { expected.getLong(it) }, actual)
                            if (data.has("maxClickGridErrorFrames")) {
                                for (sample in actual) {
                                    val tick = Math.round(sample / tickFrames)
                                    val click = Math.round(tick * tickFrames)
                                    assertTrue(context, abs(sample - click) <= data.getLong("maxClickGridErrorFrames"))
                                }
                                assertEquals(context, sampleRate * 300L, end - first)
                            }
                        }
                        else -> error("Unknown fixture operation")
                    }
                }
                val expected = data.getJSONArray("expectedStates")
                assertEquals(context, (0 until expected.length()).map { state(expected.getJSONObject(it)) }, states)
            }
        }
    }

    @Test
    fun mixAddsIndependentStemsWithoutClippingOrClearingOutput() {
        val backing = mixer(mapOf(
            "drums" to shortArrayOf(16384, -32768),
            "bass" to shortArrayOf(16384, 16384)
        ))
        launch(backing)
        val out = doubleArrayOf(0.75, 0.75, 0.75)
        render(backing, out, 0L)
        assertArrayEquals(doubleArrayOf(1.75, 0.25, 0.75), out, 0.0)
    }

    @Test
    fun cancelDropsAQueuedLaunchBeforeItStarts() {
        val backing = mixer(mapOf("drums" to shortArrayOf(16384, 16384)))
        backing.command("n:1", "launch", 0, 2, true, 0)
        backing.cancel("n:1")
        val out = doubleArrayOf(0.0, 0.0)
        render(backing, out, 0L)
        assertArrayEquals(doubleArrayOf(0.0, 0.0), out, 0.0)
    }

    @Test
    fun gainRampLasts5MsAndSurvivesChunkSplitsAndRetargeting() {
        val backing = mixer(mapOf("drums" to ShortArray(2000) { 16384 }))
        launch(backing)
        backing.setGain("drums", 0.0)
        val first = DoubleArray(120)
        render(backing, first, 0L)
        for (i in first.indices) assertEquals(0.5 * (1 - i / 240.0), first[i], 1e-7)
        backing.setGain("drums", 1.0)
        val next = DoubleArray(241)
        render(backing, next, 120L)
        for (i in next.indices) assertEquals(0.25 + 0.25 * i / 240.0, next[i], 1e-7)
        backing.setGain("drums", 0.0)
        val down = DoubleArray(241)
        render(backing, down, 361L)
        assertEquals(0.5, down.first(), 0.0)
        assertEquals(0.25, down[120], 0.0)
        assertEquals(0.0, down.last(), 0.0)
    }

    @Test
    fun longerTransportBarPadsInsteadOfLeakingTheNextSongBar() {
        assertEquals(start(1), start(2) - start(1) + 1)
        val backing = mixer(mapOf("drums" to ShortArray(start(3).toInt()) { 16384 }))
        launch(backing, fromBar = 1)
        val out = DoubleArray(3)
        render(backing, out, start(1) - 2)
        assertArrayEquals(doubleArrayOf(0.5, 0.0, 0.5), out, 0.0)
    }

    @Test
    fun shorterTransportBarTruncatesAndReanchorsTheNextSongBar() {
        val pcm = ShortArray(start(4).toInt()).apply {
            this[start(1).toInt() - 1] = 16384
            this[start(1).toInt()] = -16384
        }
        val backing = mixer(mapOf("drums" to pcm))
        backing.command("test", "launch", 0, 2, false, 1)
        val out = DoubleArray(3)
        render(backing, out, start(2) - 1)
        assertArrayEquals(doubleArrayOf(0.0, -0.5, 0.0), out, 0.0)
    }

    @Test
    fun skippingChunksStillReportsLaunchAndNaturalEndAtTheirBars() {
        val backing = mixer()
        val states = mutableListOf<String>()
        backing.onState = { _, state, bar -> states.add("$state:$bar") }
        backing.command("test", "launch", 0, 2, false, 3)
        render(backing, DoubleArray(1), start(8))
        assertEquals(listOf("queued:3", "playing:3", "stopped:5"), states)
    }
}
