"""The music box with removable tines (Reference Bible §1.10), extended for the hub.

It renders the "Wind Scene 1024" cell (§8.3: E4 G4 C5 B4 · G4 E4 D4 C4, even quavers at 72 BPM,
every eighth tick a silent click) in the porcelain_stress states:

    box_100   every tine present
    box_060   the C4 tine is gone, so the phrase can no longer come home
    box_020   the C4 is gone and every third note is missing
    box_000   the box starts, then the tape stops (0.4 s pitch fall) and only room tone is left

The same functions render the box stems of mus_u0_wind_scene_1024, mus_title and the battle
tracks from note lists, so the hub, the title and the stings share one instrument.

    python3 tools/audio/music_box.py [--out audio/music/motifs] [--bpm 72]
"""
from __future__ import annotations

import argparse
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import synth as S  # noqa: E402

SR = S.SR
# ratio, amplitude, decay (1/s) — the bible's inharmonic tine partials
PARTIALS = [(1.0, 1.0, 1.8), (2.76, 0.35, 3.5), (5.40, 0.15, 6.0), (8.93, 0.06, 9.0)]
CELL = [64, 67, 72, 71, 67, 64, 62, 60]  # E4 G4 C5 B4 G4 E4 D4 C4


def tine(freq: float, dur: float = 2.5, vel: float = 1.0, brightness: float = 1.0, detune_cents: float = 0.0,
         gen: np.random.Generator | None = None) -> np.ndarray:
    """One struck tine: inharmonic partials with a 2.5 ms pluck, a breath of pin noise, velocity
    shapes the brightness the way a harder pin does."""
    t = np.arange(int(SR * dur)) / SR
    f0 = freq * S.cents(detune_cents)
    s = np.zeros_like(t)
    for i, (r, a, d) in enumerate(PARTIALS):
        amp = a * (brightness ** i) * (0.6 + 0.4 * vel) ** i
        f = f0 * r
        if f > SR * 0.45:
            continue
        s += amp * np.exp(-d * t) * np.sin(S.TWO_PI * f * t)
    s *= np.minimum(1.0, t * 400.0)  # 2.5 ms pluck
    # the pin releasing the tine: a 3 ms bright click, very quiet
    gen = gen or S.rng(int(freq) % 997)
    click_n = int(SR * 0.004)
    click = gen.standard_normal(click_n) * np.hanning(click_n) * 0.08 * vel
    click = S.highpass(click, 3000.0, 2)
    s[:click_n] += click
    return s * vel


def tick(gen: np.random.Generator | None = None, vel: float = 1.0) -> np.ndarray:
    """The escapement tick: a 25 ms metallic click (noise into two narrow resonances)."""
    gen = gen or S.rng(5)
    n = int(SR * 0.045)
    x = gen.standard_normal(n) * np.exp(-np.arange(n) / SR * 220.0)
    y = S.resonant_bandpass(x, 3800.0, 14.0) * 0.6 + S.resonant_bandpass(x, 6100.0, 18.0) * 0.4 + S.highpass(x, 2500.0, 2) * 0.25
    y *= np.minimum(1.0, np.arange(n) / (SR * 0.0008))
    return S.normalize_peak(y, -3.0) * vel


def silent_click(gen: np.random.Generator | None = None) -> np.ndarray:
    """The missing tooth: the mechanism moves but nothing rings — a dull 12 ms thud at −20 dB."""
    gen = gen or S.rng(6)
    n = int(SR * 0.02)
    x = gen.standard_normal(n) * np.exp(-np.arange(n) / SR * 400.0)
    y = S.lowpass(x, 900.0, 2)
    return S.normalize_peak(y, -22.0)


def grind(dur: float = 1.1, gen: np.random.Generator | None = None) -> np.ndarray:
    """The mainspring grind heard every 4 bars: a rattling low burst (noise, 28 Hz amplitude
    modulation, 90–700 Hz body) with a ratchet tail."""
    gen = gen or S.rng(8)
    t = S.t_axis(dur)
    x = S.noise(dur, "pink", gen)
    body = S.bandpass(x, 90.0, 700.0, 2)
    am = 0.55 + 0.45 * np.sign(np.sin(S.TWO_PI * 28.0 * t + 0.4 * np.sin(S.TWO_PI * 3.0 * t)))
    env = S.swell(dur, 0.25, 1.4)
    y = body * am * env
    # ratchet: 11 clicks slowing down
    for i in range(11):
        at = int(SR * (0.15 + 0.07 * i + 0.004 * i * i))
        if at < len(y) - 400:
            c = gen.standard_normal(300) * np.hanning(300) * 0.5 * (1 - i / 14)
            y[at: at + 300] += S.bandpass(c, 1200.0, 5000.0, 1)
    return S.normalize_peak(y, -6.0)


