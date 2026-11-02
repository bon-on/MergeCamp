#!/usr/bin/env python3
"""Generate the synthesized sounds added for the retention update.

Python 3 standard library only. A fixed random seed makes every run produce
byte-identical files. place.wav, merge.wav and warning.wav were generated for
the project earlier and are NOT rewritten here; only the sounds listed in
SOUNDS are produced.

  chain.wav       44100 Hz  bright rising pluck trio (chain merges)
  discover.wav    44100 Hz  sparkly bell arpeggio (new camp discovered)
  mission.wav     44100 Hz  short warm chime (mission complete)
  level_up.wav    44100 Hz  cheerful rising fanfare (camp level up)
  music_loop.wav  16000 Hz  calm campfire loop, seamless

Everything is mono 16-bit PCM. The music runs at 16 kHz so a 28.8 s loop stays
under 1 MB (the content is low-passed well below 8 kHz anyway). The music loop is rendered on a circular
timeline (note tails wrap around the end, and every filter/delay is run over
two tiled periods with the second period kept), so the last sample flows into
the first one without a click and the delay/reverb tails carry over the seam.

Usage: python3 tool/generate_sounds.py
"""

import math
import os
import random
import struct
import wave

SFX_RATE = 44100
MUSIC_RATE = 16000
SFX_PEAK = 0.708  # about -3 dBFS
MUSIC_PEAK = 0.251  # about -12 dBFS
TAU = 2.0 * math.pi


# --------------------------------------------------------------------------
# Small DSP helpers (all work on plain lists of floats)
# --------------------------------------------------------------------------

def midi_hz(note):
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def lowpass(x, cutoff, rate):
    """One-pole low-pass."""
    a = 1.0 - math.exp(-TAU * cutoff / rate)
    y = 0.0
    out = []
    for s in x:
        y += a * (s - y)
        out.append(y)
    return out


def highpass(x, cutoff, rate):
    lp = lowpass(x, cutoff, rate)
    return [s - l for s, l in zip(x, lp)]


def fade_edges(x, rate, attack=0.002, release=0.03):
    """Linear ramps so a one-shot starts and ends exactly at zero."""
    n = len(x)
    a = max(1, int(attack * rate))
    r = max(1, int(release * rate))
    for i in range(min(a, n)):
        x[i] *= i / a
    for i in range(min(r, n)):
        x[n - 1 - i] *= i / r
    return x


def mix_into(buf, sig, start, wrap=False):
    """Add sig into buf at sample offset start; wrap=True makes it circular."""
    n = len(buf)
    if wrap:
        for i, s in enumerate(sig):
            buf[(start + i) % n] += s
    else:
        for i, s in enumerate(sig):
            j = start + i
            if j >= n:
                break
            buf[j] += s


def feedback_delay(x, delay, feedback, damp_hz, rate):
    """Echo: y[n] = x[n] + feedback * lowpass(y[n - delay]). Returns y - x."""
    a = 1.0 - math.exp(-TAU * damp_hz / rate)
    y = [0.0] * len(x)
    wet = [0.0] * len(x)
    lp = 0.0
    for i in range(len(x)):
        if i >= delay:
            lp += a * (wet[i - delay] - lp)
        wet[i] = x[i] + feedback * lp if i >= delay else x[i]
        y[i] = wet[i] - x[i]
    return y


def schroeder_reverb(x, rate):
    """Small mono room: four damped combs in parallel, two all-passes."""
    out = [0.0] * len(x)
    for delay_ms, fb in ((29.7, 0.77), (37.1, 0.75), (41.1, 0.73), (43.7, 0.71)):
        d = int(delay_ms * rate / 1000.0)
        buf = [0.0] * len(x)
        lp = 0.0
        for i in range(len(x)):
            fed = buf[i - d] if i >= d else 0.0
            lp += 0.45 * (fed - lp)
            buf[i] = x[i] + fb * lp
            out[i] += buf[i] * 0.25
    for delay_ms, g in ((5.0, 0.7), (1.7, 0.7)):
        d = int(delay_ms * rate / 1000.0)
        buf = [0.0] * len(out)
        res = [0.0] * len(out)
        for i in range(len(out)):
            delayed = buf[i - d] if i >= d else 0.0
            buf[i] = out[i] + g * delayed
            res[i] = delayed - g * buf[i]
        out = res
    return out


def circular(effect, x, *args):
    """Run a stateful effect over two tiled periods and keep the second one.

    The first period warms up filters and delay lines with the signal that
    precedes the loop point, so the seam carries no startup transient.
    """
    n = len(x)
    return effect(x + x, *args)[n:]


# --------------------------------------------------------------------------
# Voices
# --------------------------------------------------------------------------

