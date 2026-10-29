"""mus_battle_core_u0 / mus_battle_core_u1 — standard battles (§8.5). 144 BPM, 4/4, E minor.
One skeleton (harmony, hook rhythm, tick, box), two orchestrations:
  U0: felt piano hook, quartet stabs, warped 808, 808 kit with hiss hats, music box, tick
  U1: shakuhachi hook, detuned koto, broken-skin taiko, distorted guitar, music box, tick
Stems: box, tick + (piano, strings, bass, drums) or (lead, pad, bass, drums).
Sync Hold ducks everything but the box and stops the tick; Boost Lv3 swells the strings/pad."""
from __future__ import annotations

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402
from common import S, MB  # noqa: E402
from score import GM, DRUM_CH, DRUM_KIT, DR, n, chord_notes  # noqa: E402
from motifs import TIME_CELL, crono_cell  # noqa: E402

SECTIONS = [("intro", 4), ("a", 16), ("bridge", 8), ("b", 16), ("coda", 8)]
PROG = {
    "a": ["Em", "Em", "C", "D", "Em", "Em", "Am", "B7", "Em", "Em", "C", "D", "Em", "G", "Am", "B7"],
    "bridge": ["C", "D", "Em", "Bm", "C", "D", "Am", "B7"],
    "b": ["Em", "G", "D", "Em", "C", "D", "Em", "B7", "Em", "G", "D", "Em", "C", "Am", "B7", "B7"],
    "coda": ["Em", "C", "Am", "B7", "Em", "Em", "Em", "B7"],
}
ROOT = {"Em": 40, "C": 36, "D": 38, "Am": 45, "B7": 47, "G": 43, "Bm": 47}
QUAL = {"Em": "min", "C": "maj", "D": "maj", "Am": "min", "B7": "dom7", "G": "maj", "Bm": "min"}
CH_HOOK, CH_HARM, CH_HARM2, CH_BASS, CH_PERC2 = 0, 1, 2, 3, 4


def voicing(name: str, octave_base: int = 60) -> list[int]:
    notes = chord_notes(ROOT[name] % 12 + octave_base, QUAL[name])
    return [p - 12 if p > octave_base + 11 else p for p in notes]


def skeleton(tr: C.Track):
    """Hook rhythm positions, chord list per bar, drum/bass event times shared by both arrangements."""
    bars = []
    for sec, bars_n in SECTIONS:
        for i in range(bars_n):
            name = PROG[sec][i] if sec in PROG else "Em"
            bars.append((sec, i, name))
    return bars


def common_box_and_tick(tr: C.Track) -> tuple[np.ndarray, np.ndarray]:
    L = tr.render_length_s()
    ev = []
    # the Time cell at half speed (a quaver of the hub = a crotchet here) — the battle starts from the hub's heart
    for bar, vel in [(0, 0.75), (tr.section_bar["a"], 0.6), (tr.section_bar["a"] + 8, 0.6), (tr.section_bar["bridge"] + 4, 0.65),
                     (tr.section_bar["b"], 0.7), (tr.section_bar["b"] + 8, 0.7), (tr.section_bar["coda"] + 4, 0.6)]:
        for i, p in enumerate(TIME_CELL):
            ev.append((tr.s(bar * 4 + i * 1.0), p + 12, vel * (1.0 if i % 2 == 0 else 0.85)))
    tines = MB.render_notes(ev, L, seed=500, dur=2.0)
    box = C.box_post(tines, 1.4, 0.2)
    # the 72 BPM tick: every two beats, every eighth one silent
    half = tr.s(2.0)
    times = [k * half for k in range(int(L / half) + 1)]
    tick = MB.render_ticks(times, L, 8, (), vel=0.5, seed=501)
    return box, S.reverb(S.to_stereo(tick, 0.2), 1.0, 0.15, 0.005, 5000.0, seed=502)


def hook(sc, ch, bar_beat, vel, tp=12, tired=True):
    """Crono's cell as crotchets with the C held 300 ms too long; the E rings two beats."""
    end = crono_cell(sc, ch, bar_beat, quaver=1.0, vel=vel, transpose=tp, tired=tired, legato=0.95)
    return end


