# TRIGGER: Time Debt

A 2.5D HD-2D role-playing game in the Chrono Trigger lineage, built in Godot 4.7.2 (Forward+, statically typed
GDScript, data-driven JSON content). "TRIGGER: Time Debt" is the working title (the release title is an open
question for Nich, `docs/QUESTIONS_FOR_NICH.md`).

It is 1024 A.D., twenty-four years after the Millennial Fair. Crono is 41, and he is not the boy who died at
the Ocean Palace: he is a porcelain Bekkler copy with a Time Egg where his heart should be. His daughter Sera,
17, slips between seven aborted universes that the Golden Timeline was built on. Vaelos, a humanoid Lavos grown
from the original Crono's atoms, wants her as the keystone of a timeline with no death and no free will. Nine
playable characters, nine elements, nine universes each with its own palette and grade on one 16-bit sprite
grammar (DECISIONS "Direction"); combat uses Break and Boost on a live timeline; eight endings decided by what
you do.

## Start here

| Read | For |
|---|---|
| [`PROGRESS.md`](PROGRESS.md) | Where the build is, what is verified, what is next, what is broken. **Read first every session.** |
| [`CLAUDE.md`](CLAUDE.md) | The working agreement for agents: session protocol, ownership, conventions. |
| [`design/STORY_BIBLE.md`](design/STORY_BIBLE.md) | Premise, cast, universes, every chapter, the eight endings, flags and affinity. |
| [`design/COMBAT_LAWS_BIBLE.md`](design/COMBAT_LAWS_BIBLE.md) | Every combat rule, technique, enemy, boss and constant; §18.7 acceptance checks. |
| [`design/REFERENCE_BIBLE.md`](design/REFERENCE_BIBLE.md) | Art and audio direction, the nine canvases, creation briefs, the asset manifest. |
| [`design/AUDIT.md`](design/AUDIT.md) | How the source documents were combined; settled conflicts. |
| [`docs/ART_PIPELINE.md`](docs/ART_PIPELINE.md) | How art gets in: the 64 px contract, the import commands for characters, props, textures and UI, the sheet layout, the hourly check. |
| [`docs/BOT_REVIEW.md`](docs/BOT_REVIEW.md) | The asset team's delivery contract (Linear, Dropbox, Slack, `data/art/incoming.json`) and the audit log. |
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | Every design or tuning call made while building, with the bible section it touches. |
| [`docs/QUESTIONS_FOR_NICH.md`](docs/QUESTIONS_FOR_NICH.md) | Open questions for the designer (answered later; nothing waits on them). |
| [`docs/ASSET_REQUESTS.md`](docs/ASSET_REQUESTS.md) | The prioritized art work list for the asset team; entries move to Done as they are imported. |
| [`docs/JOB_CHATGPT.md`](docs/JOB_CHATGPT.md) | The text-layer brief (a finished job; `data/text/` is its result). |
| [`docs/screenshots/`](docs/screenshots/) | Progress gallery with a README (what, when). |
| [`docs/reports/`](docs/reports/) | Reports: the 2026-11-02 workspace audit, enemy codex judgement calls, audio build table, the earlier prototype's combat audit. |

## Run and check

```bash
source tools/setup_godot.sh                 # downloads Godot 4.7.2 into .tools/ and puts `godot` on PATH (~1 min)
bash tools/check.sh                         # import, parse every script, ~710 unit checks, data lint, 600-frame smoke boot with captures
bash tools/check.sh --no-visual             # the same without the software-Vulkan smoke boot (fast, headless)
godot --path .                              # play (window 1280×720, UI canvas 640×360 integer-scaled)
```

Boot arguments (any scene; the full list is the docstring of `scenes/boot/boot.gd`): `--scene=<id>` or
`--location=<id>`, `--spawn=<marker>`, `--checkpoint=<id>`, `--party=a,b,c`, `--chapter=<n>` (unlocks the
chapter-gated kit entries), `--integrity=<n>`, `--level=<n>` (every roster member), `--flag=Name:State`
(repeatable), `--say=<text>`. Battle arguments are read by BattleScene and the test arena, not by boot:
`--autobattle`, `--boss=<id>`, `--boss_hp=<n>`.

