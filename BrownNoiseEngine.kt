package com.focusguard.focusguard

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import java.util.Random

/**
 * Pure offline Brown Noise synthesizer (0 KB audio assets).
 * Produces warm, low-frequency focus soundscape to block hostel/ward noise.
 */
object BrownNoiseEngine {
    @Volatile
    private var running = false
    private var thread: Thread? = null

    @Synchronized
    fun setEnabled(enable: Boolean) {
        if (enable == running) return
        if (enable) start() else stop()
    }

    private fun start() {
        running = true
        thread = Thread {
            var track: AudioTrack? = null
            try {
                val sr = 22050
                val minBuf = AudioTrack.getMinBufferSize(
                    sr,
                    AudioFormat.CHANNEL_OUT_MONO,
                    AudioFormat.ENCODING_PCM_16BIT
                ).coerceAtLeast(4096)

                track = AudioTrack.Builder()
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                            .build()
                    )
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setSampleRate(sr)
                            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                            .build()
                    )
                    .setBufferSizeInBytes(minBuf)
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .build()

                track.play()
                val buf = ShortArray(1024)
                val rng = Random()
                var lastOut = 0.0
                while (running) {
                    for (i in buf.indices) {
                        val white = rng.nextDouble() * 2.0 - 1.0
                        lastOut = (lastOut + 0.02 * white) / 1.02
                        val sample = (lastOut * 3.2 * 9000.0).coerceIn(-24000.0, 24000.0)
                        buf[i] = sample.toInt().toShort()
                    }
                    track.write(buf, 0, buf.size)
                }
            } catch (_: Exception) {
            } finally {
                running = false
                try {
                    track?.stop()
                    track?.release()
                } catch (_: Exception) {}
            }
        }.apply {
            isDaemon = true
            start()
        }
    }

    private fun stop() {
        running = false
        thread = null
    }
}
