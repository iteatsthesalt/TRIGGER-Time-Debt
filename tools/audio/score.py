"""MIDI score building (mido) and FluidSynth rendering for TRIGGER: Time Debt.

A Score is a list of timed events on General MIDI channels. Each stem of a track is rendered by
writing a MIDI file that holds only that stem's channels and rendering it with FluidSynth at
48 kHz, float, with the SoundFont's own reverb and chorus off (the synth helpers add room).
All stems of one score come back with identical length.
"""
from __future__ import annotations

import math
import os
import shutil
import subprocess
import tempfile

import mido
import numpy as np

import synth as S

SF2_CANDIDATES = [
    "/usr/share/sounds/sf2/FluidR3_GM.sf2",
    "/usr/share/sounds/sf2/default-GM.sf2",
    "/usr/share/sounds/sf2/TimGM6mb.sf2",
]

# General MIDI programs (0-based) used by the palettes in §8.4
GM = {
    "piano": 0, "bright_piano": 1, "celesta": 8, "glockenspiel": 9, "music_box": 10, "vibraphone": 11,
    "marimba": 12, "tubular_bells": 14, "accordion": 21, "dist_guitar": 30, "acoustic_bass": 32,
    "violin": 40, "viola": 41, "cello": 42, "contrabass": 43, "pizzicato": 45, "harp": 46, "timpani": 47,
    "strings": 48, "slow_strings": 49, "choir_aahs": 52, "voice_oohs": 53, "synth_voice": 54,
    "bassoon": 70, "clarinet": 71, "flute": 73, "pan_flute": 75, "shakuhachi": 77, "whistle": 78,
    "fantasia": 88, "warm_pad": 89, "crystal": 98, "shamisen": 106, "koto": 107, "kalimba": 108,
    "fiddle": 110, "tinkle_bell": 112, "woodblock": 115, "taiko": 116, "melodic_tom": 117,
    "reverse_cymbal": 119, "breath_noise": 121, "seashore": 122, "bird": 123,
}
DRUM_CH = 9
DRUM_KIT = {"standard": 0, "room": 8, "power": 16, "electronic": 24, "tr808": 25, "jazz": 32, "brush": 40, "orchestra": 48}
# GM drum notes
DR = {"kick": 36, "kick2": 35, "snare": 38, "snare2": 40, "rim": 37, "clap": 39, "hh_closed": 42, "hh_pedal": 44,
      "hh_open": 46, "tom_lo": 41, "tom_lo2": 43, "tom_mid": 45, "tom_mid2": 47, "tom_hi": 48, "tom_hi2": 50,
      "crash": 49, "ride": 51, "china": 52, "ride_bell": 53, "tamb": 54, "splash": 55, "cowbell": 56, "crash2": 57,
      "shaker": 70, "triangle_open": 81, "triangle_mute": 80, "woodblock_hi": 76, "woodblock_lo": 77,
      "bongo_hi": 60, "bongo_lo": 61, "conga_hi": 63, "conga_lo": 64, "timbale_hi": 65, "timbale_lo": 66,
      "sticks": 31, "sq_click": 32, "mute_cuica": 78, "open_cuica": 79}


def find_sf2() -> str:
    env = os.environ.get("TTD_SF2")
    if env and os.path.exists(env):
        return env
    for p in SF2_CANDIDATES:
        if os.path.exists(p):
            return p
    raise RuntimeError("No General MIDI SoundFont found (set TTD_SF2)")


