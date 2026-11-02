# Decisions

What was decided where the bibles left something open or where a rule played better another way.
Each entry: what, why, which bible section it touches.

## Project and tooling

- **JSON for content, not .tres.** Techs, enemies, characters, flags, items, encounters and dialogue live in `data/**/*.json`, loaded by the `Data` autoload into typed `TechDef`/`EnemyDef` objects and validated on load (unknown tags, duplicate ids, dangling references). Reason: generated and edited by Python tools and subagents without resource UIDs; diffable; lintable outside Godot (`tools/build/lint_data.py`). Touches Combat Laws §18.2 (which named `.tres`; the fields are the same).
- **Tests load the suite at runtime.** `tests/run_tests.gd` is a bootstrap that loads `tests/suite_core.gd`, because a `--script` entry point compiles before autoload singletons exist. Touches Reference §10.1.
- **Autoload names:** `Data`, `Flags` (PossibilityEngine), `Game`, `Saves`, `Universe` (UniverseSwitcher), `Audio` (AudioDirector), `Router`, `Story`. Reference §10.1 named `TimeDebt` as an autoload; Crono's integrity and Sera's debt live on `Game` and are mirrored into the battle components.
- **Windows build machine (2026-10-29).** The build lead now runs on Nich's Windows PC. `tools/check.sh` runs there under Git Bash with `.tools/bin/godot` and `.tools/bin/python3` shims on PATH (the WinGet Godot 4.7.2 console build; Windows' own `python3` alias is a Store stub), and the visual smoke runs the window directly when `xvfb-run` is absent. `--chapter=<n>` at boot now goes through `Game.set_chapter()` so the chapter-gated kit entries unlock for probes; the battle probe prints BROKEN plates, add counts and a director's `rebuilds`. Touches CLAUDE.md "Environment notes".

## Combat

- **The Lv3 flat shave bonus lands on the first matching strike of an action**, not after the last hit. The total shave per action is identical to §5.3; the only difference is that a Break can arrive one hit earlier, which makes the +1 feel immediate and keeps per-strike resolution simple. The preview uses the same code path. Touches Combat Laws §5.3, §6.4.
- **Keyed plates spill only when the hit also carries the next key.** A multi-weight keyed plate that falls mid-strike passes its leftover shave to the next plate only if the hit's tags include that plate's key; otherwise the excess is lost. Touches §5.6.
- **Ens Parry is "armed".** Pressing parry while Guarding arms a window of `parry_frames / 60` seconds of battle time; a hit that lands while armed is a perfect parry. Pressing outside the window against U1 ink enemies throws the ink blot. This keeps resolution synchronous and headless-testable. Touches §4.2.
- **Voluntary phase-out** is recorded when any party gauge has been parked in the Ready Pool for ≥ 3 s of battle time when the 40% line is crossed (§10.2). The coordinator tracks hold time per parked ally.
- **Party synergy without Sera in the story is 1.00**; with Sera active or hovering 1.10; phased 0.85 (§6.2).
- **Enemy evasion rolls** apply only to non-telegraphed hits: LUK × 0.05% plus Trauma Silence (+10%, +20% under 50% HP) and status evasion.
- **Borrowed Future's Token Duplicate** re-runs the ally's last recorded action immediately with the same Boost level and a fixed variance of 1.0, so the copy matches the original; if the ally has no recorded action this battle, it is placed at the gate instead.
- **Prologue integrity values:** Teach Her To Land 60, Hold The Copy Together 40, The Bowl Still Whole 50 (Combat Laws Appendix A.35).
- **Krona's Oil-Drinker auto-sip** fires once per enemy action against her when she is below 25% HP; the command form heals the party 10% each.

- **The 999 Shard Doll's split dolls hold their Break for the director (Combat Laws §14.3).** When a split doll Breaks, the director extends its lock indefinitely, so the only thing that ever rebuilds it is the lesson's own window (3 s, then 12 s with 3 plates after four rebuilds, then never after eight). Before, the shield's own 3 s lock plus 18 %/s rebuild (~8.6 s) raced that window: once the window grew past it the dolls rebuilt uncounted, the rebuild count froze at four and the "stay broken" escape could never arrive, so an autobattle party sat in phase 3 forever (`ch1_probe.gd` stalled 850 s). A held Break means a broken doll cannot act, which is what the lesson wants. The dolls are also **undamageable** for the whole split (the coordinator's `undamageable` list, as a sealed boss is): at their ~100 HP a basic attack or two killed them with their plates still up, and a dead doll is neither broken nor rebuilt, so the split had nothing left to Break. The director kills them itself when phase 4 begins.

## Rendering

