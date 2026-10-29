# Bot deliveries: how to deliver, and the audit log

Nich's asset bot (Grokbot) is connected to this repository. This file is its contract and its review record.
The studio assistant audits every delivery against `docs/ART_PIPELINE.md` and the Reference Bible, writes the
verdict below, and the bot fixes what is flagged before the next batch.

## How to deliver

1. **Generate in the shared PixelLab account** from `docs/ASSET_REQUESTS.md`, naming each item exactly
   `TRIGGER <Name> <tier> v<N>` (`TRIGGER Krona field v1`, `TRIGGER Ashen Ashigaru field v1`,
   `TRIGGER Crono action v1`, `TRIGGER Sera u1 field v1`). The name is how the importer finds the tier and
   variant; a wrong name is the most common reason an asset cannot be imported.
2. **Register what you made** by appending to `data/art/incoming.json` (create it if missing), one object per
   item:
   ```json
   {"asset_key": "ashen_ashigaru", "tier": "field", "variant": "", "pixellab_id": "<uuid>",
    "pixellab_name": "TRIGGER Ashen Ashigaru field v1", "kind": "character",
    "animations": ["idle", "walk", "attack", "hurt"], "request": "Batch 4 #30",
    "prompt_used": "<the prompt you sent>", "date": "2026-10-29"}
   ```
   `kind` is `character`, `object`, `tileset`, `map_object`, `ui`, `portrait`, `texture` or `vfx`. The
   importer pulls the files by id, so you do not need to commit PNGs for PixelLab items.
3. **Anything not made in PixelLab** (a texture from another generator, a hand-made PNG) goes under
   `assets/incoming/<asset_key>/` as PNG with a `meta.json` (`asset_key`, `tier`, `kind`, `source`, `prompt`,
   `size`, `license` if third-party), registered in `data/art/incoming.json` with `"pixellab_id": null` and
   `"path": "assets/incoming/<asset_key>/"`.
4. **Commit only those paths**: `data/art/incoming.json` and `assets/incoming/**`. Do not edit anything else
   (scenes, scripts, data, docs, `assets/characters` and so on belong to the build agents). Commit message:
   `bot: <asset_key> <tier> (<kind>) — <one line>`. Pull with rebase before every push; never force-push.
5. **One item per commit**, so a bad one can be reverted alone.

## What the audit checks

- Name and tier match the request; the id resolves on PixelLab; the character is complete (all 8 directions
  for field, S/W/E at least for action) and the requested clips exist.
- Identity against the catalog image and the Reference Bible brief (costume, asymmetry, weapon, palette).
- Scale: the character's height in pixels matches `height_m` × 64 px/m within 10% once imported (Crono 95 px
  chibi at 128).
- Canvas: U0 watercolour, U1 four inks only (sumi black, cobalt, cinnabar, paper white; no gold, no grey
  gradients), U2 clay with VHS, and so on per Reference Bible §3.
- Readability at gameplay distance: strong silhouette, one focal element, no mud, no magenta or background
  fringe, hard alpha.
- Nothing from an existing game copied into a sprite (Chrono Trigger's own sprites are the *reference for
  proportion and feel*, never a source to trace).

Verdicts: **ACCEPT** (imported as is), **ACCEPT WITH FIXES** (imported; listed fixes wanted in v2),
**REJECT** (not imported; regenerate with the listed changes).

## Audit log

| Date | Item | Verdict | Notes |
|---|---|---|---|
| 2026-10-29 09:45 | — | — | No deliveries in the repository yet (no commits, branches, PRs or issues from the bot). Waiting for the first `data/art/incoming.json`. |
