package com.flowgroove.app

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ConfigGridTest {
    private val base = NativeMetronomeConfig(
        initialTick = 3,
        intervalMicros = 487_805,
        waveType = "sine",
        volume = 0.5f,
        hapticsEnabled = true,
        ticks = listOf(NativeMetronomeTick(0, true, 1600.0), NativeMetronomeTick(1, true, 800.0)),
    )

    @Test
    fun hapticsVolumeAndWaveKeepTheGrid() {
        assertTrue(base.sameGrid(base.copy(hapticsEnabled = false)))
        assertTrue(base.sameGrid(base.copy(volume = 0.9f, waveType = "square", initialTick = 7)))
    }

    @Test
    fun tempoTicksAndLatencyReanchor() {
        assertFalse(base.sameGrid(base.copy(intervalMicros = 500_000)))
        assertFalse(base.sameGrid(base.copy(ticks = base.ticks.dropLast(1))))
        assertFalse(base.sameGrid(base.copy(latencyOffsetFrames = 100)))
    }
}