Headless probes play the game without a window and end with `PROBE_END ok=true` (ok=false and exit code 1 on a
stall, a failed check, a lost battle or a timeout); `tools/check.sh` runs all three (not with `--quick`), after the
data lint and the Python tooling's self-tests (`tools/build/test_tools.py`), and fails unless each prints
`PROBE_END ok=true`:

```bash
godot --headless --path . --script res://tools/build/prologue_probe.gd -- --autobattle      # the whole Prologue
godot --headless --path . --script res://tools/build/ch1_probe.gd -- --autobattle           # Chapter 1 in the Atrium
godot --headless --path . --script res://tools/build/battle_probe.gd -- --scene=test_arena --autobattle --boss=atrium_cradle --party=crono,sera,marle --level=4
# battle_probe: ok = the battle started and was won; it prints each party member's level and known techs at the
# start. A debug start into a location learns its chapter's kit (BootArgs): without --chapter that is the Prologue
# kit, so a boss after the Prologue needs --chapter=<n>, e.g. --boss=shard_doll_999 --chapter=1 --level=4.
# --level=<n> applies to every party member, guests (Marle) included, whatever the order of the arguments.
godot --headless --path . --script res://tools/build/curves_probe.gd   # the stat curves at a few levels (a balance reference, no verdict)
```

Visual captures (a cloud container has no GPU; software Vulkan runs at ~2 fps, keep them short; on Nich's PC the
same script opens a real window):

```bash
bash tools/capture/render.sh <scene_id> <prefix> [frames] [-- extra args]     # → /tmp/captures/<prefix>_NNNN.png
bash tools/capture/render.sh test_lineup lineup 30 -- --ids=crono,sera --anim=walk   # every facing of a character
bash tools/capture/render.sh test_lineup lineup 30 -- --ids=crono --variant=px64 --anim=walk   # the 64 px anchor
```

## Repository map

```
project.godot            Forward+, 640×360 UI canvas, eight autoloads (below)
scenes/                  boot/ (main scene), ui/title.tscn (the HUD and the dialogue box are code-built: scripts/ui), u0/ (guardia_kitchen, guardia_courtyard, atrium_horologe; u1+ are added per chapter), test/ (diorama, arena, lineup)
scripts/
  autoload/              Data (JSON registry) · Flags (possibility engine: flags, affinity, counters) · Game (party, integrity, chapter, checkpoints)
                         Saves · Universe (canvas switcher) · Audio (music/stems/SFX/RTPC) · Router (scene routing) · Story (dialogue scripts)
  combat/                the Combat Laws core: stats, timeline, shields/Break, damage, Boost, statuses, techs, AI (headless-tested)
  battle/                BattleScene + HUD glue, BossController, bosses/<id>.gd directors (per-boss mechanics)
  actors/                CombatActor, ActorSprite (lit billboard), SpriteLibrary (sheet lookup), PlayerController, PartyFollow, FieldNPC
  world/                 Location base (every playable scene extends it), SceneKit (materials, primitives), PropBillboard (placed props), EncounterZone, Interactable
  locations/             one script per location (build(), after_ready())
  render/                HD2DWorld (compositor canvas stack), HD2DCameraRig, CanvasStackEffect
  ui/                    title, dialogue box, battle HUD, portraits, speaker styles
shaders/                 sprite_canvas (lit billboard, porcelain states), battle_plane, aoe_floor_ring (telegraphs), compositor/canvas_stack.glsl (the canvas stack; grades are procedural, not LUT textures)
data/                    all content as JSON (see "Adding content")
assets/                  characters/ npcs/ enemies/ bosses/ (imported sprite sheets) · props/u<n>/<key>/ (imported PixelLab objects: sheet, frames json, normal)
                         textures/ (procedural placeholders) · textures/generated/ (the twelve U0 PixelLab textures) · ui/ (icon, theme, title/, generated/: the delivered UI panels)
                         created on first import: portraits/<id>/ (Batch 5), vfx/generated/ (Batch 9)
source_art/              raw PixelLab downloads (unpacked frames + metadata + contact sheets; the zips are not tracked), style_kit/, MANIFEST.csv (every generated file: tool, model, seed, prompt); ignored by Godot
audio/                   music (OGG + stems, loop points in .import), sfx/<family>/, beds; built by tools/audio/build_all.py
tests/                   run_tests.gd and the headless check suites
tools/                   setup_godot.sh · check.sh · art/import_pixellab.py + art/import_incoming.py (+ art/pipeline/pixellab_import.py for characters, pixellab_objects.py for props) · art/import_texture.py · art/pixellab_mcp.py (listings, job checks, generation when Nich asks)
                         art/ (spritegen.py + characters.py placeholder generators, make_textures.py, make_portraits.py, pixel.py helpers) · audio/ (synthesis toolchain)
                         build/ (probes, parse_all, lint_data, write_chapter2_dialogue.py: the Chapter 2 dialogue generator) · capture/ (render.sh, smoke.gd) · blender/build_truce_pier.py (a kit-script example from the earlier prototype)
design/                  the three bibles, AUDIT.md, images/catalog (59), images/plates (12), images/refs; .gdignore (reference material, never loaded under res://)
docs/                    PROGRESS hand-off lives in the root; here: ART_PIPELINE, ASSET_REQUESTS, BOT_REVIEW, DECISIONS, JOB_CHATGPT, QUESTIONS_FOR_NICH, reports/ (workspace audit, enemy codex, audio build, prototype combat audit), screenshots/
```

