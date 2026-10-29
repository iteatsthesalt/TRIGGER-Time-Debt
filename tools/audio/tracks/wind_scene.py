"""mus_u0_wind_scene_1024 — the Atrium hub (§8.5). 72 BPM, 3/4, C major.

Stems: box (the Time cell on the tine synth), piano (felt, Crono's cell in the bridge), wind,
tick (the escapement with the missing tooth and the mainspring grind every 4 bars), and
debt (default off: the detuned escapement and reverse-reverb chirps for porcelain_stress > 60).
Box integrity variants: box_debt60 (no C4 tine), box_debt20 (no C4, every third note gone),
box_debt0 (the box starts, then the tape stops).
"""
from __future__ import annotations

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402
from common import S, MB  # noqa: E402
from score import GM, n, chord_notes  # noqa: E402
from motifs import TIME_CELL, crono_cell  # noqa: E402

ID = "mus_u0_wind_scene_1024"
CH_PIANO, CH_BOX_GM = 0, 1
VEL_SHAPE = [1.0, 0.85, 0.9, 0.8, 0.95, 0.85, 0.8, 0.9]


def box_events(tr: C.Track) -> list[tuple[float, int, float]]:
    """(time_s, midi, vel) for the tine synth. A 2-bar phrase = 8 quavers of cell + 4 of rest."""
    ev = []

    def phrase(bar: float, count: int = 8, vel: float = 0.8, extra_high: bool = False):
        start = bar * tr.beats_per_bar
        for i in range(count):
            ev.append((tr.s(start + i * 0.5), TIME_CELL[i], vel * VEL_SHAPE[i]))
        if extra_high:
            ev.append((tr.s(start + 3.5), n("C6"), vel * 0.35))

    a0 = tr.section_bar["a"]
    for k in range(6):
        phrase(a0 + 2 * k, 8, 0.78 + 0.02 * k)
    b0 = tr.section_bar["bridge"]
    phrase(b0, 4, 0.7)
    phrase(b0 + 4, 4, 0.62)
    bb = tr.section_bar["b"]
    for k in range(6):
        phrase(bb + 2 * k, 8, 0.84, extra_high=(k == 5))
    c0 = tr.section_bar["coda"]
    phrase(c0, 8, 0.66)
    phrase(c0 + 2, 8, 0.56)
    phrase(c0 + 4, 6, 0.48)
    return ev


