"""Ambience beds (§8.6): 60–90 s seamless stereo OGG loops with their identity events.
  amb_u0       wind, the distant fair, the Horologe tick; a bell, gulls over Truce, Robo's eye chirp
  amb_u1       fire roar under silence, washi crackle; a temple bell, a crow, banners snapping
  amb_transit  fracture wind and the chest rumble
"""
from __future__ import annotations

import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "tracks"))
sys.path.insert(0, os.path.join(HERE, "sfx"))
import synth as S  # noqa: E402
import music_box as MB  # noqa: E402
import common as C  # noqa: E402
import base as B  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
AMB_DIR = os.path.join(ROOT, "audio", "ambience")
AMB_LUFS = -26.0


def _finish(name: str, bed: np.ndarray, length_s: float, xf_s: float, notes: str) -> dict:
    """Cross-fade into a seamless loop, add the hiss floor, normalise to AMB_LUFS, write OGG + JSON."""
    bed = S.crossfade_loop(bed, xf_s)[: S.samples(length_s)]
    bed = bed + S.tape_hiss(length_s, -58.0, seed=S.stable_seed(name))
    y, _ = S.normalize_lufs(bed, AMB_LUFS, -3.0)
    os.makedirs(AMB_DIR, exist_ok=True)
    path = os.path.join(AMB_DIR, f"{name}.ogg")
    S.write_ogg(path, y, 6)
    m = S.measure(y)
    side = {"id": name, "file": os.path.basename(path), "duration_s": length_s, "loop": True, "loop_offset": 0.0,
            "size_bytes": os.path.getsize(path), **m, "notes": notes}
    S.write_json(os.path.join(AMB_DIR, f"{name}.json"), side)
    return side


def church_bell(gen: np.random.Generator, f0: float = 330.0, dur: float = 6.0) -> np.ndarray:
    t = S.t_axis(dur)
    s = np.zeros_like(t)
    for r, a, d in [(0.5, 0.5, 0.5), (1.0, 1.0, 0.7), (1.2, 0.6, 0.9), (1.5, 0.5, 1.1), (2.0, 0.45, 1.4), (2.5, 0.3, 1.8), (3.0, 0.2, 2.2), (4.2, 0.1, 3.0)]:
        s += a * np.sin(S.TWO_PI * f0 * r * t + gen.uniform(0, 6)) * np.exp(-t * d)
    s *= np.minimum(1.0, t * 300.0)
    s += S.bandpass(gen.standard_normal(len(t)), 800.0, 4000.0, 2) * np.exp(-t * 40.0) * 0.3
    return S.normalize_peak(s, -1.0)


def temple_bell(gen: np.random.Generator, f0: float = 92.0, dur: float = 10.0) -> np.ndarray:
    t = S.t_axis(dur)
    s = np.zeros_like(t)
    for r, a, d in [(1.0, 1.0, 0.35), (2.0, 0.6, 0.5), (2.4, 0.5, 0.6), (3.0, 0.4, 0.8), (4.1, 0.25, 1.1), (5.4, 0.15, 1.6)]:
        beat = 1.0 + 0.15 * np.sin(S.TWO_PI * (0.6 + 0.3 * r) * t)
        s += a * np.sin(S.TWO_PI * f0 * r * t + gen.uniform(0, 6)) * np.exp(-t * d) * beat
    s *= np.minimum(1.0, t * 200.0)
    s += S.lowpass(gen.standard_normal(len(t)), 900.0, 2) * np.exp(-t * 30.0) * 0.5
    return S.normalize_peak(s, -1.0)


def gull(gen: np.random.Generator) -> np.ndarray:
    """A gull cry: a falling, slightly cracked tone with breathy noise."""
    dur = 0.35 + 0.25 * gen.uniform()
    t = S.t_axis(dur)
    f = (1900.0 + 400 * gen.uniform()) * (1.0 + 0.25 * np.exp(-t * 12.0)) * (1 - 0.3 * t / dur)
    f *= 1.0 + 0.03 * np.sin(S.TWO_PI * 38.0 * t)
    s = np.sin(S.TWO_PI * np.cumsum(f) / S.SR) * 0.7 + 0.3 * np.sin(S.TWO_PI * np.cumsum(2 * f) / S.SR)
    s = np.tanh(s * 2.0)
    s += S.bandpass(gen.standard_normal(len(t)), 1500.0, 5000.0, 2) * 0.25
    return S.normalize_peak(s * S.swell(dur, 0.25, 1.2), -1.0)


def crow(gen: np.random.Generator) -> np.ndarray:
    """A crow's caw: a rough pulse train through a throat formant, pitch falling."""
    dur = 0.28 + 0.15 * gen.uniform()
    t = S.t_axis(dur)
    f = (330.0 + 60 * gen.uniform()) * (1 + 0.2 * np.exp(-t * 20)) * (1 - 0.25 * t / dur)
    src = S.pulse_train(f, dur, 0.18)
    src *= 1.0 + 0.6 * np.sign(np.sin(S.TWO_PI * 55.0 * t))  # the rasp
    s = S.resonant_bandpass(src, 1150.0, 4.0) + 0.6 * S.resonant_bandpass(src, 2300.0, 6.0) + 0.3 * S.lowpass(src, 600.0, 2)
    return S.normalize_peak(s * S.swell(dur, 0.3, 1.0), -1.0)


