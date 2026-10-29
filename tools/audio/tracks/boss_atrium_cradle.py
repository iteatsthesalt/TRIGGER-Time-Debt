"""mus_boss_atrium_cradle — the Prologue boss (§8.5). 72 BPM, 4/4, C minor.
Robo's gramophone resonance (a hymn on voices through a horn), the quartet, ceramic tings that
side-chain everything else to 0.2 s of silence. The B section is phase 2 (the clock quantised to
12 fps VHS); the coda carries phase 3's three seconds of U7 gold leaf (koto and rin chimes).
Stems: strings, lead (gramophone hymn + gold leaf), drums (tings and the cradle rock), crackle."""
from __future__ import annotations

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402
from common import S, MB  # noqa: E402
from score import GM, n, chord_notes  # noqa: E402
from motifs import TIME_CELL  # noqa: E402

ID = "mus_boss_atrium_cradle"
CH_VLN, CH_VLA, CH_VC, CH_CB, CH_VOX, CH_KOTO, CH_RIN = 0, 1, 2, 3, 4, 5, 6
# the Time cell in C minor (E♭ for E, B♮ as the leading tone)
TIME_MINOR = [n("Eb4"), n("G4"), n("C5"), n("B4"), n("G4"), n("Eb4"), n("D4"), n("C4")]