class Score:
    """Beat-based event list. Beats are floats from 0; bars are counted from 0."""

    def __init__(self, bpm: float, beats_per_bar: int = 4, ppq: int = 960):
        self.bpm = float(bpm)
        self.beats_per_bar = beats_per_bar
        self.ppq = ppq
        self.events: list[tuple[float, int, str, dict]] = []  # (beat, order, kind, data)
        self.programs: dict[int, tuple[int, int]] = {}
        self._order = 0
        self.end_beat = 0.0

    # --- timing ---
    def beat_s(self) -> float:
        return 60.0 / self.bpm

    def bar_s(self) -> float:
        return self.beat_s() * self.beats_per_bar

    def bar(self, n: float) -> float:
        return n * self.beats_per_bar

    def beats_to_s(self, b: float) -> float:
        return b * self.beat_s()

    def s_to_beats(self, s: float) -> float:
        return s / self.beat_s()

    # --- events ---
    def _add(self, beat: float, kind: str, **data) -> None:
        self._order += 1
        self.events.append((max(0.0, beat), self._order, kind, data))

    def program(self, ch: int, prog: int, bank: int = 0) -> None:
        self.programs[ch] = (prog, bank)

    def note(self, ch: int, pitch: int, start: float, dur: float, vel: int = 90) -> None:
        pitch = int(round(pitch))
        if pitch < 0 or pitch > 127 or dur <= 0:
            return
        vel = int(max(1, min(127, vel)))
        self._add(start, "on", ch=ch, pitch=pitch, vel=vel)
        self._add(start + dur, "off", ch=ch, pitch=pitch)
        self.end_beat = max(self.end_beat, start + dur)

    def chord(self, ch: int, pitches, start: float, dur: float, vel: int = 90, strum: float = 0.0) -> None:
        for i, p in enumerate(pitches):
            self.note(ch, p, start + i * strum, dur - i * strum, vel)

    def cc(self, ch: int, num: int, val: int, at: float) -> None:
        self._add(at, "cc", ch=ch, num=num, val=int(max(0, min(127, val))))

    def bend(self, ch: int, value: int, at: float) -> None:
        """Pitch bend −8192..8191 (±2 semitones unless bend_range changes it)."""
        self._add(at, "bend", ch=ch, value=int(max(-8192, min(8191, value))))

    def bend_cents(self, ch: int, cents_v: float, at: float, range_semis: float = 2.0) -> None:
        self.bend(ch, int(round(cents_v / (range_semis * 100.0) * 8192.0)), at)

    def bend_ramp(self, ch: int, c0: float, c1: float, start: float, dur: float, steps: int = 16, range_semis: float = 2.0) -> None:
        for i in range(steps + 1):
            k = i / steps
            self.bend_cents(ch, c0 + (c1 - c0) * (0.5 - 0.5 * math.cos(math.pi * k)), start + dur * k, range_semis)

    def bend_range(self, ch: int, semis: int, at: float = 0.0) -> None:
        self.cc(ch, 101, 0, at)
        self.cc(ch, 100, 0, at)
        self.cc(ch, 6, semis, at)
        self.cc(ch, 38, 0, at)

    def volume(self, ch: int, val: int, at: float = 0.0) -> None:
        self.cc(ch, 7, val, at)

    def pan(self, ch: int, val: int, at: float = 0.0) -> None:
        self.cc(ch, 10, val, at)

    def expression(self, ch: int, val: int, at: float) -> None:
        self.cc(ch, 11, val, at)

    def sustain(self, ch: int, on: bool, at: float) -> None:
        self.cc(ch, 64, 127 if on else 0, at)

    # --- output ---
    def to_midi(self, path: str, channels=None, end_beat: float | None = None, tail_s: float = 4.0) -> None:
        chans = None if channels is None else set(channels)
        mid = mido.MidiFile(ticks_per_beat=self.ppq)
        track = mido.MidiTrack()
        mid.tracks.append(track)
        track.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(self.bpm), time=0))
        track.append(mido.MetaMessage("time_signature", numerator=self.beats_per_bar, denominator=4, time=0))
        msgs: list[tuple[int, int, mido.Message]] = []
        order = 0
        for ch, (prog, bank) in sorted(self.programs.items()):
            if chans is not None and ch not in chans:
                continue
            order += 1
            msgs.append((0, order - 1000, mido.Message("control_change", channel=ch, control=0, value=bank, time=0)))
            msgs.append((0, order - 999, mido.Message("program_change", channel=ch, program=prog, time=0)))
        for beat, o, kind, d in self.events:
            if chans is not None and d["ch"] not in chans:
                continue
            tick = int(round(beat * self.ppq))
            if kind == "on":
                m = mido.Message("note_on", channel=d["ch"], note=d["pitch"], velocity=d["vel"], time=0)
            elif kind == "off":
                m = mido.Message("note_off", channel=d["ch"], note=d["pitch"], velocity=0, time=0)
            elif kind == "cc":
                m = mido.Message("control_change", channel=d["ch"], control=d["num"], value=d["val"], time=0)
            elif kind == "bend":
                m = mido.Message("pitchwheel", channel=d["ch"], pitch=d["value"], time=0)
            else:
                continue
            # note-offs before note-ons at the same tick so repeated notes retrigger
            key_order = o if kind != "off" else o - 10 ** 9
            msgs.append((tick, key_order, m))
        msgs.sort(key=lambda m: (m[0], m[1]))
        end = end_beat if end_beat is not None else self.end_beat
        end_tick = int(round((end + self.s_to_beats(tail_s)) * self.ppq))
        last = 0
        for tick, _, m in msgs:
            m.time = max(0, tick - last)
            last = max(last, tick)
            track.append(m)
        track.append(mido.MetaMessage("end_of_track", time=max(0, end_tick - last)))
        os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
        mid.save(path)


