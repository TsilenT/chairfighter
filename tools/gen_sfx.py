#!/usr/bin/env python3
"""Generate all Chairfighter SFX as 16-bit mono WAVs (stdlib only).

Design language (SPEC §12): physical comedy + readable feedback.
Wood clacks for basic, plush thumps, wheel squeaks, metal snaps, royal booms.

Usage: python3 tools/gen_sfx.py [cue ...]
Writes assets/audio/sfx/<name>.wav, for all cues by default.
"""
import argparse
import math
import os
import random
import struct
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")
random.seed(41)


def clamp(x, lo=-1.0, hi=1.0):
    return max(lo, min(hi, x))


def env_ad(t, dur, attack=0.005, curve=3.0):
    """Attack-decay envelope."""
    if t < attack:
        return t / attack
    k = min((t - attack) / max(dur - attack, 1e-6), 1.0)
    return (1.0 - k) ** curve


def sine(f, t):
    return math.sin(2 * math.pi * f * t)


def square(f, t, duty=0.5):
    return 1.0 if (f * t) % 1.0 < duty else -1.0


def tri(f, t):
    p = (f * t) % 1.0
    return 4 * abs(p - 0.5) - 1.0


def noise():
    return random.uniform(-1, 1)


def render(dur, fn, vol=0.8):
    n = int(dur * SR)
    return [clamp(fn(i / SR) * vol) for i in range(n)]


def write_wav(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(
            struct.pack("<h", int(clamp(s) * 32000)) for s in samples))
    print("wrote", path, f"({len(samples)/SR:.2f}s)")


def slide(f0, f1, t, dur):
    """Exponential pitch slide frequency at time t."""
    k = min(t / dur, 1.0)
    return f0 * (f1 / f0) ** k


def strike(t, dur, f, attack=0.003):
    """A struck wood tone with a brief, inharmonic overtone."""
    return env_ad(t, dur, attack, 3) * (
        0.8 * sine(f, t) + 0.2 * sine(f * 2.76, t) * math.exp(-40 * t))


# ── recipes ──

def sfx_jump():  # springy wood boing
    d = 0.22
    return render(d, lambda t: env_ad(t, d) * (
        0.7 * sine(slide(280, 520, t, d), t) + 0.2 * tri(slide(560, 1040, t, d), t)))


def sfx_spring():  # bigger, twangier boing
    d = 0.4
    return render(d, lambda t: env_ad(t, d, curve=2) * (
        0.6 * sine(slide(180, 720, t, d), t) + 0.3 * tri(slide(360, 1440, t, d), t)))


def sfx_land():  # soft wood thud
    d = 0.12
    return render(d, lambda t: env_ad(t, d, 0.002, 4) * (
        0.8 * sine(slide(150, 70, t, d), t) + 0.3 * noise() * env_ad(t, 0.04, 0.001, 6)))


def sfx_attack():  # quick whoosh + clack
    d = 0.14
    def f(t):
        wh = 0.5 * noise() * env_ad(t, 0.08, 0.005, 2)
        cl = 0.9 * sine(slide(900, 250, t, d), t) * env_ad(max(t - 0.04, 0), 0.08, 0.001, 5) if t > 0.04 else 0
        return wh + cl
    return render(d, f)


def sfx_hit():  # meaty impact
    d = 0.16
    return render(d, lambda t: env_ad(t, d, 0.002, 4) * (
        0.7 * sine(slide(220, 60, t, d), t) + 0.45 * noise() * env_ad(t, 0.05, 0.001, 5)))


def sfx_hurt():  # player ouch: dissonant wobble
    d = 0.3
    return render(d, lambda t: env_ad(t, d, 0.004, 3) * (
        0.5 * square(slide(340, 160, t, d), t) * 0.4 + 0.5 * sine(slide(300, 120, t, d), t)))


def sfx_death():  # sad descending womp
    d = 0.8
    return render(d, lambda t: env_ad(t, d, 0.01, 2) * (
        0.6 * sine(slide(320, 60, t, d), t) + 0.25 * tri(slide(160, 30, t, d), t)))