def pluck(freq, dur, rate, decay=3.0, harmonics=6, brightness=1.0):
    """Soft plucked string: additive partials, higher ones die faster."""
    n = int(dur * rate)
    out = [0.0] * n
    for k in range(1, harmonics + 1):
        f = freq * k
        if f > rate * 0.45:
            break
        amp = (k ** -1.35) * (brightness if k > 1 else 1.0)
        dec = decay + 1.6 * (k - 1)
        w = TAU * f / rate
        for i in range(n):
            out[i] += amp * math.sin(w * i) * math.exp(-dec * i / rate)
    # 6 ms attack removes the click of an instantly started partial stack.
    a = int(0.006 * rate)
    for i in range(min(a, n)):
        out[i] *= i / a
    return out


def bell(freq, dur, rate, decay=5.0, shimmer=1.0):
    """Glassy bell: harmonic body plus two quickly fading inharmonic partials."""
    n = int(dur * rate)
    out = [0.0] * n
    parts = ((1.0, 1.0, decay), (2.0, 0.45, decay * 1.6),
             (2.76, 0.22 * shimmer, decay * 2.4), (5.4, 0.10 * shimmer, decay * 4.0))
    for ratio, amp, dec in parts:
        f = freq * ratio
        if f > rate * 0.45:
            continue
        w = TAU * f / rate
        for i in range(n):
            out[i] += amp * math.sin(w * i) * math.exp(-dec * i / rate)
    a = int(0.003 * rate)
    for i in range(min(a, n)):
        out[i] *= i / a
    return out


def soft_tone(freq, dur, rate, decay=2.5, release=0.15):
    """Warm sustained tone (triangle-ish stack) with a plucked front."""
    n = int(dur * rate)
    out = [0.0] * n
    for k, amp in ((1, 1.0), (2, 0.38), (3, 0.14), (4, 0.06)):
        w = TAU * freq * k / rate
        for i in range(n):
            out[i] += amp * math.sin(w * i)
    r = int(release * rate)
    a = int(0.008 * rate)
    for i in range(n):
        g = 0.35 + 0.65 * math.exp(-decay * i / rate)
        if i < a:
            g *= i / a
        if i > n - r:
            g *= (n - i) / r
        out[i] *= g
    return out


# --------------------------------------------------------------------------
# Effects
# --------------------------------------------------------------------------

def chain():
    """Bright rising three-note pluck, 0.38 s (< 40 KB)."""
    rate = SFX_RATE
    n = int(0.38 * rate)
    buf = [0.0] * n
    for step, note in enumerate((79, 84, 88)):  # G5 C6 E6
        voice = pluck(midi_hz(note), 0.30, rate, decay=7.0, harmonics=5,
                      brightness=1.3)
        mix_into(buf, voice, int(step * 0.07 * rate))
    echo = feedback_delay(buf, int(0.09 * rate), 0.3, 5000, rate)
    buf = [a + 0.5 * b for a, b in zip(buf, echo)]
    return fade_edges(buf, rate, 0.002, 0.06)


def discover():
    """Sparkly rising bell arpeggio, 0.6 s."""
    rate = SFX_RATE
    n = int(0.6 * rate)
    buf = [0.0] * n
    for step, note in enumerate((84, 88, 91, 96, 100)):  # C6 E6 G6 C7 E7
        voice = bell(midi_hz(note), 0.42, rate, decay=7.0)
        mix_into(buf, voice, int(step * 0.065 * rate))
    echo = feedback_delay(buf, int(0.13 * rate), 0.35, 5500, rate)
    buf = [a + 0.45 * b for a, b in zip(buf, echo)]
    return fade_edges(buf, rate, 0.002, 0.12)


def mission():
    """Short warm two-note chime, 0.4 s."""
    rate = SFX_RATE
    n = int(0.4 * rate)
    buf = [0.0] * n
    mix_into(buf, bell(midi_hz(79), 0.3, rate, decay=8.0, shimmer=0.4), 0)
    mix_into(buf, bell(midi_hz(84), 0.3, rate, decay=7.0, shimmer=0.4),
             int(0.1 * rate))
    buf = lowpass(buf, 6000, rate)
    return fade_edges(buf, rate, 0.002, 0.08)


