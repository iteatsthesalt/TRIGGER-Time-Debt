"""mus_transit_chronoslip and mus_stings (§8.5).

Transit: no music. Brown-noise thermals, Sera's heartbeat as a chest rumble, a rubber-hose
Doppler whoosh now and then. A 64 s seamless loop; the wind and the rumble are the navigation.

Stings (one-shots, not looped):
  mus_stings_victory  — the Time cell resolving on the box, a felt-piano C major under it
  mus_stings_defeat   — the box starts, the tape stops, a porcelain crack as the Debt advances
  mus_stings_overcap  — a VHS whine, never a fanfare
"""
from __future__ import annotations

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402
from common import S, MB  # noqa: E402
from score import GM, n  # noqa: E402
from motifs import TIME_CELL  # noqa: E402

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "sfx"))


def doppler_whoosh(dur: float, gen: np.random.Generator) -> np.ndarray:
    """A rubber-hose whoosh passing left to right: band-passed noise whose centre falls as it passes."""
    t = S.t_axis(dur)
    x = S.noise(dur, "white", gen)
    y = S.swept_bandpass(x, 1800.0, 500.0, 6.0, 512) * S.swell(dur, 0.45, 1.6)
    pitch = 2.0 ** (np.linspace(3.0, -4.0, len(t)) / 12.0)  # the Doppler fall
    y = S.fit_length(S.resample_speed(y, pitch), len(t))
    pan_pos = np.linspace(-0.9, 0.9, len(t))
    left = y * np.cos((pan_pos + 1) * 0.25 * np.pi)
    right = y * np.sin((pan_pos + 1) * 0.25 * np.pi)
    return S.normalize_peak(np.stack([left, right], axis=1), -10.0)


def build_transit() -> dict:
    length = 64.0
    gen = S.rng(900)
    L = length + 4.0
    t = S.t_axis(L)
    # thermals: brown noise with slow swells and a filter that breathes between 120 and 900 Hz
    th = S.noise(L, "brown", gen)
    th = S.swept_bandpass(th, 150.0, 700.0, 1.2, 8192) + S.lowpass(th, 300.0, 2) * 0.6
    swells = 0.45 + 0.55 * (0.5 + 0.5 * np.sin(S.TWO_PI * 0.19 * t + 1.0)) * (0.5 + 0.5 * np.sin(S.TWO_PI * 0.071 * t))
    th = th * S.one_pole_lp(swells, 0.8)
    th2 = S.lowpass(S.noise(L, "brown", gen), 500.0, 2) * S.one_pole_lp(0.5 + 0.5 * np.sin(S.TWO_PI * 0.13 * t + 2.5), 0.8)
    thermals = np.stack([th + 0.5 * th2, th2 + 0.5 * th], axis=1)
    thermals *= S.db_to_amp(-24.0) / (np.sqrt(np.mean(thermals ** 2)) + 1e-9)
    # heartbeat ~ 76 BPM drifting (Sera's), low-passed into the chest
    beats = []
    tt = 0.3
    while tt < L:
        beats.append(tt)
        tt += 60.0 / (76.0 + 6.0 * np.sin(S.TWO_PI * 0.02 * tt))
    hb = C.heartbeat(beats, L, 76.0, seed=901)
    hb = S.to_stereo(hb) * (S.db_to_amp(-18.0) / (np.sqrt(np.mean(hb ** 2)) + 1e-9)) * 0.5
    # whooshes every 11–16 s
    wh = np.zeros((S.samples(L), 2))
    tw = 4.0
    while tw < length - 3.0:
        S.place(wh, doppler_whoosh(gen.uniform(1.2, 2.2), gen), tw, gen.uniform(0.5, 0.9))
        tw += gen.uniform(11.0, 16.0)
    bed = thermals + hb + wh * S.db_to_amp(-6.0)
    bed = S.crossfade_loop(bed, 4.0)[: S.samples(length)]
    bed = bed + S.tape_hiss(length, -58.0, seed=902)
    y, g = S.normalize_lufs(bed, -23.0, -1.0)
    path = os.path.join(C.MUSIC_DIR, "mus_transit_chronoslip.ogg")
    S.write_ogg(path, y, 6)
    side = {"id": "mus_transit_chronoslip", "bpm": 0, "meter": [0, 0], "key": "none", "bars": 0, "duration_s": length,
            "loop_start_s": 0.0, "loop_start_samples": 0, "loop_end_s": length, "sections": [],
            "stems": {"mix": {"file": os.path.basename(path), "default_on": True, **S.measure(y), "size_bytes": os.path.getsize(path)}},
            "mix": S.measure(y),
            "rtpc": {"heartbeat": "pitch_scale the whole bed with the heartbeat RTPC (72 → 1.0, 144 → 1.4) or layer sfx/time/chronoslip",
                     "camera_fov": "a slip widens the FOV and muffles everything except this heartbeat: music bus low-pass 400 Hz"},
            "notes": "No music: brown-noise thermals, a 76 BPM chest heartbeat, a rubber-hose Doppler whoosh every 11–16 s. Seamless 64 s loop at −23 LUFS.",
            "godot_import": {"loop": True, "loop_offset": 0.0, "bpm": 0, "beat_count": 0, "bar_beats": 4}}
    S.write_json(os.path.join(C.MUSIC_DIR, "mus_transit_chronoslip.json"), side)
    return side


