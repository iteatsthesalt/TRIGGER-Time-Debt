# TRIGGER: Time Debt

A 2.5D HD-2D sequel to Chrono Trigger, built in Godot 4.7.2 (Forward+, statically typed GDScript, data-driven
JSON content).

It is 1024 A.D., twenty-four years after the Millennial Fair. Crono is 41, and he is not the boy who died at
the Ocean Palace: he is a porcelain Bekkler copy with a Time Egg where his heart should be. His daughter Sera,
17, slips between seven aborted universes that the Golden Timeline was built on. Vaelos, a humanoid Lavos grown
from the original Crono's atoms, wants her as the keystone of a timeline with no death and no free will. Nine
playable characters, nine elements, nine art styles in one rendering pipeline; combat uses Break and Boost on a
live timeline; eight endings decided by what you do.

## Start here

| Read | For |
|---|---|
| [`PROGRESS.md`](PROGRESS.md) | Where the build is, what is verified, what is next, what is broken. **Read first every session.** |
| [`CLAUDE.md`](CLAUDE.md) | The working agreement for agents: session protocol, ownership, conventions. |
| [`design/STORY_BIBLE.md`](design/STORY_BIBLE.md) | Premise, cast, universes, every chapter, the eight endings, flags and affinity. |
| [`design/COMBAT_LAWS_BIBLE.md`](design/COMBAT_LAWS_BIBLE.md) | Every combat rule, technique, enemy, boss and constant; §18.7 acceptance checks. |
| [`design/REFERENCE_BIBLE.md`](design/REFERENCE_BIBLE.md) | Art and audio direction, the nine canvases, creation briefs, the asset manifest. |
| [`design/AUDIT.md`](design/AUDIT.md) | How the source documents were combined; settled conflicts. |
| [`docs/ART_PIPELINE.md`](docs/ART_PIPELINE.md) | How a character goes from catalog painting to lit sprite (the template for all character art). |
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | Every design or tuning call made while building, with the bible section it touches. |
| [`docs/QUESTIONS_FOR_NICH.md`](docs/QUESTIONS_FOR_NICH.md) | Open questions for the designer (answered later; nothing waits on them). |
| [`docs/ASSET_REQUESTS.md`](docs/ASSET_REQUESTS.md) | The prioritized art work list for Nich's PixelLab bot; entries move to Done as they are imported. |
| [`docs/screenshots/`](docs/screenshots/) | Progress gallery with a README (what, when). |
| [`docs/reports/`](docs/reports/) | Generated reports: enemy codex judgement calls, audio build table. |

## Run and check

```bash
source tools/setup_godot.sh                 # downloads Godot 4.7.2 into .tools/ and puts `godot` on PATH (~1 min)
bash tools/check.sh                         # import, parse every script, 423 unit checks, data lint, 600-frame smoke boot with captures
bash tools/check.sh --no-visual             # the same without the software-Vulkan smoke boot (fast, headless)
godot --path .                              # play (window 1280×720, UI canvas 640×360 integer-scaled)
```

Useful boot arguments (any scene): `--scene=<location id>`, `--spawn=<marker>`, `--checkpoint=<id>`,
`--party=crono,sera,marle`, `--chapter=<n>`, `--integrity=<n>`, `--level=<n>`, `--flag=Name:State`,
`--autobattle`.

Headless probes play the game without a window and print `PROBE_END ok=true`:

```bash
godot --headless --path . --script res://tools/build/prologue_probe.gd -- --autobattle      # the whole Prologue
godot --headless --path . --script res://tools/build/ch1_probe.gd -- --autobattle           # Chapter 1 in the Atrium
godot --headless --path . --script res://tools/build/battle_probe.gd -- --scene=test_arena --autobattle --boss=atrium_cradle --party=crono,sera,marle --level=4
```

Visual captures (the container has no GPU; software Vulkan runs at ~2 fps, keep them short):

```bash
bash tools/capture/render.sh <scene_id> <prefix> [frames] [-- extra args]     # → /tmp/captures/<prefix>_NNNN.png
bash tools/capture/render.sh test_lineup lineup 30 -- --ids=crono,sera --anim=walk   # every facing of a character
```

## Repository map

