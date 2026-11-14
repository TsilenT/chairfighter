#!/usr/bin/env python3
"""Generate loopable music with hand-written patterns (stdlib only).

The eight floors each have their own melody, groove, and instrumentation.
The four new guardians pick up their area's melody in a faster arrangement.
The King has his own minor-key march.

Usage: python3 tools/gen_music.py [track ...]
Writes assets/audio/music/<name>.wav, for all tracks by default.
"""
import argparse
import math
import os
import random
import struct
import wave
from dataclasses import dataclass

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
    def __init__(self, bpm, bars, beats_per_bar=4):
        self.beat = 60.0 / bpm
        self.bar = beats_per_bar * self.beat
        self.dur = bars * self.bar
        self.n = int(self.dur * SR)
        self.buf = [0.0] * self.n

    def add_tone(self, t0, dur, f, vol, wave_fn, attack=0.01, release=0.08,
                 retrigger_phase=False):
        s0 = math.ceil(t0 * SR) if retrigger_phase else int(t0 * SR)
        s1 = min(int((t0 + dur) * SR), self.n)
        for i in range(s0, s1):
            t = i / SR - t0
            env = 1.0
            if t < attack:
                env = t / attack
            elif t > dur - release:
                env = max((dur - t) / release, 0.0)
            self.buf[i] += wave_fn(f, t if retrigger_phase else i / SR) * vol * env

    def add_voice(self, t0, dur, pitch, volume, instrument, release=0.08, attack=0.007):
        self.add_tone(t0, dur, pitch, volume, instrument, attack=attack,
                      release=release, retrigger_phase=True)

    def add_noise_tick(self, t0, dur, vol):
        s0 = int(t0 * SR)
        s1 = min(int((t0 + dur) * SR), self.n)
        for i in range(s0, s1):
            t = i / SR - t0
            env = max(1.0 - t / dur, 0.0) ** 2
            self.buf[i] += random.uniform(-1, 1) * vol * env

    def write(self, name, gain=0.9, smooth_loop=False, rms_target=None):
        if smooth_loop:
            # The final note may decay just past the last sample on a fractional beat.
            fade = int(0.005 * SR)
            for offset in range(fade):
                self.buf[-1 - offset] *= offset / fade
        os.makedirs(OUT, exist_ok=True)
        peak = max(abs(s) for s in self.buf) or 1.0
        norm = gain / peak
        if rms_target is not None:
            rms = math.sqrt(sum(s * s for s in self.buf) / len(self.buf))
            norm = min(norm, rms_target / rms)
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

