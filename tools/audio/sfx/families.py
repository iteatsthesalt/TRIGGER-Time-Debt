"""Every vertical-slice SFX family (§8.6, §11.11), one build function per folder under audio/sfx/.
All files are WAV 48 kHz 16-bit, peak −1 dBFS; mono for positional sounds, stereo for UI and
full-screen time events; five numbered variations wherever a sound repeats."""
from __future__ import annotations

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import base as B  # noqa: E402
from base import S, SR, write_sfx, write_variations  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import music_box as MB  # noqa: E402
from motifs import TIME_CELL  # noqa: E402


# ----------------------------------------------------------------------------------------------
# UI — porcelain ticks for menus, a woodblock for the hour, an ink splash for the minute
# ----------------------------------------------------------------------------------------------

def build_ui() -> list[dict]:
    out = []
    g = S.rng(1000)
    f = "ui"
    out.append(write_sfx(f, "cursor", B.porcelain_tink(g, 5200.0, 0.06, 3), stereo=True))
    # confirm: two ticks rising a fourth, a soft ring
    x = S.mix(B.porcelain_tink(g, 4200.0, 0.08), S.place(np.zeros(S.samples(0.3)), B.porcelain_tink(g, 5600.0, 0.11), 0.07, 0.9))
    out.append(write_sfx(f, "confirm", x, stereo=True))
    x = S.mix(B.porcelain_tink(g, 4800.0, 0.07), S.place(np.zeros(S.samples(0.25)), B.porcelain_tink(g, 3300.0, 0.1), 0.06, 0.8))
    out.append(write_sfx(f, "cancel", x, stereo=True))
    # open: a brass lid lifting — a short whoosh into a tink and a small chime bloom
    x = S.mix(B.whoosh(g, 0.22, 500.0, 2600.0, 3.0, 0.5) * 0.6, S.place(np.zeros(S.samples(0.6)), B.porcelain_tink(g, 3900.0, 0.12), 0.17),
              S.place(np.zeros(S.samples(0.6)), B.bell(g, 2637.0, 0.45, 0.6) * 0.35, 0.2))
    out.append(write_sfx(f, "open", S.reverb(x, 0.9, 0.18, 0.0, 6000.0, seed=1001, tail=True), stereo=True))
    x = S.mix(S.place(np.zeros(S.samples(0.4)), B.whoosh(g, 0.2, 2200.0, 500.0, 3.0, 0.4) * 0.5, 0.0),
              S.place(np.zeros(S.samples(0.4)), B.woodblock(g, 620.0, 0.1) * 0.7, 0.14))
    out.append(write_sfx(f, "close", x, stereo=True))
    out.append(write_sfx(f, "page", B.paper_rustle(g, 0.28) * S.swell(0.28, 0.3, 0.8), stereo=True))
    # error: a dull porcelain thud with a low buzz — the material refusing
    t = S.t_axis(0.3)
    buzz = np.sign(np.sin(S.TWO_PI * 110.0 * t)) * np.exp(-t * 12.0) * 0.4
    buzz = S.lowpass(buzz, 900.0, 2)
    thud = S.lowpass(g.standard_normal(len(t)), 500.0, 2) * np.exp(-t * 40.0)
    out.append(write_sfx(f, "error", S.mix(thud, buzz, B.porcelain_tink(g, 2100.0, 0.09, 2) * 0.4), stereo=True))
    # save: the woodblock for the hour, then the ink splash for the minute
    splash = S.swept_bandpass(S.noise(0.35, "white", g), 3000.0, 900.0, 3.0, 128) * S.exp_decay(0.35, 9.0, 0.003)
    drops = np.zeros(S.samples(0.6))
    for k in range(5):
        tt = S.t_axis(0.09)
        drop = np.sin(S.TWO_PI * (1400.0 + 500 * g.uniform()) * (1 - 0.3 * tt) * tt) * np.exp(-tt * 40)
        S.place(drops, drop, 0.12 + 0.08 * k + g.uniform(0, 0.03), 0.3 - 0.04 * k)
    x = S.mix(B.woodblock(g, 760.0, 0.14), S.place(np.zeros(S.samples(0.9)), splash, 0.16, 0.7), S.place(np.zeros(S.samples(0.9)), drops, 0.18))
    out.append(write_sfx(f, "save", S.reverb(x, 1.1, 0.2, 0.0, 5000.0, seed=1002), stereo=True))
    # sync_hold_freeze: three ticks, the fourth does not come; a wind chime answers in the hole
    ticks = np.zeros(S.samples(1.6))
    for k in range(3):
        S.place(ticks, B.clock_tick(g, 1.0), 0.0 + k * 0.2083, 0.8 - 0.1 * k)
    chime = np.zeros(S.samples(1.6))
    for k, m in enumerate([TIME_CELL[2], TIME_CELL[3], TIME_CELL[1]]):
        S.place(chime, MB.tine(S.midi_to_hz(m + 12), 1.0, 0.6, 1.1, g.uniform(-3, 3), g), 0.72 + 0.09 * k)
    x = S.mix(ticks, S.reverb(chime, 2.2, 0.4, 0.0, 7000.0, seed=1003) * 0.9)
    out.append(write_sfx(f, "sync_hold_freeze", x, stereo=True))
    # door: a wooden creak (a slow pulse through a wooden body) and the latch
    t = S.t_axis(0.7)
    creak_f = 90.0 + 60.0 * S.swell(0.7, 0.4, 1.0) + 8 * np.sin(S.TWO_PI * 11 * t)
    creak = S.pulse_train(creak_f, 0.7, 0.08)
    creak = S.resonant_bandpass(creak, 520.0, 5.0) + 0.5 * S.resonant_bandpass(creak, 1300.0, 7.0)
    creak *= S.swell(0.7, 0.5, 1.2) * 0.6
    latch = S.place(np.zeros(S.samples(1.0)), B.woodblock(g, 420.0, 0.14) * 0.8, 0.62)
    latch = S.place(latch, S.lowpass(g.standard_normal(S.samples(0.05)), 2500.0, 2) * S.exp_decay(0.05, 90.0) * 0.6, 0.6)
    out.append(write_sfx(f, "door", S.reverb(S.mix(creak, latch), 1.2, 0.2, 0.0, 4000.0, seed=1004), stereo=True))
    # tube: a pneumatic tube — a sucked whoosh, a glass clink arriving, a hiss of release
    suck = B.whoosh(g, 0.6, 400.0, 1800.0, 2.5, 0.75)
    clink = S.place(np.zeros(S.samples(1.2)), B.porcelain_tink(g, 3100.0, 0.14, 4), 0.58)
    hissr = S.place(np.zeros(S.samples(1.2)), S.highpass(S.noise(0.35, "pink", g), 2500.0, 2) * S.exp_decay(0.35, 8.0, 0.01) * 0.4, 0.62)
    out.append(write_sfx(f, "tube", S.mix(suck, clink, hissr), stereo=True))
    return out


