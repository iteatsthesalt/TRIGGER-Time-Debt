"""Shared synthesis and measurement helpers for TRIGGER: Time Debt (Reference Bible §1.10, §8).

Everything here works on float64 numpy arrays at SR = 48000. Mono signals are 1-D arrays,
stereo signals are (n, 2) arrays. Nothing is random unless a numpy Generator is passed in,
so every generator that seeds its own Generator is deterministic.
"""
from __future__ import annotations

import json
import math
import os
import shutil
import subprocess
import tempfile

import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 48000
TWO_PI = 2.0 * math.pi

# ----------------------------------------------------------------------------------------------
# small conversions
# ----------------------------------------------------------------------------------------------


def db_to_amp(db: float) -> float:
    return 10.0 ** (db / 20.0)


def amp_to_db(a: float) -> float:
    return 20.0 * math.log10(max(1e-12, abs(a)))


def midi_to_hz(midi: float) -> float:
    return 440.0 * 2.0 ** ((midi - 69.0) / 12.0)


def cents(ratio_cents: float) -> float:
    """Frequency ratio for a detune in cents."""
    return 2.0 ** (ratio_cents / 1200.0)


def seconds(n_samples: int) -> float:
    return n_samples / SR


def samples(dur_s: float) -> int:
    return int(round(dur_s * SR))


def t_axis(dur_s: float) -> np.ndarray:
    return np.arange(samples(dur_s)) / SR


def rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed)


# ----------------------------------------------------------------------------------------------
# oscillators and noise
# ----------------------------------------------------------------------------------------------


def _phase(freq, n: int, phase0: float = 0.0) -> np.ndarray:
    """Running phase for a constant or per-sample frequency."""
    if np.isscalar(freq):
        return phase0 + TWO_PI * float(freq) * np.arange(n) / SR
    f = np.asarray(freq, dtype=np.float64)
    if len(f) != n:
        f = np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(f)), f)
    return phase0 + TWO_PI * np.cumsum(f) / SR


def sine(freq, dur_s: float, phase0: float = 0.0) -> np.ndarray:
    return np.sin(_phase(freq, samples(dur_s), phase0))


def saw(freq, dur_s: float, harmonics: int = 24) -> np.ndarray:
    """Additive sawtooth (band-limited enough for pads and bass)."""
    n = samples(dur_s)
    ph = _phase(freq, n)
    out = np.zeros(n)
    for k in range(1, harmonics + 1):
        out += ((-1) ** (k + 1)) * np.sin(k * ph) / k
    return out * (2.0 / math.pi)


def square(freq, dur_s: float, harmonics: int = 15) -> np.ndarray:
    n = samples(dur_s)
    ph = _phase(freq, n)
    out = np.zeros(n)
    for k in range(1, harmonics + 1, 2):
        out += np.sin(k * ph) / k
    return out * (4.0 / math.pi)


def triangle(freq, dur_s: float, harmonics: int = 15) -> np.ndarray:
    n = samples(dur_s)
    ph = _phase(freq, n)
    out = np.zeros(n)
    for i, k in enumerate(range(1, harmonics + 1, 2)):
        out += ((-1) ** i) * np.sin(k * ph) / (k * k)
    return out * (8.0 / (math.pi ** 2))


def pulse_train(freq, dur_s: float, width: float = 0.1) -> np.ndarray:
    """Naive pulse train, useful as a glottal-ish source for creature voices (filter it after)."""
    n = samples(dur_s)
    ph = np.mod(_phase(freq, n), TWO_PI) / TWO_PI
    return np.where(ph < width, 1.0, -width / (1.0 - width))


def noise(dur_s: float, colour: str = "white", gen: np.random.Generator | None = None) -> np.ndarray:
    """White, pink (−3 dB/oct), brown (−6 dB/oct) or blue noise, RMS about 0.3."""
    gen = gen or rng(0)
    n = samples(dur_s)
    w = gen.standard_normal(n)
    if colour == "white":
        out = w
    elif colour == "pink":
        # Paul Kellet's economy pink filter
        b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
        a = [1, -2.494956002, 2.017265875, -0.522189400]
        out = signal.lfilter(b, a, w) * 3.2
    elif colour == "brown":
        out = signal.lfilter([1.0], [1.0, -0.995], w)
        out = out / (np.std(out) + 1e-9)
    elif colour == "blue":
        out = np.diff(w, prepend=0.0)
        out = out / (np.std(out) + 1e-9)
    else:
        raise ValueError(colour)
    return out * (0.3 / (np.std(out) + 1e-9))


