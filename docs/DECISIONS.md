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

## Direction: the Nov 1 recipe is the style, and everything is remade at its scale (2026-11-02, Nich)
Nich confirmed in session that the assets "need to be remade the right size and this new style we are
reaching for": his Nov 1 "Chrono-Style Recreation Breakdown". Numbers adopted from it: sprites on a 64x64
canvas, three heads tall (the hero about 56 px for 1.78 m, so about 32 px per metre), a twelve-colour
budget per character from one locked palette (Resurrect 64 is the working palette until Nich confirms a
different one), coloured selective outlines and no pure black, held-frame animation timed like the
original (walk 6 steps, run 2-4, attack 7 poses); world textures and tiles at the same 32 px per metre
(`SceneKit.TILE_M` goes from 16 m to 32 m per 1024 px texture, so a 256 px tile is 8 m), drawn flat
with two-tone light and shadow, high-key lighting. Superseded: the Reference Bible's 64 px/m texel rule
(1.2) and the 3.5-head 128 px chibi field tier (Crono 95 px), the asset team's 256 px "field v3" sets
on the PixelLab account (not imported; the character import started today was stopped before it wrote
anything), and the first twelve painterly 512 px textures (replaced by 256 px SNES-density ones the
same day). The 128 px cast and the chibi NPC placeholders stay in the game until their 64 px
replacements exist, one character at a time, starting with the hero anchor (style-kit candidate 0
rotated to eight directions as "TRIGGER Anchor Crono 64 v1"). Every open ASSET_REQUESTS entry is to be
re-specified at this scale before it is sent. Touches Reference Bible 1.2, 1.4, 2.3 and 3; ART_PIPELINE
1 and 1b; the breakdown sections 3, 5, 6 and 12.

## Audit fixes of 2026-11-02: what the bibles now say where they disagreed
Settled while applying the verified docs audit (the full list is `docs/reports/WORKSPACE_AUDIT_2026-11-02.md`):
- **The R-66Y fight's fourth phase is keyed to the Paradox road** (`Amber_Rift_U2=set` in
  `data/bosses/r66y.json`), as the Story Bible says in four places; Combat Laws 14.5 said "over 45,000 HP".
  Touches Combat Laws 14.5, Story Bible 3.4 and 9.3.
- **The Salvage gives Empress Cannon (Krona + Cassia-09), not Omega Annihilation**, in the boss data's branch
  text and Combat Laws 14.5, as AUDIT.md row 25 already settled; Omega Annihilation stays the Sera + Static Dual.
- **The Cobalt Nodachi is forged in Chapter 3.** Reference Appendix B #13 settled it (vault pigment in U1,
  Geno-Foundry forge in U2), so Story 2.7 is "The cobalt pigment" (Taken = pigment + Crimson Night), the kit and
  tech unlock on the `Masamune_Reforged` flag, and the Chapter 2 generator no longer hands the weapon out
  (`game_state._learn_defaults` honours only chapter and on_join unlocks, so that dialogue `learn` was the real
  grant). The Chapter 3 forge script must `learn` it. Touches Story 2.7 and 9.3, Combat 11.4/11.14/14.3.
- **Overclocked Short-Circuit is Crono + Krona** (Combat Laws, `data/techs/duals.json`, the Weaver's data) and
  now has learners: both kits unlock it in Chapter 3. The Story Bible's two lines that called it Cassia-09's
  recruitment Dual are reworded.
- **Flag ids are spelled as the data spells them:** `R66Y_Rewound` / `R66Y_Salvaged` (the boss name keeps its
  hyphen, the flag does not). Sera's weapon is "Twin Pendulum Blades" in every document; Cassia-09's gramophone
  horn grows from her shoulder (plate-04 and the painting).
- **The embedded prototype is gone.** `prototype/` was a byte-identical snapshot of the private repository
  iteatsthesalt/Trigger at commit aea60a2 that Godot skipped only because of its nested project.godot; its
  systems were re-implemented in `scripts/combat`. Kept: its combat audit as `docs/reports/prototype_combat_audit.md`
  and `tools/blender/build_truce_pier.py` (credited). Reference 10.3 and Combat Laws 18.6 are history notes
  pointing at the Trigger repository. Tag aea60a2 there (QUESTIONS_FOR_NICH).
- **Hygiene:** `design/` is `.gdignore`d (72 import sidecars dropped), raw PixelLab zips are no longer tracked
  (`source_art/**/*.zip` ignored; the unpacked frames stay), Python tools are executable, `.gitignore` is
  deduplicated. `lint_data.py` now warns about music and ambience ids with no file (21 today), ambient-chatter
  location keys that match no Router id (5 today), and Duals with no learner (3 today); the importer refuses
  TEST/REJECTED items unless forced.

## Combat and engine fixes from the audit (2026-11-02)
- **The breaking strike lands at pre-Break defence; the reward starts on the next strike.** Combat Laws 6.4
  applies damage before the shave ("BREAK now (later hits see a Broken target)"), 5.4 says the remaining hits
  land on a Broken target, and worked example 2 (6.5) is ~676 at full DEF with no crit; the code resolved the
  breaking strike with DEF halved and a crit. Fixed in `_resolve_action` (`was_broken` decides the multiplier),
  pinned by `test_breaking_strike_uses_pre_break_defence`. The Cradle and Shard Doll were tuned with the old
  ~1.8x breaking hit, so their Break hits are a little softer now; both probes still clear them.
- **Sync Hold cannot strand a party.** `SyncHoldRules` (scripts/combat/sync_hold_rules.gd): the deck only
  offers Sync Hold when another living, unparked ally can still reach the gate (hover Sera counts, KO'd and bench
  do not), the coordinator re-prompts a parked ally nobody can relieve (no second +1 BP, hold timing unchanged),
  and `confirm` during a tick wakes the first parked ally. The prototype's C1 fix, finally ported. Touches 3.4.
- **The plate preview and the resolution share one shave helper** (`ShaveBonus`: flat Lv3 bonus, armed Ens
  ring, status bonus, watercolour puddle), so what the HUD promises is what the hit shaves. Touches 4.6 and 5.3.
- **The bench and hover Sera are built from the roster** (`BattleRoster`): everyone recruited and not active sits
  on the bench; Sera hovers when `Game.sera_in_story` is `hover`/`hover_support`, sits while `with`, is absent
  while `taken`/`absent`; Swap and Swap-KO'd (3 m) are deck entries; a Swap lasts the battle, the field party is
  the one you walked in with; reserves' level, xp and hp ratio are written back. Hover Sera gives the 1.10
  synergy, else 1.00 (6.2). Note: after `leave_for_fair()` Sera is still `with`, so a Leene Square fight would
  offer her on the bench until the Fair script sets `sera_state`.
- **Victory and defeat stings play** through `Audio.play_sting` (`audio/music/mus_stings_*.ogg`); they were
  requested through a sfx path that never existed.
- **Prop collision can be posts or several boxes.** `footprint` in `data/props/props.json` is `[w, d]` (one
  box), `"posts"` (two uprights at the drawn ends, the opening clear) or a list of `[w, d, x_offset]`; the gate
  arches and the torii are posts, the portcullis is two posts plus the grille. Arches are solid again.
- **The camera remembers each scene's explore pitch** (`HD2DCameraRig._explore_pitch`); `exit_battle` had a
  literal 30 that snapped the kitchen (32) and Atrium (34) after their first fight. The rig and `Location` default
  to 30; the bibles' 15 is superseded (Reference 2.3, ART_PIPELINE) and recorded here rather than rewritten.
- **Engine settings from the breakdown's section 12:** physics interpolation (the rig follows the interpolated
  transform and teleports call `reset_physics_interpolation`), debanding, bicubic glow upscale, 4096 directional
  shadow map, 2D transform snap; world textures (placeholders and generated) import with mipmaps and without
  Detect-3D compression, and `import_texture.py` writes that sidecar. Not done: rounding each sprite's drawn
  position to its pixel size (the right place is a render-side snap in `ActorSprite`).

## Code-audit fixes, second pass (2026-11-02)

The verified code audit (docs/reports/WORKSPACE_AUDIT_2026-11-02.md, section A) was fixed in fifteen clusters,
each by one agent and reviewed read-only by another, with one re-fix round where the review asked for it (commits
c52baeb to dc83e3f). Each call names what was built, why, and the bible section it reads; where a re-fix restated
a call, the later text is kept.

### Story runner

- **The gate toll: first traversal per gate, hub free, charged by the Router.** A gate jump is charged the first
  time the party arrives in a universe other than U0 along the thread: Crono −0.4 integrity
  (TimeDebtComponent.on_gate_jump, so Reinforced halves it), Sera +5 Translucency Debt
  (SolidityComponent.on_gate_jump), both mirrored into Game by delta; actors without live components are charged
  on Game directly, and Sera is charged whether she is with the party, hovering or taken. Returning to the Atrium
  (U0) and going back through an opened gate are free; a direct U_n → U_m jump opens gate m and pays once. Opened
  gates are Flags counters `gate_opened_u<n>`. Router.go charges it whenever the loaded location's universe
  differs from the one left; the Story `universe` command charges it only with `"jump": true`, so canvas swaps
  (ch1_nightmare's U7, the Cradle's flashes) cost nothing. Implemented in scripts/world/gate_jump.gd. Why: Combat
  Laws §10.1/§10.2 and Story Bible §9.4/§9.5 state the costs and the 'hub and back through an opened gate is free'
  exception but never say where a gate is traversed in code; the Router is the one place every location change
  passes, and the story `universe` command is also used for dreams, so it needs an opt-in. Sera's debt is 'the
  story's clock … each universe is one of her seven days', which is why it accrues even while she is captive.
  (COMBAT_LAWS_BIBLE §10.1, §10.2; STORY_BIBLE §9.4, §9.5)
- **Story commands compose: side effects, then actions, then one verb.** Every dialogue command runs
  `_apply_side_effects` (set_flag, give_item, counter, var, …), then the scene actions (move, face, anim,
  show/hide, teleport, camera, universe, music, sfx, fade, emote, shake, run, call, battle, go), then its verb:
  say / caption / choice (in that precedence), then a numeric `wait`, then goto / if / end. A bool `wait` belongs
  to `move`; a numeric `fade` belongs to `stop_music`; `label` is a pure marker. A choice's picked option still
  applies its own side effects and goto; `battle` (on_win/on_lose) and `go` jump before any verb. Why:
  say/caption/choice/goto/if/end/wait returned before the side-effect chain, so any sibling key was dropped
  silently (Chapter 2 already had two {fade, wait} beats). One shared path is simpler than a one-verb lint rule
  and matches how the generator already writes commands. README's command list states this order. (README
  'Dialogue and cutscenes' (engineering, no bible rule))
- **"Name:State" is a first-class flag form everywhere the runner reads a flag.** `set_flag`, the `flag` condition
  and the `not_flag` condition accept "Name:State" (split once on the first colon) as well as a separate `state`
  key; an explicit `state` wins over the colon part. `{"not_flag": "Name:State"}` means 'not in that state'. Why:
  README documents the colon form, boot.gd's --flag= already parses it and Chapter 2 writes it twelve times; the
  runner was the only reader that did not split it. (STORY_BIBLE §9.2, §9.3 (the flag list); README 'A flag')
- **Router.go reports its verdict; a refused story `go` ends the script and says so.** Router.go returns true when
  the location is up and false when a transition is already running (warning), the id is unknown or unbuilt
  (error) or the scene fails to load. Story's `go` records `last_refused_go`, warns with the script id and
  destination, and still ends the script when `end_after` is true (default), so the location stays interactive
  rather than running the commands that followed the departure. Title's Continue checks has_location before go so
  a save in an unbuilt location leaves the title usable. The registry keeps unbuilt entries (leene_square,
  bamboo_grove, kuro_truce) as scaffolding; has_location checks the file. Why: go() was void and silent, so
  callers mutated state and the title's _busy flag before a transition that never happened; ending the script on
  refusal is the safer runtime behaviour because the lines after a `go` usually belong to other labels. (none
  (engineering))
- **Story vars travel with the save and reset per run; history is capped.** Story.to_save()/from_save() store the
  `var` dictionary under a new "story" key in the save (old saves load with empty vars); Game.new_game() emits
  `new_game_started` and Story.reset() clears vars and history; the dialogue history keeps the last 200 lines.
  Why: README advertises `var` as a command and condition; without persistence a Continue forgot every branch and
  without a reset a New Game inherited them; the history grew for the whole session. (README 'Dialogue and
  cutscenes' (engineering))
- **Runner accepts the Chapter 2 generator's forms: face `to`, show `at`, music "stop", camera focus by marker.**
  `face` with `to` turns the actor toward another actor or a marker (face_toward); `show` with `at` teleports to
  that marker first; `music: "stop"` stops the music (its `fade` key is the seconds) instead of playing a track
  named stop; a camera `focus` that names no actor resolves to the location's marker node of that name (read from
  the scene's `markers` dictionary). Why: Five generator forms were silent no-ops (STORY-8); accepting them in the
  runner is generic and keeps the generator and chapter JSON untouched. README's command list should mention `to`,
  `at`, `music: stop` and marker focus. (README 'Dialogue and cutscenes')

### After a battle

- **Post-battle restore (BattleAftermath).** Every battle ends in one outcome: victory, defeat or withdraw. The
  fallen stand up at 1 HP after a win or a withdraw, at 30% (living raised to 30%) after a field defeat, and at
  50% after a scripted story loss. Bodies are fully restored (fade killed, transparency 0, visible, unfrozen,
  untinted, hull down). The write-back runs after the restore, so the roster matches the bodies. Reserves still
  down record the same floor. Why: The owner's direction 'after battle: fallen members revive at 1 HP' (cited by
  GAP1-1). Before this, a member KO'd in a won fight stayed invisible at 0 HP and started the next fight KO'd.
  Combat Laws 16.2 only covers in-battle revives. (COMBAT_LAWS 16.1, 16.2)
- **Withdraw.** Withdraw is a command on the ally's window. The ally first falls back toward the battle plane's
  nearest edge with its move for the window: at most its move range (SLOW halves it), aimed 1 m inside the 28 m
  plane edge. In the field the plane is laid over the room (§2.1), so the fall-back lands only on ground the party
  can stand on (WalkableGround). That means inside the Location's map_bounds less 0.6 m, with world floor
  (collision layer 1) under the body's whole 0.4 m footprint within a 0.5 m step up or 0.6 m drop, and no world
  solid overlapping the body. The fall-back is walked in 0.5 m samples. A sample a solid takes (crate, ledge, gate
  post) is passed over, as the battle's Move passes over it, and the walk ends where the floor or the bounds end.
  The ally then attempts the withdraw if it stands within 2 m of the plane's edge, or within 2 m of the room's
  walkable edge along its fall-back line, so a withdraw can succeed in rooms smaller than the plane. The attempt
  succeeds when no enemy gauge is above 80 and otherwise costs the turn. A fall-back that ends short of both edges
  costs the turn. Success ends the battle as its own outcome (reason 'withdraw'): no integrity, no defeat sting,
  no Sera jump-back. The zone's enemies stay, at full strength, un-Broken and wandering. The leader regroups where
  the ally broke away, or where it stood before the battle when the ground there cannot hold it. Followers the
  ground cannot hold step back toward the leader. Withdraw is never offered in boss or story battles. Why: The
  first version aimed at a fixed 13 m plane edge and teleported the ally there. In the shipped Atrium that point
  is 14.2 m from the hall centre, past its 13.5 m floor, so the ally fell mid-battle and the regrouped leader fell
  forever, a soft-lock. The plane conforms to the terrain (§2.1), so the room's walkable edge is the edge that
  matters indoors. (COMBAT_LAWS_BIBLE §4.1, §4.2 (command table), §16.5, §2.1)