# ----------------------------------------------------------------------------------------------
# Combat core — the shield tells you everything by ear
# ----------------------------------------------------------------------------------------------

def build_combat() -> list[dict]:
    out = []
    f = "combat"
    # shield_chip: ceramic chip, pitch rising per hit (variation index = hit number)
    def chip(gen, i):
        ratio = 2.0 ** (i * 1.5 / 12.0)
        return S.mix(B.crack(gen, 0.15, 0.14) * 0.9, B.porcelain_tink(gen, 3600.0 * ratio, 0.1, 4) * 0.8)
    out += write_variations(f, "shield_chip", chip, 5, seed=1100)
    g = S.rng(1101)
    # weak_bell: 1.3× brighter than the neutral hit
    out.append(write_sfx(f, "weak_bell", S.mix(B.bell(g, 2093.0, 0.9, 1.3), B.porcelain_tink(g, 4400.0, 0.08) * 0.5)))
    # break: a gong and a vinyl crack
    vinyl = S.bandpass(g.standard_normal(S.samples(0.05)) * S.exp_decay(0.05, 110.0, 0.0005), 800.0, 9000.0, 1)
    gongx = B.gong(g, 98.0, 3.2, 1.2)
    x = S.mix(S.place(np.zeros(S.samples(3.3)), vinyl, 0.0, 0.9), S.place(np.zeros(S.samples(3.3)), gongx, 0.03))
    out.append(write_sfx(f, "break_gong_vinyl", S.reverb(x, 2.4, 0.3, 0.0, 5000.0, seed=1102)))
    # shield_rebuild: shards fly back (reversed spill) into a settled porcelain chord
    spill = B.shard_spill(g, 1.0, 22)[::-1]
    chord = np.zeros(S.samples(1.6))
    for k, m in enumerate([72, 76, 79]):
        S.place(chord, MB.tine(S.midi_to_hz(m), 1.2, 0.7, 1.0, 0.0, g), 0.95 + 0.03 * k)
    out.append(write_sfx(f, "shield_rebuild", S.mix(spill * 0.8, chord)))
    # bp gain / spend: a glass coin tink rising / falling
    out.append(write_sfx(f, "bp_gain", S.mix(B.porcelain_tink(g, 3000.0, 0.1), S.place(np.zeros(S.samples(0.4)), B.porcelain_tink(g, 4500.0, 0.14), 0.08, 0.9))))
    out.append(write_sfx(f, "bp_spend", S.mix(B.porcelain_tink(g, 4500.0, 0.1), S.place(np.zeros(S.samples(0.4)), B.porcelain_tink(g, 3000.0, 0.14), 0.08, 0.9))))
    # boost levels: Gaspar's coin pitched up a whole step per level
    for lv in range(1, 5):
        gen = S.rng(1110 + lv)
        x = B.coin(gen, 2.0 * (lv - 1), 0.9 + 0.15 * lv)
        if lv == 3:  # the +1 shave: a crystalline spill glints on top (shave_bonus brightness)
            x = S.mix(x, B.shard_spill(gen, 0.6, 10, 5200.0) * 0.35)
        if lv == 4:
            x = S.mix(x, B.sub_thump(gen, 44.0, 0.5) * 0.5)
        out.append(write_sfx(f, f"boost_lv{lv}", x))
    # telegraph_loop: a resonant throb that pulses at the floor ring's rate (sin(TIME*6) → 1.047 s)
    period = 2 * np.pi / 6.0
    t = S.t_axis(period)
    pulse = 0.5 + 0.5 * np.sin(S.TWO_PI * t / period - np.pi / 2)
    tone = np.sin(S.TWO_PI * 196.0 * t) * 0.5 + np.sin(S.TWO_PI * 392.0 * t) * 0.3 + S.lowpass(S.noise(period, "pink", g), 800.0, 2) * 0.3
    tele = tone * pulse ** 1.5
    out.append(write_sfx(f, "telegraph_loop", tele, loop=True))
    # statue_shatter: the gold porcelain statue goes — a large crack, a gong-ish body, a long spill
    x = S.mix(B.crack(g, 1.0, 0.7), S.place(np.zeros(S.samples(2.4)), B.shard_spill(g, 1.8, 40, 3200.0), 0.12, 0.9),
              S.place(np.zeros(S.samples(2.4)), B.sub_thump(g, 52.0, 0.6), 0.0, 0.7))
    out.append(write_sfx(f, "statue_shatter", S.reverb(x, 1.8, 0.25, 0.0, 6000.0, seed=1103)))
    return out


