# Art pipeline: PixelLab → game

This file is canonical for getting art into the game: the contract an asset must meet, the import commands,
the sheet layout the engine reads, the after-import checks, the hourly delivery check, and the manifest.
`CLAUDE.md`, `README.md`, `PROGRESS.md`, `docs/ASSET_REQUESTS.md` and `docs/BOT_REVIEW.md` point here instead
of repeating it.

**Who does what.** Nich decides: he approves every concept in Slack `#all-trigger` before it is generated,
picks the anchor and the palette, and accepts or rejects deliveries. The asset team (Nich's bots, coordinated
by Cursor) generates in the shared PixelLab account from `docs/ASSET_REQUESTS.md` and tracks each asset as a
Linear issue (`docs/BOT_REVIEW.md` has the delivery contract). The build lead imports every finished asset
with one command, wires it into the scene that needs it, captures it and records it
(`data/art/pixellab_assets.json`); it generates only what Nich asks for or what proves a route, and logs that
in `source_art/MANIFEST.csv` (§8). Nothing in the PixelLab library is ever deleted.

**Scale (DECISIONS "Direction: the Nov 1 recipe is the style", 2026-11-02).** The world is 32 px per metre
(`SceneKit.PX_PER_M`). Sprites are drawn on a 64x64 canvas, three heads tall: the hero is about 56–61 px for
1.78 m. The template is the hero anchor **"TRIGGER Anchor Crono 64 v1"** (PixelLab
`ca2300bc-7592-4606-8973-32b9bc00056b`), imported as `crono` variant `px64` (61 px = 1.78 m, idle + walk;
`docs/screenshots/22_anchor_crono_px64_lineup.jpg`). Superseded and kept only until their replacements exist:
the Reference Bible's 64 px/m texel (§1.2), the 128 px 3.5-head chibi field tier (Crono `8d699d00…`, 95 px),
the asset team's 256 px "field v3" sets on the account (not imported), and painterly prompt tails for
characters.

## 1. The contract: the 64 px recipe (characters)