- **Enemies after a battle.** On a win or withdraw, dead and spared enemies leave the zone. A field defeat stands
  every foe of the encounter up again (the jump back to the moment before). Survivors are reset to full HP,
  shields, no statuses, un-Broken, on fresh wander routes. A zone re-arms only once the leader has stepped out of
  contact. Bodies no zone owns (story foes, bosses, adds, summons) are freed after the battle. Why: Spared enemies
  stayed in the zone, invisible and spareable again for XP and lean. Broken survivors stayed frozen gold forever.
  Story-battle bodies stacked on every retry. (COMBAT_LAWS 4.2, 16.1, 16.5)
- **Game is the ledger for integrity and Debt.** Location syncs the field Crono's TimeDebtComponent and Sera's
  SolidityComponent from Game whenever Game.integrity_changed or debt_changed fires (each signal syncs only its
  own value), and again at battle start. Why: Story writes (Prologue set_integrity, the Cradle loss's +5 Debt,
  Chapter 2 phase-script integrity) went to Game only and were overwritten by stale component values at the next
  battle's write-back. (COMBAT_LAWS 16.1; STORY_BIBLE Prologue)
- **Guests have roster rows.** Game.set_party gives any kit marked "guest": true that is not recruited a roster
  row at its join level and teaches its unlocked kit. Guests are never recruited and never sit on the bench. Why:
  Marle (Combat Laws 2.2: 'with her own small kit') had no techs in the Cradle, so phase 1's LIGHT plates could
  never be shaved, and her XP was discarded. (COMBAT_LAWS 2.2, 14.2)
- **Engagement by facing.** Pre-emptive when the leader stands more than ~107 degrees off the enemy's facing
  (behind it) or the enemy is frozen, asleep, stunned or time-stopped. Ambush when the leader faces away from the
  enemy. Normal otherwise, back to back included. Contact distance is max(1.1 m, enemy body_radius + 0.6 m). Why:
  The old rule read velocities: a stationary enemy approached from behind was 'normal', and a standing leader
  approached face-on was 'ambushed'. Large enemies had to be entered before contact registered. (COMBAT_LAWS 2.1,
  2.3)
- **Post-battle restore: Game follows the bodies during a battle.** From battle start
  (BattleAftermath.enter_battle) until the write-back (write_back), Game.crono_integrity and Game.sera_debt follow
  Crono's TimeDebtComponent and Sera's SolidityComponent through their change signals. Outside battle, Game stays
  the ledger and the field bodies sync from it, as before. Why: Story's mid-battle writes are relative to Game
  (for example a phase script's integrity -2). With Game stale during the fight, the absolute Game-to-body sync
  discarded in-battle tech costs and repairs. Following during the battle only keeps field writers, such as
  GateJump's delta pattern, from double-counting. (COMBAT_LAWS_BIBLE §10.1, §16.1)
- **Break hull and avoidance after a Break.** The Break hull is monitorable (layer 5) only while the body is
  Broken or a statue. on_recover() and restore_body() give back the NavigationAgent avoidance the Break found,
  where on_recover used to force it on. Why: restore_body left avoidance off and the hull detectable. A fresh
  enemy is created with avoidance off and should get none from a recovery. (COMBAT_LAWS_BIBLE §5.4)

### Battle scene and deck

- **A Swap is the window's action.** Both swaps end the acting ally's turn the way any command does (_finish_turn,
  then _after_party_action): the ordinary Swap from the Bench, and the swap of a KO'd ally from within 3 m
  (SwapRules.KO_REACH_M). Hover Sera holds no party slot and cannot swap. A KO'd reserve cannot be swapped in. The
  first Swap still pays +1 BP and the newcomer arrives with gauge 50. Why: Combat Laws 4.2 lists Swap among the
  window's actions and says nothing about a free KO swap. The free version left the coordinator in COMMAND_WAIT
  with no deck (GAP4-2) and skipped the turn bookkeeping (COMBAT-21). (COMBAT_LAWS_BIBLE §4.1, §4.2 (Swap row),
  §3.6)
- **One move per decision window.** cmd_move refuses a second move in the same window (moved_this_window resets
  when a window opens). Withdraw's fall-back is that window's move. Why: Bible 4.1: 'The ally can move and then
  take one action'. Repeated moves could cross the plane in one window. (COMBAT_LAWS_BIBLE §4.1)
- **Pay Time Debt is counted in integrity points.** The Dollhouse Seal costs SealPayment.INTEGRITY_COST = 5 points
  of Crono's 0-100 integrity. Deck label, floating number and caption all say '5% integrity'. Through
  TimeDebtComponent.max_hp_factor this lowers his HP ceiling by 2.5 points (the HUD shows ceiling 98% after one
  payment). The floating number used to say '-5% ceiling'. The bible's '5% of Crono's max HP' stays superseded by
  the existing DECISIONS entry 'The Dollhouse Seal is paid from the deck', which this one makes precise. Why:
  BATTLE-12: the cost was 5 integrity points, but the number promised a 5-point ceiling loss (2x wrong). One
  constant now builds both strings, so they cannot drift. (COMBAT_LAWS_BIBLE §14.1 (Prologue, line ~1507);
  DECISIONS 'The Dollhouse Seal is paid from the deck')
- **One summon rule, the summoner's own cap.** EnemySpawner is the only code path that brings summoned enemies in.
  The cap is the summoner's own max_adds (boss file or enemy entry, default 3): never more than that many of one
  kind standing beside it. A boss's controller places the boss's own adds, and its director may still take them
  over. Any other enemy's summon is the BattleScene's, under that enemy's own cap, even inside a boss fight. Adds
  ring the summoner at 1.8 + 0.4k m and play the revive animation. Why: BATTLE-16: two implementations disagreed.
  Zone summons had no cap, and a regular enemy beside a boss was capped by the boss's file. CLAUDE.md: generic
  before wide. (COMBAT_LAWS_BIBLE §14 (adds), §11 summon effects; CLAUDE.md 'Systems are generic before they are
  wide')
- **Seals are shown, not just applied.** While a body is undamageable (the Dollhouse Seal, the split dolls), the
  preview promises 0 damage and the aim line says 'SEALED: no HP damage'. A strike's number reads SEALED and the
  plate is prefixed [SEALED]. Plates still shave. Why: BATTLE-9: the HUD promised ~N damage, then printed 0 with
  no persistent cue. Bible 17.5: 'The plate always shows the math'. (COMBAT_LAWS_BIBLE §17.5)
- **Wind-up tint follows the decal.** Enemy plates and Turn-Bar markers use BattleHUD.telegraph_tint: cyan to
  orange by wind-up progress (clamped), brightness 0.85 + 0.15*sin(TIME*6), the same formula as
  aoe_floor_ring.gdshader. Plates are re-projected every frame, including while aiming. Why: BATTLE-19: the plate
  weight ran from 0.25 to 1.25 and extrapolated past orange. Plates also froze in screen space while the camera
  eased during targeting. (COMBAT_LAWS_BIBLE §3.5, §17.1 (Telegraph row))
- **A decision window never stays without its deck.** Every party command goes through
  BattleScene._run/_after_command. A refusal shows the reason and reopens the actor's deck. An accepted command
  closes the deck, unless the command itself opened the next window. A frame-level guard reopens the deck for any
  COMMAND_WAIT window left in Mode.NONE (not in auto, input-blocked, paused or Story-running states). Attack is
  greyed out when no enemy is targetable. Why: BATTLE-1 and GAP4-2 were both soft-locks from this one hole. A
  parked ally reopening the floor inside a command had the same problem: the old _after_command closed the deck it
  had just opened. (COMBAT_LAWS_BIBLE §3.4 (Ready Pool re-prompt), §4.1)
- **The autobattle exercises effect techs.** AutoBattler casts allowlisted party effect techs (EFFECT_USES:
  Tachyon Needle, HOLD, Rewind, Ward, Fall Break) when one has a target (30% per window). It boosts to the bank's
  max_spend one window in four, takes a Sync Hold 10% of the time when SyncHoldRules allows, and prints an
  'AUTOBATTLE victory=... cmd=n' tally at every battle end. Costly or story-bound techs (Time Debt Seal, Borrowed
  Future) are never cast. Spare, Withdraw, Swap, parry and Duals stay covered by unit tests only. Why: GAP3-4: a
  green probe certified only Attack, Guard, Item and pay_debt; TechEffects.apply never ran in automation.
  (CLAUDE.md quality bar (probes); COMBAT_LAWS_BIBLE §18.7)

### Field and combat actors

- **The Broken-kill statue counts battle time and lives in the coordinator.** StatueTimers (RefCounted, owned by
  BattleCoordinator) starts an 8 s statue when an enemy dies while Broken and ticks it with battle time inside
  advance(). It answers whether a dead body still stands as LINE_PIERCE cover, and calls the body's shatter() when
  time runs out. Dead, spared or fled units no longer tick their Break, so a corpse never recovers. Why: The bible
  counts Break timing in battle time, and the statue's terrain role belongs to the coordinator's _blockers(), so
  the statue's clock and its cover must be the same clock. The old CombatActor physics-time countdown never ran
  and could not have agreed with the coordinator. (COMBAT_LAWS_BIBLE §5.4 'Killed while Broken', §5.5, §18.7 check
  9)
- **Scripted walks always resolve.** ScriptedWalk ends a walk on arrival, after 0.75 s with no headway, or after
  distance/speed + 2 s. It always stops where the walker stands (no snap through colliders) and pushes a warning
  naming the walker and the target. A frozen walker makes no headway and therefore resolves. Why: An awaited Story
  move must never soft-lock a cutscene. Snapping to the target could put a body inside a prop collider, so
  stopping short with a warning is the safer failure and shows content authors where a prop is in the way.
  (STORY_BIBLE scripted scenes (story_runner move); no bible rule, engine robustness)
- **One integrator per body per tick.** CombatActor.step() applies gravity and move_and_slide. The field movers
  (PlayerController, PartyFollow, EncounterZone) run at process_physics_priority -1 and call it. A body only falls
  on its own when no mover stepped it this tick or the last. A body on a scripted walk is moved only by that walk.
  Why: Applying gravity twice while airborne doubled fall speed and horizontal step. A shared step keeps one copy
  of the gravity code instead of four. (CLAUDE.md 'generic before wide')
- **Sera's Debt is drawn on her sprite.** At 0 Debt she is pristine. From the first point she shows the hairline
  porcelain state (crack_amount 0.2 + Debt/100, the formula the old Rewind code computed) and her opacity is 1 -
  0.005 x Debt (about 0.73 at the field cap of 55, floor 0.5). This is applied by set_porcelain_visuals, so the
  Rewind, the gate toll and the post-battle refresh all show it. Why: Story Bible: the crack 'spreads, like her
  father's, when she pays', and the Rewind 'costs +5% translucency'. The old code set state 1, which the shader
  ignores, and never touched her opacity. (STORY_BIBLE §4.2 Sera 'Look', Chapter 1 beat 2 (the nightmare /
  Rewind))
- **The battle-time readout is debug-only.** BattleHUD's 't 12.3' label is visible only when Game.debug_mode is
  true. Why: No bible or doc describes it as player HUD; it is a development readout. (COMBAT_LAWS_BIBLE §17 (HUD
  feedback))
- **A focus release during a battle or cutscene still counts.** Releasing focus while the controls are held clears
  focusing at once. The visual reset (focus_changed(false)) is delivered once the controls are back. Why: A
  swallowed release left the leader at 0.4x speed and, after a cutscene, the forced porcelain and truth lens
  stayed on. Delaying only the visual reset avoids cutting a cutscene's own camera. (STORY_BIBLE Ch1 beat 1
  (Porcelain Insight))

### Bosses

- **A boss phase that comes due during a Break waits for the Break.** When a phase ends while the boss is Broken
  (its own 'break' gate, an HP window crossed, a director's advance_phase), the whole phase change waits until the
  boss recovers: banner, script, new shield, tags, seal, adds and director on_phase. The Break keeps its crits and
  halved DEF on the old plates. Why: The bible says the Break plays out first and the new shield appears when the
  boss would have recovered. Running the whole change at one moment keeps scripts ("the plate climbs to 18") and
  directors (reveal_all, untargetable) in step with the plates. (COMBAT_LAWS §14.1 Phase shields)
- **HP windows are walked one at a time; gates hold; seals hold.** A phase is left when the ratio reaches its
  hp_to and the next phase's hp_from (resolved by hp_from_by_branch). It is left one window per transition, so
  every phase is entered. A gated phase (advance_on) is never left by HP until its gate opens, and after that its
  window still applies. A sealed phase holds its window until the seal is paid. Why: Otherwise one big action
  skips a phase's script, seal and adds (BATTLE-8), and zero-width branch phases are unreachable (DATA-4). R-66Y's
  Mercy road gives Heart Expose 'below 40%'. (COMBAT_LAWS §14.1, §14.5)
- **Generic gates versus director gates.** break, adds_defeated, arm_broken and branch are opened by
  BossController. scripted, threads_cut, honest_lines, sera_voluntary_phase_out, stand_still_12s and ending belong
  to each boss's director (open_gate / advance_phase). Any other value is a validation error. A gated last phase
  ends the fight when its gate opens. Why: Generic before wide: the common mechanics are data, and the bespoke
  ones are written with their chapters, visible as lint warnings until then. (COMBAT_LAWS §14.1;
  docs/reports/enemy_codex_report.md schema keys)
- **A fight that ends with the boss standing pays it as a defeat.** A final Break, the yield at a last window
  above 0 and a gated last phase all end the battle as a victory once the current action has resolved. The boss's
  XP is counted as a kill's and its drops are given. Why: The Shard Doll's 60 XP and R-66Y's key drops were
  otherwise lost, and the bible's 'spare it' outcome needs the doll alive. (COMBAT_LAWS §14.3, §14.4, §14.5)
- **Krona duel ends at 50%, or at once on the overcharge.** An ungated last phase whose window ends above 0 ends
  the fight when it closes (BossDef.ends_at), so the Krona duel yields at 50%. Taking 'Overcharge the gauntlet' in
  ch2_duel_mid Breaks her outright with ASTRAL and ends the duel there. The krona_duel director answers the
  script's `call duel_overcharge` by watching Story.choice_made, so the future grove scene must not implement
  duel_overcharge as well. Why: The bible says the duel ends at 50% and the overcharge ends it with an ASTRAL
  burst that Breaks her outright. No grove scene exists yet, so the director is where this can live. (COMBAT_LAWS
  §14.4 Krona, Barren Heir)
- **Possibility Branch fallback is the dialogue box.** A phase with advance_on 'branch' freezes the clock
  (State.BRANCH while ticking, plus the transition pause) and asks the boss file's branches entry (the one whose
  after_phase is the previous phase) as a Story choice. The option's flag (Flag:State) is written at once; an
  option with no flag adds its lean. A director may stage it in-world instead (on_branch returns handled, then
  answer_branch). An optional branch `prompt` is the line shown; `notes` are never shown. Why: The bible wants an
  in-world action. A generic menu keeps every branch reachable until each chapter's director stages its action.
  (COMBAT_LAWS §14.1 Possibility branches)
- **Boss add rows: counts, triggers, overrides, respawns.** The cap is the file's max_adds, else the largest
  authored count (minimum 3); the Cradle's recorded 2 stays. Trigger rows never spawn at phase start:
  every_<N>pct_hp_lost fires on each N% lost, and other triggers wait for a director's spawn_triggered(id). Row
  overrides (shield, level, weak, resist, tags, hp, xp) apply to a copy of the codex enemy. respawn_s runs on
  battle time while the row's phase lasts. Why: Authored counts such as 6 arms and 4 umbilicals, the Ashigaru on a
  surrender order, and Cyrus's 4-plate puppets were wrong or dead before (DATA-3). (COMBAT_LAWS §13.9, §14.4,
  §14.5, §14.8)