def make_loop(name, bpm, chords, arp_oct=4, bass_oct=2,
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


def transposed(pitch, semitones):
    return pitch * 2 ** (semitones / 12)


def pluck(f, t):
    return math.exp(-4 * t) * (sine(f, t) + 0.26 * math.exp(-8 * t) * sine(3 * f, t))


def reeds(f, t):
    f *= 1 + 0.002 * sine(4.8, t)
    return 0.72 * sine(f, t) + 0.19 * sine(2 * f, t) + 0.09 * sine(3 * f, t)


def drum(_f, t):
    # Falling pitch written directly as phase, with a tight felt-mallet tail.
    return math.exp(-26 * t) * math.sin(2 * math.pi * (48 * t + 2.5 * (1 - math.exp(-20 * t))))


def electric_piano(f, t):
    phase = 2 * math.pi * f * t
    tine = 1.15 * math.exp(-10 * t) * math.sin(phase * 2)
    return math.exp(-2.6 * t) * (0.82 * math.sin(phase + tine) + 0.18 * math.sin(phase * 2))


def chip_lead(f, t):
    vibrato = 0.08 * math.sin(2 * math.pi * 5.2 * t)
    phase = 2 * math.pi * f * t + vibrato
    return (math.sin(phase) + 0.28 * math.sin(3 * phase) - 0.14 * math.sin(5 * phase)
            + 0.09 * math.sin(7 * phase)) * 0.72


def saw_bass(f, t):
    phase = 2 * math.pi * f * t
    resonance = math.exp(-8 * t)
    return 0.66 * math.sin(phase) + resonance * (
        0.24 * math.sin(2 * phase) + 0.17 * math.sin(3 * phase) + 0.11 * math.sin(4 * phase))


def brass(f, t):
    phase = 2 * math.pi * f * t
    breath = math.exp(-10 * t) * math.sin(phase * 2) * 0.65
    return 0.62 * math.sin(phase + breath) + 0.21 * math.sin(phase * 2) + 0.17 * math.sin(phase / 2)


def toy_bell(f, t):
    return 0.77 * math.exp(-4.5 * t) * sine(f, t) + 0.23 * math.exp(-14 * t) * sine(2.76 * f, t)


def metal(_f, t):
    return (sine(920, t) * 0.46 + sine(1431, t) * 0.34 + sine(2721, t) * 0.20) * math.exp(-36 * t)


def clack(_f, t):
    return (sine(510, t) * 0.55 + sine(1324, t) * 0.45) * math.exp(-59 * t)


def snare(f, t):
    return 0.7 * math.exp(-41 * t) * sine(f, t) + 0.3 * math.exp(-68 * t) * sine(1.48 * f, t)


@dataclass(frozen=True)
class Groove:
    kick: tuple
    snare: tuple
    hats: tuple
    bass: tuple
    chords: tuple
    percussion: tuple


@dataclass(frozen=True)
class FloorScore:
    bpm: int
    harmony: tuple
    melody: tuple
    lead: object
    keys: object
    bass: object
    groove: Groove


GROOVES = {
    "swing": Groove((0.0, 2.67), (1, 3), (0.67, 1.67, 2.67, 3.67),
                    ((0, 0, 0.8), (1, 7, 0.78), (2, 12, 0.55), (2.67, 7, 0.3), (3.25, 10, 0.62)),
                    (0.67, 2.0, 3.0), (1.67, 3.67)),
    "funk": Groove((0, 0.75, 2, 2.75), (1, 3), (0.5, 1.5, 2.5, 3.5, 3.75),
                   ((0, 0, 0.52), (0.75, 0, 0.22), (1.25, 7, 0.38), (2, 12, 0.38),
                    (2.75, 0, 0.55), (3.5, 7, 0.38)), (0.5, 1.75, 3.5), (0.25, 2.5)),
    "breakbeat": Groove((0, 1.75, 2.5, 3.75), (1, 3), (0.5, 1.25, 2, 2.75, 3.5),
                        ((0, 0, 1.35), (1.75, 12, 0.4), (2.5, 7, 0.58), (3.5, 0, 0.42)),
                        (1.5, 2.75), (0.75, 2.25, 3.5)),
    "industrial": Groove((0, 1.5, 2.0, 2.75, 3.5), (1, 3), (0.5, 1.75, 2.5, 3.75),
                         ((0, 0, 0.65), (0.75, 0, 0.35), (1.5, 12, 0.35), (2, 0, 0.65),
                          (2.75, 7, 0.35), (3.5, 0, 0.4)), (0, 2.75), (0.75, 1.25, 2.25, 3.5)),
    "disco": Groove((0, 1, 2, 3), (1, 3), (0.5, 1.5, 2.5, 3.5),
                    ((0, 0, 0.47), (0.5, 12, 0.3), (1.25, 0, 0.52), (2, 7, 0.4),
                     (2.5, 12, 0.45), (3.25, 7, 0.23), (3.5, 0, 0.44)), (0.75, 1.5, 2.5, 3.75), (1.75, 3.5)),
    "jungle": Groove((0, 1.5, 2.25, 3.5), (1, 3), (0.5, 1.25, 1.75, 2.5, 3.25, 3.75),
                     ((0, 0, 1.35), (1.5, 12, 0.38), (2.25, 0, 0.99), (3.5, 7, 0.42)),
                     (0, 1.75, 3.25), (1.75, 2.75)),
    "pop": Groove((0, 1.5, 2.5, 3.75), (1, 3), (0.5, 1.25, 1.75, 2.5, 3.5),
                  ((0, 0, 0.9), (1.5, 7, 0.4), (2, 12, 0.38), (2.5, 0, 0.65), (3.5, 7, 0.4)),
                  (0, 1.75, 2.5), (0.75, 2.25, 3.75)),
}

MIN7 = (0, 3, 7, 10)
MAJ7 = (0, 4, 7, 11)
DOM7 = (0, 4, 7, 10)
ADD9 = (0, 4, 7, 14)
POWER = (0, 7, 12)

# Each melody row is one measure. Pitch:beats, with "-" marking a rest.
FLOOR_SCORES = {
    "lounge": FloorScore(
        106, (("D2", MIN7), ("G2", DOM7), ("C2", MAJ7), ("A2", DOM7),
              ("F2", MAJ7), ("E2", MIN7), ("D2", MIN7), ("A2", DOM7)),
        ("A4:1 C5:.67 D5:.33 F5:1 E5:.67 D5:.33",
         "B4:1.67 D5:.33 F5:.67 E5:.33 D5:1",
         "G4:1 C5:.67 E5:.33 G5:1 E5:.67 C5:.33",
         "C#5:1 E5:.67 G5:.33 A5:1 -:1",
         "A5:1 E5:1 F5:.67 C5:.33 A4:1",
         "G4:.67 B4:.33 D5:1 E5:.67 G5:.33 E5:1",
         "F5:1 D5:.67 E5:.33 F5:1 A4:1",
         "G4:.67 A4:.33 C#5:1 E5:1 -:1"),
        reeds, electric_piano, pluck, GROOVES["swing"]),
    "office": FloorScore(
        124, (("E2", MIN7), ("G2", MAJ7), ("D2", ADD9), ("A2", DOM7),
              ("E2", MIN7), ("B2", MIN7), ("C2", MAJ7), ("D2", ADD9)),
        ("E5:.5 G5:.25 -:.25 B5:.75 A5:.25 -:.25 G5:.5 E5:.75 -:.5",
         "G5:.5 B5:.5 D6:.75 B5:.25 A5:.5 G5:.75 -:.75",
         "F#5:.5 A5:.25 -:.25 D6:.75 C#6:.25 A5:.5 F#5:.75 -:.75",
         "G5:.5 F#5:.5 E5:.75 C#5:.25 A4:1.25 -:.75",
         "B5:.75 E6:.25 D6:.5 B5:1 -:.25 A5:.5 G5:.75",
         "F#5:1 B5:.5 A5:.5 F#5:.75 E5:.25 D5:1",
         "E5:.75 G5:.25 B5:.75 C6:.25 E6:1 D6:.75 -:.25",
         "A5:1 F#5:.75 E5:.25 D5:1 -:1"),
        chip_lead, electric_piano, saw_bass, GROOVES["funk"]),
    "storage": FloorScore(
        118, (("G2", MIN7), ("G2", MIN7), ("Eb2", MAJ7), ("D2", DOM7),
              ("C2", MIN7), ("Eb2", MAJ7), ("D2", DOM7), ("G2", MIN7)),
        ("G4:.75 Bb4:.5 C5:.5 Db5:.5 D5:.75 -:1",
         "-:.5 D5:.75 F5:.25 G5:.75 F5:.25 D5:.75 G4:.75",
         "Eb5:1.25 Bb4:.75 Db5:.5 D5:.75 -:.75",
         "F#4:.75 A4:.75 C5:.5 D5:.75 A4:1.25",
         "G5:.75 Eb5:.25 C5:.75 G4:.25 Bb4:1 -:1",
         "Eb5:.75 F5:.75 G5:.5 Bb5:1 G5:1",
         "A4:.5 Db5:.5 D5:.5 F#5:.5 C5:.75 A4:1.25",
         "G4:1.5 Bb4:.5 D5:.5 G5:.75 -:.75"),
        electric_piano, toy_bell, pluck, GROOVES["breakbeat"]),
    "boiler": FloorScore(
        138, (("E2", POWER), ("E2", POWER), ("F2", MAJ7), ("D2", MIN7),
              ("E2", POWER), ("G2", POWER), ("F2", MAJ7), ("B2", DOM7)),
        ("E4:.5 E4:.25 -:.25 G4:.5 Bb4:.5 B4:1 -:.5 G4:.5",
         "E4:.75 F4:.25 E4:.5 D4:.5 E4:1 -:1",
         "F4:.75 A4:.25 C5:.75 A4:.25 E5:.75 D5:.25 C5:1",
         "D5:.75 C5:.25 A4:.75 F4:.25 D4:1 -:1",
         "E5:.5 E5:.25 -:.25 G5:.5 Bb5:.5 B5:1 -:.5 G5:.5",
         "D5:.75 G5:.25 B5:.75 A5:.25 G5:1 D5:1",
         "C5:1 F5:.75 E5:.25 C5:.75 A4:.25 F4:1",
         "F#4:.5 A4:.5 B4:.5 D#5:.5 A4:1 B4:.75 -:.25"),
        brass, saw_bass, saw_bass, GROOVES["industrial"]),
    "night_bar": FloorScore(
        122, (("F#2", MIN7), ("A2", MAJ7), ("D2", MAJ7), ("C#2", DOM7),
              ("B2", MIN7), ("E2", DOM7), ("A2", MAJ7), ("C#2", DOM7)),
        ("-:.5 C#5:.5 F#5:.75 A5:.25 G#5:.5 F#5:.5 E5:1",
         "E5:.5 A5:.75 C#6:.25 B5:.5 A5:1 -:.5 E5:.5",
         "F#5:1 A5:.5 C#6:.5 D6:.75 C#6:.25 A5:1",
         "G#5:1 F5:.75 E5:.25 D#5:.5 C#5:1 -:.5",
         "F#5:.75 D5:.25 B4:.5 D5:.5 A5:1 F#5:1",
         "G#5:.75 E5:.25 B4:.5 E5:.5 D6:.75 B5:.25 G#5:1",
         "A5:.5 B5:.5 C#6:.75 E6:.25 F#6:.75 E6:.25 C#6:1",
         "G#5:.75 B5:.25 F5:.75 D#5:.25 C#5:1 -:1"),
        electric_piano, brass, saw_bass, GROOVES["disco"]),
    "nursery": FloorScore(
        156, (("D2", ADD9), ("G2", MAJ7), ("B2", MIN7), ("A2", ADD9),
              ("D2", ADD9), ("E2", MIN7), ("G2", MAJ7), ("A2", DOM7)),
        ("D5:.5 F#5:.5 A5:.75 F#5:.25 E5:.5 D5:.5 A4:1",
         "B4:.5 D5:.5 G5:1 F#5:.75 G5:.25 A5:1",
         "B5:.75 A5:.25 F#5:.5 D5:.5 F#5:1 E5:1",
         "E5:.5 F#5:.5 E5:.5 C#5:.5 A4:1 -:1",
         "D5:.5 F#5:.5 A5:.75 D6:.25 C#6:.5 A5:.5 F#5:1",
         "G5:.75 F#5:.25 E5:.5 B4:.5 D5:1 E5:1",
         "B5:.5 G5:.5 D5:1 E5:.75 F#5:.25 G5:1",
         "A5:.5 B5:.5 C#6:1 E6:.75 D6:.25 C#6:1"),
        toy_bell, electric_piano, saw_bass, GROOVES["jungle"]),
    "conservatory": FloorScore(
        132, (("C2", MAJ7), ("D2", ADD9), ("B2", MIN7), ("E2", MIN7),
              ("C2", MAJ7), ("D2", ADD9), ("G2", MAJ7), ("D2", DOM7)),
        ("E5:.75 G5:.25 B5:.75 F#5:.25 G5:.5 E5:.5 D5:1",
         "F#5:.75 A5:.25 D6:.75 E6:.25 F#6:1 A5:1",
         "B5:1 F#5:.5 A5:.5 B5:.75 D6:.25 E6:1",
         "G6:.75 E6:.25 B5:.5 G5:.5 E5:1 -:1",
         "G5:.5 B5:.5 C6:.75 D6:.25 E6:1 F#6:1",
         "F#6:.5 A6:.5 F#6:.75 E6:.25 D6:1 A5:1",
         "B5:.5 D6:.5 G6:.75 F#6:.25 E6:.75 D6:.25 B5:1",
         "A5:.75 F#5:.25 E5:.5 F#5:.5 D5:1 -:1"),
        chip_lead, toy_bell, pluck, GROOVES["pop"]),
}


def note_pitch(note):
    flats = {"Bb": "A#", "Db": "C#", "Eb": "D#", "Gb": "F#", "Ab": "G#"}
    return freq(flats.get(note[:-1], note[:-1]), int(note[-1]))


def add_melody(track, start, phrase, instrument, gain, echo=False, octave_shift=0):
    offset = 0.0
    for token in phrase.split():
        note, beats = token.split(":")
        length = float(beats) * track.beat
        if note != "-":
            pitch = transposed(note_pitch(note), octave_shift)
            track.add_voice(start + offset, length * 0.89, pitch, gain, instrument,
                            release=min(0.11, length * 0.35))
            if echo:
                track.add_voice(start + offset + track.beat * 0.38, length * 0.7, pitch,
                                gain * 0.14, instrument, release=min(0.09, length * 0.35))
        offset += length
    if not math.isclose(offset, track.bar, abs_tol=0.001):
        raise ValueError(f"melody measure has {offset / track.beat:.2f} beats: {phrase}")


def make_floor(name, score, battle=False):
    bars = (0, 1, 2, 3, 4, 5, 6, 7, 0, 1, 2, 3) if battle else tuple(range(8)) * 2
    tr = Track(score.bpm + (16 if battle else 0), len(bars))
    beat = tr.beat
    groove = score.groove
    instrument = chip_lead if battle and score.lead == toy_bell else score.lead
    random.seed(f"{name}-drums")
    for measure, bar in enumerate(bars):
        start = measure * tr.bar
        note, intervals = score.harmony[bar]
        root = note_pitch(note)
        half_time = (not battle and measure in (8, 9, 10, 11))
        for i, (onset, interval, length) in enumerate(groove.bass):
            if half_time and i % 2:
                continue
            pitch = transposed(root, interval)
            tr.add_voice(start + beat * onset, beat * length, pitch, 0.30,
                         score.bass, release=0.09)
        kicks = (0, 2.5) if half_time else groove.kick
        snares = (2,) if half_time else groove.snare
        for onset in kicks:
            tr.add_voice(start + beat * onset, 0.21, 0, 0.42 if battle else 0.32,
                         drum, release=0.05, attack=0.002)
        for onset in snares:
            tr.add_voice(start + beat * onset, 0.115, 176, 0.19 if battle else 0.14,
                         snare, release=0.045, attack=0.002)
            tr.add_noise_tick(start + beat * onset, 0.14, 0.25 if battle else 0.17)
        if not half_time:
            for onset in groove.hats:
                tr.add_noise_tick(start + beat * onset, 0.038, 0.070)
        for onset in groove.percussion:
            industrial = groove == GROOVES["industrial"] or groove == GROOVES["breakbeat"]
            tr.add_voice(start + beat * onset, 0.094, 0, 0.11, metal if industrial else clack,
                         release=0.03, attack=0.002)
        for onset in groove.chords:
            for interval in intervals[1:]:
                pitch = transposed(root, interval + 12)
                tr.add_voice(start + beat * onset, beat * (0.86 if half_time else 0.22),
                             pitch, 0.064, score.keys, release=0.07)
        if half_time or battle and measure >= 4:
            for interval in intervals:
                pitch = transposed(root, interval + 12)
                tr.add_voice(start, tr.bar * 0.91, pitch, 0.046 if half_time else 0.025,
                             reeds, release=0.25, attack=0.18)
        add_melody(tr, start, score.melody[bar], instrument, 0.23 if battle else 0.19,
                   echo=True, octave_shift=-12 if half_time else 0)
        if battle and measure >= 8:
            add_melody(tr, start, score.melody[bar], brass, 0.082, octave_shift=-12)
        if measure % 4 == 3:
            for onset in (3.25, 3.5, 3.75):
                tr.add_voice(start + beat * onset, 0.093, 227, (onset - 3) * 0.25,
                             snare, release=0.03, attack=0.002)
                tr.add_noise_tick(start + beat * onset, 0.09, (onset - 3) * 0.18)
    tr.write(name, smooth_loop=True, rms_target=0.31 if battle else 0.28)


def make_parlor():
    tr = Track(112, 16, beats_per_bar=3)
    chords = [("D", 3), ("G", 3), ("C", 4), ("F", 4),
              ("A#", 4), ("G", 3), ("A", 4), ("D", 3)]
    # The upper voice leaves room between phrases for the room's clock ticks.
    melody = [
        ((0, "A", 4, 1.3), (1.5, "F", 4, 0.4), (2, "E", 4, 0.8)),
        ((0, "D", 4, 1.8), (2, "G", 4, 0.7)),
        ((0, "E", 4, 0.8), (1, "G", 4, 0.8), (2, "A#", 4, 0.8)),
        ((0, "A", 4, 2.3),),
        ((0, "D", 5, 0.8), (1, "C", 5, 0.8), (2, "A#", 4, 0.8)),
        ((0, "G", 4, 1.2), (1.5, "D", 5, 1.0)),
        ((0, "C#", 5, 0.8), (1, "A", 4, 0.8), (2, "E", 4, 0.8)),
        ((0, "D", 4, 1.8), (2, "F", 4, 0.7)),
    ]
    for measure in range(16):
        bar = measure % 8
        root, third = chords[bar]
        phrase = melody[bar]
        start = measure * tr.bar
        tr.add_voice(start, tr.beat * 0.95, freq(root, 2), 0.29, pluck)
        if measure >= 8:
            tr.add_voice(start + tr.beat * 1.65, tr.beat * 0.72, freq(root, 3), 0.10, pluck)
        for beat in (1, 2):
            for interval in (0, third, 7):
                tr.add_voice(start + beat * tr.beat, tr.beat * 0.72,
                             transposed(freq(root, 3), interval), 0.065,
                             electric_piano if measure >= 8 else pluck)
            tr.add_voice(start + (beat + 0.5) * tr.beat, 0.04, 870 if beat == 1 else 680,
                         0.055, pluck, release=0.025)
        for beat, note, octave, length in phrase:
            tr.add_voice(start + beat * tr.beat, length * tr.beat, freq(note, octave),
                         0.15, reeds, release=0.16)
            if measure >= 8:
                tr.add_voice(start + beat * tr.beat, length * tr.beat, freq(note, octave + 1),
                             0.045, toy_bell, release=0.14)
    tr.write("parlor", smooth_loop=True, rms_target=0.28)


def make_encounter(name, bpm, chords, royal=False):
    tr = Track(bpm, len(chords))
    random.seed(11 if royal else 10)
    bass_beats = (0, 1.5, 2, 3.5) if royal else (0, 0.75, 1.5, 2, 2.75, 3.5)
    lead_beats = (0, 1.5, 2.5, 3) if royal else (0.5, 1.5, 2.5, 3.25)
    lead_intervals = (12, 7, 3, 0) if royal else (0, 7, 12, 7)
    for bar, (root, third) in enumerate(chords):
        start = bar * tr.bar
        for beat in bass_beats:
            pitch = transposed(freq(root, 2), 7 if beat == 3.5 else 0)
            tr.add_voice(start + beat * tr.beat, tr.beat * 0.42, pitch, 0.28, pluck)
        for beat in (0, 2.5):
            tr.add_voice(start + beat * tr.beat, 0.19, 0, 0.31, drum)
        for beat in (1, 3):
            tr.add_noise_tick(start + beat * tr.beat, 0.075, 0.12)
        for beat, interval in zip(lead_beats, lead_intervals):
            pitch = transposed(freq(root, 3 if royal else 4), third if interval == 3 else interval)
            tr.add_voice(start + beat * tr.beat, tr.beat * 0.73, pitch,
                         0.16, reeds if royal else pluck)
        if royal:
            for interval in (0, third, 7):
                pitch = transposed(freq(root, 3), interval)
                tr.add_voice(start, tr.beat * 3.9, pitch, 0.06, soft_pad, release=0.3)
    tr.write(name, smooth_loop=True)


def main():
    existing = {
        "title": (96, [("C", "maj"), ("A", "min"), ("F", "maj"), ("G", "maj")] * 2, dict(seed=1)),
        "workshop": (104, [("F", "maj"), ("D", "min"), ("A#", "maj"), ("C", "maj")] * 2, dict(seed=2)),
        "throne": (92, [("A", "min"), ("F", "maj"), ("D", "min"), ("E", "maj")] * 2, dict(seed=6)),
        "victory": (108, [("C", "maj"), ("G", "maj"), ("A", "min"), ("F", "maj"),
                          ("C", "maj"), ("G", "maj"), ("F", "maj"), ("C", "maj")], dict(seed=9)),
    }
    boss_chords = [("A", 3), ("A", 3), ("F", 4), ("G", 4),
                   ("A", 3), ("C", 4), ("F", 4), ("E", 4)]
    king_chords = [("D", 3), ("A#", 4), ("G", 3), ("A", 4),
                   ("D", 3), ("F", 4), ("G", 3), ("A", 4)]
    encounters = {
        "boiler_boss": "boiler", "bar_boss": "night_bar",
        "nursery_boss": "nursery", "conservatory_boss": "conservatory",
    }
    names = [*existing, *FLOOR_SCORES, "parlor", "boss", "king", *encounters]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tracks", nargs="*", metavar="TRACK", help=", ".join(names))
    args = parser.parse_args()
    for name in args.tracks or names:
        if name in existing:
            bpm, chords, options = existing[name]
            make_loop(name, bpm, chords, **options)
        elif name in FLOOR_SCORES:
            make_floor(name, FLOOR_SCORES[name])
        elif name in encounters:
            make_floor(name, FLOOR_SCORES[encounters[name]], battle=True)
        elif name == "parlor":
            make_parlor()
        elif name == "boss":
            make_encounter(name, 142, boss_chords)
        elif name == "king":
            make_encounter(name, 126, king_chords, royal=True)
        else:
            parser.error(f"unknown track: {name}")


if __name__ == "__main__":
    main()
