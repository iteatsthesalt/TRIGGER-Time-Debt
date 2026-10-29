"""Shared SFX recipes (Reference Bible §1.10 "SFX recipes" and §8.6). Mono float arrays at 48 kHz.
Each family module turns these into files with write_sfx()."""
from __future__ import annotations

import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import synth as S  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
SFX_DIR = os.path.join(ROOT, "audio", "sfx")
SR = S.SR


# ----------------------------------------------------------------------------------------------
# writing
# ----------------------------------------------------------------------------------------------


def write_sfx(family: str, name: str, x: np.ndarray, stereo: bool = False, peak_db: float = -1.0, loop: bool = False) -> dict:
    """Write audio/sfx/<family>/<name>.wav at 48 kHz 16-bit, peak −1 dBFS, mono unless stereo.
    Non-loop sounds get a 2 ms fade-in and a tail fade so nothing clicks."""
    if stereo and x.ndim == 1:
        x = S.to_stereo(x, 0.3)
    if not stereo and x.ndim == 2:
        x = S.to_mono(x)
    x = S.dc_block(x, loop)
    if not loop:
        x = S.fade(x, 0.002, min(0.03, len(x) / SR * 0.1))
    x = S.normalize_peak(x, peak_db)
    path = os.path.join(SFX_DIR, family, f"{name}.wav")
    S.write_wav(path, x, 16)
    m = S.measure(x)
    m.update({"file": os.path.relpath(path, ROOT), "size_bytes": os.path.getsize(path), "loop": loop})
    return m


def write_variations(family: str, name: str, fn, count: int = 5, seed: int = 0, stereo: bool = False) -> list[dict]:
    """fn(gen, index) → array; files <name>_01.wav … <name>_05.wav (what AudioDirector picks from)."""
    out = []
    for i in range(count):
        gen = S.rng(seed * 101 + i)
        out.append(write_sfx(family, f"{name}_{i + 1:02d}", fn(gen, i), stereo))
    return out


# ----------------------------------------------------------------------------------------------
# porcelain, ceramic, glass
# ----------------------------------------------------------------------------------------------


def porcelain_tink(gen: np.random.Generator, base_hz: float = 4200.0, dur: float = 0.08, partials: int = 4, vel: float = 1.0) -> np.ndarray:
    """Inharmonic partials between 3 and 9 kHz, 80 ms, with a tiny contact click."""
    t = S.t_axis(dur + 0.02)
    s = np.zeros_like(t)
    ratios = [1.0, 1.41 + gen.uniform(-0.05, 0.05), 1.93 + gen.uniform(-0.08, 0.08), 2.17 + gen.uniform(-0.1, 0.1)]
    for i, r in enumerate(ratios[:partials]):
        f = base_hz * r
        if f > SR * 0.45:
            continue
        s += (0.9 ** i) * np.sin(S.TWO_PI * f * t + gen.uniform(0, 6)) * np.exp(-t * (40.0 + 25.0 * i) / (dur / 0.08))
    s *= np.minimum(1.0, t * 2500.0)
    click = S.highpass(gen.standard_normal(96) * np.hanning(96), 4000.0, 2) * 0.3
    s[:96] += click
    return S.normalize_peak(s, -1.0) * vel


def crack(gen: np.random.Generator, size: float = 0.5, dur: float | None = None) -> np.ndarray:
    """Noise burst into a swept resonant band-pass: a hairline (size 0) to a shell splitting (size 1)."""
    dur = dur or (0.12 + 0.5 * size)
    n = S.samples(dur)
    t = np.arange(n) / SR
    burst = gen.standard_normal(n) * np.exp(-t * (26.0 - 14.0 * size)) * np.minimum(1.0, t * 4000.0)
    f0 = 6500.0 - 2500.0 * size
    f1 = 1400.0 - 900.0 * size
    y = S.swept_bandpass(burst, f0, f1, 9.0 + 6.0 * size, 96)
    # the body resonance of the porcelain object
    body = S.resonant_bandpass(burst, 900.0 - 500.0 * size, 12.0) * (0.4 + 0.5 * size)
    y = y + body
    # the crack propagates as a few fast stutters
    for k in range(int(2 + 5 * size)):
        at = int(gen.uniform(0.004, dur * 0.5) * SR)
        w = int(gen.uniform(0.002, 0.006) * SR)
        if at + w < n:
            y[at: at + w] += S.highpass(gen.standard_normal(w) * np.hanning(w), 2500.0, 2) * (0.5 + 0.4 * size)
    return S.normalize_peak(y, -1.0)


