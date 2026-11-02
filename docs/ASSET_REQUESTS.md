# Asset requests for Nich's asset team

Nich makes the art decisions; his asset team generates in the shared PixelLab account. Each entry below is a
ready-to-send PixelLab request at the scale of DECISIONS "Direction: the Nov 1 recipe is the style"
(2026-11-02). Delivery tracking lives in Linear "Time Debt - Asset Pipeline" (one issue per asset), Dropbox
"TRIGGER Time Debt" and Slack `#all-trigger`; the contract is `docs/BOT_REVIEW.md`, and this file is the request
text. The build lead imports finished items per `docs/ART_PIPELINE.md` §2 and §5 and moves the entry to
**Done** with the PixelLab id and date. Keep the list in priority order: the Follow-ups come first, then the
first undone entry is the most urgent. Asset keys are the game's ids and never change; the prompts describe
the design without naming it (see "Prompt hygiene").

## Follow-ups (first)

Five fixes to the 2026-11-02 prop delivery (BOT_REVIEW audit log) and the next anchors. Props are
`create_1_direction_object`, `view="low top-down"`, transparent, canvas = `height_m × 32` rounded up to a
multiple of 32, the U0 project palette (`palette` = `source_art/style_kit/palette_resurrect_64.hex`) unless the
canvas says otherwise; declared in `data/props/props.json` before import.