def render_midi(mid_path: str, sf2: str | None = None, gain: float = 0.6) -> np.ndarray:
    """FluidSynth → stereo float array at 48 kHz. Reverb and chorus off."""
    sf2 = sf2 or find_sf2()
    fs = shutil.which("fluidsynth")
    if fs is None:
        raise RuntimeError("fluidsynth not found")
    with tempfile.TemporaryDirectory() as td:
        out = os.path.join(td, "out.wav")
        cmd = [fs, "-ni", "-F", out, "-r", str(S.SR), "-O", "float", "-T", "wav", "-R", "0", "-C", "0",
               "-g", str(gain), sf2, mid_path]
        subprocess.run(cmd, check=True, capture_output=True)
        x = S.read_wav(out)
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    return x.astype(np.float64)


def render_stems(score: Score, stems: dict[str, list[int]], length_s: float, tail_s: float = 4.0,
                 sf2: str | None = None, gain: float = 0.6, workdir: str | None = None) -> dict[str, np.ndarray]:
    """Render each stem (a list of channels) to a stereo array of exactly length_s + tail_s seconds."""
    n = S.samples(length_s + tail_s)
    out: dict[str, np.ndarray] = {}
    td = workdir or tempfile.mkdtemp(prefix="ttd_mid_")
    for name, chans in stems.items():
        p = os.path.join(td, f"{name}.mid")
        score.to_midi(p, channels=chans, end_beat=score.s_to_beats(length_s), tail_s=tail_s)
        x = render_midi(p, sf2, gain)
        out[name] = S.fit_length(x, n)
    if workdir is None:
        shutil.rmtree(td, ignore_errors=True)
    return out


# ----------------------------------------------------------------------------------------------
# small pattern helpers used by several tracks
# ----------------------------------------------------------------------------------------------

NOTE_NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def n(name: str) -> int:
    """'C4' → 60, 'Eb4' → 63, 'F#3' → 54."""
    base = NOTE_NAMES[name[0].upper()]
    i = 1
    while i < len(name) and name[i] in "#b":
        base += 1 if name[i] == "#" else -1
        i += 1
    octave = int(name[i:])
    return 12 * (octave + 1) + base


def chord_notes(root: int, quality: str = "maj", inversion: int = 0) -> list[int]:
    q = {"maj": [0, 4, 7], "min": [0, 3, 7], "dim": [0, 3, 6], "aug": [0, 4, 8], "sus2": [0, 2, 7], "sus4": [0, 5, 7],
         "maj7": [0, 4, 7, 11], "min7": [0, 3, 7, 10], "dom7": [0, 4, 7, 10], "add9": [0, 4, 7, 14], "min9": [0, 3, 7, 14],
         "5": [0, 7, 12], "maj9": [0, 4, 7, 11, 14], "m7b5": [0, 3, 6, 10], "minmaj7": [0, 3, 7, 11]}[quality]
    notes = [root + i for i in q]
    for _ in range(inversion):
        notes = notes[1:] + [notes[0] + 12]
    return notes


def humanize(score: Score, ch: int, pitch: int, start: float, dur: float, vel: int, gen: np.random.Generator,
             time_jitter: float = 0.02, vel_jitter: int = 8) -> None:
    score.note(ch, pitch, start + gen.uniform(-time_jitter, time_jitter), dur, vel + int(gen.integers(-vel_jitter, vel_jitter + 1)))