## Adding content

Everything below is data plus, at most, one small script. `Data` (scripts/autoload/data_registry.gd) loads every
JSON file under `data/` at boot and validates it; `python3 tools/build/lint_data.py` checks cross-references
(tech ids in kits, enemy keys in encounters, labels and encounters in dialogue, props against their sheets, text
keys against game ids) and warns about ambient keys with no scene, music and ambience ids with no file under
`audio/`, and Duals or Triples with no learner (a kit entry or a dialogue `learn`). It runs inside `tools/check.sh`.

**A location (scene).** Create `scripts/locations/<id>.gd` extending `Location` with `build()` (set
`location_id`, `universe_id`, `field_music`, `ambience`, camera and bounds; lay the room out with `SceneKit`
or a glTF kit; `add_marker`, `add_zone` (encounters), `add_npc`, `add_cast`, `add_door`, `add_ink_puddle`) and
`after_ready()` (first-visit scripts: `await Story.run(&"script_id")`). Make `scenes/u<n>/<id>.tscn` with that
script on a `Node3D` root (copy `scenes/u0/guardia_courtyard.tscn`), and register the id in
`scripts/autoload/scene_router.gd`. Travel with `Router.go(&"id", &"marker")` or a dialogue `{"go": ...}`.

**Dialogue and cutscenes.** `data/dialogue/<chapter>.json` maps a script id to a list of commands (Chapter 2's
file is generated by `tools/build/write_chapter2_dialogue.py`; edit the generator, not the JSON). Commands:
`label`, `goto`, `if` (a condition, with `then` / `else` label keys), `end`, `wait`, `say` (keys `who`,
`portrait`, `style`, `voice`), `caption`, `choice` (keys `who`, `prompt`; options carry `goto` and an optional
`if`), `move` (keys `to`, `speed`, `wait`), `face` (`dir`), `anim` (`name`), `show`/`hide`, `teleport` (`to`),
`camera` (`truth`/`explore`, optional `focus`), `universe` (optional `instant`), `music`/`stop_music` (`fade`)/
`sfx`/`ambience`/`rtpc`, `fade` (`s`), `emote` (`kind`), `shake`, `run` (nest a script), `call` (a method on
the location, with `args`), `battle` (an encounter id or `""` with `boss_id`, `at`, `center`, `music`;
`on_win`/`on_lose` labels), `go` (keys `spawn`, `end_after`), `set`, `set_flag` (`state`, `affinity`),
`affinity`, `rift`, `counter` (`add`), `var` (`value`), `give_item` (`n`)/`key_item`/`relic`, `integrity`,
`set_integrity`, `debt`, `recruit` (`level`), `learn` (`who`), `chapter`, `checkpoint`, `sera_state`, `party`,
`save`. The authoritative list is the `cmd.has(...)` chain in `scripts/autoload/story_runner.gd`. Conditions: `{"flag": "Name", "state": "State"}`, `not_flag`,
`light_min`, `dark_min`, `prismatic_min`, `counter_min` (+ `value`), `recruited`, `var`, `integrity_max`,
`chapter_min`, `has_key_item`, `has_item`, `party_has`. Text may use `{integrity}` and `{debt}`.
Speakers need an entry in `scripts/ui/speaker_styles.gd` only for a special style.

