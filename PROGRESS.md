# Progress

The hand-off between runs. Keep it honest: what exists, what is verified, what is next, what is broken.

## State on 2026-10-29 (run 1, end of run: Prologue plays end to end, Chapter 1 hub built, art is placeholder)

### Direction from Nich (read first)
All current art is placeholder: code-generated sprites (`tools/art/spritegen.py`), procedural textures
(`tools/art/make_textures.py`), rooms built from textured primitives, blob enemies. The target is Chrono
Trigger-grade hand-pixelled characters in Octopath-grade HD-2D dioramas; nothing blocky, boxy or voxel may
ship. **Do not polish the generators further.** From the next run, `/mnt/session/uploads/secrets.env` may hold
API keys (PixelLab for 8-direction characters, animations, tilesets, objects, VFX and normal maps; an image
model for portraits, textures, concept frames, painted backdrops). First job when it exists: build
`tools/art/pipeline/` that calls those services and writes straight into the existing contracts (sheet
layouts in `SpriteLibrary.DEFAULT_TABLE`, 128 px cells, `<id>_field.png` + `_frames.json` + optional
`_field_n.png`/`_field_m.png`; enemies `<key>_sheet.png` under `assets/enemies/u<n>/<key>/`; textures by
the names `SceneKit` already loads), then run the same per-canvas finish (`finish_frame`) and import
settings. Until then: systems, chapters, scripts, dialogue, bosses, menus, saves, music. Keep
`docs/screenshots/` (six captures + README) refreshed after every visual milestone. Never print or commit
the keys.

### How to run and check
- `source tools/setup_godot.sh` (Godot 4.7.2 on PATH). `bash tools/check.sh` = import, parse-all, unit tests (423 checks), data lint, visual smoke with captures; `--no-visual` for headless only.
- Boot args (all scenes): `--scene=<id>`, `--spawn=<marker>`, `--checkpoint=<id>`, `--party=a,b,c`, `--chapter=<n>`, `--integrity=<n>`, `--level=<n>`, `--flag=Name:State`, `--say=text`, `--autobattle`.
- Probes (headless): `godot --headless --path . --script res://tools/build/prologue_probe.gd -- --autobattle` plays the whole Prologue (breakfast → gate → Cradle → courtyard → Atrium) and prints `PROBE_END ok=true`; `tools/build/battle_probe.gd -- --scene=test_arena --autobattle --boss=<id> --party=crono,sera,marle --level=4 --boss_hp=500` drives one boss; `tools/build/walk_probe.gd`, `ui_probe.gd`, `curves_probe.gd` are small diagnostics.
- Captures: `bash tools/capture/render.sh <scene_id> <prefix> [frames] [args]` → `/tmp/captures/`. Software Vulkan runs at ~2 fps; keep captures under 600 frames. Scene demo args: `--demo=cradle` (kitchen, checkpoint `prologue_gate_open`) walks into the hall.