- **One compute pass** implements the paper → grade → edge → VHS stages of the canvas stack (Reference §1.7 describes a four-layer chain). The stages run in order inside one shader on a scratch copy of the colour buffer, blended by the UniverseSwitcher weights. Equivalent output, fewer dispatches, one place to tune.
- **Grades are procedural, not LUT textures:** per-universe saturation, paper tint, ink quantisation (U1's four inks), posterisation (U6's four steps) and a gold lift (U7/U8). A real 32³ LUT can be dropped in later without changing the stack. Touches Reference §2.2.

## Story

- **Crono's first lie** in the kitchen is a three-way choice: "Burn. Old burn." (the bible's line), covering the wrist, or holding it out. The first two lean Dark (+5), the third Light (+5). The bible gives only the lie; offering the honest gesture early sets up the Chapter 1 hearth choice. Touches Story Bible Prologue beat 3.

## Atrium Cradle retune (Combat Laws §14.1, Story Bible Prologue)
The bible lists the Cradle at Lv 3 with 2,400 HP. On the §15 curves a Lv 1–2 party deals ~12 per hit
through intact plates, so that pool is ~140 hits, and a Lv 3 enemy ATK (30) three-shots Lv 1 Crono
(120 HP). Headless playthroughs lost every attempt. The Prologue boss is a teaching fight that a careful
first-time player should win at 60% integrity in three to four minutes, so it now ships at Lv 2 with
1,200 HP, softened action powers (ring swipe 0.9, Sorrowful Blue 0.5, clamp 1.0, seal pulse 0.7,
crack-slide 1.25, mask scream 0.8) and at most two Shardlings standing at once. Phase windows,
plates, mechanics and drops are unchanged.

## The Dollhouse Seal is paid from the deck
"It can be damaged only by spending Time Debt — 5% of Crono's max HP" is implemented as a real
command: while the Cradle is sealed, Crono's deck offers PAY TIME DEBT (5% integrity, a free action)
and the Seal lifts when he pays. The phase script explains it instead of paying silently.

## The Bowl Still Whole has two routes
The breakfast fall choice offers "[Astral Smear Dash] Catch the bowl" directly (the clearest moment
for a first-time player), and the Cradle's third phase keeps the bible's route: a perfect parry on the
Crack-Slide opens a 1.5 s Prismatic window in which Astral Smear Dash grants the flag if it is not set.

## All current art is placeholder (direction from Nich, 2026-10-29)
Every sprite, texture and room in the game today is a stand-in: `tools/art/spritegen.py` paper-doll
characters, `tools/art/make_textures.py` procedural tiles, rooms built from textured primitives in
`SceneKit`, and placeholder blobs for enemies. The visual target is Chrono Trigger's hand-pixelled
characters (Toriyama proportions, expressive faces, strong silhouettes) in Octopath Traveler-grade
HD-2D dioramas (painterly pixel textures on real modelled geometry, detailed props, volumetric light,
depth of field), pushed further. Nothing may ship reading as blocky, boxy or voxel. From the next run an
art pipeline with real tools (PixelLab for 8-direction characters, animations, tilesets, objects, VFX and
normal maps; an image model for portraits, textures, concept frames and painted backdrops) is expected via
`/mnt/session/uploads/secrets.env`. Until it lands, effort goes into systems, chapters, scripts, dialogue,
bosses, menus, saves and music, and the generators are not polished further. What the engine keeps, so
generated art drops straight in: the fixed sheet contracts (characters: 4 rows S/W/E/N × the 70-column
table in `SpriteLibrary.DEFAULT_TABLE`, 128 px cells, `<id>_field.png` + `<id>_frames.json`, optional
`_field_n.png` normal and `_field_m.png` mask sheets; enemies: `<key>_sheet.png` + `<key>_frames.json`
under `assets/enemies/u<n>/<key>/`), the naming in `assets/`, the import settings written by the tools,
and the per-canvas post-processing (ink line, palette snap, desaturation) applied as a final pass so a
PixelLab sheet can be run through the same `finish_frame` step as a generated one.

## Character art route: PixelLab pro from the catalog paintings, chibi proportions (2026-10-29, run 2)
The PixelLab MCP tools are available in-session (no key file needed). Two routes were tried on Crono from
`design/images/catalog/playable_crono.jpg`: (A) `create_character(mode="pro", concept_image_url=…, size=128)`,
which designs eight directions from the painting and returned a ~3.5-head Chrono Trigger / Octopath chibi,
95 px tall; and (B) `create_image_pro` with the painting as a labelled reference (four 120 px candidates
at ~5.5 heads) rotated by `create_character(mode="v3", reference_image_url=…)`. Both rotate cleanly and
keep the gauntlet on the right arm. **(A) is the house style**: it matches plate-06 and Chrono Trigger's
own sprites, the face reads at the game camera (FOV 32°, 15° high), and `style_character_id` lets every
later character match it. Every playable, NPC and humanoid enemy goes through (A) from its catalog image
(or from text with Crono as the style anchor), then template animations (`animate_character`, 1–3
generations per direction at 128 px) for walk/run/idle/hurt/KO/revive/cast, and v3 custom clips for the
weapon-specific attack, charge and victory. Route (B)'s set (`d1df31ab…`) is kept on the PixelLab
account as an unused alternative.