- **Boss on_break / on_enter strings are design notes.** These strings are never shown in play. The boss's first
  Break in a fight shows Sera's bestiary break_line (data/text) unless the director handles on_break. Why: Most of
  these strings are notes to designers ('Sets Daimyo_Phase1.'). The text layer already has the player-facing line.
  (DECISIONS 2026-11-02 text layer; docs/JOB_CHATGPT.md break_line)
- **999 Shard Doll retune (DATA-20).** The doll stays Lv 3 (bible §14.3 says Lv 4) with gentle powers for a
  zero-fail tutorial. HP stays 9000 (the guide curve's 2,250 x 4) as a buffer only, because the fight ends on the
  phase-4 Break and has no HP bar. Why: A zero-fail first boss for a Lv 3-4 party. The HP figure is not a Lv 3
  curve value and is kept on purpose so the phases, not the HP pool, end the fight. (COMBAT_LAWS §14.3)
- **The split dolls fold back instead of dying.** At phase 4 the three split dolls leave through
  BossController.fold_add: no gold statue, no XP, their bodies slide into the doll as they fade. This amends the
  earlier 'the director kills them itself' entry. Why: chapter1.json says 'The three fold back into one'. Killing
  them stood three statues and paid three shares of split-doll XP. (COMBAT_LAWS §14.3; DECISIONS 'The 999 Shard
  Doll's split dolls hold their Break')
- **Cradle crack and gold leaf amounts.** A Dark Break Signature widens Crono's crack by 3 integrity, paid once
  through his TimeDebtComponent and mirrored into Game. The phase-3 U7 gold leaf lasts 3 battle seconds (not
  wall-clock), returns to the canvas the fight began on, and is restored on any battle end. Why: The bible says
  only 'the crack widens' and gives no amount. Combat timers run on battle_time. (COMBAT_LAWS §14.2, §18.5)
- **Drops a scene narrates are not boss drops.** The Daimyo's and the Cradle's drops lists are empty:
  ch2_daimyo_won, ch2_vault_nodachi and prologue_cradle_defeat hand those items out. Lint warns when a boss drop
  is also granted by dialogue. Why: A KO drop handed the Cobalt Nodachi out whatever the vault choice was
  (GAP4-8), and gave the Cradle's bracer twice. (COMBAT_LAWS §14.2, §14.4; DECISIONS 'Audit fixes' (Cobalt
  Nodachi))

### Statuses, shields and the enemy brain

