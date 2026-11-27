#!/usr/bin/env python3
"""Composes the game's music track from code (P2-18).

An original, loopable piece in D minor at 96 BPM (32 bars, about 80 s): a
marching snare and timpani, a bass ostinato, string-like pads and a brass-like
melody in the middle section. Everything is synthesized here with numpy (no
samples), with a fixed random seed for the drum noise, so the result is
original, reproducible and licensed like the project's assets (CC BY-SA 4.0).

Writes game/assets/audio/music/main_theme.ogg (encoded with ffmpeg, which
must be on PATH) and updates ASSET_MANIFEST.csv.

Usage: python3 tools/gen_music.py [--wav OUT.wav]   (--wav also keeps the raw mix)
"""

import csv
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "game", "assets", "audio", "music", "main_theme.ogg")
MANIFEST = os.path.join(REPO, "ASSET_MANIFEST.csv")
RATE = 44100
BPM = 96
BEAT = 60.0 / BPM
BAR = 4 * BEAT
BARS = 32
LENGTH = BARS * BAR
RNG = np.random.default_rng(20261127)

# Note numbers: MIDI style, 69 = A4 = 440 Hz.
D, E, F, G, A, Bb, C = 62, 64, 65, 67, 69, 70, 72
# Chords per two bars: root note and chord tones (semitones above the root).
MINOR = (0, 3, 7)
MAJOR = (0, 4, 7)
SECTION_A = [(D, MINOR), (Bb - 12, MAJOR), (F - 12, MAJOR), (C - 12, MAJOR)]
SECTION_B = [(G - 12, MINOR), (D, MINOR), (Bb - 12, MAJOR), (A - 12, MAJOR)]
FORM = SECTION_A + SECTION_A + SECTION_B + SECTION_A   # 16 chords x 2 bars = 32 bars
# Brass melody for section B (bars 16-23): (note, start beat in section, beats).
MELODY = [(A, 0, 1.5), (Bb, 1.5, 0.5), (A, 2, 1), (G, 3, 1), (F, 4, 2), (D, 6, 2),
          (G, 8, 1.5), (A, 9.5, 0.5), (Bb, 10, 2), (A, 12, 3), (D + 12, 15, 1),
          (C + 12 - 12, 16, 2), (Bb, 18, 2), (A, 20, 1.5), (G, 21.5, 0.5), (F, 22, 2),
          (E, 24, 2), (F, 26, 1), (G, 27, 1), (A, 28, 4)]


def hz(note):
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def samples(seconds):
    return int(round(seconds * RATE))


def adsr(n, attack, release):
    """Envelope of n samples with linear attack and release (seconds)."""
    env = np.ones(n)
    a = min(n, samples(attack))
    r = min(n - a, samples(release))
    if a > 0:
        env[:a] = np.linspace(0.0, 1.0, a)
    if r > 0:
        env[n - r:] *= np.linspace(1.0, 0.0, r)
    return env


def saw(freq, n, harmonics=12):
    t = np.arange(n) / RATE
    out = np.zeros(n)
    for k in range(1, harmonics + 1):
        if freq * k > RATE / 2:
            break
        out += np.sin(2 * np.pi * freq * k * t) / k
    return out


def lowpass(x, cutoff, rolloff=0.15):
    """Smooth low-pass in the frequency domain (whole signal at once)."""
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / RATE)
    width = cutoff * rolloff
    gain = 1.0 / (1.0 + np.exp((freqs - cutoff) / max(width, 1.0)))
    return np.fft.irfft(spec * gain, len(x))


def place(track, start_s, sound):
    i = samples(start_s)
    j = min(len(track), i + len(sound))
    if i < len(track):
        track[i:j] += sound[:j - i]


def snare(accent):
    n = samples(0.18)
    t = np.arange(n) / RATE
    noise = RNG.uniform(-1.0, 1.0, n)
    body = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 40)
    return (0.7 * noise * np.exp(-t * 22) + 0.4 * body) * (1.0 if accent else 0.45)


def timpani():
    n = samples(0.9)
    t = np.arange(n) / RATE
    f = 85 - 30 * t / 0.9
    phase = 2 * np.pi * np.cumsum(f) / RATE
    return np.sin(phase) * np.exp(-t * 5.0)


