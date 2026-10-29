# Progress

The hand-off between runs. Keep it honest: what exists, what is verified, what is next, what is broken.

## State on 2026-10-29 (run 1, continued: the Prologue plays end to end)

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
1. **Chapter 1 beats in the Atrium** (Story Bible §6 Ch1): loft wake + crack check (focus), the nightmare + Rewind tutorial (a scripted mini-battle or a field verb), Father Tank window, 999 Shard Doll boss (`data/bosses/shard_doll_999.json` exists; needs a director: fake belief plates, three-doll split at 20%, Spared/Salvaged/DollMeetsDoll flags, `Pushing Sera to 40%`), Krona's ink footprints (`Ink Path`), Seed of Doan watering (counter `seed_waters`), Glenn's honour check, midnight hearth choice (`Crono_Confession` tell/hide), the Fair trigger.
2. **Leene Square and the Fair** (`scenes/u0/leene_square.tscn`): crowds (villager sprites), chestnut vendors, Bekkler's tent (`Bekkler_Confessed`), Telepod pavilion, the chase, rift-spawn battle from seven universes, Vaelos descent (needs a Vaelos sprite: tall alabaster, fibre-optic mane), the leap into the seam → `bamboo_grove`.
3. **Chapter 2 opening**: `scenes/u1/bamboo_grove.tscn` (ink canvas), Krona duel (`krona_duel.json`), Pagoda fracture, Kuro-Truce, Krona joins (`recruit`), Eclipse X-Strike. Then the rest of Chapter 2.
4. **Enemy and boss art**: a code-drawn enemy sprite generator (Dust Mote Cluster, Porcelain Shardling, Ashen Spoon, Vaelos Echo, Bellkeeper, Moss-Mouse, Bekkler Fragment, Ferro-Drone, Cradle, Shard Doll) — everything is a grey placeholder blob now.
5. **Environment quality pass** for U0: flagstone/plank textures at 64 px/m with proper grout (the current stone reads as cracked mud), hearth fire particles, props (pots with handles, dishes), Blender kit for arches/columns/the Robo pillar face. Replace the title backdrop with our own Atrium render.
6. **Battle presentation**: verify the Cradle fight visually; boss name/phase banner; Pay Time Debt moment VFX; Sorrowful Blue 12 fps step; the Sera ring on the HUD; a save/load + party menu (Tab).
7. Fonts (Reference Bible §7.6), icon set (§7.4), theme.
8. Keep `docs/DECISIONS.md` and `docs/QUESTIONS_FOR_NICH.md` current.

## Known issues
- Enemies and bosses are placeholder blobs (`SpriteLibrary.placeholder`); the Cradle and the Shard Doll especially need art.
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
