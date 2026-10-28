"""Generates the game's two original music loops (no samples, no third-party audio).

    python tools/audio/generate_music.py        (from the project root; needs ffmpeg on PATH)

Each track is synthesised here from sine partials: warm pads on a slow
I - vi - IV - V(sus2) progression in D major, a koto-style pluck melody on the
D major pentatonic scale (the same key as the tile-match bells), and a soft
temple bell every second chord. Notes are written into a circular buffer, so a
tail that runs past the end wraps to the start: the loop joins without a seam.
ffmpeg then adds room reverb and stereo width; that pass renders the loop three
times and keeps the middle copy, so the reverb tail also crosses the seam.

Deterministic: the same seed always produces the same music.
"""

import math
import os
import random
import struct
import subprocess
import sys
import tempfile
import wave

SR = 32000
OUT_DIR = os.path.join("assets", "audio", "music")


def hz(note: str) -> float:
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semis = names[note[0]]
    rest = note[1:]
    if rest.startswith("#"):
        semis += 1
        rest = rest[1:]
    octave = int(rest)
    return 440.0 * 2 ** ((semis + 12 * (octave - 4)) / 12)


# Chords: root-position-ish voicings, all diatonic to D major.
CHORDS = {
    "D": ["D2", "A2", "D3", "F#3", "A3", "E4"],
    "Bm": ["B1", "F#2", "B2", "D3", "F#3", "A3"],
    "G": ["G1", "D2", "G2", "B2", "D3", "F#3"],
    "Asus2": ["A1", "E2", "A2", "B2", "E3", "A3"],
}
PROGRESSION = ["D", "Bm", "G", "Asus2"]
# Melody notes allowed (pentatonic), and which ones sit well on each chord.
PENTATONIC = ["D4", "E4", "F#4", "A4", "B4", "D5", "E5", "F#5", "A5"]
CHORD_TONES = {
    "D": {"D4", "F#4", "A4", "D5", "F#5", "A5", "E4", "E5"},
    "Bm": {"B4", "D4", "F#4", "D5", "F#5", "A4", "A5"},
    "G": {"B4", "D4", "D5", "E4", "E5", "A4"},
    "Asus2": {"A4", "B4", "E4", "E5", "A5", "D5"},
}


def pad_wave(chord: str, seconds: float) -> list:
    """A soft pad: each chord note as two slightly detuned sines with a gentle
    second partial; slow swell in and out."""
    n = int(seconds * SR)
    out = [0.0] * n
    attack = 2.2 * SR
    release = 3.0 * SR
    hold_end = n - release
    for k, note in enumerate(CHORDS[chord]):
        f = hz(note)
        gain = 0.16 / (1 + 0.25 * k)
        w1 = 2 * math.pi * f * 1.0015 / SR
        w2 = 2 * math.pi * f * 0.9985 / SR
        w3 = 2 * math.pi * f * 2.0 / SR
        for i in range(n):
            out[i] += gain * (math.sin(w1 * i) + math.sin(w2 * i) + 0.18 * math.sin(w3 * i))
    for i in range(n):
        if i < attack:
            env = math.sin(0.5 * math.pi * i / attack) ** 2
        elif i > hold_end:
            env = math.cos(0.5 * math.pi * (i - hold_end) / release) ** 2
        else:
            env = 1.0
        out[i] *= env
    return out


def pluck_wave(note: str, seconds: float = 2.6) -> list:
    """Koto-style pluck: four harmonics, upper ones dying faster, soft attack."""
    f = hz(note)
    n = int(seconds * SR)
    parts = [(1, 0.55, 2.6), (2, 0.28, 5.0), (3, 0.13, 8.5), (4, 0.06, 13.0)]
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        attack = 1 - math.exp(-t * 300)
        s = 0.0
        for mult, amp, decay in parts:
            s += amp * math.sin(2 * math.pi * f * mult * t) * math.exp(-t * decay)
        out[i] = attack * s
    fade = int(0.3 * SR)
    for i in range(n - fade, n):
        out[i] *= (n - i) / fade
    return out


def bell_wave(note: str, seconds: float = 4.0) -> list:
    """Temple bell like the tile-match bells: beating pair plus inharmonic partials."""
    f = hz(note)
    n = int(seconds * SR)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        d = 1.4
        s = (0.5 * math.sin(2 * math.pi * f * t) + 0.22 * math.sin(2 * math.pi * (f + 1.3) * t)) * math.exp(-t * d)
        s += 0.10 * math.sin(2 * math.pi * 2.76 * f * t) * math.exp(-t * d * 2.2)
        s += 0.05 * math.sin(2 * math.pi * 5.4 * f * t) * math.exp(-t * d * 4)
        out[i] = (1 - math.exp(-t * 250)) * s
    return out


