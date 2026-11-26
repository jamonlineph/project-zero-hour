#!/usr/bin/env python3
"""Generates the placeholder sound effects (P1-29) from code.

Every sound is synthesized here from noise, sine waves and envelopes, with a
fixed random seed, so the files are original, reproducible and licensed like
the rest of the project's assets (CC BY-SA 4.0). Final sounds replace them in
Phase 2. Writes game/assets/audio/sfx/*.wav and updates ASSET_MANIFEST.csv.

Usage: python3 tools/gen_sounds.py
"""

import csv
import os
import wave

import numpy as np

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(REPO, "game", "assets", "audio", "sfx")
MANIFEST = os.path.join(REPO, "ASSET_MANIFEST.csv")
RATE = 22050
RNG = np.random.default_rng(20261126)


def _t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def _noise(seconds):
    return RNG.uniform(-1.0, 1.0, int(RATE * seconds))


def _lowpass(x, strength):
    """One-pole low-pass; strength 0..1 (higher = darker)."""
    y = np.empty_like(x)
    acc = 0.0
    a = 1.0 - strength
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def _env(seconds, attack, decay_power):
    t = _t(seconds)
    rise = np.clip(t / max(attack, 1e-4), 0.0, 1.0)
    fall = (1.0 - t / seconds) ** decay_power
    return rise * fall


def _norm(x, peak=0.85):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def rifle():
    s = 0.14
    return _norm(_lowpass(_noise(s), 0.35) * _env(s, 0.002, 6.0))


def autocannon():
    s = 0.22
    t = _t(s)
    thump = np.sin(2 * np.pi * 110 * t) * _env(s, 0.001, 5.0)
    return _norm(0.7 * _lowpass(_noise(s), 0.5) * _env(s, 0.001, 5.0) + 0.6 * thump)


def cannon():
    s = 0.7
    t = _t(s)
    boom = np.sin(2 * np.pi * (70 - 30 * t / s) * t) * _env(s, 0.002, 3.5)
    return _norm(0.8 * _lowpass(_noise(s), 0.8) * _env(s, 0.002, 4.0) + 0.7 * boom)


def artillery():
    s = 1.0
    t = _t(s)
    boom = np.sin(2 * np.pi * (55 - 20 * t / s) * t) * _env(s, 0.003, 3.0)
    return _norm(0.9 * _lowpass(_noise(s), 0.9) * _env(s, 0.003, 3.0) + 0.8 * boom)


def missile():
    s = 0.9
    t = _t(s)
    hiss = _lowpass(_noise(s), 0.6) * _env(s, 0.08, 1.5)
    tone = 0.15 * np.sin(2 * np.pi * (300 + 500 * t / s) * t) * _env(s, 0.05, 2.0)
    return _norm(hiss + tone)


def laser():
    s = 0.35
    t = _t(s)
    f = 1400 - 800 * t / s
    phase = 2 * np.pi * np.cumsum(f) / RATE
    tone = np.sin(phase) + 0.3 * np.sin(2 * phase)
    return _norm(tone * _env(s, 0.005, 2.0), 0.6)


def explosion_small():
    s = 0.7
    return _norm(_lowpass(_noise(s), 0.85) * _env(s, 0.003, 3.0))


def explosion_large():
    s = 1.6
    t = _t(s)
    rumble = _lowpass(_noise(s), 0.95) * _env(s, 0.004, 2.2)
    sub = 0.5 * np.sin(2 * np.pi * (45 - 15 * t / s) * t) * _env(s, 0.004, 2.5)
    return _norm(rumble + sub)


def ui_click():
    s = 0.05
    t = _t(s)
    return _norm(np.sin(2 * np.pi * 1500 * t) * _env(s, 0.001, 3.0), 0.5)


def ack():
    s = 0.16
    t = _t(s)
    f = np.where(t < s / 2, 600.0, 900.0)
    phase = 2 * np.pi * np.cumsum(f) / RATE
    return _norm(np.sin(phase) * _env(s, 0.005, 1.5), 0.45)


def build_complete():
    s = 0.45
    t = _t(s)
    f = np.select([t < 0.15, t < 0.3], [520.0, 660.0], 780.0)
    phase = 2 * np.pi * np.cumsum(f) / RATE
    return _norm(np.sin(phase) * _env(s, 0.005, 1.2), 0.5)


SOUNDS = {
    "rifle": rifle, "autocannon": autocannon, "cannon": cannon, "artillery": artillery,
    "missile": missile, "laser": laser, "explosion_small": explosion_small,
    "explosion_large": explosion_large, "ui_click": ui_click, "ack": ack,
    "build_complete": build_complete,
}


def write_wav(path, samples):
    data = (np.clip(samples, -1.0, 1.0) * 32767).astype("<i2").tobytes()
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)


def update_manifest(rows):
    with open(MANIFEST, newline="", encoding="utf-8") as f:
        existing = list(csv.reader(f))
    header, body = existing[0], existing[1:]
    by_path = {r[0]: r for r in body}
    for r in rows:
        by_path[r[0]] = r
    with open(MANIFEST, "w", newline="", encoding="utf-8") as f:
        out = csv.writer(f, lineterminator="\n")
        out.writerow(header)
        for p in sorted(by_path):
            out.writerow(by_path[p])


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    rows = []
    for name, make in SOUNDS.items():
        path = os.path.join(OUT_DIR, name + ".wav")
        write_wav(path, make())
        rel = os.path.relpath(path, REPO).replace(os.sep, "/")
        rows.append([rel, "Project Zero Hour contributors", "tools/gen_sounds.py (procedural)",
                     "CC-BY-SA-4.0", "script", "placeholder"])
        print("[gen_sounds] %s" % rel)
    update_manifest(rows)
    print("[gen_sounds] done: %d sounds" % len(rows))


if __name__ == "__main__":
    main()
