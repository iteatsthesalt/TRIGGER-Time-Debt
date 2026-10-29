"""Shared track scaffolding: sections, loop points, stem finalisation, sidecars and the
instrument treatments every U0/U1 track uses."""
from __future__ import annotations

import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import synth as S  # noqa: E402
import music_box as MB  # noqa: E402
from score import Score, render_stems  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
MUSIC_DIR = os.path.join(ROOT, "audio", "music")
TAIL_S = 5.0
MUSIC_LUFS = -20.0
# stems the AudioDirector auto-loads when play_music() is called without a stem list
AUTO_STEMS = {"box", "piano", "strings", "hiss", "bass", "drums", "lead", "pad", "quartet", "crackle", "wind", "tick"}


class Track:
    """One music asset: a Score, named sections in bars, stems, loop points and a sidecar."""

    def __init__(self, track_id: str, bpm: float, beats_per_bar: int, sections: list[tuple[str, int]], key: str,
                 loop_from: str = "a", single_file: bool = False, meter_note: int = 4,
                 display_bpm: float | None = None, display_beats_per_bar: int | None = None):
        self.id = track_id
        self.bpm = bpm
        self.beats_per_bar = beats_per_bar
        self.meter_note = meter_note
        # a 6/8 track is scored with the quaver as the beat; the sidecar shows the felt pulse
        self.display_bpm = display_bpm or bpm
        self.display_beats_per_bar = display_beats_per_bar or beats_per_bar
        self.key = key
        self.sections = sections
        self.single_file = single_file
        self.score = Score(bpm, beats_per_bar)
        self.bar_s = self.score.bar_s()
        self.section_bar: dict[str, int] = {}
        b = 0
        for name, bars in sections:
            self.section_bar[name] = b
            b += bars
        self.total_bars = b
        self.total_s = self.total_bars * self.bar_s
        self.loop_start_s = self.section_bar[loop_from] * self.bar_s if loop_from else 0.0
        self.loop_end_s = self.total_s
        self.notes = ""
        self.rtpc: dict[str, str] = {}
        self.default_off: set[str] = set()

    # --- timing helpers ---
    def bar(self, section: str, offset_bars: float = 0.0) -> float:
        """Beat position of a bar inside a section."""
        return (self.section_bar[section] + offset_bars) * self.beats_per_bar

    def bars_in(self, section: str) -> int:
        return dict(self.sections)[section]

    def s(self, beat: float) -> float:
        return self.score.beats_to_s(beat)

    def render_length_s(self) -> float:
        return self.total_s + TAIL_S

    def buffer(self) -> np.ndarray:
        return np.zeros(S.samples(self.render_length_s()))

    def midi_stems(self, stems: dict[str, list[int]], gain: float = 0.6) -> dict[str, np.ndarray]:
        return render_stems(self.score, stems, self.total_s, TAIL_S, gain=gain)

    # --- finishing ---
    def fold(self, x: np.ndarray) -> np.ndarray:
        return S.fold_loop_tail(x, S.samples(self.loop_start_s), S.samples(self.loop_end_s))

    def finalize(self, stems: dict[str, np.ndarray], hiss_stem: str | None = None, hiss_db: float = -60.0,
                 target_lufs: float = MUSIC_LUFS, quality: int = 6) -> dict:
        """Fold tails across the loop seam, normalise the default mix to target_lufs, write OGGs and
        the sidecar. Returns the report entry."""
        n = S.samples(self.loop_end_s)
        out: dict[str, np.ndarray] = {}
        for name, x in stems.items():
            x2 = S.to_stereo(x) if x.ndim == 1 else x
            x2 = self.fold(x2) if len(x2) > n else S.fit_length(x2, n)
            out[name] = S.fit_length(x2, n)
        defaults = [k for k in out if k not in self.default_off]
        hiss_stem = hiss_stem or ("hiss" if "hiss" in out else ("crackle" if "crackle" in out else defaults[0]))
        out[hiss_stem] = out[hiss_stem] + S.tape_hiss(self.loop_end_s, hiss_db, seed=hash(self.id) % 1000)
        mix = sum(out[k] for k in defaults)
        cur = S.lufs_integrated(mix)
        gain = S.db_to_amp(target_lufs - cur) if math.isfinite(cur) else 1.0
        mix *= gain
        # keep the mix under −1 dBFS: if the gain would clip, pull everything down instead of limiting stems
        pk = S.peak_dbfs(mix)
        if pk > -1.0:
            trim = S.db_to_amp(-1.0 - pk)
            gain *= trim
            mix *= trim
            if pk > 0.0:
                print(f"  [{self.id}] note: mix trimmed {pk + 1.0:.1f} dB below target loudness to keep the peak at -1 dBFS")
        os.makedirs(MUSIC_DIR, exist_ok=True)
        files = {}
        if self.single_file:
            path = os.path.join(MUSIC_DIR, f"{self.id}.ogg")
            S.write_ogg(path, mix, quality)
            files["mix"] = {"file": os.path.basename(path), "default_on": True, **S.measure(mix), "size_bytes": os.path.getsize(path)}
        else:
            for name, x in out.items():
                y = x * gain
                path = os.path.join(MUSIC_DIR, f"{self.id}__{name}.ogg")
                S.write_ogg(path, y, quality)
                files[name] = {"file": os.path.basename(path), "default_on": name not in self.default_off,
                               "auto_loaded_by_director": name in AUTO_STEMS, **S.measure(y), "size_bytes": os.path.getsize(path)}
        side = {
            "id": self.id,
            "bpm": self.display_bpm,
            "meter": [self.beats_per_bar if self.meter_note == 4 else self.beats_per_bar, self.meter_note],
            "key": self.key,
            "bars": self.total_bars,
            "bar_s": round(self.bar_s, 6),
            "duration_s": round(self.loop_end_s, 4),
            "loop_start_s": round(self.loop_start_s, 4),
            "loop_start_samples": S.samples(self.loop_start_s),
            "loop_end_s": round(self.loop_end_s, 4),
            "sections": [{"name": name, "bar": self.section_bar[name], "bars": bars,
                          "start_s": round(self.section_bar[name] * self.bar_s, 4)} for name, bars in self.sections],
            "stems": files,
            "mix": S.measure(mix),
            "rtpc": self.rtpc,
            "notes": self.notes,
            "godot_import": {"loop": True, "loop_offset": round(self.loop_start_s, 4), "bpm": self.display_bpm,
                             "beat_count": self.total_bars * self.display_beats_per_bar, "bar_beats": self.display_beats_per_bar},
        }
        S.write_json(os.path.join(MUSIC_DIR, f"{self.id}.json"), side)
        return side


