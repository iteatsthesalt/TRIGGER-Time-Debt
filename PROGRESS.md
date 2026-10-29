# Progress

The hand-off between runs. Keep it honest: what exists, what is verified, what is next, what is broken.
Two agents work this repository in turns (the build agent and the studio assistant); Nich makes the art.

## State on 2026-10-29 (run 2, in progress)

### The plan now (from Nich, read first)
- **Art comes from Nich's PixelLab bot**, which works from `docs/ASSET_REQUESTS.md` (prioritized, ready-to-send
  requests; entries move to Done with the PixelLab id when imported). Agents do not generate art beyond the
  pipeline proof. **Check the PixelLab library at least hourly and before any scene work** (`list_characters`,
  `list_objects`, `list_topdown_tilesets`, `list_ui_assets`, `list_images`), import anything completed that
  matches an asset key with `python3 tools/art/import_pixellab.py <id|url> <asset_key> [--name "<PixelLab name>"]`,
  wire it in, screenshot it; the import is recorded in `data/art/pixellab_assets.json`. Never delete anything on
  the account. Characters with pending jobs are zip-locked: wait or `--listing`.
- **A character is a set of sprites**: tiers map/field/action/portrait + variants (`docs/ART_PIPELINE.md` §1b).
- **Lanes:** the studio assistant writes `data/dialogue/chapter2.json` and ASSET_REQUESTS Batch 4 (U1); the
  build agent keeps Chapter 1, the Fair, scenes/, scripts/ and wires Chapter 2 scenes to those dialogue ids.
  Dialogue commands are listed in README ("Dialogue and cutscenes"); add new ones there.
- Pull (`git pull --rebase`) before every push; both agents commit to `main`.

### Art pipeline (done, verified in-engine)
- `tools/art/import_pixellab.py` (+ `tools/art/pipeline/pixellab_import.py`): downloads a PixelLab character,
  packs the 8-row sheet (s, w, e, n, sw, se, nw, ne), feet 8 px above the cell bottom, per-canvas finish,
  `_n` normal sheet, `<stem>_frames.json`, `.import` sidecars, contact sheet in `source_art/`, record in
  `data/art/pixellab_assets.json`; flags a direction that came back facing the wrong way.
- Engine: `SpriteLibrary.resolve/apply(sprite, id, fps, tier, variant)` with fallbacks, `has_tier`;
  `ActorSprite.set_height` (bible metres from drawn pixels), eight-way `face_vector`, `set_tier`, `set_variant`;
  fixed: `set_sheet` now always applies the first frame rect. Review scene `scenes/test/lineup.tscn`
  (`--ids=`, `--anim=`, `--tier=`, `--variant=`).
- Imported: `crono_field` (idle, walk, run, hurt, ready, ko), `crono_action` (idle; the realistic base),
  `sera_field` (idle, walk, run), `krona_field` (idle, walk), `marle_field` (idle; realistic proportions, Nich to
  decide). On the account, not yet imported: `villager_m` (`feef7cc5…`, zip locked by its animation jobs), the
  bot's alternative Krona (`364e2216…`), and realistic Sera/Crono tests by the studio assistant.
- Screenshots: `docs/screenshots/07–10`.

### How to run and check
- `source tools/setup_godot.sh`; `bash tools/check.sh` (import, parse-all, 435 unit checks, data lint, visual
  smoke) or `--no-visual`.
- Boot args: `--scene=<id>`, `--spawn=<marker>`, `--checkpoint=<id>`, `--party=a,b,c`, `--chapter=<n>`,
  `--integrity=<n>`, `--level=<n>`, `--flag=Name:State`, `--say=text`, `--autobattle`.