| Setting | Value |
|---|---|
| Anchor tool | `create_image_pro`, 64x64, `palette` = the project palette (hex list in `source_art/style_kit/palette_resurrect_64.hex`; Resurrect 64 is the working palette until Nich confirms another), `max_colors` 14 (the breakdown's 12-slot character budget plus trim; never more than 14), `no_background` on, a fixed `seed` (logged), outline **selective outline**, shading basic or medium, detail medium. Generate several candidates (the kit made 16); Nich picks one south-facing sprite. |
| Rotation tool | `create_character` **mode v3**, `reference_image_base64` = the picked south sprite, `size` 64, `n_directions` 8, `view` "low top-down", template mannequin. One generation. For a cast-wide look pass the approved anchor as the style reference; `create_character_state` with `color_palette_from_reference` for outfit and story-state variants so the palette holds. Upload nothing upscaled (run `/unzoom` first). |
| Canvas | **64x64** for anything human-sized (crowd NPCs too: one canvas per asset class, never resized mid-cast). Enemies by size class at the same density: small 64x64, medium 64x128 or 128x64, bosses 128–192 (the breakdown's 1x4 / 1x8 / 3x4 units at 2x). A canvas is `height_m × 32` rounded up to a multiple of 32, plus room for raised arms or a weapon. |
| View | `view="low top-down"` (the game camera pitches about 30° in the field, 35° in battle). |
| Directions | 8 from PixelLab (south, south-west, west, north-west, north, north-east, east, south-east); the breakdown's minimum is four hand-drawn facings. Never mirror an asymmetric design (the hero's gauntlet is on his right arm; the one-armed marshal's left sleeve is empty); mirror only a symmetric creature's missing side. |
| Palette / colours | Every pixel from the project palette; 12–14 colours per character: one dark outline colour per material (a darker, slightly cooler shade of what it encloses), two skin tones, three or four hair tones, two or three per main garment, one trim, one near-white highlight. No gradients, no dither on characters. |
| Outline | Coloured selective outline, lighter on the lit top and left edges, darker on the bottom and right; **no pure black** except where distinct shapes meet (chin against neck). |
| Shading | Flat cel shading, one light from the upper left, two tones per material plus a single-pixel highlight; never pillow-shaded; anti-alias only steps of 2 px or more. |
| Proportions | About three heads tall, short torso, long limbs so poses read; the hair silhouette (rigid triangular clumps, a different clump count and direction per character) is the identifier; detail spent on one prop per character. |
| Height | Judged in metres from the design, not pixels: `height_m` from the kit (`data/characters/<id>.json`), the enemy def, the boss JSON or `--height-m`; the importer sizes the quad so the sprite stands at those metres (hero 1.78 m = 61 px). |
| Naming | `TRIGGER <Name> [<variant>] <tier> v<N>` (`TRIGGER Sera field v1`, `TRIGGER Sera u1 field v1`, `TRIGGER Crono px64 field v1`). The importer reads tier and variant from the name. |
| Background | Transparent (PixelLab default); hard alpha. |
| Prompt | Describe the design and the style, never the game: the design-lock identity block **without the character's name**, then "16-bit JRPG field sprite, three heads tall, large expressive eyes, strong hair silhouette, flat cel shading with one light from upper left, selective dark-coloured outline, two main costume colours plus one accent, standing, south-facing, transparent background". Era cues go in the description ("medieval cloth and leather"); locations stay out of character prompts; animation prompts describe movement only. |
| Negative cues | `negative_description` = "blur, gradient, anti-aliasing, soft shading, photo, 3D render". |
| Never | A Square Enix character or game name in a prompt or a style-reference slot (the breakdown's section 14); a ripped sprite as a base, reference image or inpaint source. |

**Animations** (`animate_character` on the rotated character, `animation_name` = the game name in the first
column; template clips cost one generation per direction, so 8 per clip for eight directions; "v3" means a
custom `action_description` clip in `mode="v3"`, `frame_count` as listed). The breakdown recommends
`ai_freedom` 0 for rigid, consistent template motion.

| Game anim | PixelLab clip | Frames | Who needs it |
|---|---|---|---|
| idle | `breathing-idle` | 4 | everyone |
| walk | `walking` | 6 | everyone who moves (the original: 6 steps for the party, 4 for NPCs) |
| run | `running-6-frames` | 6 | party, chasers |
| hurt | `taking-punch` | 6 | everyone who fights (the hurt flash itself is a shader, not frames) |
| ready | `fight-stance-idle-8-frames` | 8 | party and bosses (battle idle) |
| attack | v3, weapon described | 8 | everyone who fights (the original holds 7 poses) |
| ko | `falling-back-death` | 7 | party, humanoid enemies |
| revive | `getting-up` | 5 | party |
| release | `fireball` | 6 | casters (tech release) |
| charge | v3 "gathering power, loop" | 4 | party |
| interact | `picking-up` | 5 | party |
| victory | v3, one personality beat | 6–8 | party |

Field NPCs need idle + walk. Enemies need idle + attack + hurt (+ ko for humanoids). The party needs the full
table; optional lead beats (`blink`, `nod`, `shake`, `laugh`, `shocked`, 2–4 frames each) are v3 clips added
when Nich asks. Frames are held, never tweened: the engine plays each clip at the `fps` in its frames table
(idle 5, walk 10, run 12, ready 8, attack 14, hurt 12, ko 10, revive 10, release 12, interact 8, charge 8,
victory 8) and per-frame `holds` can slow a clip to the original's cadence (10–15 ticks per walk step), which
is an open tuning item. A direction that comes back facing the wrong way is flagged by the importer
(`WARNING … looks like the <other> rotation`): delete that one direction with `delete_animation(…, direction=)`
and queue it again into the same `animation_group_id`, or inpaint it.

## 1b. A character is a set of sprites: tiers and variants

| Tier | Canvas | Look | Used for | File |
|---|---|---|---|---|
| `field` | **64**, 8 dirs (cell 64 or 96, §3) | the recipe above: three heads, hero 61 px | locations, biomes **and battle** (battle clips are columns of the field sheet) | `<id>_field.png` |
| `map` | to be re-specified at the new scale (the breakdown's overworld unit is 16x16 at 1x, so about 32 px here; 4 dirs, legA / stand / legB / stand) | tiny bold silhouette | the overworld (Chapter 3+) | `<id>_map.png` |
| `action` | to be re-specified (the realistic sheet `crono_action`, `d1df31ab…`, shipped in a **128** px cell with a 120 px figure, one idle column over eight rows; it stays the only one until then) | close-up | Dual/Triple Tech cut-ins, cinematic beats, duel intros, the Fair descent; each sequence is a **clip** = a column group in the one action sheet | `<id>_action.png` |
| `portrait` | **48x48** pixel portrait in the character's own palette family (replaces the 512 painted bust); six expressions in the breakdown (calm, happy, angry, sad, surprised, determined), the exact list fixed with the first portrait request | menu and dialogue bust | dialogue, menus (`PortraitCache` reads `assets/portraits/<id>/<id>_<expr>.png`, any `<expr>`, falls back to `neutral`) | `<id>_portrait_<expr>.png` |

A **variant** is the same character in another canvas (`u1` … `u8`), a story state (`debt60`, `debt20`,
`debt0`, `broken`, `salvaged`, `rewound`, `mask_off`, `oil`, `sealed`, `cobalt`, `gold`, `ghost`) or a canvas
size (`px<size>`), generated as the tier above with that canvas's palette and the base as the style reference
so the identity holds. File: `<id>_<variant>_<tier>.png` (`sera_u1_field.png`, `crono_debt20_field.png`,
`crono_px64_field.png`).

**The px64 transition rule.** A character that already has a 128 px chibi field sheet is imported as the
`px64` variant (`--variant px64`, or `px64` in the PixelLab name) until Nich approves the anchor; the game
keeps shipping the 128 px sheet meanwhile. When he approves, the 64 px sheet becomes the base `field` sheet
(re-run the import without the variant) and the old 128 px sheet, its `_n`, frames json and manifest entry are
deleted. A character with no sheet yet is imported straight as `field`. Today: `crono_px64_field` exists;
`crono_field`, `sera_field`, `krona_field`, `marle_field` are the 128 px sheets still in use
(`docs/screenshots/23_cast_px128_lineup.jpg` beside `22`).

PixelLab names carry tier and variant: `TRIGGER <Name> <tier> v1`, `TRIGGER <Name> <variant> <tier> v1`.
The importer reads them from `--name`, or takes `--tier` / `--variant` explicitly; an unnamed character is
field/base. Every tier/variant sheet has its own `<stem>_frames.json`, `_n` normal sheet and manifest entry
(`<id>[_<variant>]_<tier>`).

Engine: `SpriteLibrary.apply(sprite, id, fps, tier := &"field", variant := &"")` resolves in this order:
the variant's tier, the base tier, the variant's field sheet, the base field sheet, the legacy `_sheet`, the
painted stand-in, a placeholder; it records what it found in `sprite.loaded_tier` / `loaded_variant`.
`ActorSprite.set_tier(&"action")` swaps a live sprite for a cut-in (facing kept, the current animation kept
when the new sheet has it, else idle) and returns false when it had to fall back; `set_variant(&"px64")`
likewise. `SpriteLibrary.has_tier(id, tier, variant)` asks without loading. Enemies and bosses use the same
tiers through `SpriteLibrary.apply_enemy(sprite, def, tier, variant)`.

## 2. Import: one command per kind

### Characters, NPCs, enemies, bosses

```
python3 tools/art/import_pixellab.py <pixellab_id | download url | character url> <asset_key> [options]

# the 64 px anchor, as imported today (a character that still has a 128 px sheet -> the px64 variant)
python3 tools/art/import_pixellab.py ca2300bc-7592-4606-8973-32b9bc00056b crono --tier field --variant px64 --height-m 1.78 --name "TRIGGER Crono px64 field v1"
# a character with no sheet yet -> straight to field (pass --height-m for an NPC or enemy without a data height)
python3 tools/art/import_pixellab.py <id> glenn_marshall --name "TRIGGER Glenn Marshall field v1" --height-m 1.80
python3 tools/art/import_pixellab.py <id> sera --name "TRIGGER Sera u1 field v1"            # variant u1 -> sera_u1_field.png
python3 tools/art/import_pixellab.py https://api.pixellab.ai/mcp/characters/<id>/download enm_u0_porcelain_shardling --height-m 0.9
python3 tools/art/import_pixellab.py <id> marle --listing /tmp/marle.txt     # jobs still running: paste get_character's output into the file
python3 tools/art/import_pixellab.py <id> enm_u0_moss_mouse --mirror           # fill a missing west side from the east, symmetric creatures only
```

The asset key is the game's sprite id. The importer accepts `px<size>` variants and never builds a cell
smaller than 64 px. The target is resolved from game data (override with `--group`, `--canvas`, `--fps`,
`--height-m`, `--map game=pixellab,…`):

| Key is… | Writes | Height |
|---|---|---|
| a playable (`data/characters/<key>.json`) | `assets/characters/<key>/<key>[_<variant>]_<tier>.png` | `height_m` from the kit |
| an enemy key or sprite id (`data/enemies/`) | `assets/enemies/u<n>/<key>/<key>[_<variant>]_<tier>.png` | `height_m` in the def, else a fallback density |
| a boss sprite id or id (`data/bosses/`) | `assets/bosses/u<n>/<key>/<key>[_<variant>]_<tier>.png` | `height_m` or `size` in the boss JSON |
| anything else | `assets/npcs/<key>/<key>[_<variant>]_<tier>.png` | the fallback density |

The fallback density constant (`CAST_DENSITY`, 95 px / 1.78 m = 53.4 px/m) is the 128 px cast's and is wrong
for a 64 px sprite: always pass `--height-m` for an NPC or enemy that has no height in data, or add
`height_m` to its def.

Each import writes, next to the sheet: `<stem>_n.png` (a tangent-space normal sheet generated from the
silhouette and shading, so the HD-2D light shapes the sprite), `<stem>_frames.json` (§3), the `.import`
sidecars (lossless, no mipmaps, fix alpha border, normal flag on the `_n` sheet), and
`source_art/<group>/<key>/pixellab[<suffix>]/` (the raw frames, `metadata.json` with the prompt PixelLab
stored, `contact.png`; the downloaded zip stays local, `source_art/**/*.zip` is git-ignored). It then records
the asset in `data/art/pixellab_assets.json` under
`<key>[_<variant>]_<tier>` (PixelLab id and name, key, tier, variant, date, settings, previous ids under
`history`). Re-running rebuilds the sheet (after more clips were generated); `--skip-download` rebuilds from
the cached raw frames. PixelLab's zip is locked (HTTP 423) while any job on that character is still running:
wait, or build from a pasted `get_character` listing with `--listing`.

### Objects (props)

```
python3 tools/art/import_pixellab.py 89ddf903-c7ce-454c-8f1f-d74854fe290b prp_u0_hearth --request TRI-57
python3 tools/art/import_pixellab.py <object_id> prp_u1_torii --kind object      # a prp_ key or an /objects/ URL already says object
python3 tools/art/import_incoming.py --dry-run                                     # what data/art/incoming.json still owes
python3 tools/art/import_incoming.py                                               # import it all (objects and characters)
python3 tools/art/import_incoming.py --only prp_u0_hearth,prp_u0_oak_table --force
```

The prop must be declared in `data/props/props.json` first (§6); its height comes from there.

### Textures (materials)

`tools/art/import_texture.py` takes a raw PNG or a PixelLab image job id and writes a `SceneKit` material pair:
the source quantised to its own 15-colour material palette (median cut, no dither), wrap-blended over a thin
border so it tiles, tiled to the 1024 px sheet that covers 32 m (`SceneKit.TILE_M`; a 256 px source repeats
every 8 m, a 128 px one every 4 m), plus a normal map from luminance, as
`assets/textures/generated/<name>_albedo.png` and `<name>_normal.png`; `SceneKit.named("<name>")` picks the
pair up at once, and a row goes to `source_art/MANIFEST.csv` (§8).

```
python3 tools/art/import_texture.py <png | pixellab image job id> castle_flagstone --universe u0 --colours 15 --border 12 \
    --tool create_image_pixen --model pixen --seed 1024 --prompt "<the prompt sent>"
```

The twelve U0 materials of ASSET_REQUESTS Batch 7 went through this route on 2026-11-02
(`docs/screenshots/21_kitchen_snes_density.jpg`); the texture prompt that worked is in their MANIFEST rows
("16-bit SNES JRPG field tile texture, crisp hard pixels, flat colour areas with simple two-tone light and
shadow, no anti-aliasing, seamless tileable, a flat close-up of the surface only, no objects, no scene").

### UI panels

No importer yet: a delivered panel is copied as delivered to `assets/ui/generated/ui_<name>.png` (Godot writes
the `.import` on the next run) and logged in `source_art/MANIFEST.csv`. The four panels the asset team made
(battle command menu, party status card, menu kit, dialogue box) are there, **not wired**: the HUD and the
dialogue box stay code-drawn until Nich chooses between that navy-and-gold set and the palette-locked frame
in the style kit (QUESTIONS_FOR_NICH "Window frame A or B?").

## 3. Sheet layout (what the engine reads)

- Rows are directions in this order: **s, w, e, n, sw, se, nw, ne** (the first four are the old four-row
  order, so four-row sheets still work; a character delivered with only the four cardinal rotations gets just
  those four rows, which ActorSprite maps the diagonals onto). Columns are the delivered animations in the
  importer's order (`pixellab_import.DEFAULT_MAP`: idle, walk, run, interact, emote, ready, attack, charge,
  release, hurt, ko, revive, victory, death), each `count` wide; a character with no idle clip gets its south
  rotation as a one-frame `idle` column. The `_frames.json` table (`col`, `count`) is authoritative, so read
  a contact sheet against it, not against the §1 table.
- **Cell: the smallest multiple of 32 px that holds every frame around the pivot, never below 64.** Pivot
  bottom-centre; the feet sit on the line **8 px above the cell's bottom edge**. So a 64 px sprite whose feet
  touch the canvas bottom lands in a **96** cell (the anchor: cell 96, 61 px tall); one drawn with 8 px of
  floor under the feet stays in **64**; the older 128 px sets are **128**; props run 64 to 256. Template clips
  keep PixelLab's canvas, so the ground line is the south rotation's; v3 clips on a larger canvas are
  re-anchored on their first frame's feet.
- Finish per canvas (`pixellab_import.finish`): hard alpha at 128; U0 ink line #2C2C2C and saturation 0.92;
  U1 near-black line and saturation 0.30 (props keep their U1 saturation, §6); U7 sumi-brown line. Other
  canvases pass through. The finish never adds colours; a palette-locked sprite stays on palette.
- `<stem>_frames.json` (the anchor's, `crono_px64_field_frames.json`):
  ```json
  {"cell": 96, "rows": ["s","w","e","n","sw","se","nw","ne"], "mirror_w": false, "fps": 60,
   "height_px": 61, "height_m": 1.78, "source": {"pixellab_character": "ca2300bc-7592-4606-8973-32b9bc00056b", "canvas": "u0"},
   "anims": {"idle": {"col": 0, "count": 4, "fps": 5, "loop": true}, "walk": {"col": 4, "count": 6, "fps": 10, "loop": true}}}
  ```
  Optional per-anim `holds` (seconds per frame) override `fps` frame by frame.
- Engine side: `SpriteLibrary.apply(sprite, id, fps, tier, variant)` finds the sheet by id under
  `assets/{characters,npcs,enemies,bosses}`, calls `ActorSprite.set_height(height_px, height_m)` and `set_sheet`;
  `_n` and `_m` sheets are picked up automatically. Every key above is read: `rows` is the row order (a list
  that is not distinct directions is warned and the default order used); the top-level `fps` is the sheet's
  canvas rate, used when the caller passes none (`fps` 0, as `Location.add_npc` does by default; a character's
  `canvas_fps` from its data wins); an anim without its own `fps` steps at that rate. A sheet with no
  `height_px`/`height_m` stands at its cell's density: 32 px/m for a cell up to 96, the legacy 64 px/m for the
  128 px sets. A missing frames json falls back to the 70-column default table, and an anim that runs past the
  PNG's last column is cut (or dropped), each with a warning. `ActorSprite.face_vector` gives true eight-way facing on
  eight-row sheets; `play(name, return_to)` runs one-shots.

## 4. After every import

1. Look at `source_art/<group>/<key>/pixellab*/contact.png` against the catalog image, the bible brief and
   the approved anchor.
2. Render it on the lineup stage and in the scene that uses it:
   ```
   bash tools/capture/render.sh test_lineup lineup 30 -- --ids=crono --variant=px64 --anim=walk     # every facing of one character
   bash tools/capture/render.sh test_lineup lineup 30 -- --ids=crono,sera,krona --anim=idle         # the cast side by side
   bash tools/capture/render.sh guardia_kitchen kitchen 40 -- --checkpoint=prologue_breakfast_done --party=crono,marle,sera
   ```
   Captures land in `/tmp/captures/<prefix>_NNNN.png`.
3. Acceptance (the breakdown's list, applied to the capture and the sheet):
   - reads at 1x and at 3x: identity, face and weapon clear at the game camera and crisp when the capture is
     zoomed; no mud, no fringe, no soft edge;
   - the palette holds: no colour outside the project palette, at most 14 per character (count them on the
     sheet), no pure black line, no gradient;
   - three heads tall, the hair silhouette distinct from every other cast member's;
   - the height in metres is right next to the hero (61 px = 1.78 m) and the ground line sits on the floor;
   - no mirroring of an asymmetric design (compare west and east rows for the gauntlet, the sleeve, the scar);
   - every clip loops or ends cleanly, the facing in each row is the row's (the importer warned if not);
   - the per-canvas rule holds (U1: the four inks only).
4. Move the entry in `docs/ASSET_REQUESTS.md` to **Done** with the PixelLab id and date; add the audit row to
   `docs/BOT_REVIEW.md`; refresh `docs/screenshots/` when a scene changes visibly; if the build lead generated
   the asset, add its `source_art/MANIFEST.csv` row.

## 5. Checking for new art (at least hourly, and before any scene work)

Deliveries are Linear issues in "Time Debt - Asset Pipeline" (one per asset, `asset_key:` and `PixelLab id:`
in the description, stage labels Concept Review → In Production → In QA → QA Pass → Approved → Delivered →
Integrated) with files in Dropbox "TRIGGER Time Debt" and a thread in Slack `#all-trigger`. The repo-side
record is `data/art/incoming.json`: the build lead writes it from the Linear issues (one object per item, the
shape in `docs/BOT_REVIEW.md`), and the bot may append to it. Items named `TEST …` or `REJECTED …` are never
imported: `import_incoming.py` skips and lists them, `import_pixellab.py --name "TEST …"` exits with
`refused: … never ships`, and only `--force` on either overrides that.

```
git pull --rebase
python3 tools/art/import_incoming.py --dry-run          # lists every registered item not yet in data/art/pixellab_assets.json
python3 tools/art/import_incoming.py                     # imports them (objects to §6, characters to §2); stamps "imported" in incoming.json
python3 tools/art/pixellab_mcp.py list_characters '{"limit": 50}'    # the account itself: anything Delivered that incoming.json lacks
python3 tools/art/pixellab_mcp.py list_objects '{"limit": 50}'
python3 tools/art/pixellab_mcp.py get_character '{"character_id": "<uuid>"}'   # which jobs are still running
```

Also `list_topdown_tilesets`, `list_tiles_pro`, `list_ui_assets`, `list_images`. The MCP client needs a token
only for listings and generation (never printed); downloads need none. Anything the listing shows as
Delivered but missing from `incoming.json`: add it there from its Linear issue, then import. Then wire,
capture, record, and reply in the `[BUILD]` thread.

## 6. Objects / props (the second real route, 2026-11-02)

`footprint` in `data/props/props.json` shapes the collision: `[w, d]` is one centred box, `"posts"` two uprights at the drawn ends (an arch or a gate the party walks through), a list of `[w, d, x_offset]` several boxes (the portcullis: two posts and the grille).

Props are PixelLab **objects** (`create_1_direction_object`, `create_8_direction_object`,
`create_object_pro_flash`; `view="low top-down"`, transparent, the canvas's palette), named
`TRIGGER <Name> field v<N>`, tracked as Linear issues and mirrored into `data/art/incoming.json` with
`"kind": "object"`. In the game a prop is **a billboard with a height in metres**: the same `ActorSprite` +
`sprite_canvas` shader + `_n` normal sheet as the cast, so it is lit, shadowed and graded by the universe like
everyone else.

**Canvas at the new scale.** A prop's natural canvas is `height_m × 32` rounded up to a multiple of 32 (a
0.6 m stool 19 px in a 32 canvas, a 1.9 m hearth 61 px in 64, a 4 m torii 128). The delivered 47 were asked at
128/256 before the direction and measure 20 px/m (the clocktower spire) to 247 px/m (the ribbon), the big
landmarks nearest the recipe; they stay in the game until Nich asks for remakes, and new prop requests follow
the rule.

**Contract.** `/mcp/objects/<id>/download` returns a bare PNG (one rotation, no clips) or a zip holding
`rotations/<direction>.png` (`unknown` for a single rotation) and optionally
`animations/<slug>/<direction>/frame_NNN.png`. The importer takes both and writes:

| File | What |
|---|---|
| `assets/props/u<n>/<key>/<key>.png` | one row per rotation (1 row, or 4 `s w e n`, or 8, missing sides mirrored or filled from the nearest drawn one); columns = `idle`, then each clip. A single clip is the looping `idle` (the hearth's embers at 6 fps) and the drawn rotation becomes a one-frame `still`; with no clip, `idle` is the rotation. Cell = the smallest multiple of 32 that holds every frame about its canvas centre (64 for the gourd, 128 for most, 192–256 for the arches and the tent); pivot bottom-centre, feet 8 px up as for characters |
| `<key>_frames.json` | the character contract (`cell`, `rows`, `anims` {col, count, fps, loop, holds}, `height_px`, `height_m`) plus `width_px` (the drawn width, for the collision box) and `source` (object id, canvas, rotations, clip slugs) |
| `<key>_n.png` + `.import` sidecars | the normal sheet and lossless, no-mipmap import settings (as §3) |
| `source_art/props/<key>/pixellab/` | the unpacked frames (or the bare PNG), a character-shaped `metadata.json` and `contact.png`; the downloaded `object.zip` stays local (`source_art/**/*.zip` is git-ignored) |
| `data/art/pixellab_assets.json` | the record: `kind: "object"`, `group: "props"`, `universe`, `request` (the Linear issue), rotations, clips, cell, height |

Finish per canvas: U0 as the cast (hard alpha, ink line #2C2C2C, saturation 0.92); **U1 keeps its saturation**
(the four inks arrive on-palette; the character route's 0.30 would grey the cinnabar) and only has its line
pulled to sumi black.

**Height comes from data.** `data/props/props.json` declares every prop before it is imported: `key`
(`prp_u<n>_<name>`), `universe`, `height_m` (the full drawn height in metres: a stool 0.6, a table 1.2 with its
foreshortened top, a hearth with its chimney breast 1.9, a portcullis arch 4.0, a torii 4.0; the reasoning in
`notes`), `solid` (a collision box `width_px × pixel_size` wide, `height_m` tall, half as deep, clamped 0.3–1.2 m,
or an explicit `footprint`), `y_offset` (shelves, windows, pots on counters), `anims` (game name →
`{match: <slug substring>, fps, loop, holds}`), `emission` (the stained-glass panel glows), `pending` (declared,
not delivered), `request`. `Data` validates it (unknown fields, a key that does not name its universe, a
non-positive height are errors), `lint_data.py` and the unit suite check every non-pending prop has its sheet,
frames json and normal sheet, and that every object in `pixellab_assets.json` has an entry.

**Engine.** `SpriteLibrary.resolve_prop(key, universe)` / `apply_prop(sprite, key, fps, universe)` /
`frames_meta(r)`; `PropBillboard.make(key, facing, solid)` builds the sprite at the data height with its
collision body, or a labelled placeholder box of the declared height when the sheet is missing or the prop is
pending; `Location.add_prop(key, pos, facing := &"s", solid := true)` places it (data `y_offset` added) and
returns it (`set_still` freezes an animated prop on its drawn rotation, `set_tint`), `Location.get_prop(key)`
finds it again. Interactables stay separate nodes, so a prop can be swapped under an existing prompt.

**Review.** `source_art/props/<key>/pixellab/contact.png` against the catalog image and Reference §5.7; then
the room (`guardia_kitchen`, `guardia_courtyard`, `atrium`; the §4 command). Judge width next to the hero
(1.78 m), the ground line, and whether the drawn view agrees with where it stands: a front-view hearth belongs
on the back wall, not edge-on on a side wall. `docs/screenshots/14_props_delivered_47.jpg` shows every
delivered sheet's first cell with its key, cell, height and drawn size; `11`–`13` show the rooms.

What the first delivery taught (47 objects, Linear TRI-31..78, DECISIONS "Props are billboards with a height
in metres"): the route must accept a bare PNG; `prp_u0_clock_pillar_face` came back as a whole clocktower
spire (kept as a Truce landmark; Robo's pillar keeps its code-drawn face); `prp_u0_pool_rim` is one front arc
(the Atrium pool stays primitive); `prp_u1_dojo_set_rusted_katana` stands upright instead of lying on its
cloth; `prp_u0_doan_tree_stages` is the seed stage only; `prp_u0_klein_journal` (TRI-72) has no PixelLab id
and is `pending`. All five are the first entries of `docs/ASSET_REQUESTS.md` ("Follow-ups").

## 6b. Other asset kinds (routes to add as they arrive)

- **Portraits**: 48x48 pixel busts in the character's palette (§1b); target
  `assets/portraits/<id>/<id>_<expr>.png`, which `PortraitCache` already reads first. Route to write with the
  first delivery (a copy plus a MANIFEST row is enough).
- **Tilesets** (`create_topdown_tileset` Wang corner sets at 32 px, `create_tiles_pro` building kits): target
  `assets/tilesets/u<n>/<key>/` with the sheet and PixelLab's metadata JSON (each tile's NW/NE/SW/SE corner
  as lower / upper / transition). The three test sets in `source_art/style_kit/tilesets/` are the shape. The
  HD-2D rooms use flat textures on geometry (§2 textures); Wang sets are for ground planes and the 2D fallback.
- **VFX** (PixelLab VFX Creator, `vfx_workbench`): the export is a folder of clips (`whole`, `behind`, `front`,
  `part-<id>`) with a `manifest.json` giving frame size, fps, anchor and offsets (the README in
  `source_art/style_kit/vfx_impact_burst/`); target `assets/vfx/generated/<family>/<id>_fb_<n>f.png`, drawn
  behind, then the character, then front, scaled by whole numbers only.
- **UI**: §2 (copied as delivered).

## 7. Generation costs seen (PixelLab generations, this account)

Pro anchor at 64x64 (`create_image_pro`, 16 candidates): 10. v3 rotation to eight directions from a reference:
1. Template animation clip: 1 per direction, so 8 per clip for eight directions (a hero with idle, walk, run,
hurt, ready, ko is about 49 including the rotation). `create_image_pixen` texture: 1. `create_image_pro`
texture at 128 px: 10. Tileset: standard 1, pro 15. UI panel (`create_ui_asset`): 10. VFX Creator export:
0.1–1. For comparison, the superseded 128 px pro route cost 25 per character and about 200 for a full lead.
The account started 2026-11-02 at 9,590 generations; the build lead's first batch spent about 50.

## 8. The manifest and disclosure

`source_art/MANIFEST.csv` is the AI-disclosure log the breakdown (sections 10, 13 and 14) and Reference §9.9
ask for: one row per generated file, so the style stays auditable and Steam's disclosure is one line. Columns:

| Column | Holds |
|---|---|
| `file` | the path in the repository (`assets/textures/generated/castle_flagstone_albedo.png`, `source_art/style_kit/anchor_candidates/cand_00..15.png`) |
| `kind` | `texture`, `ui`, `vfx`, `wang-tileset`, `character-anchor-candidate`, `ui-frame-candidate`, … |
| `universe` | `u0` … `u8`, or `ui` |
| `tool` | the PixelLab tool (`create_image_pixen`, `create_image_pro`, `create_topdown_tileset`, `create_ui_asset`, `vfx_workbench`) and who ran it when not the build lead ("(asset team)") |
| `model` | the model family PixelLab named (`pixen`, `pro`, `pro (candidate 3 of 4)`, `ui`, a VFX preset); PixelLab publishes no changelog, so the name is pinned here |
| `seed` | the seed sent, when there was one |
| `generated_on` | the date |
| `post_process` | what the importer did (palette budget, wrap-blend width, tiling, normal map; "max 14 colours, 64x64" for the anchor) |
| `prompt` | the full prompt as sent (quoted; commas inside) |

`tools/art/import_texture.py` appends its row itself; a character import keeps its prompt in
`source_art/<group>/<key>/pixellab*/metadata.json` and its id in `data/art/pixellab_assets.json`, which
together are its provenance; anything the build lead generates by hand gets a row by hand. The file lives in
`source_art/`, not under `assets/`, because Godot imports any CSV inside the project's asset tree as a
translation table (the breakdown's `assets/MANIFEST.csv` path is therefore not used). Nothing without a
provenance row or a PixelLab record ships.
