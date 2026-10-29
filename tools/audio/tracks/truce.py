"""mus_u0_truce_1024 — Truce and the U0 field (§8.5). 78 BPM, 4/4, D Dorian.
Detuned shamisen (15 cents flat, wobbling), a warped 808 (2.2 s decay), the broken music box,
tape hiss as percussion; the World cell. Stems: lead, bass, box, drums, hiss."""
from __future__ import annotations

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402
from common import S, MB  # noqa: E402
from score import GM, DRUM_CH, DRUM_KIT, DR, n  # noqa: E402
from motifs import WORLD_CELL, TIME_CELL, world_cell  # noqa: E402

ID = "mus_u0_truce_1024"
CH_SHAM, CH_SHAM2 = 0, 1


def build() -> dict:
    tr = C.Track(ID, 78, 4, [("intro", 4), ("a", 8), ("bridge", 4), ("b", 8), ("coda", 4)], "D Dorian")
    sc = tr.score
    sc.program(CH_SHAM, GM["shamisen"]); sc.program(CH_SHAM2, GM["shamisen"])
    sc.program(DRUM_CH, DRUM_KIT["tr808"], 128)
    sc.pan(CH_SHAM, 56); sc.pan(CH_SHAM2, 72)
    L = tr.render_length_s()
    gen = S.rng(300)

    # the detune: 15 cents flat with a slow wobble (bend range ±2 semitones)
    for ch in (CH_SHAM, CH_SHAM2):
        for k in range(int(tr.total_bars * tr.beats_per_bar * 2)):
            b = k * 0.5
            sc.bend_cents(ch, -15.0 + 6.0 * np.sin(0.9 * b) + gen.uniform(-2, 2), b)

    prog_a = ["Dm", "Dm", "G", "Dm", "Dm", "F", "C", "Dm"]
    prog_br = ["Bm7b5", "Em", "G", "A"]
    prog_b = ["Dm", "Am", "G", "Dm", "F", "C", "G", "Dm"]
    prog_coda = ["Dm", "G", "C", "Dm"]
    roots = {"Dm": 38, "G": 43, "F": 41, "C": 36, "Am": 45, "Bm7b5": 47, "Em": 40, "A": 45}
    tones = {"Dm": [62, 65, 69], "G": [62, 67, 71], "F": [60, 65, 69], "C": [60, 64, 67], "Am": [60, 64, 69],
             "Bm7b5": [59, 62, 65], "Em": [59, 64, 67], "A": [57, 61, 64]}

    # ---- shamisen: the World cell as the lead, with answering plucks on chord tones ----
    def cell(bar_beat, vel, tp=0, q=1.0, hold=2.5):
        world_cell(sc, CH_SHAM, bar_beat, quaver=q, vel=vel, transpose=tp, hold=hold)

    def plucks(bar_beat, name, vel, pattern=(0.0, 1.5, 2.0, 3.0)):
        t = tones[name]
        for i, off in enumerate(pattern):
            sc.note(CH_SHAM2, t[i % len(t)] - 12 + (12 if i == 3 else 0), bar_beat + off, 0.6, vel - 6 * (i % 2))

    for i, name in enumerate(prog_a):
        if i % 2 == 0:
            cell(tr.bar("a", i), 74 + i, 0 if i < 4 else 5)
        plucks(tr.bar("a", i), name, 54 if i % 2 else 46)
    for i, name in enumerate(prog_br):
        plucks(tr.bar("bridge", i), name, 50, (0.0, 1.0, 2.0, 2.5))
    cell(tr.bar("bridge", 2), 72, 7, 1.0, 2.0)
    for i, name in enumerate(prog_b):
        if i % 2 == 0:
            cell(tr.bar("b", i), 80, [0, 5, 0, 12][i // 2], 1.0 if i != 6 else 0.5, 2.5 if i != 6 else 4.0)
        plucks(tr.bar("b", i), name, 58, (0.0, 0.5, 1.5, 2.0, 3.0, 3.5)[: 4 if i % 2 == 0 else 6])
    cell(tr.bar("coda", 0), 70, 0, 1.5, 3.0)
    plucks(tr.bar("coda", 2), "C", 46)
    plucks(tr.bar("coda", 3), "Dm", 42, (0.0, 2.0))

    # ---- drums: 808 snare on 2 and 4, claps in B, hiss bursts for hats ----
    hiss_ev = []
    for bar in range(tr.section_bar["a"], tr.total_bars):
        b0 = bar * 4
        soft = bar < tr.section_bar["a"] + 2 or bar >= tr.section_bar["coda"] + 2
        sc.note(DRUM_CH, DR["snare"], b0 + 1, 0.3, 58 if soft else 78)
        sc.note(DRUM_CH, DR["snare"], b0 + 3, 0.3, 54 if soft else 74)
        if tr.section_bar["b"] <= bar < tr.section_bar["coda"]:
            sc.note(DRUM_CH, DR["clap"], b0 + 3, 0.3, 60)
            sc.note(DRUM_CH, DR["rim"], b0 + 2.5, 0.2, 50)
        for e in range(8):
            v = 0.55 if e % 2 == 0 else 0.3
            if bar >= tr.section_bar["bridge"] and bar < tr.section_bar["b"]:
                v *= 0.6
            hiss_ev.append((tr.s(b0 + e * 0.5), v * (0.8 if soft else 1.0)))

    # ---- bass: the warped 808 on the roots; kick doubles it (side-chain to Crono's breath at runtime) ----
    bass_ev = []
    for sec, prog in (("a", prog_a), ("bridge", prog_br), ("b", prog_b), ("coda", prog_coda)):
        for i, name in enumerate(prog):
            b0 = tr.bar(sec, i)
            r = roots[name] - 12
            bass_ev.append((tr.s(b0), r, 1.0))
            if sec in ("b", "a") and i % 2 == 1:
                bass_ev.append((tr.s(b0 + 2.5), r, 0.7))
            if sec == "b":
                bass_ev.append((tr.s(b0 + 3.5), r + 7 if i % 2 == 0 else r, 0.5))
    # the intro: a single 808 on D, then the box answers
    bass_ev.insert(0, (tr.s(tr.bar("intro", 0)), 26, 0.9))
    bass_ev.insert(1, (tr.s(tr.bar("intro", 2)), 26, 0.7))

    # ---- the broken box: the Time cell at pitch (all notes live in D Dorian), every 4 bars ----
    box_ev = []
    bars_for_box = [tr.section_bar["intro"] + 1, tr.section_bar["a"] + 2, tr.section_bar["a"] + 6, tr.section_bar["bridge"] + 1,
                    tr.section_bar["b"] + 2, tr.section_bar["b"] + 6, tr.section_bar["coda"]]
    for k, bar in enumerate(bars_for_box):
        for i, p in enumerate(TIME_CELL):
            box_ev.append((tr.s(bar * 4 + i * 0.5), p, 0.7 if k % 2 == 0 else 0.6))
    # "each crack removes a tine": the box here is already missing a tine or two
    tines = MB.render_notes(box_ev, L, missing={n("B4")}, skip_every=0, seed=301, wobble_cents=5.0)
    stems = {}
    stems["box"] = C.box_post(tines, 1.6, 0.25)

    midi = tr.midi_stems({"lead": [CH_SHAM, CH_SHAM2], "drums": [DRUM_CH]}, gain=0.6)
    lead = S.reverb(S.lowpass(midi["lead"], 7000.0, 1), 1.5, 0.2, 0.01, 4500.0, seed=302)
    stems["lead"] = S.wow_flutter(lead, 6.0, 0.4, 2.0, 5.5, seed=303)
    drums = midi["drums"] * 1.0
    drums = S.saturate(drums * 1.4, 1.5)
    hats = C.hiss_hats(hiss_ev, L, seed=304)
    stems["drums"] = S.mix(S.reverb(drums, 0.8, 0.12, 0.005, 3000.0, seed=305), S.to_stereo(hats, 0.5))
    bass = C.sub_808(bass_ev, L, 2.2, 18.0, seed=306)
    stems["bass"] = S.to_stereo(bass)
    stems["hiss"] = S.tape_hiss(L, -46.0, seed=307) + S.to_stereo(S.vinyl_crackle(L, 8.0, -50.0, seed=308), 0.5)

    C.balance(stems, {"lead": -24.0, "bass": -26.0, "box": -29.0, "drums": -27.0, "hiss": -44.0},
              ceilings={"lead": -9.0, "drums": -10.0})
    tr.rtpc = {"crono_hp": "100% → full mix; towards 20% fade lead and drums to leave bass + box (the hollow marrow pulse)",
               "breath": "side-chain the bass stem to Crono's idle breath (duck 3 dB on each exhale)",
               "porcelain_stress": "swap in a box stem with more missing tines (not rendered: use wind_scene box_debt60/20 as the model)"}
    tr.notes = "Shamisen bent 15 cents flat with a slow wobble; 808 decays 2.2 s; the box is already missing its B4 tine."
    return tr.finalize(stems, hiss_stem="hiss", hiss_db=-62.0)


if __name__ == "__main__":
    r = build()
    print(r["id"], r["duration_s"], "s; loop from", r["loop_start_s"], "s; mix", r["mix"])
    for k, v in r["stems"].items():
        print(f"  {k:10s} {v['file']:36s} peak {v['peak_dbfs']:6.1f} lufs {v['lufs_i']}")