```
project.godot            Forward+, 640×360 UI canvas, eight autoloads (below)
scenes/                  boot/ (main scene), ui/ (title, HUD, dialogue), u0/ … u8/ (locations by universe), test/ (diorama, arena, lineup)
scripts/
  autoload/              Data (JSON registry) · Flags (possibility engine: flags, affinity, counters) · Game (party, integrity, chapter, checkpoints)
                         Saves · Universe (canvas switcher) · Audio (music/stems/SFX/RTPC) · Router (scene routing) · Story (dialogue scripts)
  combat/                the Combat Laws core: stats, timeline, shields/Break, damage, Boost, statuses, techs, AI (headless-tested)
  battle/                BattleScene + HUD glue, BossController, bosses/<id>.gd directors (per-boss mechanics)
  actors/                CombatActor, ActorSprite (lit billboard), SpriteLibrary (sheet lookup), PlayerController, PartyFollow, FieldNPC
  world/                 Location base (every playable scene extends it), SceneKit (materials, primitives), EncounterZone, Interactable
  locations/             one script per location (build(), after_ready())
  render/                HD2DWorld (compositor canvas stack), HD2DCameraRig, CanvasStackEffect
  ui/                    title, dialogue box, battle HUD, portraits, speaker styles
shaders/                 sprite_canvas (lit billboard, porcelain states), canvas stack compute shaders, grade LUTs
data/                    all content as JSON (see "Adding content")
assets/                  characters/ npcs/ enemies/ bosses/ (imported sprite sheets) · portraits/ ui/generated/ textures/generated/ vfx/generated/ (import targets for those kinds)
                         textures/ (procedural placeholders), luts/, materials/
source_art/              raw PixelLab downloads, contact sheets, prompts (rebuild sources; ignored by Godot)
audio/                   music (OGG + stems, loop points in .import), sfx/<family>/, beds; built by tools/audio/build_all.py
tests/                   run_tests.gd and the headless check suites
tools/                   setup_godot.sh · check.sh · art/import_pixellab.py (+ art/pipeline/) · art/ (placeholder generators, pixel.py helpers)
                         audio/ (synthesis toolchain) · build/ (probes, parse_all, lint_data) · capture/ (render.sh, smoke.gd)
design/                  the three bibles, AUDIT.md, images/catalog (59) and images/plates (12)
prototype/               the earlier combat core (reference only; its systems live in scripts/combat now)
docs/                    PROGRESS hand-off lives in the root; here: ART_PIPELINE, ASSET_REQUESTS, DECISIONS, QUESTIONS_FOR_NICH, reports/, screenshots/
```

## Adding content

Everything below is data plus, at most, one small script. `Data` (scripts/autoload/data_registry.gd) loads every
JSON file under `data/` at boot and validates it; `python3 tools/build/lint_data.py` checks cross-references
(tech ids in kits, enemy keys in encounters, flags in dialogue) and runs inside `tools/check.sh`.

**A location (scene).** Create `scripts/locations/<id>.gd` extending `Location` with `build()` (set
`location_id`, `universe_id`, `field_music`, `ambience`, camera and bounds; lay the room out with `SceneKit`
or a glTF kit; `add_marker`, `add_zone` (encounters), `add_npc`, `add_cast`, `add_door`, `add_ink_puddle`) and
`after_ready()` (first-visit scripts: `await Story.run(&"script_id")`). Make `scenes/u<n>/<id>.tscn` with that
script on a `Node3D` root (copy `scenes/u0/guardia_courtyard.tscn`), and register the id in
`scripts/autoload/scene_router.gd`. Travel with `Router.go(&"id", &"marker")` or a dialogue `{"go": ...}`.

**Dialogue and cutscenes.** `data/dialogue/<chapter>.json` maps a script id to a list of commands. Commands:
`say/who/portrait/style`, `caption`, `choice` (options with `goto` and optional `if`), `label/goto/if/else/end`,
`wait`, `move/face/anim/show/hide/teleport` (actors by id), `camera` (`truth`/`explore`), `universe`,
`music/stop_music/sfx/ambience/rtpc`, `fade`, `emote`, `shake`, `run` (nest a script), `call` (a method on the
location), `battle` (an encounter or `boss_id`, with `on_win`/`on_lose`), `go`, `set`/`set_flag`/`affinity`,
`rift`, `counter`, `var`, `give_item/key_item/relic`, `integrity/debt`, `recruit`, `learn`, `chapter`,
`checkpoint`, `sera_state`, `party`, `save`. Conditions: `{"flag": "Name", "state": "State"}`, `not_flag`,
`light_min`, `dark_min`, `prismatic_min`, `counter_min` (+ `value`), `recruited`, `var`, `integrity_max`,
`chapter_min`, `has_key_item`, `has_item`, `party_has`. Text may use `{integrity}` and `{debt}`.
Speakers need an entry in `scripts/ui/speaker_styles.gd` only for a special style.