# ----------------------------------------------------------------------------------------------
# envelopes
# ----------------------------------------------------------------------------------------------


def adsr(n: int, a: float, d: float, s: float, r: float, curve: float = 1.0) -> np.ndarray:
    """ADSR over n samples. a, d, r in seconds; s is the sustain level. The release starts so
    the whole envelope fits in n samples."""
    a_n, d_n, r_n = samples(a), samples(d), samples(r)
    sus_n = max(0, n - a_n - d_n - r_n)
    if a_n + d_n + r_n > n:  # squeeze proportionally
        total = a_n + d_n + r_n
        a_n, d_n = int(n * a_n / total), int(n * d_n / total)
        r_n = n - a_n - d_n
        sus_n = 0
    env = np.concatenate([
        np.linspace(0.0, 1.0, a_n, endpoint=False) ** curve,
        np.linspace(1.0, s, d_n, endpoint=False),
        np.full(sus_n, s),
        np.linspace(s, 0.0, r_n),
    ])
    return env[:n] if len(env) >= n else np.pad(env, (0, n - len(env)))


def exp_decay(dur_s: float, decay: float, attack_s: float = 0.002) -> np.ndarray:
    """exp(-decay * t) with a short linear attack so clicks do not happen."""
    t = t_axis(dur_s)
    env = np.exp(-decay * t)
    if attack_s > 0:
        env *= np.minimum(1.0, t / attack_s)
    return env


def swell(dur_s: float, peak_at: float = 0.5, power: float = 2.0) -> np.ndarray:
    """A raised-cosine swell with the peak at a fraction of the duration (brush strokes, tides)."""
    n = samples(dur_s)
    k = int(n * peak_at)
    up = 0.5 - 0.5 * np.cos(np.linspace(0, math.pi, max(1, k)))
    down = 0.5 + 0.5 * np.cos(np.linspace(0, math.pi, max(1, n - k)))
    return np.concatenate([up, down])[:n] ** power


def fade(x: np.ndarray, in_s: float = 0.0, out_s: float = 0.0) -> np.ndarray:
    y = x.copy()
    n = len(y)
    if in_s > 0:
        k = min(n, samples(in_s))
        ramp = np.linspace(0, 1, k)
        y[:k] = (y[:k].T * ramp).T
    if out_s > 0:
        k = min(n, samples(out_s))
        ramp = np.linspace(1, 0, k)
        y[n - k:] = (y[n - k:].T * ramp).T
    return y


# ----------------------------------------------------------------------------------------------
# filters
# ----------------------------------------------------------------------------------------------


def _sos(kind: str, fc, order: int = 2):
    nyq = SR * 0.5
    if isinstance(fc, (tuple, list)):
        wn = [max(1.0, fc[0]) / nyq, min(nyq - 1.0, fc[1]) / nyq]
    else:
        wn = min(nyq - 1.0, max(1.0, float(fc))) / nyq
    return signal.butter(order, wn, btype=kind, output="sos")


def _apply_sos(sos, x: np.ndarray) -> np.ndarray:
    if x.ndim == 2:
        return np.stack([signal.sosfilt(sos, x[:, c]) for c in range(x.shape[1])], axis=1)
    return signal.sosfilt(sos, x)


def lowpass(x: np.ndarray, fc: float, order: int = 2) -> np.ndarray:
    return _apply_sos(_sos("lowpass", fc, order), x)


def highpass(x: np.ndarray, fc: float, order: int = 2) -> np.ndarray:
    return _apply_sos(_sos("highpass", fc, order), x)


def bandpass(x: np.ndarray, lo: float, hi: float, order: int = 2) -> np.ndarray:
    return _apply_sos(_sos("bandpass", (lo, hi), order), x)


