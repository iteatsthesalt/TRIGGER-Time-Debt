# Asset team deliveries: the contract, and the audit log

Nich's asset team (his bots, coordinated by Cursor; the first bot was Grokbot) makes every asset in the shared
PixelLab account. This file is the delivery contract and the review record. The studio assistant audits every
delivery against `docs/ART_PIPELINE.md` §1 and the Reference Bible, writes the verdict below, and the team
fixes what is flagged before the next batch. Nothing in the PixelLab library is ever deleted.

## How a delivery works (as it runs today)

1. **Concept first.** Post the concept (the request text from `docs/ASSET_REQUESTS.md`, the catalog image, a
   first south-facing candidate) in a Slack `#all-trigger` thread. Nich approves there. Nothing goes to PixelLab
   before its concept is approved; while the style gate is open (ASSET_REQUESTS "Style gate") nothing in volume
   is generated at all.
2. **One Linear issue per asset** in the project "Time Debt - Asset Pipeline" (the props were TRI-31..TRI-78,
   the text layer TRI-80). The description carries the lines `asset_key: <key>` and `PixelLab id: <uuid>` (plus
   the Dropbox link). Stage labels move Concept Review → In Production → In QA → QA Pass → Approved →
   Delivered → Integrated; the build lead imports at Delivered and sets Integrated after the capture.
3. **Files in Dropbox "TRIGGER Time Debt"**: `01 Concepts for approval`, `02 Approved`, `03 Sprites`,
   `04 Audio`, `05 Docs`; the Notion hub links them. PixelLab items are pulled by id, so PNGs need not be
   committed anywhere.
