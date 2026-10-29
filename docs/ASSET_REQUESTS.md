# Asset requests for Nich's PixelLab bot

Nich makes the art. Each entry below is a ready-to-send PixelLab request. The build agent imports finished
items with `python3 tools/art/import_pixellab.py <pixellab_id|url> <asset_key>` (contract, sheet layout and
checks in `docs/ART_PIPELINE.md`) and moves the entry to **Done** with the PixelLab id and date. Keep this
list in priority order; the first undone entry is the most urgent. Entries marked IN PROGRESS already exist
on the account (ids given); only the listed remaining animations are needed for them.

## How to send one

- **Characters** (anything that walks): `create_character` in **pro** mode (`mode="pro"`), `size=128` (pro's
  maximum; the importer scales every sprite to its height in metres, so never pad or resize),
  `view="low top-down"`, 8 directions, name it `TRIGGER <Name> v1` (v2, v3 for retries), `concept_image_url`
  = the catalog image link given, `description` = the prompt given. For the house style, add
  `style_character_id` = Crono's id `8d699d00-eb9f-4da7-a408-a1f70039fa1c` whenever there is no catalog image.
- Then queue the **animations** listed, one or two at a time (`animate_character`, and pass
  `animation_name` = the game name: `idle`, `walk`, `run`, `hurt`, `ready`, `ko`, `revive`, `release`,
  `interact`, `attack`, `charge`, `victory`): field set = `breathing-idle` (idle), `walking` (walk),
  `running-6-frames` (run), `taking-punch` (hurt); battle set adds `fight-stance-idle-8-frames` (ready),
  `falling-back-death` (ko), `getting-up` (revive), `fireball` (release), `picking-up` (interact), plus a
  custom v3 **attack** (`mode="v3"`, `frame_count=8`, weapon in the `action_description`).
- **Creatures and things that do not walk like a person** (motes, drones, spoons, a cat robot) and **anything
  taller than a person**: `create_character_pro_flash` with `width`/`height` 128 (creatures) or 256 (bosses) and
  the right `template_id` (`cat`, `dog`, `custom`), or `create_8_direction_object` (max 168); same view, same
  naming. Pro Flash animates with the same `animate_character` clips.
- Every prompt below already carries the style line. Keep the transparent background. If a direction comes
  back facing the wrong way (the importer reports it), delete just that direction and queue it again into the
  same `animation_group_id`.

Catalog images live at `https://raw.githubusercontent.com/iteatsthesalt/TRIGGER-Time-Debt/main/design/images/catalog/<file>.jpg`.

## Sprite tiers and variants (one character is a set of sprites)

Nich's rule: a character has several sprites, by situation and size, plus variants. The tiers, their PixelLab
settings and the game file they land in (`assets/<group>/<id>/`). Every request below names its tier; a
request without one means **field**.

| Tier | Used for | PixelLab | Look | Game file |
|---|---|---|---|---|
| **map** | the overworld / world map, once it opens (Chapter 3 and later) | pro, `size=64`, 4 directions; clips `breathing-idle`, `walking` | tiny, bold silhouette, 2–3 colours per material | `<id>_map.png` |
| **field** | walking around locations and biomes, and battle (battles happen on the map, so battle uses the field sprite with the battle clips added) | pro, `size=128`, `view="low top-down"`, 8 directions; field clips, then battle clips | Chrono Trigger chibi, about 3.5 heads tall (Crono 95 px) | `<id>_field.png` |
| **action** | action sequences and cinematic close-ups: Dual and Triple Tech cut-ins, story beats, the Fair descent, duel intros | pro or v3, `size=256` (or `width`/`height` 256), the directions the sequence needs (often S, W, E only); custom v3 clips per sequence, 8–12 frames | realistic proportions, about 5.5 heads tall (Crono ~120 px in a 256 cell), full costume detail. Reference: `design/images/refs/crono_action_tier_reference.png` | `<id>_action_<clip>.png` |
| **portrait** | dialogue busts, menus | `create_image_pro` 512×512, eight expressions (Batch 5) | painted bust in the character's canvas | `<id>_portrait_<expr>.png` |
| **variant** | the same character in another universe's art style, or a story state | the tier above it, generated again with that canvas's prompt tail (Reference Bible §1.11) and a `style_character_id` of the base sprite so the identity holds | U1 three-ink sumi-e, U2 clay with VHS, U3 ligne claire, U4 stained glass, U5 rubber-hose, U6 cel, U7 gold leaf; states `_debt60`, `_debt20`, `_debt0`, `_broken`, `_salvaged`, `_rewound` | `<id>_<variant>_<tier>.png`, e.g. `sera_u1_field.png`, `crono_debt20_field.png` |