**A flag.** Add it to the `flags` list in `data/flags/flags_u*.json` (one file may cover several universes:
`flags_u0`, `flags_u1`, `flags_u2_u3`, `flags_u4_u9`): `id`, `where`, `states` (each with an
`id`, `affinity` light/dark/prismatic deltas, `text`). Set it from dialogue with `{"set_flag": "Name:State"}`
or code with `Flags.set_flag(&"Name", &"State")`; read with `Flags.has`, `Flags.state`, `Flags.is_state`. Endings and the Codex
read these; the Story Bible lists every canonical flag.

**A tech.** Add to `techs` in `data/techs/<actor>.json`, `duals.json`, `duals_early.json` (the Prologue and
Chapter 1 Duals) or `triples.json`: `id`, `name`, `tier` (single, dual,
triple), `actors`, `tags` (element and weapon keys), `shape` (SINGLE, LINE, CONE, RING, ALL …), `hits`,
`power`, `uses`, `costs` per actor (`strain_pct`, `bp`, `integrity_pct`), `unlock` (chapter, level or flag),
optional `status`, `effects`, `notes`. Then list it under `techs` in the actor's kit
`data/characters/<id>.json` with its `unlock`. Combat Laws §11 is the source of every number.

**An enemy.** Add to `enemies` in any JSON under `data/enemies/` (`u<n>/u<n>_enemies.json` per universe; the
post-game roster is `u9/postgame_enemies.json`): `id` (E-number), `key`, `name`,
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

**A character sheet.** Art is generated on PixelLab by the asset team from `docs/ASSET_REQUESTS.md`, to the
Nov 1 recipe (DECISIONS "Direction"; the contract is `docs/ART_PIPELINE.md` §1): a 64×64 canvas, three heads
tall, about 32 px per metre, one locked palette, selective coloured outlines, eight directions, held frames. A
character is a set of sprites: tiers `field` (also battle) / `action` (cut-ins) / `portrait` / `map`, plus
variants (another canvas `u1`…, a state `debt20`…, or a canvas size `px64`/`px128` while two scales coexist).
Import a finished asset with
`python3 tools/art/import_pixellab.py <pixellab_id|url> <asset_key> --height-m <m> [--name "TRIGGER Sera px64 field v1" | --tier field --variant px64]`
(items named `TEST …` or `REJECTED …` are refused unless `--force`), review with
`tools/capture/render.sh test_lineup lineup 30 -- --ids=<key> [--tier=<tier>] [--variant=<variant>]`; the
import is recorded in `data/art/pixellab_assets.json`. The 128 px chibi sheets the game ships today stay the
base `field` sheets until Nich approves the 64 px anchor; new 64 px sets of those characters go in as the
`px64` variant, everything else as `field`. In code: `SpriteLibrary.apply(sprite, id, fps, tier, variant)`
falls back to field/base, and `ActorSprite.set_tier(&"action")` / `set_variant(&"px64")` swap a live sprite.