def resonant_bandpass(x: np.ndarray, fc: float, q: float = 10.0) -> np.ndarray:
    """A narrow resonant band (scipy iirpeak), for porcelain and glass bodies."""
    fc = min(SR * 0.49, max(10.0, fc))
    b, a = signal.iirpeak(fc / (SR * 0.5), q)
    return signal.lfilter(b, a, x)


def resonator_bank(x: np.ndarray, freqs, qs, gains) -> np.ndarray:
    out = np.zeros_like(x)
    for f, q, g in zip(freqs, qs, gains):
        out += g * resonant_bandpass(x, f, q)
    return out


def swept_bandpass(x: np.ndarray, f_start: float, f_end: float, q: float = 8.0, block: int = 256) -> np.ndarray:
    """A resonant band-pass whose centre glides from f_start to f_end over the signal (crack sweeps)."""
    n = len(x)
    out = np.zeros(n)
    zi = None
    nblocks = int(math.ceil(n / block))
    for i in range(nblocks):
        a0, a1 = i * block, min(n, (i + 1) * block)
        frac = i / max(1, nblocks - 1)
        fc = f_start * (f_end / f_start) ** frac
        fc = min(SR * 0.49, max(20.0, fc))
        b, a = signal.iirpeak(fc / (SR * 0.5), q)
        if zi is None:
            zi = signal.lfilter_zi(b, a) * 0.0
        out[a0:a1], zi = signal.lfilter(b, a, x[a0:a1], zi=zi)
    return out


def shelf_high(x: np.ndarray, fc: float, gain_db: float) -> np.ndarray:
    """A crude high shelf: split with a 1st-order lowpass and rescale the top."""
    low = lowpass(x, fc, 1)
    return low + (x - low) * db_to_amp(gain_db)


def one_pole_lp(x: np.ndarray, fc: float) -> np.ndarray:
    a = math.exp(-TWO_PI * fc / SR)
    return signal.lfilter([1 - a], [1, -a], x, axis=0)


def dc_block(x: np.ndarray) -> np.ndarray:
    return signal.lfilter([1, -1], [1, -0.995], x, axis=0)


# ----------------------------------------------------------------------------------------------
# effects
# ----------------------------------------------------------------------------------------------


def to_stereo(x: np.ndarray, width: float = 0.0, gen: np.random.Generator | None = None) -> np.ndarray:
    """Mono → stereo. width 0 = dual mono; width > 0 adds a decorrelated Haas spread."""
    if x.ndim == 2:
        return x
    if width <= 0:
        return np.stack([x, x], axis=1)
    gen = gen or rng(7)
    d = samples(0.0004 + 0.012 * width)
    left = x
    right = np.concatenate([np.zeros(d), x[:-d]]) if d < len(x) else x
    mid = 0.5 * (left + right)
    side = 0.5 * (left - right) * width
    return np.stack([mid + side, mid - side], axis=1)


def pan(x: np.ndarray, p: float) -> np.ndarray:
    """Constant-power pan, p in [-1, 1]."""
    if x.ndim == 2:
        x = x.mean(axis=1)
    ang = (p + 1.0) * 0.25 * math.pi
    return np.stack([x * math.cos(ang), x * math.sin(ang)], axis=1)


def to_mono(x: np.ndarray) -> np.ndarray:
    return x if x.ndim == 1 else x.mean(axis=1)


def _ensure_2d(x: np.ndarray) -> np.ndarray:
    return x if x.ndim == 2 else x[:, None]


def make_ir(rt60: float = 1.8, predelay_s: float = 0.015, damping_hz: float = 4000.0,
            stereo: bool = True, seed: int = 11, early: bool = True) -> np.ndarray:
    """A synthetic room impulse response: early taps + exponentially decaying noise that darkens
    as it decays. Convolve with fftconvolve."""
    gen = rng(seed)
    n = samples(rt60 * 1.2 + predelay_s)
    t = np.arange(n) / SR
    chans = 2 if stereo else 1
    ir = np.zeros((n, chans))
    for c in range(chans):
        tail = gen.standard_normal(n) * np.exp(-6.91 * t / rt60)
        # damping: progressive low-pass by crossfading a dark copy in over time
        dark = lowpass(tail, damping_hz * 0.35, 2)
        bright = lowpass(tail, damping_hz, 1)
        k = np.clip(t / rt60, 0, 1)
        tail = bright * (1 - k) + dark * k
        if early:
            for tap_t, g in [(0.007, 0.7), (0.011, 0.5), (0.019, 0.45), (0.027, 0.35), (0.041, 0.3)]:
                idx = samples(tap_t + gen.uniform(0, 0.003))
                if idx < n:
                    tail[idx] += g * gen.choice([-1, 1])
        ir[:, c] = tail
    pre = np.zeros((samples(predelay_s), chans))
    ir = np.concatenate([pre, ir], axis=0)
    ir /= (np.sqrt(np.sum(ir ** 2, axis=0)).max() + 1e-9)
    return ir if stereo else ir[:, 0]


