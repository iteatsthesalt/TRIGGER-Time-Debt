# Requests for the studio assistant

The studio assistant owns `assets/portraits/`, `assets/ui/generated/`, `assets/textures/generated/` and
`assets/vfx/generated/` (each with a `manifest.json`: files, sizes, intended use). The build agent wires in
whatever is there and carries on with a placeholder for anything missing. This file lists what the game
needs from those folders, most urgent first. Tick items off (or note the file that satisfies them) as they
land; the build agent checks the folders and this file at the start of every run.

## How the game loads these

- **Portraits**: `scripts/ui/portrait_cache.gd` looks for `assets/portraits/<id>/<id>_<expr>.png` first (512×512
  bust, transparent background), then falls back to `assets/characters/<id>/<id>_portrait_<expr>.png` and the
  catalog crops. Expressions used by dialogue: `neutral, sad, angry, surprised, smile, hurt, special_a,
  special_b` (Reference Bible §1.4 PRT). Speaker ids match `data/characters/` and `data/dialogue/` speaker
  keys: `crono, sera, krona, marle, glenn, magus, robo, lucca, vaelos, bekkler, johnny, cyrus, cassia_09,
  xyloph, vesper, pierrot_glenn, static, omega_spekkio`.
- **UI**: `scripts/ui/*.gd` read 9-slice frames and icons from `assets/ui/generated/` when present (names
  below), else draw flat placeholders.
- **Textures**: `SceneKit.material(albedo, normal)` takes any path; locations ask for materials by name through
  `SceneKit.named("<material>")`, which looks in `assets/textures/generated/<material>_albedo.png` (+ `_normal.png`)
  before the procedural placeholders in `assets/textures/`.
- **VFX**: `scripts/battle/vfx_library.gd` (to be written) loads `assets/vfx/generated/<family>/<id>_fb_<n>f.png`
  flipbooks by element and tech id.

## 1. Portraits (dialogue) — blocks the vertical slice's dialogue polish

Eight expressions each, 512×512, in the character's canvas (Reference Bible §5.2–§5.4 prompts):

- [ ] crono (U0 watercolour; include the `hurt` and a `porcelain` special with hairline gold cracks)
- [ ] sera (U0 + tachyon violet; `special_a` = eyes glowing violet, `special_b` = translucent 40%)
- [ ] marle (U0), glenn (U0, one-armed Marshall, grey), magus (U0, blind eye bleeding silver), robo (the clock
      face / Prometheus), lucca (journal portrait)
- [ ] krona (U1 sumi-e, four inks; `special_a` = Oil-Drinker veins)
- [ ] vaelos (Sovereign; `special_a` = Lamplighter, `special_b` = the Boy)
- [ ] bekkler, johnny, cyrus; then cassia_09 (U2), xyloph (U3), vesper (U4), pierrot_glenn (U5), static (U6),
      omega_spekkio (U7)

## 2. UI frames and icons (`assets/ui/generated/`)

Reference Bible §6 (UI) and the UI prompt tail: flat vector, cream #F2EAD7 on ink #161821, chamfered octagonal
frame, diamond studs, no gradients. Authored at 2× (the UI canvas is 640×360, integer-scaled).

- [ ] `frame_dialogue.png` 9-slice (corners 16 px at 1×), `frame_menu.png`, `frame_tooltip.png`
- [ ] `cursor_hand.png` 16×16, `cursor_target.png` 24×24
- [ ] element icons 32×32: `icon_el_astral, tachyon, ruin, ferro, mycelia, vitreous, guile, hz, null` (shape as
      well as colour: Combat Laws §9)
- [ ] status icons 16×16 with distinct shapes: `icon_st_bleed, burn, slow, haste, seal, break, guard, stagger,
      oil_blight, rewound`
- [ ] gauge housings + fill masks: `gauge_hp.png`, `gauge_bp.png` (Boost pips ×5), `gauge_turn.png`
- [ ] `plate_shield.png` (the shield plate housing, 48×24) and the three plate key glyphs (sword, fire, light…)
- [ ] fonts: a pixel UI face (8 px cap height, ASCII + accented Latin) and a display face for titles
      (`fonts/ui_pixel.ttf`, `fonts/title.ttf`)

## 3. Textures (`assets/textures/generated/`, 64 px/m, with `_normal`)

Name by material; the kitchen, courtyard, Atrium and Leene Square need these first (U0), then the bamboo
grove and Kuro-Truce (U1):

- [ ] U0: `castle_flagstone`, `castle_wall_block`, `oak_plank`, `oak_beam`, `slate_roof`, `brass_panel`,
      `cobble_wet`, `grass_moss`, `dirt_path`, `fair_canvas_stripe`, `stone_steps`, `plaster_cream`
- [ ] U1: `washi_floor`, `black_lacquer_wall`, `bamboo_stalk`, `tatami`, `cinnabar_lacquer`, `ink_water`
- [ ] shared: `cold_press_paper` (overlay, 1024²), `washi_paper`, `crack_noise` (porcelain), `galaxy_cubemap_6x1`

## 4. VFX flipbooks (`assets/vfx/generated/`, 128 or 256 cells, canvas rate)

- [ ] Element hits (one per element, 8 frames): `hit_astral … hit_null`
- [ ] Break shatter (12 frames, additive), shield plate crack (6), perfect parry flash (4)
- [ ] Crono: tech charge wisps (4 loop), Astral Smear Dash trail (4); Sera: Rewind glyph (8), Tachyon
      fast-forward streaks (6); Krona: ink splash (8), wet ink zone (loop 6)
- [ ] Chronoslip style phase (Reference Bible §5.8.4), seven-canvas fracture (§5.8.5)

## Answered / landed

(nothing yet)
