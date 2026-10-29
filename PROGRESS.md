# Progress

The hand-off between runs. Keep it honest: what exists, what is verified, what is next, what is broken.

## State on 2026-10-29 (run 1, foundation)

### What exists and is verified
- **Project** at the repo root: `project.godot` (Godot 4.7.2, Forward+, 640×360 UI base with integer scaling, input map, physics 60 Hz), eight autoloads, folder layout (`scenes/ scripts/ data/ assets/ audio/ shaders/ tests/ tools/ docs/`).
- **Autoloads:** `Data` (JSON registry + validation), `Flags` (Possibility Engine: flags, Light/Dark/Prismatic, Beckons, Amber Rifts, leans, ending qualification), `Game` (roster, party, inventory, integrity, debt, chapter, settings), `Saves` (JSON slots), `Universe` (canvas weights, fps table, 0.8 s blend), `Audio` (buses, music stems, SFX pools, RTPCs, tape stop), `Router` (locations with fade), `Story` (JSON cutscene/dialogue runner with a code-built dialogue box and Crono's three-choice wheel).
- **Combat core** (`scripts/combat/`): tags, constants sheet, stat curves (Combat Laws §15), `CombatantStats`, `ShieldComponent` (shave law, keyed plates, belief plates, regenerating/refill/shield-only rules, lock → rebuild → resume timers on battle time, Break Signature), `StatusComponent` (seconds/turn durations, stacks, periodic ticks, all modifiers), `TimeDebtComponent` (three HP layers, crack states, Reinforced, interest), `SolidityComponent` (debt, thresholds, Causal Collapse, voluntary tracking), `BoostBank` (shared pool, caps, owed BP), `TechDef`/`EnemyDef` (from JSON, validated), `DamagePipeline` (§6.4 in full), `TacticalPositioner` (all shapes analytic, blockers, snap), `EnemyBrain`, `BattleFields` (residual fields, Canvas Clash conversions), `TechEffects` (Rewind, HOLD, Borrowed Future, Fall Break, Time Debt Seal, Bekkler's Guilt, Astral Field, Shogun's Command, gourd, Ruin Purge, Eclipse X-Strike, Tachyon Needle, Ward, Mercury Pulse, Wire Loom Mend, NULL strip and more), and `BattleCoordinator` (battle_time clock, Sync Hold at 99.0, Ready Pool, Duals/Triples from the pool, Guard/Ens Parry, Swap, Spare, Withdraw, enemy wind-ups, Break cover, Prometheus Core, Oil-Blight, rewards, defeat = −5 integrity).
- **Tests:** `tests/run_tests.gd` → `tests/suite_core.gd`: **302 checks pass** headless, including the §18.7 acceptance checks (shave law, Lv3 bonus, keyed plates, Break timing 3.0 s + 18%/s + 0.4 s, HOLD, damage states 1.0/1.3/2.0/2.6, worked examples §6.5, falloff, ASTRAL displacement, positioner coverage and cover, BP caps, Crono ceiling and floor, crack states, Sera thresholds and phase-out, hairline rewind tax, parry, wind-ups, victory/XP/spare, defeat, Prometheus Core, Oil-Blight, Borrowed Future, Duals from the Ready Pool, data validation, flags/affinity/Beckons, save round trip, story runner branching).
- **Data:** techs for Crono, Sera, Krona, Marle and early Duals; all 11 U0 enemies (E23–E30, E01, E03, E04) with actions; character kits; 80 flag definitions across all universes; universes table; items; U0 encounters; the Prologue scripts (`data/dialogue/prologue.json`).
- **Tooling:** `tools/check.sh` (import, parse-all, tests, data lint, smoke boot with captures), `tools/build/parse_all.gd`, `tools/build/lint_data.py`, `tools/capture/smoke.gd`.
- **Docs:** `docs/DECISIONS.md`, `docs/QUESTIONS_FOR_NICH.md`.

### Not yet built
- No scenes beyond `boot.tscn` (the title and locations are registered in `Router` but their `.tscn` files do not exist yet).
- No rendering pipeline (compositor), sprites, environments, VFX, UI HUD, audio files.
- No field controller, actors, encounter zones, battle presentation.

## The plan (whole game, in priority order)

### A. Foundation (this run)
1. ✅ Project, autoloads, combat core, tests, check.sh.
2. ▶ HD-2D proof: compositor canvas stack (paper, grade, edge, VHS), lit diorama scene with a crisp billboard sprite, porcelain shader; `scenes/test/diorama.tscn`; screenshots in `/mnt/session/outputs/`.
3. Field layer: `CombatActor` (CharacterBody3D) with components, `ActorSprite` (quad + `sprite_canvas.gdshader`, SpriteFrames from sheets at the canvas rate), player controller, party follow, HD-2D camera rig (32° explore, 24° truth), interactables, encounter zones, the battle bootstrap (28×28 plane over terrain, dissolve), battle HUD (Turn Bar, shield plates with preview math, command deck, Boost pips, Sera's ring, telegraph decals, damage numbers).
4. Asset generators: `tools/art/pixel.py` helpers; a paper-doll pixel sprite generator (128 px cells, 4 directions, idle/walk/battle columns, per-canvas treatment); portraits from the catalog paintings (key_out → 512 PRT); texture generators (paper, stone, moss, wood); Blender kit builder for U0 (castle kitchen, courtyard, Atrium interior, Truce square); UI frame/icon generator; `tools/audio/` (music box, drones, SFX families, MIDI → FluidSynth tracks).
5. Vertical slice: Prologue (kitchen, stir ritual, first slip, the choice, gate, Atrium Cradle boss, courtyard) → Chapter 1 (Atrium hub: Robo, fountain, 999 dummy, Seed, Glenn, hearth choice; Fair: chase, Bekkler's tent, Telepod, Vaelos) → Chapter 2 opening (bamboo grove duel, Pagoda fracture, Kuro-Truce, Krona joins, Eclipse X-Strike).

### B. Main game
6. Chapter 2 remainder (Iron Bridges and Ens Parry, karma loop, Goyama, Ashen Daimyo, Cobalt Nodachi, Mammon Furnace, Weeping Shogun) + Interlude Day 1.
7. Chapter 3 U2 (Slag-Yards, Porcelain Weaver, Cassia, Spine-Highway, three roads, Arris Dome, Geno-Foundry, R-66Y with the Possibility Branch) + Interlude Day 2.
8. Chapter 4 U3 (Mycelia Floor, Xyloph, Mid-City, Canopy, Azar) + Day 3.
9. Chapter 5 U4 (Baptistery, Nave, Library, Vesper, caustic puzzles, Central Eye, Schala Shadow Weaver, Dreaming Moon) + Day 4.
10. Chapter 6 U5 (the 22-minute loop, Ringmaster, Pierrot-Glenn, Hall of Mirrors, Cyrus) + Day 5.
11. Chapter 7 U6 (CRT shrine, Static, Oracle, clinic, tuning, Neon Bloom, Isolator) + Day 6.
12. Chapter 8 U7 (Root Approach, shrines, lotus ponds, Gold Leaf repair, Kami-Ori, Omega-Spekkio's Dojo) + Day 7.
13. Chapter 9 U8 (Navel String, Gallery, Cradle, Vaelos: Which Father) and the ending gate.
14. Endings 1–4 (Golden Light, Empress Heir, Vaelos Child, Borrowed Future), New Game+ carry-overs.
15. Side quests (Ch15: Seed of Doan, Bekkler doll, Glenn's arm, Crown/Klein/Robo's heart), Possibility Codex (Ch14), Director Commentary (Ch16), Endings 5–8.
16. Polish, balance, accessibility (reduced flicker, captions, auto Sync Hold), performance; exports for Linux, Windows, web into `/mnt/session/outputs/`.

## Next steps (start here)
1. Build the compositor canvas stack and the diorama proof scene; capture and look at the screenshot.
2. Build the field layer and the battle scene (`scenes/battle/`), with a sandbox encounter that plays end to end with the HUD.
3. Sprite generator + Crono/Sera/Marle/Robo sprites and portraits; U0 kitchen kit; run the Prologue.
4. Spawn subagents for: full tech library JSON from Combat Laws §11; enemy codex JSON for U1–U8 from §13; audio families (music box, SFX) under `tools/audio/`.

## Known issues
- `project.godot` points `run/main_scene` at `scenes/boot/boot.tscn`, which routes to `title` (not yet built): the boot logs a warning and idles.
- `Audio` and `Story` build their UI from code; the theme is a stub (`assets/ui/theme.tres`), fonts are the engine default until the pixel/text fonts are generated.
- Shared plates (`shared_owner`) and Break-immune-until conditions are implemented in `ShieldComponent` but not yet exercised by a boss.