- **Ruin is battle-scoped until camps exist.** Enemy Ruin lowers the max-HP ceiling for the battle;
  RuinRules.clear removes the stacks (TimeDebtComponent and StatusComponent) and resets the cap when the battle
  ends. TimeDebtComponent.rest() still clears Ruin for a future camp. Why: The cluster note asked that Ruin not
  leak between battles. There is no camp in the build yet (TimeDebtComponent.rest() has no caller), and party
  actors are rebuilt per location, so 'until camp' would really mean 'until the next location loads'. Persisting
  it properly needs a Game roster field cleared at camp, which belongs with the camp system. (Combat Laws 12.2
  (Ruin), Appendix A.45, 18.7 #18)
- **Where Ruin lives and how the Porcelain Silence cap is found.** Crono's stacks live in
  TimeDebtComponent.ruin_stacks, inside the 10.1 formula; his StatusComponent 'ruin' entry mirrors them for the
  HUD. Every other battler's stacks live in the StatusComponent entry, and CombatantStats.max_hp() applies
  max(0.10, 1 − 0.15 × stacks). The cap is 10 when any boss on the field has an arena_hazards entry starting with
  'ruin_scaling' (config 'ruin_cap' overrides it), otherwise 3. Why: §12.2 lowers every character's ceiling, not
  only Crono's. The Porcelain Silence rule is a §12.6 arena hazard and the data already carries it as a string, so
  no new field is needed. (Combat Laws 12.2, 12.6 (Ending spaces), 14.12 Ending 5)
- **Statuses that act during an enemy action are read when the action is chosen.** EnemyBrain.choose writes
  refracted, probability_lock (then removes it, since it covers the 'next action') and the GUILTY redirect
  ('turned') into the action dictionary, and EnemyStrike reads them. Why: The coordinator counts down turn-based
  statuses before the action resolves, so a 2-turn status read at resolution would cover only one action. Reading
  at choose time gives Refracted and GUILTY their two actions. (Combat Laws 7.3, 12.1, 12.2)
- **GUILTY redirects one attack at one ally.** 50% of a GUILTY enemy's attacks aim at a random living, targetable
  ally of its own. A redirected attack, even an area one, resolves as a single hit on that ally. Bosses are immune
  (12.1). Why: The bible says 'hits one of its own allies'. Resolving the shape against enemy bodies would hit a
  crowd, and resolving it against the party would hit the wrong side. (Combat Laws 7.3, 12.2 GUILTY)
- **A Jammed enemy whose actions all wind up makes a plain Attack.** When every action winds up and the enemy is
  Jammed, it strikes with its weapon tags, no wind-up, at the weakest target. It does not skip the turn. When
  nothing is usable, the brain relaxes the cadence first, then the HP window, and never relaxes Jammed. Why:
  Jammed forbids starting a wind-up; it is not a stun. A plain strike keeps the enemy's turn and gives HZ a
  visible payoff against a third of the roster. (Combat Laws 7.3, 12.2 Jammed)
- **Party accuracy: rolled per strike, only when below 100%.** Each party strike rolls against 1 + accuracy_mod,
  and only when the mod is negative. A miss shaves nothing and shows 'miss'. The plate preview does not forecast
  misses: it shows what a hit that lands will shave. Why: BLIND is meant to cost hits (§12.2). Skipping the roll
  at full accuracy keeps seeded tests and probes drawing the same numbers. Acceptance #23 still holds for every
  strike that lands. (Combat Laws 12.2 BLIND/Ink Blot/Ash Inhale/White-Noise, 18.7 #23)
- **Shave penalties are taken per matching strike.** ShaveBonus.penalty: BLIND [BOW]/[GUN] hits lose 1 shave, and
  Crono's ASTRAL hits under Sticky Ash lose 1. The penalty comes off each matching strike after the flat bonus,
  floored at 0, in both preview_action and apply_strike. Why: Both rules say hits 'lose 1 shave'. Applying them in
  the shared shave helper keeps the preview equal to the result. (Combat Laws 12.2 BLIND, Sticky Ash; 18.7 #23)
- **Ash Inhale counts as one SLOW stack.** Ash Inhale gives gauge ×0.5, movement ×0.5 and −20% accuracy. It does
  not add to a Mercury SLOW stack for the hitch. Why: The table says 'SLOW (1 stack) and BLIND 20%'. This is the
  smallest faithful reading. (Combat Laws 12.2 Ash Inhale)
- **Refills once only matters at a 'break' gate.** consume_refill() is checked when a phase gated by 'break'
  Breaks: the first Break rebuilds the plates (as every Break does) and the gate stays shut; the second opens it.
  Phases that advance by HP window are unaffected. Why: Every Break already ends in a full rebuild (§5.4).
  'Instead of the phase ending' only changes anything where a Break ends the phase. (Combat Laws 5.7 Refills once,
  14.1)
- **Break-immune conditions and shared plates.** ferro_in_party holds while a living party member's kit element is
  FERRO; it is evaluated live, so a swap-in releases a Break that is waiting at 0. Other conditions (springs_cut)
  hold once BreakConditions.release(body) is called. Conditions are re-armed every battle. For shared plates, the
  first body of a shared_group holds the count; members show it, Break with it, share lock extensions and recover
  with it; if the holder dies, the first living member keeps its count running. Why: §5.7 and §13.4 E38 / §13.7
  E64 describe both rules. Linking to the first body needs no extra node and keeps preview_action's existing
  routing. (Combat Laws 5.7, 13.4 E38, 13.7 E64)
- **DoT ticks and regen.** A DoT applied by an enemy hit stores tick = max(1, 15% of that hit's raw damage) and
  deals tick × stacks each period. It never crits or shaves, and the zero-fail HP floor holds. Regen heals its own
  tick, or 2% of max HP if it has none. Grief costs 2 MP per stack every 10 s; Laugh Track Drain costs 1 MP every
  8 s on each bearer (the action hits the whole party). Why: §6.3 fixes DoTs at 15% of one hit's raw damage at
  cast time; regen has no amount in the bible and 2% matches the spore mat. (Combat Laws 6.3, 12.2)
- **Boss status rules count Mercury SLOW as SLOW.** Bosses halve slow, mercury_slow, chrono_lag and knock_static
  (seconds × 0.5; turns halved, at least 1) and are immune to confuse, guilty and time_stop. An entry can lift
  this by listing statuses under behaviour.takes_statuses. Field ticks (the amber pool) are not halved. Why: §12.1
  names 'SLOW'; Mercury SLOW is the SLOW status of §12.2. Fields re-apply every second, and halving their 1.5 s
  would make them flicker. (Combat Laws 12.1)
- **Glenn's laugh BP and the Ringmaster exception.** The laugh BP comes only from an empty counter. A Broken enemy
  with behaviour.steal_all_when_broken gives up its whole counter in one steal; the pool's cap still applies. The
  Ash Ringmaster's phase data carries the flag. Why: §7.5 says 'If the counter is empty, he takes 1 BP from the
  laugh'. §14.8 makes the Ringmaster's Break the one exception to the 3 BP cap. (Combat Laws 7.5, 14.8, 18.7 #22)

### Resolution pipeline

- **Turn statuses.** A status counted in turns ("N turns") counts the bearer's own actions after the action that
  gave it. A status added while the bearer's own action is in progress (StatusComponent.begin_action through
  on_turn_taken: Prism Guard, Rooted, Fragile) is not counted down by that action. A status that lands on a parked
  ally counts that ally's next action. Why: Without this rule, a self-buff cast on the caster's own turn was used
  up by that same turn's _finish_turn, so 'until his next turn' meant nothing. Cited in
  scripts/combat/status_component.gd and battle_coordinator.gd. (COMBAT_LAWS_BIBLE §10.6, §12)
- **NULL true damage.** NULL damage goes through the full party-hit pipeline (PartyHit.context into
  DamagePipeline.compute_hit). It ignores DEF and resistances (resist, immunity, absorb). No weakness multiplies
  it unless NULL itself created that weakness (`nulled_weakness`). Every other term applies as to any hit:
  synergy, party synergy, home canvas, Boost, the Broken crit, guaranteed crits, perfect frame, falloff,
  height/ledge, taken_mult, flicker and variance. Why: NULL had been a separate shortcut that skipped synergy, the
  Broken crit, variance and the other terms. 'True damage' in §6.3 means the defence terms are removed, not the
  whole pipeline. (COMBAT_LAWS_BIBLE §6.2-§6.4, §8.7, §8.8)
- **Lv3 fields.** Boost Lv4 leaves the technique's lv4_field; if it has none, its own lv3_field; if neither, its
  element's default field. Boost Lv3 leaves a field only when the technique's own row says so (lv3_field: Astral
  Slash's watercolour puddle, Ferro Graviton's mercury pool, Prism Refraction's caustic floor). A plain Attack
  leaves nothing, and a Boosted Attack scales only its power and shape (no Lv2 debuff, no Lv4 field). The field
  covers the shape (CIRCLE: the circle; LINE: the line; SINGLE: a 2 m circle under the target) for 6 s of battle
  time. Lint rejects field kinds BattleFields does not know. Why: The §11 tables give some techniques a field at
  Lv3, while §7.4 gives every technique an element field at Lv4. One ResidualFields rule covers both and keeps the
  Attack plain. (COMBAT_LAWS_BIBLE §7.2, §7.4, §4.2, §11)
- **Floor fields and Sera; the two white blanks.** Every field except divinity_field, astral_field and sound_ring
  is a floor field, and floor fields never touch Sera, good or bad (spore mat, golden patch, ghost ring, puddle
  free cast). The Canvas Clash white blank, left by any NULL hit, is terrain only: it erases fields and leaves hit
  tags alone. The NULL Boost Lv4 residual white blank (strips_tags) erases the tags of hits on targets inside:
  neutral damage, no shave, no debuff. The caustic floor adds [VITREOUS] to party hits whose path crosses it, or
  whose target stands in it. Why: If the clash blank also stripped tags, every NULL hit would cancel the fake
  weakness NULL creates in the same circle. The bible's own 'Quantum Flicker' rule exempts Sera from floor
  terrain. (Combat Laws 7.4, 9.6, 10.2, 12.1, 12.5)
- **Divinity Field.** One temporary plate is worth 5% of max HP (FieldEffects.DIVINITY_PLATE_HP = 0.05). The
  Divinity cap of 20% of max HP as temporary shield is therefore 4 plates on any shielded body, and 20% of max HP
  of temp shield on an ally, gained at 5% max HP per tick. The thaw (the end-of-field shield return) goes to the
  field's owners only. Balance note: this replaces the HP-scaled roundi(max_hp*0.2/50) plate cap, which gave a
  64,000 HP boss about 256 plates, with a flat 4 for every enemy. Allies previously gained 1 HP of temp shield per
  tick. Retune here if U3 bosses feel too hard to Break inside Divinity. Why: The old formula gave large bosses
  hundreds of temporary plates, and allies a token 1 HP per tick. One plate-to-HP ratio applies the bible's 20%
  cap the same way to enemies and allies. (COMBAT_LAWS_BIBLE §12.5, §9.6)
- **Cap upgrades from flags.** A flag state earns a 15.7 upgrade by naming it under "upgrade" in data/flags:
  Krona_Joined set gives parry_taught (6 frames); Goyama Repainted gives parry_dojo (8 frames); Central_Eye Broken
  gives hold_step. CapUpgrades applies these on every flag set, never takes one back, and lint checks the ids.
  max_bp and max_spend are wired the same way but wait for the Memory Shard and first-Vaelos-rift flags of later
  chapters. Why: Before this, MAX_BP_UPGRADED, MAX_SPEND_UPGRADED, the parry-frame upgrades and hold_upgraded had
  no setter. (Combat Laws 15.7, 7.6, 4.2)
- **Technique signature.** The uniqueness key that lint uses for techniques (TechDef.signature) is casters +
  effect + sorted tags + shape + radius + length. Same-caster techniques may share tags and size when their effect
  differs. Why: The bible's own tables give several same-caster pairs one tag set and one size and tell them apart
  by what they do: Mycelia Tether and Photosynthetic Burst, the three NULL commands, and Sera's SINGLE [TACHYON]
  commands. Under a key of tags, shape and size alone, §17.5 would reject the bible's own content.
  (COMBAT_LAWS_BIBLE §17.5, §18.2)
- **HOLD needs a Broken target.** A technique whose data sets `requires_broken` (HOLD) is refused in cmd_tech
  before any cost is paid when the target is not Broken. The command window stays open, so nothing needs
  refunding. HOLD takes its step count from the technique's data `steps` or from options.steps, at +5% solidity
  cost per extra step. Why: HOLD used to run against unbroken targets and ignored its step count. Refusing before
  payment is the clean failure the bible asks for. (COMBAT_LAWS_BIBLE §10.2)
- **Cooldowns are per caster.** A technique cooldown (data `cooldown_turns`) belongs to the caster. It counts that
  caster's own actions, starting with the next one (the cast itself does not count, as with turn statuses). Each
  caster of a Dual or Triple carries its own cooldown, and _can_cast refuses a multi-caster technique while any
  partner's cooldown is running. A field the technique names as its `recharge_field` (Mercury Pulse: the amber
  pool) clears the actor's own cooldown at once. Known gap: the partner check does not yet honour recharge_field,
  and it has no dedicated test. Why: A cooldown shared across the party let one actor's turns recharge another's
  technique. Cassia-09's Mercury Pulse says it 'recharges after 2 of her turns'. (COMBAT_LAWS_BIBLE §7.4, §9.6;
  Cassia-09 kit)
- **Party-only ledge term.** The ±10% height term (attacking down from a ledge of 1 m or more: +10%; attacking up:
  -10%) is live for party strikes through PartyHit.ledge. EnemyStrike has no ledge term yet, and the preview's
  the preview now includes it too (the final review's "one hit context": the preview and the resolution share
  PartyHit). Why:
  This records the asymmetry so it can be closed deliberately: add the term to EnemyStrike and to the preview
  estimate. Shave parity is unaffected. (COMBAT_LAWS_BIBLE §8.8)

### Technique effects

- **Effect table.** A technique `effect` is either a bespoke handler (TechEffects.HANDLED, 40 ids, unchanged), a
  row of data/effects/effects.json (57 ids), or an entry under `flavour` (prismlight_salvo) or `pending` (none
  today), each with a reason. Every enemy action effect is an EnemyEffects arm, a summon:<key>, or listed in
  `enemy_pending` (shared_damage). Every status the data names has a reader or is listed in `status_pending`
  (confuse). Data.load_all and lint_data.py fail on anything else. Each row is the technique's §11 text turned
  into conditions, damage and shave modifiers, and ops that run after the hit. Clauses that need a system nobody
  has built yet go in the row's `unbuilt` text and are not faked. Why: The audit found 58 technique ids and 6
  enemy ids that resolved silently as plain damage, and no check that could tell an unbuilt rule from a typo. This
  follows CLAUDE.md's 'content is data, systems generic': most rules become one table row instead of a new match
  arm. (Combat Laws §11, §5.3, §5.4, §7, §12)
- **Readings chosen where §11 is ambiguous.** 'Next action' on an enemy is turns 2. Statuses on enemies count down
  at the start of their own turn, so this matches the Lv2 debuffs: Gramophone Resonance's hitch, Ruin Elastic's
  decoy, Masque Feint's mirror. A 'heals the party for what it deals' technique (First Light, the child variant)
  shares the damage it deals evenly across the living party. 'High Cassia Synergy' (Ashtear Paradox) means the
  Triple's synergy is 2.75 or more, which is the three-universes bonus. 'Lucca was asked' and 'Cassia consenting'
  read the flag Lucca_Consent:Asked. Prometheus Overload without that flag writes Prometheus_Core:Burned. Rewind
  Reel puts enemies back at their last turn start, because the engine keeps no 8 s history: wind-ups are undone
  and the gauge loses 8 s of fill. A hz_static hit gets +30% if Static is tuned or the target is BLIND.
  Washi-Hollow Rebirth's plate loss never Breaks on its own. Guile Elastic's clone draws the struck enemy's next
  two actions. Origami Requiem's gold fold lasts the whole battle, because at 1% per 8 s a 6 s field would never
  thaw anything. The Last Joke is offered only while vaelos or empress_vaelos stands. Why: §11 leaves these open.
  Each choice is the smallest reading that keeps the rule mechanical and testable. (Combat Laws §11.5-§11.13,
  §12.1)
- **Enemy-owned fields hurt the party.** An Ash Field laid by an enemy (owner_team 1) slows the party inside it
  and chips their temporary shield by one plate's worth every 2 s; the enemy's own side is not affected. It comes
  from the Daimyo's oil flood (a BATTLEFIELD action covers the whole arena for 12 s) and from the oil-fire bike.
  The Mercury Leaker's oil pool gives Mercury SLOW to party members standing in it and switches on Oil-Blight.
  Before this change every ash field hurt enemies only, whoever laid it. Why: The Daimyo's phase data says
  'oil_floods_arena_ash_field_slow_plus_shield_chip', and §12.2 defines Oil-Blight as a party-wide condition.
  (Combat Laws §12.5, §14.4)

### Progression and data readers

- **One flag spelling.** Outside dialogue, every flag reference is "Name" (set, any state) or "Name:State"
  (exactly that state), naming a flag and state defined in data/flags. This covers kit and tech unlocks, tech
  requires_flags, a boss's *_by_branch keys and the requires of its adds, actions and phases, and universes
  hazard_by_flag. FlagRef splits and validates; Flags.holds tests. The old Flag_State and Flag=State spellings are
  rewritten and rejected by Data.load_all and lint_data.py. Pseudo-flags became real unlocks: Dark_40 ->
  {dark_min: 40}; Act1_Done -> {chapter: 2}, because Story 'Acts of the hub' ends Act 1 when U1 opens in Chapter
  2; True_Ending_Route -> {story: true_ending_route}. Why: Dialogue and README already use Name:State
  (story_runner, boot --flag=). The kit Flag_State and boss Flag=State forms could never hold against Flags'
  exact-id lookup. (Story Bible §9.3; Combat Laws §11 Unlock column)
- **Kit unlocks.** A kit entry's unlock is a set of conditions that must all hold: chapter, on_join, level, flag,
  light_min / dark_min / prismatic_min, drop (an enemy key whose drops have been awarded this cycle, Game.looted)
  or story (never automatic; the chapter script teaches it with `learn`). Recruit and set_chapter check every
  kind. A flag or affinity change re-checks the flag kinds, a level-up (BattleAftermath.write_back ->
  Game.set_level) re-checks level, and an awarded drop re-checks drop. The tech file's `unlock` stays as the
  bible's Unlock column for reference; the kit entry is what Game evaluates. New Game still leaves the chapter-0
  kit to the Prologue's story teaches. Why: §15.8's level-gated techs had no grant path. The flag `learn`
  convention covered only two techs. suite_aftermath pins the Prologue teaching Crono in story. (Combat Laws §11,
  §15.8; supersedes the passing note in DECISIONS 'Audit fixes of 2026-11-02' (Cobalt Nodachi) that
  _learn_defaults honours only chapter and on_join)
- **Item kinds.** Each data/items/items.json item has a kind: consumable or material (inventory), key (key_items),
  relic (relics) or counter (adds to the Flags counter it names; Kirie Scales -> kirie_scales for Ending 8).
  Game.grant routes boss drops, enemy drops and dialogue give_item / key_item / relic by that kind, and the verb
  is only the fallback for an unlisted id. Kinds follow Combat Laws §11.14 for relics (Vaelos Tooth, Grief Filter,
  Charred Laurel, Bubble Lens, Kintsugi Brush, Vapor Memory Core, Long Pull, Syringe Heart Key, Null Shield).
  cobalt_nodachi (the vault pigment) is a key item, Thoracic Ring and Gold-Leaf Memory Flake are materials. The
  Matriarch's seed drops x3 (three uses). Only consumables with a battle effect are offered in the Item deck. Why:
  29 referenced ids were undefined, and the boss path turned every unknown id into a relic. (Combat Laws §11.14,
  §13 drop notes, §14.6; Story Bible 3.6)
- **Rewards: XP, drops and leans at victory.** RewardResolver pays on victory only (a defeat or a withdraw pays
  nothing). XP: a defeated enemy pays full, a spared one half. Drops: every defeated, non-boss enemy rolls its
  drops ({item, chance, count}) through Game.grant; a boss's drops are paid by RewardResolver.award_drops at victory
  only (final review). Leans: an enemy feeds its codex lean only when resolved the signature way: L when spared, D when
  salvaged (killed while Broken by a RUIN or FERRO finisher) or incinerated (FIRE finisher), P when a Dual or
  Triple finished it. Anything else feeds nothing; bosses lean through their branches. The +1 crafting part from a
  salvage waits for crafting. Why: Every spare used to add Light whatever the enemy's lean, and no regular enemy
  ever dropped anything. (Combat Laws §5.2 (Spare, Salvage), §13.1 Lean column, §15.2)
- **Effective Rank Level.** Regular and elite encounter enemies spawn at ERL + (authored level - universe band
  minimum), with ERL = round(active party average level) + universes.json bias + hazard. Hazard is the encounter
  row's `hazard` field (0-2), raised by the universe's hazard_by_flag (U3: Azar:Predator gives 4). The authored
  level is read as the enemy's rank inside the band, so a band-floor party in U0 meets the authored levels and the
  codex spread survives. A party under the band minimum meets nothing below band minimum - 2. Above band maximum +
  5 the encounter is under Time Shear (+15% speed; SLOW immunity, the vignette and the extra consumables wait for
  their systems). Bosses, mini-bosses and an encounter row's explicit `level` keep their levels. universes.json
  `cap` is the player stat cap (§15.1, §15.6), not part of ERL. Why: §15.3 says regular encounters scale to the
  party, but level_band and bias were read by nothing. (Combat Laws §15.1, §15.3, §13.2 (Atrium Echoes rescale))
- **Universe tables are data.** Universe reads fps and name from data/universes/universes.json.
  CanvasStackEffect.GRADES is the only grade table, and the battle plane's paper tint comes from it via paper_of;
  a test keeps its fps column equal to the data. Universe.leaks is deleted (HD2DWorld.set_leak is the hub leak). A
  location without field_music plays its universe's music_field, and a battle with no music of its own plays
  music_battle. Kit `passives` and `element` stay as bible reference fields. Why: There were two or three copies
  of the per-universe numbers, and they had already drifted. (Reference Bible §2.4, §3.1)
- **Keyed plates decide the count.** When a phase or enemy keys its plates, `shield` must equal the summed weights
  (EnemyDef validation and lint). The Vaelos Child's Tantrum and Hide and Seek now say 5, the count the fight
  already played; the bible's 6 waits on Nich. Why: ShieldComponent always plays the keyed sum, so the mismatch
  was invisible and unchecked. (Combat Laws §14.12)

### Engine, saves and the possibility engine

- **An Amber Rift flag pays its +15 through the rift alone.** When a flag with amber_rift reaches its rift_state,
  set_flag registers the rift under rift_source (or the flag id), once per source. Prismatic from an override or
  from the state is not paid on top; other affinities are. Goyama gets amber_rift/rift_state Both/rift_source
  Amber_Rift_U1_Goyama with an empty Both affinity. The Cradle no longer passes {prismatic: 15}. Why: The Bowl
  Still Whole and Goyama Both are +15 in the bible, and both routes of the Bowl must pay the same. A shared
  rift_source lets the flag and its dialogue's `rift` command name one rift. (Story Bible 9.1, 9.3; Combat Laws
  15.9)
- **Flags are permanent for the cycle; a few are mutable.** A flag defined in data/flags keeps its first state
  this cycle; a second state is refused with a warning. Defs may say "mutable": true; today that is Seed_of_Doan
  (Grown -> Ash), Robo_Ribbon (Equipped -> Lost), Sera_Clone (Rescued -> Lost) and Glenn_Duals (Refused -> Granted
  via the Bekkler doll). Script-local flags with no definition are unrestricted. A Codex re-break API
  (post-ending, 8.1) will be the explicit exception when it is built. Why: Story Bible 9.2 says flags are
  permanent for the cycle, but 9.3 lists flags that legitimately change state within a cycle (the verifier's
  refutation), so the rule is per definition. It also stops a boss retry from writing both branches' affinity.
  (Story Bible 9.2, 9.3)
- **The endings are data.** data/endings/endings.json holds each ending's inclusive affinity bounds, FlagRef
  `flags` / `not_flags`, counter minimums and rift count; EndingRules evaluates it, and Data.load_all and
  lint_data.py validate its flag references. Spellings follow the data: Seed_of_Doan:Grown; Sera_First_Voluntary
  stands for 'an earlier voluntary phase-out'; 100 Kirie Scales is the kirie_scales counter, the live writer
  through Game.grant. NULL mastery, Kintsugi repairs and the siege are counters. New flags:
  Native_Duplicate_Given, Crono_Entered_Heart_At_20, Porcelain_Stress_Held_100, Seed_of_Doan_Full,
  Mycelia_Tether_Mastery, Codex_True_Null, each with a Codex Keeper page. Why: Content belongs in data, and the
  validator makes it impossible for a predicate to test a flag nothing can set (DECISIONS 'One flag spelling').
  (Story Bible 7.1, 9.3)
- **Codex leans grant no Beckons.** add_lean writes affinity but no Beckons. Why: Combat Laws 7.7 says Beckons
  come from story choices and 'are never earned in battle'; leans are battle rewards (5.8). 15.9's 'every affinity
  write' is read as the story writes 7.7 describes. (Combat Laws 7.7, 15.9)
- **Settings live in their own file.** Player options live in user://settings.cfg, read at boot and written on
  every Game.set_setting; save slots no longer carry them. A version 1 slot's settings are adopted once while no
  settings file exists, only for known keys of the right type and inside SETTING_RANGES (flow_speed 0.75-1.25,
  text_size 0.5-2, volumes 0-1). Title Options step battle flow through 0.75 / 1.0 / 1.25. Why: Options are the
  player's, not the run's. An option toggled on the title must survive Continue, and must persist without waiting
  for a checkpoint. The ranges keep probe pollution (flow_speed 4.0 in old slot_00 files) out of a real install.
  (Combat Laws 3.7, 17.5)
- **Save files are atomic and versioned.** Every save and settings write goes through a .tmp file renamed over the
  target. Saves.VERSION is 2; Saves.status returns empty / ok / corrupt / newer, and only ok loads. The title
  hides Continue otherwise. summaries() lists slot 0 (autosave) first. The `universe` field stays in the save.
  Why: A crash mid-autosave must not leave a Continue row that does nothing. The universe field is not redundant
  since c52baeb: Continue sets the saved universe before Router.go, so landing in a U1 location is not charged as
  a gate jump. (Combat Laws 18.x save data line (siege count, flags persist))
- **Headless runs never touch the player's files.** Saves.suspended, or the --no-save user argument, moves slots
  and settings to user://scratch. The prologue, ch1 and battle probes and the test runner set it; the runner also
  resets options to DEFAULT_SETTINGS. Why: The README tells everyone to run the probes, and they used to overwrite
  the real autosave with probe state (and flow_speed 4.0).
- **The Atrium Siege, first cut.** Integrity 0 outside a battle starts the siege's frame once the field is idle:
  tape stop; an optional `atrium_siege` dialogue script (for the studio assistant to write); Atrium_Siege +1; Sera
  reglazes to 20; a jump to the last Atrium checkpoint, meaning the spawn of the last save made in the Atrium
  (Game.atrium_spawn). Before the Atrium is home (the Prologue) the party stays where the defeat rewind put it.
  The three waves and the vendor-family losses wait for their encounter data. An ordinary defeat still rewinds to
  the encounter. Why: Acceptance check 25 requires that integrity 0 starts the Siege, and Ending 5 needs the
  counter. This is the smallest faithful version that gives integrity 0 a consequence and a way back to 20.
  (Combat Laws 16.1, 16.3, 18.7 #25; Story Bible 9.3 Atrium_Siege)
- **porcelain_stress follows integrity.** Audio sets porcelain_stress = 100 - Crono's integrity on every integrity
  change and at boot; it drives the existing Music low-pass (20 kHz at stress 0 down to 2.5 kHz at 100). Why:
  16.3: at integrity 0 porcelain_stress hits 100; 17.3's music-box thresholds read as integrity values. (Combat
  Laws 16.3, 17.3)
- **New Game+ biases toward the finished cycle's dominant affinity.** Game.new_game with new_game_plus resets the
  cycle with Flags.dominant_affinity() (+10). A fresh New Game resets Sera's permanent baseline to 0.
  Game.new_game is the only cycle reset. Why: 15.10 / Story Bible 7.2. The old code forwarded a stale bias, and
  the title reset the cycle a second time. (Combat Laws 15.10; Story Bible 7.2)
- **A location may hold its opening black.** Location.holds_black, set before its first await, makes Router.go
  skip its own fade-in; the kitchen's wake uses it. Why: The Router faded in over the 'wake in the dark' lines one
  frame after the kitchen set alpha 1.

### Shipped locations

- **The Fair waits for Leene Square.** leave_for_fair writes Ch1_Fair_Left and sets the [crono] party only once
  the Router will accept the go (has_location and no transition running). Until then ch1_fair_call captions that
  the square is not built and the hub stays as it was. The CP_FAIR autosave, at the hearth, replays the call on
  Continue. No save is made at departure: Leene Square's first checkpoint must write the arrival autosave (and set
  sera_state) when the scene is built. Why: A save at departure would hold the flag with location atrium and
  resume in a hub with no way forward. Committing before an unbuildable go left Game and the field party
  disagreeing. Router.go's own refusals are checked first and the go is not awaited, because the Atrium is freed
  during the transition. (Story Bible Ch1 beat 10 (the Fair))
- **Every autosave names its marker.** Location.autosave_at(spawn, cp) records the checkpoint and the marker a
  Continue resumes at. Atrium: loft_bed, ramp_bottom, dummy_center, seed, dais (Robo's rest), hearth. Kitchen:
  start, gate, cradle_center. A field defeat jumps the party back to where the leader stood when the battle began,
  and to the spawn marker only when nothing was recorded. Why: Router.go was the only writer of Game.spawn_point,
  so every save after the time skip resumed in the loft, and a lost hub fight teleported the party up there.
  Combat Laws 16.1 sends the party back to 'the moment before the encounter'. (Combat Laws 16.1)
- **Autosaves that do not end the day.** Slot 0 is written after the 999 Shield Dummy's result, after Glenn's
  honour check and after the Seed's first water, without changing the checkpoint. Robo's 'Rest and save' still
  ends the day and moves to night. Why: Between the hub opening and the Fair, the only save was the rest that
  advances the story, so the dummy fight (minutes long), Glenn's verdict and the Seed were lost on quit. (Story
  Bible Ch1 beats 4-8)
- **The Seed of Doan has one state.** The flag Seed_of_Doan (Grown or Ash) is the state every consumer reads
  (Promise Across Rust, Endings 4 and 6, the Bloom Matriarch, the Forge Tendril). The seed_waters counter only
  counts waterings. Each water pays the Grown state's affinity from data/flags (Light +5); the third water sets
  Seed_of_Doan:Grown, which pays the last +5, for Light +15 in all. Seed_of_Doan_Full stays a separate Chapter 15
  flag for Ending 6's full growth. Chapter 1 builds only the first water, because a gate slip must pass between
  waterings. Why: Waterings awarded no Light, and nothing ever set the ids the endings and the Triple read. (Story
  Bible §5 (Doan and the Seed: 'watered three times across three visits'), Ch1 beat 7, §9.3 'Grown (Light +5 per
  water)')
- **The Cradle wakes at the pantry.** The Prologue's Cradle trigger is now the pantry mouth only (x 6.5..10.5, z
  -6.8..-2.8). The Shardlings stay at (4.5, 2.5); the Spoons move to (10, 3.2) r1.8; the post-boss Echo moves to
  (11, -3.5). The probe and --demo=cradle walk to the pantry. Why: The old box covered the hall from x 4.5, so the
  Spoons' two-tag lesson came only after the boss it prepares for. The locked-exit line already points the player
  at the pantry wall. (Story Bible Prologue beats 7-8 and its Enemies paragraph)
