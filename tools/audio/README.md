# tools/audio — the TRIGGER: Time Debt audio toolchain

Every sound in `audio/` is made by code from this folder (Reference Bible §1.10, §8). Nothing is
recorded; every generator is seeded, so a rebuild reproduces the same bytes.

## Rebuild everything

```bash
python3 tools/audio/build_all.py            # motifs, music, SFX, ambience (about 10 minutes)
python3 tools/audio/build_all.py --only battle        # ids containing "battle" (tracks or SFX families)
python3 tools/audio/build_all.py --music              # one group: --music --sfx --ambience --motifs
python3 tools/audio/build_all.py --check              # measure what is in audio/ without rebuilding
python3 tools/audio/build_all.py --refresh-manifest   # rewrite audio/AUDIO_MANIFEST.json from the sidecars and files
python3 tools/audio/godot_import.py                   # (re)write the Godot .import sidecars only
python3 tools/audio/tracks/wind_scene.py              # any track module also runs on its own
python3 tools/audio/sfx/families.py porcelain         # one SFX family
python3 tools/audio/music_box.py --out /tmp/box       # the bible's music-box states as WAV previews
```

Requirements: Python 3 with numpy, scipy and mido; `fluidsynth`, `ffmpeg` (libvorbis) and a General
MIDI SoundFont (`/usr/share/sounds/sf2/FluidR3_GM.sf2`, or set `TTD_SF2`).

The build prints, for every file, duration, channels, peak dBFS and integrated loudness
(ITU-R BS.1770 K-weighting with gating) and writes `audio/AUDIO_MANIFEST.json`. It exits non-zero
if a music mix is more than 1.5 LU from −20 LUFS, an SFX peak is off −1 dBFS, or a file is over
6 MB or 2:30.

## Layout

| Path | What |
|---|---|
| `synth.py` | DSP helpers: oscillators, noise colours, ADSR/swells, Butterworth and resonant filters, swept band-pass, convolution reverb and reverse reverb, delay, bitcrush, wow/flutter, VHS tear, tape stop, saturation, side-chain duck, tape hiss / vinyl crackle / room tone, loop folding and cross-fades, peak and LUFS measurement, WAV/OGG/JSON writers |
| `score.py` | `Score`: a beat-based MIDI event list (notes, chords, CCs, pitch bends) written with mido; `render_stems()` renders each stem's channels through FluidSynth at 48 kHz float with the SoundFont reverb/chorus off; GM program and drum tables |
| `motifs.py` | The §8.3 cells (Time, World, Vaelos, Crono, Sera, Krona) and helpers that lay them into a Score; `export_cells()` writes `audio/music/motifs/*_cell.mid` |
| `music_box.py` | The bible's tine synth with removable tines, the escapement tick with the missing tooth, the mainspring grind; renders the box states (`box_100`, `box_060`, `box_020`, `box_000` tape stop) |
| `tracks/common.py` | `Track`: sections in bars, loop points on bar lines, stem finalisation (tail folding across the seam, −20 LUFS mix normalisation, OGG q6, JSON sidecar); instrument treatments (felt piano, quartet with crackle, box room, gramophone, broken-skin taiko, shakuhachi breath, koto, distorted guitar, warped 808, hiss hats, wind bed, porcelain ting, heartbeat) |
| `tracks/*.py` | One module per track or pair of tracks (see the table below) |
| `sfx/base.py` | SFX recipes (porcelain tink, crack, shard spill, gong, bell, brush on paper, tide, paper tear, whoosh, clock tick, woodblock, coin, harp pluck, sub thump, whisper, reversed tine, breath, shimmer) and the WAV writer (peak −1 dBFS, 16-bit) |
| `sfx/families.py` | One build function per `audio/sfx/<family>/` |
| `ambience.py` | The seamless ambience beds and their identity events |
| `godot_import.py` | Writes the Godot `.import` sidecars (loop points, beat info, QOA) for everything under `audio/` |
| `build_all.py` | Runs everything, measures, writes the manifest |

## What the game finds

`scripts/autoload/audio_director.gd` looks for:

- music at `audio/music/<track>.ogg`, or stems `audio/music/<track>__<stem>.ogg`. When `play_music()`
  is called without a stem list it loads `<track>.ogg` **and** every stem named `box, piano, strings,
  hiss, bass, drums, lead, pad, quartet, crackle, wind, tick` that exists. So tracks with stems have
  **no** `<track>.ogg` (it would double the mix); their default stems all use names from that list,
  and optional layers (`debt`, `box_debt60`, `box_debt20`, `box_debt0`) use other names so they only
  play when asked for: `Audio.play_music(&"mus_u0_wind_scene_1024", 1.5, ["box_debt60", "piano", "wind", "tick", "debt"])`.
- SFX at `audio/sfx/<family>/<id>.wav`, or numbered variations `<id>_01.wav … _05.wav` picked at random.
- ambience at `audio/ambience/<id>.ogg`.