def drums(total):
    track = np.zeros(total)
    for bar in range(BARS):
        t0 = bar * BAR
        place(track, t0, timpani() * 0.9)
        place(track, t0 + 2 * BEAT, timpani() * 0.6)
        # Marching pattern: accents on 2 and 4, ghost notes between.
        for step in range(8):
            accent = step in (2, 6)
            place(track, t0 + step * BEAT / 2, snare(accent))
        # A roll into every second bar's downbeat.
        if bar % 2 == 1:
            for k in range(8):
                place(track, t0 + 3 * BEAT + k * BEAT / 8, snare(False) * (0.4 + 0.08 * k))
    return track


def bass(total):
    track = np.zeros(total)
    pattern = [0, 0, 7, 0, 0, 0, 12, 7]   # eighth notes: root, root, fifth, ...
    for i, (root, _) in enumerate(FORM):
        for bar in range(2):
            t0 = (i * 2 + bar) * BAR
            for step, interval in enumerate(pattern):
                n = samples(BEAT / 2 * 0.9)
                tone = saw(hz(root - 24 + interval), n, 8) * adsr(n, 0.005, 0.08)
                place(track, t0 + step * BEAT / 2, tone)
    return lowpass(track, 700.0)


def pads(total):
    left = np.zeros(total)
    right = np.zeros(total)
    for i, (root, chord) in enumerate(FORM):
        n = samples(2 * BAR + 0.3)
        voice_l = np.zeros(n)
        voice_r = np.zeros(n)
        for interval in chord:
            f = hz(root + interval)
            voice_l += saw(f * 0.997, n, 10)
            voice_r += saw(f * 1.003, n, 10)
        env = adsr(n, 0.6, 0.5)
        place(left, i * 2 * BAR, voice_l * env)
        place(right, i * 2 * BAR, voice_r * env)
    return lowpass(left, 1800.0), lowpass(right, 1800.0)


def brass(total):
    track = np.zeros(total)
    start = 16 * BAR   # section B
    for note, beat, beats in MELODY:
        n = samples(beats * BEAT)
        t = np.arange(n) / RATE
        f = hz(note) * (1.0 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / 0.3, 0, 1))
        phase = 2 * np.pi * np.cumsum(f) / RATE
        tone = sum(np.sin(k * phase) / (k ** 1.2) for k in range(1, 9))
        place(track, start + beat * BEAT, tone * adsr(n, 0.05, 0.12))
    return lowpass(track, 2500.0)


def mix():
    total = samples(LENGTH)
    d = drums(total)
    b = bass(total)
    pl, pr = pads(total)
    m = brass(total)

    def norm(x):
        peak = np.max(np.abs(x))
        return x / peak if peak > 0 else x

    d, b, pl, pr, m = norm(d), norm(b), norm(pl), norm(pr), norm(m)
    left = 0.42 * d + 0.38 * b + 0.30 * pl + 0.34 * m
    right = 0.42 * d + 0.38 * b + 0.30 * pr + 0.30 * m
    stereo = np.stack([left, right], axis=1)
    stereo = np.tanh(stereo * 1.2)   # gentle soft clip
    return stereo / np.max(np.abs(stereo)) * 0.89   # about -1 dBFS


def write_wav(path, stereo):
    data = (np.clip(stereo, -1.0, 1.0) * 32767).astype("<i2").tobytes()
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)


def update_manifest(row):
    with open(MANIFEST, newline="", encoding="utf-8") as f:
        existing = list(csv.reader(f))
    header, body = existing[0], existing[1:]
    by_path = {r[0]: r for r in body}
    by_path[row[0]] = row
    with open(MANIFEST, "w", newline="", encoding="utf-8") as f:
        out = csv.writer(f, lineterminator="\n")
        out.writerow(header)
        for p in sorted(by_path):
            out.writerow(by_path[p])


def main():
    keep_wav = sys.argv[sys.argv.index("--wav") + 1] if "--wav" in sys.argv else None
    stereo = mix()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = keep_wav or os.path.join(tmp, "main_theme.wav")
        write_wav(wav, stereo)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "5",
                        "-map_metadata", "-1", OUT], check=True)
    rel = os.path.relpath(OUT, REPO).replace(os.sep, "/")
    update_manifest([rel, "Project Zero Hour contributors", "tools/gen_music.py (procedural)",
                     "CC-BY-SA-4.0", "script", "music: main theme (P2-18)"])
    print("[gen_music] %s: %.1f s, %d KB" % (rel, LENGTH, os.path.getsize(OUT) // 1024))


if __name__ == "__main__":
    main()
