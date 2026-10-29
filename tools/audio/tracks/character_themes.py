"""mus_vaelos_theme and mus_sera_theme (§8.5).

Vaelos: 68 BPM, 4/4, C Locrian. Contrabassoon C2 → G♭2 pulsing on every beat (bassoon plus a
sub octave), a clean boyish tenor humming Crono's cell a quarter-tone flat, the marrow pump at
0.8 Hz and the grief_resonance drone between 28 and 40 Hz. Stems: bass, lead, pad.

Sera: 72 BPM, 4/4, E minor. Harp on her palindrome cell, reversed shamisen, a double voice
from other timelines. Stems: lead (harp), pad (reversed shamisen + warm pad), strings (voices,
scaled by translucency)."""
from __future__ import annotations

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402
from common import S  # noqa: E402
from score import GM, n, chord_notes  # noqa: E402
from motifs import crono_cell, sera_cell, vaelos_pulse, SERA_CELL  # noqa: E402


# ----------------------------------------------------------------------------------------------
# Vaelos
# ----------------------------------------------------------------------------------------------

def build_vaelos() -> dict:
    tr = C.Track("mus_vaelos_theme", 68, 4, [("intro", 4), ("a", 8), ("bridge", 4), ("b", 8), ("coda", 4)], "C Locrian")
    sc = tr.score
    CH_BSN, CH_VOX, CH_VOX2, CH_PAD = 0, 1, 2, 3
    sc.program(CH_BSN, GM["bassoon"]); sc.program(CH_VOX, GM["voice_oohs"]); sc.program(CH_VOX2, GM["synth_voice"])
    sc.program(CH_PAD, GM["slow_strings"])
    sc.pan(CH_VOX, 58); sc.pan(CH_VOX2, 70); sc.pan(CH_PAD, 64)
    L = tr.render_length_s()
    # the tenor hum a quarter-tone flat (−50 cents), the synth voice doubling −50 + a 6 cent waver
    sc.bend_cents(CH_VOX, -50.0, 0.0)
    for k in range(tr.total_bars * 2):
        sc.bend_cents(CH_VOX2, -50.0 + 6.0 * np.sin(0.8 * k), k * 2.0)

    # contrabassoon pulse: C2 bars alternate with G♭2 bars from A; the intro pulses C only
    vaelos_pulse(sc, CH_BSN, tr.bar("intro", 0), 4, alternate_bars=False, vel=56)
    for sec in ("a", "bridge", "b", "coda"):
        vaelos_pulse(sc, CH_BSN, tr.bar(sec, 0), tr.bars_in(sec), alternate_bars=(sec != "b"), vel=66 if sec != "b" else 74)

    # the tenor hum: Crono's cell clean (even crotchets), each statement two bars long
    def hum(sec, bar, vel, q=1.0, hold=4.0):
        b = tr.bar(sec, bar)
        end = crono_cell(sc, CH_VOX, b, quaver=q, vel=vel, transpose=0, tired=False, legato=1.02)
        sc.note(CH_VOX, n("E4"), end, hold, vel - 4)  # the E stays
        crono_cell(sc, CH_VOX2, b, quaver=q, vel=vel - 18, transpose=0, tired=False, legato=1.02)

    hum("a", 2, 72); hum("a", 6, 74)
    hum("bridge", 0, 76, 2.0, 2.0)
    hum("b", 0, 80); hum("b", 2, 78); hum("b", 4, 82); hum("b", 6, 80)
    hum("coda", 1, 70)
    # Locrian pad: C–G♭–D♭ voicings, low and slow, in the bridge and B
    for sec, bars, vel in [("bridge", 4, 44), ("b", 8, 52), ("coda", 2, 40)]:
        for i in range(bars):
            b = tr.bar(sec, i)
            chord = [n("C3"), n("Gb3"), n("Db4")] if i % 2 == 0 else [n("Db3"), n("Gb3"), n("C4")]
            sc.chord(CH_PAD, chord, b, 3.95, vel, strum=0.0)

    midi = tr.midi_stems({"bsn": [CH_BSN], "lead": [CH_VOX, CH_VOX2], "pad": [CH_PAD]}, gain=0.6)
    # the contra octave: a sub sine following the bassoon's pulse grid
    sub_ev = []
    for bar in range(tr.total_bars):
        p = n("C1") if (bar < tr.section_bar["a"] or (bar - tr.section_bar["a"]) % 2 == 0 or tr.section_bar["b"] <= bar < tr.section_bar["coda"]) else n("Gb1")
        for beat in range(4):
            pitch = p if not (tr.section_bar["b"] <= bar < tr.section_bar["coda"]) else (n("C1") if beat % 2 == 0 else n("Gb1"))
            sub_ev.append((tr.s(bar * 4 + beat), pitch, 0.9 if beat == 0 else 0.7))
    sub = C.sub_808(sub_ev, L, 0.7, 4.0, seed=700)
    bass = S.mix(S.reverb(S.lowpass(midi["bsn"], 3200.0, 1), 2.4, 0.22, 0.02, 2500.0, seed=701), S.to_stereo(sub) * S.db_to_amp(-9.0))
    lead = S.reverb(midi["lead"], 3.2, 0.3, 0.03, 4000.0, seed=702)  # no plate: a wide, cold hall
    # marrow pump at 0.8 Hz and the grief drone 28–40 Hz, sweeping slowly
    pump = C.heartbeat([k * 1.25 for k in range(int(L / 1.25) + 1)], L, 48.0, seed=703)
    t = S.t_axis(L)
    drone_f = 34.0 + 6.0 * np.sin(S.TWO_PI * 0.011 * t) 
    drone = np.sin(S.TWO_PI * np.cumsum(drone_f) / S.SR) * (0.6 + 0.4 * np.sin(S.TWO_PI * 0.07 * t))
    pad = S.mix(S.reverb(midi["pad"], 3.0, 0.3, 0.02, 3000.0, seed=704), S.to_stereo(pump) * 1.4, S.to_stereo(drone) * 0.5)
    stems = {"bass": bass, "lead": lead, "pad": pad}
    tr.highpass_hz = 20.0  # the grief drone lives at 28–40 Hz
    C.balance(stems, {"bass": -25.0, "lead": -23.5, "pad": -28.0}, ceilings={"bass": -8.0})
    tr.rtpc = {"grief_resonance": "pad stem volume and the Sub bus: 28 Hz → −6 dB, 40 Hz → +3 dB; also opens the music low-pass to 800 Hz",
               "vaelos_near": "lay bass + pad under any world track (they phase at 68 against the hub's 72)",
               "heartbeat": "the pump is fixed at 0.8 Hz here; U8 drives it from the RTPC"}
    tr.notes = "Bassoon C2/G♭2 on every beat with a sub octave; tenor hum = Crono's cell even and clean, −50 cents; pump 0.8 Hz; drone 28–40 Hz."
    return tr.finalize(stems, hiss_stem="pad", hiss_db=-60.0)