**A flag.** Add it to the `flags` list in `data/flags/flags_u<n>.json`: `id`, `where`, `states` (each with an
`id`, `affinity` light/dark/prismatic deltas, `text`). Set it from dialogue with `{"set_flag": "Name:State"}`
or code with `Flags.set_flag(&"Name", &"State")`; read with `Flags.has`, `Flags.state`, `Flags.is_state`. Endings and the Codex
read these; the Story Bible lists every canonical flag.

**A tech.** Add to `techs` in `data/techs/<actor or duals|triples>.json`: `id`, `name`, `tier` (single, dual,
triple), `actors`, `tags` (element and weapon keys), `shape` (SINGLE, LINE, CONE, RING, ALL …), `hits`,
`power`, `uses`, `costs` per actor (`strain_pct`, `bp`, `integrity_pct`), `unlock` (chapter, level or flag),
optional `status`, `effects`, `notes`. Then list it under `techs` in the actor's kit
`data/characters/<id>.json` with its `unlock`. Combat Laws §11 is the source of every number.

**An enemy.** Add to `enemies` in `data/enemies/u<n>/u<n>_enemies.json`: `id` (E-number), `key`, `name`,
`universe`, `level`, `kind`, `shield` (plate count), `tags`, `weak`, `lean` (L/D), `sprite`, `fps`,
`body_radius`, `size`, `actions` (id, tags, shape, power, hits, target, optional `effects` such as
`summon:<key>`), `drops`, `notes`. Put encounters that use it in `data/encounters/u<n>.json`. Its sheet goes
in `assets/enemies/u<n>/<key>/<key>_sheet.png` + `<key>_frames.json` (rows W, E and optionally S, N); until
it exists the engine draws a readable placeholder.

**A boss.** `data/bosses/<id>.json`: `id`, `name`, `level`, `hp`, `phases` (each a full `EnemyDef` override:
shield, tags, actions, `adds`, `max_adds`, `script` = a dialogue id run with the clock stopped), `drops`,
`music`. Mechanics that data cannot express go in `scripts/battle/bosses/<id>.gd` (hooks: `on_setup`,
`on_phase`, `on_break`, `on_parry`, `on_action`, `on_tick`, `on_defeat`, `on_summon`). Start it from
dialogue with `{"battle": "", "boss_id": "<id>", "at": "<marker>", "center": "<marker>", "music": ...}`.
Drive it headless with `tools/build/battle_probe.gd -- --boss=<id>`.

**A character sheet.** Art is generated by Nich's PixelLab bot from `docs/ASSET_REQUESTS.md`. A character is a
set of sprites: tiers `map` (64) / `field` (128, also battle) / `action` (256 cut-ins) / `portrait`, plus
variants (another canvas `u1`…, or a state `debt20`…). Import a finished asset with
`python3 tools/art/import_pixellab.py <pixellab_id|url> <asset_key> [--name "TRIGGER Sera u1 field v1" | --tier action --variant u1]`
(contract and layout in `docs/ART_PIPELINE.md`), review with
`tools/capture/render.sh test_lineup lineup 30 -- --ids=<key> --tier=<tier>`; the import is recorded in
`data/art/pixellab_assets.json`. In code: `SpriteLibrary.apply(sprite, id, fps, tier, variant)` falls back to
field/base, and `ActorSprite.set_tier(&"action")` / `set_variant(&"u1")` swap a live sprite for a cut-in.

**Music and SFX.** `tools/audio/` synthesises every track and effect (`python3 tools/audio/build_all.py`);
`Audio.play_music(&"id")`, `Audio.play_ambience(&"id")`, `Audio.play_sfx("family/id")`,
`Audio.set_rtpc("name", value)` drive them. New
tracks need a loop point in their `.import` and a row in `docs/reports/audio_build_report.md`.

## Conventions

- Statically typed GDScript, `class_name` for every reusable type, one responsibility per file, files kept
  small (split a script before it passes ~600 lines).
- Content is data: tune numbers in `data/`, not in code. Every bible number is a starting value; record
  changes in `docs/DECISIONS.md`.
- Commit small and often, straight to `main`, with `git pull --rebase` before every push; nothing is force-pushed.
- Placeholders are honest placeholders: generated-looking but clearly logged in `PROGRESS.md` for replacement.