def level_up():
    """Cheerful rising fanfare ending on a held major chord, 0.9 s."""
    rate = SFX_RATE
    n = int(0.9 * rate)
    buf = [0.0] * n
    for step, note in enumerate((72, 76, 79)):  # C5 E5 G5, quick run
        mix_into(buf, soft_tone(midi_hz(note), 0.22, rate, decay=6.0,
                                release=0.05), int(step * 0.09 * rate))
    start = int(0.27 * rate)
    for note, amp in ((72, 0.7), (76, 0.7), (79, 0.7), (84, 0.9)):
        tone = soft_tone(midi_hz(note), (n - start) / rate, rate, decay=2.2,
                         release=0.3)
        mix_into(buf, [amp * s for s in tone], start)
    sparkle = bell(midi_hz(96), 0.5, rate, decay=6.0)
    mix_into(buf, [0.25 * s for s in sparkle], start)
    echo = feedback_delay(buf, int(0.11 * rate), 0.3, 4500, rate)
    buf = [a + 0.35 * b for a, b in zip(buf, echo)]
    buf = lowpass(buf, 7000, rate)
    return fade_edges(buf, rate, 0.003, 0.15)


# --------------------------------------------------------------------------
# Music: calm campfire loop
# --------------------------------------------------------------------------

BPM = 100
BEATS_PER_BAR = 4
BARS = 12
EIGHTH = 60.0 / BPM / 2.0  # seconds

# Pad voicings, bass notes (MIDI). Progression, one chord per bar:
#   C Am F G | C Am F G | F C/E Dm G   -> ends on the dominant, so the loop
#   returns to C like a turnaround.
CHORDS = {
    "C": ((48, 55, 60, 64), 36 + 12),
    "Am": ((52, 57, 60, 64), 45),
    "F": ((53, 57, 60, 65), 41),
    "G": ((55, 59, 62, 67), 43),
    "C/E": ((52, 55, 60, 64), 40),
    "Dm": ((50, 53, 57, 62), 38),
}
PROGRESSION = ["C", "Am", "F", "G", "C", "Am", "F", "G", "F", "C/E", "Dm", "G"]

# Melody, C major pentatonic (C D E G A). Each bar: (eighth offset, MIDI, length
# in eighths). The first two phrases state the theme, the third climbs and the
# last bar resolves toward the next loop's opening E.
MELODY = [
    # C: theme
    [(0, 76, 2), (2, 79, 1), (3, 76, 1), (4, 74, 2), (6, 72, 2)],
    # Am
    [(0, 72, 2), (2, 76, 2), (4, 81, 3), (7, 79, 1)],
    # F
    [(0, 76, 2), (2, 79, 1), (3, 76, 1), (4, 79, 2), (6, 81, 2)],
    # G
    [(0, 74, 2), (2, 76, 2), (4, 74, 2), (6, 67, 2)],
    # C: theme again, higher ending
    [(0, 76, 2), (2, 79, 1), (3, 81, 1), (4, 84, 3), (7, 81, 1)],
    # Am
    [(0, 79, 2), (2, 76, 2), (4, 72, 2), (6, 76, 2)],
    # F
    [(0, 81, 2), (2, 79, 2), (4, 76, 1), (5, 79, 1), (6, 74, 2)],
    # G
    [(0, 74, 3), (3, 76, 1), (4, 79, 4)],
    # F: new phrase
    [(0, 81, 2), (2, 84, 2), (4, 81, 1), (5, 79, 1), (6, 76, 2)],
    # C/E
    [(0, 79, 2), (2, 76, 1), (3, 79, 1), (4, 84, 3), (7, 79, 1)],
    # Dm
    [(0, 81, 2), (2, 79, 1), (3, 74, 1), (4, 77, 2), (6, 74, 2)],
    # G: turnaround
    [(0, 74, 2), (2, 79, 2), (4, 74, 2), (6, 76, 1), (7, 76, 1)],
]