def stamp(buffer: list, wave_data: list, start: float, gain: float) -> None:
    """Adds a sound into the circular buffer; anything past the end wraps."""
    n = len(buffer)
    at = int(start * SR) % n
    for i, v in enumerate(wave_data):
        buffer[(at + i) % n] += gain * v


def melody(rng: random.Random, chord: str, beats: int, density: float, start_index: int):
    """Sparse pentatonic line: a gentle random walk that favours chord tones."""
    notes = []
    index = start_index
    for beat in range(beats):
        if rng.random() > density:
            continue
        for _ in range(8):
            step = rng.choice([-2, -1, -1, 0, 1, 1, 2])
            candidate = min(max(index + step, 0), len(PENTATONIC) - 1)
            strong = beat % 2 == 0
            if not strong or PENTATONIC[candidate] in CHORD_TONES[chord]:
                index = candidate
                break
        # Occasionally a pair of quick notes (on the off-beat) for movement.
        offset = 0.5 if rng.random() < 0.15 else 0.0
        notes.append((beat + offset, PENTATONIC[index], 0.7 + 0.3 * rng.random()))
    return notes, index


def render(name: str, bpm: float, cycles: int, density: float, melody_gain: float, seed: int) -> None:
    rng = random.Random(seed)
    beat = 60.0 / bpm
    beats_per_chord = 8
    chord_seconds = beat * beats_per_chord
    total = chord_seconds * len(PROGRESSION) * cycles
    buffer = [0.0] * int(total * SR)

    pads = {c: pad_wave(c, chord_seconds + 3.0) for c in PROGRESSION}
    plucks = {}
    bells = {}
    index = 3
    t = 0.0
    for cycle in range(cycles):
        for k, chord in enumerate(PROGRESSION):
            stamp(buffer, pads[chord], t - 1.0, 1.0)
            if k % 2 == 0:
                bell_note = {"D": "D5", "Bm": "F#5", "G": "B4", "Asus2": "A4"}[chord]
                bells.setdefault(bell_note, bell_wave(bell_note))
                stamp(buffer, bells[bell_note], t + beat * 0.02, 0.22)
            # The first chord of the first cycle starts quietly: let the pad breathe.
            if cycle == 0 and k == 0:
                t += chord_seconds
                continue
            notes, index = melody(rng, chord, beats_per_chord, density, index)
            for at_beat, note, velocity in notes:
                plucks.setdefault(note, pluck_wave(note))
                stamp(buffer, plucks[note], t + at_beat * beat, melody_gain * velocity)
            t += chord_seconds

    peak = max(abs(v) for v in buffer) or 1.0
    with tempfile.TemporaryDirectory() as tmp:
        dry = os.path.join(tmp, "dry.wav")
        with wave.open(dry, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(b"".join(struct.pack("<h", int(32000 * 0.8 * v / peak)) for v in buffer))
        out = os.path.join(OUT_DIR, f"{name}.ogg")
        # Reverb and a Haas-style stereo spread, over three back-to-back loops;
        # keep the middle loop so the reverb tail crosses the seam seamlessly.
        graph = (
            f"aloop=loop=2:size={len(buffer)},"
            "aecho=0.85:0.75:67|109|163|241:0.32|0.24|0.18|0.12,"
            "lowpass=f=7000,"
            "asplit[l][r];[r]adelay=11[rd];[l][rd]amerge=inputs=2,"
            f"atrim=start={total:.6f}:end={2 * total:.6f},asetpts=PTS-STARTPTS,"
            "aresample=44100,volume=-3dB"
        )
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", dry, "-filter_complex", graph,
                        "-ac", "2", "-c:a", "libvorbis", "-q:a", "4", out], check=True)
    print(f"{out}: {total:.1f} s loop")


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    which = sys.argv[1:] or ["menu", "gameplay"]
    if "menu" in which:
        # Menu: a little more melodic movement.
        render("music_main_menu", bpm=66, cycles=2, density=0.55, melody_gain=0.5, seed=2026)
    if "gameplay" in which:
        # Gameplay: slower and sparser, so tile sounds stay in front.
        render("music_gameplay", bpm=58, cycles=3, density=0.3, melody_gain=0.36, seed=8128)
