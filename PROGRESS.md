# Progress

The hand-off between runs. Keep it honest: what exists, what is verified, what is next, what is broken.
Nich makes the art decisions; his asset team generates; the build lead (the Claude Code session Nich runs)
builds, imports and records; the studio assistant writes dialogue and audits deliveries.

## Run 4 (2026-11-02, cloud session): branch `ccr-71b3659f-ryo8fv`, draft PR iteatsthesalt/TRIGGER-Time-Debt#1

**This run could not push to `main`** (cloud sessions work on their branch, CLAUDE.md "Branch rule"). Everything
below is on the branch and in draft PR #1; Nich merges. The prototype repository has a one-commit draft PR of its
own (iteatsthesalt/Trigger#6: a status note pointing here). The full record of the run is
`docs/reports/WORKSPACE_AUDIT_2026-11-02.md`.

### Direction (from Nich, in session)
- **The Nov 1 "Chrono-Style Recreation Breakdown" is the style, and assets are remade at its scale** (DECISIONS
  "Direction"; the text is `design/STYLE_BREAKDOWN_2026-11-01.md`): 64x64 three-head sprites (hero 56-61 px =
  1.78 m), one locked palette (Resurrect 64 until Nich confirms), coloured selective outlines, held frames; the
  world at 32 px per metre (`SceneKit.PX_PER_M`); 15-colour material families. Superseded: the 128 px chibi field
  tier (still shipped until each character's 64 px set exists), the asset team's 256 px "field v3" sets (not
  imported), the 64 px/m texel rule.

### What landed and is verified
Verified on the branch head: `bash tools/check.sh` passes in full (import, parse, 3,494 unit checks in 17 suites, data lint, 20
Python tool tests, `prologue_probe`, `ch1_probe` and `battle_probe` each `PROBE_END ok=true`, the smoke boot and the
lineup and arena captures, which were looked at).
- **Text layer** (Linear TRI-80): `data/text/` loaded and validated by `Data`; ambient lines for unscripted NPCs.
- **Props** (TRI-31..TRI-78): the object import route, `PropBillboard` + `Location.add_prop`, `data/props/props.json`,
  47 props dressing the kitchen, courtyard and Atrium (screenshots 11-14).
- **PixelLab by the build lead** (~60 generations): twelve U0 textures at 32 px/m, the Phase-1 style kit (anchor
  candidates, Wang test tilesets, a 9-slice frame, an impact burst; screenshot 20), the 64 px Crono anchor as the
  `px64` variant (screenshots 22-23); `tools/art/pixellab_mcp.py`, `tools/art/import_texture.py`,
  `source_art/MANIFEST.csv`.
- **Workspace audit**: two verified audits (docs: 140 confirmed; code: 199 confirmed or plausible). The docs fixes
  landed first (prototype snapshot removed, bibles reconciled with the data, README/CLAUDE/ART_PIPELINE/
  ASSET_REQUESTS/BOT_REVIEW rewritten); then fifteen code clusters, each reviewed, 168 of the 199 fixed, 23 partly, 8 left with a recorded reason, and a
  final integration review (two rounds over six angles: 41 findings, 39 confirmed by an independent refuter and all fixed, among them two critical defects older than this run: battle input was ignored in every story battle, and the party could be placed past the kitchen floor after a zone battle). What changed for a player: Withdraw works and is not a
  defeat; the fallen stand up after a win; spared and broken enemies are settled; story-battle retries no longer stack
  bodies; a Break plays out before a boss changes phase; the final Break pays the boss's XP and drops; Ruin lowers
  Crono's ceiling; DoTs, regen and BLIND work; 57 technique effects moved from silent plain damage into a data
  table; kit unlocks by level, flag and drop are learned; enemies drop items and scale by Effective Rank Level; the
  gate toll is charged; saves are atomic and settings have their own file; the Chapter 1 save points resume
  somewhere playable; the Fair call stops with a caption instead of a dead end; ghosts and a fading Sera are drawn
  translucent. Every call is in DECISIONS "Code-audit fixes, second pass"; 56 calls to confirm are in
  QUESTIONS_FOR_NICH.
- **Tests and gate**: `tests/` is one suite per area on a shared base (`suite_base.gd`); `tools/check.sh` now runs the
  probes and the Python tool tests and fails on import errors; `Saves.suspended` keeps headless runs off the
  player's saves.

### How to run and check
- `source tools/setup_godot.sh`; `bash tools/check.sh` (the full gate, about five minutes in a cloud container with a warm
  import cache), `--no-visual` (no boot or captures), `--quick` (import, parse and the suites only).
- Boot and battle arguments, probes and captures: README "Run and check".
- Hourly art check: `python3 tools/art/import_incoming.py --dry-run`; listings
  `python3 tools/art/pixellab_mcp.py list_characters '{"limit": 50}'`.

## Next steps (start here)
1. **Close the style gate with Nich**: anchor candidate and palette (screenshots 20 and 22), window frame A or B;
   then Crono's 64 px clips (run, hurt, ready, attack, ko, revive) and promote `px64` to the base `field` sheet
   (ART_PIPELINE 1b). Tell the asset team to stop at 128/256 px until then (QUESTIONS_FOR_NICH).
2. **The slice at 64 px** (ASSET_REQUESTS "Style gate"): Sera and Krona anchors and clips, six Prologue/Chapter 1
   NPCs, the four U0 enemies and the Atrium Cradle, two 48 px portraits, one exterior Wang set and the kitchen kit.
3. **Leene Square and the Fair** (Story Bible Chapter 1 beat 10): the scene, its first checkpoint writes the arrival
   autosave and sets Sera's state; then Chapter 2's `bamboo_grove` against `data/dialogue/chapter2.json` (the
   markers, actors and Router ids it needs are listed in the audit report, STORY-10).
4. **Boss directors as their chapters arrive**: the director-only gates (scripted, threads_cut, honest_lines,
   sera_voluntary_phase_out, stand_still_12s, ending) of nine bosses (lint warns per boss), the Krona duel's
   `duel_overcharge` call, the Atrium Siege's three waves.
5. **Menus and Options**: party, techs, items, relics, settings, save slots; the breakdown's Options rows.
6. **Audio**: 20 music ids without a track (lint lists them; all are Reference Bible 8.5 rows), three sfx ids
   (`combat/phase_shift`, `time/amber_chime`, `weapons/parry_don`) and the run-time ids lint cannot see
   (`time/gate_open_u2..u8`, `magic/<element>_contact` for most elements); the RTPC names nothing consumes.
7. **Open engine items** from the audit: the perfect-frame input, a HOLD step picker, Confuse, the Lichen Colony's
   shared damage, New Game+ and the ending flow, save on quit and a Robo "Save" that does not rest. Bring
   `battle_coordinator.gd` (815 lines after the split into rule classes) under 600, and the test suites over it.
8. **A by-hand battle in the gate.** Every probe runs `--autobattle`; the input tests now drive the deck with synthetic
   input events, but a probe that plays the Cradle through the deck would have caught the story-battle input bug
   long before the audit.
9. Keep `docs/DECISIONS.md`, `docs/QUESTIONS_FOR_NICH.md`, `docs/ASSET_REQUESTS.md`, `docs/screenshots/` current.

## Known issues
- Chapter 2's 28 scripts cannot be reached until the U1 scenes exist; Chapter 1 ends at the Fair call with a caption.
- Lint warnings, all tracked: 12 boss phases whose gate needs a director that comes with its chapter, 20 music ids
  without a track, 3 sfx ids without a file, 5 ambient-chatter locations with no scene yet, 3 Duals with no learner
  (`origami_requiem`, `time_debt_paid`, `fake_family_photo`), `atropos_ribbon` taught by no script yet, the
  scheduled `ossuary_arrival` scene, the `duel_overcharge` call, and `assets/enemies/citizen_husk` matching no key.
- Mid Tonic, Revive and Cobalt Wash have no source (TRI-79, QUESTIONS_FOR_NICH); Tungsten Scrap drops but waits
  for crafting.
- Three authored boss phases cannot be reached by HP (azar `red_moon`, guardian_triad `dance_not_curse`, r66y
  `mother_brain_unmasked`); a director or new windows decide (QUESTIONS_FOR_NICH).
- The renders are verified only under software Vulkan: the HDR bloom on emissives and the fade pass's missing shadow
  need a look on a GPU. The Chronoslip is staged but has no capture yet.
- Marle's only sheet is the one-frame realistic `marle_field`, so she glides when a script walks her.
- The dialogue box and HUD are still code-drawn; the delivered UI panels wait for Nich's frame choice.
- Scripts over the ~600-line guideline: `battle_coordinator.gd` (815), `tools/art/spritegen.py`, `tools/audio/synth.py`,
  `tools/build/write_chapter2_dialogue.py`; seven test suites are over it too.
- Audio tracks were composed blind; a listening pass is needed.
- U1 ink grade does not exempt Crono's watercolour. Pierrot-Glenn's portrait crop is wrong. The title backdrop is
  plate 00.
- Software-Vulkan captures draw the dust-mote particles as a white square (a lavapipe artefact, not in-game).
- The battle HUD at 720p: the third party card runs off the bottom edge, and the plates of enemies standing close
  together overlap (screenshot 24).
- A Router fade now hides a dialogue line already on screen the moment it starts (the lines draw above the fade so
  the New Game wake reads over the held black); a debug start at chapter 0 after the Cradle gives Sera no Fall Break.

## The plan (whole game, in priority order)
A. Foundation ✅ project, autoloads, combat core, tests, check.sh, HD-2D proof, field layer, battle scene,
   audio toolchain, boss framework, Prologue, art pipeline (characters, props, textures, UI; the manifest), the
   2026-11-02 audit and its fixes.
B. Style gate ▶ the 64 px anchor approved, the palette locked, the slice assets remade at the new scale.
C. Vertical slice: Chapter 1 hub beats and the Fair, Chapter 2 opening through Krona joining.
D. Chapters 2-9 in order, each with its bosses (directors), side content, Sera interludes, music per universe.
E. Endings 1-8, New Game+, Possibility Codex (Ch14), side quests (Ch15), Director Commentary (Ch16).
F. Polish, balance, accessibility, performance; exports for Linux, Windows and web.

## Earlier runs
- **Run 3 (2026-10-29, Nich's Windows PC; the build lead is Claude Code):** Godot and python shims in
  `.tools/bin`; the Chapter 1 Shard Doll fixed (a broken doll's Break held for the director, undamageable split
  dolls, the integrity bleed capped); `--chapter` at boot unlocks kits; the autobattle's tech pick; the Slack
  `#all-trigger` hub and its `[BUILD]` threads.
- **Run 2 (2026-10-29):** the PixelLab character import route (`import_pixellab.py`, eight-row sheets, normal maps,
  frames json, contact sheets, `data/art/pixellab_assets.json`); `SpriteLibrary` tiers and variants;
  `crono_field`, `crono_action`, `sera_field`, `krona_field`, `marle_field` imported; screenshots 07-10.
- **Run 1 and the lead hand-off (to 2026-10-29 09:50 EDT):** the project, eight autoloads, the Combat Laws core,
  the boss framework with directors, the Atrium Cradle, the data for every tech, enemy, boss, encounter and flag,
  the field layer, the Prologue scenes and the Chapter 1 hub beats, the audio toolchain and the vertical-slice
  music. The Console build agent handed the lead to the Claude Code session Nich runs.
