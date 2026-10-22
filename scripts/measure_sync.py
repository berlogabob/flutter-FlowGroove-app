#!/usr/bin/env python3
"""Measure a mono SoX recording of the metronome and diagnostic backing.

Record with: rec -c 1 rec.wav
Analyze with: uv run --with numpy --with scipy scripts/measure_sync.py rec.wav --bpm 123
"""

import argparse
import sys

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, find_peaks, hilbert, sosfiltfilt


def onsets(audio, sample_rate, band, separation):
    sos = butter(4, band, btype="bandpass", fs=sample_rate, output="sos")
    envelope = np.abs(hilbert(sosfiltfilt(sos, audio)))
    window = max(1, round(sample_rate * 0.001))
    envelope = np.convolve(envelope, np.ones(window) / window, mode="same")
    noise = np.percentile(envelope, 20)
    peaks, _ = find_peaks(
        envelope,
        height=max(envelope.max() * 0.15, noise * 6),
        prominence=max(envelope.max() * 0.1, noise * 3),
        distance=max(1, round(separation * sample_rate)),
    )
    times = []
    for peak in peaks:
        threshold = max(envelope[peak] * 0.2, noise * 3)
        start = peak
        while start > 0 and envelope[start - 1] > threshold:
            start -= 1
        # Ignore events truncated by either edge of the recording.
        if start < sample_rate * 0.03 or peak > len(audio) - sample_rate * 0.03:
            continue
        before, after = envelope[start - 1 : start + 1]
        fraction = (threshold - before) / (after - before)
        times.append((start - 1 + fraction) / sample_rate)
    return np.array(times)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("wav", help="Mono WAV recorded with SoX rec")
    parser.add_argument("--bpm", type=float, required=True)
    args = parser.parse_args()
    if not np.isfinite(args.bpm) or args.bpm <= 0:
        parser.error("--bpm must be positive and finite")

    try:
        sample_rate, audio = wavfile.read(args.wav)
        if audio.ndim != 1:
            raise ValueError("record a mono WAV (rec -c 1 rec.wav)")
        if sample_rate <= 6800:
            raise ValueError("sample rate must exceed 6800 Hz")
        if len(audio) < sample_rate or not np.all(np.isfinite(audio)):
            raise ValueError("record at least one second of finite audio")
        audio = audio.astype(np.float64)
        audio -= audio.mean()
        peak = np.max(np.abs(audio))
        if peak == 0:
            raise ValueError("recording is silent")
        audio /= peak
        beat = 60 / args.bpm
        clicks = onsets(audio, sample_rate, (800, 2200), beat * 0.1)
        bursts = onsets(audio, sample_rate, (2600, 3400), beat * 0.4)
        if len(clicks) < 3 or len(bursts) < 3:
            raise ValueError("need at least three clicks and diagnostic bursts")

        # Match each burst to its nearest click, allowing either offset sign.
        times, offsets = [], []
        used = set()
        for burst in bursts:
            right = np.searchsorted(clicks, burst)
            candidates = [i for i in (right - 1, right) if 0 <= i < len(clicks)]
            index = min(candidates, key=lambda i: abs(burst - clicks[i]))
            if index not in used and abs(burst - clicks[index]) < beat * 0.45:
                used.add(index)
                times.append(clicks[index])
                offsets.append((burst - clicks[index]) * 1000)
        if len(times) < 3 or times[-1] - times[0] < beat:
            raise ValueError("not enough matched beats to measure drift")

        median = np.median(offsets)
        slope, _ = np.polyfit(np.array(times) - times[0], offsets, 1)
        duration = len(audio) / sample_rate
        drift = slope * duration
        passed = abs(median) < 3 and abs(drift) < 1
        print(f"Matched beats: {len(times)} ({duration:.1f} s recording)")
        print(f"Median offset (burst minus click): {median:+.3f} ms")
        print(f"Drift: {slope * 60:+.3f} ms/min ({drift:+.3f} ms over recording)")
        print(
            f"{'PASS' if passed else 'FAIL'}: "
            "|offset| < 3 ms and |drift over recording| < 1 ms"
        )
        return 0 if passed else 1
    except (OSError, ValueError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