def _write_sting(name: str, x: np.ndarray, notes: str) -> dict:
    x = S.to_stereo(x) if x.ndim == 1 else x
    x = x + S.tape_hiss(len(x) / S.SR, -60.0, seed=S.stable_seed(name))
    y, _ = S.normalize_lufs(x, -18.0, -1.0)  # stings sit 2 dB above the music they interrupt
    path = os.path.join(C.MUSIC_DIR, f"{name}.ogg")
    S.write_ogg(path, y, 6)
    side = {"id": name, "bpm": 72, "meter": [4, 4], "key": "C major", "bars": 0, "duration_s": round(len(y) / S.SR, 3),
            "loop_start_s": 0.0, "loop_start_samples": 0, "loop_end_s": round(len(y) / S.SR, 3), "sections": [],
            "stems": {"mix": {"file": os.path.basename(path), "default_on": True, **S.measure(y), "size_bytes": os.path.getsize(path)}},
            "mix": S.measure(y), "rtpc": {}, "notes": notes,
            "godot_import": {"loop": False, "loop_offset": 0.0, "bpm": 72, "beat_count": 0, "bar_beats": 4}}
    S.write_json(os.path.join(C.MUSIC_DIR, f"{name}.json"), side)
    return side


def build_stings() -> list[dict]:
    out = []
    q = 60.0 / 72.0 / 2.0
    # ---- victory: the Time cell comes home, with a felt piano C major and a glockenspiel shimmer ----
    ev = [(0.3 + i * q, p, 0.85 if i % 2 == 0 else 0.75) for i, p in enumerate(TIME_CELL)]
    ev.append((0.3 + 8 * q, n("C5"), 0.6)); ev.append((0.3 + 8 * q, n("E5"), 0.5)); ev.append((0.3 + 8 * q, n("G5"), 0.45))
    ev.append((0.3 + 8 * q + 0.08, n("C6"), 0.4))
    box = C.box_post(MB.render_notes(ev, 6.5, seed=950), 2.4, 0.3)
    sc = C.Score(72, 4)
    sc.program(0, GM["piano"]); sc.program(1, GM["glockenspiel"])
    sc.chord(0, [n("C2"), n("G2"), n("E3"), n("G3"), n("C4")], sc.s_to_beats(0.3 + 7 * q), 4.0, 62, strum=0.05)
    sc.note(0, n("G1"), sc.s_to_beats(0.3 + 3 * q), 2.0, 52)
    sc.note(1, n("G6"), sc.s_to_beats(0.3 + 8 * q + 0.2), 2.0, 40)
    sc.note(1, n("E6"), sc.s_to_beats(0.3 + 8 * q + 0.45), 2.0, 34)
    mid = C.render_stems(sc, {"p": [0, 1]}, 2.5, 4.0, gain=0.6)["p"]
    piano = C.felt_piano(mid, 2600.0, 2.2, 0.26)
    victory = S.mix(box, piano * S.db_to_amp(-3.0))
    victory = S.fade(victory[: S.samples(6.0)], 0.0, 1.2)
    out.append(_write_sting("mus_stings_victory", victory, "The Time cell resolving onto C major with whatever tines remain (render variants with missing tines by the same generator)."))

    # ---- defeat: the box starts, the tape stops at 1.1 s, a porcelain crack, room tone ----
    ev = [(0.2 + i * q, p, 0.8) for i, p in enumerate(TIME_CELL[:5])]
    box = C.box_post(MB.render_notes(ev, 4.0, seed=951), 1.5, 0.2)
    box = S.tape_stop(box, 1.15, 0.4)
    gen = S.rng(952)
    crack = S.swept_bandpass(gen.standard_normal(S.samples(0.35)) * S.exp_decay(0.35, 14.0, 0.001), 5200.0, 700.0, 10.0, 128)
    crack = S.normalize_peak(crack, -4.0)
    shards = np.zeros(S.samples(1.2))
    for k in range(9):
        tk = C.porcelain_ting(3800.0 + 500 * gen.uniform(), 0.08, seed=960 + k, vel=0.4 * (1 - k / 10))
        S.place(shards, tk, 0.05 + k * 0.07 + gen.uniform(0, 0.03))
    defeat = S.mix(box, np.zeros((S.samples(4.0), 2)))
    defeat = S.place(defeat, S.reverb(crack, 1.8, 0.3, 0.0, 5000.0, seed=953), 1.55, 0.9)
    defeat = S.place(defeat, S.reverb(shards, 1.6, 0.4, 0.0, 6000.0, seed=954), 1.62, 0.7)
    defeat = S.fade(defeat[: S.samples(4.0)], 0.0, 0.8)
    out.append(_write_sting("mus_stings_defeat", defeat, "Tape stop over 0.4 s at 1.15 s, then a porcelain crack and shards as the Debt advances."))

    # ---- overcap: a VHS whine — a thin tone climbing 2.4 → 3.1 kHz with flutter, tracking hiss, a snap ----
    dur = 1.6
    t = S.t_axis(dur)
    f = np.linspace(2400.0, 3100.0, len(t)) * (1 + 0.004 * np.sin(S.TWO_PI * 7.3 * t))
    whine = np.sin(S.TWO_PI * np.cumsum(f) / S.SR) * S.swell(dur, 0.7, 1.2) * 0.5
    whine += np.sin(S.TWO_PI * np.cumsum(f * 0.5) / S.SR) * S.swell(dur, 0.7, 1.2) * 0.2
    hiss = S.highpass(S.noise(dur, "pink", S.rng(955)), 2500.0, 2) * S.swell(dur, 0.6, 1.0) * 0.3
    snap = S.lowpass(S.noise(0.06, "white", S.rng(956)), 3000.0, 2) * S.exp_decay(0.06, 70.0, 0.0005)
    over = S.wow_flutter(whine + hiss, 30.0, 1.2, 12.0, 9.0, seed=957)
    over = S.to_stereo(over, 0.5)
    over = S.place(over, snap, dur - 0.2, 0.8)
    over = S.fade(over, 0.0, 0.15)
    out.append(_write_sting("mus_stings_overcap", over, "A VHS whine (2.4 → 3.1 kHz with flutter) and a tracking snap. Never a fanfare."))
    return out


if __name__ == "__main__":
    r = build_transit()
    print(r["id"], r["duration_s"], r["mix"])
    for r in build_stings():
        print(r["id"], r["duration_s"], r["mix"])
