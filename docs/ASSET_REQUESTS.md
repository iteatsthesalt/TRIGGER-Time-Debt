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
| **action** | action sequences and cinematic close-ups: Dual and Triple Tech cut-ins, story beats, the Fair descent, duel intros | one PixelLab character per character (`create_character` v3 with the action-tier base as `reference_image_url`, `size=256`, or Pro Flash 256), with the directions the sequence needs (often S, W, E only); each sequence is a custom v3 clip (`animate_character`, `animation_name` = the clip name below, 8–12 frames) on that one character | realistic proportions, about 5.5 heads tall (Crono ~120 px in a 256 cell), full costume detail. Reference: `design/images/refs/crono_action_tier_reference.png` | `<id>_action.png` (every clip is a column group in that one sheet; the importer names them from `animation_name`) |
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
| 2 | `krona` | IN PROGRESS (PixelLab `6af5c834-e7a7-4e8b-83d7-8fb2b4222695`, "Krona (pro, concept)", nodachi in hand; has idle, walk; this is the one wired in). The bot's `364e2216-2931-4644-b149-9a2cca9f2abd` (nodachi on her back) is kept as an alternative; **Nich picks**. Add the remaining clips to whichever he picks and tell the build agent the id. **Remaining:** `running-6-frames`, `taking-punch`, battle set, attack v3 (`a heavy two-handed nodachi slash from high right to low left, ink flicks off the blade`), charge v3 (`iai stance, both nodachi sheathed low, a held breath`), victory v3. |
| 3 | `marle` | **ON THE ACCOUNT as `npc_marle` (`05c8ee87-ac36-41af-870a-f1bf8bc4dabc`), imported as `marle_field` (idle only).** It is realistic 5.5-head (124 px) while the cast is 3.5-head chibi: **Nich to decide** — either accept it as her field sprite (it will read taller and more detailed than Crono beside her), or make a v2 with the proportion line below for field and keep this one as `marle` **action** base. Anims still needed either way: `breathing-idle`, `walking`, `taking-punch`, `picking-up`. Original request: **Character, pro, 128, 8-dir.** Concept image `npc_marle.jpg`. Prompt: `Queen Nadia Marle, 40, blonde ponytail, ceremonial blue and cream gown with a fitted bodice, brown boots, a ledger under one arm, tired regal posture, Chrono Trigger hero proportions about 3.5 heads tall, expressive face, strong silhouette, painterly watercolour pixel shading, desaturated`. Anims: field set + `fight-stance-idle-8-frames` + attack (`she draws a small crossbow and fires one bolt`). |
| 4 | `glenn_marshall` | **Character, pro, 128, 8-dir.** Concept image `npc_glenn.jpg`. Prompt: `Glenn, 47, one-armed Marshall of Guardia, grey swept hair and short beard, LEFT sleeve empty and pinned, green cape over white-and-gold plate armour, belts and pouches, a tall cane capped with an old bronze sword hilt in his RIGHT hand, worn boots, Chrono Trigger hero proportions about 3.5 heads tall, expressive weathered face, strong silhouette, painterly watercolour pixel shading, desaturated`. Keep the missing arm in every direction. Anims: `breathing-idle`, `walking` (cane walk), `taking-punch`, `picking-up`. |
| 5 | `magus` | **Character, pro, 128, 8-dir.** Concept image `npc_magus.jpg`. Prompt: `Magus, tall gaunt sorcerer, long silver-lavender hair, one eye blind and clouded with a trail of liquid silver dripping from it, violet high-collared cloak over dark robes, long fingers, Chrono Trigger hero proportions about 4 heads tall, sharp expressive face, strong silhouette, painterly watercolour pixel shading, desaturated`. Keep the blind eye on the same side in every direction. Anims: field set + `fireball` + attack (`he raises one hand and a scythe of violet light sweeps across`). |
| 6 | `vaelos_boy` | **Character, pro, 128, 8-dir.** Concept image `enemy_vaelos.jpg` (the adult; make him a boy). Prompt: `a boy of about ten who looks like Crono's son, pale alabaster skin with faint hairline cracks that leak points of starlight, short red-and-silver hair, simple cream tunic and bare feet, calm unsettling smile, Chrono Trigger child proportions about 3 heads tall, painterly watercolour pixel shading, desaturated`. Anims: `breathing-idle`, `walking`, `picking-up`. |
| 7 | `vaelos` (Sovereign) | **Pro Flash character, 256×256, 8-dir, template `custom`** (he is nine feet tall; the importer scales by `height_m` = 2.74). Style image: a 256-px crop of `enemy_vaelos.jpg` is too large for Pro Flash, so give the full prompt and use `style_image` = Crono's south rotation URL for the pixel look. Prompt: `Vaelos, nine-foot androgynous humanoid Lavos grown from Crono's atoms, cracked alabaster skin leaking starlight, a fibre-optic mane of light, a mantle of fossilised saurian bones with server blades and shards of stained glass, long elegant hands, serene cruel face like an older Crono, tall imposing silhouette, painterly watercolour pixel shading, desaturated, violet accents`. Anims: `breathing-idle`, `walking`, `fight-stance-idle-8-frames`, `fireball`, attack (`he extends one arm and a spear of starlight erupts forward`). |
| 8 | `villager_m` (**on the account: `feef7cc5-0f0f-4dac-a678-e71d1e42961a`, import pending its animation jobs**), `villager_f`, `child`, `elder`, `guard`, `merchant` | Six **characters, pro, 128, 8-dir**, `style_character_id` = Crono's id, no concept image. Prompts: `a Guardia townsman in a brown tunic and cap carrying a basket`; `a Guardia townswoman in a green dress and apron with a shawl`; `a Guardia child in a yellow smock with a wooden sword`; `a white-bearded elder in a grey robe leaning on a stick`; `a Guardia castle guard in blue-and-silver mail with a halberd and a plumed helm`; `a plump merchant in a red waistcoat with a money pouch and a ledger`; each ending `Chrono Trigger NPC proportions about 3.5 heads tall, friendly readable face, painterly watercolour pixel shading, desaturated`. Anims: `breathing-idle`, `walking` only. |

## Batch 1b: action tier for the vertical slice (256 px, realistic 5.5-head, custom v3 clips)

One action-tier character per hero, named `TRIGGER <Name> action v1`; the base for Crono exists
(`d1df31ab-e2cc-47c7-a8b7-6b293769a293`, imported as `crono_action`, idle only). For Sera and Krona make the
base first (pro image of the catalog painting at realistic proportions, then v3 rotation, or Pro Flash 256 with
the painting described), then queue the clips with `animation_name` set to the clip name. Directions: south,
west, east unless noted.

| # | Asset key / clip | Request |
|---|---|---|
| A1 | `crono` action · `smear_dash` | 8 frames. `Crono drops into a low draw stance and dashes forward in a blur, the katana trailing a smeared desaturated red-to-blue paint streak, afterimages of himself a few frames behind, watercolour drag at every edge`. Used for Astral Smear Dash and the Prologue bowl catch. |
| A2 | `crono` action · `katana_cross` | 8 frames. `Crono steps in and cuts a long diagonal from high right to low left with the gauntlet arm, then a return cut forming an X, a faint rainbow arc off the blade`. The Crono half of Eclipse X-Strike. |
| A3 | `sera` action base + `chronoslip_fall` | base first; then 12 frames. `Sera stumbles mid-air, her outline stuttering between frames, violet light flickering across her and the clock-hand daggers slipping from her hands, then she folds and falls`. The Prologue Chronoslip collapse. |
| A4 | `sera` action · `rewind_cast` | 8 frames. `Sera hovers higher, both daggers raised, violet clock glyphs spinning backwards around her wrists`. The Rewind cut-in. |
| A5 | `krona` action base + `ink_cross` | base first (realistic Krona from `playable_krona.jpg`, nodachi in hand); then 8 frames. `Krona crosses both nodachi overhead and brings them down in a scissor cut, black ink flicking off the blades, a wet ink splash where they meet`. The Krona half of Eclipse X-Strike; the two halves are composited by the engine. |
| A6 | `krona` action · `iai_hold` | 6 frames, loop. `Krona in iai stance, both nodachi sheathed low, hair ties lifting in a held breath, ink dripping from the gourd`. Cobalt Nodachi charge. |
| A7 | `vaelos` action · `fair_descent` | base = the Sovereign (Batch 1 #7, Pro Flash 256), south only; 12 frames. `Vaelos descends slowly from above with his arms open, the fibre-optic mane streaming upward and shifting through painting styles, starlight leaking from the cracks in his alabaster skin, bone mantle settling as his feet touch the ground`. The Fair descent (Chapter 1 beat 10). |

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

## Batch 4: Chapter 2, the Crimson Shogunate (U1, sumi-e)

The whole of U1: its people, creatures, bosses, landmarks, world kit and textures. Everything here is drawn
in **four inks only**: sumi black `#1A1A1A`, cobalt `#0D2640`, cinnabar `#8C1D18` (fire and banners), paper
white `#F2EED8`. No gold, no grey gradients, dither inside the ink instead. Luminance is ink density. End
every prompt with the U1 tail: `sumi-e and ukiyo-e woodblock on washi, four inks only: sumi black, cobalt,
cinnabar, paper white, dry-brush edges, pixel art`. Deliver per `docs/BOT_REVIEW.md`.

