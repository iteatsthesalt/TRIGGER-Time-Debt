"""mus_u0_guardia_morning — the Prologue kitchen (§8.5). 72 BPM, 4/4, F major.
Quartet with vinyl crackle, felt piano, the World cell. Stems: quartet, piano, crackle
(the crackle stem also carries the house clock, ticking once a beat)."""
from __future__ import annotations

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402
from common import S, MB  # noqa: E402
from score import GM, n  # noqa: E402
from motifs import world_cell  # noqa: E402

ID = "mus_u0_guardia_morning"
CH_PIANO, CH_VLN, CH_VLA, CH_VC = 0, 1, 2, 3


def build() -> dict:
    tr = C.Track(ID, 72, 4, [("intro", 2), ("a", 8), ("bridge", 4), ("b", 8), ("coda", 4)], "F major")
    sc = tr.score
    sc.program(CH_PIANO, GM["piano"])
    sc.program(CH_VLN, GM["violin"]); sc.program(CH_VLA, GM["viola"]); sc.program(CH_VC, GM["cello"])
    sc.pan(CH_VLN, 48); sc.pan(CH_VLA, 80); sc.pan(CH_VC, 64)
    L = tr.render_length_s()

    # chords: (root midi for the bass, voicing in the middle register)
    V = {"F": (41, [57, 60, 65]), "Bb": (46, [58, 62, 65]), "Dm": (38, [57, 62, 65]), "C": (36, [55, 60, 64]),
         "Gm": (43, [58, 62, 67]), "Am": (45, [57, 60, 64]), "C7": (36, [55, 58, 60, 64]), "F/A": (45, [60, 65, 69])}
    a_prog = ["F", "Bb", "Dm", "C", "F", "Gm", "Bb", "C7"]
    br_prog = ["Dm", "Bb", "Gm", "C7"]
    b_prog = ["F", "Am", "Bb", "C", "Dm", "Bb", "Gm", "C7"]
    coda_prog = ["F", "Bb", "F/A", "F"]

    def arpeggio(ch, bar_beat, name, vel, pattern=(0, 1, 2, 1, 0, 1, 2, 1)):
        root, voice = V[name]
        notes = [root + 12] + voice
        for i, p in enumerate(pattern):
            sc.note(ch, notes[p] if p < len(notes) else notes[-1], bar_beat + i * 0.5, 0.55, vel - (0 if i % 2 == 0 else 8))

    # ---- intro: piano alone, the World cell over Dm → F ----
    sc.note(CH_PIANO, 38, tr.bar("intro", 0), 4.0, 50)
    world_cell(sc, CH_PIANO, tr.bar("intro", 0), quaver=1.0, vel=60, hold=3.0)
    sc.note(CH_PIANO, 41, tr.bar("intro", 1), 4.0, 48)
    sc.chord(CH_PIANO, [57, 60, 65], tr.bar("intro", 1) + 2.0, 2.0, 40, strum=0.04)

    # ---- A: piano arpeggios with the cell every second bar (at pitch over F/Dm, a fourth up over Gm/Bb) ----
    for i, name in enumerate(a_prog):
        b = tr.bar("a", i)
        sc.note(CH_PIANO, V[name][0], b, 3.9, 52)
        arpeggio(CH_PIANO, b, name, 44)
    for k, (bar, tp) in enumerate([(0, 0), (2, 0), (4, 5), (6, 5)]):
        world_cell(sc, CH_PIANO, tr.bar("a", bar), quaver=1.0, vel=62 + 2 * k, transpose=tp, hold=3.0)

    # ---- bridge: the quartet chorale; piano only a bass note ----
    for i, name in enumerate(br_prog):
        b = tr.bar("bridge", i)
        root, voice = V[name]
        sc.note(CH_PIANO, root, b, 3.9, 46)
        sc.note(CH_VC, root + 12, b, 3.95, 58)
        sc.note(CH_VLA, voice[0], b, 3.95, 52)
        sc.note(CH_VLN, voice[-1] + 12 if i % 2 == 0 else voice[1] + 12, b, 3.95, 54)
    world_cell(sc, CH_VLN, tr.bar("bridge", 2), quaver=1.0, vel=64, transpose=12, hold=3.0)

    # ---- B: quartet carries the cell long; piano arpeggios underneath ----
    for i, name in enumerate(b_prog):
        b = tr.bar("b", i)
        root, voice = V[name]
        sc.note(CH_PIANO, root, b, 3.9, 54)
        arpeggio(CH_PIANO, b, name, 46, (0, 2, 1, 2, 0, 2, 1, 3 if len(voice) > 3 else 2))
        sc.note(CH_VC, root + 12, b, 3.95, 56 + (6 if i >= 4 else 0))
        sc.note(CH_VLA, voice[1], b, 3.95, 50 + (6 if i >= 4 else 0))
    for bar, tp, vel in [(0, 12, 66), (2, 17, 66), (4, 12, 70), (6, 12, 64)]:
        world_cell(sc, CH_VLN, tr.bar("b", bar), quaver=1.0 if bar != 6 else 2.0, vel=vel, transpose=tp, hold=3.0 if bar != 6 else 1.0)

    # ---- coda: the cell slows (longer values) and lands on F; strings hold F then fade into the loop ----
    for i, name in enumerate(coda_prog):
        b = tr.bar("coda", i)
        root, voice = V[name]
        sc.note(CH_PIANO, root, b, 3.9, 48 - 2 * i)
        if i < 2:
            sc.chord(CH_PIANO, voice, b + 2.0, 1.9, 38, strum=0.04)
    world_cell(sc, CH_PIANO, tr.bar("coda", 0), quaver=1.5, vel=58, hold=3.0)
    sc.chord(CH_PIANO, [41, 53, 60, 65, 69], tr.bar("coda", 2), 7.5, 46, strum=0.05)
    sc.note(CH_VC, 53, tr.bar("coda", 0), 15.0, 50)
    sc.note(CH_VLA, 60, tr.bar("coda", 0), 15.0, 44)
    sc.note(CH_VLN, 69, tr.bar("coda", 1), 11.0, 44)
    for i in range(4):
        for ch in (CH_VLN, CH_VLA, CH_VC):
            sc.expression(ch, 127 - 28 * i, tr.bar("coda", i))
    for ch in (CH_VLN, CH_VLA, CH_VC):
        sc.expression(ch, 127, tr.bar("a", 0))

    midi = tr.midi_stems({"piano": [CH_PIANO], "quartet": [CH_VLN, CH_VLA, CH_VC]}, gain=0.6)
    stems = {
        "piano": C.felt_piano(midi["piano"], 2000.0, 1.5, 0.18),
        "quartet": C.quartet(midi["quartet"], 2.2, 0.26, crackle_db=None, seed=43),
    }
    # ---- crackle: vinyl texture, warm room, and the house clock (a wooden tick each beat) ----
    crackle = S.vinyl_crackle(L, 16.0, -40.0, seed=44)
    gen = S.rng(45)
    clock = np.zeros(S.samples(L))
    beat = tr.s(1.0)
    for k in range(int(L / beat) + 1):
        tk = S.lowpass(MB.tick(gen, 0.6), 2600.0, 2)
        tk = S.pitch_shift(tk, -9.0)
        S.place(clock, tk, k * beat + 0.012, 0.8 if k % 2 == 0 else 0.6)
    st = S.to_stereo(crackle, 0.6) + S.pan(clock, 0.35) * S.db_to_amp(-6.0) + S.to_stereo(S.room_tone(L, -52.0, 46))
    stems["crackle"] = st

    levels = {"piano": -24.0, "quartet": -25.0, "crackle": -40.0}
    for k, v in levels.items():
        stems[k] = C.set_lufs(stems[k], v)
    tr.rtpc = {"stir_ritual": "the stirring is quantised to the beat (3.333 s bar); when Crono stops stirring, skip the crackle stem 0.5 s forward (the house clock skips)",
               "porcelain_stress": "music bus low-pass via AudioDirector"}
    tr.notes = "World cell at pitch (D4 F4 A4 G4 E4) in F major; the crackle stem carries the house clock at 72 BPM."
    return tr.finalize(stems, hiss_stem="crackle")


if __name__ == "__main__":
    r = build()
    print(r["id"], r["duration_s"], "s; loop from", r["loop_start_s"], "s; mix", r["mix"])
    for k, v in r["stems"].items():
        print(f"  {k:10s} {v['file']:40s} peak {v['peak_dbfs']:6.1f} lufs {v['lufs_i']}")