| # | Asset key | Request |
|---|---|---|
| F1 | `prp_u0_clock_pillar_face` v2 (TRI-63) | **Object, 128x128, 3.2 m, U0.** A flat clock dial for the Atrium pillar (the face is a 3.2 m disc 7.8 m up the pillar in `atrium_horologe.gd`), seen straight on. Prompt: `a round porcelain clock face with a brass bezel and fine black hour marks, no hands, a hairline crack across the glass, flat and face-on`. Hands are left off: the engine moves them. The delivered v1 (a whole clocktower spire, 9 m) stays as the Truce skyline landmark under the same key's history. |
| F2 | `prp_u0_pool_disc` (new key; TRI-69 was the rim) | **Object, 128x128, 3.8 m across (rim radius 1.9 m in `atrium_horologe.gd`), U0, top-down.** `view="high top-down"`. Prompt: `a round shallow reflecting pool seen from directly above, a low porcelain rim with brass inlay, still dark water with one faint ripple ring, flat`. Replaces `prp_u0_pool_rim` (one front arc, unusable); the Atrium keeps its primitive pool until this lands. |
| F3 | `prp_u1_dojo_set_rusted_katana` v2 (TRI-43) | **Object, 64x32 (wide), 0.2 m tall, U1 four inks.** Prompt: `a rusted katana lying flat on an oil-stained cloth, seen from the low top-down camera, the blade along the cloth, dry-brush edges`. v1 stands upright. |
| F4 | `prp_u0_doan_tree_sprout`, `prp_u0_doan_tree_sapling`, `prp_u0_doan_tree_ash` (TRI-77 delivered the seed only, kept as `prp_u0_doan_tree_stages`) | **Three objects, U0:** sprout 32x32 (0.4 m) `a pale green sprout with two leaves in a crack of dark earth`; sapling 64x64 (1.6 m) `a slender young tree with a silver-green crown and a single gold leaf`; ash 64x64 (1.6 m) `the same young tree burned to a black skeleton, a thread of smoke, one gold leaf left`. Same palette and light as the seed. |
| F5 | `prp_u0_klein_journal` (TRI-72) | **The issue lists icon / field / pages variants but no PixelLab id.** Deliver the id of the field object (32x32, 0.25 m, `a thick leather journal closed with a brass clasp, a loose page sticking out`) and the icon (16x16, same journal); the pages are a UI texture (Batch 8). The prop is declared `pending` and stands in as a labelled box until then. |
| F6 | `crono` remaining clips, then `sera`, `krona`, `marle` 64 px anchors | On "TRIGGER Anchor Crono 64 v1" (`ca2300bc-7592-4606-8973-32b9bc00056b`; idle + walk imported): queue `running-6-frames`, `taking-punch`, `fight-stance-idle-8-frames`, `falling-back-death`, `getting-up`, `fireball`, `picking-up`, attack v3 8 frames (`a fast one-handed katana slash from the right side, the brass gauntlet leading, a faint rainbow arc off the blade`), charge v3 4 frames loop (`crouched draw stance, the katana held back, faint clock-wisps gathering`), victory v3 8 frames (`lowers the katana, exhales, rests the gauntlet hand on the hip`). Then, once Nich has approved the anchor and the palette, the same recipe for Sera, Krona and Marle (Batch 1 #1–#3), delivered as `px64` variants. |

## Style gate (read before sending anything in volume)

The breakdown's production plan has four gates and the first two are open. **Phase 1, the style bible:** one
palette, one approved south-facing hero anchor, three test tiles, one battle effect, frozen. The kit exists
(`source_art/style_kit/`, `docs/screenshots/20_style_bible_kit_review.jpg`: sixteen 64x64 anchor candidates in
Resurrect 64, three Wang test tilesets, a 9-slice window frame, an impact burst) and candidate 0 has been rotated
to eight directions as the working anchor (`22_anchor_crono_px64_lineup.jpg`); **Nich has not yet picked the
candidate or confirmed the palette** (QUESTIONS_FOR_NICH "Style bible, Phase 1"). **Phase 2, the slice:** hero
plus one partner with field and battle sets, six NPCs, four enemies and one boss, two characters' portraits, one
exterior Wang set and one interior kit, three techs and one gate effect, one window theme; nothing in volume
starts until a stranger can play it and the sprites stay crisp. Until Phase 1 closes, send only the Follow-ups
and nothing that depends on the anchor; until Phase 2 closes, send only the slice rows (Batch 1 #0–#1 and #8,
Batch 2 #9–#12, Batch 3 #20, Batch 5 for `crono` and `sera`, Batch 8's frame); the rest is "after gate 2". The
asset team's existing 128/256 px "field v3" sets are superseded and are not imported (BOT_REVIEW audit log).

## How to send one (the 64 px recipe; the full contract is ART_PIPELINE §1)

- **Characters** (anything that walks). Three calls: (1) `create_image_pro`, 64x64, `palette` = the project
  palette hex list (`source_art/style_kit/palette_resurrect_64.hex`; Resurrect 64 until Nich confirms another),
  `max_colors` 14, `no_background` on, fixed `seed`, outline selective, shading basic or medium, detail medium;
  `description` = the entry's prompt + the character tail below; `negative_description` = the negative cues;
  several candidates, Nich picks the south sprite in the Slack thread. (2) `create_character`, `mode="v3"`,
  `reference_image_base64` = the picked sprite, `size=64`, `n_directions=8`, `view="low top-down"`, template
  mannequin; name it per the naming rule. (3) `animate_character` for each clip listed, `animation_name` = the
  game name: **field set** = `breathing-idle` (idle), `walking` (walk), `running-6-frames` (run),
  `taking-punch` (hurt); **battle set** adds `fight-stance-idle-8-frames` (ready), `falling-back-death` (ko),
  `getting-up` (revive), `fireball` (release), `picking-up` (interact); plus any custom v3 clip named in the
  entry (`mode="v3"`, `frame_count` as given, the movement in `action_description`, nothing else). Outfit and
  story-state variants: `create_character_state` with `color_palette_from_reference`.
- **The character tail** (append to every character prompt): `16-bit JRPG field sprite, three heads tall, large
  expressive eyes, strong hair silhouette, flat cel shading with one light from upper left, selective
  dark-coloured outline, two main costume colours plus one accent, standing, south-facing, transparent
  background`. **Negative cues** (every call): `blur, gradient, anti-aliasing, soft shading, photo, 3D render`.
- **Enemies and bosses**: the same three calls at the size class: small 64x64, medium 64x128 or 128x64, large
  128x128, bosses up to 192 (a canvas is `height_m × 32` plus room for the pose); v3 rotation at 128 costs 2.
  Creatures that do not walk like a person may use `create_character_pro_flash` at the same canvas with the
  palette as `style_image`. Clips: `breathing-idle`, one attack (v3 from the prompt), `taking-punch`
  (+ `falling-back-death` for humanoids). Enemy tail: `16-bit JRPG enemy sprite, one idea and one silhouette,
  flat cel shading with one light from upper left, selective dark-coloured outline, transparent background`.
- **Props**: see Follow-ups (objects at `height_m × 32`); declare the key in `data/props/props.json` first.
- **Textures**: `create_image_pixen` (1 generation) or `create_image_pro` (10) at 256x256, seamless, drawn flat
  (floors from above, walls straight on), with the texture tail in ART_PIPELINE §2; the build lead runs
  `tools/art/import_texture.py`, which budgets each to a 15-colour material palette and tiles it at 32 px/m.
- **Tilesets**: `create_topdown_tileset` Wang sets at 32 px with `target_palette`, standard (1) for drafts and
  pro (15) for finals; `create_tiles_pro` for building kits.
- **UI**: `create_ui_asset` (10) for 9-slice frames at 16–64 px; icons 16/24/32 with `create_image_pro` and the
  palette. **VFX**: the VFX Creator (`vfx_workbench`), 32 px cells (64 for big effects), 8–32 frames, quantised to
  the palette. **Portraits**: Batch 5.
- **Naming**: `TRIGGER <Name> [<variant>] <tier> v<N>`; a character that already has a 128 px sheet in the game
  (crono, sera, krona, marle) is delivered as `TRIGGER <Name> px64 field v<N>` until Nich approves the anchor;
  everyone else is plain `field`. `TEST ` and `REJECTED ` prefixes are never imported (the importer refuses them).
- **Prompt hygiene** (the breakdown's section 14): never a Square Enix character or game name in a prompt or a
  style-reference slot; the prompt is the design-lock identity block without the name, era cues in the
  description, no locations in character prompts; never a ripped sprite as a reference image or inpaint base.
- Transparent background always. A direction that comes back facing the wrong way: delete just that direction
  and queue it again into the same `animation_group_id`. Upload nothing upscaled (`/unzoom` first).

Catalog images (for the Slack concept thread and as `concept_image_url` where a tool takes one) live at
`https://raw.githubusercontent.com/iteatsthesalt/TRIGGER-Time-Debt/main/design/images/catalog/<file>.jpg`.

## Sprite tiers and variants

A character is a set of sprites (ART_PIPELINE §1b): **field** = the 64x64 recipe, used in locations and in
battle (battle clips are columns of the field sheet); **portrait** = 48x48 (Batch 5); **map** and **action**
are to be re-specified at the new scale before any request goes out (the 256 px realistic `crono_action`
stays until then). A **variant** is the same character in another canvas (`u1` … `u8`), a story state
(`debt60`, `debt20`, `debt0`, `broken`, `salvaged`, `rewound`, …) or a size (`px64`), generated with the base
as the style reference so the identity holds; which variants exist is Nich's call per character.

## Batch 1: the playable cast and the Prologue's people (U0; #0–#1 and #8 are slice rows)

| # | Asset key | Request |
|---|---|---|
| 0 | `crono` | **Anchor exists** (`ca2300bc…`, imported as `crono` `px64`: 61 px = 1.78 m, idle + walk). Remaining clips: Follow-up F6. Prompt as used: `weary 41-year-old swordsman father, spiky dull-red hair, white headband, grey stubble, frayed orange scarf, faded blue tunic, brown trousers and boots, moss-covered stone pauldrons, a heavy brass gauntlet on the RIGHT arm wired to a curved katana held low`. |
| 1 | `sera` | **64x64, v3 from an approved south sprite, px64; clips: field set + battle set + attack v3 8 (`a quick double slash with two clock-hand daggers, ribbons of light trailing`), charge v3 4 loop (`she hovers higher, daggers raised, violet light pooling`), victory v3 8.** Prompt: `17-year-old girl, short auburn bob undercut at the sides, frayed red scarf knotted at the throat, teal jacket over a cream shirt, belt with pouch, brown trousers and boots, a short cape of manuscript paper, one blue eye and one violet eye, a hairline porcelain crack under the left eye, two clock-hand daggers held low on ribbons of light, violet accent`. 1.62 m. Supersedes the 128 px `ce6ffc25…`. |
| 2 | `krona` | **64x64, v3 from an approved south sprite, px64, palette = the four U1 inks (her own canvas); clips: field set + battle set + attack v3 8 (`a heavy two-handed nodachi slash from high right to low left, ink flicks off the blade`), charge v3 4 loop (`iai stance, both nodachi sheathed low, a held breath`), victory v3 8.** Prompt: `ageless woman who looks early thirties, spiky red hair tied in a war-knot with white ties, tired eyes, a cheek scar, cracked black lacquered o-yoroi armour with a melted pauldron, red sash, tattered cape, a dripping gourd at the hip, bare feet, two long nodachi of snapped steel and red chitin held low`. 1.72 m. **Nich picks** nodachi in hand (the wired `6af5c834…`) or on her back (`364e2216…`) before the anchor is drawn. |
| 3 | `marle` | **64x64, v3 from an approved south sprite, px64; clips: field set + `fight-stance-idle-8-frames` + attack v3 8 (`she draws a small crossbow and fires one bolt`) + `picking-up`.** Prompt: `queen of forty, blonde ponytail, ceremonial faded royal blue and cream gown with a fitted bodice, brown boots, a ledger tucked under one arm, tired regal posture`. 1.68 m. Supersedes the realistic 128 px `05c8ee87…` (its proportion question is closed by the recipe). |
| 4 | `glenn_marshall` | **64x64, v3 from an approved south sprite, field; clips: `breathing-idle`, `walking` (a cane walk), `taking-punch`, `picking-up`.** Prompt: `one-armed marshal of forty-seven, grey swept-back hair and short beard, LEFT sleeve empty and pinned, green cape over white-and-gold plate armour, belts and pouches, a tall cane capped with an old bronze sword hilt in his RIGHT hand, worn boots, weathered face`. Keep the missing arm in every direction; 1.80 m (`--height-m`). |
| 5 | `magus` | **64x64, v3 from an approved south sprite, field; clips: field set + `fireball` + attack v3 8 (`he raises one hand and a scythe of violet light sweeps across`).** Prompt: `tall gaunt sorcerer, long silver-lavender hair, one eye blind and clouded with a trail of liquid silver running from it, violet high-collared cloak over dark robes, long fingers, sharp face`. Keep the blind eye on the same side in every direction; 1.90 m. |
| 6 | `vaelos_boy` | **64x64, v3 from an approved south sprite, field; clips: `breathing-idle`, `walking`, `picking-up`.** Prompt: `a boy of about ten with the swordsman's features, pale alabaster skin with faint hairline cracks that leak points of starlight, short red-and-silver hair, a simple cream tunic, bare feet, calm unsettling smile; a child, two and a half heads tall`. 1.35 m. |
| 7 | `vaelos` (the Sovereign) | **128x128 (2.74 m = 88 px), anchor at 128 then v3 rotation, field; clips: `breathing-idle`, `walking`, `fight-stance-idle-8-frames`, `fireball`, attack v3 8 (`he extends one arm and a spear of starlight erupts forward`).** Prompt: `nine-foot androgynous humanoid grown from the swordsman's atoms, cracked alabaster skin leaking starlight, a fibre-optic mane of light, a mantle of fossilised saurian bones with server blades and shards of stained glass, long elegant hands, a serene cruel face like an older version of the hero, violet accents`. After gate 2. |
| 8 | `villager_m`, `villager_f`, `child`, `elder`, `guard`, `merchant` | **Six crowd NPCs, 64x64, `create_character` v3 from text (2 each) with the palette and the approved anchor as style reference, field; clips: `breathing-idle`, `walking`.** Prompts: `a townsman in a brown tunic and cap carrying a basket`; `a townswoman in a green dress and apron with a shawl`; `a child in a yellow smock with a wooden sword`; `a white-bearded elder in a grey robe leaning on a stick`; `a castle guard in blue-and-silver mail with a halberd and a plumed helm`; `a plump merchant in a red waistcoat with a money pouch and a ledger`; each + `friendly readable face` + the tail. The 128 px `villager_m` on the account (`feef7cc5…`) is superseded. |

## Batch 1b: action tier (suspended until the tier is re-specified at the new scale)

One action-tier character per hero for Dual/Triple Tech cut-ins; the only base is the 256 px realistic
`crono_action` (`d1df31ab…`, idle only). Clip descriptions, kept for the re-spec (custom v3, 8–12 frames,
directions south, west, east unless noted): A1 `crono` `smear_dash` 8 (`drops into a low draw stance and dashes
forward in a blur, the katana trailing a smeared red-to-blue streak, afterimages a few frames behind`); A2
`crono` `katana_cross` 8 (`steps in and cuts a long diagonal from high right to low left with the gauntlet arm,
then a return cut forming an X, a faint rainbow arc off the blade`); A3 `sera` base + `chronoslip_fall` 12
(`she stumbles mid-air, her outline stuttering between frames, violet light flickering, the clock-hand daggers
slipping from her hands, then she folds and falls`); A4 `sera` `rewind_cast` 8 (`hovers higher, both daggers
raised, violet clock glyphs spinning backwards around her wrists`); A5 `krona` base + `ink_cross` 8 (`crosses
both nodachi overhead and brings them down in a scissor cut, black ink flicking off the blades, a wet splash
where they meet`); A6 `krona` `iai_hold` 6 loop (`iai stance, both nodachi sheathed low, hair ties lifting in a
held breath, ink dripping from the gourd`); A7 `vaelos` `fair_descent` 12, south only (`descends slowly from
above with arms open, the fibre-optic mane streaming upward, starlight leaking from the cracks, the bone
mantle settling as the feet touch the ground`).

## Batch 2: the Prologue and Chapter 1 enemies (U0; #9–#12 are slice rows)

Size class, then the three calls; clips `breathing-idle`, the attack described (v3), `taking-punch`. Height
comes from the enemy def (`height_m`) or `--height-m` at import. Every prompt + the enemy tail.

| # | Asset key | Request |
|---|---|---|
| 9 | `enm_u0_dust_mote_cluster` | **Small 64x64.** `a cluster of seven glowing dust motes orbiting a faint ring of light, soft gold and cream`; attack: `the motes rush inward and burst outward in a wash`. |
| 10 | `enm_u0_porcelain_shardling` | **Small 64x64.** `a small porcelain imp made of a broken doll's shards, a spiky red-hair fragment on its head, one blue glass eye, jagged white body with gold cracks`; attack: `it lunges and slashes with a shard arm`. |
| 11 | `enm_u0_ashen_spoon` | **Small 64x64.** `a wooden kitchen spoon come alive as a brush creature, its bowl a dripping ink brush head, thin legs of dry brush strokes, three inks only: bone white, soot grey, arterial crimson`; attack: `it whips its brush head and flings ink`. |
| 12 | `vaelos_echo` | **Small 64x64 (human height).** `an intangible shadow silhouette of a spiky-haired boy made of dark translucent smoke with points of starlight inside, no face, edges breaking into flickering frames`; attack: `it reaches out and the air around its hand stutters`. |
| 13 | `enm_u0_trance_bellkeeper` | **Small 64x64 (1.9 m).** `a slender porcelain bell-ringer automaton carrying a brass handbell, a single crack along its jawline, cream robes with brass fittings, calm closed eyes`; attack: `it raises the bell and rings it, sound rings spread`. A `TEST` sprite exists on the account; not imported. |
| 14 | `enm_u0_gato_ruin` | **Medium 128x64 (wide).** `a ruined carnival boxing robot shaped like a round cat, cracked porcelain and brass, a dented chest plate with faded serial lettering, one red eye, spring-loaded punching gloves`; attack: `a heavy telegraphed glove punch`. |
| 15 | `enm_u0_debtling` | **Small 64x64.** `a swarm of five tiny cracked porcelain doll heads with spiky red hair scuttling on little spider legs, gold crack lines`; attack: `the heads leap and bite`. A `TEST` sprite exists; not imported. |
| 16 | `enm_u0_moss_mouse` | **Small 64x64 (symmetric: `--mirror` allowed).** `a round grey mouse with moss and tiny mushrooms growing on its back, bright black eyes`; attack: `it darts forward and nips`. A `TEST` sprite exists; not imported. |
| 17 | `enm_u0_bekkler_fragment` | **Small 64x64.** `a rubber-hose cartoon doll fragment: one white-gloved arm and half a grinning painted face on a bouncing spring body, 1930s cartoon style`; attack: `it stretches to three times its height and snaps back like an accordion`. |
| 18 | `enm_u0_ashen_echo_krona` | **Small 64x64 (1.72 m).** `a dry-brush ink silhouette of a woman with a war-knot of hair and two long swords, no face, soot grey ink with crimson accents on bone white`; attack: `a wide ink slash that leaves wet ink on the ground`. |
| 19 | `enm_u0_ferro_drone_09` | **Medium 64x128.** `a brass six-legged spider drone with a gramophone horn head and a glowing mercury orb in its belly, clay-and-brass look with scanlines`; attack: `the horn emits a cone of sound rings`. |

## Batch 3: the two U0 bosses (#20 is a slice row)

| # | Asset key | Request |
|---|---|---|
| 20 | `bos_u0_atrium_cradle` | **Boss 128x128 (3.2 m = 102 px), anchor at 128 then v3 rotation (2); clips: `breathing-idle` (the ring turns), attack v3 (`the barrel ring spins and fires a volley`), `taking-punch`, `falling-back-death` (legs fold).** Prompt: `a prototype of a hulking curator robot on six brass insect legs, a rotating thoracic ring of eight gun barrels, a porcelain theatre-mask face with one sorrowful blue eye, copper vines and oil, a peeled chassis showing red muscle fibre, clay-and-brass detail` (the catalog image `enemy_arch_curator_r_66y.jpg` is the finished version; this is smaller and rougher). |
| 21 | `enm_u0_training_dummy_prime` (the 999 Shard Doll) | **Large 128x128 (2.0 m = 64 px, legs spread); clips: `breathing-idle` (head tilt), attack v3 (`it rears up and stamps with two legs`), `taking-punch`, `falling-back-death` (cracks open on a galaxy inside).** Prompt: `a life-size porcelain carnival doll of the swordsman with goggles pushed up and a glowing egg-shaped clock-heart set in its chest, standing on six reverse-jointed brass spider legs, a tungsten bracer on one arm and a mercury-silver shoulder, small porcelain masks orbiting its collar, a giggling expression, gold cracks`. After gate 2. |

## Batch 4: Chapter 2, the Crimson Shogunate (U1, sumi-e; after gate 2 except the delivered props)

Everything here is drawn in **four inks only**: sumi black `#1A1A1A`, cobalt `#0D2640`, cinnabar `#8C1D18`
(fire and banners), paper white `#F2EED8`. Send them as the `palette` with `max_colors` 4; tone is ink density
and dither inside the ink, no gold, no grey gradients. U1 tail for characters: the character tail + `four inks
only: sumi black, cobalt, cinnabar, paper white; dry-brush edges`. Krona's approved anchor is the style
reference for the people.

### 4a. People (64x64, v3 from an approved south sprite, field)

| # | Asset key | Prompt and clips |
|---|---|---|
| 22 | `krona_duel` (boss variant of Krona; deliver as `TRIGGER Krona duel field v1`, `create_character_state` from her anchor) | `the swordswoman in cracked black lacquered o-yoroi with the melted pauldron, war-knot hair, two long nodachi of snapped steel and red chitin drawn and ready, oil dripping from the hip gourd, bare feet planted in wet ink`. Clips: `fight-stance-idle-8-frames`, attack v3 8 (`a two-handed overhead nodachi cut that splashes ink`), second attack v3 8 (`a low sweeping slash from right to left`), `taking-punch`, `falling-back-death` (she kneels, not dies), **disarm** v3 6 (`she lowers both blades and lets one fall`). |
| 23 | `krona_retainer_a`, `krona_retainer_b`, `krona_retainer_c` | `a half-corroded samurai retainer in cracked lacquered armour, a plain paper mask over the face with the lacquer flaking at the edges, kneeling-stiff posture, oil stains at the joints` (vary: spear, bow, bare hands). Clips: `breathing-idle` only (they kneel). |
| 24 | `u1_citizen_m`, `u1_citizen_f`, `u1_painter`, `u1_child` | `a townsman in a plain paper mask and indigo work robe carrying a bucket of white paint`; `a townswoman in a paper mask and grey kimono with a brush`; `a gate painter on a short ladder with a wide brush, white paint dripping`; `a child in a paper mask too big for its face, holding a paper crane`. Clips: `breathing-idle`, `walking`. |
| 25 | `lord_ashinaga_npc` (the Daimyo before the fight, seated) | `an old daimyo seated on a dais in black court robes with a cinnabar crest, writing with a long brush, face hidden by a paper mask that is a surrender petition, armour at the joints weeping black oil`. Clips: `breathing-idle` (writing). The fight uses #35. |

### 4b. Enemies (size class; clips `breathing-idle`, the attack described, `taking-punch`; + the enemy tail and the four inks)

| # | Asset key | Request |
|---|---|---|
| 26 | `enm_u1_ashen_ashigaru` | **Small 64x64.** `a foot soldier in armour made of folded paper plates lacquered black, a conical paper hat, a plain white mask, a short yari spear, ash on the shoulders`; attack: `a quick spear thrust`; extra v3 clip **repaint** 4 (`he slaps fresh white paper over his own chest plate`). |
| 27 | `enm_u1_porcelain_captain` | **Small 64x64.** `a taller ashigaru captain in cracked porcelain armour over paper, a cinnabar sashimono banner on his back, a katana, a mask with one crack from brow to jaw`; attack: `a commanding katana cut`. |
| 28 | `enm_u1_ink_calligrapher` | **Medium 64x128 (the brush).** `a robed scribe with a brush taller than himself, sleeves soaked black, writing in the air, the strokes he leaves hang as wet black kanji`; attack: `he writes a single huge kanji that slams forward`. |
| 29 | `enm_u1_gourd_bloated_heimin` | **Small 64x64.** `a peasant swollen and shiny with oil, a gourd fused to his belly, skin cracking like lacquer with black oil in the cracks, slow and sad`; attack: `he lurches and bursts into a cloud of ash`; add `falling-back-death` (the burst). |
| 30 | `enm_u1_surrender_petition_yokai` | **Small 64x64.** `a surrender petition folded into an origami spirit, a paper body with brushed kanji showing through, a seal stamp for a face, hovering`; attack: `it unfolds flat and snaps shut around the target`. |
| 31 | `enm_u1_crimson_banner_samurai` | **Medium 64x128 (the banner).** `an elite samurai in full black lacquered armour carrying a tall cinnabar war banner, a mask with a drawn snarl, katana sheathed`; attack v3 8 (`he holds a frozen ink pose for a long beat, then draws and cuts in one stroke`); the hold must read as a telegraph. |
| 32 | `enm_u1_omen_crow` | **Medium 128x64 (wings).** `a large crow whose feathers are strips of videotape and scanline static, eyes of white noise, perched then flaring`; attack: `it flares its wings and a burst of static blinds`. |
| 33 | `enm_u1_imp_crackle` | **Small 64x64.** `a small ink imp made of a single splashed brush stroke with two white dot eyes, trailing wet ink on the floor`; attack: `it skids and paints a black streak`. |
| 34 | `enm_u1_shogun_memory_flame` (field boss) | **Boss 128x128 (3.6 m).** `a column of living cinnabar fire in the rough shape of a kneeling shogun, armour outlines in the flames, a paper mask floating where the face would be`; attack: `the flame rears and sweeps a burning sleeve`. Clips: `breathing-idle` (flame loop), attack, `taking-punch`, `falling-back-death` (gutters out). |

### 4c. Bosses

| # | Asset key | Request |
|---|---|---|
| 35 | `bos_u1_ashen_daimyo` (phases are the same body) | **Boss 192x192 (6 m seated).** `a twenty-foot seated giant whose whole body is thousands of folded surrender petitions stacked and bound into the shape of a daimyo in court armour, brush in hand, armour joints weeping black oil, fire licking the floor around him, a gourd-shaped shadow where his heart is`. Clips: `breathing-idle` (writing), attack **scribe** (`he finishes a petition and flicks it off the brush`), attack **roof** (`he raises both arms and fire breathes across the floor`), `taking-punch` (petitions scatter), **crack** v3 6 (`his chest cracks open to show a glowing gourd heart`), `falling-back-death` (he comes apart as porcelain over red fibre). |
| 36 | `bos_u1_weeping_shogun` (concept image `enemy_weeping_shogun.jpg`) | **Boss 192x192.** `two bodies in one: the lower body a black ink spawn with spiked brush-stroke legs, fused at a ragged seam to a brass and clay clockwork centipede with segmented armour and a weeping porcelain face; the ink half brushed, the clay half with visible thumbprints and scanlines`. Clips: `breathing-idle`, attack **ink** (`the ink legs rake forward`), attack **clay** (`the centipede head slams down`), `taking-punch`, `falling-back-death` (the two halves fall apart in opposite directions). Deliver a mask too if you can; the engine splits the halves by colour otherwise. |

### 4d. Landmarks and props: delivered

All twenty objects of this batch (Linear TRI-31..TRI-50: the guillotine, the cage, the clay gear, the torii,
the three petitions-and-banners pieces, the gourd, the blade stand, the four dojo pieces, the six street pieces,
the finial) were delivered and imported on 2026-11-02 at the pre-direction 128/256 canvases; one row per key
with id, height and cell is in **Done**. Open: Follow-up F3 (the rusted katana lying flat).

### 4e. World kit (after gate 2; textures via `import_texture.py`, Wang sets at 32 px)

| # | Asset key | What |
|---|---|---|
| 47 | `tex_u1_ink_ground` (+ `tex_u1_ink_ground_burned`) | 256 px seamless, from above: `wet black ink ground with faint paper fibre showing through`; the burned variant `the same ground scorched to golden watercolour`. |
| 48 | `tex_u1_washi_floor` | 256 px seamless, from above: `white washi paper floor over dark boards, subtle brush texture`. |
| 49 | `tex_u1_castle_wall` (+ `_burned`) | 256 px seamless, straight on: `plaster-and-timber castle wall in black ink lines on paper white, a cinnabar trim strip`; burned: `char climbing from the bottom`. |
| 50 | `tex_u1_iron_bridge_deck` | 256 px seamless, from above: `dark timber planks with black iron strapping`. |
| 51 | `tex_u1_carved_waves` | 256 px seamless, from above: `water as carved woodblock wave lines in cobalt on paper white, opaque`. |
| 52 | `tex_u1_bamboo_wall` | 256 px seamless, straight on: `a wall of black ink bamboo stalks with cinnabar leaves`. |
| 53 | `tex_u1_street_cobble` | 256 px seamless, from above: `cobbles as ink outlines with dither, ash in the joints`. |
| 54 | `tex_u1_roof_chitin` | 256 px seamless, straight on: `a roof of black insect-chitin scales with a cobalt sheen line`. |
| 55 | `tiles_u1_kuro_truce` | `create_topdown_tileset`, 32 px, `target_palette` = the four inks: ink ground → street cobble → washi floor (chained with `lower_base_tile_id`), for the streets. |
| 56 | `tiles_u1_hinterlands` | `create_topdown_tileset`, 32 px: paper-white negative space → faint mountain wash → mossy ground, for the Hinterlands. |

### 4f. U1 VFX and Krona's signatures (VFX Creator, 32–64 px cells, four inks)

| # | Asset key | What |
|---|---|---|
| 57 | `vfx_teppo_ash_cut` | a 180° wet-ink slash arc, 8 frames, leaving a wet zone; `vfx_ash_field` a tileable ash-ground decal. |
| 58 | `vfx_ens_parry` | a sumi circle closing to a ring, 6 frames, then a ring shield loop 4 frames. |
| 59 | `vfx_eclipse_x_strike` | the X slash frames, 8, half watercolour half ink (the split itself is a shader). |
| 60 | `vfx_cobalt_iai` | a 12-frame horizontal cobalt slice that goes indigo → white. |
| 61 | `vfx_ruin_purge` | an expanding ash circle with a buff glyph shattering, 8 frames. |
| 62 | `vfx_ink_bleed_impact` | an ink impact bloom that feathers over 12 frames (the U1 hit decal). |
| 63 | `vfx_u1_rain_strokes` | vertical calligraphy-stroke rain, 6-frame loop, tileable. |
| 64 | `vfx_petition_spawn` | a petition folding itself into a soldier, 8 frames. |

### 4g. Portraits (48x48, four inks; Batch 5 recipe)

`krona` (if not already done in Batch 5), `lord_ashinaga`, `u1_citizen_m`, `u1_citizen_f`, `krona_retainer_a`.

## Batch 5: portraits (48x48 pixel busts; `crono` and `sera` are slice rows)

`create_image_pro`, **48x48**, `view="side"`, the character's approved south sprite as the style image, the
project palette (or the four inks for U1) with `max_colors` 14, transparent; one call per expression. Six
expressions, named for the files: `neutral` (calm), `happy`, `angry`, `sad`, `surprised`, `determined`
(`PortraitCache` falls back to `neutral`, so deliver that one first). Import target
`assets/portraits/<id>/<id>_<expr>.png`. Order: crono, sera, marle, robo, glenn, magus, krona, vaelos, lucca,
bekkler. Prompts: the character's identity block (no name) + `48 px pixel-art bust, head and shoulders,
three-quarter face, same palette as the field sprite, flat cel shading, selective outline`. Supersedes the 512
painted busts (Reference Bible §1.4 PRT).

## Batch 6: Prologue props and the Atrium: delivered

All 27 objects (Linear TRI-51..TRI-78) were delivered and imported on 2026-11-02 at the pre-direction canvases;
the kitchen, courtyard and Atrium stand nineteen of them (`docs/screenshots/11`–`13`), the rest await their
scenes; one row per key in **Done**. Open: Follow-ups F1 (clock face), F2 (pool), F4 (tree stages), F5
(Klein journal).

## Batch 7: U0 textures: done by the build lead (2026-11-02)

The twelve materials (castle_flagstone, castle_wall_block, oak_plank, oak_beam, slate_roof, brass_panel,
cobble_wet, grass_moss, dirt_path, fair_canvas_stripe, stone_steps, plaster_cream) were generated with
`create_image_pixen` / `create_image_pro`, budgeted to 15 colours, tiled at 32 px/m and are in
`assets/textures/generated/` with rows in `source_art/MANIFEST.csv` (`docs/screenshots/21_kitchen_snes_density.jpg`).
Nich says which to redo (one generation each). New U0 materials follow the same route (ART_PIPELINE §2).

## Batch 8: UI (the frame is a slice row; the rest after gate 2)

Delivered and copied as is to `assets/ui/generated/` (not wired): `ui_battle_command_menu`,
`ui_party_status_card`, `ui_menu_kit`, `ui_dialogue_box` (navy and gold). **Style gate:** Nich picks that set
(B) or the palette-locked 9-slice frame in the style kit (A, `source_art/style_kit/window_frame_resurrect64_256.png`)
before anything more is made. Then, in the chosen theme, with `create_ui_asset` (frames) and `create_image_pro`
with the palette (icons): tooltip frame 9-slice 32, cursor hand 16, target cursor 24, nine element icons 32
(astral, tachyon, ruin, ferro, mycelia, vitreous, guile, hz, null; shape as well as colour), ten status icons 16
(bleed, burn, slow, haste, seal, break, guard, stagger, oil_blight, rewound), HP/BP/turn gauges, shield plate
housing 48x24 with the key glyphs, the Klein journal pages texture (F5). Import target `assets/ui/generated/`.

## Batch 9: VFX flipbooks (after gate 2; the impact burst exists in the style kit)

VFX Creator (`vfx_workbench`), 32 px cells (64 for the Break shatter), palette-quantised, additive where noted:
element hits ×9 (8 frames each), Break shatter 12 (additive), plate crack 6, perfect-parry flash 4, the hero's
tech wisps 4 (loop) and Smear Dash trail 4, Sera's Rewind glyph 8 and fast-forward streaks 6, Krona's ink
splash 8 and wet-ink zone 6 (loop). Import target `assets/vfx/generated/<family>/<id>_fb_<n>f.png`
(ART_PIPELINE §6b).

## Done

Characters and props imported from PixelLab (`data/art/pixellab_assets.json` is the record; the Linear issue
is in Notes). Heights are the data values (`data/props/props.json`, the kits).

| Asset key | PixelLab id | Imported | Notes |
|---|---|---|---|
| `crono_px64_field` (idle, walk) | `ca2300bc-7592-4606-8973-32b9bc00056b` | 2026-11-02 | "TRIGGER Anchor Crono 64 v1": the 64 px anchor, 61 px = 1.78 m, cell 96; becomes `crono_field` when Nich approves the anchor; remaining clips F6 |
| `crono_field` (idle, walk, run, hurt, ready, ko) | `8d699d00-eb9f-4da7-a408-a1f70039fa1c` | 2026-10-29 | the 128 px chibi template, superseded; ships until the anchor is approved |
| `crono_action` (idle only) | `d1df31ab-e2cc-47c7-a8b7-6b293769a293` | 2026-10-29 | the 256 px action-tier base; tier to be re-specified (Batch 1b) |
| `sera_field` (idle, walk, run) | `ce6ffc25-e512-4312-9d83-a850ab3b561f` | 2026-10-29 | 128 px, superseded; 64 px remake is #1 |
| `krona_field` (idle, walk) | `6af5c834-e7a7-4e8b-83d7-8fb2b4222695` | 2026-10-29 | 128 px, superseded; alternative `364e2216…` on the account; 64 px remake is #2 |
| `marle_field` (idle only) | `05c8ee87-ac36-41af-870a-f1bf8bc4dabc` | 2026-10-29 | 128 px realistic, superseded; 64 px remake is #3 |
| `prp_u0_bekkler_doll` | `c862ecdb-89a9-45eb-980c-c13c7da1a7ca` | 2026-11-02 | TRI-67; 0.45 m, cell 128; Atrium |
| `prp_u0_bekkler_tent` | `41966135-0fe8-4735-88f5-0d8792402f68` | 2026-11-02 | TRI-73; 3.4 m, cell 192; imported, awaiting its scene |
| `prp_u0_brass_gate_arch` | `a96a4b60-1eed-4f09-a2e8-589a545071ca` | 2026-11-02 | TRI-64; 3.8 m, cell 224; Atrium ×8 |
| `prp_u0_clock_pillar_face` | `b1b65e83-ec91-41ab-9da8-166875efb2cc` | 2026-11-02 | TRI-63; 9.0 m, cell 192; a whole clocktower spire, not a pillar face (not placed); v2 is F1 |
| `prp_u0_counter_bowls` | `1bfc9189-c11d-4dc4-a3d8-d329858da146` | 2026-11-02 | TRI-52; 1.1 m, cell 96; kitchen |
| `prp_u0_doan_tree_stages` | `0aad5a7e-5316-422b-9817-34ec0df50985` | 2026-11-02 | TRI-77; 0.5 m, cell 96; seed stage only; the other stages are F4 |
| `prp_u0_dummy_plinth` | `bbb6b5f2-1163-4c8d-b670-4f25c9fe0b13` | 2026-11-02 | TRI-68; 0.8 m, cell 64; Atrium |
| `prp_u0_gramophone_workbench` | `6857fb3f-eba7-4e12-ad4d-54f842529b06` | 2026-11-02 | TRI-66; 1.5 m, cell 128; Atrium |
| `prp_u0_hand_cart` | `5b91d919-d2f4-4c90-948f-54e852acfc9b` | 2026-11-02 | TRI-60; 1.5 m, cell 128; courtyard |
| `prp_u0_hearth` | `89ddf903-c7ce-454c-8f1f-d74854fe290b` | 2026-11-02 | TRI-57; 1.9 m, cell 128, 5-frame idle loop; kitchen + Atrium |
| `prp_u0_ink_stool` | `6112a4dd-aa92-40cb-948f-1db480d3304d` | 2026-11-02 | TRI-54; 0.6 m, cell 96; kitchen |
| `prp_u0_leene_bell` | `1aafb3c2-d678-4872-99ce-f3ce593d1336` | 2026-11-02 | TRI-75; 2.8 m, cell 160; imported, awaiting its scene |
| `prp_u0_loft_ladder` | `5c82b89e-ec1d-48ec-a2d9-a55252f8f208` | 2026-11-02 | TRI-70; 2.4 m, cell 128; Atrium loft |
| `prp_u0_moss_flower_bed` | `27a25879-3dce-4a3a-a98e-94428abc74e4` | 2026-11-02 | TRI-61; 0.9 m, cell 96; courtyard ×4 |
| `prp_u0_oak_table` | `b4f8b062-9d67-4b00-9b4f-6d1c5a64cf15` | 2026-11-02 | TRI-53; 1.2 m, cell 128; kitchen |
| `prp_u0_pool_rim` | `2b28c782-27dc-4c9f-a259-dae956ee5c3f` | 2026-11-02 | TRI-69; 1.0 m, cell 128; one front arc of rim (not placed); the pool disc is F2 |
| `prp_u0_porridge_pot` | `3eb122dc-c46c-48a3-9408-23a43655b4bc` | 2026-11-02 | TRI-51; 0.9 m, cell 128; kitchen |
| `prp_u0_portcullis` | `3c15ff79-7782-4a48-a430-60f96e279541` | 2026-11-02 | TRI-62; 4.0 m, cell 128; courtyard |
| `prp_u0_pot_shelf` | `7e896fe4-6207-4742-bfe1-c2890f367924` | 2026-11-02 | TRI-56; 1.0 m, cell 128; kitchen |
| `prp_u0_robo_rest_alcove` | `13d9167d-fa81-4657-a20b-f34fb7363f27` | 2026-11-02 | TRI-71; 2.8 m, cell 128; Atrium |
| `prp_u0_robos_ribbon` | `8eff6e4f-6f0c-4ace-bfea-722d35448693` | 2026-11-02 | TRI-76; 0.3 m, cell 96; imported, awaiting its scene |
| `prp_u0_seed_of_doan_pot` | `1869f296-e811-42bf-be15-f9e61f285261` | 2026-11-02 | TRI-65; 1.1 m, cell 128; Atrium |
| `prp_u0_speaking_tube` | `538e8657-1d67-4d7e-b01b-cec3a9852885` | 2026-11-02 | TRI-55; 1.6 m, cell 128; kitchen |
| `prp_u0_stained_glass_panel` | `ee86cc0c-e8e6-433c-89fb-7d66ee592da3` | 2026-11-02 | TRI-58; 3.0 m, cell 192; kitchen ×3 |
| `prp_u0_stone_well` | `3c966da7-03f4-4854-9552-282af352a642` | 2026-11-02 | TRI-59; 2.0 m, cell 128; courtyard |
| `prp_u0_telepods` | `4b72d8ff-bea4-41d0-bc00-f12274179e1b` | 2026-11-02 | TRI-74; 1.9 m, cell 224; imported, awaiting its scene |
| `prp_u1_clay_gear` | `fae1201e-2d55-4c39-b63e-f38befce3e33` | 2026-11-02 | TRI-33; 4.0 m, cell 256, 5-frame idle loop; imported, awaiting its scene |
| `prp_u1_dojo_set_cushion` | `1e8c4a44-dd17-4861-8fa5-9f3578dac56a` | 2026-11-02 | TRI-42; 0.4 m, cell 96; imported, awaiting its scene |
| `prp_u1_dojo_set_rusted_katana` | `4ad20c87-a860-4885-8688-19fdfc2603ed` | 2026-11-02 | TRI-43; 1.1 m, cell 128; came back upright; v2 lying flat is F3 |
| `prp_u1_dojo_set_tatami` | `5d748077-ebb5-4acf-9f16-69c768ae1b5c` | 2026-11-02 | TRI-40; 0.9 m, cell 128; imported, awaiting its scene |
| `prp_u1_dojo_set_weapon_rack` | `e6a1b202-c0cc-44a9-b252-664036456b49` | 2026-11-02 | TRI-41; 1.6 m, cell 128; imported, awaiting its scene |
| `prp_u1_leene_bell_guillotine` | `d58bc077-79db-4bdc-8036-9e30871b9470` | 2026-11-02 | TRI-31; 4.5 m, cell 256; imported, awaiting its scene |
| `prp_u1_pagoda_finial` | `cb738aec-e6ce-4975-8e02-8d9a8964f131` | 2026-11-02 | TRI-50; 1.2 m, cell 128; imported, awaiting its scene |
| `prp_u1_petitions_banners_lantern` | `c0a7f865-79c2-4c18-998a-37db24f483d0` | 2026-11-02 | TRI-37; 0.9 m, cell 128; imported, awaiting its scene |
| `prp_u1_petitions_banners_scrolls` | `2104cb75-dabf-430f-a0fb-5b53470e776f` | 2026-11-02 | TRI-35; 0.5 m, cell 96; imported, awaiting its scene |
| `prp_u1_petitions_banners_war_banner` | `2db8eba7-f567-4d87-99ea-4092115b9e5f` | 2026-11-02 | TRI-36; 2.6 m, cell 128; imported, awaiting its scene |
| `prp_u1_sake_gourd` | `acb8217f-21ee-43b0-a015-07632309455f` | 2026-11-02 | TRI-38; 0.35 m, cell 64; imported, awaiting its scene |
| `prp_u1_sera_cage` | `46a70648-787c-4315-a783-f5fe6c3238e3` | 2026-11-02 | TRI-32; 2.6 m, cell 224, 5-frame idle loop; imported, awaiting its scene |
| `prp_u1_street_set_door_painted` | `73021fa1-ab77-4ace-90d0-4faee358c50a` | 2026-11-02 | TRI-44; 2.0 m, cell 128; imported, awaiting its scene |
| `prp_u1_street_set_door_peeled` | `b7df11ac-89ee-425e-8e5d-ea37a2fd331c` | 2026-11-02 | TRI-45; 2.0 m, cell 128; imported, awaiting its scene |
| `prp_u1_street_set_ladder` | `29e31e3c-ff78-49c2-bf8b-f36efbd39ccb` | 2026-11-02 | TRI-47; 2.4 m, cell 128; imported, awaiting its scene |
| `prp_u1_street_set_paint_bucket` | `a797c0e3-aead-4453-90c0-836fa6187ec7` | 2026-11-02 | TRI-46; 0.5 m, cell 128; imported, awaiting its scene |
| `prp_u1_street_set_roof_tiles` | `058b2f90-6626-46f3-abbc-10f998d0c17e` | 2026-11-02 | TRI-49; 0.7 m, cell 96; imported, awaiting its scene |
| `prp_u1_street_set_stone_lantern` | `b9ba3dea-85a3-47ca-b5f5-bc6f87c1de13` | 2026-11-02 | TRI-48; 1.6 m, cell 128; imported, awaiting its scene |
| `prp_u1_torii` | `37ea4f86-3834-4a4a-b64c-37b0168ec25f` | 2026-11-02 | TRI-34; 4.0 m, cell 192; imported, awaiting its scene |
| `prp_u1_vault_blade_stand` | `446ce3e9-1e32-46a2-a7a2-694c3efd6f38` | 2026-11-02 | TRI-39; 0.6 m, cell 128; imported, awaiting its scene |
| `prp_u2_seed_of_doan` | `c4f7051a-c770-4278-b743-4420a83ea924` | 2026-11-02 | TRI-78; 0.5 m, cell 128; imported, awaiting its scene |

Pending in `data/props/props.json` with no PixelLab id: `prp_u0_klein_journal` (TRI-72, Follow-up F5).

Generated or copied by the build lead, logged in `source_art/MANIFEST.csv` rather than `pixellab_assets.json`:
the twelve Batch 7 textures (`assets/textures/generated/`, 2026-11-02); the four Batch 8 panels
(`assets/ui/generated/`, asset team, 2026-11-02, unwired); the Phase-1 style kit (`source_art/style_kit/`:
16 anchor candidates, 3 Wang test tilesets, 1 window frame, 1 impact burst, 2026-11-02; nothing from it ships
until Nich picks).
