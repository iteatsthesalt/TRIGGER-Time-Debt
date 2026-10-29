# Art pipeline: PixelLab characters → game sheets

How a character goes from a catalog painting to a lit, animated sprite in the game. This is the template
every playable, NPC, enemy and boss follows. Generation runs through the PixelLab MCP tools in a session;
the import runs anywhere with Python 3 + Pillow + numpy (no token needed: PixelLab downloads are keyed by the
character UUID).

Ownership (see `docs/REQUESTS_FOR_STUDIO.md`): this pipeline and everything under `assets/characters`,
`assets/npcs`, `assets/enemies`, `assets/bosses` is the build agent's. Portraits, generated UI, textures and
VFX come from the studio assistant into `assets/portraits/`, `assets/ui/generated/`,
`assets/textures/generated/`, `assets/vfx/generated/`, each with a `manifest.json`.

## 1. Generate (MCP tools, in a session)

1. **Create the character** from its catalog image (Reference Bible §5) in pro mode. Name it `TRIGGER <Name> vN`
   so Nich can find it in PixelLab's Character Creator (same account).
   ```
   create_character(mode="pro", size=128, view="low top-down",
       name="TRIGGER Sera v1",
       concept_image_url="https://raw.githubusercontent.com/iteatsthesalt/TRIGGER-Time-Debt/main/design/images/catalog/playable_sera.jpg",
       description="<identity block from Reference Bible §4/§5, + 'Chrono Trigger hero proportions (about 3.5 heads tall), expressive face, strong silhouette, confident pixel shading'>")
   ```
   Pro mode costs 25 generations and returns eight rotations in ~5 minutes. Without a catalog image, pass
   `style_character_id=<Crono's id>` so the cast stays in one style. Quadrupeds and creatures use
   `create_character_pro_flash(template_id=...)` or `create_8_direction_object`.
2. **Look at the rotations** (download the zip, make a contact sheet: `tools/art/pipeline/pixellab_import.py`
   does this as `source_art/<group>/<id>/pixellab/contact.png`). Check against the catalog image and §4:
   identity, asymmetry (Crono's gauntlet stays on his right arm), height ratio to Crono (95 px ≈ 1.78 m).
   Regenerate with a sharper description if wrong: a second candidate costs 25 generations and is cheaper
   than shipping a weak lead.
3. **Animate** with `animate_character`. Template clips cost 1–2 generations per direction at 128 px and keep
   the 128 canvas; custom v3 clips (`action_description`, `frame_count`) cost ~3–4 per direction and come back
   on a larger canvas (the importer re-anchors them on the feet). Standard set and the template ids:

   | Game anim | PixelLab clip | Frames | Use |
   |---|---|---|---|
   | idle | `breathing-idle` | 4 | field and menu idle |
   | walk | `walking` | 6 | field |
   | run | `running-6-frames` | 6 | field, battle approach |
   | hurt | `taking-punch` | 6 | damage flinch |
   | ready | `fight-stance-idle-8-frames` | 8 | battle idle |
   | ko | `falling-back-death` | 7 | KO / shutdown |
   | revive | `getting-up` | 5 | revive / boot |
   | release | `fireball` | 6 | tech cast release |
   | interact | `picking-up` | 5 | field interaction |
   | attack | v3 `action_description` (weapon-specific) | 8 | basic attack |
   | charge | v3 (4 frames, loop) | 4 | tech charge |
   | victory | v3 | 6–8 | battle won |

   The 20 concurrent job slots are shared with the studio assistant and Nich: queue one or two clips at a
   time and `wait_for_jobs` between. Pass `animation_name=<game anim>` so the importer finds the clip by its
   display name.
4. **Record** the character in `data/art/pixellab_characters.json`: `pixellab.chosen`, every candidate id with
   its PixelLab name, the canvas, `height_m` (Reference Bible §1.2) and any `anims` overrides.

## 2. Import (`tools/art/pipeline/`)

```
python3 tools/art/pipeline/build_characters.py crono        # one id; none = every entry with a chosen id
python3 tools/art/pipeline/build_characters.py crono --listing /tmp/crono.txt   # zip locked: use a saved get_character listing
```

`build_characters.py` reads the manifest and calls `pixellab_import.py`, which:

- downloads `https://api.pixellab.ai/mcp/characters/<id>/download` into `source_art/<group>/<id>/pixellab/`
  (zip, unpacked frames, `metadata.json`, `contact.png`). The zip answers HTTP 423 while any job on the
  character is still running; `--listing` fetches the finished frames from a pasted `get_character` output
  instead;
- packs the sheet: eight direction rows in the order **s, w, e, n, sw, se, nw, ne** (the first four match the
  old four-row sheets), animation columns in `DEFAULT_MAP` order, cell = smallest multiple of 32 that holds
  every frame, feet on the line 8 px above the cell bottom (Reference Bible §1.2), missing directions filled
  with the rotation (or mirrored when `mirror_missing` is set, never for asymmetric heroes);
- applies the canvas finish (`finish()`): hard alpha at 128, U0 ink #2C2C2C line and saturation 0.92, U1
  near-black line and saturation 0.3, U7 sumi-brown line;
- writes `assets/<group>/<id>/<id>_field.png`, `<id>_frames.json` (cell, rows, fps, `height_px`, `height_m`,
  per-anim col/count/fps/loop) and the `.import` sidecar (lossless, no mipmaps, fix alpha border, §1.12).

## 3. In the engine

- `SpriteLibrary.apply(sprite, id, fps)` finds `assets/{characters,npcs,enemies,bosses}/<id>/<id>_field.png`,
  reads the frame table, calls `ActorSprite.set_height(height_px, height_m)` (so a 95 px Crono stands 1.78 m)
  and `set_sheet`. Optional `<id>_field_n.png` / `<id>_field_m.png` are picked up as normal and mask sheets.
- `ActorSprite` picks the row from `facing`; eight-row sheets get true diagonals from `face_vector`, four-row
  sheets collapse diagonals to the nearest cardinal. Animations play at their own fps with optional per-frame
  `holds`; one-shots return to the animation named in `play(name, return_to)`.
- Review: `tools/capture/render.sh test_lineup lineup 30 -- --ids=crono,sera --anim=walk` renders every facing of
  the listed ids on the lit stage to `/tmp/captures/`. Look at it before calling the character done.

## 4. Checks before commit (Reference Bible §1.13)

1. Identity against the catalog image and §4 (asymmetry kept, weapon reads in silhouette).
2. Height ratio: `height_px` in the frames JSON vs Crono's 95 (Sera 86, Krona 101, Marle ~90).
3. Every direction present for idle, walk and run; no mirrored diagonals on asymmetric characters.
4. Loops close (walk/run/idle); one-shots end on a readable pose.
5. The lineup capture: crisp pixels (no filtering), shadow on the ground, outline colour matches the canvas.

## 5. Costs so far (generations)

Pro character 25; `breathing-idle` 8/8 directions; `walking` 16; `running-6-frames` 16; `taking-punch` 16;
`fight-stance-idle-8-frames` ≤16; `falling-back-death` ≤16. A full lead (field + battle + three v3 clips)
lands around 200 generations; an NPC with idle + walk around 50.