### What exists and is verified
- **Project**: Forward+, UI canvas 640×360 with integer scaling (window 1280×720), eight autoloads (`Data`, `Flags`, `Game`, `Saves`, `Universe`, `Audio`, `Router`, `Story`). Main scene `scenes/boot/boot.tscn` → title.
- **Combat core** (`scripts/combat/`, 423 headless checks): every Combat Laws system from the previous hand-off plus `BossDef` (phases → per-phase `EnemyDef`), coordinator `paused`, `add_enemy`, `undamageable` (seals), `summon:<key>` enemy effects, XP overrides.
- **Boss framework**: `scripts/battle/boss_controller.gd` watches the HP pool, swaps shield/tags/actions per phase, runs the phase's `script` (a dialogue id in the boss JSON) with the clock stopped and input blocked, spawns `adds` per phase (capped by `max_adds`), hands events to an optional director `scripts/battle/bosses/<id>.gd` (`on_setup/on_phase/on_break/on_parry/on_action/on_tick/on_defeat/on_summon`), applies `drops`. Story battles: `{"battle": "<encounter or empty>", "boss_id": "...", "at": "<marker>", "center": "<marker>", "music": ..., "on_win"/"on_lose"}`. Story scripts can nest (`{"run": "<script>"}` and phase scripts while a battle waits).
- **Atrium Cradle** (`data/bosses/atrium_cradle.json`, `scripts/battle/bosses/atrium_cradle.gd`): three phases, keyed plates, Break Signature (LIGHT holds the crack / SWORD-FIRE widens it −3 integrity), Dollhouse Seal paid from Crono's deck (PAY TIME DEBT, 5% integrity, free action), Shardling adds, U7 gold-leaf swap on Break in phase 3, perfect parry on Crack-Slide → 1.5 s Prismatic window → Astral Smear Dash grants The Bowl Still Whole. Retuned to Lv 2 / 1,200 HP (see DECISIONS).
- **Data**: 123 techs (all §11), 11 character kits, 82 enemies (all codices U0–U9), 31 bosses (`data/bosses/`), 71 encounters, 80 flags, items, universes, dialogue for the Prologue and the Chapter 1 hub. `docs/reports/enemy_codex_report.md` lists every judgement call and every mechanic that is notes-only.
- **Field layer**: `Location` base (world, lights, camera rig, party spawn, markers, zones, interactables, `add_npc` → `FieldNPC`, `add_cast` (a CombatActor standing in the scene before joining), `rebuild_party`, `add_ink_puddle` (24 fps Chronoslip residue + U1 leak), `add_door`, story battles, defeat handling with story-battle revive), `EncounterZone`, `Interactable`, `PlayerController`, `PartyFollow`, `CombatActor`, `ActorSprite`, `SpriteLibrary`, `HD2DWorld` (compositor + `set_leak(universe, amount)`), `HD2DCameraRig`.
- **Scenes**: `scenes/ui/title.tscn` (New Game / Continue / Options / Quit; backdrop is plate-00 for now), `scenes/u0/guardia_kitchen.tscn` (kitchen + hall, breakfast cutscene with `stir_ritual` / `first_chronoslip` / `sera_collapses` / `after_fall`, three-way fall choice, Fracture Gate, hall encounters, Cradle trigger, exit), `scenes/u0/guardia_courtyard.tscn` (rain, Glenn and Magus, Epoch gauntlet, gate to Truce), `scenes/u0/atrium_horologe.tscn` (first hub: round brass hall, dais and clock pillar with turning hands and 72 BPM vines, pool, Seed pot, workbench with the little Bekkler doll, gramophone, dummy plinth, loft, eight gates lit when `Gate_U<n>_Open`, Robo rest/save/galaxy, arrival script), `scenes/test/diorama.tscn`, `scenes/test/arena.tscn` (`--encounter=`, `--boss=`, `--boss_hp=`).
- **Checkpoints** (`Game.checkpoint`): `prologue_kitchen` → `prologue_breakfast_done` → `prologue_gate_open` → `prologue_cradle_done` → `atrium_arrival` → `atrium_hub`. Saves to slot 0 at each.
- **Art**: `tools/art/spritegen.py` + `tools/art/characters.py` (paper-doll rig, chibi HD-2D proportions, 4 directions × 70 columns, per-canvas finish; asymmetric west view keeps Crono's gauntlet on his right arm; ~10 s per character). Sheets exist for crono, sera, krona (U1 sumi finish), marle, glenn_marshall, magus, vaelos_boy, villager_m/f, child, guard, elder, merchant, ashen_villager, ashen_soldier. Portraits from the catalog for the main cast. Textures in `assets/textures/`.
- **Audio** (`audio/`, 95 MB, built by `python3 tools/audio/build_all.py`): title, Guardia morning, Wind Scene 1024 (box/piano/wind/tick + debt variants), Truce 1024, Fair, battle core U0/U1, Cradle boss, Vaelos, Sera, U1 morning, Krona duel, transit, stings; SFX families ui/combat/porcelain/weapons/magic/footsteps/time/status/creatures; beds amb_u0/amb_u1/amb_transit. Loudness-normalised, loop points in the `.import` sidecars. Stem tracks have no base `.ogg` on purpose. `docs/reports/audio_build_report.md` has the table.
- **Outputs**: screenshots in `/mnt/session/outputs/screenshots/`.

### Verified visually this run
Kitchen with the party and the dialogue box, title screen, hall with placeholder enemies, generated sprites lit with shadows in the arena. The Cradle fight itself has only been verified headless (probe) and by the HUD capture from the arena earlier.

## Next steps (start here)
0. If `/mnt/session/uploads/secrets.env` exists: copy nothing into git; write `tools/art/pipeline/` (PixelLab characters → `assets/characters/<id>/`, enemies, tilesets; image model → portraits/textures/backdrops), regenerate Crono/Sera/Marle/Krona first, look at them in the kitchen, refresh `docs/screenshots/`.
1. **Verify Chapter 1 end to end**: `godot --headless --path . --script res://tools/build/ch1_probe.gd -- --autobattle`. Loft → crack check → Rewind → Father Tank all pass; the 999 Shard Doll's phase 3 (three dolls, all Break within 3 s) was still stalling the autobattle at cutoff. The director now tires the dolls after 4 rebuilds (12 s window, 3 plates) and stops rebuilding after 8; re-run the probe, then play the rest (Glenn, rest → midnight, hearth, Fair call).
2. **Leene Square and the Fair** (`scenes/u0/leene_square.tscn`, Story Bible Ch1 beat 10): crowds, chestnut vendors, Bekkler's tent (`Bekkler_Confessed`), Lucca's Telepod pavilion, the chase through Sera's ghosts, the seven-canvas rift-spawn battle (write `data/encounters/u0.json` `fair_rift_spawn` from low-level U1–U7 enemies), Vaelos's descent (sprite needed), the leap → `bamboo_grove`. `leave_for_fair()` in the Atrium already routes there with Crono alone.
3. **Chapter 2 opening**: `scenes/u1/bamboo_grove.tscn` (U1 ink canvas, `Universe.set_universe(1)`), Krona duel (`data/bosses/krona_duel.json`, needs a director), Pagoda fracture, Kuro-Truce, Krona joins (`recruit`), Eclipse X-Strike. Then the rest of Chapter 2.
4. Menus: a Tab menu (party, techs, items, relics, settings, save slots) and a save/load screen; the title's Options stub.
5. Music hooks: `Audio.set_rtpc` consumers (porcelain_stress → box stems, sync_hold duck, translucency → Sera's strings), boss phase stems, the Fair chase stem.
6. Boss directors for Chapter 2+ as their chapters are built; mechanics listed as notes-only in `docs/reports/enemy_codex_report.md`.
7. Keep `docs/DECISIONS.md`, `docs/QUESTIONS_FOR_NICH.md` and `docs/screenshots/` current.

## Known issues
- All art is placeholder (see the direction above). Enemies and bosses are grey blobs; the two art subagents of this run (enemy sprites, textures) were cut off by the credit limit before writing files.
- Chapter 1 Shard Doll phase 3 not yet verified to complete under autobattle (see next step 1).
- Autobattle AI (used by probes) never heals, so probe losses overstate difficulty; still, defeat costs −5 integrity each retry, which can drain a Prologue (probe ended at 29–50 integrity). Consider a story-battle exemption or a floor during the Prologue.
- The floor textures read as cracked mud at diorama distance; the kitchen lights are flat; the hearth has no fire.
- A faint rectangle shows inside the dialogue box bottom-right (some child control's default style); harmless, not yet traced.
- Title backdrop uses design plate-00 (temporary).
- U1 ink grade does not exempt Crono's watercolour (bible: only crimson and Crono keep colour).
- Pierrot-Glenn portrait crop is wrong (shows Cyrus's ghost). `knows_tech` kits for crono/sera/krona list few duals/triples (data/characters) — add them before Chapter 2.
- Audio: tracks were composed blind; a listening pass is needed. Not rendered yet: fair chase stem, boss phase clips, Truce tine variants.
- Boss JSON mechanics marked notes-only in `docs/reports/enemy_codex_report.md` (conjunction weaknesses, untargetable sub-targets, battle-time heal timers) need code when their chapters are built.
- `ObjectDB instances leaked` warnings at the end of probe scripts (scripts quit mid-scene); harmless.

## The plan (whole game, in priority order)
A. Foundation ✅ project, autoloads, combat core, tests, check.sh, HD-2D proof, field layer, battle scene, sprite generator, audio toolchain, boss framework, Prologue.
B. Vertical slice ▶ Chapter 1 hub beats + Fair, Chapter 2 opening through Krona joining, with enemy art and U0/U1 environment kits.
C. Chapters 2–9 in order, each with its bosses (directors), side content, Sera interludes, music per universe.
D. Endings 1–8, New Game+, Possibility Codex (Ch14), side quests (Ch15), Director Commentary (Ch16).
E. Polish, balance, accessibility (reduced flicker, captions, auto Sync Hold), performance; exports for Linux, Windows and web into `/mnt/session/outputs/`.