# ----------------------------------------------------------------------------------------------
# Porcelain — one crack sound shared by every porcelain thing
# ----------------------------------------------------------------------------------------------

def build_porcelain() -> list[dict]:
    out = []
    f = "porcelain"
    out += write_variations(f, "tink", lambda gen, i: B.porcelain_tink(gen, 3400.0 + 900.0 * gen.uniform(), 0.08, 4), 5, seed=1200)
    out += write_variations(f, "crack_small", lambda gen, i: B.crack(gen, 0.2 + 0.1 * gen.uniform()), 5, seed=1201)
    out += write_variations(f, "crack_large", lambda gen, i: S.mix(B.crack(gen, 0.85 + 0.15 * gen.uniform()),
                                                                     S.place(np.zeros(S.samples(1.2)), B.shard_spill(gen, 0.9, 14), 0.1, 0.6)), 5, seed=1202)
    g = S.rng(1203)
    out.append(write_sfx(f, "crystalline_spill", B.shard_spill(g, 1.6, 36)))
    # galaxy hums: 432 Hz pristine, 220 Hz once the crack mask passes 60% — seamless 6 s loops
    for hz in (432.0, 220.0):
        dur = 7.0  # one extra second is cross-faded away so the noise band loops too
        t = S.t_axis(dur)
        s = np.sin(S.TWO_PI * hz * t) * 0.6 + np.sin(S.TWO_PI * hz * 2.0 * t) * 0.15 + np.sin(S.TWO_PI * hz * 0.5 * t) * (0.25 if hz < 300 else 0.1)
        s *= 1.0 + 0.08 * np.sin(S.TWO_PI * (1.0 / 3.0) * t) + 0.04 * np.sin(S.TWO_PI * 5.1 * t)
        s += S.bandpass(S.noise(dur, "pink", g), hz * 1.9, hz * 2.1, 2) * 0.12 * (0.5 + 0.5 * np.sin(S.TWO_PI * (1.0 / 3.0) * t + 1))
        s = S.crossfade_loop(s, 1.0)
        out.append(write_sfx(f, f"galaxy_hum_{int(hz)}", s, loop=True))
    # wind_chime_crack: a chime cluster breaks mid-ring
    chimes = np.zeros(S.samples(1.8))
    for k, m in enumerate([84, 88, 91, 95, 96]):
        S.place(chimes, MB.tine(S.midi_to_hz(m), 1.2, 0.6, 1.2, g.uniform(-6, 6), g), 0.05 * k + g.uniform(0, 0.03))
    chimes = S.place(chimes, B.crack(g, 0.4, 0.3) * 0.9, 0.42)
    chimes[S.samples(0.42):] *= np.exp(-np.arange(len(chimes) - S.samples(0.42)) / SR * 6.0)
    out.append(write_sfx(f, "wind_chime_crack", chimes))
    return out