Each music track has a sidecar `audio/music/<track>.json`: bpm, meter, key, bars, `loop_start_s`,
`loop_start_samples`, the sections with bar numbers and start times (for `AudioStreamInteractive`
clips), every stem file with its loudness and whether it is on by default, the RTPC hooks, and the
Godot import values. `godot_import.py` (run by `build_all.py`) writes a `.import` file next to every
OGG and WAV so Godot imports music and beds with `loop = true`, `loop_offset` at the end of the
intro and bpm / beat_count / bar_beats set (Godot then loops at the beat count and folds the tail
into the loop start), stings with `loop = false`, SFX as QOA with trim on, and the status loops,
galaxy hums and telegraph loop with loop mode Forward. Verified against Godot 4.7.2 headless.

## Music

Form is Intro → A → Bridge → B → Coda on bar lines. The loop region is everything after the intro
(the title loops only its coda, the box alone), and the ring-out of the last bar is folded onto the
loop start so the seam is not clean. Stems of one track have identical lengths. Mix target −20 LUFS,
peaks under −1 dBFS; tape hiss at −60 dB rides under every track so silence is never digital zero.

| Track | Module | BPM, meter, key | Stems (default on unless noted) |
|---|---|---|---|
| mus_title | `tracks/title.py` | 72, 3/4, C | box, piano, strings, hiss; `box_debt60`, `box_debt20` (optional) |
| mus_u0_guardia_morning | `tracks/guardia_morning.py` | 72, 4/4, F | quartet, piano, crackle (crackle carries the house clock) |
| mus_u0_wind_scene_1024 | `tracks/wind_scene.py` | 72, 3/4, C | box, piano, wind, tick; `debt`, `box_debt60`, `box_debt20`, `box_debt0` (optional) |
| mus_u0_truce_1024 | `tracks/truce.py` | 78, 4/4, D Dorian | lead (shamisen −15 cents), bass (808), box, drums, hiss |
| mus_u0_fair_1024 | `tracks/fair.py` | 108, 6/8, G | single file |
| mus_battle_core_u0 | `tracks/battle.py` | 144, 4/4, E minor | box, tick, piano, strings, bass, drums |
| mus_battle_core_u1 | `tracks/battle.py` | 144, 4/4, E minor | box, tick, lead (shakuhachi), pad (koto), bass (distorted guitar), drums (taiko) |
| mus_boss_atrium_cradle | `tracks/boss_atrium_cradle.py` | 72, 4/4, C minor | strings, lead (gramophone hymn + gold leaf), drums (tings), crackle |
| mus_vaelos_theme | `tracks/character_themes.py` | 68, 4/4, C Locrian | bass (contrabassoon + sub), lead (tenor hum −50 cents), pad (marrow pump, 28–40 Hz drone) |
| mus_sera_theme | `tracks/character_themes.py` | 72, 4/4, E minor | lead (harp), pad (reversed shamisen), strings (double voice; scale with translucency) |
| mus_u1_ashen_morning | `tracks/u1.py` | 48, 4/4, A minor pentatonic | single file |
| mus_u1_krona_duel | `tracks/u1.py` | 96, 4/4, D minor | single file |
| mus_transit_chronoslip | `tracks/transit_and_stings.py` | free | single file, 64 s seamless, −23 LUFS |
| mus_stings_victory / _defeat / _overcap | `tracks/transit_and_stings.py` | — | one-shots at −18 LUFS, `loop = false`; play with `Audio.play_music(&"mus_stings_victory", 0.0)` |

Motif cells as dry MIDI (`audio/music/motifs/*_cell.mid`) and the four music-box states as WAV
previews (`box_100/060/020/000.wav`) are written by `--motifs`.

## SFX

WAV 48 kHz 16-bit, peak −1 dBFS, mono for positional sounds and stereo for UI and full-screen time
events; `_01…_05` variations wherever a sound repeats. Status loops, the galaxy hums and the
telegraph loop are seamless (import with Loop on). Families: `ui`, `combat`, `porcelain`, `weapons`,
`magic` (`<element>_gesture/_travel/_contact/_tail`), `footsteps`, `time`, `status`, `creatures`.

## Ambience

`audio/ambience/amb_u0.ogg`, `amb_u1.ogg` (80 s) and `amb_transit.ogg` (64 s): seamless stereo
loops at −26 LUFS with their identity events placed inside the loop. Sidecar JSONs sit beside them.

## Adding a track

Copy a module under `tracks/`, give it a `Track(id, bpm, beats_per_bar, sections, key)`, write notes
into `tr.score` with the motif helpers, render MIDI stems with `tr.midi_stems({...})`, synthesise
anything the SoundFont cannot do with `synth.py`, set the balance with `C.balance()`, and call
`tr.finalize(stems)`. Add the id to `MUSIC_BUILDERS` in `build_all.py`.