def shard_spill(gen: np.random.Generator, dur: float = 1.4, count: int = 28, base_hz: float = 3600.0) -> np.ndarray:
    """A crystalline spill: many small tinks tumbling, denser at the start, rising slightly."""
    out = np.zeros(S.samples(dur) + S.samples(0.2))
    for k in range(count):
        at = dur * (gen.uniform() ** 1.7) * 0.85
        f = base_hz * (1.0 + 0.6 * gen.uniform()) * (1.0 + 0.25 * at / dur)
        S.place(out, porcelain_tink(gen, f, 0.06 + 0.05 * gen.uniform(), 3, 0.3 + 0.7 * gen.uniform() * (1 - at / dur)), at)
    return S.normalize_peak(out[: S.samples(dur)], -1.0)


def gong(gen: np.random.Generator, f0: float = 98.0, dur: float = 3.0, bright: float = 1.0, submerged: bool = False) -> np.ndarray:
    """A gong: slow-blooming inharmonic partials with a shimmer; submerged = low-passed with a wobble."""
    t = S.t_axis(dur)
    s = np.zeros_like(t)
    ratios = [1.0, 1.52, 2.0, 2.48, 3.07, 3.92, 4.6, 5.9]
    for i, r in enumerate(ratios):
        a = (0.8 ** i) * (bright if i > 2 else 1.0)
        bloom = 1.0 - np.exp(-t * (18.0 - 1.5 * i))
        s += a * np.sin(S.TWO_PI * f0 * r * (1 + 0.0008 * i) * t + gen.uniform(0, 6)) * np.exp(-t * (0.9 + 0.5 * i)) * bloom
    strike = S.lowpass(gen.standard_normal(len(t)), 1200.0, 2) * np.exp(-t * 60.0) * 0.6
    s = s + strike
    if submerged:
        s = S.lowpass(s, 700.0, 2)
        s = S.wow_flutter(s, 25.0, 0.9, 6.0, 4.0, seed=int(gen.integers(0, 1000)))
    return S.normalize_peak(s, -1.0)


def bell(gen: np.random.Generator, f0: float = 1760.0, dur: float = 1.2, brightness: float = 1.0) -> np.ndarray:
    """A small bright bell (FM pair plus a partial), brightness scales the modulation index."""
    t = S.t_axis(dur)
    idx = 2.2 * brightness * np.exp(-t * 4.0)
    mod = np.sin(S.TWO_PI * f0 * 1.4 * t) * idx
    s = np.sin(S.TWO_PI * f0 * t + mod) * np.exp(-t * 3.5)
    s += 0.35 * np.sin(S.TWO_PI * f0 * 2.76 * t) * np.exp(-t * 7.0) * brightness
    s *= np.minimum(1.0, t * 1500.0)
    return S.normalize_peak(s, -1.0)


def glass_harp(gen: np.random.Generator, f0: float = 880.0, dur: float = 1.5) -> np.ndarray:
    t = S.t_axis(dur)
    s = np.sin(S.TWO_PI * f0 * t) * S.swell(dur, 0.35, 1.2)
    s += 0.3 * np.sin(S.TWO_PI * f0 * 3.01 * t) * S.swell(dur, 0.5, 2.0)
    s *= 1.0 + 0.08 * np.sin(S.TWO_PI * 5.5 * t)
    return S.normalize_peak(s, -1.0)


# ----------------------------------------------------------------------------------------------
# paper, brush, tide, wind
# ----------------------------------------------------------------------------------------------


def brush_on_paper(gen: np.random.Generator, dur: float = 0.14, lo: float = 900.0, hi: float = 5200.0, peak_at: float = 0.4) -> np.ndarray:
    """Band-passed pink noise with a 120 ms swell and the grain of the paper (amplitude jitter)."""
    x = S.bandpass(S.noise(dur, "pink", gen), lo, hi, 2)
    grain = 1.0 + 0.35 * S.one_pole_lp(gen.standard_normal(S.samples(dur)), 900.0) * 6
    return S.normalize_peak(x * S.swell(dur, peak_at, 1.5) * grain, -1.0)


def tide_swell(gen: np.random.Generator, dur: float = 0.6, fc: float = 260.0) -> np.ndarray:
    x = S.lowpass(S.noise(dur, "brown", gen), fc, 2)
    return S.normalize_peak(x * S.swell(dur, 0.35, 1.3), -1.0)


