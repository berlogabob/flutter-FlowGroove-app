package com.flowgroove.app

import java.math.BigDecimal
import java.math.RoundingMode
import org.junit.Assert.assertEquals
import org.junit.Test

/** Click and backing share one absolute grid: exact to the frame, no drift. */
class TickGridTest {
    private val sampleRate = 48_000
    private val fiveMinutesMicros = 5L * 60 * 1_000_000

    private fun exact(index: Long, intervalMicros: Long, epoch: Long): Long =
        epoch + BigDecimal(index).multiply(BigDecimal(intervalMicros)).multiply(BigDecimal(sampleRate))
            .divide(BigDecimal(1_000_000), 0, RoundingMode.HALF_UP).toLong()

    @Test
    fun clickAndBackingBarStartsMatchExactArithmeticForFiveMinutes() {
        for (bpm in listOf(60.0, 123.0, 180.0, 200.0, 240.0)) {
            for ((numerator, subdivisions) in listOf(3 to 1, 4 to 1, 4 to 2, 6 to 2, 4 to 3)) {
                val ticksPerBar = numerator * subdivisions
                val intervalMicros = Math.round(60_000_000.0 / bpm / subdivisions)
                val ticks = fiveMinutesMicros / intervalMicros
                var worst = 0L
                var tick = 0L
                while (tick <= ticks) {
                    val want = exact(tick, intervalMicros, 7L)
                    val click = absoluteTickFrame(tick, intervalMicros.toDouble(), sampleRate, 7L)
                    worst = maxOf(worst, kotlin.math.abs(click - want))
                    tick += 1
                }
                assertEquals("click grid bpm=$bpm $numerator/$subdivisions", 0L, worst)
                val bars = (ticks / ticksPerBar).toInt()
                for (bar in 0..bars) {
                    assertEquals(
                        absoluteTickFrame(bar.toLong() * ticksPerBar, intervalMicros.toDouble(), sampleRate, 7L),
                        barStartFrame(bar, ticksPerBar, intervalMicros.toDouble(), sampleRate, 7L)
                    )
                }
            }
        }
    }
}