**A prop.** Props are PixelLab *objects* (Nich's Batch 4d / Batch 6), placed as lit billboards with a height in
metres. Declare it first in `data/props/props.json` (`key` = `prp_u<n>_<name>`, `universe`, `height_m` judged
from Reference Bible §1.2 / §5.7 / §11.7, `solid`, optional `y_offset`, `anims` {name: {match, fps, loop,
holds}}, `emission`, `footprint` (`[w, d]` one collision box, `"posts"` two uprights at the drawn ends with the opening clear, or a list of `[w, d, x_offset]` boxes), `pending`, `request`, `notes`; unknown fields are errors), then import it:
`python3 tools/art/import_pixellab.py <object_id|url> prp_u0_hearth --request TRI-57` (a `prp_` key or an
`/objects/` URL takes the object route; `--kind object` forces it). That writes
`assets/props/u<n>/<key>/<key>.png` (one row per rotation, columns = idle then each clip; a single clip becomes
the looping idle and the drawn rotation a `still` column), `<key>_frames.json` (the character contract plus
`width_px`), `<key>_n.png`, the `.import` sidecars, `source_art/props/<key>/pixellab/` and the record in
`data/art/pixellab_assets.json` (kind `object`). `python3 tools/art/import_incoming.py` imports everything the
bot registered in `data/art/incoming.json` that is not yet recorded. In a location:
`add_prop(&"prp_u0_hearth", Vector3(x, 0, z))` (optional `facing` row and `solid` override) returns a
`PropBillboard` (`set_still`, `set_tint`); a pending or unknown key stands in as a labelled box of the declared
height, so the scene builds either way. `lint_data.py` and the unit suite check every declared prop has its
sheet.

**The text layer.** `data/text/` holds the prose the game reads aloud: `bestiary.json` (one entry per enemy
key and boss id: `name`, `entry`, `weak_hint`, `break_line`), `techs.json` (`description`, `flavor` per tech
id), `items.json` (`description`, `flavor`, `found` per item id, including the key items and relics dialogue
hands out), `ambient.json` (twelve one-line things townsfolk say per location id) and `codex.json` (a
`title` and one page per flag state). Plain ASCII, no numbers in tech descriptions; the full contract is
`docs/JOB_CHATGPT.md`. `Data` loads them (`Data.bestiary(key)`, `Data.tech_text(id)`, `Data.item_text(id)`,
`Data.codex_page(flag, state)`, `Data.ambient_lines(location_id)`); a bestiary, tech, item or codex key that
names nothing in the game is a validation error, a game id without prose is a gap listed in `Data.text_gaps`
and by `lint_data.py`. Ambient keys are Router location ids (`scripts/autoload/scene_router.gd`); a key whose
scene does not exist yet is a lint warning until the scene registers it. An NPC added with `add_npc` and no
script says one of its location's ambient lines when talked to.

**A texture.** Rooms ask for materials by name: `SceneKit.named("castle_flagstone")` loads
`assets/textures/generated/<name>_albedo.png` + `_normal.png` when they exist and a procedural placeholder
otherwise (`SceneKit.PLACEHOLDER_BY_NAME`). The world is 32 px per metre (`SceneKit.PX_PER_M`; a 1024 px sheet
covers 32 m). Import a generated texture with
`python3 tools/art/import_texture.py <png | pixellab image job id> <name> [--colours 15 --tool ... --seed ... --prompt "..."]`:
it quantises the tile to its own 15-colour material palette, wrap-blends the edges so it repeats, tiles it to
1024 px, writes the normal map and logs a row in `source_art/MANIFEST.csv`.

**Generated art and the manifest.** The build lead holds the PixelLab MCP (`python3 tools/art/pixellab_mcp.py
<tool> '<json args>'`; token from `PIXELLAB_TOKEN` or the local Claude config, never printed) for listings, job
checks and the generation Nich asks for. Every generated file, and every delivered one copied in as is, gets a
row in `source_art/MANIFEST.csv` (tool, model, seed, prompt, post-process): the project's AI-disclosure log. It
lives outside `assets/` because Godot imports any CSV under the project as a translation table.

**Music and SFX.** `tools/audio/` synthesises every track and effect (`python3 tools/audio/build_all.py`);
`Audio.play_music(&"id")`, `Audio.play_ambience(&"id")`, `Audio.play_sfx("family/id")`,
`Audio.set_rtpc("name", value)` drive them. New tracks need a loop point in their `.import` and a row in
`docs/reports/audio_build_report.md`. `lint_data.py` warns for every music or ambience id that data or a
location script names without a file under `audio/`; `AudioDirector` plays silence for an unknown id (an error
only when the Prologue or Chapter 1 asks for it).

## Conventions

- Statically typed GDScript, `class_name` for every reusable type, one responsibility per file, files kept
  small (split a script before it passes ~600 lines).
- Content is data: tune numbers in `data/`, not in code. Every bible number is a starting value; record
  changes in `docs/DECISIONS.md`.
- Commit small and often, with `git pull --rebase` before every push; nothing is force-pushed. On Nich's PC the
  build lead pushes to `main`; a cloud session works on its `ccr-…` branch and opens a draft PR (CLAUDE.md,
  "Branch rule").
- Placeholders are honest placeholders: generated-looking but clearly logged in `PROGRESS.md` for replacement.