# ----------------------------------------------------------------------------------------------
# Weapons — material first, then the impact tier is read from the shield sounds
# ----------------------------------------------------------------------------------------------

def build_weapons() -> list[dict]:
    out = []
    f = "weapons"

    def crono(gen, i):  # brush on paper and a tide swell
        brush = B.brush_on_paper(gen, 0.13 + 0.03 * gen.uniform(), 900.0, 5600.0, 0.45)
        tide = B.tide_swell(gen, 0.55, 240.0 + 40 * gen.uniform())
        return S.mix(brush, S.place(np.zeros(S.samples(0.65)), tide, 0.04, 0.8))

    def sera(gen, i):  # ticking clock hands and a ribbon whoosh
        ticks = np.zeros(S.samples(0.5))
        for k in range(3):
            S.place(ticks, B.clock_tick(gen, 1.0 + 0.1 * k), 0.0 + k * 0.055 + gen.uniform(0, 0.01), 0.9 - 0.15 * k)
        rib = B.whoosh(gen, 0.3, 900.0 + 300 * gen.uniform(), 3600.0, 5.0, 0.5)
        return S.mix(ticks, S.place(np.zeros(S.samples(0.5)), rib, 0.1, 0.9))

    def krona(gen, i):  # brush on paper, never metal, and a submerged gong
        brush = B.brush_on_paper(gen, 0.18 + 0.04 * gen.uniform(), 500.0, 4200.0, 0.35)
        gongx = B.gong(gen, 82.0 + 8 * gen.uniform(), 1.6, 0.7, submerged=True)
        return S.mix(brush, S.place(np.zeros(S.samples(1.7)), gongx, 0.09, 0.85))

    out += write_variations(f, "crono_slash", crono, 5, seed=1300)
    out += write_variations(f, "sera_dagger", sera, 5, seed=1301)
    out += write_variations(f, "krona_nodachi", krona, 5, seed=1302)
    return out


# ----------------------------------------------------------------------------------------------
# Magic — gesture, travel, contact, tail for ASTRAL, TACHYON and RUIN
# ----------------------------------------------------------------------------------------------