**Scale.** Pro mode's canvas tops out at 128 px, so humans come out ~90–100 px tall rather than the
bible's 114 px (§1.2). Rather than rescale pixel art, `<id>_frames.json` now carries `height_px` and
`height_m`, and `ActorSprite.set_height` sizes the quad so the character stands at the bible's metres
(Crono 1.78 m). Character pixels are therefore ~1.2× the environment's 64 px/m texel, as in Octopath.
Touches Reference Bible §1.2 (pixel density) and §1.4 CHR-F (the sheet now has eight direction rows:
s, w, e, n, sw, se, nw, ne; the first four keep the old order so four-row sheets still load).

## Art comes from Nich; a character is a set of sprites (2026-10-29, run 2)
Nich now makes every asset with his PixelLab bot from `docs/ASSET_REQUESTS.md`; agents import with
`tools/art/import_pixellab.py` and build everything else. A character is a set of sprites by tier — map (64),
field (128 chibi, also used in battle), action (256, realistic 5.5-head, for Dual/Triple Tech cut-ins and
cinematic beats), portrait (512) — plus variants for another canvas or a story state
(`<id>[_<variant>]_<tier>.png`). `SpriteLibrary.apply` takes a tier and variant and falls back to field/base;
`ActorSprite.set_tier` swaps a live sprite. The earlier "house style = one chibi sheet" decision stands for the
field tier; the realistic rotation set (`d1df31ab…`) is the action tier's base rather than an unused
alternative. Touches Reference Bible §1.4 (CHR-F/CHR-B become tiers of one set; battle clips live in the field
sheet) and §4 (the action tier is the realistic reading of the catalog paintings).

## Marle's field sprite arrived at realistic proportions
`npc_marle` (`05c8ee87…`) from the bot is a 5.5-head, 124 px figure beside a 3.5-head cast. It is imported as
`marle_field` so the game has her, and the decision (keep, or regenerate as chibi and move this one to her
action tier) is left to Nich in ASSET_REQUESTS #3 and QUESTIONS_FOR_NICH.

## The text layer is data, loaded and validated like everything else (2026-11-02)
ChatGPT's text delivery of 2026-10-29 (the five JSONs of `docs/JOB_CHATGPT.md`, Linear TRI-80; package SHA-256
`b8c3cc27cfd8301f11e0ff8eafc0e61e23d1aec59575738e99e5d65b403f50dc`) was verified against the repository
(113 bestiary keys = 82 enemies + 31 bosses, 123 techs, 15 items, 10 locations x 12 lines, 84 flags / 148
states, plain ASCII) and committed as `data/text/*.json`. `Data` loads it, treats a key that names nothing
as an error and a game id without prose as a warning (`Data.text_gaps`), and offers `bestiary()`,
`tech_text()`, `item_text()`, `codex_page()` and `ambient_lines()`; `lint_data.py` repeats the checks. The
first consumer is `Location.add_npc`: townsfolk with no script of their own say an ambient line of their
location. The three `found` fields the writers could not source (`mid_tonic`, `revive`, `cobalt_wash`) keep
their honest five-word placeholder "Acquisition source not yet recorded." until Nich names a vendor, chest
or drop (Linear TRI-79; a unit test pins exactly those three so the answer cannot be forgotten). The brief's
enemy glob missed `data/enemies/u9/postgame_enemies.json`; the writers included its seven keys anyway and
the brief now says every file under `data/enemies/`. Touches Story Bible section 10 (voice) and section 8.1
(the Possibility Codex reads `codex.json`).