def paper_tear(gen: np.random.Generator, dur: float = 0.5) -> np.ndarray:
    """Filtered noise with amplitude jitter — fibres letting go one after another."""
    n = S.samples(dur)
    x = S.bandpass(S.noise(dur, "white", gen), 1200.0, 7000.0, 2)
    jitter = np.abs(S.one_pole_lp(gen.standard_normal(n), 180.0)) * 8
    jitter = np.minimum(jitter, 1.5)
    env = S.swell(dur, 0.3, 1.0)
    return S.normalize_peak(x * jitter * env, -1.0)


def paper_rustle(gen: np.random.Generator, dur: float = 0.4) -> np.ndarray:
    n = S.samples(dur)
    x = S.bandpass(S.noise(dur, "white", gen), 2000.0, 9000.0, 2)
    env = np.abs(S.one_pole_lp(gen.standard_normal(n), 30.0)) * 12 * S.swell(dur, 0.5, 0.8)
    return S.normalize_peak(x * env, -1.0)


def whoosh(gen: np.random.Generator, dur: float = 0.35, f_start: float = 600.0, f_end: float = 2400.0, q: float = 4.0, peak_at: float = 0.55) -> np.ndarray:
    x = S.swept_bandpass(S.noise(dur, "white", gen), f_start, f_end, q, 256)
    return S.normalize_peak(x * S.swell(dur, peak_at, 1.8), -1.0)


# ----------------------------------------------------------------------------------------------
# mechanisms and tones
# ----------------------------------------------------------------------------------------------


def clock_tick(gen: np.random.Generator, pitch: float = 1.0, dur: float = 0.03) -> np.ndarray:
    n = S.samples(dur)
    x = gen.standard_normal(n) * np.exp(-np.arange(n) / SR * 300.0)
    y = S.resonant_bandpass(x, 3200.0 * pitch, 12.0) + 0.5 * S.resonant_bandpass(x, 5600.0 * pitch, 16.0) + 0.3 * S.highpass(x, 2000.0, 2)
    return S.normalize_peak(y * np.minimum(1.0, np.arange(n) / (SR * 0.0005)), -1.0)


def woodblock(gen: np.random.Generator, f0: float = 820.0, dur: float = 0.12) -> np.ndarray:
    t = S.t_axis(dur)
    s = np.sin(S.TWO_PI * f0 * t) * np.exp(-t * 45.0) + 0.5 * np.sin(S.TWO_PI * f0 * 2.4 * t) * np.exp(-t * 80.0)
    s += S.bandpass(gen.standard_normal(len(t)), 1500.0, 5000.0, 2) * np.exp(-t * 140.0) * 0.6
    return S.normalize_peak(s * np.minimum(1.0, t * 3000.0), -1.0)


def coin(gen: np.random.Generator, semitones: float = 0.0, dur: float = 0.9) -> np.ndarray:
    """Gaspar's coin: a metallic ring whose spin flutter slows as it settles, pitched by semitones."""
    t = S.t_axis(dur)
    ratio = 2.0 ** (semitones / 12.0)
    s = np.zeros_like(t)
    for r, a, d in [(1.0, 1.0, 4.0), (1.19, 0.6, 5.5), (2.37, 0.4, 7.0), (3.41, 0.25, 9.0)]:
        s += a * np.sin(S.TWO_PI * 2650.0 * ratio * r * t + gen.uniform(0, 6)) * np.exp(-t * d)
    spin_rate = 38.0 * np.exp(-t * 1.6) + 6.0
    spin = 0.6 + 0.4 * np.sin(S.TWO_PI * np.cumsum(spin_rate) / SR)
    s = s * spin * np.minimum(1.0, t * 2000.0)
    s += S.highpass(gen.standard_normal(len(t)), 5000.0, 2) * np.exp(-t * 120.0) * 0.5
    return S.normalize_peak(s, -1.0)


def karplus(gen: np.random.Generator, f0: float, dur: float = 1.5, damping: float = 0.996, bright: float = 0.5) -> np.ndarray:
    """Karplus–Strong pluck (harp, koto-ish)."""
    n = S.samples(dur)
    period = max(2, int(round(SR / f0)))
    buf = gen.standard_normal(period)
    buf = S.lowpass(buf, 2000.0 + 8000.0 * bright, 1)
    out = np.zeros(n)
    idx = 0
    prev = 0.0
    for i in range(n):
        v = buf[idx]
        out[i] = v
        new = damping * 0.5 * (v + prev)
        prev = v
        buf[idx] = new
        idx = (idx + 1) % period
    return S.normalize_peak(out, -1.0)