# ----------------------------------------------------------------------------------------------
# Sera
# ----------------------------------------------------------------------------------------------

def build_sera() -> dict:
    tr = C.Track("mus_sera_theme", 72, 4, [("intro", 2), ("a", 8), ("bridge", 4), ("b", 8), ("coda", 4)], "E minor")
    sc = tr.score
    CH_HARP, CH_SHAM, CH_VOX, CH_VOX2, CH_PAD = 0, 1, 2, 3, 4
    sc.program(CH_HARP, GM["harp"]); sc.program(CH_SHAM, GM["shamisen"]); sc.program(CH_VOX, GM["voice_oohs"])
    sc.program(CH_VOX2, GM["voice_oohs"]); sc.program(CH_PAD, GM["warm_pad"])
    sc.pan(CH_HARP, 56); sc.pan(CH_VOX, 48); sc.pan(CH_VOX2, 80); sc.pan(CH_PAD, 64)
    sc.bend_cents(CH_VOX2, 9.0, 0.0)  # the second timeline's voice is 9 cents sharp
    L = tr.render_length_s()
    V = {"Em": (40, "min"), "C": (36, "maj"), "G": (43, "maj"), "D": (38, "maj"), "Bm": (47, "min"), "Am": (45, "min")}
    prog_a = ["Em", "C", "G", "D", "Em", "Bm", "C", "D"]
    prog_br = ["Am", "Em", "C", "D"]
    prog_b = ["Em", "C", "G", "D", "Em", "Bm", "Am", "D"]
    prog_coda = ["C", "D", "Em", "Em"]

    def harp_arp(sec, prog, vel, dense=False):
        for i, name in enumerate(prog):
            b = tr.bar(sec, i)
            root, q = V[name]
            notes = chord_notes(root + 12, q) + [root + 24]
            seq = [0, 1, 2, 3, 2, 1, 0, 1] if not dense else [0, 1, 2, 3, 2, 3, 1, 2, 0, 1, 2, 3, 2, 3, 1, 2]
            step = 0.5 if not dense else 0.25
            for k, idx in enumerate(seq):
                sc.note(CH_HARP, notes[idx], b + k * step, step * 2.2, vel - (0 if k % 2 == 0 else 10))

    # intro: the cell alone, twice (the second time reversed — it is the same)
    sera_cell(sc, CH_HARP, tr.bar("intro", 0), 0.5, 70)
    sera_cell(sc, CH_HARP, tr.bar("intro", 1), 0.5, 66, reverse=True)
    harp_arp("a", prog_a, 66)
    for bar in (0, 2, 4, 6):
        sera_cell(sc, CH_HARP, tr.bar("a", bar) + 2.0, 0.5, 78)
    harp_arp("bridge", prog_br, 58)
    sera_cell(sc, CH_HARP, tr.bar("bridge", 1), 1.0, 74, reverse=True)
    harp_arp("b", prog_b, 72, dense=True)
    for bar in (0, 2, 4, 6):
        sera_cell(sc, CH_HARP, tr.bar("b", bar), 0.5, 84, transpose=0 if bar < 4 else 12)
    harp_arp("coda", prog_coda, 56)
    sera_cell(sc, CH_HARP, tr.bar("coda", 2), 1.0, 64)
    # the double voice: the cell slow (crotchets) in the bridge and B, two timelines
    for sec, bar, vel in [("bridge", 0, 64), ("bridge", 2, 66), ("b", 0, 72), ("b", 2, 70), ("b", 4, 76), ("b", 6, 72), ("coda", 0, 60)]:
        b = tr.bar(sec, bar)
        for i, p in enumerate(SERA_CELL):
            sc.note(CH_VOX, p - 12, b + i * 1.0, 1.08, vel)
            sc.note(CH_VOX2, p - 12, b + i * 1.0 + 0.06, 1.08, vel - 8)
    # shamisen plucks on chord tones (to be reversed per bar) and a warm pad under B
    for sec, prog in [("a", prog_a), ("bridge", prog_br), ("b", prog_b), ("coda", prog_coda)]:
        for i, name in enumerate(prog):
            b = tr.bar(sec, i)
            root, q = V[name]
            notes = chord_notes(root + 24, q)
            for k, off in enumerate((0.0, 1.0, 2.0, 3.0)):
                sc.note(CH_SHAM, notes[k % 3], b + off, 0.9, 70 - 8 * (k % 2))
            if sec in ("b", "coda"):
                sc.chord(CH_PAD, chord_notes(root + 12, q), b, 3.95, 44)

    midi = tr.midi_stems({"lead": [CH_HARP], "sham": [CH_SHAM], "strings": [CH_VOX, CH_VOX2], "pad": [CH_PAD]}, gain=0.6)
    lead = S.reverb(midi["lead"], 2.4, 0.26, 0.015, 6000.0, seed=710)
    # reversed shamisen: flip each bar's audio so every pluck swells into the next downbeat
    sham = midi["sham"]
    bar_n = S.samples(tr.bar_s)
    rev = sham.copy()
    for k in range(int(len(sham) / bar_n)):
        seg = sham[k * bar_n: (k + 1) * bar_n]
        rev[k * bar_n: (k + 1) * bar_n] = seg[::-1]
    rev = S.wow_flutter(rev, 8.0, 0.5, 2.0, 6.0, seed=711)
    pad = S.mix(S.reverb(rev, 2.0, 0.3, 0.0, 4000.0, seed=712), S.reverb(midi["pad"], 3.0, 0.3, 0.02, 3000.0, seed=713) * S.db_to_amp(-3.0))
    # the voices: a second copy 25 ms late and the whole thing through a long, glassy hall
    vox = midi["strings"]
    d = S.samples(0.025)
    vox = vox + np.concatenate([np.zeros((d, 2)), vox[:-d]]) * 0.6
    strings = S.reverb(vox, 3.4, 0.32, 0.03, 5000.0, seed=714)
    stems = {"lead": lead, "pad": pad, "strings": strings}
    C.balance(stems, {"lead": -23.5, "pad": -28.0, "strings": -27.0}, ceilings={"lead": -8.0})
    tr.rtpc = {"translucency": "strings stem (the voices): 100 → −12 dB, 0 → +3 dB; below 50 add the Debt bus chorus (up to 7 voices)",
               "slip": "on a slip play the harp stem reversed (AudioStreamPlayer pitch −1 is not available: use the reversed section clip from the bridge)"}
    tr.notes = "Harp cell E5 B4 D5 B4 E5 (a palindrome: the bridge states it reversed and it sounds the same). Shamisen reversed per bar."
    return tr.finalize(stems, hiss_stem="pad", hiss_db=-60.0)


if __name__ == "__main__":
    for r in (build_vaelos(), build_sera()):
        print(r["id"], r["duration_s"], "s; loop from", r["loop_start_s"], "s; mix", r["mix"])
        for k, v in r["stems"].items():
            print(f"  {k:8s} {v['file']:34s} peak {v['peak_dbfs']:6.1f} lufs {v['lufs_i']}")