def set_lufs(x: np.ndarray, target: float) -> np.ndarray:
    """Gain a stem to a gated loudness (relative balance before the final mix normalisation)."""
    cur = S.lufs_integrated(x)
    if not math.isfinite(cur):
        return x
    return x * S.db_to_amp(target - cur)


def balance(stems: dict[str, np.ndarray], levels: dict[str, float], ceilings: dict[str, float] | None = None) -> None:
    """Set each stem's gated loudness, then cap peaky stems (plucks, drums) with a look-ahead limiter."""
    for k, v in levels.items():
        stems[k] = set_lufs(stems[k], v)
        if ceilings and k in ceilings and S.peak_dbfs(stems[k]) > ceilings[k]:
            stems[k] = S.limiter(stems[k], ceilings[k])


# ----------------------------------------------------------------------------------------------
# instrument treatments (§8.4 palettes)
# ----------------------------------------------------------------------------------------------


def felt_piano(x: np.ndarray, fc: float = 2200.0, room: float = 1.4, mix: float = 0.16) -> np.ndarray:
    """Acoustic piano → felt: low-pass, soft saturation, a small room."""
    y = S.felt(x, fc)
    return S.reverb(y, room, mix, 0.012, 3500.0, seed=31)


def quartet(x: np.ndarray, room: float = 2.4, mix: float = 0.28, crackle_db: float | None = None, seed: int = 41) -> np.ndarray:
    """String quartet: hall, a little top taken off, optional vinyl crackle riding with it."""
    y = S.shelf_high(x, 6000.0, -3.0)
    y = S.reverb(y, room, mix, 0.02, 4500.0, seed=seed)
    if crackle_db is not None:
        c = S.vinyl_crackle(len(y) / S.SR, 14.0, crackle_db, seed=seed + 1)
        y = y + S.to_stereo(c, 0.6)
    return y


