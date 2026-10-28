package com.flowgroove.app

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import java.io.BufferedOutputStream
import java.io.ByteArrayOutputStream
import java.io.FileOutputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Imported song files → ADTS AAC (the format the app records in, so trimming
 * and practice work on them), plus a decoder for files SoLoud can't read.
 */
object AudioTranscoder {
    private const val TIMEOUT_US = 10_000L
    private const val PEAK_COUNT = 200 // waveformPeakCount in audio_note_edit.dart

    /** Encodes [inPath] to ADTS AAC at [outPath]. Returns durationMs + peaks. */
    fun toAac(inPath: String, outPath: String, bitrate: Int): Map<String, Any> {
        var encoder: MediaCodec? = null
        var rate = 0
        var channels = 0
        var frames = 0L
        val totalMs = durationUs(inPath) / 1000.0
        val sumSquares = DoubleArray(PEAK_COUNT)
        val counts = LongArray(PEAK_COUNT)
        val info = MediaCodec.BufferInfo()
        val out = BufferedOutputStream(FileOutputStream(outPath))

        fun drain(endOfStream: Boolean) {
            val codec = encoder ?: return
            while (true) {
                val o = codec.dequeueOutputBuffer(info, if (endOfStream) TIMEOUT_US else 0)
                if (o == MediaCodec.INFO_TRY_AGAIN_LATER) {
                    if (!endOfStream) return
                    continue
                }
                if (o < 0) continue
                val isConfig = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
                if (info.size > 0 && !isConfig) {
                    val buf = codec.getOutputBuffer(o)!!
                    buf.position(info.offset)
                    buf.limit(info.offset + info.size)
                    out.write(adtsHeader(info.size, rate, channels))
                    val bytes = ByteArray(info.size)
                    buf.get(bytes)
                    out.write(bytes)
                }
                codec.releaseOutputBuffer(o, false)
                if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
            }
        }

        fun feed(samples: ShortArray, endOfStream: Boolean) {
            val codec = encoder ?: return
            val data = samples
            var at = 0
            while (at < data.size || endOfStream) {
                val i = codec.dequeueInputBuffer(TIMEOUT_US)
                if (i < 0) {
                    drain(false)
                    continue
                }
                val buf = codec.getInputBuffer(i)!!
                buf.clear()
                val n = minOf(buf.remaining() / 2, data.size - at)
                buf.order(ByteOrder.LITTLE_ENDIAN).asShortBuffer().put(data, at, n)
                at += n
                val pts = frames * 1_000_000L / rate
                frames += n / channels
                val last = endOfStream && at >= data.size
                codec.queueInputBuffer(
                    i, 0, n * 2, pts,
                    if (last) MediaCodec.BUFFER_FLAG_END_OF_STREAM else 0
                )
                drain(false)
                if (last) break
            }
        }

        try {
            decode(inPath, { r, c ->
                rate = r
                channels = minOf(c, 2)
                val format = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, r, channels)
                format.setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                format.setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
                format.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)
                encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC).apply {
                    configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
                    start()
                }
            }) { samples, sourceChannels ->
                val stereo = downmix(samples, sourceChannels, channels)
                for (f in 0 until stereo.size / channels) {
                    val ms = (frames + f) * 1000.0 / rate
                    val bucket = if (totalMs > 0) (ms / totalMs * PEAK_COUNT).toInt() else 0
                    if (bucket in 0 until PEAK_COUNT) {
                        val v = stereo[f * channels].toDouble()
                        sumSquares[bucket] += v * v
                        counts[bucket]++
                    }
                }
                feed(stereo, false)
            }
            if (encoder == null) throw IOException("no audio decoded")
            feed(ShortArray(0), true)
            drain(true)
        } finally {
            out.close()
            encoder?.stop()
            encoder?.release()
        }
        val rms = DoubleArray(PEAK_COUNT) { i ->
            if (counts[i] > 0) kotlin.math.sqrt(sumSquares[i] / counts[i]) else 0.0
        }
        val maxRms = rms.maxOrNull() ?: 0.0
        val peaks = rms.map {
            if (maxRms > 0) kotlin.math.round(it / maxRms * 255).toInt().coerceIn(0, 255) else 0
        }
        return mapOf(
            "durationMs" to (if (rate > 0) frames * 1000 / rate else 0L),
            "peaks" to peaks.toList(),
            // Encoder priming the decoder doesn't strip from ADTS: 2048 samples,
            // measured against the source WAV on the A24 (c2 AAC encoder).
            "primingMs" to (if (rate > 0) 2048 * 1000 / rate else 0)
        )
    }

    /** Whole file as mono 16-bit little-endian PCM at [sampleRate]. */
    fun decodePcm(inPath: String, sampleRate: Int): ByteArray {
        val mono = ByteArrayOutputStream()
        var rate = 0
        var position = 0.0 // next output sample, in source frames
        var sourceFrame = 0L
        var previous = 0
        decode(inPath, { r, _ -> rate = r }) { samples, ch ->
            val step = rate.toDouble() / sampleRate
            val count = samples.size / ch
            for (f in 0 until count) {
                var sum = 0
                for (c in 0 until ch) sum += samples[f * ch + c]
                val v = sum / ch
                // Linear interpolation between the previous and this frame.
                while (position <= sourceFrame) {
                    val t = 1 - (sourceFrame - position)
                    val s = (previous + (v - previous) * t).toInt()
                    mono.write(s and 0xff)
                    mono.write((s shr 8) and 0xff)
                    position += step
                }
                previous = v
                sourceFrame++
            }
        }
        return mono.toByteArray()
    }

    private fun durationUs(path: String): Long {
        val ex = MediaExtractor()
        try {
            ex.setDataSource(path)
            for (t in 0 until ex.trackCount) {
                val f = ex.getTrackFormat(t)
                if (f.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true &&
                    f.containsKey(MediaFormat.KEY_DURATION)
                ) return f.getLong(MediaFormat.KEY_DURATION)
            }
        } finally {
            ex.release()
        }
        return 0
    }

    private fun downmix(samples: ShortArray, from: Int, to: Int): ShortArray {
        if (from == to) return samples
        val frames = samples.size / from
        val out = ShortArray(frames * to)
        for (f in 0 until frames) {
            if (to == 1) {
                var sum = 0
                for (c in 0 until from) sum += samples[f * from + c]
                out[f] = (sum / from).toShort()
            } else {
                out[f * 2] = samples[f * from]
                out[f * 2 + 1] = samples[f * from + if (from > 1) 1 else 0]
            }
        }
        return out
    }

    /**
     * Decodes the first audio track, calling [onFormat] once with the output
     * rate and channel count, then [onPcm] with interleaved 16-bit chunks.
     */
    private fun decode(
        path: String,
        onFormat: (Int, Int) -> Unit,
        onPcm: (ShortArray, Int) -> Unit
    ) {
        val ex = MediaExtractor()
        ex.setDataSource(path)
        val track = (0 until ex.trackCount).firstOrNull {
            ex.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
        } ?: run {
            ex.release()
            throw IOException("no audio track")
        }
        ex.selectTrack(track)
        val input = ex.getTrackFormat(track)
        val codec = MediaCodec.createDecoderByType(input.getString(MediaFormat.KEY_MIME)!!)
        codec.configure(input, null, null, 0)
        codec.start()
        val info = MediaCodec.BufferInfo()
        var channels = 0
        var encoding = AudioFormat.ENCODING_PCM_16BIT
        fun readFormat() {
            val f = codec.outputFormat
            channels = f.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            encoding = if (f.containsKey(MediaFormat.KEY_PCM_ENCODING))
                f.getInteger(MediaFormat.KEY_PCM_ENCODING) else AudioFormat.ENCODING_PCM_16BIT
            onFormat(f.getInteger(MediaFormat.KEY_SAMPLE_RATE), channels)
        }
        var inputDone = false
        try {
            while (true) {
                if (!inputDone) {
                    val i = codec.dequeueInputBuffer(TIMEOUT_US)
                    if (i >= 0) {
                        val n = ex.readSampleData(codec.getInputBuffer(i)!!, 0)
                        if (n < 0) {
                            codec.queueInputBuffer(i, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            codec.queueInputBuffer(i, 0, n, ex.sampleTime, 0)
                            ex.advance()
                        }
                    }
                }
                val o = codec.dequeueOutputBuffer(info, TIMEOUT_US)
                if (o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    readFormat()
                } else if (o >= 0) {
                    if (channels == 0) readFormat()
                    if (info.size > 0) {
                        val buf = codec.getOutputBuffer(o)!!
                        buf.position(info.offset)
                        buf.limit(info.offset + info.size)
                        onPcm(toShorts(buf.order(ByteOrder.LITTLE_ENDIAN), encoding), channels)
                    }
                    codec.releaseOutputBuffer(o, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
                }
            }
        } finally {
            codec.stop()
            codec.release()
            ex.release()
        }
    }

    private fun toShorts(buf: ByteBuffer, encoding: Int): ShortArray = when (encoding) {
        AudioFormat.ENCODING_PCM_FLOAT -> {
            val f = buf.asFloatBuffer()
            ShortArray(f.remaining()) { (f.get().coerceIn(-1f, 1f) * 32767).toInt().toShort() }
        }
        AudioFormat.ENCODING_PCM_32BIT -> {
            val i = buf.asIntBuffer()
            ShortArray(i.remaining()) { (i.get() shr 16).toShort() }
        }
        AudioFormat.ENCODING_PCM_24BIT_PACKED -> ShortArray(buf.remaining() / 3) {
            buf.get() // drop the low byte
            val lo = buf.get().toInt() and 0xff
            val hi = buf.get().toInt()
            ((hi shl 8) or lo).toShort()
        }
        AudioFormat.ENCODING_PCM_8BIT -> ShortArray(buf.remaining()) {
            (((buf.get().toInt() and 0xff) - 128) shl 8).toShort()
        }
        else -> {
            val s = buf.asShortBuffer()
            ShortArray(s.remaining()).also { s.get(it) }
        }
    }

    private val adtsRates = intArrayOf(
        96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050, 16000, 12000, 11025, 8000, 7350
    )

    private fun adtsHeader(payload: Int, rate: Int, channels: Int): ByteArray {
        val length = payload + 7
        val freq = adtsRates.indexOf(rate).let { if (it < 0) 4 else it }
        val profile = 1 // AAC LC (object type 2) - 1
        return byteArrayOf(
            0xFF.toByte(),
            0xF1.toByte(),
            ((profile shl 6) or (freq shl 2) or (channels shr 2)).toByte(),
            (((channels and 3) shl 6) or (length shr 11)).toByte(),
            ((length shr 3) and 0xFF).toByte(),
            (((length and 7) shl 5) or 0x1F).toByte(),
            0xFC.toByte()
        )
    }
}