Naming in PixelLab: `TRIGGER <Name> <tier> v1`, and for variants `TRIGGER <Name> <variant> <tier> v1`
(`TRIGGER Crono action v1`, `TRIGGER Sera u1 field v1`). The importer reads the tier and variant from the name.

Which variants exist is a design call per character (Reference Bible §2.6 keeps each character in their own
canvas by default, with Sera's seven ghost layers, Vaelos's forms and the state suffixes as the exceptions);
Nich decides and adds them to the list. Already on the account: a realistic 5.5-head Crono
(`d1df31ab-e2cc-47c7-a8b7-6b293769a293`, "Crono 41 (v3 from pro sprite)") is the **action** tier's base.

## Batch 1: the playable cast and the Prologue's people (U0 watercolour)

| # | Asset key | Request |
|---|---|---|
| 0 | `crono` | IN PROGRESS, template character (PixelLab `8d699d00-eb9f-4da7-a408-a1f70039fa1c`, "Crono 41 (pro, concept)"; has idle, walk, run, hurt, ready, ko). **Remaining:** `getting-up` (revive), `fireball` (release), `picking-up` (interact), attack v3 (`a fast one-handed katana slash from his right side, the brass gauntlet leading, a faint rainbow arc off the blade`), charge v3 4 frames loop (`crouched draw stance, the katana held back, faint clock-wisps gathering`), victory v3 8 frames (`he lowers the katana, exhales, and rests the gauntlet hand on his hip`). |
| 1 | `sera` | IN PROGRESS (PixelLab `ce6ffc25-e512-4312-9d83-a850ab3b561f`, "Sera 17 (pro, concept)"; has idle, walk, run). **Remaining:** `taking-punch`, battle set, attack v3 (`a quick double slash with two clock-hand daggers, ribbons of light trailing`), charge v3 (`she hovers higher, daggers raised, violet light pooling`), victory v3. |
| 2 | `krona` | IN PROGRESS (PixelLab `6af5c834-e7a7-4e8b-83d7-8fb2b4222695`, "Krona (pro, concept)"; has idle, walk). **Remaining:** `running-6-frames`, `taking-punch`, battle set, attack v3 (`a heavy two-handed nodachi slash from high right to low left, ink flicks off the blade`), charge v3 (`iai stance, both nodachi sheathed low, a held breath`), victory v3. |
| 3 | `marle` | **Character, pro, 128, 8-dir.** Concept image `npc_marle.jpg`. Prompt: `Queen Nadia Marle, 40, blonde ponytail, ceremonial blue and cream gown with a fitted bodice, brown boots, a ledger under one arm, tired regal posture, Chrono Trigger hero proportions about 3.5 heads tall, expressive face, strong silhouette, painterly watercolour pixel shading, desaturated`. Anims: field set + `fight-stance-idle-8-frames` + attack (`she draws a small crossbow and fires one bolt`). |
| 4 | `glenn_marshall` | **Character, pro, 128, 8-dir.** Concept image `npc_glenn.jpg`. Prompt: `Glenn, 47, one-armed Marshall of Guardia, grey swept hair and short beard, LEFT sleeve empty and pinned, green cape over white-and-gold plate armour, belts and pouches, a tall cane capped with an old bronze sword hilt in his RIGHT hand, worn boots, Chrono Trigger hero proportions about 3.5 heads tall, expressive weathered face, strong silhouette, painterly watercolour pixel shading, desaturated`. Keep the missing arm in every direction. Anims: `breathing-idle`, `walking` (cane walk), `taking-punch`, `picking-up`. |
| 5 | `magus` | **Character, pro, 128, 8-dir.** Concept image `npc_magus.jpg`. Prompt: `Magus, tall gaunt sorcerer, long silver-lavender hair, one eye blind and clouded with a trail of liquid silver dripping from it, violet high-collared cloak over dark robes, long fingers, Chrono Trigger hero proportions about 4 heads tall, sharp expressive face, strong silhouette, painterly watercolour pixel shading, desaturated`. Keep the blind eye on the same side in every direction. Anims: field set + `fireball` + attack (`he raises one hand and a scythe of violet light sweeps across`). |
| 6 | `vaelos_boy` | **Character, pro, 128, 8-dir.** Concept image `enemy_vaelos.jpg` (the adult; make him a boy). Prompt: `a boy of about ten who looks like Crono's son, pale alabaster skin with faint hairline cracks that leak points of starlight, short red-and-silver hair, simple cream tunic and bare feet, calm unsettling smile, Chrono Trigger child proportions about 3 heads tall, painterly watercolour pixel shading, desaturated`. Anims: `breathing-idle`, `walking`, `picking-up`. |
| 7 | `vaelos` (Sovereign) | **Pro Flash character, 256×256, 8-dir, template `custom`** (he is nine feet tall; the importer scales by `height_m` = 2.74). Style image: a 256-px crop of `enemy_vaelos.jpg` is too large for Pro Flash, so give the full prompt and use `style_image` = Crono's south rotation URL for the pixel look. Prompt: `Vaelos, nine-foot androgynous humanoid Lavos grown from Crono's atoms, cracked alabaster skin leaking starlight, a fibre-optic mane of light, a mantle of fossilised saurian bones with server blades and shards of stained glass, long elegant hands, serene cruel face like an older Crono, tall imposing silhouette, painterly watercolour pixel shading, desaturated, violet accents`. Anims: `breathing-idle`, `walking`, `fight-stance-idle-8-frames`, `fireball`, attack (`he extends one arm and a spear of starlight erupts forward`). |
| 8 | `villager_m`, `villager_f`, `child`, `elder`, `guard`, `merchant` | Six **characters, pro, 128, 8-dir**, `style_character_id` = Crono's id, no concept image. Prompts: `a Guardia townsman in a brown tunic and cap carrying a basket`; `a Guardia townswoman in a green dress and apron with a shawl`; `a Guardia child in a yellow smock with a wooden sword`; `a white-bearded elder in a grey robe leaning on a stick`; `a Guardia castle guard in blue-and-silver mail with a halberd and a plumed helm`; `a plump merchant in a red waistcoat with a money pouch and a ledger`; each ending `Chrono Trigger NPC proportions about 3.5 heads tall, friendly readable face, painterly watercolour pixel shading, desaturated`. Anims: `breathing-idle`, `walking` only. |

## Batch 2: the Prologue and Chapter 1 enemies (U0)

All at `size=128` unless noted; these are creatures, so use `create_character_pro_flash` (template `custom`
unless a better template fits) or `create_8_direction_object`. Anims: `breathing-idle` plus one attack clip
described in the prompt, plus `taking-punch`.

| # | Asset key | Prompt |
|---|---|---|
| 9 | `enm_u0_dust_mote_cluster` | `a cluster of seven glowing dust motes orbiting a faint ring of light in a kitchen, soft gold and cream, small (about 48 px), painterly watercolour pixel art`; attack: `the motes rush inward and burst outward in a wash`. |
| 10 | `enm_u0_porcelain_shardling` | `a small porcelain imp made of a broken doll's shards, spiky red-hair fragment on its head, one blue glass eye, jagged white body with gold cracks, about 64 px, painterly watercolour pixel art`; attack: `it lunges and slashes with a shard arm`. |
| 11 | `enm_u0_ashen_spoon` | `a wooden kitchen spoon come alive as a sumi-e brush creature, its bowl a dripping ink brush head, thin legs of dry brush strokes, three inks only: bone white, soot grey, arterial crimson, about 64 px, pixel art`; attack: `it whips its brush head and flings ink`. |
| 12 | `vaelos_echo` | `an intangible shadow silhouette of a spiky-haired boy made of dark translucent smoke with points of starlight inside, no face, edges breaking into flickering frames, about 96 px, painterly watercolour pixel art`; attack: `it reaches out and the air around its hand stutters`. |
| 13 | `enm_u0_trance_bellkeeper` | `a slender porcelain bell-ringer automaton carrying a brass handbell, a single crack along its jawline, cream robes with brass fittings, calm closed eyes, about 110 px, painterly watercolour pixel art`; attack: `it raises the bell and rings it, sound rings spread`. |
| 14 | `enm_u0_gato_ruin` | `a ruined carnival boxing robot shaped like a round cat, cracked porcelain and brass, a dented chest plate with faded serial lettering, one red eye, spring-loaded punching gloves, about 120 px, painterly watercolour pixel art`; attack: `a heavy telegraphed glove punch`. |
| 15 | `enm_u0_debtling` | `a swarm of five tiny cracked porcelain doll heads with spiky red hair scuttling on little spider legs, gold crack lines, about 48 px, painterly watercolour pixel art`; attack: `the heads leap and bite`. |
| 16 | `enm_u0_moss_mouse` | `a round grey mouse with moss and tiny mushrooms growing on its back, bright black eyes, about 48 px, painterly watercolour pixel art` (template `custom`, or `dog` posed small); attack: `it darts forward and nips`. |
| 17 | `enm_u0_bekkler_fragment` | `a rubber-hose cartoon doll fragment: one white-gloved arm and half a grinning painted face on a bouncing spring body, 1930s cartoon style with a watercolour wash, about 80 px, pixel art`; attack: `it stretches 300% and snaps back like an accordion`. |
| 18 | `enm_u0_ashen_echo_krona` | `a dry-brush sumi-e silhouette of a woman with a war-knot of hair and two long swords, no face, soot grey ink with crimson accents on bone white, about 110 px, pixel art`; attack: `a wide ink slash that leaves wet ink on the ground`. |
| 19 | `enm_u0_ferro_drone_09` | `a brass six-legged spider drone with a gramophone horn head and a glowing mercury orb in its belly, clay-and-brass look with VHS scanlines, about 90 px, pixel art`; attack: `the horn emits a cone of sound rings`. |