def build_magic() -> list[dict]:
    out = []
    f = "magic"
    g = S.rng(1400)
    # ASTRAL: paper fizz high, tide low
    fizz = S.highpass(S.noise(0.6, "white", g), 4000.0, 2) * np.abs(S.one_pole_lp(g.standard_normal(S.samples(0.6)), 60.0)) * 10 * S.swell(0.6, 0.7, 1.2)
    out.append(write_sfx(f, "astral_gesture", S.mix(fizz, B.tide_swell(g, 0.6, 220.0) * 0.7)))
    trav = S.mix(S.highpass(S.noise(0.5, "white", g), 5000.0, 2) * 0.5 * S.swell(0.5, 0.5, 1.0), B.whoosh(g, 0.5, 300.0, 900.0, 2.0, 0.6))
    out.append(write_sfx(f, "astral_travel", trav))
    contact = S.mix(B.brush_on_paper(g, 0.12, 1200.0, 7000.0, 0.2), B.tide_swell(g, 0.4, 300.0) * 0.9, B.porcelain_tink(g, 5200.0, 0.06, 3) * 0.3)
    out.append(write_sfx(f, "astral_contact", contact))
    tail = S.mix(S.highpass(S.noise(1.4, "pink", g), 3500.0, 2) * S.exp_decay(1.4, 2.5, 0.02) * 0.5, B.tide_swell(g, 1.4, 180.0) * S.exp_decay(1.4, 1.5, 0.05))
    out.append(write_sfx(f, "astral_tail", S.reverb(tail, 1.6, 0.3, 0.0, 5000.0, seed=1401)))
    # TACHYON: reversed tape, harp, the seven-layer whisper
    rev = S.wow_flutter(B.harp_pluck(g, 659.0, 0.7), 20.0, 1.5, 8.0, 7.0, seed=1402)[::-1]
    out.append(write_sfx(f, "tachyon_gesture", S.mix(rev, B.whisper(g, 0.7, 3, reverse=True) * 0.35)))
    harp_seq = np.zeros(S.samples(0.8))
    for k, m in enumerate([76, 71, 74, 71, 76]):
        S.place(harp_seq, B.harp_pluck(g, S.midi_to_hz(m), 0.5), 0.0 + k * 0.07, 0.8)
    out.append(write_sfx(f, "tachyon_travel", S.mix(harp_seq, B.whoosh(g, 0.6, 2000.0, 600.0, 3.0, 0.3)[::-1] * 0.5)))
    contact = S.mix(B.harp_pluck(g, 1318.0, 0.6), B.clock_tick(g, 1.2) * 0.8, S.place(np.zeros(S.samples(0.6)), B.clock_tick(g, 0.9) * 0.6, 0.06))
    out.append(write_sfx(f, "tachyon_contact", contact))
    out.append(write_sfx(f, "tachyon_tail", S.reverb(B.whisper(g, 1.3, 7), 2.4, 0.4, 0.0, 6000.0, seed=1403)))
    # RUIN: brush on paper, a submerged gong
    out.append(write_sfx(f, "ruin_gesture", S.mix(B.brush_on_paper(g, 0.3, 400.0, 3800.0, 0.6), B.sub_thump(g, 40.0, 0.5) * 0.4)))
    out.append(write_sfx(f, "ruin_travel", S.mix(B.whoosh(g, 0.45, 300.0, 1400.0, 3.0, 0.5), B.paper_tear(g, 0.45) * 0.4)))
    out.append(write_sfx(f, "ruin_contact", S.mix(B.brush_on_paper(g, 0.1, 800.0, 5000.0, 0.15), B.gong(g, 78.0, 1.4, 0.8, True) * 0.9)))
    out.append(write_sfx(f, "ruin_tail", S.reverb(S.mix(B.gong(g, 70.0, 2.2, 0.5, True), B.paper_tear(g, 0.6) * 0.25 * S.exp_decay(0.6, 3.0)), 2.0, 0.35, 0.0, 3000.0, seed=1404)))
    return out


# ----------------------------------------------------------------------------------------------
# Footsteps — one material per canvas
# ----------------------------------------------------------------------------------------------

def build_footsteps() -> list[dict]:
    out = []
    f = "footsteps"

    def ceramic(gen, i):  # Crono's foot: a ceramic tap, not a boot
        tap = B.porcelain_tink(gen, 1900.0 + 500 * gen.uniform(), 0.07, 3) * 0.7
        body = S.lowpass(gen.standard_normal(S.samples(0.08)), 1400.0, 2) * S.exp_decay(0.08, 70.0, 0.001)
        return S.mix(body, tap)

    def moss(gen, i):  # mossy stone: a soft crunch, low thud
        crunch = S.bandpass(gen.standard_normal(S.samples(0.16)), 600.0, 4000.0, 2) * np.abs(S.one_pole_lp(gen.standard_normal(S.samples(0.16)), 250.0)) * 8 * S.exp_decay(0.16, 24.0, 0.003)
        thud = S.lowpass(gen.standard_normal(S.samples(0.12)), 220.0, 2) * S.exp_decay(0.12, 40.0, 0.002)
        return S.mix(crunch * 0.7, thud)

    def woodblock(gen, i):  # U1 woodblock stamp
        return S.mix(B.woodblock(gen, 560.0 + 120 * gen.uniform(), 0.13), S.lowpass(gen.standard_normal(S.samples(0.1)), 400.0, 2) * S.exp_decay(0.1, 50.0) * 0.6)

    out += write_variations(f, "u0_ceramic", ceramic, 5, seed=1500)
    out += write_variations(f, "u0_moss", moss, 5, seed=1501)
    out += write_variations(f, "u1_woodblock", woodblock, 5, seed=1502)
    return out


