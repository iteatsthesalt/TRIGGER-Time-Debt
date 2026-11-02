# Screenshots

Progress captures for Nich, refreshed after every visual milestone. Newest state first. Rooms and textures
in captures 01–06 are placeholders (primitive-box rooms, procedural tiles) until textures and props arrive
from Nich's PixelLab bot (`docs/ASSET_REQUESTS.md`); from capture 07 on, the characters are real PixelLab
sprites (see `docs/ART_PIPELINE.md`).

| File | What it shows | Date |
|---|---|---|
| `20_style_bible_kit_review.jpg` | The Phase-1 style-bible kit from Nich's Nov 1 breakdown, generated for his decision: sixteen 64x64 palette-locked hero anchor candidates, three Wang test tilesets, a 9-slice window frame, the impact-burst effect, and the twelve U0 textures now in `assets/textures/generated/`. Nothing ships until he picks. | 2026-11-02 |
| `13_props_atrium.jpg` | **The Atrium with Nich's props** (Linear TRI-51..78, Batch 6): the gramophone workbench at six o'clock, two of the eight brass gate arches with their universe panels standing in the openings, the Seed of Doan in its pot at the end of Sera's ink marks, the hearth corner (left) with Marle on the benches. The camera-side columns and balconies of the ring are now cut to the ledge like the wall, so the hall reads from the follow camera. Floors, pillar and ramp are still blockout primitives. | 2026-11-02 |
| `12_props_courtyard.jpg` | **The courtyard with Nich's props**: the hand cart and two of the four moss flower beds beside the keep wall, Glenn and Magus (still placeholder blobs) on the flagstone path in the rain. The stone well stands at the west side, out of this frame. | 2026-11-02 |
| `12_props_courtyard_gate.jpg` | The portcullis arch filling the gatehouse opening, seen from outside with the party in the gateway and the courtyard through its bars (the `Truce` exit prompt). | 2026-11-02 |
| `11_props_kitchen.jpg` | **The Prologue kitchen with Nich's props**: the hearth with its 6 fps ember loop at the west end of the back wall, three stained-glass panels glowing through the sprite shader's emission, the pot shelf, the bowl counter, the speaking tube; the oak table and Sera's stool at the bottom edge. The white square over the counter is the dust-mote particle system as software Vulkan draws it (it is motes on a GPU) and hides the porridge pot hanging there. | 2026-11-02 |
| `14_props_delivered_47.jpg` | **All 47 delivered props as imported** (`assets/props/u<n>/<key>/`): the first cell of every sheet in its 64-256 cell with the ground line, labelled key, cell, height in metres and drawn size. U0 watercolour and U1 four-ink palettes kept; flagged: the clock pillar face is a whole spire, the pool rim one arc, the rusted katana upright. | 2026-11-02 |
| `09_cast_lineup_pixellab.jpg` | Crono, Sera, Krona (build-agent template characters) and Marle (from Nich's bot) in all eight facings, mid walk, lit with normal maps. Marle's realistic 5.5-head proportions next to the 3.5-head cast are flagged for Nich in ASSET_REQUESTS. | 2026-10-29 |
| `10_crono_action_tier.jpg` | The **action tier**: Crono's realistic 5.5-head sheet loaded through `SpriteLibrary.apply(…, &"action")` on the same stage, proving the tier swap for Dual/Triple Tech cut-ins. | 2026-10-29 |
| `07_crono_pixellab_8_directions.jpg` | **First real character art.** Crono (41) generated with PixelLab pro mode from his catalog painting, imported by `tools/art/pipeline/`, standing in all eight facings on the lit test stage (`scenes/test/lineup.tscn`). Chrono Trigger proportions, gauntlet and katana on the right arm in every view, lit with shadows by the HD-2D sprite shader. The wall and floor are still placeholder textures. | 2026-10-29 |
| `08_crono_pixellab_walk.jpg` | The same lineup mid walk cycle (6-frame PixelLab template walk, 8 directions). | 2026-10-29 |
| `04_prologue_kitchen_dialogue.jpg` | The Prologue kitchen (Guardia Atrium wing): Crono, Marle and Sera as lit billboard sprites in a textured-primitive room with stained glass, the dialogue box at the 640×360 UI scale. Playable: breakfast, first Chronoslip, the fall choice, the Fracture Gate, the Atrium Cradle. | 2026-10-29 |
| `05_title_screen.jpg` | Title screen with New Game / Continue / Options / Quit. The backdrop is design plate-00 for now. | 2026-10-29 |
| `06_cast_lineup_placeholders.jpg` | The code-generated placeholder cast (Crono, Sera, Krona, Marle, Glenn, Magus, townsfolk): correct proportions and palettes, not the Toriyama-grade target. | 2026-10-29 |
| `03_battle_hud_arena.jpg` | A seamless field battle: turn bar, shield plates with the preview math, command deck, Boost pips, telegraph decal. | 2026-10-29 |
| `01_canvas_stack_u0_u1_u2_u7.jpg` | The compositor canvas stack grading one diorama as U0 watercolour, U1 sumi-e, U2 clay/VHS and U7 gold leaf. | 2026-10-29 |
| `02_diorama_u1_sumi_e.jpg` | The HD-2D pipeline proof under the U1 sumi-e grade: ink edges, posterised tones, paper. | 2026-10-29 |