def box_post(x: np.ndarray, room: float = 1.8, mix: float = 0.22, seed: int = 51) -> np.ndarray:
    """The music box in its brass case: slight spread, 9 kHz roll-off, a small bright room."""
    y = S.lowpass(x, 9000.0, 1)
    y = S.to_stereo(y, 0.35) if y.ndim == 1 else y
    return S.reverb(y, room, mix, 0.008, 6000.0, seed=seed)


def gramophone_post(x: np.ndarray, crackle_db: float = -34.0, wow_cents: float = 9.0, seed: int = 61) -> np.ndarray:
    y = S.gramophone(S.to_mono(x), 320.0, 3400.0, 1.8)
    y = S.wow_flutter(y, wow_cents, 0.55, 3.0, 6.5, seed=seed)
    c = S.vinyl_crackle(len(y) / S.SR, 22.0, crackle_db, seed=seed + 1)
    return S.to_stereo(y + c, 0.25)


def broken_skin_taiko(x: np.ndarray) -> np.ndarray:
    """Broken-skin taiko: the drum pitched down a minor third, saturated, the top folded under 2.5 kHz."""
    y = S.pitch_shift(S.to_mono(x), -3.0)
    y = S.saturate(y * 1.8, 2.2)
    y = S.lowpass(y, 2500.0, 2)
    return S.reverb(y, 1.6, 0.3, 0.01, 2500.0, seed=71)


def shakuhachi_post(x: np.ndarray, breath_db: float = -38.0, seed: int = 81) -> np.ndarray:
    """Shakuhachi: a wooden room and a breath layer that follows the envelope."""
    m = S.to_mono(x)
    env = S.one_pole_lp(np.abs(m), 12.0)
    breath = S.bandpass(S.noise(len(m) / S.SR, "pink", S.rng(seed)), 1800.0, 6000.0, 2) * env * S.db_to_amp(breath_db) / (env.max() + 1e-9) * 6
    y = S.to_stereo(m + breath, 0.3)
    return S.reverb(y, 2.0, 0.26, 0.015, 5000.0, seed=seed)


def koto_post(x: np.ndarray, seed: int = 91) -> np.ndarray:
    y = S.to_stereo(S.to_mono(x), 0.5)
    return S.reverb(y, 1.9, 0.22, 0.01, 5000.0, seed=seed)


def guitar_post(x: np.ndarray) -> np.ndarray:
    """Distorted guitar: extra drive, a cabinet-ish band, a short room."""
    m = S.to_mono(x)
    y = S.saturate(m * 2.5, 3.0)
    y = S.bandpass(y, 90.0, 5200.0, 1)
    y = S.resonant_bandpass(y, 2400.0, 1.2) * 0.3 + y
    return S.reverb(S.to_stereo(y, 0.4), 0.9, 0.15, 0.008, 3500.0, seed=101)


def sub_808(times_pitches: list[tuple[float, int, float]], length_s: float, decay_s: float = 2.2, warp_cents: float = 18.0,
            seed: int = 111) -> np.ndarray:
    """A warped 808: a sine that drops from a fifth above into the root, with a long decay and a
    slow pitch wobble (mono)."""
    gen = S.rng(seed)
    out = np.zeros(S.samples(length_s) + S.samples(decay_s))
    for t0, midi, vel in times_pitches:
        f = S.midi_to_hz(midi)
        n = S.samples(decay_s)
        t = np.arange(n) / S.SR
        glide = f * (1.0 + 0.5 * np.exp(-t * 28.0))
        wob = S.cents(warp_cents * np.sin(S.TWO_PI * gen.uniform(0.4, 0.9) * t) * (1 - np.exp(-t * 4)))
        ph = S.TWO_PI * np.cumsum(glide * wob) / S.SR
        s = np.sin(ph) * np.exp(-t * (4.0 / decay_s)) * np.minimum(1.0, t * 300.0)
        s += 0.35 * np.sin(2 * ph) * np.exp(-t * 9.0)  # a touch of second harmonic for small speakers
        s = S.saturate(s * 1.3, 1.6)
        S.place(out, s, t0, vel)
    return out[: S.samples(length_s)]