def sfx_transform():  # quick magical rearrange: up-arp blip
    d = 0.18
    notes = [392, 523, 659]
    def f(t):
        i = min(int(t / d * 3), 2)
        return square(notes[i], t, 0.3) * 0.5 * env_ad(t % (d / 3), d / 3, 0.002, 2)
    return render(d, f)


def sfx_fold():  # metal snap-fold
    d = 0.12
    return render(d, lambda t: env_ad(t, d, 0.001, 6) * (
        0.8 * sine(slide(1200, 300, t, d), t) + 0.3 * noise() * env_ad(t, 0.03, 0.001, 8)))


def sfx_dash():  # wheel spin-up whoosh
    d = 0.3
    return render(d, lambda t: env_ad(t, d, 0.02, 2) * (
        0.45 * noise() * (0.4 + 0.6 * sine(slide(60, 240, t, d), t)) +
        0.3 * sine(slide(300, 900, t, d), t) * 0.3))


def sfx_grapple():  # rope zip
    d = 0.25
    return render(d, lambda t: env_ad(t, d, 0.01, 2) * (
        0.5 * sine(slide(500, 1400, t, d), t) + 0.2 * noise() * 0.5))


def sfx_grapple_miss():  # dull no
    d = 0.12
    return render(d, lambda t: env_ad(t, d) * 0.5 * square(140, t, 0.5) * 0.6)


def sfx_door():  # friendly whoosh-pop
    d = 0.3
    return render(d, lambda t: env_ad(t, d, 0.02, 2) * (
        0.4 * sine(slide(200, 480, t, d), t) + 0.2 * noise() * env_ad(t, 0.1, 0.01, 3)))


def sfx_locked():  # rattle-deny
    d = 0.22
    return render(d, lambda t: env_ad(t, d, 0.002, 3) * 0.6 * square(
        110 + 30 * sine(28, t), t, 0.4))


def sfx_checkpoint():  # cozy chime
    d = 0.5
    def f(t):
        a = sine(523, t) * env_ad(t, d, 0.005, 3)
        b = sine(784, t) * env_ad(max(t - 0.12, 0), d - 0.12, 0.005, 3) if t > 0.12 else 0
        return 0.45 * a + 0.4 * b
    return render(d, f)


def sfx_gate_open():  # furniture latch, followed by a friendly rising third
    d = 0.45
    def f(t):
        latch = 0.32 * noise() * env_ad(t, 0.13, 0.002, 3) + 0.45 * strike(t, 0.13, 185)
        a = 0.38 * strike(t - 0.055, 0.23, 523) if t >= 0.055 else 0
        b = 0.38 * strike(t - 0.15, 0.28, 659) if t >= 0.15 else 0
        return latch + a + b
    return render(d, f)


def sfx_break():  # wall shatter
    d = 0.35
    return render(d, lambda t: env_ad(t, d, 0.002, 4) * (
        0.7 * noise() + 0.3 * sine(slide(200, 70, t, d), t)))


def sfx_lob():  # poomf
    d = 0.15
    return render(d, lambda t: env_ad(t, d, 0.01, 3) * 0.6 * sine(slide(240, 120, t, d), t))


def sfx_enemy_down():  # squash pop
    d = 0.25
    return render(d, lambda t: env_ad(t, d, 0.003, 3) * (
        0.6 * sine(slide(600, 90, t, d), t) + 0.2 * noise() * env_ad(t, 0.05, 0.001, 6)))


def sfx_telegraph():  # two crisp, urgent taps rise above the fight
    d = 0.22
    def f(t):
        a = 0.68 * strike(t, 0.10, 784)
        b = 0.58 * strike(t - 0.075, 0.14, 1109) if t >= 0.075 else 0
        return a + b
    return render(d, f)


def sfx_ability_ready():  # the hinge takes weight
    d = 0.18
    def f(t):
        latch = 0.58 * strike(t, 0.075, 218)
        settle = 0.33 * strike(t - 0.055, 0.12, 321) if t >= 0.055 else 0
        return latch + settle
    return render(d, f)


