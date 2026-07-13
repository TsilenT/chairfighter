#!/usr/bin/env python3
"""Generate all Chairfighter SFX as 16-bit mono WAVs (stdlib only).

Design language (SPEC §12): physical comedy + readable feedback.
Wood clacks for basic, plush thumps, wheel squeaks, metal snaps, royal booms.

Usage: python3 tools/gen_sfx.py   (writes assets/audio/sfx/<name>.wav)
"""
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


def sfx_gate_open():  # sliding stone + sparkle
    d = 0.45
    return render(d, lambda t: env_ad(t, d, 0.03, 2) * (
        0.35 * noise() * (1 - t / d) + 0.35 * sine(slide(300, 700, t, d), t)))


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


def sfx_telegraph():  # warning shimmer
    d = 0.25
    return render(d, lambda t: env_ad(t, d, 0.02, 2) * 0.4 * (
        sine(880, t) * (0.5 + 0.5 * sine(30, t))))


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


def sfx_unlock():  # the fanfare: major arpeggio up
    d = 1.2
    notes = [392, 494, 587, 784, 988]
    def f(t):
        i = min(int(t / 0.16), 4)
        local = t - i * 0.16
        tone = 0.4 * square(notes[i], t, 0.35) + 0.3 * sine(notes[i] * 2, t)
        tail = 0.3 * sine(988, t) * env_ad(max(t - 0.8, 0), 0.4, 0.01, 2) if t > 0.8 else 0
        return tone * env_ad(local, 0.16, 0.004, 1.5) * (1.0 if t < 0.8 else 0.4) + tail
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
}

if __name__ == "__main__":
    for name, fn in RECIPES.items():
        write_wav(name, fn())
    print(f"{len(RECIPES)} sfx generated")