4. **Names in PixelLab** are exactly `TRIGGER <Name> [<variant>] <tier> v<N>`: `TRIGGER Krona field v1`,
   `TRIGGER Ashen Ashigaru field v1`, `TRIGGER Sera u1 field v1`, `TRIGGER Hearth field v1` (objects take `field`).
   The importer reads tier and variant from the name; a wrong name is the most common reason an asset cannot be
   imported. **The px64 rule:** a character that already has a 128 px sheet in the game is delivered as
   `TRIGGER <Name> px64 field v<N>` until Nich approves the anchor; a character with no sheet yet is plain
   `field` (ART_PIPELINE §1b). Prefix `TEST ` for an experiment and `REJECTED ` for a dropped candidate: those
   are never imported (the importer refuses the name; only an operator's `--force` overrides it).
5. **The repo-side record** is `data/art/incoming.json`, one object per item in this shape. The build lead
   writes it from the Linear issues; the bot may append to it (same shape, one item per entry, commit message
   `bot: <asset_key> (<kind>) — <one line>`, `git pull --rebase` first, and nothing else in the repository
   touched). `python3 tools/art/import_incoming.py` is the hourly import and stamps `"imported"`.
   ```json
   {"asset_key": "prp_u0_hearth", "tier": "", "variant": "", "pixellab_id": "89ddf903-c7ce-454c-8f1f-d74854fe290b",
    "pixellab_name": "TRIGGER Hearth field v1", "kind": "object", "animations": ["flicker"],
    "request": "TRI-57", "prompt_used": "<the prompt sent>", "date": "2026-11-02"}
   ```
   `kind` is `character`, `object`, `tileset`, `ui`, `portrait`, `texture` or `vfx`; `tier` and `variant` for
   characters (`"field"`, `"px64"`), empty for objects. Fill `prompt_used`: it is the provenance record.
6. **Anything not made in PixelLab** (a texture from another generator, a hand-made PNG) is delivered through
   Dropbox and its Linear issue with the tool, prompt, seed and licence named; the build lead imports it
   (`tools/art/import_texture.py` for a texture) and writes its `source_art/MANIFEST.csv` row.

## What the audit checks (the 64 px recipe)

- Name, tier and variant match the request and the px64 rule; the id resolves on PixelLab; the character is
  complete (eight directions, the requested clips) and no direction faces the wrong way.
- Identity against the catalog image and the Reference Bible brief (costume, asymmetry kept in every direction,
  weapon hand, hair silhouette distinct from the rest of the cast).
- **Scale:** 64x64 canvas, about three heads tall; the drawn height is `height_m × 32 px` within 10% (the hero
  1.78 m → 56–61 px). Enemies by size class (small 64, medium 64x128, bosses 128–192). Props: `height_m × 32`
  rounded up to a multiple of 32. The importer sizes everything to metres (`height_m` from the kit, the def or
  `data/props/props.json`), so a sprite with far more pixels than its metres warrant reads blurry at the game
  camera, and one with far fewer reads blocky.
- **Palette holds:** every pixel from the project palette, at most 14 colours per character, no colour outside
  it; coloured selective outline, no pure black line, no gradient, no anti-aliasing, no dither on characters.
- Canvas rule: U0 the project palette; U1 four inks only (sumi black, cobalt, cinnabar, paper white; no gold,
  no grey gradients); U2 clay with VHS; and so on per Reference Bible §3.
- Readability: strong silhouette, one focal element, reads at 1x and at 3x, hard alpha, no fringe.
- **No names in prompts:** `prompt_used` describes the design and the style and contains no Square Enix
  character or game name, in the prompt or the style-reference slot; nothing from an existing game is traced,
  inpainted over or used as a reference image.
- Animation: held frames, the clip set the request asked for, loops close, the attack reads as a telegraph.

Verdicts: **ACCEPT** (imported as is), **ACCEPT WITH FIXES** (imported; listed fixes wanted in v2),
**REJECT** (not imported; regenerate with the listed changes), **NOT IMPORTED** (superseded or out of
contract; stays on the account).

## Audit log

| Date | Item | Verdict | Notes |
|---|---|---|---|
| 2026-10-29 09:45 | — | — | No deliveries yet. |
| 2026-11-02 | 47 PixelLab objects, Linear TRI-31..TRI-78 (Batch 4d U1 landmarks, Batch 6 Prologue and Atrium dressing) | **ACCEPT**, four exceptions | Imported through the object route (`data/art/pixellab_assets.json`, `assets/props/u<n>/<key>/`; `docs/screenshots/14_props_delivered_47.jpg`, rooms in `11`–`13`); 19 placed in the kitchen, courtyard and Atrium, 28 imported awaiting their scenes. Palettes kept (U0 watercolour, U1 four inks). Exceptions: TRI-63 `prp_u0_clock_pillar_face` is a whole clocktower spire, unusable as the pillar's dial (kept as a Truce landmark; v2 wanted as a flat dial); TRI-69 `prp_u0_pool_rim` is one front arc, unusable as a pool (v2 wanted as a top-down disc); TRI-43 `prp_u1_dojo_set_rusted_katana` stands upright (v2 wanted lying on its cloth); TRI-77 `prp_u0_doan_tree_stages` is the seed stage only (sprout, sapling, ash wanted). Pending: TRI-72 `prp_u0_klein_journal` has no PixelLab id. All five are ASSET_REQUESTS "Follow-ups". Note for the team: `prompt_used` is empty in every entry; fill it from now on. The delivery predates the Nov 1 direction, so the props sit at 20–247 px/m against the 32 px/m world; they stay until Nich asks for remakes. |
| 2026-11-02 | Four UI panels (battle command menu, party status card, menu kit, dialogue box), navy-and-gold | **ACCEPT**, unwired | Copied as delivered to `assets/ui/generated/`, rows in `source_art/MANIFEST.csv`. Not wired: the HUD and dialogue box stay code-drawn until Nich picks this set or the palette-locked frame in the style kit (QUESTIONS_FOR_NICH "Window frame A or B?"). |
| 2026-11-02 | The 256 px (and 128 px) "TRIGGER <Name> field v3" character sets on the account, about fifty, including the Crono core-7 clip set awaiting approval | **NOT IMPORTED** | Superseded by DECISIONS "Direction: the Nov 1 recipe is the style": the field tier is 64x64, three heads tall, 32 px/m. Nothing from these sets is deleted; they are not imported. The character import started that day was stopped before it wrote anything. Every open character request is re-specified at 64 px in `docs/ASSET_REQUESTS.md`; the team is asked to stop at the old size and wait for the approved anchor (QUESTIONS_FOR_NICH "The asset team's 256 px sets"). |
| 2026-11-02 | `TEST`-prefixed enemy sprites on the account (trance bellkeeper, debtling, moss mouse) | **NOT IMPORTED** | By rule: `TEST` and `REJECTED` items are never imported. Re-request at the enemy size classes once the anchor is approved. |
| 2026-11-02 | "TRIGGER Anchor Crono 64 v1" (`ca2300bc-7592-4606-8973-32b9bc00056b`), generated by the build lead at Nich's request from style-kit candidate 0 | **ACCEPT** as `crono` `px64` | 61 px = 1.78 m, idle + walk, Resurrect 64 palette, cell 96; `docs/screenshots/22_anchor_crono_px64_lineup.jpg`. It becomes the base `field` sheet when Nich approves the anchor and the palette; the remaining clips are ASSET_REQUESTS F6 / Batch 1 #0. |
