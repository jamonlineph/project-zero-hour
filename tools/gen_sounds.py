#!/usr/bin/env python3
"""Generates the placeholder sound effects (P1-29) from code.

Every sound is synthesized here from noise, sine waves and envelopes, with a
fixed random seed, so the files are original, reproducible and licensed like
the rest of the project's assets (CC BY-SA 4.0). The P2-18 audio pass added
alerts, protection, jamming and acknowledgement sounds. Writes game/assets/audio/sfx/*.wav and updates ASSET_MANIFEST.csv.

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


# --- P2-18 additions (kept after the originals: the shared random stream
# stays in the same order, so the first sounds don't change) -------------

def _tones(seconds, steps, attack=0.005, decay=1.2, peak=0.5):
    """Notes in sequence: steps = [(frequency, start_seconds), ...]."""
    t = _t(seconds)
    f = np.full_like(t, steps[0][0])
    for freq, start in steps[1:]:
        f = np.where(t >= start, freq, f)
    phase = 2 * np.pi * np.cumsum(f) / RATE
    tone = np.sin(phase) + 0.25 * np.sin(2 * phase)
    return _norm(tone * _env(seconds, attack, decay), peak)


def _chirp(seconds, f0, f1, squelch):
    """Radio acknowledgement: a squelch burst, then a short tone glide."""
    t = _t(seconds)
    f = f0 + (f1 - f0) * t / seconds
    phase = 2 * np.pi * np.cumsum(f) / RATE
    tone = np.sin(phase) * _env(seconds, 0.01, 1.5)
    burst = _lowpass(_noise(seconds), 0.3) * np.clip(1.0 - t / squelch, 0.0, 1.0) * 0.5
    return _norm(tone + burst, 0.45)


def ack_2():
    return _chirp(0.18, 700.0, 1000.0, 0.04)


def ack_3():
    return _chirp(0.2, 950.0, 650.0, 0.05)


def aps_intercept():
    """Active protection: a sharp crack and a short whoosh."""
    s = 0.4
    t = _t(s)
    crack = _noise(s) * np.exp(-t * 60.0)
    whoosh = _lowpass(_noise(s), 0.7) * _env(s, 0.02, 2.5) * 0.6
    return _norm(crack + whoosh)


def jam_static():
    """Jamming: warbling radio static."""
    s = 0.5
    t = _t(s)
    warble = 0.5 + 0.5 * np.sin(2 * np.pi * 14 * t)
    return _norm(_noise(s) * warble * _env(s, 0.02, 1.0), 0.55)


def power_alert():
    """A commander power was used: a two-tone rising alert."""
    return _tones(0.5, [(440.0, 0.0), (660.0, 0.12), (880.0, 0.24)], decay=1.0, peak=0.5)


def upgrade_complete():
    return _tones(0.6, [(523.0, 0.0), (659.0, 0.12), (784.0, 0.24), (1047.0, 0.36)], decay=1.4)


def rank_up():
    """Promotion: a short brass-like fanfare (stacked harmonics)."""
    s = 0.9
    t = _t(s)
    f = np.select([t < 0.15, t < 0.3], [392.0, 523.0], 659.0)
    phase = 2 * np.pi * np.cumsum(f) / RATE
    brass = sum(np.sin(k * phase) / k for k in range(1, 6))
    return _norm(brass * _env(s, 0.02, 1.3), 0.5)


def strike_incoming():
    """An enemy strike was launched: a falling whistle."""
    s = 1.2
    t = _t(s)
    f = 1500.0 - 900.0 * t / s
    phase = 2 * np.pi * np.cumsum(f) / RATE
    return _norm(np.sin(phase) * _env(s, 0.1, 0.8), 0.4)


def under_attack():
    """Low two-pulse alarm when our units or buildings are lost."""
    s = 0.8
    t = _t(s)
    gate = ((t % 0.4) < 0.25).astype(float)
    tone = np.sign(np.sin(2 * np.pi * 330 * t)) * 0.4 + np.sin(2 * np.pi * 165 * t)
    return _norm(_lowpass(tone * gate, 0.5) * _env(s, 0.01, 0.6), 0.5)


SOUNDS = {
    "rifle": rifle, "autocannon": autocannon, "cannon": cannon, "artillery": artillery,
    "missile": missile, "laser": laser, "explosion_small": explosion_small,
    "explosion_large": explosion_large, "ui_click": ui_click, "ack": ack,
    "build_complete": build_complete,
    # P2-18
    "ack_2": ack_2, "ack_3": ack_3, "aps_intercept": aps_intercept, "jam_static": jam_static,
    "power_alert": power_alert, "upgrade_complete": upgrade_complete, "rank_up": rank_up,
    "strike_incoming": strike_incoming, "under_attack": under_attack,
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
