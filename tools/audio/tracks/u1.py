"""mus_u1_ashen_morning and mus_u1_krona_duel (§8.5), the Crimson Shogunate.

Ashen morning: 48 BPM, free feel, A minor pentatonic. Shakuhachi long tones on the World cell
(A4 C5 E5 D5 B4), sparse koto, a taiko every two bars, ink-stroke swells, long silences, a
washi crackle under everything. Single file.

Krona's duel: 96 BPM, 4/4, D minor. Broken-skin taiko, distorted guitar on a Phrygian riff,
detuned koto ostinato, shakuhachi on Krona's cell (G3 C4 D4 E♭4 with the bend into the E♭);
a 0.3 s reverb freeze closes the bridge. Single file."""
from __future__ import annotations

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402
from common import S, MB  # noqa: E402
from score import GM, n  # noqa: E402
from motifs import krona_cell  # noqa: E402

A_CELL = [n("A4"), n("C5"), n("E5"), n("D5"), n("B4")]  # the World cell on A
PENTA = [n("A3"), n("C4"), n("D4"), n("E4"), n("G4"), n("A4"), n("C5"), n("D5"), n("E5")]


def ink_swell(dur: float, gen: np.random.Generator) -> np.ndarray:
    """An ink-stroke swell: band-passed pink noise that rises and falls like a brush loading."""
    x = S.bandpass(S.noise(dur, "pink", gen), 400.0, 3200.0, 2) * S.swell(dur, 0.65, 1.8)
    return S.normalize_peak(x, -8.0)


def washi_bed(length_s: float, level_db: float, seed: int) -> np.ndarray:
    """Washi crackle: fire-paper pops, sparse and low-passed, with a faint roar."""
    gen = S.rng(seed)
    pops = S.lowpass(S.vinyl_crackle(length_s, 9.0, level_db + 4, seed=seed + 1, pops=True), 3500.0, 1)
    roar = S.lowpass(S.noise(length_s, "brown", gen), 220.0, 2)
    roar *= S.db_to_amp(level_db - 2) / (np.std(roar) + 1e-9)
    t = S.t_axis(length_s)
    roar *= 0.7 + 0.3 * np.sin(S.TWO_PI * 0.05 * t + gen.uniform(0, 6))
    return S.to_stereo(pops, 0.6) + S.to_stereo(roar)


def build_ashen_morning() -> dict:
    tr = C.Track("mus_u1_ashen_morning", 48, 4, [("intro", 2), ("a", 4), ("bridge", 2), ("b", 6), ("coda", 2)],
                 "A minor pentatonic", single_file=True)
    sc = tr.score
    CH_SHAK, CH_KOTO, CH_TAIKO = 0, 1, 2
    sc.program(CH_SHAK, GM["shakuhachi"]); sc.program(CH_KOTO, GM["koto"]); sc.program(CH_TAIKO, GM["taiko"])
    sc.pan(CH_KOTO, 80); sc.pan(CH_SHAK, 52)
    for k in range(tr.total_bars):  # koto 8 cents flat
        sc.bend_cents(CH_KOTO, -8.0 + 3.0 * np.sin(0.9 * k), k * 4.0)
    L = tr.render_length_s()
    gen = S.rng(800)

    def long_cell(sec, bar, vel, q=2.0, hold=4.0, tp=0):
        b = tr.bar(sec, bar)
        for i, p in enumerate(A_CELL):
            d = hold if i == len(A_CELL) - 1 else q
            # meri: scoop into the first and last notes
            if i in (0, 4):
                sc.bend_cents(CH_SHAK, -90.0, b - 0.02)
                sc.bend_ramp(CH_SHAK, -90.0, 0.0, b, 0.6, 8)
            sc.note(CH_SHAK, p + tp, b, d * 0.97, vel)
            b += d

    # intro: a single koto note, silence, the taiko
    sc.note(CH_KOTO, n("A3"), tr.bar("intro", 0) + 1.0, 4.0, 60)
    sc.note(CH_TAIKO, 36, tr.bar("intro", 1) + 2.0, 2.0, 70)
    long_cell("a", 0, 72)
    sc.note(CH_KOTO, n("E4"), tr.bar("a", 2) + 2.0, 3.0, 56)
    sc.note(CH_KOTO, n("A3"), tr.bar("a", 3) + 1.5, 3.0, 52)
    long_cell("a", 3, 68, q=1.0, hold=5.0, tp=-12)
    # bridge: silence as an instrument — one koto note and a breath
    sc.note(CH_KOTO, n("D4"), tr.bar("bridge", 0) + 3.0, 4.0, 50)
    sc.note(CH_SHAK, n("E4"), tr.bar("bridge", 1) + 2.0, 2.0, 40)
    long_cell("b", 0, 78, q=2.0, hold=6.0)
    for k, (bar, off, p) in enumerate([(1, 2.0, n("G4")), (2, 1.0, n("A3")), (3, 3.0, n("C4")), (4, 0.5, n("E4")), (5, 2.0, n("A3"))]):
        sc.note(CH_KOTO, p, tr.bar("b", bar) + off, 3.0, 58 - 2 * k)
    long_cell("b", 3, 74, q=1.5, hold=6.0, tp=12)
    sc.note(CH_SHAK, n("A4"), tr.bar("coda", 0) + 1.0, 6.0, 60)
    sc.note(CH_KOTO, n("A3"), tr.bar("coda", 1) + 2.0, 4.0, 50)
    for bar in range(tr.section_bar["a"], tr.total_bars, 2):
        sc.note(CH_TAIKO, 36, bar * 4, 2.0, 74 if bar < tr.section_bar["b"] else 84)

    midi = tr.midi_stems({"shak": [CH_SHAK], "koto": [CH_KOTO], "taiko": [CH_TAIKO]}, gain=0.6)
    shak = C.shakuhachi_post(midi["shak"], -34.0, seed=801)
    koto = C.koto_post(midi["koto"], seed=802)
    taiko = C.broken_skin_taiko(midi["taiko"]) * 0.6
    swells = np.zeros(S.samples(L))
    for t0 in [tr.s(tr.bar("a", 1)) + 1.0, tr.s(tr.bar("a", 3)), tr.s(tr.bar("b", 1)) + 2.0, tr.s(tr.bar("b", 4)) + 1.0, tr.s(tr.bar("coda", 0)) + 3.0]:
        S.place(swells, ink_swell(2.4, gen), t0, 0.7)
    mix = S.mix(shak, koto * S.db_to_amp(-3.0), taiko, S.to_stereo(swells, 0.5) * S.db_to_amp(-14.0), washi_bed(L, -50.0, 803))
    stems = {"mix": mix}
    C.balance(stems, {"mix": -21.0}, ceilings={"mix": -2.0})
    tr.rtpc = {"movement": "ink-stroke swells on movement: play sfx/weapons/krona_nodachi gesture layer at −18 dB on each run start",
               "silence": "the track is quiet by design (−12 LUFS short-term peaks only on the taiko); do not normalise it louder"}
    tr.notes = "48 BPM, 5 s bars. World cell on A (A4 C5 E5 D5 B4) with meri scoops. Taiko every two bars; washi crackle at −50 dB."
    return tr.finalize(stems, hiss_db=-60.0)