def render_notes(notes, length_s: float, missing=(), skip_every: int = 0, dur: float = 2.6, detune_cents: float = 0.0,
                 wobble_cents: float = 2.5, brightness: float = 1.0, seed: int = 100) -> np.ndarray:
    """Render (time_s, midi, velocity 0..1) tuples with the tine synth into a mono buffer of
    length_s. `missing` removes tines by pitch, `skip_every` silences every k-th struck note."""
    gen = S.rng(seed)
    out = np.zeros(S.samples(length_s) + S.samples(dur))
    for i, (t0, midi, vel) in enumerate(notes):
        if midi is None or midi in missing or (skip_every and i % skip_every == skip_every - 1):
            continue
        det = detune_cents + gen.uniform(-wobble_cents, wobble_cents)
        s = tine(S.midi_to_hz(midi), dur, vel, brightness, det, gen)
        S.place(out, s, t0)
    return out[: S.samples(length_s)]


def render_ticks(times_s, length_s: float, silent_every: int = 8, grind_times_s=(), vel: float = 0.5, seed: int = 101,
                 silent_positions=None, grind_gain: float = 0.7) -> np.ndarray:
    """The escapement: a tick at each time, every `silent_every`-th a silent click (or the indices in
    `silent_positions`); mainspring grinds at grind_times_s."""
    gen = S.rng(seed)
    out = np.zeros(S.samples(length_s) + S.samples(1.5))
    for i, t0 in enumerate(times_s):
        silent = (i in silent_positions) if silent_positions is not None else (silent_every and i % silent_every == silent_every - 1)
        if silent:
            S.place(out, silent_click(gen), t0)
        else:
            S.place(out, tick(gen, vel * gen.uniform(0.85, 1.0)), t0)
    for g in grind_times_s:
        S.place(out, grind(1.1, gen), g, grind_gain)
    return out[: S.samples(length_s)]


def render(notes, bpm: float = 72, missing=(), skip_every: int = 0, tape_stop: bool = False,
           include_tick: bool = True, tail_s: float = 3.0, seed: int = 1) -> np.ndarray:
    """The bible's API: a note list at quaver spacing (two quavers per beat) → float mono.
    Ticks run under the tines with every eighth tick silent."""
    quaver = 60.0 / bpm / 2.0
    evts = [(i * quaver, m, 0.85) for i, m in enumerate(notes)]
    length = len(notes) * quaver + tail_s
    out = render_notes(evts, length, missing, skip_every, seed=seed)
    if include_tick:
        out += render_ticks([i * quaver for i in range(len(notes))], length, 8, vel=0.35, seed=seed + 1) * 0.5
    if tape_stop:
        out = S.tape_stop(out, len(notes) * quaver * 0.5 + quaver * 2, 0.4)
    return out


def cell_states(bpm: float = 72, repeats: int = 2, seed: int = 1) -> dict[str, np.ndarray]:
    notes = CELL * repeats
    return {
        "box_100": render(notes, bpm, seed=seed),
        "box_060": render(notes, bpm, missing={60}, seed=seed),
        "box_020": render(notes, bpm, missing={60}, skip_every=3, seed=seed),
        "box_000": render(notes, bpm, missing={60}, skip_every=3, tape_stop=True, seed=seed),
    }


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    ap.add_argument("--out", default=os.path.join(root, "audio", "music", "motifs"))
    ap.add_argument("--bpm", type=float, default=72.0)
    args = ap.parse_args(argv)
    os.makedirs(args.out, exist_ok=True)
    for name, x in cell_states(args.bpm).items():
        x = S.normalize_peak(x, -1.0) * 0.8
        x = x + S.room_tone(len(x) / SR, -60.0) + S.tape_hiss(len(x) / SR, -62.0, stereo=False)
        p = os.path.join(args.out, f"{name}.wav")
        S.write_wav(p, x)
        m = S.measure(x)
        print(f"{p}: {m['duration_s']} s, peak {m['peak_dbfs']} dBFS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