## Props are billboards with a height in metres (2026-11-02)
Nich's asset team delivered the first 47 PixelLab *objects* (Linear TRI-31..TRI-78: Batch 4d's U1 landmarks and
Batch 6's Prologue and Atrium dressing). Rather than a glTF route, a prop is a lit billboard: the same
`ActorSprite`, `sprite_canvas` shader, `_n` normal sheet and per-canvas finish as the cast, so a hearth is lit,
shadowed and graded exactly like the people standing at it, and the second prop costs nothing
(`Location.add_prop(key, pos)`). Each prop's size is a design value, not a pixel count: `data/props/props.json`
declares `height_m` per key (a stool 0.6, the oak table 1.2 with its foreshortened top, the hearth 1.9 because
the drawing carries its chimney breast, the portcullis arch 4.0, the torii 4.0; every call written in `notes`),
`solid` (a collision box sized from the drawn width), `y_offset`, `anims` (clip fps), `emission`, `pending`, and
`Data` treats an unknown field or a key that does not name its universe as an error. The importer reads the
height from there (`tools/art/pipeline/pixellab_objects.py`, reached through `import_pixellab.py` for any
`prp_` key), accepts PixelLab's two download shapes (a bare PNG for a still object, a zip with rotations and
clips), packs one row per rotation with the cell as the smallest multiple of 32 that holds the frames (64 to
256), makes a single ambient clip the looping `idle` with the drawn rotation kept as `still`, and keeps U1's
saturation (the four inks arrive on-palette; the character route's 0.30 would grey the cinnabar). A pending or
unknown key stands in as a labelled box of the declared height so a scene never breaks. `data/art/incoming.json`
now carries the delivery record in the `docs/BOT_REVIEW.md` shape and `tools/art/import_incoming.py` is the
hourly import. Judgement calls on the delivery: `prp_u0_clock_pillar_face` is a whole clocktower spire (kept as a
Truce landmark, Robo's pillar keeps its animated hands), `prp_u0_pool_rim` is one front arc (the Atrium pool
stays primitive), `prp_u1_dojo_set_rusted_katana` stands upright (v2 wanted), `prp_u0_doan_tree_stages` is the
seed only; the kitchen hearth moved from the west wall to the west end of the back wall because a front-view
hearth read as a free-standing stove edge-on, and the counter shortened to make room; the Atrium's eight gate
arches are walk-through billboards with their universe panel billboarded behind them. Two Atrium layout calls
came out of the captures: the camera-facing third of the ring now keeps only its ledge for the columns and
balconies as well as the wall (they stood between the follow camera and the hearth, the pool and the gates),
and the hearth corner (hearth, benches, `hearth*` markers, the HearthSeat prompt) moved a step in from the
gate ring to x -7.9 / -5.4 so gate U2's arch no longer hides it; the mice zone at (-9, -3) and the pool rim
were checked clear. The Atrium pool and Robo's pillar face keep their primitives (see QUESTIONS_FOR_NICH). Touches Reference Bible
§1.2 (prop pixels sit at the cast's density, ~1.2× the environment texel, and up to 2× for the 128 px arches),
§1.3 (`assets/props/<u>/<id>/` holds a sheet, a frames json and a normal rather than `<id>.png` alone), §1.4
(PRP-S/PRP-M are one billboard contract; the glTF option is unused for now), §5.7 and §11.7 (the delivered set: the manifest's own rows plus Batch 6's dressing keys that §11.7 never
listed, `prp_u0_counter_bowls` … `prp_u0_robo_rest_alcove`; `data/props/props.json` is now the complete list,
the bible table is not edited).

## PixelLab generation by the build lead: Prologue textures, the UI panels, and Nich's Phase-1 style kit (2026-11-02)
Nich opened PixelLab to the build lead ("it's so you can make stuff for the game"). First batch, 9,590
generations on the account, about 50 spent: (1) the twelve U0 textures of ASSET_REQUESTS Batch 7
(`create_image_pixen` at 512 px, one generation each; six regenerated with stricter prompts after the
first pass drew whole castles instead of surfaces), wrap-blended so they tile, tiled 2x2 to the 1024 px =
16 m contract of `SceneKit.named`, with luminance normal maps, in `assets/textures/generated/`; (2) the
four UI panels the asset team had already generated (battle command menu, party status card, menu kit,
dialogue box) imported as delivered into `assets/ui/generated/`, not yet wired: the dialogue box and HUD
stay code-drawn until Nich picks between that navy-and-gold set and (3) the palette-locked candidate from
the style kit; (3) the Phase-1 style-bible kit the Nov 1 breakdown asks to freeze before volume work: a
64x64 hero anchor (`create_image_pro`, Resurrect 64 palette, 16 candidates, the design-lock identity
block without a character name), three 32 px Wang test tilesets, one 9-slice window frame and one impact
burst (VFX Creator game pack), all under `source_art/style_kit/` with the review sheet
`docs/screenshots/20_style_bible_kit_review.jpg`. Nothing from the kit ships until Nich picks; the
questions are in QUESTIONS_FOR_NICH. Every generated file is logged in `source_art/MANIFEST.csv` (tool,
model, seed, prompt, palette, post-process), the AI-disclosure log the breakdown section 14 asks for; it
lives in `source_art/` because Godot imports any CSV under `assets/` as a translation table. Touches
Reference Bible 1.11 (Route G) and 5.6/5.9, the breakdown sections 9, 10, 13 and 14.