## Batch 3: the two U0 bosses (large)

| # | Asset key | Prompt |
|---|---|---|
| 20 | `bos_u0_atrium_cradle` | **Pro Flash character, 256×256, 8-dir, template `custom`** (3.2 m tall; `create_8_direction_object` at 168 is the fallback). Concept: `enemy_arch_curator_r_66y.jpg` as a smaller proto version (describe it; Pro Flash takes no concept image). Prompt: `a prototype Arch-Curator: a hulking robot on six brass insect legs, a rotating thoracic ring of eight gun barrels, a porcelain theatre-mask face with one sorrowful blue eye, copper vines and oil, peeled chassis showing red muscle fibre, painterly watercolour pixel art with clay-and-brass detail`. Anims: `breathing-idle` (the ring turns), attack (`the barrel ring spins and fires a volley`), `taking-punch`, `falling-back-death` (legs fold). |
| 21 | `enm_u0_training_dummy_prime` (the 999 Shard Doll) | **Pro Flash character, 192×192, 8-dir, template `custom`** (2.0 m tall; pro mode cannot exceed 128). Describe the Crono doll from `playable_crono.jpg`. Prompt: `a life-size porcelain Bekkler doll of Crono with goggles pushed up and a glowing Time Egg replica set in its chest, standing on six reverse-jointed brass spider legs, a tungsten bracer on one arm and a mercury-silver shoulder, small porcelain masks orbiting its collar, giggling expression, gold cracks, painterly watercolour pixel art`. Anims: `breathing-idle` (head tilt), attack (`it rears up and stamps with two legs`), `taking-punch`, `falling-back-death` (cracks open on a galaxy inside). |