- **The lab spawns all four echoes.** After the dummy, the Atrium spawns Moss-Mice, a Bekkler Fragment, the Ashen
  Echo of Krona (by the hearth) and the Ferro-Drone 09 (by the workbench). The post-dummy caption names all four.
  Why: The caption promised an Ashen Echo that never appeared, and two validated encounters shipped unused. (Story
  Bible Ch1 'Enemies')
- **A field Rewind with nothing to rewind is free.** Pressing R in the hub outside the scripted loft Rewind shows
  'Nothing here to rewind.' and charges no Translucency Debt. The loft beat's Rewind still costs +5%. Why: The
  bible prices 'each Rewind in combat or gate jump'. Debt heals only at U7's lotus ponds, so eleven stray key
  presses could walk Sera to the 55 cap and start every later battle at 45% solidity. (Story Bible §3.4
  (Translucency), Ch1 beat 2)
- **The hearth confession is priced in the flag data.** Crono_Confession keeps Told Light +10 and Hidden Dark +10.
  The values now live in data/flags/flags_u0.json and the dialogue no longer overrides them. Why: The kitchen's
  first lie (±5, DECISIONS Story) sets this choice up as the chapter's honesty beat, and ±10 matches the dummy's
  Spared and Bekkler_Hid's Dark +10. The bible lists no affinity for it, so this is a tuning call; before this
  change, the data file said 0 while the dialogue paid 10. (Story Bible §9.3 (Crono_Confession), Ch1 beat 9)
- **Location sound cues use files that exist.** Cues with no file now play the nearest existing sound: the stir
  (ceramic step), the clock skip (sync_hold_freeze), the chronoslip, the frame snap (universe_switch), the doll
  fall (a low tink), the katana slash (crono_slash), the brass gate (door), the gramophone needle (rewind for the
  Seed, cursor for the gramophone), the heal chime (save) and the ink puddle (U1 woodblock step). A test pins that
  every location cue resolves to a file. Why: play_sfx drops a missing id silently, so the Prologue's signature
  beats played without sound. Generating new audio would touch binary assets, which is out of scope here.
  (Reference Bible audio (the tools/audio set in docs/reports/audio_build_report.md))

### Chapter dialogue data

- **A lost Chapter 2 fight jumps back; the duel is the one exception.** Each bridge, the Daimyo and the Furnace
  has a `fight` label before its battle. A loss plays one narration line, adds 5 Debt and jumps back to `fight`.
  The Krona duel keeps going on after a loss: it reaches ch2_duel_end as a win would, after costing 5 Debt. Why:
  Combat Laws 16.1: Sera jumps the party back to before the encounter, and the Prologue's Cradle loop does the
  same. Story Bible 2.1 scripts the duel's killing stroke being rewound, after which Krona stops, so losing there
  is still progress. The new bridge line is: 'The stroke lands. Then it hasn't. Somewhere a girl turns the page
  back, and the ronin kneel again.' (COMBAT_LAWS_BIBLE 16.1; STORY_BIBLE Chapter 2, 2.1)
- **Chapter 2 sound cues use the files that exist.** sfx_time_ink_footstep becomes footsteps/u1_woodblock;
  sfx_time_rewind becomes time/rewind; sfx_time_fracture_tear becomes time/fracture_sky; sfx_impact_clay_crash
  becomes porcelain/crack_large; sfx_ui_paper_tear becomes ui/page; sfx_magic_astral_burn becomes
  magic/astral_contact; sfx_combat_fibre_tear becomes status/ruin_tear; sfx_weapons_nodachi_draw_cobalt becomes
  weapons/krona_nodachi. No new audio was generated. Why: AudioDirector resolves audio/sfx/<family>/<name>, the
  flat ids played silence, and the build lead does not generate audio. Each pick is the closest existing sound by
  meaning. (REFERENCE_BIBLE 8.2)
- **Chapter 2 music names Reference Bible 8.5 tracks.** mus_boss_goyama_daimyo becomes mus_u1_boss_daimyo,
  mus_boss_weeping_shogun becomes mus_u1_boss_weeping_shogun, and mus_interlude_ash_kitchen becomes
  mus_sera_interlude. These stay warnings until their files arrive. The Furnace approach (mus_u1_furnace_approach,
  which has no file and is not in the table) plays mus_sera_theme, because the scene opens on Sera in the cage.
  Why: The delivery team produces tracks under the 8.5 ids, so the dialogue has to name those ids.
  (REFERENCE_BIBLE 8.5)
- **Missing music must at least be a scheduled track.** lint_data.py reads the Reference Bible 8.5 table. A music
  id with no file that is not a table row is an error; `mus_battle_core` counts as covering mus_battle_core_u<n>.
  A scheduled id with no file is still a counted warning. If the table cannot be found, lint warns and falls back
  to warning only. Why: DATA-11's failure scenario: a typo in a music id could not be detected. Every id
  referenced today is scheduled, so the rule adds no errors now. (REFERENCE_BIBLE 8.5)
- **Script-local flags are declared in data/flags/script_local.json.** The eight progress markers that dialogue or
  code sets and reads are listed with their states under `script_local`: Prologue_Courtyard_Done, Crono_First_Lie,
  Ch1_Arrived, Ch1_Father_Looked_Away, Ch1_Fair_Left, Dummy_Wrist, Bekkler_Doll_Taken, Glenn_Honour_Checked. They
  are not added to Data.flags, so they get no codex page, no first-state rule and no affinity. A dialogue flag
  that is neither defined nor declared is now an error in lint and in Data.load_all. Before, lint only warned
  (296eba2). Why: CORE-11: a typo used to become a silent new flag. Turning the markers into codex flags would
  have added codex pages and text gaps for internal state. (STORY_BIBLE 9.2-9.3)
