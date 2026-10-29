"""mus_title — the title screen (§8.5). 72 BPM, 3/4, C major, through-composed 2:00 then loops
on the box alone. Stems: box, piano, strings, hiss (+ box_debt60 / box_debt20 for a loaded save
whose tines are already gone)."""
from __future__ import annotations

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402
from common import S, MB  # noqa: E402
from score import GM, n  # noqa: E402
from motifs import TIME_CELL, crono_cell  # noqa: E402
from wind_scene import VEL_SHAPE  # noqa: E402

ID = "mus_title"
CH_PIANO, CH_VLN, CH_VLA, CH_VC, CH_GM_BOX = 0, 1, 2, 3, 4


def build() -> dict:
    tr = C.Track(ID, 72, 3, [("intro", 4), ("a", 12), ("bridge", 8), ("b", 16), ("coda", 8)], "C major", loop_from="coda")
    sc = tr.score
    sc.program(CH_PIANO, GM["piano"])
    sc.program(CH_VLN, GM["violin"])
    sc.program(CH_VLA, GM["viola"])
    sc.program(CH_VC, GM["cello"])
    sc.program(CH_GM_BOX, GM["music_box"])
    sc.pan(CH_VLN, 44); sc.pan(CH_VLA, 84); sc.pan(CH_VC, 60)
    L = tr.render_length_s()

    # ---- the box: a 2-bar phrase (cell + 2 beats rest), present everywhere except the bridge's second half ----
    ev: list[tuple[float, int, float]] = []

    def phrase(bar, count=8, vel=0.8, high=False):
        start = bar * tr.beats_per_bar
        for i in range(count):
            ev.append((tr.s(start + i * 0.5), TIME_CELL[i], vel * VEL_SHAPE[i]))
        if high:
            ev.append((tr.s(start + 3.5), n("C6"), vel * 0.3))

    for k in range(2):
        phrase(tr.section_bar["intro"] + 2 * k, 8, 0.6 + 0.08 * k)
    for k in range(6):
        phrase(tr.section_bar["a"] + 2 * k, 8, 0.76 + 0.02 * k)
    phrase(tr.section_bar["bridge"], 4, 0.7)
    phrase(tr.section_bar["bridge"] + 4, 4, 0.6)
    for k in range(8):
        phrase(tr.section_bar["b"] + 2 * k, 8, 0.86, high=(k in (3, 7)))
    for k in range(4):
        phrase(tr.section_bar["coda"] + 2 * k, 8, 0.68)

    # ---- piano: waltz in A and B, sustained dyads under the cello in the bridge ----
    roots = {"C": 48, "Am": 45, "F": 41, "G": 43, "Em": 40, "Dm": 38, "Fm": 41, "G/B": 47, "C/E": 40, "G7": 43}
    voicings = {"C": [60, 64, 67], "Am": [57, 60, 64], "F": [57, 60, 65], "G": [59, 62, 67], "Em": [59, 64, 67],
                "Dm": [57, 62, 65], "Fm": [56, 60, 65], "G/B": [59, 62, 67], "C/E": [60, 64, 67], "G7": [59, 62, 65]}
    a_chords = ["C", "Am", "F", "G", "C", "Em", "F", "G7", "Am", "F", "Dm", "G"]
    b_chords = ["C", "G/B", "Am", "Em", "F", "C/E", "Dm", "G", "C", "G/B", "Am", "Em", "F", "Fm", "C", "G7"]
    for i, ch in enumerate(a_chords):
        b = tr.bar("a", i)
        sc.note(CH_PIANO, roots[ch] - 12, b, 2.9, 54)
        sc.chord(CH_PIANO, voicings[ch], b + 1.0, 0.9, 42, strum=0.025)
        sc.chord(CH_PIANO, voicings[ch], b + 2.0, 0.9, 38, strum=0.025)
    for k, chname in enumerate(["Am", "F", "C", "G"]):
        b = tr.bar("bridge", 2 * k)
        sc.note(CH_PIANO, roots[chname] - 12, b, 5.8, 50)
        sc.note(CH_PIANO, roots[chname] - 5, b, 5.8, 40)
        sc.chord(CH_PIANO, voicings[chname], b + 3.0, 2.8, 36, strum=0.03)
    for i, ch in enumerate(b_chords):
        b = tr.bar("b", i)
        sc.note(CH_PIANO, roots[ch] - 12, b, 2.9, 58)
        sc.note(CH_PIANO, roots[ch] - 24 if roots[ch] - 24 > 28 else roots[ch] - 12, b, 2.9, 40)
        sc.chord(CH_PIANO, voicings[ch], b + 1.0, 0.9, 46, strum=0.02)
        sc.chord(CH_PIANO, voicings[ch], b + 2.0, 0.9, 40, strum=0.02)
    crono_cell(sc, CH_PIANO, tr.bar("b", 8), quaver=1.0, vel=60, transpose=12)
    # a last C major that rings into the box-only coda (the coda is the loop; the piano stays out of it)
    sc.chord(CH_PIANO, [36, 48, 55, 64, 67], tr.bar("b", 15) + 2.0, 1.0, 50, strum=0.04)

    # ---- quartet: the cello carries Crono's cell in the bridge; B adds long lines ----
    for k in range(2):
        b = tr.bar("bridge", 4 * k)
        crono_cell(sc, CH_VC, b, quaver=1.0, vel=70, transpose=0)
        sc.note(CH_VLA, 57 if k == 0 else 60, b + 6.0, 5.8, 46)
        sc.note(CH_VLN, 64 if k == 0 else 67, b + 6.0, 5.8, 44)
    b_lines = [(72, 76), (71, 74), (69, 72), (67, 71), (69, 72), (67, 72), (65, 69), (67, 71),
               (72, 76), (71, 74), (69, 72), (67, 71), (69, 72), (68, 72), (67, 72), (67, 71)]
    for i, (vln, vla) in enumerate(b_lines):
        b = tr.bar("b", i)
        swell_v = 50 + int(12 * np.sin(np.pi * i / 16))
        sc.note(CH_VLN, vln, b, 2.9, swell_v)
        sc.note(CH_VLA, vla - 12, b, 2.9, swell_v - 8)
        sc.note(CH_VC, roots[b_chords[i]] - 12, b, 2.9, swell_v - 4)
    # the Time cell augmented on the violin across the last four bars of B (each note a beat)
    for i, p in enumerate(TIME_CELL):
        sc.note(CH_VLN, p + 12, tr.bar("b", 12) + i * 1.0, 1.0, 62)
    for i in range(16):  # strings fade through B's second half → silent in the coda
        sc.expression(CH_VLN, 127 - int(70 * max(0, i - 8) / 8), tr.bar("b", i))
        sc.expression(CH_VLA, 127 - int(70 * max(0, i - 8) / 8), tr.bar("b", i))
        sc.expression(CH_VC, 127 - int(70 * max(0, i - 8) / 8), tr.bar("b", i))

    # ---- GM music box doubling under the tines, same omissions per variant ----
    def gm_box(missing=(), skip_every=0):
        sc2 = C.Score(tr.bpm, tr.beats_per_bar)
        sc2.program(CH_GM_BOX, GM["music_box"])
        for i, (t0, midi, vel) in enumerate(ev):
            if midi in missing or (skip_every and i % skip_every == skip_every - 1):
                continue
            sc2.note(CH_GM_BOX, midi + 12, sc2.s_to_beats(t0), 1.0, int(28 + 50 * vel))
        return C.render_stems(sc2, {"gm": [CH_GM_BOX]}, tr.total_s, C.TAIL_S, gain=0.5)["gm"]

    def box_variant(missing=(), skip_every=0, seed=100):
        tines = MB.render_notes(ev, L, missing, skip_every, seed=seed)
        return S.mix(C.box_post(tines, 2.0, 0.24), gm_box(missing, skip_every) * S.db_to_amp(-15.0))

    stems = {"box": box_variant(), "box_debt60": box_variant(missing={n("C4")}),
             "box_debt20": box_variant(missing={n("C4")}, skip_every=3)}
    midi = tr.midi_stems({"piano": [CH_PIANO], "strings": [CH_VLN, CH_VLA, CH_VC]}, gain=0.6)
    stems["piano"] = C.felt_piano(midi["piano"], 2300.0, 1.8, 0.2)
    stems["strings"] = C.quartet(midi["strings"], 2.6, 0.3, crackle_db=-44.0)

    # ---- hiss stem: tape hiss as a soft percussion (the escapement at −30 dB) and room tone ----
    q = tr.s(0.5)
    n_ticks = int(L / q) + 1
    times = [k * q for k in range(n_ticks)]
    silent = {k for k in range(n_ticks) if k % 12 == 7}
    tick = MB.render_ticks(times, L, 0, (), vel=0.4, seed=102, silent_positions=silent)
    hiss = S.to_stereo(S.room_tone(L, -54.0, 24)) + S.tape_hiss(L, -52.0, seed=25) + S.to_stereo(tick, 0.2) * S.db_to_amp(-22.0)
    stems["hiss"] = hiss
    tr.default_off = {"box_debt60", "box_debt20"}

    levels = {"box": -24.0, "box_debt60": -24.0, "box_debt20": -24.0, "piano": -25.0, "strings": -26.0, "hiss": -44.0}
    for k, v in levels.items():
        stems[k] = C.set_lufs(stems[k], v)
    tr.rtpc = {"save_loaded": "replace box with box_debt60 / box_debt20 according to the save's porcelain integrity",
               "glow_intensity": "box stem volume −12 dB … +2 dB"}
    tr.notes = "Through-composed 100 s, then the loop region is the coda: box alone over hiss. Loop lands on bar 40."
    return tr.finalize(stems, hiss_stem="hiss", hiss_db=-62.0)


if __name__ == "__main__":
    r = build()
    print(r["id"], r["duration_s"], "s; loop from", r["loop_start_s"], "s; mix", r["mix"])
    for k, v in r["stems"].items():
        print(f"  {k:12s} {v['file']:36s} peak {v['peak_dbfs']:6.1f} lufs {v['lufs_i']} on={v['default_on']}")