def reverb(x: np.ndarray, rt60: float = 1.8, mix: float = 0.25, predelay_s: float = 0.015,
           damping_hz: float = 4000.0, seed: int = 11, tail: bool = True) -> np.ndarray:
    """Convolution reverb with a synthetic IR. Mono in → stereo out; stereo in → stereo out.
    If tail is True the output is longer than the input by the IR length."""
    ir = make_ir(rt60, predelay_s, damping_hz, True, seed)
    x2 = _ensure_2d(x)
    if x2.shape[1] == 1:
        x2 = np.repeat(x2, 2, axis=1)
    wet = np.stack([signal.fftconvolve(x2[:, c], ir[:, c]) for c in range(2)], axis=1)
    dry = np.zeros_like(wet)
    dry[: len(x2)] = x2
    out = dry * (1 - mix) + wet * mix
    return out if tail else out[: len(x2)]


def reverse_reverb(x: np.ndarray, rt60: float = 1.5, mix: float = 0.5, seed: int = 12) -> np.ndarray:
    """A swell that arrives before the sound: reverb applied backwards."""
    x2 = _ensure_2d(x)
    if x2.shape[1] == 1:
        x2 = np.repeat(x2, 2, axis=1)
    rev = reverb(x2[::-1], rt60, 1.0, 0.0, 6000.0, seed, tail=True)[::-1]
    out = np.zeros_like(rev)
    out[len(rev) - len(x2):] = x2
    return out * (1 - mix) + rev * mix


def delay(x: np.ndarray, time_s: float, feedback: float = 0.3, mix: float = 0.3, damping_hz: float = 5000.0,
          taps: int = 8) -> np.ndarray:
    d = samples(time_s)
    x2 = _ensure_2d(x)
    n = len(x2) + d * taps
    out = np.zeros((n, x2.shape[1]))
    out[: len(x2)] = x2 * (1 - mix)
    echo = x2.copy()
    for k in range(1, taps + 1):
        echo = lowpass(echo, damping_hz, 1) * feedback if k > 1 else echo * feedback
        a = k * d
        out[a: a + len(echo)] += echo * mix / max(feedback, 1e-6)
    return out if x.ndim == 2 else out[:, 0]