def music_loop():
    rate = MUSIC_RATE
    bar = EIGHTH * 8
    n = int(round(bar * BARS * rate))
    rng = random.Random(2024)

    pad = [0.0] * n
    bass = [0.0] * n
    plucks = [0.0] * n
    shaker = [0.0] * n

    # --- pad: soft detuned sine stacks with slow raised-cosine envelopes
    pad_cache = {}
    for b, name in enumerate(PROGRESSION):
        if name not in pad_cache:
            notes, _ = CHORDS[name]
            dur = bar + 1.0  # tail overlaps the next chord (and wraps)
            m = int(dur * rate)
            voice = [0.0] * m
            for note in notes:
                f = midi_hz(note)
                for detune, amp in ((0.9965, 0.5), (1.0, 0.7), (1.0035, 0.5)):
                    for k, ha in ((1, 1.0), (2, 0.30), (3, 0.10)):
                        w = TAU * f * detune * k / rate
                        for i in range(m):
                            voice[i] += amp * ha * math.sin(w * i)
            att = int(0.55 * rate)
            rel = int(1.0 * rate)
            for i in range(m):
                g = 1.0
                if i < att:
                    g = math.sin(0.5 * math.pi * i / att) ** 2
                if i > m - rel:
                    g = min(g, math.sin(0.5 * math.pi * (m - i) / rel) ** 2)
                voice[i] *= g
            pad_cache[name] = voice
        mix_into(pad, [0.09 * s for s in pad_cache[name]],
                 int(b * bar * rate), wrap=True)
    pad = circular(lowpass, pad, 1300, rate)

    # --- bass: rounded plucks on beats 1 and 3 (and a soft pickup on 4&)
    bass_cache = {}
    for b, name in enumerate(PROGRESSION):
        root = CHORDS[name][1]
        if root not in bass_cache:
            voice = pluck(midi_hz(root), 1.6, rate, decay=2.4, harmonics=3)
            bass_cache[root] = voice
        v = bass_cache[root]
        base = int(b * bar * rate)
        mix_into(bass, [0.55 * s for s in v], base, wrap=True)
        mix_into(bass, [0.40 * s for s in v[: int(1.1 * rate)]],
                 base + int(4 * EIGHTH * rate), wrap=True)
        if b % 2 == 1:
            fifth = pluck(midi_hz(root + 7), 0.6, rate, decay=4.0, harmonics=3)
            mix_into(bass, [0.22 * s for s in fifth],
                     base + int(7 * EIGHTH * rate), wrap=True)
    bass = circular(lowpass, bass, 600, rate)

    # --- melody: plucks, mildly low-passed, with a gentle swell on long notes
    pluck_cache = {}
    for b, notes in enumerate(MELODY):
        for off, midi, length in notes:
            if length <= 0:
                continue
            key = (midi, length)
            if key not in pluck_cache:
                dur = min(2.6, 0.9 + 0.35 * length)
                pluck_cache[key] = pluck(midi_hz(midi), dur, rate, decay=2.6,
                                         harmonics=6, brightness=0.8)
            gain = 0.34 if off == 0 else 0.28
            mix_into(plucks, [gain * s for s in pluck_cache[key]],
                     int((b * bar + off * EIGHTH) * rate), wrap=True)
    plucks = circular(lowpass, plucks, 2600, rate)

    # --- light shaker: filtered noise ticks on the eighths
    pattern = (0.55, 0.0, 0.30, 0.0, 0.50, 0.0, 0.30, 0.22)
    tick_len = int(0.07 * rate)
    for b in range(BARS):
        for e in range(8):
            vel = pattern[e]
            if vel == 0.0:
                continue
            vel *= 0.85 + 0.3 * rng.random()
            tick = [rng.uniform(-1.0, 1.0) * math.exp(-60.0 * i / rate)
                    for i in range(tick_len)]
            mix_into(shaker, [0.05 * vel * s for s in tick],
                     int((b * bar + e * EIGHTH) * rate), wrap=True)
    shaker = circular(highpass, shaker, 3500, rate)
    shaker = circular(lowpass, shaker, 8000, rate)

    # --- echo on the melody (dotted-eighth feel) and a small room on pad+melody
    delay = int(round(EIGHTH * 3 * rate))
    echo = circular(feedback_delay, plucks, delay, 0.42, 2200, rate)
    melody_bus = [p + 0.45 * e for p, e in zip(plucks, echo)]
    room_in = [a + b for a, b in zip(pad, melody_bus)]
    room = circular(schroeder_reverb, room_in, rate)
    mix = [p + m + b + s + 0.28 * r
           for p, m, b, s, r in zip(pad, melody_bus, bass, shaker, room)]

    # Remove DC / subsonic drift without touching the loop continuity.
    mix = circular(highpass, mix, 35, rate)
    return mix, MUSIC_PEAK


SOUNDS = {
    "chain": (chain, SFX_RATE, SFX_PEAK),
    "discover": (discover, SFX_RATE, SFX_PEAK),
    "mission": (mission, SFX_RATE, SFX_PEAK),
    "level_up": (level_up, SFX_RATE, SFX_PEAK),
    "music_loop": (music_loop, MUSIC_RATE, MUSIC_PEAK),
}


def write_wav(path, samples, rate, peak_target):
    peak = max(abs(s) for s in samples) or 1.0
    scale = peak_target / peak
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(rate)
        out.writeframes(
            b"".join(
                struct.pack("<h", int(round(max(-1.0, min(1.0, s * scale)) * 32767)))
                for s in samples
            )
        )


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    target = os.path.join(root, "assets", "audio")
    os.makedirs(target, exist_ok=True)
    for name, (build, rate, peak) in SOUNDS.items():
        result = build()
        if isinstance(result, tuple):
            result = result[0]
        path = os.path.join(target, name + ".wav")
        write_wav(path, result, rate, peak)
        print("wrote", os.path.relpath(path, root), os.path.getsize(path),
              "bytes", "%.2f s" % (len(result) / rate))


if __name__ == "__main__":
    main()