- **The Router's start-up registry is a const, and dialogue `go` targets are checked against it.** scene_router.gd
  DEFAULT_LOCATIONS lists every location, built or scheduled. _register_defaults copies it into the registry.
  ossuary_arrival (res://scenes/u2/ossuary_arrival.tscn) is registered as the Chapter 3 arrival. DialogueCheck and
  lint read the const: an unknown `go` target is an error, and a registered location whose scene is not built is a
  warning. Why: Data loads before the Router autoload, so Data.load_all needs a static source. A scheduled entry
  is how the Router already treats unbuilt scenes (has_location checks the file). (STORY_BIBLE Chapter 3, 3.1)
- **The chapter's last save follows the interlude and the `go`.** ch2_furnace_won runs the interlude, sets
  checkpoint ch2_done, runs `go` with end_after false, then saves and ends. If the player quits during the
  interlude, they replay from the ch2_vault_done save. Why: STORY-25: the interlude's Debt and spoon counters were
  never saved. A save made before `go` records the scene being left, because Router.go sets Game.location only on
  arrival. Story Bible: Spoon_Taught needs four lessons across the interludes. (STORY_BIBLE Interlude Day 1)
- **The Vaelos Tooth is given as a relic.** ch2_daimyo_won uses `relic: vaelos_tooth` instead of key_item. Why:
  The catalogue already makes it a relic (DATA-10). Game.grant follows the catalogue kind anyway, so the verb now
  matches and the warning is gone. (COMBAT_LAWS_BIBLE 11.14)

### Tooling and harness

- **The headless probes are part of every check.** tools/check.sh runs prologue_probe, ch1_probe and battle_probe
  (the README Cradle command) by default, including with --no-visual; only --quick skips them, together with lint
  and the tool tests. A probe fails the gate unless it prints PROBE_END ok=true and exits 0. Every probe now quits
  with 1 on failure, and a timeout prints ok=false. Why: The quality bar says 'headless probes keep printing
  PROBE_END ok=true', but nothing enforced it and the battle probe had no verdict at all. The cost is about 3.5
  minutes per check, ch1_probe being about 165 s of that. (CLAUDE.md Quality bar; COMBAT_LAWS_BIBLE §18.7
  acceptance checks)
- **A debug start learns its chapter's kit (BootArgs).** A start straight into a location applies --party, then
  --level, then --chapter, in that order whatever the argument order. This covers boot.gd with --scene/--location
  and the test arena. --level goes through Game.set_level for every roster row, the party's guests included. The
  chapter's kit is learned through Game.set_chapter: --chapter if given, otherwise the current chapter, which is 0
  (the Prologue kit). A title start and New Game never take this path, so the Prologue's dialogue `learn` commands
  still teach its kit in real play. Game.set_chapter now teaches every learner (recruited plus guests with a
  roster row, Marle), the same set refresh_unlocks uses. Why: The probes and arena runs must fight with the kit
  and levels a real party would have. The README had promised the Prologue kit by default, but nobody knew a tech
  without --chapter, and a guest stayed at level 1. (Combat Laws §2.2 (guests), §11 and §15.8 (kit unlocks);
  DECISIONS 'Kit unlocks')
- **One uid encoder; existing uids are kept.** tools/common/godot_uid.py (base 34, a-y then 0-8, 63-bit) is used
  by every .import writer: sheets, textures and audio. The committed uids are not rewritten; they are already
  Godot's own text, and a test now pins that. Why: The sprite and texture writers used to make base-36 uids that
  Godot re-encoded on the next --import, which caused one round of tracked .import churn per new asset.
  (REFERENCE_BIBLE §1.12, §10.2 item 3 (.import files kept in the repository))
- **A re-import replaces the raw delivery.** After a successful download, the importer clears that key's
  source_art/.../pixellab* folder before unpacking: frames, metadata.json and the archive. The earlier delivery
  survives in git history and in the record's `history`. A failed download leaves the cache untouched as the
  fallback. Why: The prop route rebuilt metadata by scanning the folder, so a v2 delivery inherited v1's rotations
  and clips. (docs/ART_PIPELINE.md §2, §6)
- **Four-rotation characters get four-row sheets.** When no diagonal direction was delivered, the character
  importer writes only the s, w, e, n rows, and ActorSprite maps the diagonals onto them. A missing idle rotation
  is recorded. The record and frames json list rows, rotations and clips. Why: The contract allows a minimum of
  four facings. An 8-row sheet would have had transparent diagonal rows, which ActorSprite selects on diagonal
  movement. (docs/ART_PIPELINE.md §1 Directions, §3)
- **The hourly importer routes only characters and objects.** Items of kind ui, texture, vfx, tileset or portrait
  are listed as 'no import route here yet' and imported by hand per ART_PIPELINE. They are no longer forced down
  the character route. Record keys read tier and variant from the PixelLab name when the item's own fields are
  empty. Why: Without this, such an item would fail every hourly run, and a character whose tier lived only in its
  name would be re-imported every hour. (docs/BOT_REVIEW.md item 5)
- **Placeholder generators never overwrite a delivery; the npcs Marle paper doll is retired.** spritegen refuses
  any stem that pixellab_assets.json or an importer frames table owns, unless --force is given. Marle's
  placeholder spec now points at assets/characters (her kit makes her a character). The dead assets/npcs/marle
  field sheet and frames table are deleted; her painted stand-in and portrait stay in assets/npcs/marle. Why: A
  README-documented spritegen run would have silently replaced the delivered crono, sera and krona sheets. The
  npcs copy was a 552 KB duplicate that nothing resolved. (DECISIONS 'All current art is placeholder';
  REFERENCE_BIBLE §5 Marle file names (superseded by the importer's rule that a character with a kit lives under
  assets/characters))
- **Texture tiles must divide the 1024 px sheet.** import_texture refuses a non-square tile or one that does not
  divide 1024 (valid sizes 16 to 1024 px) instead of resampling it. Why: SceneKit maps every sheet over a fixed 32
  m, so any other tile size would silently change the world's pixels per metre. (DECISIONS 'Direction' (32 px/m))
- **The audio manifest's verdict is per group, and null when nothing was measured.** The manifest gains
  problems_by_group and checked_groups. `problems` covers music and SFX only once both groups have been measured,
  and is null otherwise; --refresh-manifest writes null. Which SFX loop comes only from write_sfx's loop flag,
  carried on each manifest row; LOOPED_WAVS is removed. Why: An empty list read as a passed loudness gate when
  nothing had been evaluated. A new looped SFX would also have been imported trimmed, with loop Disabled.
  (REFERENCE_BIBLE §1.13 (loudness), §8)
- **Sprite, portrait and UI sidecars: Detect 3D disabled.** All sprite, stand-in, portrait and UI .import files
  now use detect_3d/compress_to=0 (still lossless, no mipmaps). World textures stay lossless and mipmapped; the
  Nov 1 breakdown's lossless rule replaces 1.12's 'VRAM Compressed', so they needed no change. suite_tools
  enforces both rules. Why: With compress_to=1, an editor session viewing a stand-in in 3D could flip it to VRAM
  compression and commit that. (REFERENCE_BIBLE §1.12; style breakdown §12)
- **Reference 10.1/10.2 command block (TOOLS-11).** gdlint and tools/build/build_all.gd are dropped. Nothing is
  generated (locations are built in code from data), parse_all.gd is the parse gate, and tools/check.sh is the one
  command: import, parse_all, the GDScript suites, lint_data, test_tools.py, the three probes, the smoke boot and
  two scene captures. Of 10.2's test scenes, lineup, arena and diorama exist, and lineup and arena are captured by
  every visual check. canvas_switch, vfx_gallery and audio_board are scheduled for when their content exists.
  10.2's headless checks: import settings and uids exist now; palette per canvas, frame counts and fps, manifest
  naming and per-file loudness are open tooling work. Why: A new agent following 10.1 would run commands that do
  not exist. Recording what the harness really is gives the bible's acceptance net one honest list.
  (REFERENCE_BIBLE §10.1, §10.2 (to be amended once Nich decides))
- **check.sh visual step: two scene captures and one known-noise filter.** After the title smoke boot, the visual
  step captures test_lineup (60 frames) and a test_arena autobattle (120 frames). The smoke and capture logs pass
  through one filter that drops only the known-harmless lines: lavapipe/llvmpipe, the ObjectDB report at exit, and
  the Vulkan context failing to start without a surface (Godot then falls back to OpenGL 3). Why: Nothing
  automated rendered a Location or ActorSprite before this. The pre-existing smoke step also failed in every
  container, because the Vulkan fallback error was not filtered. (REFERENCE_BIBLE §1.13; CLAUDE.md Environment
  notes (cloud captures))
- **The Vulkan-context log exemption applies only under xvfb.** check.sh drops the
  rendering_context_driver_vulkan.cpp errors and the VK_KHR_surface line from the SMOKE and CAPTURE logs only when
  that run went through xvfb-run (NO_SURFACE=1). It does not drop them on a GPU desktop. Why: xvfb offers no
  Vulkan surface, so a container always fails the Vulkan context and Godot falls back to OpenGL 3. On Nich's GPU
  machine the same error means a real regression, and before cc815f5 the gate failed on it. (CLAUDE.md Quality bar
  (look at every capture; headless probes keep printing PROBE_END ok=true))
- **Python tool tests start bash found along PATH.** test_tools.py calls shutil.which("bash") once and passes that
  path to subprocess. A test that needs bash is skipped when none is on PATH. Why: Windows CreateProcess searches
  System32 before PATH, so a bare "bash" can start WSL's bash.exe on the build lead's PC and turn TOOL TESTS red
  for reasons unrelated to the code under test. (CLAUDE.md Environment notes (Nich's Windows PC, Git Bash, the
  python shim))

### Rendering and sprites

- **Sprite opacity is two passes.** Every character sprite shares one shader body
  (shaders/sprite_canvas.gdshaderinc) used by two passes. The cut-out pass (sprite_canvas.gdshader) cuts the
  sheet's edge with discard, never writes ALPHA, and stays opaque with depth and shadows; the engine's
  GeometryInstance3D.transparency still fades it. The fade pass (sprite_canvas_fade.gdshader) blends at (1 -
  transparency) * opacity and casts no shadow. ActorSprite.set_opacity below 1 selects the fade pass; 1 returns to
  the cut-out. No alpha scissor is used. Why: ALPHA = opacity together with ALPHA_SCISSOR_THRESHOLD 0.5 turned
  opacity into a step function and overrode every transparency tween. Ghosts at 0.45 vanished, a phased Sera at
  0.18 vanished, and dying enemies never faded. A single shader cannot be both opaque-with-shadows and blended.
  (Reference Bible 1.7 and 1.9 (hard alpha, one sprite material))
- **The canvas stack carries HDR past the grade.** The compute pass grades the picture clamped to linear 1.0,
  which round-trips exactly through its display-space conversion. It adds the light above 1.0 back after the
  grade, dimmed only by the VHS scanlines and vignette, and leaves that excess ungraded so fire keeps its colour
  in U1. Why: The display-space round trip capped every pixel at about 1.106 before the Environment glow
  (threshold 0.9), which flattened the embers, galaxy cracks and U6 neon that 2.3's single glow pass is meant to
  bloom. This amends 'One compute pass ... Equivalent output'. (Reference Bible 2.2-2.3; DECISIONS Rendering 'One
  compute pass')
- **A Chronoslip is staged, and the canvas rate snaps.** Over the 0.8 s slip the paper moves over 0.0-0.3 s and
  the grade over 0.2-0.6 s (smoothstep within each window). The grade covers saturation, inks, posterise, gold,
  line colour and amount, VHS, scanline and chroma. The frame rate switches to the new canvas at 0.5 s. The canvas
  always quantises at the rate of the universe holding the most frame-rate weight, never a weighted average. Hub
  leaks bleed into the grade and paper but never into the rate. Why: Reference 2.4 gives the three-stage table and
  'frame rate snaps'. The linear lerp of all fields drifted through fractional rates such as 36 or 42 fps. Section
  2.4 also says U0 stays home and props keep their source rate inside the hub. (Reference Bible 2.4)
- **Glow and SDFGI readings of 2.3 (environment unchanged).** The glow row's 'mix blend 0.35' is read as
  glow_bloom 0.35 under GLOW_BLEND_MODE_SOFTLIGHT (intensity 1.15, strength 0.85, HDR threshold 0.9). SDFGI stays
  off, section 10.5's low-end setting, until it is judged on a GPU capture and a quality option exists to toggle
  it at energy 0.2. Why: No GPU in the cloud container to judge SDFGI or a switch to GLOW_BLEND_MODE_MIX. The
  values are unchanged and only documented in hd2d_world.gd. (Reference Bible 2.3, 10.5)
- **The breakdown's section 12 settings, row by row.** Already adopted: debanding, physics interpolation, the 4096
  directional shadow map, 2D transform snap, the 30-degree explore pitch. Kept from the Reference Bible: the
  640x360 base (Reference 1.12, the pixel scale), the ACES tonemap (Reference 2.2: it keeps watercolour and gold
  leaf from blowing out on white paper; AgX/Filmic only after a side-by-side capture), and glow 1.15/0.85/0.35/0.9
  (Reference 2.3) rather than 0.3-0.6/0.05/1.0. Deferred until a GPU capture can judge them: the 4-split sun with
  shadow_blur, shadow_opacity and angular distance, volumetric fog, and the per-frame sprite snap to pixel_size
  (the right home is a render-side snap in ActorSprite). Why: Two documents, two directions; this records which
  one each row follows so agents stop tuning in opposite directions. (style breakdown section 12 (adopted by
  DECISIONS 'Direction'), Reference Bible 1.12, 2.2, 2.3)
- **Sprite density constants.** ActorSprite.PIXELS_PER_METRE is SceneKit.PX_PER_M (32). A sheet with
  height_px/height_m stands at its height. A sheet without one stands at 32 px/m if its cell is 96 or less (the
  recipe canvas) and at LEGACY_PIXELS_PER_METRE (64) if its cell is larger (the 128 px chibi sets and the 12
  generated NPC sheets). Painted stand-ins stay at 64 px/m. Generated placeholders are 64 px cells at 32 px/m
  (enemy placeholders 64/128/256). No shipped sprite changes on-screen size. Why: The Direction entry moves the
  world to 32 px/m, but the legacy sheets must keep their size until their 64 px replacements arrive. (DECISIONS
  'Direction'; Reference Bible 1.2)
- **Frames json keys the engine honours.** `rows` is the sheet's row order. The top-level `fps` is the sheet's
  canvas rate, used when the caller passes none; Location.add_npc and FieldNPC.make now default to 0, and a
  character's data canvas_fps still wins. An anim without its own fps steps at the resolved rate. A missing frames
  json warns once before the 70-column default table is used. An anim past the PNG's last column is cut or dropped
  with a warning. Why: ART_PIPELINE section 3 documented rows and fps as the contract, but the engine ignored both
  and fell back silently. (docs/ART_PIPELINE.md section 3)
- **The action tier's cell as shipped.** The action tier is a 128 px cell as shipped (crono_action: one idle
  column over eight rows, 120 px figure, 1.78 m). It is to be re-specified at the Direction scale. Amend 'A
  character is a set of sprites' from 'action (256, ...)' to 'action (128 as shipped; re-specified with
  Direction)'. ART_PIPELINE 1b now says so. Why: Two documents still said 256 while the data says 128; the next
  action request would be wrong by 2x. (DECISIONS 'Art comes from Nich; a character is a set of sprites';
  ART_PIPELINE 1b)
- **The truth-moment DOF mapping.** 2.3's 'DOF far 12.0' becomes a far blur starting 6 m behind the focus and
  ramping over 12 m (CombatConstants.DOF_FAR), with a near blur starting 2 m in front of the focus over 2 m and
  one blur amount of 0.08. The bible's near 0.05 has no separate setting, because Godot 4's
  CameraAttributesPractical has a single blur amount, so CombatConstants.DOF_NEAR has no reader. Why: Taken
  literally, far 12 m with the rig 15 m away would blur the subject itself. (Reference Bible 2.3)
- **Placeholder figure keeps the old metres at the new density.** An enemy placeholder's figure is cell_px * 0.8 *
  min(1, size / (cell_px / 64)) px at 32 px/m. That is 1.6 m per metre of `size`, capped at 0.8 of its 2/4/8 m
  quad, the same metres the 64 px/m code drew. Why: The 32 px/m move must not shrink or double any sprite on
  screen (cluster notes; DECISIONS 'Direction'). 81 of 82 enemies draw as placeholders. (DECISIONS 'Direction' (32
  px per metre); REFERENCE_BIBLE §1.13)
- **One body opacity for un-phase and revive.** CombatActor.body_opacity() is Sera's Debt opacity (1 - 0.005 per
  point, never below 0.5), and 1.0 for every other body. Un-phasing and restore_body return a body to it instead
  of to 1.0. Why: Opacity now really fades (WORLD-1), so the old reset to 1.0 made Sera visibly pop back to solid.
  Story Bible §4.2 says her body thins with her Debt. (STORY_BIBLE §4.2 'Look'; COMBAT_LAWS_BIBLE Translucency
  Debt)

### Acceptance tests