def build() -> dict:
    tr = C.Track(ID, 72, 4, [("intro", 4), ("a", 8), ("bridge", 4), ("b", 8), ("coda", 4)], "C minor")
    sc = tr.score
    for ch, prog in [(CH_VLN, "violin"), (CH_VLA, "viola"), (CH_VC, "cello"), (CH_CB, "contrabass"),
                     (CH_VOX, "voice_oohs"), (CH_KOTO, "koto"), (CH_RIN, "crystal")]:
        sc.program(ch, GM[prog])
    sc.pan(CH_VLN, 40); sc.pan(CH_VLA, 84); sc.pan(CH_VC, 60); sc.pan(CH_CB, 64)
    L = tr.render_length_s()
    gen = S.rng(600)

    V = {"Cm": (36, [60, 63, 67]), "Ab": (44, [60, 63, 68]), "Fm": (41, [60, 65, 68]), "G": (43, [59, 62, 67]),
         "Eb": (39, [58, 63, 67]), "Bb": (46, [58, 62, 65]), "Ddim": (38, [59, 62, 65]), "G7": (43, [59, 62, 65, 67])}
    prog_a = ["Cm", "Ab", "Fm", "G", "Cm", "Eb", "Ab", "G7"]
    prog_br = ["Fm", "Ddim", "G7", "G7"]
    prog_b = ["Cm", "Cm", "Ab", "G", "Cm", "Fm", "Ddim", "G7"]
    prog_coda = ["Cm", "Ab", "Fm", "Cm"]

    def chorale(sec, prog, vel, rhythm=None):
        for i, name in enumerate(prog):
            b = tr.bar(sec, i)
            root, voice = V[name]
            if rhythm is None:
                sc.note(CH_CB, root, b, 3.95, vel - 6)
                sc.note(CH_VC, root + 12, b, 3.95, vel)
                sc.note(CH_VLA, voice[1], b, 3.95, vel - 4)
                sc.note(CH_VLN, voice[-1] + 12, b, 3.95, vel - 2)
            else:  # quaver pulses (phase 2)
                for e in rhythm:
                    sc.note(CH_CB, root, b + e, 0.45, vel - 6)
                    sc.note(CH_VC, root + 12, b + e, 0.45, vel)
                    sc.chord(CH_VLA, voice, b + e, 0.45, vel - 6)
                sc.note(CH_VLN, voice[-1] + 12, b, 3.95, vel)

    # intro: the contrabass and cello alone, the cradle rocking between C and G
    for i in range(4):
        b = tr.bar("intro", i)
        sc.note(CH_CB, 36 if i % 2 == 0 else 31, b, 3.95, 56)
        sc.note(CH_VC, 48 if i % 2 == 0 else 43, b + 2.0, 1.9, 50)
    chorale("a", prog_a, 62)
    chorale("bridge", prog_br, 68)
    chorale("b", prog_b, 74, rhythm=(0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5))
    chorale("coda", prog_coda[:1], 60)
    # the coda bars 1–2 are the gold leaf: strings out; bar 3 brings C minor back for the loop
    root, voice = V["Cm"]
    sc.note(CH_CB, root, tr.bar("coda", 3), 3.95, 58)
    sc.note(CH_VC, root + 12, tr.bar("coda", 3), 3.95, 60)
    sc.chord(CH_VLA, voice, tr.bar("coda", 3), 3.95, 54)

    # ---- the gramophone hymn: voices sing the Time cell in minor, slowly, in A and B ----
    def hymn(sec, bar, vel, q=1.0):
        b = tr.bar(sec, bar)
        for i, p in enumerate(TIME_MINOR):
            sc.note(CH_VOX, p, b + i * q, q * 1.05, vel)
            if i % 2 == 0:
                sc.note(CH_VOX, p - 5 if i < 4 else p - 4, b + i * q, q * 2.05, vel - 10)

    hymn("a", 0, 74); hymn("a", 4, 78)
    hymn("b", 0, 84, 0.5); hymn("b", 2, 84, 0.5); hymn("b", 4, 88); 
    # ---- gold leaf (phase 3): koto and the rin cluster for 3 s in the coda ----
    g0 = tr.bar("coda", 1)
    for k, p in enumerate([n("C4"), n("G4"), n("Eb5"), n("C5"), n("G5")]):
        sc.note(CH_KOTO, p, g0 + k * 0.45, 1.8, 72 - 4 * k)
    for k, p in enumerate([n("C5"), n("Eb5"), n("Gb5"), n("A5"), n("C6"), n("Eb6")]):
        sc.note(CH_RIN, p, g0 + 1.2 + k * 0.12, 2.5, 52)

    midi = tr.midi_stems({"strings": [CH_VLN, CH_VLA, CH_VC, CH_CB], "vox": [CH_VOX], "gold": [CH_KOTO, CH_RIN]}, gain=0.6)
    strings = C.quartet(midi["strings"], 2.6, 0.3, crackle_db=None, seed=601)
    # phase 2 (B section): the quartet stutters at 12 fps — gate the strings at 12 Hz across B
    b0, b1 = S.samples(tr.s(tr.bar("b", 0))), S.samples(tr.s(tr.bar("coda", 0)))
    t = np.arange(b1 - b0) / S.SR
    gate = 0.55 + 0.45 * (np.sign(np.sin(S.TWO_PI * 12.0 * t)) * 0.5 + 0.5)
    gate = S.one_pole_lp(gate, 400.0)
    strings[b0:b1] *= gate[:, None]
    strings[b0:b1] = S.bitcrush(strings[b0:b1], 10, 2) * 0.9 + strings[b0:b1] * 0.4
    lead = S.mix(C.gramophone_post(midi["vox"], -36.0, 7.0, seed=602),
                 S.reverb(S.to_stereo(S.to_mono(midi["gold"]), 0.5), 2.8, 0.35, 0.02, 6000.0, seed=603) * S.db_to_amp(-2.0))

    # ---- ceramic tings (drums stem) and their 0.2 s silences ----
    ting_times = []
    for sec, bars, pattern in [("a", 8, (1.0, 3.0)), ("bridge", 4, (1.0, 2.5, 3.0)), ("b", 8, (0.5, 1.0, 2.5, 3.0, 3.5)), ("coda", 1, (1.0, 3.0))]:
        for i in range(bars):
            for off in pattern:
                ting_times.append(tr.s(tr.bar(sec, i) + off))
    drums = np.zeros(S.samples(L))
    for k, t0 in enumerate(ting_times):
        S.place(drums, C.porcelain_ting(4600.0 + 400 * (k % 3), 0.09, seed=610 + k, vel=0.8), t0)
    # the cradle: a slow wooden rock (low thud) on beat 1 of every bar
    for bar in range(tr.total_bars):
        th = S.lowpass(S.noise(0.25, "brown", gen), 160.0, 2) * S.exp_decay(0.25, 18.0)
        S.place(drums, th, tr.s(bar * 4), 0.6)
    drums_st = S.reverb(S.to_stereo(drums, 0.35), 2.2, 0.3, 0.01, 6000.0, seed=604)
    # side-chain: everything but the tings drops to 0.2 for 0.2 s after each ting
    sidechain = [t0 + 0.02 for t0 in ting_times]
    strings = S.duck(strings, sidechain, 0.2, 0.2, 0.18)
    lead = S.duck(lead, sidechain, 0.2, 0.2, 0.18)
    crackle = S.to_stereo(S.vinyl_crackle(L, 20.0, -40.0, seed=605), 0.5) + S.to_stereo(S.room_tone(L, -54.0, 606))
    # phase 2 texture in the crackle stem: a 12 Hz VHS flutter of hiss across B
    vhs = S.tape_hiss(L, -40.0, seed=607)
    vhs[b0:b1] *= (0.3 + 0.7 * gate)[:, None]
    vhs[:b0] *= 0.0; vhs[b1:] *= 0.0
    crackle = S.duck(crackle + vhs, sidechain, 0.2, 0.3, 0.18)
    stems = {"strings": strings, "lead": lead, "drums": drums_st, "crackle": crackle}
    C.balance(stems, {"strings": -24.0, "lead": -27.0, "drums": -29.0, "crackle": -40.0}, ceilings={"drums": -8.0, "lead": -9.0, "strings": -7.0})
    tr.rtpc = {"phase": "phase 1 = intro+A, phase 2 = bridge+B (12 fps VHS), phase 3 = coda (gold leaf at bar 25); use AudioStreamInteractive clips per section",
               "grief_resonance": "not used here; Robo is not Vaelos"}
    tr.notes = "Ceramic tings side-chain the other stems to 0.2 for 0.2 s. B gates the quartet at 12 Hz and bit-crushes it."
    return tr.finalize(stems, hiss_stem="crackle")


if __name__ == "__main__":
    r = build()
    print(r["id"], r["duration_s"], "s; loop from", r["loop_start_s"], "s; mix", r["mix"])
    for k, v in r["stems"].items():
        print(f"  {k:8s} {v['file']:40s} peak {v['peak_dbfs']:6.1f} lufs {v['lufs_i']}")