def banner_snap(gen: np.random.Generator) -> np.ndarray:
    dur = 0.5
    t = S.t_axis(dur)
    snap = S.bandpass(gen.standard_normal(len(t)), 600.0, 5000.0, 2) * np.exp(-t * 45.0)
    flutter = S.bandpass(S.noise(dur, "pink", gen), 300.0, 2500.0, 2) * np.abs(np.sin(S.TWO_PI * 14.0 * t)) * np.exp(-t * 6.0) * 0.5
    return S.normalize_peak(snap + flutter, -1.0)


def robo_chirp(gen: np.random.Generator) -> np.ndarray:
    dur = 0.22
    t = S.t_axis(dur)
    f = np.where(t < 0.1, 1800.0, 2400.0)
    s = np.sin(S.TWO_PI * np.cumsum(f) / S.SR) * (np.exp(-((t - 0.05) ** 2) / 0.0006) + np.exp(-((t - 0.15) ** 2) / 0.0006))
    return S.normalize_peak(S.bandpass(s, 400.0, 6000.0, 1), -1.0)


def fair_far(length_s: float, gen: np.random.Generator) -> np.ndarray:
    """The fair heard across the water: a detuned accordion-ish drone and a far frame-drum pulse,
    band-passed and washed in a long reverb."""
    t = S.t_axis(length_s)
    tones = np.zeros_like(t)
    for midi, det in [(55, 0), (62, 6), (67, -4), (71, 9), (74, -7)]:
        f = S.midi_to_hz(midi) * S.cents(det)
        tones += S.saw(f, length_s, 10) * (0.3 + 0.2 * np.sin(S.TWO_PI * (0.05 + 0.01 * midi % 3) * t + midi))
    tones = S.bandpass(tones, 300.0, 1800.0, 2)
    pulse = np.zeros_like(t)
    beat = 60.0 / 108.0
    for k in range(int(length_s / beat)):
        at = S.samples(k * beat)
        n = S.samples(0.12)
        if at + n < len(pulse):
            pulse[at: at + n] += np.sin(S.TWO_PI * 90.0 * np.arange(n) / S.SR) * np.exp(-np.arange(n) / S.SR * 25) * (0.5 if k % 2 else 1.0)
    y = tones * 0.5 + S.lowpass(pulse, 400.0, 2) * 0.6
    y *= 0.6 + 0.4 * np.sin(S.TWO_PI * 0.013 * t)  # it drifts with the wind
    return S.reverb(y, 3.5, 0.8, 0.05, 2500.0, seed=int(gen.integers(0, 1000)), tail=False)


def build_u0(length_s: float = 80.0) -> dict:
    gen = S.rng(2000)
    L = length_s + 4.0
    wind = C.wind_bed(L, seed=2001, gust_hz=0.05, lo=120.0, hi=1200.0, level_db=-26.0)
    fair = fair_far(L, gen) * S.db_to_amp(-34.0)
    # the Horologe tick at 72 BPM with the missing tooth, far away
    beat = 60.0 / 72.0
    times = [k * beat for k in range(int(L / beat) + 1)]
    tick = MB.render_ticks(times, L, 8, (), vel=0.4, seed=2002)
    tick = S.reverb(S.lowpass(tick, 3500.0, 1), 2.6, 0.5, 0.03, 3000.0, seed=2003, tail=False) * S.db_to_amp(-30.0)
    events = np.zeros((S.samples(L), 2))
    bell = church_bell(gen, 330.0, 7.0)
    for at in (14.0, 46.0):
        S.place(events, S.pan(S.reverb(bell, 3.0, 0.5, 0.04, 3000.0, seed=2004, tail=False), -0.4), at, S.db_to_amp(-24.0))
    for at in (6.5, 7.1, 28.0, 29.0, 29.6, 58.0, 71.0):
        S.place(events, S.pan(S.reverb(gull(gen), 1.5, 0.4, 0.02, 5000.0, seed=2005, tail=False), gen.uniform(-0.8, 0.8)), at, S.db_to_amp(-30.0 + gen.uniform(-4, 2)))
    for at in (22.0, 40.0, 63.0):
        S.place(events, S.pan(robo_chirp(gen), 0.3), at, S.db_to_amp(-34.0))
    bed = wind + fair + tick + events
    return _finish("amb_u0", bed, length_s, 4.0,
                   "Wind through the Horologe, the fair across the water, the 72 BPM tick with its missing tooth; bells at 14 s and 46 s, gulls, Robo's eye chirp.")