- **Rewind's turn start.** Rewind restores the target to the snapshot taken when its turn began. For an ally that
  is its window, with the gauge at the gate (99); for an enemy, the start of its turn, before the gauge resets. So
  a Rewound ally's turn comes round again, and a parked ally keeps its 99 and its Ready Pool place (rewind_unit's
  ready_pool branch is the same value). suite_acceptance pins this. Why: It is the literal reading of the bible's
  'state at its own last turn start: HP, gauge and position'. Changing the snapshot moment would also move Time
  Mines' ghosts and the auto-battler's 'rewindable' test, which is too wide for a test cluster. A question for
  Nich records the balance and Shard Doll concern. (COMBAT_LAWS_BIBLE §3.6, §10.2 (Rewind), §18.7 #14)
- **CastReach: the preview reaches what the cast reaches.** scripts/combat/cast_reach.gd is read by both
  BattleCoordinator.preview and _resolve_action. It answers: whether a cast strikes at all (TechEffects.STRIKING
  for bespoke handlers, EffectSteps.resolve_mode for rows, the support path otherwise); the partners' extra
  origins; the handler's target filter; the row's pre ops (hits, beams); and after-effect plates (shave_any,
  auto_break 'smallest', Eclipse's crossing plate, struck with the body's first weakness as the handler does). A
  cast that strikes nothing returns an empty preview, so its plates show no change. preview() takes optional
  partners; BattleScene passes them. Why: Acceptance #23 requires preview equal to resolution for every technique
  and shape. The every-technique sweep found 36 mismatches across 14 techniques; all now agree.
  battle_coordinator.gd went from 1624 to 1623 lines, because the extra-origin code moved out. (COMBAT_LAWS_BIBLE
  §4.6, §11 (Eclipse X-Strike, Ferro Null, Chrono Laugh, Overclocked Short-Circuit, Delta Storm), §18.7 #23)
- **Fixture techniques come from data.** tests/suite_base.gd _lib() returns Data.techs[id] for LIB_IDS (eight
  techniques) instead of hand-copied dicts. Why: A retune of those rows is then what the core battle tests
  exercise (DATA-22). The values matched apart from astral_slash.lv3_field and hold.requires_broken, and no test
  depended on their absence. (COMBAT_LAWS_BIBLE §18.7 (automate in the headless runner))

### Corrections to earlier entries

- **The action tier is a 128 px cell.** The "set of sprites" entry above says action (256, realistic 5.5-head);
  the action sheet that ships (`crono_action`) is a 128 px cell with a 120 px figure, one idle column over eight
  rows (ART_PIPELINE 1b). The 256 px sets the asset team built stay unimported under the Direction entry.
- **Hand-off numbers.** The unit suite is split into per-area suites under `tests/` (`suite_base.gd` holds the
  helpers; `run_tests.gd` discovers every `suite_*.gd`), and `tools/check.sh` runs the three headless probes and
  the Python tool tests on every check. PROGRESS carries the current counts; other documents should not repeat
  them.
- **The two reference documents live under design/.** `design/STYLE_BREAKDOWN_2026-11-01.md` (the text layer of
  Nich's Nov 1 PDF, adopted by the Direction entry) and `design/COMBAT_ARCHITECTURE_HYBRID.md` (the architecture
  note the Combat Laws grew from, reference only) are in the repository, and design/AUDIT.md's source table names
  them with the uploaded Chrono Apocrypha Master Design Bible (an earlier Story Bible whose differences are
  settled in the audit report's APOC rows). Why: the hand-off rule; the Direction entry cited a document that was
  not in the repository.
- **Active party stays at four.** Up to four characters on the plane and the rest on the Bench (Combat Laws 3.1),
  as the code and `BattleRoster` are built. The Reference Bible's "three" and the breakdown's three-column ATB
  table are presentation notes, not a rule; AUDIT.md lets the Combat Laws numbers win on combat.
- **The title footer and the project description no longer call the game a sequel.** The working title stays until
  Nich picks a release title (breakdown section 14; QUESTIONS_FOR_NICH).

### Final integration review

After the fifteen clusters, two review rounds looked at how their changes fit together: six angles (battle seams,
combat rules, a whole run, what the player sees, the harness, code health), every finding refuted by a second
agent and reproduced where it mattered, then fixed one group at a time (commits f5e18e9 to ac990dc). Two
pre-existing critical defects came out of it: battle input was ignored during every story battle (the gate's
probes all use --autobattle), and the party could be placed past the kitchen floor after a zone battle. The calls
those fixes made:

#### Battle seams (round one)

- **Enemy Ruin clears in the restore, not in end_battle.** restore_enemy clears Ruin and the statuses before it
  refills the vitals. StatusRules.end_battle still clears Ruin only for the party, the bench and hover Sera. Why:
  restore_enemy is the only path where an enemy body outlives its battle (zone survivors), and §16.5's 'full
  strength' is its job. Clearing the statuses first keeps reset_vitals reading the base ceiling. Enemy bodies that
  are not kept are freed, so clearing their Ruin at end_battle as well would be a second rule for the same thing.
  (COMBAT_LAWS §16.5; DECISIONS "Enemies after a battle", "Ruin is battle-scoped")
- **A spared enemy's statuses still run out, but nothing ticks on it.** StatusTicks ignores periodic emissions for
  units the coordinator no longer counts (c._alive). StatusComponent timers keep counting down, so a status still
  expires and runs its undo. Why: §4.2: the spared enemy is 'removed from the fight alive'. This matches d454087,
  which stopped its Break from ticking, and FieldEffects._living. Stopping the timers too would change expiry and
  undo timing for KO'd party members, who are also not _alive.
- **One end_wind_up helper on the coordinator.** Every way a wind-up ends goes through
  BattleCoordinator.end_wind_up(e): resolution, Break, KO, spare, HZ, Omega Annihilation, Rewind Reel and a boss
  phase change. Nothing else erases a wind-up entry or emits telegraph_ended. BossController's phase change now
  emits only when the boss was actually winding up. That changes no behaviour, because a decal exists only while a
  wind_ups entry does. Why: Five call sites erased the entry and emitted the signal by hand, and the KO path had
  no such call. One helper means a new way out of the fight cannot forget the decal. (COMBAT_LAWS §3.5)
- **Boss drops are paid by RewardResolver at victory; on_defeat stays at the fall.** RewardResolver.award_drops
  pays the boss's drops at victory, from its phase EnemyDef, which carries the boss file's drops. Game.note_drop
  now also records the boss key. The director's on_defeat still runs when the boss falls or end_fight is called,
  so it can play the message, the gold-leaf teardown and the Shard Doll's counters. Why: DECISIONS "Rewards: XP,
  drops and leans at victory" says a defeat pays nothing, and a story retry loop must not pay twice. Paying in
  resolve() also puts the boss's drops in the victory summary. on_defeat is the presentation of the fall. The only
  director bookkeeping in it today is in the Shard Doll's fight, which cannot be lost. (DECISIONS "Rewards: XP,
  drops and leans at victory"; COMBAT_LAWS §15.2)
- **Summoned adds are scaled from the summoner's encounter.** A regular or elite add, called or split from a body
  that EffectiveRank scaled, is built with EffectiveRank.create using that encounter's hazard, so it gets its own
  ERL and the Time Shear rule. The level is not inherited as an offset from the summoner. Boss, mini-boss and
  pinned-row summoners, and regular adds of a boss, keep their adds at the authored level. Why: Inheriting the
  summoner's offset gives the wrong level when the 'band minimum - 2' floor applies. Example: a Lv-1 party in U8
  gets the guardian floored to 69 (offset -6), so its Atom-Eaters would come out at 65 while the encounter's own
  rows are 69. Building the add from the same ERL formula keeps it level with the encounter's rows. (COMBAT_LAWS
  §15.3; DECISIONS "Effective Rank Level")

#### Combat rules (round one)

- **The preview's damage.** BattleCoordinator.preview estimates damage with PartyHit.estimate. For each strike it
  aims at, estimate sums DamagePipeline.compute_hit over PartyHit.terms, which the resolution's PartyHit.context
  also uses. Variance is 1.0, there is no chance crit (oil drinker), nothing is spent and the RNG is not touched.
  Exposed is counted per strike: strike i ignores DEF while the target has more than i stacks. A shield-only body
  previews 0 until it Breaks. Two things are not forecast: the mercury pool's +20% on the first FERRO hit
  (FieldEffects.on_party_strike has side effects) and a Break that lands mid-action (the preview reads the target
  as it stands). PartyHit.action_keys is the one builder of an action's damage keys for cmd_attack, cmd_tech and
  the preview. This closes the 'Party-only ledge term' gap on the preview side: the preview now includes the
  ledge. The DECISIONS line that names _estimate_damage should be updated; EnemyStrike still has no ledge term.
  Why: The aim line should read what the hit deals (bible: the preview shows 'the exact shave and damage each will
  take'). One shared builder stops the two paths drifting again. (COMBAT_LAWS_BIBLE §4.5, §4.6, §6.2-§6.4, §8.7,
  §8.8, §18.7 #23)
- **Knock-Static is read when the action is chosen.** EnemyBrain.choose records Knock-Static as action.stepped
  before the turn's countdown, and the wind-up adds its 0.5 s hitch from that snapshot. A 2-turn Knock-Static
  hitches two enemy actions; a boss's halved 1 turn hitches one. Magnetized and Gramophone Resonance's hitched
  stay 'next action' statuses read after the countdown (turns 2 = one action, as DECISIONS 'Readings chosen'
  sets). Why: The bible says Knock-Static means every action hitches 0.5 s for 2 turns. Read after the countdown,
  it covered one action, and a boss's halved status never hitched at all. This extends the existing rule 'Statuses
  that act during an enemy action are read when the action is chosen' (refracted, probability_lock, GUILTY) to
  Knock-Static. (COMBAT_LAWS_BIBLE §12.1, §12.2 (Knock-Static row), §11 Red Bike Ghost)
- **One steal per Glenn action across many bodies.** An effect-table steal op takes one steal per action, sized as
  before (by_boost or n, giving GLENN_STEAL 1/2/3 BP). It draws from the units of `on` in order, counter first and
  then the laugh, until that size is filled. Guilt Halo ('Steals 1 BP on a Break') therefore takes 1 BP however
  many bodies Break. Only a steal_all_when_broken Break (the Ash Ringmaster) gives more. Why: §7.5 says one steal
  per Glenn action, and #22 says never more than 3 BP per action. Under the per-body loop, one Guilt Halo into
  five weakened adds took 5 BP. Capping at the action's own steal size, not at a flat 3, is the literal reading of
  §7.5 and also satisfies #22. (COMBAT_LAWS_BIBLE §7.5, §11 guilt_halo, §18.7 #22)
- **Silence on enemies.** A Silenced enemy's named actions are all sealed: EnemyBrain makes it a plain weapon-tag
  Attack with no wind-up until Silence ends. StatusComponent.outgoing_multiplier was removed as dead code;
  Refracted is read from the snapshot taken when the action is chosen. Why: §12 defines Silence as 'Techniques
  sealed; Attack, Guard, Items and commands still work'. The Divinity Break's 15 s silence had no reader on the
  enemy path. (COMBAT_LAWS_BIBLE §12 (Silence), §12.5 (Divinity Field))

#### Battle input and rules

- **A story battle has the player's input.** Story.blocks_battle_input() is true while a script is running, except
  when the innermost running script is the one waiting on its own `battle` command. A phase beat or branch nested
  in the fight still blocks, as does input_blocked. Battle input and the deck-recovery guard read this, not
  Story.is_running(). Why: Every story fight (Cradle, Shard Doll, Chapter 2) was soft-locked at its first party
  window. The waiting script owns how the fight ends, not the screen during it. (Combat Laws §3-§4 (decision
  windows); DECISIONS Code-audit fixes second pass, Story runner)
- **Battle placement stands the party on the ground.** PartyPlacement fans the party on the Location's
  WalkableGround. Order: the near side (+Z) at 4.5 m, then at 3.0 m, then the fan turned ±45, ±90, ±135 and 180°
  until every anchor is standable. Failing all of those, each member walks out from the centre to the last floor.
  Enemies face the party's side. After any outcome, regroup puts a leader the ground cannot hold back where it
  stood before the battle. Why: The kitchen's three zones sit within 3 m of a south edge or wall, so the fixed +Z
  fan put everyone over the void and a win dropped the party forever. §2.1 says the plane conforms to the terrain.
  (Combat Laws §2.1; DECISIONS Withdraw / After a battle)
- **DoT tick base is one hit's §6.4 raw.** tick = max(1, round(15% × raw)), with raw = max(1, 0.8 × (atk −
  def_used/2)) before power, crit, weakness, vulnerability or variance. Enemy path: that hit's raw. Party
  effect-table `dot` path: the raw of the action's last landed strike on that body, at Broken DEF if that strike
  hit it Broken. A caught but unstruck body uses the best caster's raw against it. Why: §6.3 and the §6.5 #3
  example (raw 81.2 gives a tick of 12). The party path stored 15% of the whole action (Solar Railgun ticked about
  400), and the enemy path stored 15% of the final hit. (Combat Laws §6.3, §6.4, §6.5 #3; DECISIONS DoT ticks and
  regen)
- **Taunts count from the bearer's next action.** TauntBook entries given during the bearer's own action are fresh
  and are not counted down by that action, matching Turn statuses. Bekkler's Guilt is now the §11 ring and does
  not draw attacks: a hit aimed at another ally within 4 m × Boost scale lands on Crono at 75% and gives +1 BP, 2
  at most, until his next action. Shogun's Command draws 60% of attacks for 2 of Krona's turns. If she is still
  standing when it runs out, every ally gets ruin_infused through StatusRules, and it lasts until spent. Why: The
  casting action erased Bekkler's Guilt before any enemy acted and halved Shogun's Command. Its payoff and
  guilt_redirect had no reader. (Combat Laws §11 tech table (bekkler_guilt, shoguns_command); DECISIONS Turn
  statuses)
- **Ruin-infused is the bearer's next landed strike.** PartyHit.terms sets DEF to 0 for the infused striker's
  first strike, and PartyHit.context removes the status on the strike that lands. The preview gives the bonus to
  the first strike it forecasts (the first body in resolution order) and marks it spent, so later hits and later
  bodies read full DEF in both the preview and the resolution. Why: §12.3 says 'the next hit ignores DEF'. Reading
  it as one strike keeps the preview and the resolution consistent, which is the f5e18e9 rule. (Combat Laws §12.3)
- **Mercury Pulse: one circle, boss rules, Centaur reach.** CastReach.radius(tech) is tech.radius + 1.0 for
  Mercury Pulse unless R66Y:Salvaged; Centaur is her default form. cmd_tech, the preview and the aim outline use
  it. The pulse uncloaks, reveals, slows (StatusRules, 4 s, halved on bosses) and magnetizes exactly the bodies
  its own circle reaches, including cloaked ones. Why: The handler called StatusComponent.add directly, skipping
  the boss halving. It also always added +1.0 to the status radius only, so bodies 6-7 m away were slowed but not
  struck or previewed. (Combat Laws §10 (Cassia-09 forms), §11 mercury_pulse; DECISIONS Boss status rules count
  Mercury SLOW as SLOW)
- **Rewind takes back Ruin gained since the turn start.** The turn snapshot records Ruin stacks. Rewind thaws the
  stacks gained since, through RuinRules, for every battler: Crono's TimeDebtComponent and his mirror together. It
  does this before restoring HP, so the HP returns against the whole ceiling. Why: Rewind already dropped another
  ally's new Ruin but left Crono's, desyncing his mirror. The bible's Rewind restores 'statuses gained since', and
  one rule for every battler fixes the split. (Combat Laws §3.6, §10 Rewind, §12.2 Ruin)
- **An Attack's preview never takes Dual partners.** coordinator.preview ignores partners when tech is null, and
  the deck's Attack clears partners left from a cancelled Dual. Why: cmd_attack strikes with the actor alone, so
  the aim line must read the same. (Combat Laws §4.5-§4.6 (the preview reads what the hit deals))

#### A whole run: story, world and saves

- **Lines and captions are drawn above the transition fade.** The Story CanvasLayer is 110 (StoryRunner.LAYER),
  above Router.FADE_LAYER (100). If a caption is the first command of a script, the box is shown without its
  panel. Router.fade_out emits fading_out; a line the player has already read (no prompt or choice waiting) is
  cleared then. A line still waiting and a caption stay up over the black. Why: DECISIONS 'A location may hold its
  opening black' wants the wake's lines on a black screen. With the box under the fade, a by-hand New Game sat on
  an invisible prompt, and opening captions were never drawn because the box was still hidden. Clearing read lines
  stops the box (now above the fade) from leaving the last line up through every scene change. (REFERENCE_BIBLE
  §7.6 (dialogue box); STORY_BIBLE Prologue wake and Ch1 time skip; DECISIONS 'A location may hold its opening
  black')
- **Captures and debug starts never write the player's files.** smoke.gd suspends Saves and render.sh passes
  --no-save. In boot.gd, any state argument (--scene/--location other than the title, --spawn, --checkpoint,
  --party, --level, --chapter, --integrity, --flag) puts saves and settings in scratch. A new --save argument opts
  back into the player's files. README should list --save under boot arguments and note the --no-save in
  render.sh. Why: 'Headless runs never touch the player's files' covered only the probes and the test runner. A
  location capture or a debug start that reached an autosave overwrote Nich's slot_00 with made-up state.
  (DECISIONS 'Headless runs never touch the player's files' (extended))
- **Arriving at the flatline starts the Atrium Siege.** Location._ready calls AtriumSiege.begin_if_owed. A save
  made while the siege is owed keeps integrity 0; saves are not deferred. Continuing that save runs the siege when
  the player arrives. Why: Deferring or skipping saves could lose a save the player meant to make. Starting the
  siege on arrival also repairs any other route into a 0-integrity state, including older saves. Acceptance check
  25 and Ending 5's counter then hold after Continue. (COMBAT_LAWS §16.3, §18.7 #25; DECISIONS 'The Atrium Siege,
  first cut')
- **Time Debt Seal is taught at breakfast; a tech the story teaches mid-chapter carries the next chapter as its
  kit unlock.** prologue.json robo_relay teaches crono time_debt_seal right after the 'TIME DEBT' caption,
  silently, with no new text. Sera's kit entry for fall_break is now {chapter: 1}. Cradle phase 2's `learn` still
  teaches it in the Prologue, and data/techs keeps the bible's 'Prologue' unlock for reference. The general rule:
  a kit entry's chapter is the latest chapter start by which the tech is known. A tech the story teaches partway
  through a chapter is keyed to the next chapter, so a debug start at a chapter's beginning holds exactly what a
  real party holds there. README and DECISIONS 'A debug start learns its chapter's kit' should drop Fall Break
  from the chapter-0 debug kit. Why: STORY_BIBLE lists Time Debt Seal as a Prologue tech ('he uses it here'), but
  nothing in the Prologue taught it. battle_probe's chapter-0 kit also gave Sera Fall Break from phase 1, which a
  real player only gets in phase 2. DECISIONS says probes must fight with the kit a real party has. (STORY_BIBLE
  Prologue 'Rewards and techs'; COMBAT_LAWS §11 Unlock column; DECISIONS 'Kit unlocks', 'A debug start learns its
  chapter's kit (BootArgs)')
- **One scratch directory per process.** A suspended run writes to user://scratch/<pid> (ScratchDir). It is
  emptied on first use and removed when the run exits. A pid directory where nothing has changed for 7 days is
  pruned. Liveness checks are not used, because OS.is_process_running only knows the process's own children. The
  flat user://scratch/saves of older builds is left alone, since one of them may still be running. Why: Every
  probe and test run on one machine shared one autosave, so concurrent gates (worktrees, the build lead next to
  the studio assistant) could fail ch1_probe or suite_locations at random. (DECISIONS 'Headless runs never touch
  the player's files'; CLAUDE.md quality bar (probes keep printing PROBE_END ok=true))
- **Version 1 saves rename retired flag ids.** Saves.RETIRED_FLAGS_V1 maps Glenn_Duals_Offered to
  Glenn_Duals:Granted and Glenn_Duals_Refused to Glenn_Duals:Refused when a v1 save loads; if the new id is
  already set it keeps its state. Unknown flag ids are not dropped on load, because test flags and boot --flag ids
  are legitimately undefined and a blanket drop could lose state. A future rename adds its own entry with the
  version that retires it. Why: A v1 Chapter 1 save where Glenn refused played his 'offered' line, and the verdict
  could never be recorded again because Glenn_Honour_Checked skips the honour check. (DECISIONS 'Save files are
  atomic and versioned'; STORY_BIBLE §9.3 Glenn_Duals)

#### What the player sees

- **One owner of the body look; the phase wins over every redraw.** CombatActor.apply_body_look is now the only
  place that sets a body's standing opacity and tint. A phased Sera is always drawn at 0.18 in gold, after a hit,
  a DoT tick or a revive. A Sera who is KO'd and revived while still phased comes back phased-looking, because the
  rules leave her phased: a KO does not clear phased_turns_left, and she stays untargetable until her phased turns
  pass. A Debt redraw (set_porcelain_visuals) leaves the tint alone unless she is phased, so a cutscene's grey
  tint survives it. Why: The look must match what the coordinator does. Changing the rules (ending the phase on a
  KO) was outside this finding. (COMBAT_LAWS_BIBLE §10.2 (phase-out); STORY_BIBLE §4.2 'Look'; amends DECISIONS
  'One body opacity for un-phase and revive')
- **Ground overlays sort before sprites.** The battle plane material uses render_priority -2 and the telegraph/AoE
  decals use -1. Sprites stay at 0. The constants live in BattleFx (PLANE_RENDER_PRIORITY, DECAL_RENDER_PRIORITY).
  Why: The fade pass writes no depth, so a centre-sorted ground quad drawn after a faded body blends over it.
  Ground overlays should always be under the bodies standing on them. (REFERENCE_BIBLE §1.13; COMBAT_LAWS_BIBLE
  §2.1 (battle plane), §8.5 (telegraphs); DECISIONS 'Sprite opacity is two passes')
- **The gate's battle capture is timed from battle_started, at 20 Debt.** smoke.gd
  --capture_after=<signal>:<seconds> (plus --max_frames) saves <prefix>_<signal>.png and fails the run if the
  signal never fires. check.sh shoots the arena 1 s after battle_started with a new boot argument, --debt=20, so
  the shot is check_test_arena_battle_started.png. It shows the HUD, the plates, the plane and Sera's fade pass on
  any host speed. The lineup capture is unchanged. check.sh now says xvfb's OpenGL 3 fallback never renders the
  compositor. Why: A fixed frame landed on the walk on a GPU and on the empty field after victory under xvfb, so
  the gate never looked at a battle or a faded sprite. (CLAUDE.md quality bar (look at every capture); DECISIONS
  on the check.sh visual step)
- **Cast bodies follow Game's ledger in the field.** A Story debt or integrity command, or the gate toll, now
  syncs and redraws the party and the cast (npc_actors CombatActors) through BattleAftermath.follow_game. During a
  battle only the values sync. Every create_party_member spawn applies its porcelain look. Why: A body's Debt and
  cracks should show the moment the ledger moves, not at the next hit. The battle redraws its own bodies, so the
  field redraw is guarded by not _in_battle. (STORY_BIBLE §4.2 'Look'; DECISIONS 'Sera's Debt is drawn on her
  sprite')

#### Whether green means what it says

- **The parry key.** The `parry` action (G / joypad 4) is read only while the battle clock runs (TICK, not
  paused). One press arms the Ens Parry of every guarding living ally that an active enemy wind-up targets. If no
  wind-up targets a guard, or any wind-up is an area (non-SINGLE) shape, it arms every guard. An ally who is not
  guarding is never armed. Each ally's press is then spent for ENS_PARRY_RECOVER_S = 0.5 s of battle time (30
  frames), and a press never reopens a window that is already open. The logic is in scripts/combat/ens_parry.gd
  (EnsParry); BattleScene keeps one per battle. Why: DECISIONS 'Ens Parry is armed' made the parry a player press,
  but nothing read the key. With one key and several guards, arming only the guards a hit is aimed at keeps the U1
  ink-blot penalty off guards no hit was coming for. A press with no hit due still opens a window, so the bible's
  'pressing outside the window against U1 ink enemies throws an ink blot' holds. Without the 0.5 s recovery,
  mashing at about 10 Hz would keep a 4-8 frame window open most of the time, and the timing skill the bible
  describes would mean nothing. (COMBAT_LAWS_BIBLE §4.2 (Guard, Ens Parry); DECISIONS 'Ens Parry is "armed"')
- **The test runner counts SCRIPT ERRORs and the gate fails on them and on exit leaks.** tests/run_tests.gd
  installs an OS Logger (tests/script_error_log.gd). A test that raised a SCRIPT ERROR fails by name, and any
  SCRIPT ERROR fails the run. A suite that does not parse is a failed suite. The 'ran no checks' guard counts
  failures only, so totals drop from 3693 to 3392 (they no longer include one guard pass per test). check.sh fails
  the unit-test step on SCRIPT ERROR or 'leaked at exit' / 'still in use at exit', and a probe on any SCRIPT
  ERROR. Before quit the runner stops all audio players and waits 0.5 s so audio playbacks still mixing are not
  reported as leaks. run_tests.gd takes --suites=<dir>, and check.sh honours CHECK_LOG_DIR. Why: A runtime error
  part way through a test ended it silently and the gate stayed green (H2). The exit leak line was printed on
  every run and never read (H6). Today's log has neither, so making them fatal costs nothing. The only leaks left
  were audio playbacks still mixing at quit, which varied by timing, so they are drained rather than allowlisted.
  (CLAUDE.md quality bar (probes print PROBE_END ok=true; verified/untested/broken); DECISIONS 'Tooling and
  harness')
- **Captures play on the default options.** check.sh passes --no-save to its smoke boot and captures, and smoke.gd
  calls Game.reset_settings(), so no capture reads the player's settings.cfg. Why: Game._ready adopts the settings
  file before smoke.gd's code runs, so the gate's captures used Nich's flow_speed and reduced_flicker and differed
  from machine to machine (H7). This extends DECISIONS 'Headless runs never touch the player's files' to the
  visual steps. (DECISIONS 'Headless runs never touch the player's files')

#### Code health

- **Per-battle marks are cleared at battle start and on restore, not in init_unit.** BattleMarks.PER_BATTLE is the
  list of battle-long Node metas. start_battle clears them on every body it is given, and
  BattleAftermath.restore_enemy clears them on a zone survivor. Sunlight Stacks, Static's tuning and Xyloph's
  tether nodes count as battle-scoped. Why: The bodies outlive a battle (Location reuses its party; zones keep
  their survivors). init_unit also runs for a mid-battle swap-in, and clearing there would let Crono use the Seal
  a second time in one battle by swapping out and back in. (COMBAT_LAWS §11 time_debt_seal (once per battle),
  §10.1 Wire Loom Mend (+0.6 once per battle), §12.3 Concerned (once per battle), Tune 'for the battle')
- **Krona's Corruption is a component ledger like Debt and integrity.** CorruptionComponent on Krona's body is
  seeded from Game, followed by Game during a battle, and written back afterwards. The 50/100 thresholds, the
  Goyama clear and Oil-Drinker+ are not built; they are listed under effects.json handler_unbuilt.oil_drinker. The
  dead oil_drinker_plus crit check is removed until a beat earns the passive. Why: The bible makes Corruption
  persistent save data. No flag exists for the U2 ruthless road yet. (COMBAT_LAWS §10.3, §18.5 save data)
- **A bare flag write means the state 'set' everywhere outside dialogue too.** The effect table's `flag` op and a
  boss branch option with no state write Name:set (Flags.set_ref / FlagRef.written). Validators check a write as
  the exact state it writes, and a read as written (bare means any state). Why: This is dialogue's existing
  set_flag rule. Before, the effect op silently wrote nothing for a bare name. (DECISIONS 'One flag spelling';
  STORY_BIBLE §9.3)
- **A pending effect is never castable; a handler's unbuilt clauses get their own listing.** A technique whose
  effect is under effects.json `pending` is not offered and its preview strikes nothing. Miura Fold moved there,
  because its shared HP pool needs a damage hook that no strike path has. A new `handler_unbuilt` group lists the
  clauses a bespoke handler does not run yet (Honest Laugh's honest GUILE hit, since no honesty rule exists;
  Balloon Escape's squash; Oil-Drinker+). The lint prints both lists. Why: Otherwise a pending effect would
  resolve as a plain strike or heal, and the lint counted half-built handlers as done. (COMBAT_LAWS §11
  (miura_fold, honest_laugh, balloon_escape), §10.3)
- **Balloon Escape: one foiled theft per cast, and a FIRE hit on the balloon is a miss.** The cast sets
  theft_immune_once on the caster. The next enemy bp_steal against the party drains nothing and spends that mark.
  While the 2 s balloon status lasts, every enemy hit tagged [FIRE] on that body resolves as evaded (shown as
  'miss'). Why: This follows the bible's 'the next BP theft against the party this battle fails, immune to [FIRE]
  for 2 s'. The 4 px squash is presentation. (COMBAT_LAWS §11 balloon_escape, §7.5)
- **Summoned adds stand on the room's ground and face the party's side.** Each ring spot is tried at 8 angles
  around the summoner; if none is standable, the add takes the summoner's own spot. Adds face center + party_side
  * 4. Why: A Cradle shardling could appear inside the hall pillar, and rooms where PartyPlacement turns the fan
  would have adds facing away from the party. (COMBAT_LAWS §2.1; DECISIONS 'One summon rule', 'Withdraw')
- **The coordinator is a coordinator: 815 lines, rules in static classes, no private access from outside.** The
  coordinator keeps the lifecycle, the timeline, the command entry points, the queries and the bookkeeping.
  Resolution, costs, availability, preview, rewind, enemy turns, the gate pick, parry, Oil-Blight and the damage
  terms moved out. A suite_acceptance guard fails if any script names one of its underscore members. Why: It was
  2.7 times the ~600-line rule, and 22 files used its private API, which the parser does not check. At 815 lines
  it is still above the rule; splitting the timeline further (for example into a BattleClock) would be the next
  step. (CLAUDE.md working agreement (scripts under ~600 lines, one class per file))
- **One music stem list, one image sidecar writer.** AudioDirector.MUSIC_STEMS is the list play_music,
  DialogueCheck and lint all read. tools/common/import_sidecar.py writes every sheet and texture .import, keeping
  a canonical uid and re-minting one Godot cannot parse. Why: There were two hand-kept stem lists, and lint
  accepted any stem. The two writer bodies were identical except for their docstrings. (REFERENCE_BIBLE §8.2;
  docs/ART_PIPELINE.md §1b)

- **Bekkler's Guilt turns the whole action.** An enemy action's effect (time stop, grief, fog blind and the rest)
  follows its hits to where they landed, so a hit the ring turns onto Crono brings its effect with it. Why: the ring
  already turned the damage and the action's own status; leaving the effect on the guarded ally split one attack in
  two (COMBAT_LAWS §11, Bekkler's Guilt).