def build_u0() -> dict:
    tr = C.Track("mus_battle_core_u0", 144, 4, SECTIONS, "E minor")
    sc = tr.score
    sc.program(CH_HOOK, GM["piano"])
    sc.program(CH_HARM, GM["strings"]); sc.program(CH_HARM2, GM["cello"])
    sc.program(DRUM_CH, DRUM_KIT["tr808"], 128)
    sc.pan(CH_HARM, 44); sc.pan(CH_HARM2, 80)
    L = tr.render_length_s()
    bass_ev, hat_ev = [], []
    for sec, i, name in skeleton(tr):
        b0 = tr.bar(sec, i)
        root = ROOT[name]
        voice = voicing(name, 60)
        in_groove = sec != "intro"
        # hook every 4 bars on the piano (U0), with an answer two bars later in the B section
        if in_groove and i % 4 == 0 and sec != "coda":
            hook(sc, CH_HOOK, b0, 92 if sec == "b" else 84)
        if sec == "b" and i % 4 == 2:
            for k, p in enumerate([n("E5"), n("D5"), n("B4"), n("G4")]):
                sc.note(CH_HOOK, p, b0 + k * 0.5, 0.45, 70)
        if sec == "coda" and i == 0:
            hook(sc, CH_HOOK, b0, 80)
        # piano chords: left hand on 1 and the and-of-2
        if in_groove:
            sc.chord(CH_HOOK, [p - 12 for p in voice], b0, 0.9, 60)
            sc.chord(CH_HOOK, [p - 12 for p in voice], b0 + 2.5, 0.6, 50)
        # strings: off-beat stabs, sustained in B and the bridge
        if sec in ("a", "coda"):
            sc.chord(CH_HARM, voice, b0 + 1.5, 0.4, 76)
            sc.chord(CH_HARM, voice, b0 + 3.0, 0.4, 70)
            sc.note(CH_HARM2, root, b0 + 1.5, 0.4, 70)
        elif sec in ("bridge", "b"):
            sc.chord(CH_HARM, [p + 12 for p in voice], b0, 3.9, 62 if sec == "bridge" else 72)
            sc.note(CH_HARM2, root, b0, 3.9, 66)
            if sec == "b":
                sc.chord(CH_HARM, voice, b0 + 1.5, 0.4, 72)
                sc.chord(CH_HARM, voice, b0 + 3.0, 0.4, 66)
        # drums
        if in_groove:
            soft = sec == "bridge"
            sc.note(DRUM_CH, DR["kick"], b0, 0.3, 100)
            sc.note(DRUM_CH, DR["kick"], b0 + 2.5, 0.3, 86)
            sc.note(DRUM_CH, DR["kick"], b0 + 3.0, 0.3, 80)
            sc.note(DRUM_CH, DR["snare"], b0 + 1.0, 0.3, 72 if soft else 96)
            sc.note(DRUM_CH, DR["snare"], b0 + 3.0, 0.3, 70 if soft else 92)
            if sec == "b":
                sc.note(DRUM_CH, DR["clap"], b0 + 3.0, 0.3, 70)
            if i == 0 and sec != "a":
                sc.note(DRUM_CH, DR["crash"], b0, 1.0, 84)
            for e in range(8):
                hat_ev.append((tr.s(b0 + e * 0.5), (0.6 if e % 2 == 0 else 0.35) * (0.6 if soft else 1.0)))
        # bass: 808 root on 1 and the and-of-2, fifth on 4 in B
        if in_groove:
            sub = C.sub_register(root)
            bass_ev.append((tr.s(b0), sub, 1.0))
            bass_ev.append((tr.s(b0 + 2.5), sub, 0.75))
            if sec == "b":
                bass_ev.append((tr.s(b0 + 3.5), sub + 7, 0.55))
    # the intro: a low E and the box, strings swell into A
    sc.note(CH_HARM2, 40, tr.bar("intro", 2), 7.8, 50)
    sc.chord(CH_HARM, [n("E4"), n("G4"), n("B4")], tr.bar("intro", 2), 7.8, 40)
    sc.expression(CH_HARM, 60, tr.bar("intro", 2)); sc.expression(CH_HARM, 127, tr.bar("a", 0))
    bass_ev.insert(0, (tr.s(tr.bar("intro", 0)), 28, 0.9))

    box, tick = common_box_and_tick(tr)
    midi = tr.midi_stems({"piano": [CH_HOOK], "strings": [CH_HARM, CH_HARM2], "drums": [DRUM_CH]}, gain=0.6)
    stems = {
        "box": box, "tick": tick,
        "piano": C.felt_piano(midi["piano"], 3200.0, 1.1, 0.14),
        "strings": C.quartet(midi["strings"], 1.8, 0.24, crackle_db=-46.0, seed=503),
        "bass": S.to_stereo(C.sub_808(bass_ev, L, 1.1, 10.0, seed=504)),
        "drums": S.mix(S.reverb(S.saturate(midi["drums"] * 1.5, 1.6), 0.7, 0.12, 0.004, 3200.0, seed=505),
                       S.to_stereo(C.hiss_hats(hat_ev, L, seed=506), 0.5)),
    }
    C.balance(stems, {"box": -30.0, "tick": -38.0, "piano": -23.0, "strings": -25.0, "bass": -25.0, "drums": -24.0},
              ceilings={"piano": -8.0, "drums": -8.0, "strings": -9.0})
    tr.rtpc = {"sync_hold": "fade every stem except box to −inf over 0.15 s and mute tick; restore on release",
               "shave_bonus": "strings stem +4 dB while shave_bonus = 1 (Boost Lv3)",
               "break": "play sfx/combat/break_gong_vinyl and duck all stems 6 dB for 0.4 s"}
    tr.notes = "Hook = Crono's cell up an octave as crotchets, the C held 300 ms (0.72 beat) too long. Box = Time cell at half speed."
    return tr.finalize(stems, hiss_stem="drums", hiss_db=-60.0)