### 4a. People (characters, pro, 128, 8-dir, `style_character_id` = Krona's `6af5c834-e7a7-4e8b-83d7-8fb2b4222695`)

| # | Asset key | Prompt and clips |
|---|---|---|
| 22 | `krona_duel` (boss variant of Krona) | Same identity as Krona's field sprite but **armed**: `Krona in cracked black lacquered o-yoroi with the melted pauldron, war-knot hair, two long nodachi of snapped steel and red chitin drawn and ready, oil dripping from the hip gourd, bare feet planted in wet ink`. Clips: `fight-stance-idle-8-frames`, attack (`a two-handed overhead nodachi cut that splashes ink`), a second attack (`a low sweeping slash from right to left`), `taking-punch`, `falling-back-death` (she kneels, not dies), v3 **disarm** (6 frames: `she lowers both blades and lets one fall`). |
| 23 | `krona_retainer_a`, `krona_retainer_b`, `krona_retainer_c` | Three retainers: `a half-corroded samurai retainer in cracked lacquered armour, a plain paper mask over the face with the lacquer flaking at the edges, kneeling-stiff posture, oil stains at the joints` (vary: spear, bow, bare hands). Clips: `breathing-idle` only (they kneel). |
| 24 | `u1_citizen_m`, `u1_citizen_f`, `u1_painter`, `u1_child` | Kuro-Truce townsfolk: `a townsman in a plain paper mask and indigo work robe carrying a bucket of white paint`; `a townswoman in a paper mask and grey kimono with a brush`; `a gate painter on a short ladder with a wide brush, white paint dripping`; `a child in a paper mask too big for its face, holding a paper crane`. Clips: `breathing-idle`, `walking`. |
| 25 | `lord_ashinaga_npc` (the Daimyo before the fight, seated) | `an old daimyo seated on a dais in black court robes with a cinnabar mon, writing with a long brush, face hidden by a paper mask that is a surrender petition, armour at the joints weeping black oil`. Clips: `breathing-idle` (writing). Used for the throne-room approach; the fight uses #35. |

