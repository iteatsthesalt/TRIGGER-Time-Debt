"""The motif cells of TRIGGER: Time Debt (Reference Bible §8.3). Every cell is original.

A cell is a list of (pitch_midi, duration_in_quavers) pairs; None is a rest. Helpers lay a cell
into a Score at a tempo-independent position so each track can re-time and re-voice it.
"""
from __future__ import annotations

from score import Score, n

# Time ("Wind Scene 1024"): E4 G4 C5 B4 · G4 E4 D4 C4, even quavers at 72 BPM.
TIME_CELL = [n("E4"), n("G4"), n("C5"), n("B4"), n("G4"), n("E4"), n("D4"), n("C4")]
# World (Truce): D4 F4 A4 G4 E4, D Dorian, the last note held.
WORLD_CELL = [n("D4"), n("F4"), n("A4"), n("G4"), n("E4")]
# Threat (Vaelos): C2 → G♭2, the diminished fifth, pulsing at 68 BPM.
VAELOS_CELL = [n("C2"), n("Gb2")]
# Crono: G3 C4 D4 E4, the second note held 300 ms too long.
CRONO_CELL = [n("G3"), n("C4"), n("D4"), n("E4")]
# Sera: E5 B4 D5 B4 E5, a palindrome.
SERA_CELL = [n("E5"), n("B4"), n("D5"), n("B4"), n("E5")]
# Krona: G3 C4 D4 E♭4, a pitch bend into the E♭.
KRONA_CELL = [n("G3"), n("C4"), n("D4"), n("Eb4")]


def time_cell(score: Score, ch: int, start_beat: float, quaver: float = 0.5, vel: int = 80,
              transpose: int = 0, missing=(), skip_every: int = 0, dur_mult: float = 1.6, vel_shape=None) -> list[float]:
    """Lay the Time cell as even quavers from start_beat. Returns the beat of every note slot
    (including silent ones) so a tick track can line up. `missing` removes tines by MIDI pitch
    (60 = the C4 that breaks first), `skip_every` silences every k-th note (20% integrity)."""
    slots = []
    for i, p in enumerate(TIME_CELL):
        b = start_beat + i * quaver
        slots.append(b)
        pitch = p + transpose
        if pitch in missing or (skip_every and i % skip_every == skip_every - 1):
            continue
        v = vel if vel_shape is None else int(vel * vel_shape[i % len(vel_shape)])
        score.note(ch, pitch, b, quaver * dur_mult, v)
    return slots


def crono_cell(score: Score, ch: int, start_beat: float, quaver: float = 0.5, vel: int = 80, transpose: int = 0,
               tired: bool = True, legato: float = 1.0) -> float:
    """G3 C4 D4 E4 as quavers; the second note is held 300 ms too long and the rest arrive late.
    Returns the beat where the cell ends. tired=False is Vaelos's clean version."""
    extra = score.s_to_beats(0.3) if tired else 0.0
    b = start_beat
    for i, p in enumerate(CRONO_CELL):
        d = quaver + (extra if i == 1 else 0.0)
        score.note(ch, p + transpose, b, d * legato, vel if i != 1 else max(1, vel - 6))
        b += d
    return b


def world_cell(score: Score, ch: int, start_beat: float, quaver: float = 0.5, vel: int = 80, transpose: int = 0,
               hold: float = 2.0) -> float:
    """D4 F4 A4 G4 E4, the last note held (hold = quavers)."""
    b = start_beat
    for i, p in enumerate(WORLD_CELL):
        d = hold * quaver if i == len(WORLD_CELL) - 1 else quaver
        score.note(ch, p + transpose, b, d * 0.98, vel)
        b += d
    return b


def sera_cell(score: Score, ch: int, start_beat: float, quaver: float = 0.5, vel: int = 80, transpose: int = 0,
              reverse: bool = False) -> float:
    cell = SERA_CELL[::-1] if reverse else SERA_CELL
    b = start_beat
    for p in cell:
        score.note(ch, p + transpose, b, quaver * 1.8, vel)
        b += quaver
    return b


def krona_cell(score: Score, ch: int, start_beat: float, quaver: float = 0.5, vel: int = 90, transpose: int = 0,
               bend_from_cents: float = -120.0) -> float:
    """G3 C4 D4 E♭4; the E♭ is approached by a pitch bend from below (the channel must be free
    of other notes while bending)."""
    b = start_beat
    for i, p in enumerate(KRONA_CELL):
        if i == 3:
            score.bend_cents(ch, bend_from_cents, b)
            score.bend_ramp(ch, bend_from_cents, 0.0, b, quaver * 0.9)
            score.note(ch, p + transpose, b, quaver * 2.5, vel)
            score.bend_cents(ch, 0.0, b + quaver * 2.6)
        else:
            score.note(ch, p + transpose, b, quaver * 1.05, vel)
        b += quaver
    return b


def vaelos_pulse(score: Score, ch: int, start_beat: float, bars: int, beats_per_bar: int = 4, vel: int = 70,
                 transpose: int = 0, alternate_bars: bool = True) -> None:
    """The contrabassoon tritone pulsing on every beat: C2 for a bar, then G♭2 (or alternating)."""
    for bar in range(bars):
        for beat in range(beats_per_bar):
            b = start_beat + bar * beats_per_bar + beat
            if alternate_bars:
                p = VAELOS_CELL[bar % 2]
            else:
                p = VAELOS_CELL[beat % 2]
            score.note(ch, p + transpose, b, 0.85, vel - (0 if beat == 0 else 10))


def export_cells(out_dir: str) -> list[str]:
    """Write each cell as a dry solo MIDI file (§5.10.2: audio/music/motifs/<char>_cell.mid)."""
    import os
    from score import GM
    os.makedirs(out_dir, exist_ok=True)
    written = []

    def save(name: str, score: Score):
        p = os.path.join(out_dir, f"{name}_cell.mid")
        score.to_midi(p, tail_s=2.0)
        written.append(p)

    s = Score(72, 3); s.program(0, GM["music_box"]); time_cell(s, 0, 0.0); time_cell(s, 0, 6.0); save("time", s)
    s = Score(72, 4); s.program(0, GM["piano"]); world_cell(s, 0, 0.0, quaver=1.0, hold=3.0); save("world", s)
    s = Score(68, 4); s.program(0, GM["bassoon"]); vaelos_pulse(s, 0, 0.0, 4); save("threat_vaelos", s)
    s = Score(72, 4); s.program(0, GM["piano"]); crono_cell(s, 0, 0.0, quaver=1.0); save("crono", s)
    s = Score(72, 4); s.program(0, GM["harp"]); sera_cell(s, 0, 0.0); sera_cell(s, 0, 4.0, reverse=True); save("sera", s)
    s = Score(96, 4); s.program(0, GM["shakuhachi"]); krona_cell(s, 0, 0.0, quaver=1.0); save("krona", s)
    return written