def bitcrush(x: np.ndarray, bits: int = 8, rate_div: int = 4) -> np.ndarray:
    """Quantise to `bits` and sample-hold every `rate_div` samples (U2 at 12 fps, the Singularity)."""
    q = 2 ** (bits - 1)
    y = np.round(np.clip(x, -1, 1) * q) / q
    if rate_div > 1:
        idx = (np.arange(len(y)) // rate_div) * rate_div
        y = y[idx]
    return y


def resample_speed(x: np.ndarray, speed: np.ndarray | float) -> np.ndarray:
    """Variable-speed playback (tape): speed is a per-output-sample ratio (1 = unchanged)."""
    x2 = _ensure_2d(x)
    if np.isscalar(speed):
        n_out = int(len(x2) / float(speed))
        pos = np.arange(n_out) * float(speed)
    else:
        pos = np.cumsum(np.asarray(speed, dtype=np.float64))
        pos = pos[pos < len(x2) - 1]
    src = np.arange(len(x2))
    out = np.stack([np.interp(pos, src, x2[:, c]) for c in range(x2.shape[1])], axis=1)
    return out if x.ndim == 2 else out[:, 0]


def wow_flutter(x: np.ndarray, wow_cents: float = 12.0, wow_hz: float = 0.6, flutter_cents: float = 4.0,
                flutter_hz: float = 7.0, seed: int = 3) -> np.ndarray:
    """Tape wow and flutter (§8.2 vhs_tracking): a slow and a fast pitch modulation, both drifting."""
    gen = rng(seed)
    n = len(x)
    t = np.arange(n) / SR
    drift = one_pole_lp(gen.standard_normal(n), 0.3) * 40.0
    c = wow_cents * np.sin(TWO_PI * wow_hz * t + gen.uniform(0, TWO_PI)) + drift
    c += flutter_cents * np.sin(TWO_PI * flutter_hz * t + gen.uniform(0, TWO_PI)) * (0.7 + 0.3 * np.sin(TWO_PI * 0.21 * t))
    speed = 2.0 ** (c / 1200.0)
    y = resample_speed(x, speed)
    return fit_length(y, n)


def vhs_tear(x: np.ndarray, at_s: float, depth_cents: float = -200.0, dur_s: float = 0.35) -> np.ndarray:
    """A tracking tear: pitch drops by depth over dur then snaps back."""
    n = len(x)
    c = np.zeros(n)
    a, b = samples(at_s), min(n, samples(at_s + dur_s))
    c[a:b] = depth_cents * np.sin(np.linspace(0, math.pi, b - a)) ** 0.5
    return fit_length(resample_speed(x, 2.0 ** (c / 1200.0)), n)


def tape_stop(x: np.ndarray, start_s: float, stop_dur_s: float = 0.4, curve: float = 1.6) -> np.ndarray:
    """From start_s the tape slows to nothing over stop_dur_s and the output stays silent after."""
    x2 = _ensure_2d(x)
    n0 = min(len(x2), samples(start_s))
    head = x2[:n0]
    m = samples(stop_dur_s)
    speed = np.linspace(1.0, 0.0, m) ** curve
    pos = n0 + np.cumsum(speed)
    pos = pos[pos < len(x2) - 1]
    src = np.arange(len(x2))
    tail = np.stack([np.interp(pos, src, x2[:, c]) for c in range(x2.shape[1])], axis=1)
    tail *= np.linspace(1.0, 0.0, len(tail))[:, None] ** 0.3
    out = np.concatenate([head, tail, np.zeros((max(0, len(x2) - n0 - len(tail)), x2.shape[1]))])
    out = out[: len(x2)]
    return out if x.ndim == 2 else out[:, 0]


def pitch_shift(x: np.ndarray, semitones: float) -> np.ndarray:
    """Resampling pitch shift (changes duration, which is right for impacts and tines)."""
    return resample_speed(x, 2.0 ** (semitones / 12.0))


def saturate(x: np.ndarray, drive: float = 2.0) -> np.ndarray:
    return np.tanh(x * drive) / math.tanh(min(drive, 20.0)) if drive > 0 else x


def soft_clip(x: np.ndarray, ceiling: float = 0.95) -> np.ndarray:
    return ceiling * np.tanh(x / ceiling)


def tremolo(x: np.ndarray, rate_hz: float, depth: float = 0.5) -> np.ndarray:
    t = np.arange(len(x)) / SR
    m = 1.0 - depth * 0.5 * (1 + np.sin(TWO_PI * rate_hz * t))
    return (x.T * m).T


def gramophone(x: np.ndarray, lo: float = 300.0, hi: float = 3200.0, drive: float = 1.6) -> np.ndarray:
    """Horn band-pass plus a little saturation (Robo's resonance, the U2 hymns)."""
    y = bandpass(x, lo, hi, 2)
    y = saturate(y, drive) * 0.8
    return resonant_bandpass(y, 1800.0, 2.0) * 0.4 + y if y.ndim == 1 else y


def felt(x: np.ndarray, fc: float = 2200.0) -> np.ndarray:
    """The felt-piano treatment: low-pass, a touch of saturation, softened attack."""
    y = lowpass(x, fc, 2)
    return saturate(y * 1.2, 1.3) * 0.85


def duck(x: np.ndarray, times_s, hold_s: float = 0.2, depth: float = 0.1, release_s: float = 0.25) -> np.ndarray:
    """Side-chain gain: at each time the signal drops to `depth` for hold_s then recovers."""
    n = len(x)
    g = np.ones(n)
    for t0 in times_s:
        a = samples(t0)
        b = min(n, a + samples(hold_s))
        c = min(n, b + samples(release_s))
        if a >= n:
            continue
        g[a:b] = np.minimum(g[a:b], depth)
        if c > b:
            g[b:c] = np.minimum(g[b:c], np.linspace(depth, 1.0, c - b))
    return (x.T * g).T


# ----------------------------------------------------------------------------------------------
# textures that are always underneath
# ----------------------------------------------------------------------------------------------


def tape_hiss(dur_s: float, level_db: float = -60.0, seed: int = 21, stereo: bool = True) -> np.ndarray:
    """Pink-ish hiss with a gentle top shelf, RMS at level_db (silence is never digital zero)."""
    gen = rng(seed)
    h = noise(dur_s, "pink", gen)
    h = highpass(h, 120.0, 1)
    h = shelf_high(h, 3000.0, 2.0)
    h *= db_to_amp(level_db) / (np.std(h) + 1e-9)
    if stereo:
        h2 = noise(dur_s, "pink", gen)
        h2 = highpass(h2, 120.0, 1) * db_to_amp(level_db) / (np.std(h2) + 1e-9)
        return np.stack([h, 0.7 * h + 0.7 * h2], axis=1)
    return h


def vinyl_crackle(dur_s: float, density_hz: float = 18.0, level_db: float = -36.0, seed: int = 22,
                  pops: bool = True) -> np.ndarray:
    """Sparse random ticks with random size, plus occasional low pops (mono)."""
    gen = rng(seed)
    n = samples(dur_s)
    out = np.zeros(n)
    count = max(1, int(density_hz * dur_s))
    idx = gen.integers(0, n, count)
    amp = gen.pareto(2.5, count) + 0.2
    amp = np.minimum(amp, 6.0) / 6.0
    for i, a in zip(idx, amp):
        w = int(gen.integers(2, 12))
        seg = gen.standard_normal(w) * np.hanning(w) * a
        end = min(n, i + w)
        out[i:end] += seg[: end - i]
    out = bandpass(out, 900.0, 9000.0, 1)
    if pops:
        for _ in range(max(1, int(dur_s / 6))):
            i = int(gen.integers(0, n - 2000))
            pop = exp_decay(0.03, 150.0) * np.sin(TWO_PI * gen.uniform(90, 200) * t_axis(0.03))
            out[i: i + len(pop)] += pop * gen.uniform(0.3, 0.8)
    out *= db_to_amp(level_db) / (np.sqrt(np.mean(out ** 2)) + 1e-9)
    return out


def room_tone(dur_s: float, level_db: float = -60.0, seed: int = 23) -> np.ndarray:
    gen = rng(seed)
    r = lowpass(noise(dur_s, "brown", gen), 300.0, 2)
    r *= db_to_amp(level_db) / (np.std(r) + 1e-9)
    return r


# ----------------------------------------------------------------------------------------------
# mixing utilities
# ----------------------------------------------------------------------------------------------


def fit_length(x: np.ndarray, n: int) -> np.ndarray:
    """Crop or zero-pad to n samples (first axis)."""
    if len(x) == n:
        return x
    if len(x) > n:
        return x[:n]
    pad = [(0, n - len(x))] + [(0, 0)] * (x.ndim - 1)
    return np.pad(x, pad)


def place(out: np.ndarray, x: np.ndarray, at_s: float, gain: float = 1.0) -> np.ndarray:
    """Add x into out starting at at_s (in place; returns out). Handles mono→stereo."""
    a = samples(at_s)
    if a >= len(out) or a < 0:
        return out
    if out.ndim == 2 and x.ndim == 1:
        x = np.stack([x, x], axis=1)
    if out.ndim == 1 and x.ndim == 2:
        x = x.mean(axis=1)
    end = min(len(out), a + len(x))
    out[a:end] += x[: end - a] * gain
    return out


def mix(*layers, length: int | None = None) -> np.ndarray:
    """Sum layers of possibly different lengths (and channel counts); mono layers are centred."""
    stereo = any(l.ndim == 2 for l in layers)
    n = length or max(len(l) for l in layers)
    out = np.zeros((n, 2)) if stereo else np.zeros(n)
    for l in layers:
        place(out, l, 0.0)
    return out


def normalize_peak(x: np.ndarray, peak_db: float = -1.0) -> np.ndarray:
    p = np.abs(x).max()
    if p < 1e-9:
        return x
    return x * (db_to_amp(peak_db) / p)


def limiter(x: np.ndarray, ceiling_db: float = -1.0, lookahead_s: float = 0.003, release_s: float = 0.08) -> np.ndarray:
    """A simple look-ahead peak limiter (gain riding on the envelope of |x|)."""
    ceiling = db_to_amp(ceiling_db)
    x2 = _ensure_2d(x)
    peak = np.abs(x2).max(axis=1)
    la = samples(lookahead_s)
    # look-ahead maximum via a sliding window
    if la > 1:
        from numpy.lib.stride_tricks import sliding_window_view
        padded = np.pad(peak, (0, la), mode="edge")
        peak = sliding_window_view(padded, la + 1).max(axis=1)[: len(x2)]
    need = np.minimum(1.0, ceiling / np.maximum(peak, 1e-9))
    # release smoothing: gain can drop instantly, recovers slowly
    a = math.exp(-1.0 / (release_s * SR))
    g = np.empty_like(need)
    cur = 1.0
    # a vectorised approximation: minimum filter followed by one-pole smoothing towards 1
    smooth = signal.lfilter([1 - a], [1, -a], need)
    g = np.minimum(need, smooth)
    g = np.minimum(g, 1.0)
    out = x2 * g[:, None]
    return out if x.ndim == 2 else out[:, 0]


def crossfade_loop(x: np.ndarray, xf_s: float = 2.0) -> np.ndarray:
    """Make a bed loop seamlessly: the last xf_s is cross-faded into the first xf_s and trimmed.
    Returns a signal shorter than the input by xf_s."""
    k = samples(xf_s)
    x2 = _ensure_2d(x)
    head, tail = x2[:k].copy(), x2[-k:].copy()
    w = np.linspace(0, 1, k)[:, None]
    body = x2[:-k].copy()
    body[:k] = head * w + tail * (1 - w)
    return body if x.ndim == 2 else body[:, 0]


def fold_loop_tail(x: np.ndarray, loop_start: int, loop_end: int) -> np.ndarray:
    """Fold everything after loop_end onto the region starting at loop_start, then crop to loop_end.
    This is what makes a looping music file ring across its own seam."""
    x2 = _ensure_2d(x)
    out = x2[:loop_end].copy()
    tail = x2[loop_end:]
    if len(tail):
        end = min(loop_end, loop_start + len(tail))
        out[loop_start:end] += tail[: end - loop_start]
    return out if x.ndim == 2 else out[:, 0]


# ----------------------------------------------------------------------------------------------
# measurement
# ----------------------------------------------------------------------------------------------


def peak_dbfs(x: np.ndarray) -> float:
    return amp_to_db(float(np.abs(x).max()) if len(x) else 0.0)


def rms_db(x: np.ndarray) -> float:
    return 10.0 * math.log10(max(1e-20, float(np.mean(x ** 2))))


_K_STAGE1 = ([1.53512485958697, -2.69169618940638, 1.19839281085285],
             [1.0, -1.69065929318241, 0.73248077421585])
_K_STAGE2 = ([1.0, -2.0, 1.0], [1.0, -1.99004745483398, 0.99007225036621])


def k_weight(x: np.ndarray) -> np.ndarray:
    y = signal.lfilter(_K_STAGE1[0], _K_STAGE1[1], x, axis=0)
    return signal.lfilter(_K_STAGE2[0], _K_STAGE2[1], y, axis=0)


def lufs_integrated(x: np.ndarray) -> float:
    """ITU-R BS.1770-4 integrated loudness at 48 kHz (400 ms blocks, 75% overlap, −70 LUFS absolute
    gate and a −10 LU relative gate). Returns -inf for silence."""
    x2 = _ensure_2d(x).astype(np.float64)
    if len(x2) < samples(0.4):
        x2 = fit_length(x2, samples(0.4))
    y = k_weight(x2)
    block, hop = samples(0.4), samples(0.1)
    n_blocks = 1 + (len(y) - block) // hop
    if n_blocks < 1:
        return float("-inf")
    # mean square per block per channel via cumulative sums
    sq = y ** 2
    csum = np.concatenate([np.zeros((1, sq.shape[1])), np.cumsum(sq, axis=0)])
    starts = np.arange(n_blocks) * hop
    z = (csum[starts + block] - csum[starts]) / block  # (blocks, ch)
    power = z.sum(axis=1)  # G = 1 for L and R
    l_block = -0.691 + 10.0 * np.log10(np.maximum(power, 1e-20))
    keep = l_block > -70.0
    if not keep.any():
        return float("-inf")
    rel = -0.691 + 10.0 * math.log10(float(power[keep].mean())) - 10.0
    keep2 = keep & (l_block > rel)
    if not keep2.any():
        return float("-inf")
    return -0.691 + 10.0 * math.log10(float(power[keep2].mean()))


def normalize_lufs(x: np.ndarray, target: float = -20.0, ceiling_db: float = -1.0) -> tuple[np.ndarray, float]:
    """Gain the signal to the target integrated loudness; limit if the peak would pass the ceiling.
    Returns (signal, gain_applied_linear)."""
    cur = lufs_integrated(x)
    if not math.isfinite(cur):
        return x, 1.0
    g = db_to_amp(target - cur)
    y = x * g
    if peak_dbfs(y) > ceiling_db:
        y = limiter(y, ceiling_db)
    return y, g


def measure(x: np.ndarray) -> dict:
    return {
        "duration_s": round(len(x) / SR, 3),
        "channels": 1 if x.ndim == 1 else int(x.shape[1]),
        "peak_dbfs": round(peak_dbfs(x), 2),
        "rms_dbfs": round(rms_db(x), 2),
        "lufs_i": (lambda v: round(v, 2) if math.isfinite(v) else None)(lufs_integrated(x)),
    }


# ----------------------------------------------------------------------------------------------
# files
# ----------------------------------------------------------------------------------------------


def write_wav(path: str, x: np.ndarray, bits: int = 16) -> None:
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    y = np.clip(x, -1.0, 1.0)
    if bits == 16:
        data = (y * 32767.0).round().astype(np.int16)
    elif bits == 24 or bits == 32:
        data = (y * 2147483647.0).round().astype(np.int32)
    else:
        data = y.astype(np.float32)
    wavfile.write(path, SR, data)


def read_wav(path: str) -> np.ndarray:
    sr, data = wavfile.read(path)
    if data.dtype == np.int16:
        x = data.astype(np.float64) / 32768.0
    elif data.dtype == np.int32:
        x = data.astype(np.float64) / 2147483648.0
    elif data.dtype == np.uint8:
        x = (data.astype(np.float64) - 128.0) / 128.0
    else:
        x = data.astype(np.float64)
    if sr != SR:
        x = signal.resample_poly(x, SR, sr, axis=0)
    return x


def write_ogg(path: str, x: np.ndarray, quality: int = 6) -> None:
    """OGG Vorbis via ffmpeg (libvorbis, -q:a quality), 48 kHz, stereo unless the input is mono."""
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        raise RuntimeError("ffmpeg not found")
    with tempfile.TemporaryDirectory() as td:
        tmp = os.path.join(td, "tmp.wav")
        wavfile.write(tmp, SR, np.clip(x, -1.0, 1.0).astype(np.float32))
        cmd = [ffmpeg, "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(quality), "-ar", str(SR), path]
        subprocess.run(cmd, check=True)


def write_json(path: str, data: dict) -> None:
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


def ogg_duration(path: str) -> float:
    ffprobe = shutil.which("ffprobe")
    if ffprobe is None:
        return float("nan")
    out = subprocess.run([ffprobe, "-v", "error", "-show_entries", "format=duration", "-of", "default=nw=1:nk=1", path],
                         capture_output=True, text=True)
    try:
        return float(out.stdout.strip())
    except ValueError:
        return float("nan")