## Batch 4: Chapter 2 (U1 Crimson Shogunate, sumi-e)

Requested once Batch 1–3 are in. The build agent adds the U1 enemy list, the Krona duel-boss variant and the
Ashen Daimyo here with prompts in the three-ink sumi-e style when Chapter 2 scene work starts.

## Batch 5: portraits (dialogue busts)

`create_image_pro`, 512×512, transparent, one call per expression with the catalog image as a labelled
reference (`usage: "character base"`). Expressions, in this order: neutral, sad, angry, surprised, smile, hurt,
special_a, special_b. Import target `assets/portraits/<id>/<id>_<expr>.png` (the game looks there first).
Order: crono, sera, marle, robo, glenn, magus, krona (U1 four-ink prompt tail), vaelos, lucca, bekkler.
Prompt tails per canvas are in Reference Bible §1.11; identity blocks in §4 and §5.

## Batch 6: Prologue props and the Atrium (billboards, `create_1_direction_object` or `create_object_pro_flash`, `view="low top-down"`)

128 px unless noted, transparent, U0 watercolour tail. Kitchen: copper porridge pot on a hook, stone counter
with two porcelain bowls, long oak table, three-legged stool with an ink-burned groove, brass speaking tube,
copper pots on a shelf, a hearth with embers (3-frame flicker), stained-glass window panel (texture, 128×192).
Courtyard: stone well, hand cart, moss flower bed, iron portcullis. Atrium Horologe (Reference Bible §3.2,
§5.4.3, plate-00): the clock pillar face 256, brass gate arch 256, the Seed of Doan pot (§5.7.7), gramophone
on a workbench (§5.7.5), the little Bekkler doll, dummy plinth, reflecting pool rim tiles, loft ladder, Robo's
rest alcove.

