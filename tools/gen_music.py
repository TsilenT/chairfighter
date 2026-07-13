#!/usr/bin/env python3
"""Generate loopable chiptune-ish music beds (stdlib only).

Deliberately simple and low-key: soft bass pulse, gentle arpeggio, airy pad,
brushed noise hats. One mood per area + title/boss/victory. Loops are
bar-exact so AudioStreamWAV forward-looping is seamless.

Usage: python3 tools/gen_music.py   (writes assets/audio/music/<name>.wav)
"""
import math
import os
import random
import struct
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "music")

# Note helpers ---------------------------------------------------------------
A4 = 440.0
NOTES = {n: i for i, n in enumerate(
    ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}


def freq(name, octave):
    semis = NOTES[name] + (octave - 4) * 12 - 9  # relative to A4
    return A4 * (2 ** (semis / 12))


def clamp(x):
    return max(-1.0, min(1.0, x))


class Track:
    def __init__(self, bpm, bars, swing=0.0):
        self.bpm = bpm
        self.bars = bars
        self.beat = 60.0 / bpm
        self.dur = bars * 4 * self.beat
        self.n = int(self.dur * SR)
        self.buf = [0.0] * self.n

    def add_tone(self, t0, dur, f, vol, wave_fn, attack=0.01, release=0.08):
        s0 = int(t0 * SR)
        s1 = min(int((t0 + dur) * SR), self.n)
        for i in range(s0, s1):
            t = i / SR - t0
            env = 1.0
            if t < attack:
                env = t / attack
            elif t > dur - release:
                env = max((dur - t) / release, 0.0)
            self.buf[i] += wave_fn(f, i / SR) * vol * env

    def add_noise_tick(self, t0, dur, vol):
        s0 = int(t0 * SR)
        s1 = min(int((t0 + dur) * SR), self.n)
        for i in range(s0, s1):
            t = i / SR - t0
            env = max(1.0 - t / dur, 0.0) ** 2
            self.buf[i] += random.uniform(-1, 1) * vol * env

    def write(self, name, gain=0.9):
        os.makedirs(OUT, exist_ok=True)
        peak = max(abs(s) for s in self.buf) or 1.0
        norm = gain / peak
        path = os.path.join(OUT, name + ".wav")
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(b"".join(
                struct.pack("<h", int(clamp(s * norm) * 30000)) for s in self.buf))
        print("wrote", path, f"({self.dur:.1f}s)")


def sq(f, t, duty=0.5):
    return 0.6 if (f * t) % 1.0 < duty else -0.6


def tri(f, t):
    p = (f * t) % 1.0
    return 4 * abs(p - 0.5) - 1.0


def sine(f, t):
    return math.sin(2 * math.pi * f * t)


def soft_pad(f, t):
    return 0.6 * sine(f, t) + 0.3 * sine(f * 2, t) + 0.15 * sine(f * 1.5, t)


# Composition ----------------------------------------------------------------

def make_loop(name, bpm, chords, arp_oct=4, bass_oct=2, mood="warm",
              hats=True, pad=True, seed=7):
    """chords: list of (root, quality) per bar, quality in maj/min."""
    random.seed(seed)
    tr = Track(bpm, len(chords))
    b = tr.beat
    for bar, (root, quality) in enumerate(chords):
        t_bar = bar * 4 * b
        third = 3 if quality == "min" else 4
        tones = [0, third, 7, 12]
        # Bass: root pulse on 1 and 3.5 (a little lilt).
        for off in (0.0, 2.5):
            tr.add_tone(t_bar + off * b, b * 0.9, freq(root, bass_oct), 0.5,
                        lambda f, t: sq(f, t, 0.4), release=0.1)
        # Pad: airy chord.
        if pad:
            for semi in (tones[0], tones[1], tones[2]):
                tr.add_tone(t_bar, 4 * b, freq(root, 3) * 2 ** (semi / 12), 0.10,
                            soft_pad, attack=0.4, release=0.9)
        # Arp: 8th-note broken chord, occasionally resting.
        pattern = [0, 2, 1, 2, 3, 2, 1, 2]
        for i, idx in enumerate(pattern):
            if random.random() < 0.12:
                continue
            semi = tones[idx]
            tr.add_tone(t_bar + i * b / 2, b * 0.42,
                        freq(root, arp_oct) * 2 ** (semi / 12), 0.16, tri,
                        release=0.12)
        # Hats: offbeat ticks.
        if hats:
            for i in range(8):
                if i % 2 == 1:
                    tr.add_noise_tick(t_bar + i * b / 2, 0.03, 0.10)
    tr.write(name)


def main():
    # Title: hopeful, mid-tempo.
    make_loop("title", 96, [("C", "maj"), ("A", "min"), ("F", "maj"), ("G", "maj")] * 2, seed=1)
    # Workshop: cozy tinkering.
    make_loop("workshop", 104, [("F", "maj"), ("D", "min"), ("A#", "maj"), ("C", "maj")] * 2, seed=2)
    # Lounge: plush waltz-ish warmth (still 4/4, lazier arp).
    make_loop("lounge", 88, [("D", "min"), ("A#", "maj"), ("F", "maj"), ("C", "maj")] * 2, seed=3)
    # Office: busy, caffeinated.
    make_loop("office", 122, [("E", "min"), ("C", "maj"), ("G", "maj"), ("D", "maj")] * 2, seed=4)
    # Storage: clanky suspense, sparse pad.
    make_loop("storage", 100, [("G", "min"), ("D#", "maj"), ("F", "maj"), ("D", "min")] * 2,
              pad=False, seed=5)
    # Throne: regal minor pomp.
    make_loop("throne", 92, [("A", "min"), ("F", "maj"), ("D", "min"), ("E", "maj")] * 2, seed=6)
    # Boss: driving.
    make_loop("boss", 140, [("A", "min"), ("A", "min"), ("F", "maj"), ("G", "maj")] * 2,
              arp_oct=5, seed=8)
    # Victory: bright.
    make_loop("victory", 108, [("C", "maj"), ("G", "maj"), ("A", "min"), ("F", "maj"),
                               ("C", "maj"), ("G", "maj"), ("F", "maj"), ("C", "maj")], seed=9)


if __name__ == "__main__":
    main()