def build() -> dict:
    tr = C.Track(ID, 72, 3, [("intro", 4), ("a", 12), ("bridge", 8), ("b", 12), ("coda", 8)], "C major")
    sc = tr.score
    sc.program(CH_PIANO, GM["piano"])
    sc.program(CH_BOX_GM, GM["celesta"])
    L = tr.render_length_s()
    ev = box_events(tr)

    # ---- piano: bass notes and soft chords in A, Crono's tired cell in the bridge, a waltz in B ----
    a_chords = ["C", "Am", "F", "G", "C", "Em", "F", "G", "Am", "F", "Dm", "G"]
    b_chords = ["C", "G/B", "Am", "Em", "F", "C/E", "Dm", "G", "Am", "F", "Fm", "G"]
    roots = {"C": 48, "Am": 45, "F": 41, "G": 43, "Em": 40, "Dm": 38, "Fm": 41, "G/B": 47, "C/E": 40}
    voicings = {"C": [60, 64, 67], "Am": [57, 60, 64], "F": [57, 60, 65], "G": [59, 62, 67], "Em": [59, 64, 67],
                "Dm": [57, 62, 65], "Fm": [56, 60, 65], "G/B": [59, 62, 67], "C/E": [60, 64, 67]}
    for i, ch in enumerate(a_chords):
        b = tr.bar("a", i)
        sc.note(CH_PIANO, roots[ch] - 12, b, 3.0, 50 if i % 2 == 0 else 44)
        if i % 2 == 1:
            sc.chord(CH_PIANO, voicings[ch], b + 1.0, 1.9, 40, strum=0.03)
    for k, chname in enumerate(["Am", "F", "C", "G"]):
        b = tr.bar("bridge", 2 * k)
        sc.note(CH_PIANO, roots[chname] - 12, b, 5.8, 48)
        sc.note(CH_PIANO, roots[chname] - 5, b, 5.8, 38)
        if k % 2 == 0:
            crono_cell(sc, CH_PIANO, b, quaver=1.0, vel=58, transpose=12)
    for i, ch in enumerate(b_chords):
        b = tr.bar("b", i)
        sc.note(CH_PIANO, roots[ch] - 12, b, 2.9, 52)
        sc.chord(CH_PIANO, voicings[ch], b + 1.0, 0.9, 42, strum=0.02)
        sc.chord(CH_PIANO, voicings[ch], b + 2.0, 0.9, 36, strum=0.02)
    crono_cell(sc, CH_PIANO, tr.bar("b", 8), quaver=1.0, vel=54, transpose=12)
    for k, chname in enumerate(["C", "Am", "F", "G"]):
        sc.note(CH_PIANO, roots[chname] - 12, tr.bar("coda", 2 * k), 5.5, 46 - 4 * k)

    # ---- the GM celesta doubles the tines very quietly (same note list and the same omissions) ----
    def gm_box(missing=(), skip_every=0, stop_at_s=None):
        sc2 = C.Score(tr.bpm, tr.beats_per_bar)
        sc2.program(CH_BOX_GM, GM["celesta"])
        for i, (t0, midi, vel) in enumerate(ev):
            if midi in missing or (skip_every and i % skip_every == skip_every - 1):
                continue
            if stop_at_s is not None and t0 > stop_at_s:
                continue
            sc2.note(CH_BOX_GM, midi + 12, sc2.s_to_beats(t0), 1.2, int(30 + 50 * vel))
        return C.render_stems(sc2, {"gm": [CH_BOX_GM]}, tr.total_s, C.TAIL_S, gain=0.5)["gm"]

    def box_variant(missing=(), skip_every=0, stop_at_s=None, seed=100):
        tines = MB.render_notes(ev, L, missing, skip_every, seed=seed)
        gm = gm_box(missing, skip_every, stop_at_s)
        x = S.mix(C.box_post(tines), gm * S.db_to_amp(-16.0))
        if stop_at_s is not None:
            x = S.tape_stop(x, stop_at_s, 0.4)
        return x

    stems = {}
    stems["box"] = box_variant()
    stems["box_debt60"] = box_variant(missing={n("C4")})
    stems["box_debt20"] = box_variant(missing={n("C4")}, skip_every=3)
    stems["box_debt0"] = box_variant(missing={n("C4")}, skip_every=3, stop_at_s=tr.s(tr.bar("a", 2)) + 0.2)

    midi = tr.midi_stems({"piano": [CH_PIANO]}, gain=0.6)
    stems["piano"] = C.felt_piano(midi["piano"], 2100.0, 1.6, 0.2)

    # ---- tick: 12 quavers per 2-bar phrase, the 8th one a silent click; grind every 4 bars ----
    q = tr.s(0.5)
    n_ticks = int(L / q) + 1
    times = [k * q for k in range(n_ticks)]
    silent = {k for k in range(n_ticks) if k % 12 == 7}
    grinds = [tr.s(tr.bar("a", 4 * g)) for g in range(int((tr.total_bars - tr.section_bar["a"]) / 4) + 1)]
    tick = MB.render_ticks(times, L, 0, grinds, vel=0.5, seed=101, silent_positions=silent, grind_gain=0.55)
    stems["tick"] = S.reverb(S.to_stereo(tick, 0.2), 1.4, 0.18, 0.006, 5000.0, seed=17)

    # ---- wind through the Horologe, seamless across the loop seam ----
    wind = C.wind_bed(L, seed=131)
    stems["wind"] = seamless_region(wind, S.samples(tr.loop_start_s), S.samples(tr.loop_end_s), 2.0)

    # ---- debt layer (default off): detuned escapement, reverse-reverb chirps, a sub wobble ----
    gen = S.rng(777)
    debt = np.zeros(S.samples(L))
    for k, t0 in enumerate(times):
        if gen.uniform() < 0.72:
            tk = S.pitch_shift(MB.tick(gen, 0.5), -5.0 - gen.uniform(0, 2.5))
            S.place(debt, tk, t0 + gen.uniform(-0.06, 0.06))
    chirps = np.zeros(S.samples(L))
    for g in grinds:
        t = S.t_axis(0.09)
        ch = np.sin(S.TWO_PI * np.cumsum(np.linspace(1800.0, 2600.0, len(t))) / S.SR) * S.exp_decay(0.09, 30.0)
        S.place(chirps, ch, g + tr.s(1.0), 0.5)
    chirps = S.reverse_reverb(chirps, 1.6, 0.75, seed=12)
    sub = np.sin(S.TWO_PI * 36.0 * S.t_axis(L)) * (0.5 + 0.5 * np.sin(S.TWO_PI * 0.5 * S.t_axis(L))) * 0.25
    debt_st = S.to_stereo(debt, 0.4) + S.fit_length(chirps, S.samples(L)) * 0.8 + S.to_stereo(sub)
    stems["debt"] = debt_st
    tr.default_off = {"debt", "box_debt60", "box_debt20", "box_debt0"}

    # ---- relative levels (gated LUFS before the mix normalisation) ----
    C.balance(stems, {"box": -24.0, "box_debt60": -24.0, "box_debt20": -24.0, "box_debt0": -24.0, "piano": -26.5,
                      "wind": -37.0, "tick": -36.0, "debt": -33.0})

    tr.rtpc = {
        "porcelain_stress": "swap the box stem: >60 → box, 21–60 → box_debt60, 1–20 → box_debt20, 0 → box_debt0 (the tape stops at 15.2 s); above 60 also fade in the debt stem",
        "glow_intensity": "box and tick stem volume: 0 → −12 dB, 100 → +2 dB with saturation",
        "camera_fov": "music bus low-pass 400 Hz (32°) → 800 Hz (24°)",
        "gate_proximity": "not rendered: layer sfx/status/vhs_fog (U2 gramophone hiss) or a CRT hum near gates",
        "vaelos_near": "layer mus_vaelos_theme__pad (68 BPM heartbeat) under this track",
    }
    tr.notes = ("Tick: 12 quavers per 2-bar phrase, the 8th is a silent click (the missing tooth) so the C4 "
                "lands without its tick; mainspring grind every 4 bars from the loop start. Loop region = A+Bridge+B+Coda.")
    return tr.finalize(stems, hiss_stem="wind")


def seamless_region(x: np.ndarray, a: int, b: int, xf_s: float) -> np.ndarray:
    """Cross-fade the end of [a, b) into its start so a noise bed loops without a click."""
    k = S.samples(xf_s)
    y = x[:b].copy()
    w = np.linspace(0, 1, k)
    if y.ndim == 2:
        w = w[:, None]
    y[a: a + k] = y[a: a + k] * w + y[b - k: b] * (1 - w)
    return y


if __name__ == "__main__":
    r = build()
    print(r["id"], r["duration_s"], "s; loop from", r["loop_start_s"], "s; mix", r["mix"])
    for k, v in r["stems"].items():
        print(f"  {k:12s} {v['file']:40s} {v['duration_s']:7.2f}s peak {v['peak_dbfs']:6.1f} lufs {v['lufs_i']} on={v['default_on']}")