# ----------------------------------------------------------------------------------------------
# Time and portals — one fingerprint transformed by scale and state
# ----------------------------------------------------------------------------------------------

def fingerprint(gen: np.random.Generator, scale: float = 1.0, pitch_semis: float = 0.0, breath: float = 1.0, shimmer_amt: float = 1.0) -> np.ndarray:
    """A reversed music-box tine sucked into a deep breath, then released as a bright shimmer."""
    pre = B.reversed_tine(gen, 72 + int(pitch_semis), 0.7 * scale)
    br = B.breath_in(gen, 0.7 * scale) * breath
    release = B.shimmer(gen, 1.1 * scale, 1800.0 * 2 ** (pitch_semis / 12.0), int(10 + 8 * scale)) * shimmer_amt
    click = B.clock_tick(gen, 1.0)
    L = 0.7 * scale + 1.3 * scale
    out = np.zeros(S.samples(L))
    S.place(out, pre, 0.0, 0.8)
    S.place(out, br, 0.05 * scale, 0.9)
    S.place(out, click, 0.7 * scale, 0.9)
    S.place(out, release, 0.72 * scale, 0.9)
    return out


def build_time() -> list[dict]:
    out = []
    f = "time"
    g = S.rng(1600)
    # chronoslip: the fingerprint at full scale with a heartbeat drop and the thermals opening
    x = fingerprint(g, 1.3, 0, 1.0, 1.0)
    x = S.mix(x, S.place(np.zeros(S.samples(2.8)), B.sub_thump(g, 42.0, 0.7), 0.9, 0.8))
    out.append(write_sfx(f, "chronoslip", S.reverb(x, 2.0, 0.3, 0.0, 6000.0, seed=1601), stereo=True))
    # gates: U0 is the clean fingerprint; U1 is dry-brushed (band-passed, a paper snap)
    out.append(write_sfx(f, "gate_open_u0", S.reverb(fingerprint(g, 1.0, 0, 0.8, 1.0), 1.6, 0.25, 0.0, 6000.0, seed=1602)))
    u1 = S.bandpass(fingerprint(g, 1.0, -5, 0.6, 0.6), 300.0, 5000.0, 1)
    u1 = S.mix(u1, S.place(np.zeros(S.samples(2.0)), B.paper_tear(g, 0.3) * 0.6, 0.65), S.place(np.zeros(S.samples(2.0)), B.brush_on_paper(g, 0.3, 500.0, 4000.0), 0.0, 0.7))
    out.append(write_sfx(f, "gate_open_u1", S.reverb(u1, 1.2, 0.2, 0.0, 4000.0, seed=1603)))
    # amber rift: the fingerprint slowed and thickened, with a sticky resonance
    rift = S.resample_speed(fingerprint(g, 1.0, -7, 1.0, 0.7), 0.7)
    rift = S.mix(rift, S.resonant_bandpass(rift, 330.0, 8.0) * 0.6, S.lowpass(S.noise(len(rift) / SR, "brown", g), 200.0, 2) * S.swell(len(rift) / SR, 0.5, 1.0) * 0.4)
    out.append(write_sfx(f, "amber_rift", S.reverb(rift, 2.0, 0.3, 0.0, 3500.0, seed=1604)))
    # universe_switch: exactly 0.8 s — the fingerprint compressed to the blend time, a snap at the end
    sw = S.fit_length(S.resample_speed(fingerprint(g, 0.5, 0, 0.8, 1.0), 1.0), S.samples(0.8))
    sw = S.fade(sw, 0.0, 0.08)
    sw = S.place(sw, B.clock_tick(g, 1.4) * 0.7, 0.76)
    out.append(write_sfx(f, "universe_switch", sw, stereo=True))
    # fracture_sky: a vast crack across the sky — the porcelain crack at giant scale, a sub drop, shards falling far away
    big = S.resample_speed(B.crack(g, 1.0, 0.9), 0.45)
    x = S.mix(big, S.place(np.zeros(S.samples(4.0)), B.sub_thump(g, 36.0, 1.2), 0.1), S.place(np.zeros(S.samples(4.0)), S.lowpass(B.shard_spill(g, 2.2, 40, 2400.0), 4000.0, 1) * 0.6, 0.6))
    out.append(write_sfx(f, "fracture_sky", S.reverb(x, 3.5, 0.4, 0.02, 3500.0, seed=1605), stereo=True))
    # rewind: the Time cell backwards with tape wobble, climbing; fast_forward: the cell twice as fast with flutter, a chirp
    cell = np.zeros(S.samples(1.6))
    for k, m in enumerate(TIME_CELL):
        S.place(cell, MB.tine(S.midi_to_hz(m), 0.8, 0.8, 1.0, 0.0, g), k * 0.14)
    rew = S.wow_flutter(cell[::-1], 30.0, 2.0, 10.0, 8.0, seed=1606)
    rew = S.resample_speed(rew, np.linspace(0.8, 1.6, len(rew)))
    out.append(write_sfx(f, "rewind", S.mix(rew, B.whoosh(g, len(rew) / SR, 400.0, 3000.0, 3.0, 0.8) * 0.4), stereo=True))
    ff = S.resample_speed(cell, 2.0)
    ff = S.wow_flutter(ff, 10.0, 3.0, 20.0, 12.0, seed=1607)
    out.append(write_sfx(f, "fast_forward", S.mix(ff, S.highpass(S.noise(len(ff) / SR, "white", g), 6000.0, 2) * 0.25), stereo=True))
    # tape_stop: the cell stops over 0.4 s
    ts = S.tape_stop(cell * 0.9, 0.5, 0.4)
    out.append(write_sfx(f, "tape_stop", S.fit_length(ts, S.samples(1.3)), stereo=True))
    return out