def sfx_counter():  # a solid block snaps back
    d = 0.25
    def f(t):
        block = 0.70 * strike(t, 0.13, 155)
        snap = 0.59 * strike(t - 0.028, 0.21, 712) if t >= 0.028 else 0
        return block + snap
    return render(d, f)


def sfx_boss_start():  # dread horn
    d = 0.9
    return render(d, lambda t: env_ad(t, d, 0.05, 2) * (
        0.5 * square(slide(98, 110, t, d), t, 0.5) * 0.5 +
        0.4 * sine(slide(196, 220, t, d), t) + 0.15 * noise() * 0.3))


def sfx_boss_hit():  # heavier hit
    d = 0.2
    return render(d, lambda t: env_ad(t, d, 0.002, 4) * (
        0.7 * sine(slide(180, 50, t, d), t) + 0.5 * noise() * env_ad(t, 0.06, 0.001, 5)))


def sfx_boss_rage():  # phase-2 roar
    d = 0.7
    return render(d, lambda t: env_ad(t, d, 0.03, 2) * (
        0.5 * square(slide(80, 160, t, d), t, 0.45) * 0.6 + 0.35 * noise() * 0.5))


def sfx_boss_down():  # triumphant collapse
    d = 1.1
    def f(t):
        boom = 0.6 * sine(slide(160, 40, t, d), t) * env_ad(t, d, 0.005, 2)
        sparkle = 0.25 * sine(slide(600, 1800, t, d), t) * env_ad(max(t - 0.3, 0), 0.6, 0.02, 2) if t > 0.3 else 0
        return boom + sparkle
    return render(d, f)


def sfx_unlock():  # a little struck-wood fanfare
    d = 0.95
    notes = [(0.0, 392), (0.12, 494), (0.24, 587), (0.37, 784)]
    def f(t):
        melody = sum(0.59 * strike(t - start, 0.38, note) for start, note in notes if t >= start)
        harmony = 0.28 * strike(t - 0.37, 0.55, 494) if t >= 0.37 else 0
        return melody + harmony
    return render(d, f)


def sfx_ui_start():  # confident blip pair
    d = 0.3
    def f(t):
        a = square(440, t, 0.4) * env_ad(t, 0.12, 0.003, 3)
        b = square(660, t, 0.4) * env_ad(max(t - 0.12, 0), 0.15, 0.003, 3) if t > 0.12 else 0
        return 0.45 * (a + b)
    return render(d, f)


def sfx_ui_blip():
    d = 0.08
    return render(d, lambda t: env_ad(t, d, 0.002, 3) * 0.4 * square(600, t, 0.4))


RECIPES = {
    "jump": sfx_jump, "spring": sfx_spring, "land": sfx_land,
    "attack": sfx_attack, "hit": sfx_hit, "hurt": sfx_hurt, "death": sfx_death,
    "transform": sfx_transform, "fold": sfx_fold, "dash": sfx_dash,
    "grapple": sfx_grapple, "grapple_miss": sfx_grapple_miss,
    "door": sfx_door, "locked": sfx_locked, "checkpoint": sfx_checkpoint,
    "gate_open": sfx_gate_open, "break": sfx_break, "lob": sfx_lob,
    "enemy_down": sfx_enemy_down, "telegraph": sfx_telegraph,
    "boss_start": sfx_boss_start, "boss_hit": sfx_boss_hit,
    "boss_rage": sfx_boss_rage, "boss_down": sfx_boss_down,
    "unlock": sfx_unlock, "ui_start": sfx_ui_start, "ui_blip": sfx_ui_blip,
    "ability_ready": sfx_ability_ready, "counter": sfx_counter,
}

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cues", nargs="*", metavar="CUE", help=", ".join(RECIPES))
    args = parser.parse_args()
    unknown = set(args.cues) - RECIPES.keys()
    if unknown:
        parser.error("unknown cue: " + ", ".join(sorted(unknown)))
    for name, fn in RECIPES.items():
        # Keep noise samples deterministic when regenerating a subset of cues.
        samples = fn()
        if not args.cues or name in args.cues:
            write_wav(name, samples)