### 4b. Enemies (`create_character_pro_flash`, 128, `template_id="custom"` unless noted; clips `breathing-idle`, the attack described, `taking-punch`)

| # | Asset key | Prompt |
|---|---|---|
| 26 | `enm_u1_ashen_ashigaru` | `a foot soldier in armour made of folded paper plates lacquered black, a conical paper hat, a plain white mask, a short yari spear, ash on the shoulders, about 100 px`; attack: `a quick spear thrust`; extra v3 clip **repaint** (4 frames: `he slaps fresh white paper over his own chest plate`). |
| 27 | `enm_u1_porcelain_captain` | `a taller ashigaru captain in cracked porcelain armour over paper, a cinnabar sashimono banner on his back, a katana, a mask with one crack from brow to jaw, about 110 px`; attack: `a commanding katana cut`. |
| 28 | `enm_u1_ink_calligrapher` | `a robed scribe with a brush taller than himself, sleeves soaked black, writing in the air, the strokes he leaves hang as wet black kanji, about 100 px`; attack: `he writes a single huge kanji that slams forward`. |
| 29 | `enm_u1_gourd_bloated_heimin` | `a peasant swollen and shiny with oil, a gourd fused to his belly, skin cracking like lacquer with black oil in the cracks, slow and sad, about 100 px`; attack: `he lurches and bursts into a cloud of ash`. Add `falling-back-death` (the burst). |
| 30 | `enm_u1_surrender_petition_yokai` | `a surrender petition folded into an origami yokai, a paper body with brushed kanji showing through, a seal stamp for a face, hovering, about 90 px`; attack: `it unfolds flat and snaps shut around the target`. |
| 31 | `enm_u1_crimson_banner_samurai` | `an elite samurai in full black lacquered armour carrying a tall cinnabar war banner, mask with a drawn snarl, katana sheathed, about 112 px`; attack: v3 (8 frames: `he holds a frozen ink pose for a long beat, then draws and cuts in one stroke`); the hold must read as a telegraph. |
| 32 | `enm_u1_omen_crow` (template `custom`, flying) | `a large crow whose feathers are strips of VHS tape and scanline static, eyes of white noise, perched then flaring, about 80 px wide`; attack: `it flares its wings and a burst of static blinds`. |
| 33 | `enm_u1_imp_crackle` | `a small sumi-ink imp made of a single splashed brush stroke with two white dot eyes, trailing wet ink on the floor, about 56 px`; attack: `it skids and paints a black streak`. |
| 34 | `enm_u1_shogun_memory_flame` (field boss, 256) | `a column of living cinnabar fire in the rough shape of a kneeling shogun, armour outlines in the flames, a paper mask floating where the face would be, about 200 px tall`; attack: `the flame rears and sweeps a burning sleeve`. Clips: `breathing-idle` (flame loop), attack, `taking-punch`, `falling-back-death` (gutters out). |