def harp_pluck(gen: np.random.Generator, f0: float, dur: float = 1.4) -> np.ndarray:
    """A harp pluck as a bright decaying additive tone (faster than the KS loop for many notes)."""
    t = S.t_axis(dur)
    s = np.zeros_like(t)
    for k in range(1, 9):
        s += (1.0 / k ** 1.3) * np.sin(S.TWO_PI * f0 * k * t + gen.uniform(0, 6)) * np.exp(-t * (2.2 + 1.6 * k))
    s *= np.minimum(1.0, t * 1200.0)
    return S.normalize_peak(s, -1.0)


def sub_thump(gen: np.random.Generator, f0: float = 48.0, dur: float = 0.5) -> np.ndarray:
    t = S.t_axis(dur)
    f = f0 * (1 + 1.5 * np.exp(-t * 35.0))
    s = np.sin(S.TWO_PI * np.cumsum(f) / SR) * np.exp(-t * 7.0) * np.minimum(1.0, t * 400.0)
    return S.normalize_peak(s, -1.0)


def whisper(gen: np.random.Generator, dur: float = 1.0, voices: int = 7, reverse: bool = False) -> np.ndarray:
    """Whispered voices: noise through moving vowel formants, several layers slightly offset."""
    n = S.samples(dur)
    out = np.zeros(n + S.samples(0.3))
    vowels = [(730, 1090, 2440), (270, 2290, 3010), (530, 1840, 2480), (570, 840, 2410), (440, 1020, 2240)]
    for v in range(voices):
        x = S.noise(dur, "white", gen)
        seg = np.zeros(n)
        f1, f2, f3 = vowels[int(gen.integers(0, len(vowels)))]
        g1, g2, g3 = [1.0, 0.5, 0.25]
        seg = g1 * S.resonant_bandpass(x, f1 * gen.uniform(0.9, 1.1), 6.0) + g2 * S.resonant_bandpass(x, f2 * gen.uniform(0.9, 1.1), 8.0) + g3 * S.resonant_bandpass(x, f3, 10.0)
        syll = np.abs(S.one_pole_lp(gen.standard_normal(n), 6.0)) * 10
        seg = seg * np.minimum(syll, 1.2) * S.swell(dur, gen.uniform(0.3, 0.7), 1.0)
        if reverse:
            seg = seg[::-1]
        S.place(out, seg, gen.uniform(0, 0.12) * (v > 0), 0.6 + 0.4 / (v + 1))
    return S.normalize_peak(out[: n + S.samples(0.3)], -1.0)


def reversed_tine(gen: np.random.Generator, midi: int = 72, dur: float = 0.8) -> np.ndarray:
    """The time fingerprint's first half: a music-box tine played backwards (a swell into a click)."""
    import music_box as MB
    x = MB.tine(S.midi_to_hz(midi), dur, 1.0, 1.0, gen.uniform(-4, 4), gen)
    return S.normalize_peak(x[::-1], -1.0)


def breath_in(gen: np.random.Generator, dur: float = 0.7) -> np.ndarray:
    x = S.swept_bandpass(S.noise(dur, "pink", gen), 500.0, 2200.0, 2.5, 512)
    return S.normalize_peak(x * S.swell(dur, 0.8, 1.6), -1.0)


def shimmer(gen: np.random.Generator, dur: float = 1.2, base: float = 2000.0, count: int = 14) -> np.ndarray:
    """A bright shimmer: a cloud of short high sines, rising."""
    out = np.zeros(S.samples(dur) + S.samples(0.4))
    for k in range(count):
        at = dur * 0.7 * (k / count) ** 1.3
        f = base * (1.0 + 1.5 * gen.uniform()) * (1 + 0.5 * at / dur)
        d = 0.25 + 0.3 * gen.uniform()
        t = S.t_axis(d)
        s = np.sin(S.TWO_PI * f * t) * np.exp(-t * 9.0) * np.minimum(1.0, t * 800.0)
        S.place(out, s, at, 0.4 + 0.6 * gen.uniform())
    return S.normalize_peak(out[: S.samples(dur)], -1.0)
