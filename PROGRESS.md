# Progress

The hand-off between runs. Keep it honest: what exists, what is verified, what is next, what is broken.
Two agents work this repository in turns (the build agent and the studio assistant); Nich makes the art.

## Run 3 (2026-10-29 from 10:20 EDT): the build lead is Claude Code (Fable) on Nich's Windows PC

- **Machine:** repo at `C:\Users\names\dev\TRIGGER-Time-Debt`; Godot 4.7.2 and python shims in `.tools/bin`
  (CLAUDE.md "Environment notes"); `bash tools/check.sh` passes on Windows (parse, 440 unit checks, data lint,
  smoke boot without xvfb).
- **Chapter 1 Shard Doll fixed, verified:** `ch1_probe.gd -- --autobattle` prints `PROBE_END ok=true` (split
  lesson: rebuilds 0→8, then the dolls stay broken, phase 4, the rest of the chapter through the Fair call).
  Three causes, all in `scripts/battle/bosses/shard_doll_999.gd` (see DECISIONS "The 999 Shard Doll's split
  dolls"): a broken doll's Break is now held until the director rebuilds it; the dolls are undamageable
  during the split (they died at ~100 HP with plates up); the dummy's integrity bleed is capped at five
  floors (10 integrity; a slow party lost all 100).
- **Probes:** `--chapter=<n>` at boot now calls `Game.set_chapter()` (kits unlock); `battle_probe.gd` and
  `ch1_probe.gd` print each add's plates, BROKEN, and a director's `rebuilds`.
- **Autobattle hook:** `BattleScene._auto_pick_tech()` chooses the tech the AI casts (currently random; a
  multi-target preference for fights like the split is the next tuning step).
- **Team hub:** Slack `#all-trigger` (workspace "Trigger"): Nich's kickoff, the build-lead protocol
  (`[BUILD]` threads, hourly import replies). Read it before every push.
- **In progress:** `docs/ASSET_REQUESTS.md` is being expanded from Batches 1–9 to the complete game (every
  Reference Bible §11 row, tiers map/field/action/portrait, variants, cut-ins) as Batches 10+.

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
  (Chapter 1, passes since run 3), `battle_probe.gd -- --scene=test_arena --autobattle --boss=<id>
  --party=crono,sera,marle --chapter=1 --level=4` (pass `--chapter` so the kits are unlocked).
- Captures: `bash tools/capture/render.sh <scene_id> <prefix> [frames] [-- args]` → `/tmp/captures/`.

### What exists and is verified (unchanged from run 1 unless noted)
- Project, eight autoloads, Combat Laws core (435 checks), boss framework with directors, Atrium Cradle,
  data for 123 techs / 82 enemies / 31 bosses / 71 encounters / 80 flags, field layer, Prologue scenes
  (kitchen, courtyard, Atrium hub), Chapter 1 hub beats, audio toolchain and vertical-slice music.
- `PortraitCache` looks in `assets/portraits/<id>/<id>_<expr>.png` first; `SceneKit.named("<material>")` looks in
  `assets/textures/generated/` first (import targets for Nich's portraits and textures).

## Lead hand-off (2026-10-29 09:50 EDT)

The Console build agent ran out of credit at 09:46 after pushing everything. **The build lead is now the Claude
Code session Nich runs on his machine** (same working agreement, `CLAUDE.md`). The studio assistant keeps its
lanes: bot audits (`docs/BOT_REVIEW.md`), `docs/ASSET_REQUESTS.md`, and Chapter 3+ dialogue. Nich's bot
delivers art per `docs/BOT_REVIEW.md`; ChatGPT writes the text layer per `docs/JOB_CHATGPT.md` into
`data/text/`.

## Next steps (start here)
1. **Hourly: check the PixelLab library / `data/art/incoming.json` and import** (see the plan). Import
   `villager_m` when its jobs finish. Read Slack `#all-trigger` first.
2. **Finish the complete `docs/ASSET_REQUESTS.md`** (Batches 10+, in progress in run 3) and post it in Slack.
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
- **The autobattle AI single-targets**, so the Shard Doll's split lesson takes ~5 min headless (eight
  rebuilds before the dolls stay broken) and Crono is floored often; `BattleScene._auto_pick_tech()` is the
  place to prefer LINE/CONE/CIRCLE techs when several enemies share a weakness.
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