### 4c. Bosses (`create_character_pro_flash` or `create_8_direction_object`, 256 unless noted)

| # | Asset key | Prompt |
|---|---|---|
| 35 | `bos_u1_ashen_daimyo` (256; phases are the same body) | `Lord Ashinaga the Ashen Daimyo: a twenty-foot seated giant whose whole body is thousands of folded surrender petitions stacked and bound into the shape of a daimyo in court armour, brush in hand, armour joints weeping black oil, fire licking the floor around him, a gourd-shaped shadow where his heart is`. Clips: `breathing-idle` (writing), attack **scribe** (`he finishes a petition and flicks it off the brush`), attack **roof** (`he raises both arms and fire breathes across the floor`), `taking-punch` (petitions scatter), **crack** v3 (6 frames: `his chest cracks open to show a glowing gourd heart`), `falling-back-death` (he comes apart as porcelain over red fibre). |
| 36 | `bos_u1_weeping_shogun` (256, concept image `enemy_weeping_shogun.jpg`) | Two bodies in one: `the Weeping Shogun: the lower body a black sumi-ink Lavos spawn with spiked brush-stroke legs, fused at a ragged seam to a brass and clay clockwork centipede with segmented armour and a weeping porcelain face; the ink half brushed, the clay half with visible thumbprints and VHS scanlines`. Clips: `breathing-idle`, attack **ink** (`the ink legs rake forward`), attack **clay** (`the centipede head slams down`), `taking-punch`, `falling-back-death` (the two halves fall apart in opposite directions). The importer splits the ink and clay halves by colour if you also deliver a mask; otherwise one sheet is fine. |

### 4d. Landmarks and props (`create_1_direction_object` or `create_object_pro_flash`, `view="low top-down"`, transparent)

