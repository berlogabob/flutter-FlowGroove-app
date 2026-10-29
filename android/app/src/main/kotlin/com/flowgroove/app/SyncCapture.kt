package com.flowgroove.app

import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Sync-test aid (SYNC_TEST builds only): records the first channel of the exact PCM the
 * engine hands to the AudioTrack, so click/backing alignment can be measured digitally,
 * free of speaker, microphone and room artifacts.
 */
class SyncCapture(
    private val file: File,
    private val sampleRate: Int,
    private val maxFrames: Long
) {
    private val data = ByteArrayOutputStream()
    private var frames = 0L

    /** Appends one chunk; returns true once [maxFrames] have been recorded. */
    @Synchronized
    fun add(pcm: ShortArray, channels: Int): Boolean {
        val bytes = ByteBuffer.allocate((pcm.size / channels) * 2).order(ByteOrder.LITTLE_ENDIAN)
        var i = 0
        while (i < pcm.size) {
            bytes.putShort(pcm[i])
            i += channels
        }
        data.write(bytes.array())
        frames += pcm.size / channels
        return frames >= maxFrames
    }

    @Synchronized
    fun finish() {
        val pcm = data.toByteArray()
        val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
        header.put("RIFF".toByteArray()).putInt(36 + pcm.size).put("WAVE".toByteArray())
        header.put("fmt ".toByteArray()).putInt(16).putShort(1).putShort(1)
            .putInt(sampleRate).putInt(sampleRate * 2).putShort(2).putShort(16)
        header.put("data".toByteArray()).putInt(pcm.size)
        file.parentFile?.mkdirs()
        file.outputStream().use {
            it.write(header.array())
            it.write(pcm)
        }
    }
}