- Probes: `tools/build/prologue_probe.gd -- --autobattle` (whole Prologue, passes), `ch1_probe.gd -- --autobattle`
  (Chapter 1; **stalls in the Shard Doll's third phase**, see Known issues), `battle_probe.gd -- --scene=test_arena
  --autobattle --boss=<id> --party=crono,sera,marle --level=4`.
- Captures: `bash tools/capture/render.sh <scene_id> <prefix> [frames] [-- args]` → `/tmp/captures/`.

### What exists and is verified (unchanged from run 1 unless noted)
- Project, eight autoloads, Combat Laws core (435 checks), boss framework with directors, Atrium Cradle,
  data for 123 techs / 82 enemies / 31 bosses / 71 encounters / 80 flags, field layer, Prologue scenes
  (kitchen, courtyard, Atrium hub), Chapter 1 hub beats, audio toolchain and vertical-slice music.
- `PortraitCache` looks in `assets/portraits/<id>/<id>_<expr>.png` first; `SceneKit.named("<material>")` looks in
  `assets/textures/generated/` first (import targets for Nich's portraits and textures).

## Next steps (start here)
1. **Hourly: check the PixelLab library and import** (see the plan). Import `villager_m` when its jobs finish.
2. **Fix the 999 Shard Doll phase 3** so `ch1_probe.gd` reaches `PROBE_END ok=true`; then play the rest of
   Chapter 1 (Glenn, rest → midnight, hearth, Fair call).
3. **Leene Square and the Fair** (`scenes/u0/leene_square.tscn`, Story Bible Ch1 beat 10): crowds, Bekkler's
   tent, Lucca's Telepod pavilion, the chase, the rift-spawn battle (`fair_rift_spawn` encounter), Vaelos's
   descent (action tier A7 when it arrives; placeholder until then), the leap → `bamboo_grove`.
4. **Chapter 2 opening** scenes wired to the studio assistant's `chapter2.json` ids: `bamboo_grove`, Krona duel
   director (`data/bosses/krona_duel.json`), Pagoda fracture, Kuro-Truce, Krona joins, Eclipse X-Strike cut-in
   (action tier: `ActorSprite.set_tier(&"action")` with clips A2 + A5 composited).
5. Menus (party, techs, items, relics, settings, save slots), save/load screen, title Options.
6. Music hooks (`Audio.set_rtpc` consumers), boss phase stems, Fair chase stem.
7. Keep `docs/DECISIONS.md`, `docs/QUESTIONS_FOR_NICH.md`, `docs/ASSET_REQUESTS.md`, `docs/screenshots/` current.

## Known issues
- **Chapter 1 Shard Doll phase 3** (three dolls must Break within 3 s): the autobattle party stays at 1 HP and
  the phase never advances (probe: `shield=24/24 adds=3` for 500 s). Suspects: the adds are not targeted by the
  autobattle AI, or `on_add_break` never fires. Fix next.
- Rooms, textures, props and enemies are placeholders until Nich's assets land (ASSET_REQUESTS batches 2–9).
- Marle's imported sprite is realistic-proportioned beside a chibi cast (Nich to decide).
- Autobattle AI never heals, so probe losses overstate difficulty; defeat costs −5 integrity each retry.
- Kitchen lights are flat; hearth has no fire; a faint rectangle shows inside the dialogue box bottom-right.
- Title backdrop uses design plate-00 (temporary).
- U1 ink grade does not exempt Crono's watercolour. Pierrot-Glenn portrait crop is wrong.
- Audio: tracks composed blind; listening pass needed; fair chase stem, boss phase clips not rendered.
- Boss JSON mechanics marked notes-only in `docs/reports/enemy_codex_report.md` need code with their chapters.
- `ObjectDB instances leaked` warnings at the end of probe scripts; harmless.

## The plan (whole game, in priority order)
A. Foundation ✅ project, autoloads, combat core, tests, check.sh, HD-2D proof, field layer, battle scene,
   audio toolchain, boss framework, Prologue, **art pipeline (PixelLab import, tiers, normal maps)**.
B. Vertical slice ▶ Chapter 1 hub beats + Fair, Chapter 2 opening through Krona joining, with Nich's assets
   imported as they arrive.
C. Chapters 2–9 in order, each with its bosses (directors), side content, Sera interludes, music per universe.
D. Endings 1–8, New Game+, Possibility Codex (Ch14), side quests (Ch15), Director Commentary (Ch16).
E. Polish, balance, accessibility (reduced flicker, captions, auto Sync Hold), performance; exports for Linux,
   Windows and web into `/mnt/session/outputs/`.
