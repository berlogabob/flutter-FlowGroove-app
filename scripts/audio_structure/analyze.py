# /// script
# requires-python = ">=3.11,<3.13"
# dependencies = ["librosa>=0.10", "numpy", "scipy"]
# ///
"""Suggest a tempo grid and section markers for a song file (PRACTICE-MARKERS).

Usage:
    uv run --script scripts/audio_structure/analyze.py SONG.mp3 [--sections N]

Prints one JSON object: bpm, beatsPerBar, firstDownbeatMs, beatsMs,
downbeatsMs, segments [{label, startMs, endMs}]. Labels are letters; the same
letter = similar-sounding section (A/B often verse/chorus). Suggestions only:
the owner confirms or drags them in the app.
"""

import argparse
import json
import sys

import librosa
import numpy as np
import scipy.signal
from scipy.cluster import hierarchy

SR = 22050
HOP = 512


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("song")
    parser.add_argument("--sections", type=int, default=10)
    args = parser.parse_args(argv)

    y, sr = librosa.load(args.song, sr=SR, mono=True)
    _, beat_frames = librosa.beat.beat_track(y=y, sr=sr, hop_length=HOP)
    beats = librosa.frames_to_time(beat_frames, sr=sr, hop_length=HOP)
    bpm = 60.0 / float(np.median(np.diff(beats)))

    # Downbeat phase: the beat phase (mod 4) with the most low-end energy
    # (kick drum / bass land on the one). ponytail: assumes 4/4.
    b, a = scipy.signal.butter(4, 150 / (sr / 2), btype="low")
    low_rms = librosa.feature.rms(y=scipy.signal.lfilter(b, a, y), hop_length=HOP)[0]
    at_beat = low_rms[np.clip(beat_frames, 0, len(low_rms) - 1)]
    phase = int(np.argmax([at_beat[p::4].sum() for p in range(4)]))
    downbeat_frames = beat_frames[phase::4]

    # Sections: bar-synchronous chroma + MFCC, self-similarity novelty
    # (Foote checkerboard, 8-bar kernel), strongest peaks >= 4 bars apart.
    # Boundaries fall on downbeats by construction.
    feats = np.vstack([
        librosa.feature.chroma_cqt(y=y, sr=sr, hop_length=HOP),
        librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13, hop_length=HOP)[1:],
    ])
    feats = librosa.util.normalize(feats, axis=1)
    bars = librosa.util.sync(feats, downbeat_frames, aggregate=np.mean)[:, 1:]
    unit = bars / (np.linalg.norm(bars, axis=0, keepdims=True) + 1e-9)
    ssm = unit.T @ unit
    k = 4
    sign = np.sign(np.subtract.outer(np.arange(-k, k), -0.5))
    kernel = np.outer(sign, sign) * np.outer(*[np.hanning(2 * k)] * 2)
    padded = np.pad(ssm, k, mode="edge")
    novelty = np.array([
        (padded[i:i + 2 * k, i:i + 2 * k] * kernel).sum() for i in range(ssm.shape[0])
    ])
    picked = []
    for i in np.argsort(novelty)[::-1]:
        if len(picked) >= args.sections - 1:
            break
        if novelty[i] > 0 and 2 <= i and all(abs(i - j) >= 4 for j in picked):
            picked.append(int(i))
    downs = librosa.frames_to_time(downbeat_frames, sr=sr, hop_length=HOP)
    end_t = len(y) / sr
    cuts = [i for i in sorted(picked) if i < len(downs)]
    edges = [0.0] + [float(downs[i]) for i in cuts] + [end_t]
    bar_edges = [0] + cuts + [bars.shape[1]]  # bars column j starts at downs[j]

    # Labels: cluster segment mean features (cosine), threshold relative to
    # this song's spread; letters by first use.
    means = [bars[:, a:max(b, a + 1)].mean(axis=1)
             for a, b in zip(bar_edges[:-1], bar_edges[1:])]
    if len(means) > 1:
        z = hierarchy.linkage(np.array(means), method="average", metric="cosine")
        clusters = hierarchy.fcluster(z, t=0.5 * z[:, 2].max(), criterion="distance")
    else:
        clusters = [1]
    letters = {}
    labels = [letters.setdefault(c, chr(ord("A") + len(letters))) for c in clusters]

    ms = lambda t: int(round(t * 1000))
    print(json.dumps({
        "bpm": round(bpm, 1),
        "beatsPerBar": 4,
        "firstDownbeatMs": ms(downs[0]) if len(downs) else 0,
        "beatsMs": [ms(t) for t in beats],
        "downbeatsMs": [ms(t) for t in downs],
        "segments": [
            {"label": l, "startMs": ms(s), "endMs": ms(e)}
            for l, s, e in zip(labels, edges[:-1], edges[1:])
        ],
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