| # | Asset key | Prompt |
|---|---|---|
| 37 | `prp_u1_leene_bell_guillotine` (256) | `a tall execution guillotine whose blade and frame are cast from a melted bronze bell, black lacquered timber, cinnabar paint, bell inscriptions still visible on the blade`. |
| 38 | `prp_u1_sera_cage` (256, concept image `prop_sera_geometric_cage.jpg`) | `a hexagonal birdcage-like prison of black iron bars hanging from chains, red glints on the bars, geometric facets, ink and clay mixed media`. Add a 4-frame **swing** clip. |
| 39 | `prp_u1_clay_gear` (256) | `a house-sized clockwork gear of thumbprinted grey clay, half buried in a shattered pagoda roof of black chitin tiles, turning slowly, one burned jetbike wheel wedged in its teeth`. Add a 4-frame **turn** clip stepping at 12 fps feel. |
| 40 | `prp_u1_torii` (256) | `a mossy wooden torii gate in black ink with cinnabar paint flaking, a paper charm hanging from the crossbeam`. |
| 41 | `prp_u1_petitions_banners` (128, three objects) | `a stack of surrender petition scrolls tied with black cord`; `a tall cinnabar war banner with a black mon on a bamboo pole`; `a paper lantern painted bone white, unlit`. |
| 42 | `prp_u1_sake_gourd` (64) | `a dripping hip gourd of dark lacquered wood with a cord, black oil beading at the stopper`. |
| 43 | `prp_u1_vault_blade_stand` (128) | `a sword stand of black lacquer holding one long nodachi whose blade is a single stroke of deep cobalt blue`. |
| 44 | `prp_u1_dojo_set` (128, four objects) | `a burned tatami mat with one clean corner`; `a weapon rack of charred wood with two katana`; `a kneeling cushion of grey cloth`; `a rusted katana on an oil-stained cloth`. |
| 45 | `prp_u1_street_set` (128, six objects) | `a paper-screen door freshly painted bone white with paste still wet`; `the same door with the paper peeled, char and small soot handprints beneath`; `a wooden bucket of white paint with a brush`; `a ladder of dark timber`; `a stone lantern with a cinnabar paper panel`; `a stack of charred roof tiles`. |
| 46 | `prp_u1_pagoda_finial` (128) | `a horned finial of black chitin from a pagoda roof, cracked, cinnabar under the curve`. |

### 4e. World kit (tilesets and tiles: `create_topdown_tileset`, `create_isometric_tile` 128, or `create_image_pixen` tileable 256; delivered as PNG under `assets/incoming/`)

| # | Asset key | What |
|---|---|---|
| 47 | `tex_u1_ink_ground` | tileable ground of wet black ink with faint paper fibre showing through; a second tile `tex_u1_ink_ground_burned` of the same ground scorched to golden watercolour (the Astral burn result). |
| 48 | `tex_u1_washi_floor` | tileable floor of white washi paper over dark boards (the castle's paper floors), subtle brush texture. |
| 49 | `tex_u1_castle_wall` | tileable plaster-and-timber castle wall in black ink lines on paper white, cinnabar trim strip; a `_burned` variant with char climbing from the bottom. |
| 50 | `tex_u1_iron_bridge_deck` | tileable dark timber planks with black iron strapping. |
| 51 | `tex_u1_carved_waves` | tileable water as carved ukiyo-e wave lines in cobalt on paper white, never transparent. |
| 52 | `tex_u1_bamboo_wall` | tileable wall of black ink bamboo stalks with cinnabar leaves (for the grove's edges). |
| 53 | `tex_u1_street_cobble` | tileable cobbles as ink outlines with dither, ash in the joints. |
| 54 | `tex_u1_roof_chitin` | tileable roof of black insect-chitin scales with a cobalt sheen line. |
| 55 | `tiles_u1_kuro_truce` | a top-down tileset: ink ground → street cobble → washi floor transitions (`create_topdown_tileset` chained), for the streets. |
| 56 | `tiles_u1_hinterlands` | a top-down tileset: paper-white negative space → faint mountain wash → mossy ground, for the Hinterlands. |

### 4f. U1 VFX and Krona's signatures (`animate_image`, 128 cells, four inks; `create_image_pro` for the first frame)

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

### 4g. Portraits (U1 four-ink busts, 512, eight expressions each, see Batch 5)

krona (if not already done in Batch 5), lord_ashinaga, u1_citizen_m, u1_citizen_f, krona_retainer_a.

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
| `crono_field` (idle, walk, run, hurt, ready, ko) | `8d699d00-eb9f-4da7-a408-a1f70039fa1c` | 2026-10-29 | the template; remaining battle clips listed as #0 |
| `crono_action` (idle only) | `d1df31ab-e2cc-47c7-a8b7-6b293769a293` | 2026-10-29 | the action-tier base; clips A1–A2 pending |
| `sera_field` (idle, walk, run) | `ce6ffc25-e512-4312-9d83-a850ab3b561f` | 2026-10-29 | remaining clips listed as #1 |
| `krona_field` (idle, walk) | `6af5c834-e7a7-4e8b-83d7-8fb2b4222695` | 2026-10-29 | remaining clips listed as #2; alternative `364e2216…` on the account |
| `marle_field` (idle only) | `05c8ee87-ac36-41af-870a-f1bf8bc4dabc` | 2026-10-29 | realistic proportions: see #3 |