def hiss_hats(times: list[tuple[float, float]], length_s: float, seed: int = 121) -> np.ndarray:
    """Tape hiss as percussion: short bursts of pink hiss at (time, velocity)."""
    gen = S.rng(seed)
    out = np.zeros(S.samples(length_s) + S.samples(0.3))
    for t0, vel in times:
        d = 0.05 + 0.08 * vel
        b = S.bandpass(S.noise(d, "pink", gen), 3000.0, 11000.0, 2) * S.exp_decay(d, 40.0 / d * 0.8, 0.002)
        S.place(out, b, t0, vel * 0.9)
    return out[: S.samples(length_s)]


def wind_bed(length_s: float, seed: int = 131, gust_hz: float = 0.07, lo: float = 160.0, hi: float = 1400.0,
             level_db: float = -30.0) -> np.ndarray:
    """Wind through brass: band-limited brown noise with slow gusts and a whistling resonance
    that drifts (stereo)."""
    gen = S.rng(seed)
    t = S.t_axis(length_s)
    base = S.bandpass(S.noise(length_s, "brown", gen), lo, hi, 2)
    gust = 0.55 + 0.45 * np.sin(S.TWO_PI * gust_hz * t + gen.uniform(0, 6)) * np.sin(S.TWO_PI * gust_hz * 0.37 * t + 1.0)
    gust = S.one_pole_lp(gust, 0.5)
    whistle = S.swept_bandpass(S.noise(length_s, "white", gen), 700.0, 1100.0, 25.0, 4096) * 0.12
    whistle *= (0.5 + 0.5 * np.sin(S.TWO_PI * 0.023 * t + 2.0)) ** 3
    y = base * gust + whistle * gust
    left = y
    right = S.bandpass(S.noise(length_s, "brown", gen), lo, hi, 2) * gust * 0.6 + 0.6 * y
    st = np.stack([left, right], axis=1)
    st *= S.db_to_amp(level_db) / (np.sqrt(np.mean(st ** 2)) + 1e-9)
    return st


def porcelain_ting(freq_hz: float = 5200.0, dur: float = 0.09, seed: int = 141, vel: float = 1.0) -> np.ndarray:
    """The ceramic ting used by the boss track and the UI: three inharmonic partials, 80–90 ms."""
    gen = S.rng(seed)
    t = S.t_axis(dur)
    s = np.zeros_like(t)
    for r, a, d in [(1.0, 1.0, 55.0), (1.47, 0.5, 70.0), (2.23, 0.25, 95.0)]:
        f = freq_hz * r
        if f < S.SR * 0.45:
            s += a * np.sin(S.TWO_PI * f * t + gen.uniform(0, 6)) * np.exp(-d * t)
    s *= np.minimum(1.0, t * 1500.0)
    return S.normalize_peak(s, -3.0) * vel


def heartbeat(times: list[float], length_s: float, bpm_hint: float = 68.0, seed: int = 151) -> np.ndarray:
    """Lub-dub pairs at the given times (mono, sub region, felt in the chest)."""
    out = np.zeros(S.samples(length_s) + S.samples(0.6))
    dub_gap = min(0.32, 60.0 / bpm_hint * 0.36)
    for t0 in times:
        for k, (gain, f) in enumerate([(1.0, 52.0), (0.7, 44.0)]):
            d = 0.22
            t = np.arange(S.samples(d)) / S.SR
            s = np.sin(S.TWO_PI * (f * (1 + 0.6 * np.exp(-t * 40))) * t) * np.exp(-t * 16) * np.minimum(1.0, t * 200)
            thud = S.lowpass(S.noise(d, "brown", S.rng(seed + k)), 140.0, 2) * np.exp(-t * 22) * 0.5
            S.place(out, (s + thud) * gain, t0 + k * dub_gap)
    return S.lowpass(out[: S.samples(length_s)], 110.0, 2)