def build_krona_duel() -> dict:
    tr = C.Track("mus_u1_krona_duel", 96, 4, [("intro", 4), ("a", 12), ("bridge", 8), ("b", 12), ("coda", 4)], "D minor", single_file=True)
    sc = tr.score
    CH_SHAK, CH_KOTO, CH_GTR, CH_TAIKO, CH_WB = 0, 1, 2, 3, 4
    sc.program(CH_SHAK, GM["shakuhachi"]); sc.program(CH_KOTO, GM["koto"]); sc.program(CH_GTR, GM["dist_guitar"])
    sc.program(CH_TAIKO, GM["taiko"]); sc.program(CH_WB, GM["woodblock"])
    sc.pan(CH_KOTO, 84); sc.pan(CH_WB, 40); sc.pan(CH_SHAK, 56)
    for k in range(tr.total_bars):
        sc.bend_cents(CH_KOTO, -14.0 + 5.0 * np.sin(1.1 * k), k * 4.0)
    L = tr.render_length_s()
    prog = {"a": ["Dm", "Dm", "Eb", "Dm", "Dm", "Gm", "A", "Dm", "Dm", "Eb", "A", "Dm"],
            "bridge": ["Bb", "Gm", "Eb", "A", "Dm", "Eb", "A", "A"],
            "b": ["Dm", "Eb", "Dm", "Gm", "Dm", "Eb", "A", "Dm", "Dm", "Eb", "A", "Dm"],
            "coda": ["Dm", "Eb", "A", "Dm"]}
    root = {"Dm": 38, "Eb": 39, "Gm": 43, "A": 45, "Bb": 46}
    riff = {"Dm": [38, 38, 41, 39, 38, 38, 36, 34], "Eb": [39, 39, 43, 41, 39, 39, 38, 36], "Gm": [43, 43, 46, 45, 43, 43, 41, 39],
            "A": [45, 45, 49, 47, 45, 45, 43, 41], "Bb": [46, 46, 50, 48, 46, 46, 45, 43]}

    for sec in ("a", "bridge", "b", "coda"):
        for i, name in enumerate(prog[sec]):
            b0 = tr.bar(sec, i)
            r = root[name]
            soft = sec == "bridge"
            # guitar: power chord on 1, the riff in quavers (palm-muted = short notes), heavier in B
            sc.chord(CH_GTR, [r, r + 7], b0, 0.9, 100 if not soft else 76)
            for e, p in enumerate(riff[name]):
                if e == 0:
                    continue
                sc.note(CH_GTR, p, b0 + e * 0.5, 0.22 if not (sec == "b" and e in (4, 6)) else 0.45, 84 if not soft else 60)
            # taiko: 1, and-of-2, 3 (big), 4 (small), rolls at section ends
            sc.note(CH_TAIKO, 36, b0, 0.6, 112 if not soft else 84)
            sc.note(CH_TAIKO, 43, b0 + 1.5, 0.4, 92 if not soft else 66)
            sc.note(CH_TAIKO, 36, b0 + 2.0, 0.6, 104 if not soft else 78)
            sc.note(CH_TAIKO, 43, b0 + 3.0, 0.4, 88 if not soft else 64)
            if sec == "b":
                sc.note(CH_TAIKO, 43, b0 + 3.5, 0.3, 80)
            for e in range(8):
                if e % 2 == 1:
                    sc.note(CH_WB, 60, b0 + e * 0.5, 0.2, 70 if not soft else 48)
            # koto ostinato in semiquavers (B) or quavers (A)
            tones = [r + 24, r + 31, r + 36, r + 31]
            step = 0.25 if sec == "b" else 0.5
            for k in range(int(4 / step)):
                sc.note(CH_KOTO, tones[k % 4] + (12 if k % 8 == 6 else 0), b0 + k * step, step * 1.8, 74 if k % 2 == 0 else 58)
    # intro: taiko alone building, a guitar D on the last bar
    for i in range(4):
        b0 = tr.bar("intro", i)
        sc.note(CH_TAIKO, 36, b0, 1.0, 72 + 12 * i)
        if i >= 2:
            sc.note(CH_TAIKO, 43, b0 + 1.5, 0.4, 70 + 8 * i)
            sc.note(CH_TAIKO, 36, b0 + 2.0, 0.6, 76 + 10 * i)
    for e in range(8):
        sc.note(CH_TAIKO, 43, tr.bar("intro", 3) + 2.0 + e * 0.25, 0.2, 60 + 7 * e)
    sc.chord(CH_GTR, [38, 45], tr.bar("intro", 3), 3.9, 90)
    # shakuhachi: Krona's cell up an octave every four bars, slow and pleading in the bridge
    for sec, bars, vel, q in [("a", (0, 4, 8), 98, 0.5), ("b", (0, 4, 8), 104, 0.5), ("coda", (0,), 90, 0.5)]:
        for bar in bars:
            krona_cell(sc, CH_SHAK, tr.bar(sec, bar) + 2.0, quaver=q, vel=vel, transpose=12)
    krona_cell(sc, CH_SHAK, tr.bar("bridge", 0), quaver=1.0, vel=92, transpose=12)
    krona_cell(sc, CH_SHAK, tr.bar("bridge", 4), quaver=1.0, vel=96, transpose=12)

    midi = tr.midi_stems({"shak": [CH_SHAK], "koto": [CH_KOTO], "gtr": [CH_GTR], "taiko": [CH_TAIKO], "wb": [CH_WB]}, gain=0.6)
    shak = C.shakuhachi_post(midi["shak"], -36.0, seed=811)
    # the 0.3 s reverb freeze at the end of the bridge (the 24 fps smear)
    f0 = S.samples(tr.s(tr.bar("b", 0)) - 0.3)
    chunk = shak[f0: f0 + S.samples(0.3)]
    frozen = np.concatenate([chunk, chunk[::-1]] * 3)
    frozen *= np.linspace(1.0, 0.0, len(frozen))[:, None] ** 0.6
    shak = S.place(shak, S.reverb(frozen, 2.0, 0.6, 0.0, 4000.0, seed=812, tail=False), tr.s(tr.bar("b", 0)), 0.8)
    koto = C.koto_post(midi["koto"], seed=813)
    gtr = C.guitar_post(midi["gtr"])
    taiko = C.broken_skin_taiko(midi["taiko"])
    wb = S.reverb(S.to_stereo(S.to_mono(midi["wb"]), 0.3), 1.0, 0.15, 0.005, 5000.0, seed=814)
    mix = S.mix(shak, koto * S.db_to_amp(-5.0), gtr * S.db_to_amp(-2.0), taiko, wb * S.db_to_amp(-8.0), washi_bed(L, -54.0, 815))
    stems = {"mix": mix}
    C.balance(stems, {"mix": -20.0}, ceilings={"mix": -1.5})
    tr.rtpc = {"smear": "the 24 fps smear: a 0.3 s reverb freeze is rendered at the bridge → B seam (35.0 s); at runtime use AudioEffectReverb with room 1.0 for 0.3 s",
               "hitstop": "duck the mix 6 dB and play sfx/combat/break_gong_vinyl on hitstop"}
    tr.notes = "Krona's cell G C D E♭ at pitch over a D pedal (Phrygian bruise). Taiko pitched down a minor third and saturated."
    return tr.finalize(stems, hiss_db=-60.0)


if __name__ == "__main__":
    for r in (build_ashen_morning(), build_krona_duel()):
        print(r["id"], r["duration_s"], "s; loop from", r["loop_start_s"], "s; mix", r["mix"])