# ----------------------------------------------------------------------------------------------
# Status and hazards — each status has a loop that matches its icon
# ----------------------------------------------------------------------------------------------

def loopable(x: np.ndarray, xf_s: float = 0.5) -> np.ndarray:
    return S.crossfade_loop(x, xf_s)


def build_status() -> list[dict]:
    out = []
    f = "status"
    g = S.rng(1700)
    # grief_whisper: reversed whispers over a 28–40 Hz sub (6 s loop)
    dur = 6.5
    wh = np.zeros(S.samples(dur))
    for k in range(5):
        S.place(wh, B.whisper(g, 0.9 + 0.5 * g.uniform(), 3, reverse=True), 0.2 + k * 1.15 + g.uniform(0, 0.2), 0.5 + 0.4 * g.uniform())
    t = S.t_axis(dur)
    sub = np.sin(S.TWO_PI * np.cumsum(34.0 + 6.0 * np.sin(S.TWO_PI * t / dur)) / SR) * 0.7
    x = S.mix(S.reverb(wh, 2.0, 0.5, 0.0, 4000.0, seed=1701, tail=False) * 0.6, sub)
    out.append(write_sfx(f, "grief_whisper", loopable(x, 0.5), loop=True))
    # vhs_fog: hiss with wow and flutter, a tracking tear now and then (6 s loop)
    hz = S.tape_hiss(6.5, -14.0, seed=1702, stereo=False) + S.lowpass(S.noise(6.5, "pink", g), 600.0, 2) * 0.3
    hz = S.wow_flutter(hz, 25.0, 0.7, 8.0, 7.0, seed=1703)
    hz = S.vhs_tear(hz, 2.1, -200.0, 0.35)
    hz = S.vhs_tear(hz, 4.6, -200.0, 0.3)
    out.append(write_sfx(f, "vhs_fog", loopable(hz, 0.5), loop=True))
    # mercury_slosh: a heavy liquid — low-passed noise with pitch wobble and wet resonances (4 s loop)
    dur = 4.5
    t = S.t_axis(dur)
    slosh = S.lowpass(S.noise(dur, "pink", g), 900.0, 2) * (0.5 + 0.5 * np.sin(S.TWO_PI * 0.9 * t + 1.0) * np.sin(S.TWO_PI * 0.37 * t)) ** 2
    slosh = S.resample_speed(slosh, 2.0 ** (12.0 * np.sin(S.TWO_PI * 0.9 * t) / 1200.0))
    slosh = S.fit_length(slosh, S.samples(dur))
    glug = np.zeros(S.samples(dur))
    for k in range(7):
        tt = S.t_axis(0.12)
        fr = (420.0 + 300 * g.uniform()) * (1 - 0.5 * tt / 0.12)
        S.place(glug, np.sin(S.TWO_PI * np.cumsum(fr) / SR) * np.exp(-tt * 25), g.uniform(0, dur - 0.2), 0.35)
    out.append(write_sfx(f, "mercury_slosh", loopable(S.mix(slosh, S.lowpass(glug, 1500.0, 2)), 0.5), loop=True))
    # ruin_tear: paper tearing in slow pulses (4 s loop)
    dur = 4.5
    tear = np.zeros(S.samples(dur))
    for k in range(6):
        S.place(tear, B.paper_tear(g, 0.35 + 0.3 * g.uniform()), k * 0.7 + g.uniform(0, 0.1), 0.5 + 0.5 * g.uniform())
    out.append(write_sfx(f, "ruin_tear", loopable(S.mix(tear, S.lowpass(S.noise(dur, "brown", g), 150.0, 2) * 0.25), 0.5), loop=True))
    # oil_drip: drops in a resonant space (6 s loop)
    dur = 6.5
    drips = np.zeros(S.samples(dur))
    for k in range(8):
        tt = S.t_axis(0.16)
        fr = (900.0 + 700 * g.uniform()) * (1 + 0.8 * np.exp(-tt * 40)) * (1 - 0.25 * tt / 0.16)
        d = np.sin(S.TWO_PI * np.cumsum(fr) / SR) * np.exp(-tt * 22) * np.minimum(1.0, tt * 600)
        S.place(drips, S.lowpass(d, 3000.0, 1), g.uniform(0.1, dur - 0.4), 0.4 + 0.6 * g.uniform())
    x = S.reverb(drips, 2.6, 0.5, 0.0, 3000.0, seed=1704, tail=False)
    out.append(write_sfx(f, "oil_drip", loopable(S.mix(x, S.lowpass(S.noise(dur, "brown", g), 120.0, 2) * 0.2), 0.5), loop=True))
    return out


