# Asset requests for Nich's PixelLab bot

Nich makes the art. Each entry below is a ready-to-send PixelLab request. The build agent imports finished
items with `python3 tools/art/pipeline/build_characters.py <asset_key>` (see `docs/ART_PIPELINE.md`) and marks
the entry DONE with the PixelLab id. Keep this list in priority order; the first undone entry is the most
urgent.

## How to send one

- **Characters** (anything that walks): `create_character` in **pro** mode, `size=128`, `view="low top-down"`,
  8 directions, name it `TRIGGER <Name> v1` (v2, v3 for retries), `concept_image_url` = the catalog image
  link given, `description` = the prompt given. For the house style, add `style_character_id` =
  Crono's id `8d699d00-eb9f-4da7-a408-a1f70039fa1c` whenever there is no catalog image.
- Then queue the **animations** listed, one or two at a time (`animate_character`, pass `animation_name`):
  field set = `breathing-idle`, `walking`, `running-6-frames`, `taking-punch`; battle set adds
  `fight-stance-idle-8-frames`, `falling-back-death`, `getting-up`, `fireball` (tech release), `picking-up`
  (interact), plus a custom v3 **attack** (8 frames, weapon in the description).
- **Creatures and things that do not walk like a person** (motes, drones, spoons, a cat robot): use
  `create_character_pro_flash` with the right `template_id` (`cat`, `dog`, `custom`) or
  `create_8_direction_object`; same size, same view, same naming.
- Every prompt below already carries the style line. Keep the flat background.

Catalog images live at `https://raw.githubusercontent.com/iteatsthesalt/TRIGGER-Time-Debt/main/design/images/catalog/<file>.jpg`.

## Batch 1: the playable cast and the Prologue's people (U0 watercolour)

| # | Asset key | Request |
|---|---|---|
| 1 | `sera` | IN PROGRESS by the build agent (PixelLab `ce6ffc25-…`). Skip unless the agent asks for a v2. |
| 2 | `krona` | **Character, pro, 128, 8-dir.** Concept image `playable_krona.jpg`. Prompt: `Krona, ageless woman who looks early thirties, female mirror of Crono, spiky red hair tied in a war-knot with white ties, tired eyes, cheek scar, cracked black lacquered o-yoroi with a melted pauldron, red sash, tattered dry-brush cape, dripping gourd at the hip, bare feet, two long nodachi of snapped steel and red chitin on her back, Chrono Trigger hero proportions about 3.5 heads tall, expressive face, strong silhouette, confident pixel shading, sumi-e ink look with three tones: bone white, soot grey, arterial crimson`. Anims: field set + battle set + attack (`a heavy two-handed nodachi slash from high right to low left, ink flicks off the blade`). |
| 3 | `marle` | **Character, pro, 128, 8-dir.** Concept image `npc_marle.jpg`. Prompt: `Queen Nadia Marle, 40, blonde ponytail, ceremonial blue and cream gown with a fitted bodice, brown boots, a ledger under one arm, tired regal posture, Chrono Trigger hero proportions about 3.5 heads tall, expressive face, strong silhouette, painterly watercolour pixel shading, desaturated`. Anims: field set + `fight-stance-idle-8-frames` + attack (`she draws a small crossbow and fires one bolt`). |
| 4 | `glenn_marshall` | **Character, pro, 128, 8-dir.** Concept image `npc_glenn.jpg`. Prompt: `Glenn, 47, one-armed Marshall of Guardia, grey swept hair and short beard, LEFT sleeve empty and pinned, green cape over white-and-gold plate armour, belts and pouches, a tall cane capped with an old bronze sword hilt in his RIGHT hand, worn boots, Chrono Trigger hero proportions about 3.5 heads tall, expressive weathered face, strong silhouette, painterly watercolour pixel shading, desaturated`. Keep the missing arm in every direction. Anims: `breathing-idle`, `walking` (cane walk), `taking-punch`, `picking-up`. |
| 5 | `magus` | **Character, pro, 128, 8-dir.** Concept image `npc_magus.jpg`. Prompt: `Magus, tall gaunt sorcerer, long silver-lavender hair, one eye blind and clouded with a trail of liquid silver dripping from it, violet high-collared cloak over dark robes, long fingers, Chrono Trigger hero proportions about 4 heads tall, sharp expressive face, strong silhouette, painterly watercolour pixel shading, desaturated`. Keep the blind eye on the same side in every direction. Anims: field set + `fireball` + attack (`he raises one hand and a scythe of violet light sweeps across`). |
| 6 | `vaelos_boy` | **Character, pro, 128, 8-dir.** Concept image `enemy_vaelos.jpg` (the adult; make him a boy). Prompt: `a boy of about ten who looks like Crono's son, pale alabaster skin with faint hairline cracks that leak points of starlight, short red-and-silver hair, simple cream tunic and bare feet, calm unsettling smile, Chrono Trigger child proportions about 3 heads tall, painterly watercolour pixel shading, desaturated`. Anims: `breathing-idle`, `walking`, `picking-up`. |
| 7 | `vaelos` (Sovereign) | **Character, pro, 128, 8-dir** (he is nine feet tall: ask for `height` so he fills the canvas; the importer scales by `height_m`). Concept image `enemy_vaelos.jpg`. Prompt: `Vaelos, nine-foot androgynous humanoid Lavos grown from Crono's atoms, cracked alabaster skin leaking starlight, a fibre-optic mane of light, a mantle of fossilised saurian bones with server blades and shards of stained glass, long elegant hands, serene cruel face like an older Crono, tall imposing silhouette, painterly watercolour pixel shading, desaturated, violet accents`. Anims: `breathing-idle`, `walking`, `fight-stance-idle-8-frames`, `fireball`, attack (`he extends one arm and a spear of starlight erupts forward`). |
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
| 20 | `bos_u0_atrium_cradle` | **Object or character, 8-dir, `size=256`.** Concept image `enemy_arch_curator_r_66y.jpg` (a smaller proto version). Prompt: `a prototype Arch-Curator: a hulking robot on six brass insect legs, a rotating thoracic ring of eight gun barrels, a porcelain theatre-mask face with one sorrowful blue eye, copper vines and oil, peeled chassis showing red muscle fibre, painterly watercolour pixel art with clay-and-brass detail`. Anims: `breathing-idle` (the ring turns), attack (`the barrel ring spins and fires a volley`), `taking-punch`, `falling-back-death` (legs fold). |
| 21 | `enm_u0_training_dummy_prime` (the 999 Shard Doll) | **Character, pro, `size=192`, 8-dir.** Concept image `playable_crono.jpg`. Prompt: `a life-size porcelain Bekkler doll of Crono with goggles pushed up and a glowing Time Egg replica set in its chest, standing on six reverse-jointed brass spider legs, a tungsten bracer on one arm and a mercury-silver shoulder, small porcelain masks orbiting its collar, giggling expression, gold cracks, painterly watercolour pixel art`. Anims: `breathing-idle` (head tilt), attack (`it rears up and stamps with two legs`), `taking-punch`, `falling-back-death` (cracks open on a galaxy inside). |

## Batch 4: Chapter 2 (U1 Crimson Shogunate, sumi-e)

Requested once Batch 1–3 are in. The build agent will add the U1 enemy list and the Ashen Daimyo here with
prompts in the three-ink sumi-e style.

## Done

(The build agent moves entries here with the PixelLab id and the import date.)