def build_u1() -> dict:
    tr = C.Track("mus_battle_core_u1", 144, 4, SECTIONS, "E minor")
    sc = tr.score
    sc.program(CH_HOOK, GM["shakuhachi"])
    sc.program(CH_HARM, GM["koto"]); sc.program(CH_HARM2, GM["koto"])
    sc.program(CH_BASS, GM["dist_guitar"])
    sc.program(CH_PERC2, GM["taiko"])
    sc.pan(CH_HARM, 40); sc.pan(CH_HARM2, 88); sc.pan(CH_PERC2, 64)
    L = tr.render_length_s()
    gen = S.rng(510)
    # the koto is detuned −12 cents and wobbles
    for ch in (CH_HARM, CH_HARM2):
        for k in range(int(tr.total_bars * 2)):
            sc.bend_cents(ch, -12.0 + 5.0 * np.sin(0.7 * k) + gen.uniform(-2, 2), k * 2.0)
    wb_ev = []
    for sec, i, name in skeleton(tr):
        b0 = tr.bar(sec, i)
        root = ROOT[name]
        voice = voicing(name, 64)
        in_groove = sec != "intro"
        if in_groove and i % 4 == 0 and sec != "coda":
            # a shakuhachi scoop into the first note
            sc.bend_cents(CH_HOOK, -120.0, b0 - 0.05)
            sc.bend_ramp(CH_HOOK, -120.0, 0.0, b0, 0.35, 8)
            hook(sc, CH_HOOK, b0, 100 if sec == "b" else 92)
        if sec == "b" and i % 4 == 2:
            for k, p in enumerate([n("E5"), n("D5"), n("B4"), n("G4")]):
                sc.note(CH_HOOK, p, b0 + k * 0.5, 0.45, 76)
        if sec == "coda" and i == 0:
            hook(sc, CH_HOOK, b0, 86)
        # koto: quaver arpeggios across two channels (L/R)
        if in_groove:
            arp = [voice[0], voice[2], voice[1], voice[2] + 12, voice[0] + 12, voice[2], voice[1], voice[0]]
            for e in range(8):
                ch = CH_HARM if e % 2 == 0 else CH_HARM2
                vel = 80 if e % 2 == 0 else 62
                if sec == "bridge":
                    vel -= 14
                sc.note(ch, arp[e], b0 + e * 0.5, 0.9, vel)
        # distorted guitar: power chords on 1 and 3, chugs on the other quavers
        if in_groove:
            pc = [root - 12 + 12, root - 12 + 19] if root - 12 + 12 >= 40 else [root, root + 7]
            pc = [max(40, pc[0]), max(47, pc[1])]
            sc.chord(CH_BASS, pc, b0, 1.4, 96 if sec != "bridge" else 70)
            sc.chord(CH_BASS, pc, b0 + 2.0, 1.4, 90 if sec != "bridge" else 66)
            for e in (1.5, 3.5):
                sc.note(CH_BASS, pc[0], b0 + e, 0.2, 72 if sec != "bridge" else 50)
            if sec == "b":
                sc.note(CH_BASS, pc[0], b0 + 3.75, 0.2, 70)
        # taiko: big drum on 1 and 3, a smaller one on the and-of-2 and 4; a hit before each section
        if in_groove:
            soft = sec == "bridge"
            sc.note(CH_PERC2, 36, b0, 0.6, 110 if not soft else 80)
            sc.note(CH_PERC2, 36, b0 + 3.0, 0.6, 96 if not soft else 70)
            sc.note(CH_PERC2, 43, b0 + 2.5, 0.4, 92 if not soft else 64)
            sc.note(CH_PERC2, 43, b0 + 1.0, 0.4, 84 if not soft else 60)
            if sec == "b":
                for e in range(8):
                    wb_ev.append((tr.s(b0 + e * 0.5), 0.7 if e % 2 == 0 else 0.4))
        if sec == "intro":
            sc.note(CH_PERC2, 36, b0, 1.0, 70 + 12 * i)
            if i == 3:
                for e in range(4):
                    sc.note(CH_PERC2, 43, b0 + 2.0 + e * 0.5, 0.3, 60 + 10 * e)
    box, tick = common_box_and_tick(tr)
    midi = tr.midi_stems({"lead": [CH_HOOK], "pad": [CH_HARM, CH_HARM2], "bass": [CH_BASS], "drums": [CH_PERC2]}, gain=0.6)
    # woodblock pattern (page-rustle snare stand-in) rendered with the tick synth, pitched down
    wb = np.zeros(S.samples(L))
    for t0, v in wb_ev:
        S.place(wb, S.pitch_shift(MB.tick(gen, 0.7), -14.0), t0, v)
    stems = {
        "box": box, "tick": tick,
        "lead": C.shakuhachi_post(midi["lead"], -36.0, seed=511),
        "pad": C.koto_post(midi["pad"], seed=512),
        "bass": C.guitar_post(midi["bass"]),
        "drums": S.mix(C.broken_skin_taiko(midi["drums"]), S.to_stereo(wb, 0.4) * S.db_to_amp(-10.0)),
    }
    C.balance(stems, {"box": -31.0, "tick": -39.0, "lead": -23.0, "pad": -26.0, "bass": -25.0, "drums": -23.5},
              ceilings={"drums": -7.0, "pad": -10.0, "bass": -8.0})
    tr.rtpc = {"sync_hold": "fade every stem except box to −inf over 0.15 s and mute tick",
               "shave_bonus": "pad stem +4 dB while shave_bonus = 1 (Boost Lv3)",
               "hitstop": "the war drum (drums stem) only on hitstop: play drums at −inf and open it for 0.3 s on each hitstop if the U1 night rule is wanted"}
    tr.notes = "Same skeleton as U0: shakuhachi scoops into the hook, koto −12 cents, taiko pitched down a minor third and saturated."
    return tr.finalize(stems, hiss_stem="drums", hiss_db=-60.0)


if __name__ == "__main__":
    for r in (build_u0(), build_u1()):
        print(r["id"], r["duration_s"], "s; loop from", r["loop_start_s"], "s; mix", r["mix"])
        for k, v in r["stems"].items():
            print(f"  {k:8s} {v['file']:34s} peak {v['peak_dbfs']:6.1f} lufs {v['lufs_i']}")