# ----------------------------------------------------------------------------------------------
# Creatures — U0 dust wash and porcelain; U1 brush hiss and paper rustle
# ----------------------------------------------------------------------------------------------

def build_creatures() -> list[dict]:
    out = []
    f = "creatures"

    def u0(gen, i):
        dur = 0.5 + 0.3 * gen.uniform()
        wash = S.bandpass(S.noise(dur, "pink", gen), 300.0 + 400 * gen.uniform(), 2500.0, 2) * S.swell(dur, 0.4 + 0.3 * gen.uniform(), 1.4)
        ring = B.porcelain_tink(gen, 2400.0 + 1800 * gen.uniform(), 0.2, 3) * 0.4
        ring = S.place(np.zeros(S.samples(dur)), ring, dur * 0.3)
        # a hollow voice: formant noise with a pitch (the shardling's mouth)
        voice = S.pulse_train(220.0 + 160 * gen.uniform(), dur, 0.1)
        voice = S.resonant_bandpass(voice, 700.0 + 300 * gen.uniform(), 6.0) * S.swell(dur, 0.5, 2.0) * 0.4
        return S.mix(wash, ring, voice)

    def u1(gen, i):
        dur = 0.45 + 0.3 * gen.uniform()
        hiss = B.brush_on_paper(gen, dur, 1500.0, 7000.0, 0.3 + 0.4 * gen.uniform())
        rustle = B.paper_rustle(gen, dur * 0.8) * 0.7
        growl = S.pulse_train(70.0 + 40 * gen.uniform(), dur, 0.15)
        growl = S.lowpass(S.resonant_bandpass(growl, 400.0, 4.0), 1800.0, 2) * S.swell(dur, 0.4, 1.5) * 0.5
        return S.mix(hiss, rustle, growl)

    out += write_variations(f, "u0_voice", u0, 5, seed=1800)
    out += write_variations(f, "u1_voice", u1, 5, seed=1801)
    return out


FAMILIES = {
    "ui": build_ui, "combat": build_combat, "porcelain": build_porcelain, "weapons": build_weapons, "magic": build_magic,
    "footsteps": build_footsteps, "time": build_time, "status": build_status, "creatures": build_creatures,
}


def build_all(only: str | None = None) -> list[dict]:
    out = []
    for name, fn in FAMILIES.items():
        if only and only not in name:
            continue
        res = fn()
        for r in res:
            r["family"] = name
        out += res
        print(f"  sfx/{name}: {len(res)} files")
    return out


if __name__ == "__main__":
    import sys as _s
    res = build_all(_s.argv[1] if len(_s.argv) > 1 else None)
    for r in res:
        print(f"{r['file']:52s} {r['duration_s']:6.2f}s ch{r['channels']} peak {r['peak_dbfs']:5.1f} rms {r['rms_dbfs']:6.1f}")