def build_u1(length_s: float = 80.0) -> dict:
    gen = S.rng(2100)
    L = length_s + 4.0
    t = S.t_axis(L)
    roar = S.lowpass(S.noise(L, "brown", gen), 180.0, 2)
    roar *= 0.55 + 0.45 * S.one_pole_lp(np.abs(S.one_pole_lp(gen.standard_normal(len(t)), 0.4)) * 30, 0.6)
    roar *= S.db_to_amp(-26.0) / (np.std(roar) + 1e-9)
    roar2 = S.lowpass(S.noise(L, "brown", gen), 260.0, 2)
    roar2 *= S.db_to_amp(-30.0) / (np.std(roar2) + 1e-9) * (0.6 + 0.4 * np.sin(S.TWO_PI * 0.03 * t + 1.0))
    fire = np.stack([roar + 0.5 * roar2, roar2 + 0.5 * roar], axis=1)
    pops = S.lowpass(S.vinyl_crackle(L, 12.0, -42.0, seed=2101, pops=True), 4000.0, 1)
    washi = S.to_stereo(pops, 0.7)
    heat = S.bandpass(S.noise(L, "pink", gen), 1500.0, 6000.0, 2) * (0.5 + 0.5 * np.sin(S.TWO_PI * 0.21 * t)) ** 3
    heat = S.to_stereo(heat * S.db_to_amp(-46.0) / (np.std(heat) + 1e-9), 0.5)
    events = np.zeros((S.samples(L), 2))
    bell = temple_bell(gen, 92.0, 12.0)
    for at in (9.0, 52.0):
        S.place(events, S.pan(S.reverb(bell, 4.0, 0.45, 0.05, 2500.0, seed=2102, tail=False), 0.2), at, S.db_to_amp(-20.0))
    for at in (24.0, 24.6, 25.4, 66.0, 66.7):
        S.place(events, S.pan(S.reverb(crow(gen), 1.8, 0.4, 0.02, 4000.0, seed=2103, tail=False), gen.uniform(-0.7, 0.7)), at, S.db_to_amp(-28.0 + gen.uniform(-3, 2)))
    for at in (4.0, 17.0, 31.0, 44.5, 60.0, 73.0):
        S.place(events, S.pan(banner_snap(gen), gen.uniform(-0.9, 0.9)), at, S.db_to_amp(-30.0 + gen.uniform(-4, 2)))
    bed = fire + washi + heat + events
    return _finish("amb_u1", bed, length_s, 4.0,
                   "Fire roar under silence, washi crackle, heat shimmer; the temple bell at 9 s and 52 s, crows, banners snapping.")


def build_transit(length_s: float = 64.0) -> dict:
    gen = S.rng(2200)
    L = length_s + 4.0
    t = S.t_axis(L)
    th = S.noise(L, "brown", gen)
    th = S.swept_bandpass(th, 120.0, 900.0, 1.5, 8192)
    th *= S.one_pole_lp(0.5 + 0.5 * np.sin(S.TWO_PI * 0.15 * t) * np.sin(S.TWO_PI * 0.043 * t + 2.0), 0.8)
    whistle = S.swept_bandpass(S.noise(L, "white", gen), 1400.0, 2600.0, 30.0, 4096) * (0.5 + 0.5 * np.sin(S.TWO_PI * 0.031 * t)) ** 4
    wind = np.stack([th + 0.3 * whistle, S.lowpass(S.noise(L, "brown", gen), 600.0, 2) * 0.7 + 0.5 * th + 0.3 * whistle], axis=1)
    wind *= S.db_to_amp(-26.0) / (np.sqrt(np.mean(wind ** 2)) + 1e-9)
    beats, tt = [], 0.2
    while tt < L:
        beats.append(tt)
        tt += 60.0 / (72.0 + 5.0 * np.sin(S.TWO_PI * 0.017 * tt))
    hb = C.heartbeat(beats, L, 72.0, seed=2201)
    hb = S.to_stereo(hb) * S.db_to_amp(-24.0) / (np.sqrt(np.mean(hb ** 2)) + 1e-9)
    # the fracture: a glassy crack far off every ~20 s
    events = np.zeros((S.samples(L), 2))
    for at in (11.0, 33.0, 51.0):
        cr = S.resample_speed(B.crack(gen, 0.9, 0.6), 0.6)
        S.place(events, S.pan(S.reverb(cr, 3.0, 0.6, 0.05, 3000.0, seed=2202, tail=False), gen.uniform(-0.6, 0.6)), at, S.db_to_amp(-30.0))
    bed = wind + hb + events
    return _finish("amb_transit", bed, length_s, 4.0, "Fracture wind with a thin whistle, the chest heartbeat at ~72 BPM, a far glass crack every ~20 s.")


def build_all() -> list[dict]:
    return [build_u0(), build_u1(), build_transit()]


if __name__ == "__main__":
    for r in build_all():
        print(f"{r['file']:20s} {r['duration_s']}s peak {r['peak_dbfs']} lufs {r['lufs_i']} {r['size_bytes'] // 1024} KB")
