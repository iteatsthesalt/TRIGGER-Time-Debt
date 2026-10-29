"""mus_u0_fair_1024 — Leene Square, Chapter 1 (§8.5). 108 BPM, 6/8, G major.
Fair band: accordion, fiddle, tin whistle, frame drum; the World cell in E Dorian
(E4 G4 B4 A4 F#4). Single file; the chase layer (tachyon chirps) is a follow-up stem."""
from __future__ import annotations

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402
from common import S  # noqa: E402
from score import GM, n  # noqa: E402

ID = "mus_u0_fair_1024"
CH_ACC, CH_FID, CH_WHI, CH_ACC_BASS = 0, 1, 2, 3
# the World cell transposed to E Dorian so it sits inside G major
CELL = [n("E4"), n("G4"), n("B4"), n("A4"), n("F#4")]


def build() -> dict:
    # scored with the quaver as the beat: 324 quavers/min, 6 per bar = the 108 BPM dotted-crotchet pulse
    tr = C.Track(ID, 324, 6, [("intro", 4), ("a", 16), ("bridge", 8), ("b", 24), ("coda", 12)], "G major",
                 single_file=True, meter_note=8, display_bpm=108, display_beats_per_bar=2)
    sc = tr.score
    sc.program(CH_ACC, GM["accordion"]); sc.program(CH_FID, GM["fiddle"]); sc.program(CH_WHI, GM["whistle"])
    sc.program(CH_ACC_BASS, GM["accordion"])
    sc.pan(CH_ACC, 74); sc.pan(CH_FID, 50); sc.pan(CH_WHI, 40); sc.pan(CH_ACC_BASS, 70)
    L = tr.render_length_s()
    gen = S.rng(400)

    V = {"G": (43, [59, 62, 67]), "C": (48, [60, 64, 67]), "D": (50, [57, 62, 66]), "Em": (52, [59, 64, 67]),
         "Bm": (47, [59, 62, 66]), "Am": (45, [57, 60, 64]), "D7": (50, [57, 60, 62, 66])}
    prog_a = ["G", "G", "C", "D", "G", "Em", "C", "D"] * 2
    prog_br = ["Em", "Em", "Bm", "Bm", "C", "D", "Em", "D7"]
    prog_b = ["G", "G", "C", "D", "G", "Em", "C", "D", "G", "Bm", "C", "D", "Em", "C", "G", "D7"] + ["G", "C", "G", "D", "G", "C", "D7", "G"]
    prog_coda = ["G", "Em", "C", "D", "G", "Em", "Am", "D7", "G", "C", "D7", "G"]

    def oompah(sec, prog, vel):
        for i, name in enumerate(prog):
            b = tr.bar(sec, i)
            root, voice = V[name]
            sc.note(CH_ACC_BASS, root - 12, b, 1.0, vel)
            sc.note(CH_ACC_BASS, root - 12 + 7 if i % 2 else root - 12, b + 3, 1.0, vel - 6)
            for off in (1, 2, 4, 5):
                sc.chord(CH_ACC, voice, b + off, 0.8, vel - 14 - (4 if off in (2, 5) else 0))

    # ---- melody: a jig figure that opens with the cell and runs down the mode ----
    def jig(sec, bar, vel, ch=CH_FID, tp=0, ornament=True):
        b = tr.bar(sec, bar)
        # bar 1: cell notes on the strong quavers; bar 2: a run that lands on the chord
        seq = [(0, CELL[0], 1), (1, CELL[1], 1), (2, CELL[2], 1), (3, CELL[3], 2), (5, CELL[4], 1),
               (6, n("G4"), 1), (7, n("A4"), 1), (8, n("B4"), 1), (9, n("D5"), 1.5), (10.5, n("B4"), 0.5), (11, n("G4"), 1)]
        for off, p, d in seq:
            sc.note(ch, p + tp, b + off, d * 0.92, vel + int(gen.integers(-5, 6)))
        if ornament:
            sc.note(ch, CELL[2] + tp + 2, b + 2.66, 0.3, vel - 10)  # a grace note into the B

    def whistle_counter(sec, bar, vel):
        b = tr.bar(sec, bar)
        for off, p in [(0, n("B5")), (3, n("A5")), (6, n("G5")), (9, n("F#5"))]:
            sc.note(CH_WHI, p, b + off, 2.8, vel)

    # intro: the frame drum alone (synth) and a single accordion chord swell
    sc.chord(CH_ACC, V["G"][1], tr.bar("intro", 2), 11.5, 44, strum=0.05)
    oompah("a", prog_a, 60)
    for k in range(0, 16, 2):
        jig("a", k, 72 + (6 if k >= 8 else 0))
    oompah("bridge", prog_br, 52)
    for k in range(0, 8, 2):
        jig("bridge", k, 66, tp=0, ornament=False)
    for k in (0, 4):
        whistle_counter("bridge", k, 50)
    oompah("b", prog_b, 66)
    for k in range(0, 24, 2):
        jig("b", k, 78)
        if k % 4 == 2:
            jig("b", k, 56, ch=CH_WHI, tp=12, ornament=False)
    oompah("coda", prog_coda, 56)
    for k in range(0, 8, 2):
        jig("coda", k, 68 - 2 * k)
    sc.chord(CH_ACC, V["G"][1] + [n("G5")], tr.bar("coda", 8), 11.0, 50, strum=0.06)
    sc.note(CH_FID, n("G5"), tr.bar("coda", 8), 11.0, 60)
    sc.note(CH_WHI, n("B5"), tr.bar("coda", 8) + 3, 8.0, 46)

    # ---- frame drum (synth): dum on 1, tak on 4, rolls into section starts ----
    drum = np.zeros(S.samples(L))
    for bar in range(tr.total_bars):
        b0 = bar * 6
        if bar >= 2:
            S.place(drum, frame_hit(gen, low=True), tr.s(b0), 0.9)
            S.place(drum, frame_hit(gen, low=False), tr.s(b0 + 3), 0.6)
            if bar >= tr.section_bar["a"]:
                S.place(drum, frame_hit(gen, low=False), tr.s(b0 + 5), 0.35)
        if (bar + 1) in tr.section_bar.values():
            for r in range(6):
                S.place(drum, frame_hit(gen, low=False), tr.s(b0 + 3 + r * 0.5), 0.3 + 0.08 * r)

    midi = tr.midi_stems({"band": [CH_ACC, CH_FID, CH_WHI, CH_ACC_BASS]}, gain=0.55)
    band = S.reverb(S.lowpass(midi["band"], 9000.0, 1), 1.6, 0.2, 0.012, 5000.0, seed=401)
    drums = S.reverb(S.to_stereo(drum, 0.3), 1.2, 0.18, 0.006, 3500.0, seed=402)
    stems = {"mix": S.mix(band, drums * S.db_to_amp(-4.0))}
    C.balance(stems, {"mix": -20.0}, ceilings={"mix": -2.0})
    tr.rtpc = {"chase": "follow-up: a chase stem of tachyon chirps (sfx/magic/tachyon_travel at 1/8th notes)",
               "telepod": "at the Telepod detune the band: pitch_scale 0.97 and the Debt bus chorus to 7 voices"}
    tr.notes = "6/8 scored at the quaver (324/min, 6 per bar); felt pulse 108. World cell in E Dorian on the fiddle."
    return tr.finalize(stems, hiss_db=-60.0)


def frame_hit(gen: np.random.Generator, low: bool = True) -> np.ndarray:
    d = 0.35 if low else 0.12
    t = S.t_axis(d)
    if low:
        f = 95.0 * (1 + 0.8 * np.exp(-t * 60))
        s = np.sin(S.TWO_PI * np.cumsum(f) / S.SR) * np.exp(-t * 14)
        s += S.lowpass(gen.standard_normal(len(t)), 900.0, 2) * np.exp(-t * 60) * 0.5
    else:
        s = S.bandpass(gen.standard_normal(len(t)), 1500.0, 6000.0, 2) * np.exp(-t * 55)
        s += np.sin(S.TWO_PI * 420.0 * t) * np.exp(-t * 50) * 0.3
    s *= np.minimum(1.0, t * 600.0)
    return S.normalize_peak(s, -6.0)


if __name__ == "__main__":
    r = build()
    print(r["id"], r["duration_s"], "s; loop from", r["loop_start_s"], "s; mix", r["mix"])
