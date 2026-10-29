# Art pipeline: PixelLab → game

**Who does what (current plan).** Nich makes all art with his PixelLab bot, working from
`docs/ASSET_REQUESTS.md`. The build agent (and the studio assistant when it takes over) imports every finished
asset with one command, wires it into the scene that needs it, screenshots it, and records it in
`data/art/pixellab_assets.json`. Agents do not generate art beyond what proves the pipeline. Nothing in the
PixelLab library is ever deleted.

Crono (PixelLab `8d699d00-eb9f-4da7-a408-a1f70039fa1c`) is the finished template: generated → sheet → normal
map → import → screenshot (`docs/screenshots/07…`, `08…`).

## 1. The contract (what a character request must produce)

| Setting | Value |
|---|---|
| Tool | `create_character` **pro** mode (`mode="pro"`), or `create_character_pro_flash` for creatures/large bodies |
| Canvas | **128 × 128** for anything human-sized (pro mode's maximum). Humans come out ~86–101 px tall; the importer scales each sprite to its bible height in metres, so do not pad or resize. Bosses and large creatures: Pro Flash at **256 × 256** (`width=256, height=256`), or `create_8_direction_object` up to 168 |
| View | `view="low top-down"` (the game camera is 15–30° above the ground) |
| Directions | **8**: south, south-west, west, north-west, north, north-east, east, south-east |
| Reference | `concept_image_url` = the catalog painting from `design/images/catalog/` (raw GitHub URL), or `style_character_id` = Crono's id when there is no painting, so the cast shares one look |
| Proportions | Chrono Trigger: about 3.5 heads, expressive face, strong silhouette; put that sentence in every description |
| Asymmetry | Keep it in every direction and never mirror (Crono's gauntlet is on his right arm; Glenn's left arm is missing) |
| Name | `TRIGGER <Name> v1` (v2, v3 for retries) so the Character Creator and this repository agree |
| Background | Transparent (PixelLab default) |

**Animations** (`animate_character`, pass `animation_name` = the game name in the first column; template ids
are PixelLab clips, 1–2 generations per direction at 128 px; "v3" means a custom `action_description` clip
in `mode="v3"`, `frame_count` as listed):

| Game anim | PixelLab clip | Frames | Who needs it |
|---|---|---|---|
| idle | `breathing-idle` | 4 | everyone |
| walk | `walking` | 6 | everyone who moves |
| run | `running-6-frames` | 6 | party, chasers |
| hurt | `taking-punch` | 6 | everyone who fights |
| ready | `fight-stance-idle-8-frames` | 8 | party and bosses (battle idle) |
| attack | v3, weapon described | 8 | everyone who fights |
| ko | `falling-back-death` | 7 | party, humanoid enemies |
| revive | `getting-up` | 5 | party |
| release | `fireball` | 6 | casters (tech release) |
| charge | v3 "gathering power, loop" | 4 | party |
| interact | `picking-up` | 5 | party |
| victory | v3 | 6–8 | party |

Field NPCs need idle + walk. Enemies need idle + attack + hurt (+ ko for humanoids). The party needs the full
table. Directions that PixelLab gets wrong (a back view drawn as a front view) are flagged by the importer
(`WARNING … looks like the <other> rotation`); delete that one direction with `delete_animation(…, direction=)`
and queue it again into the same `animation_group_id`.

## 1b. A character is a set of sprites: tiers and variants

| Tier | Canvas | Look | Used for | File |
|---|---|---|---|---|
| `map` | 64, 4 dirs | tiny bold silhouette | the overworld (Chapter 3+) | `<id>_map.png` |
| `field` | 128, 8 dirs | Chrono Trigger chibi, ~3.5 heads (Crono 95 px) | locations, biomes **and battle** (battle clips are columns of the field sheet) | `<id>_field.png` |
| `action` | 256 (the sequence's directions, often s/w/e) | realistic ~5.5 heads (Crono ~120 px); ref `design/images/refs/crono_action_tier_reference.png` | Dual/Triple Tech cut-ins, cinematic beats, duel intros, the Fair descent. Each sequence is a **clip** = an animation column group in the one action sheet | `<id>_action.png` |
| `portrait` | 512 | painted bust | dialogue, menus | `<id>_portrait_<expr>.png` |

A **variant** is the same character in another canvas (`u1`, `u2`, … `u8`) or a story state (`debt60`,
`debt20`, `debt0`, `broken`, `salvaged`, `rewound`, `mask_off`, `oil`, `sealed`, `cobalt`, `gold`, `ghost`),
generated as the tier above with that canvas's prompt tail and `style_character_id` of the base so the
identity holds. File: `<id>_<variant>_<tier>.png` (e.g. `sera_u1_field.png`, `crono_debt20_field.png`).

PixelLab names carry both: `TRIGGER <Name> <tier> v1`, `TRIGGER <Name> <variant> <tier> v1`
(`TRIGGER Crono action v1`, `TRIGGER Sera u1 field v1`). The importer reads them from `--name`, or takes
`--tier` / `--variant` explicitly; unnamed characters are field/base. Every tier/variant sheet has its own
`<stem>_frames.json`, `_n` normal sheet and manifest entry (`<id>[_<variant>]_<tier>`).

Engine: `SpriteLibrary.apply(sprite, id, fps, tier := &"field", variant := &"")` resolves in this order —
the variant's tier, the base tier, the variant's field sheet, the base field sheet, the legacy `_sheet`, the
painted stand-in, a placeholder — and records what it found in `sprite.loaded_tier` / `loaded_variant`.
`ActorSprite.set_tier(&"action")` swaps a live sprite for a cut-in (facing kept, the current animation kept
when the new sheet has it, else idle) and returns false when it had to fall back; `set_variant(&"u1")`
likewise. `SpriteLibrary.has_tier(id, tier, variant)` asks without loading. Enemies and bosses use the same
tiers through `SpriteLibrary.apply_enemy(sprite, def, tier, variant)`.

## 2. Import: one command

```
python3 tools/art/import_pixellab.py <pixellab_id | download url | character url> <asset_key>
```

Examples:

```
python3 tools/art/import_pixellab.py 8d699d00-eb9f-4da7-a408-a1f70039fa1c crono --name "TRIGGER Crono field v1"
python3 tools/art/import_pixellab.py d1df31ab-e2cc-47c7-a8b7-6b293769a293 crono --tier action        # or --name "TRIGGER Crono action v1"
python3 tools/art/import_pixellab.py <id> sera --name "TRIGGER Sera u1 field v1"                      # variant u1 -> sera_u1_field.png
python3 tools/art/import_pixellab.py https://api.pixellab.ai/mcp/characters/<id>/download enm_u0_porcelain_shardling
python3 tools/art/import_pixellab.py <id> marle --listing /tmp/marle.txt     # jobs still running: paste get_character's output into the file
python3 tools/art/import_pixellab.py <id> glenn_marshall --no-mirror           # the default; --mirror fills a missing west side from the east for symmetric creatures
```

The asset key is the game's sprite id. The target is resolved from game data (override with `--group`,
`--canvas`, `--fps`, `--height-m`, `--map game=pixellab,…`):

| Key is… | Writes | Height |
|---|---|---|
| a playable (`data/characters/<key>.json`) | `assets/characters/<key>/<key>[_<variant>]_<tier>.png` | `height_m` from the kit |
| an enemy key or sprite id (`data/enemies/`) | `assets/enemies/u<n>/<key>/<key>[_<variant>]_<tier>.png` | `height_m` in the def, else the cast density (53.4 px/m) |
| a boss sprite id or id (`data/bosses/`) | `assets/bosses/u<n>/<key>/<key>[_<variant>]_<tier>.png` | `height_m` or `size` in the boss JSON |
| anything else | `assets/npcs/<key>/<key>[_<variant>]_<tier>.png` | cast density |

Each import writes, next to the sheet: `<stem>_n.png` (a tangent-space normal sheet generated from the
silhouette and shading, so the HD-2D light shapes the sprite), `<stem>_frames.json` (below), the `.import`
sidecars (lossless, no mipmaps, fix alpha border, normal flag on the `_n` sheet), and
`source_art/<group>/<key>/pixellab[<suffix>]/` (zip, raw frames, `metadata.json`, `contact.png`). It then records
the asset in `data/art/pixellab_assets.json` under `<key>[_<variant>]_<tier>` (PixelLab id, key, tier, variant,
date, settings, previous ids under `history`).

PixelLab's zip (`/mcp/characters/<id>/download`) is locked (HTTP 423) while any job on that character is still
running; `--listing <file>` builds from a pasted `get_character` listing instead, and `--skip-download` rebuilds
from the cached raw frames.

## 3. Sheet layout (what the engine reads)

- Rows are directions in this order: **s, w, e, n, sw, se, nw, ne** (the first four are the old four-row
  order, so four-row sheets still work). Columns are animations in the table order above, each `count` wide.
- Cell: the smallest multiple of 32 px that holds every frame (128 for the cast). Pivot bottom-centre; the
  feet sit on the line **8 px above the cell's bottom edge** (Reference Bible §1.2). Template clips keep
  PixelLab's canvas, so the ground line is the south rotation's; v3 clips on a larger canvas are re-anchored
  on their first frame's feet.
- Finish per canvas (`pixellab_import.finish`): hard alpha at 128; U0 ink line #2C2C2C and saturation 0.92; U1
  near-black line and saturation 0.30; U7 sumi-brown line. Other canvases pass through.
- `<stem>_frames.json` (e.g. `crono_field_frames.json`, `crono_action_frames.json`):
  ```json
  {"cell": 128, "rows": ["s","w","e","n","sw","se","nw","ne"], "mirror_w": false, "fps": 60,
   "height_px": 95, "height_m": 1.78, "source": {"pixellab_character": "<id>", "canvas": "u0"},
   "anims": {"idle": {"col": 0, "count": 4, "fps": 5, "loop": true}, "walk": {"col": 4, "count": 6, "fps": 10, "loop": true}, "...": {}}}
  ```
  Optional per-anim `holds` (seconds per frame) override `fps` frame by frame.
- Engine side: `SpriteLibrary.apply(sprite, id, fps)` finds the sheet by id under
  `assets/{characters,npcs,enemies,bosses}`, calls `ActorSprite.set_height(height_px, height_m)` and `set_sheet`;
  `_n` and `_m` sheets are picked up automatically. `ActorSprite.face_vector` gives true eight-way facing on
  eight-row sheets; `play(name, return_to)` runs one-shots.

## 4. After every import

1. Look at `source_art/<group>/<key>/pixellab/contact.png` against the catalog image and the bible brief.
2. Render it: `bash tools/capture/render.sh test_lineup lineup 30 -- --ids=<key> --anim=walk` → `/tmp/captures/`,
   and the scene that uses it. Judge: identity, asymmetry, height next to Crono (95 px ≈ 1.78 m), loops close.
3. Move the entry in `docs/ASSET_REQUESTS.md` to **Done** with the PixelLab id and date; refresh
   `docs/screenshots/` when a scene changes visibly.

## 5. Checking for new art (at least hourly, and before any scene work)

With the MCP tools: `list_characters(limit=50)`, `list_objects(limit=50)`, `list_topdown_tilesets`,
`list_tiles_pro`, `list_ui_assets`, `list_images(limit=50)`. Anything completed whose name matches an asset key
(or is clearly for the game) and is not yet in `data/art/pixellab_assets.json`: import it, wire it in,
screenshot it, record it. Characters still showing pending jobs: wait, or import with `--listing`.

## 6. Other asset kinds (import routes to add as they arrive)

- **Objects / props** (`create_8_direction_object`, `create_1_direction_object`, `create_object_pro_flash`):
  `get_object` gives the rotation URLs; props are billboards placed by `Location.add_prop` (to write with the
  first prop) under `assets/props/u<n>/<key>.png`.
- **Portraits** (`create_image_pro` / `pro_flash`, 512×512 bust, eight expressions): `assets/portraits/<id>/<id>_<expr>.png`;
  `PortraitCache` already looks there first.
- **Textures** (`create_image_*` tileable, 64 px/m): `assets/textures/generated/<material>_albedo.png` + `_normal.png`;
  `SceneKit.named("<material>")` already looks there first.
- **Tilesets** (`create_topdown_tileset`, `create_tiles_pro`): `assets/tilesets/u<n>/<key>/` with the sheet and
  metadata JSON (Wang corners) for ground planes.
- **UI** (`create_ui_asset`, icons via `create_image_pro`): `assets/ui/generated/`.
- **VFX** (`animate_image` flipbooks): `assets/vfx/generated/<family>/<id>_fb_<n>f.png`.

## 7. Costs seen so far (generations)

Pro character 25; `breathing-idle` 8 per eight directions; `walking`, `running-6-frames`, `taking-punch`,
`fight-stance-idle-8-frames`, `falling-back-death` up to 16 each; a full lead (field + battle + three v3
clips) is about 200; an NPC with idle + walk about 50; a direction redo 1–2.