## Batch 7: U0 textures (tileable, 64 px/m, `create_image_pixen` or `pro` at 256×256 then tiled; a `_normal` from the importer)

castle_flagstone, castle_wall_block, oak_plank, oak_beam, slate_roof, brass_panel, cobble_wet, grass_moss,
dirt_path, fair_canvas_stripe, stone_steps, plaster_cream. Import target `assets/textures/generated/<name>_albedo.png`
(the game looks there first).

## Batch 8: UI (`create_ui_asset` and `create_image_pro` icons; Reference Bible §6 and the UI prompt tail)

Dialogue frame 9-slice, menu frame, tooltip frame, cursor hand 16, target cursor 24, nine element icons 32
(astral, tachyon, ruin, ferro, mycelia, vitreous, guile, hz, null; shape as well as colour), ten status icons
16 (bleed, burn, slow, haste, seal, break, guard, stagger, oil_blight, rewound), HP/BP/turn gauges, shield plate
housing 48×24 with the key glyphs. Import target `assets/ui/generated/`.

## Batch 9: VFX flipbooks (`animate_image`, 128 cells, additive where noted)

Element hits ×9 (8 frames each), Break shatter 12 (additive), plate crack 6, perfect-parry flash 4, Crono tech
wisps 4 (loop) and Smear Dash trail 4, Sera Rewind glyph 8 and fast-forward streaks 6, Krona ink splash 8 and
wet-ink zone 6 (loop). Import target `assets/vfx/generated/<family>/<id>_fb_<n>f.png`.

## Done

| Asset key | PixelLab id | Imported | Notes |
|---|---|---|---|
| `crono` (field: idle, walk, run, hurt, ready, ko) | `8d699d00-eb9f-4da7-a408-a1f70039fa1c` | 2026-10-29 | the template; battle clips still listed above as #0 |
