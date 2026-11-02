# Questions for Nich

Things I'd like your view on when you have a moment. None of them block the build; I made a call on each and noted it in DECISIONS.md.

1. **The Lv3 shave bonus timing.** I apply the +1 on the first matching strike of an action (total shave unchanged). The bible's pseudocode adds it after the last hit. Do you want the Break to be able to land one hit earlier like this, or strictly at the end?
2. **Crono's first lie.** I added "hold the wrist out" as a third option in the kitchen (Light +5). Is an honest Crono in the Prologue acceptable, or should the lie be forced so the Chapter 1 hearth is his first chance to tell?
3. **Dialogue data format.** Story scripts are JSON command lists (data/dialogue). If you'd rather write in a screenplay-like text format, I can add a converter.

## Combat (2026-10-29, run 3)
- **How much may the 999 Shard Doll crack Crono?** A floor (a member left at 1 HP) now costs 2 integrity
  for the first five floors only (10 total); before, a slow party lost all 100 during the split lesson. Is 10
  the right ceiling for a tutorial, or should the dummy cost nothing at all?
- **Should the split dolls be killable?** They are undamageable now so the lesson is about Breaks (they had
  ~100 HP and died to plain hits with plates up). If you want them killable, they need the boss's HP pool.

## Art (2026-10-29, run 2)
- **Marle's proportions.** Your `npc_marle` is realistic (5.5 heads, 124 px); Crono/Sera/Krona are chibi (3.5
  heads, 86–101 px). Keep it as her field sprite, or regenerate a chibi v2 for field and use this one as her
  action-tier base? (ASSET_REQUESTS #3.)
- **Krona.** Two exist: mine with the nodachi in hand (`6af5c834…`, wired, idle + walk) and the bot's with
  them on her back (`364e2216…`). Which do you want animated? (ASSET_REQUESTS #2.)
- **Action-tier directions.** Cut-ins currently need south, west and east only; say if you want all eight for
  any sequence (it triples the clip cost).

## Text layer (2026-11-02)
- **Where do Mid Tonic, Revive and Cobalt Wash come from?** The writers found no vendor, chest or drop for
  them in the data or the bibles, so `data/text/items.json` says "Acquisition source not yet recorded." for
  exactly those three (Linear TRI-79). Name a source for each (a Truce shop, a chest in the Atrium, a drop)
  and the build lead will write the five-word `found` line and, if it is a shop, the stock entry.

## Props (2026-11-02)
- **Robo's clock face.** TRI-63 `prp_u0_clock_pillar_face` came back as a whole clocktower spire, not a flat
  dial for the Atrium pillar, so the pillar keeps its primitive porcelain face with the moving hands and eyes.
  Do you want a v2 as a flat 256 dial (hands left off: the engine moves them), or shall the spire become the
  Truce skyline landmark and the pillar face stay code-drawn?
- **The Atrium pool.** TRI-69 `prp_u0_pool_rim` is a single front arc of rim. A billboard cannot read as a
  round pool from the 32° camera; shall the pool be a top-down tile (a 256 disc with its water, PRP-M) or a
  glTF ring from the kit?
- **Klein journal id.** TRI-72 lists icon/field/pages variants but no PixelLab id; the journal is declared
  `pending` in `data/props/props.json` and stands in as a labelled box.
- **Prop heights.** Each imported prop has a height in metres in `data/props/props.json` (the hearth 1.9 with
  its chimney breast, the oak table 1.2, the portcullis arch 4.0, the torii 4.0; the reasoning in `notes`).
  Overrule any of them there; the room updates by itself.

## Style bible, Phase 1 (2026-11-02): see docs/screenshots/20_style_bible_kit_review.jpg
- **Scale: answered in session (the Nov 1 recipe: 64 px three-head sprites, a 32 px/m world).** Still open from the sheet: which anchor candidate and which palette. Three sizes existed before the answer: the 128 px chibi field tier the engine ships
  (Crono 95 px tall), the asset team's 256 px "field v3" sets on the account, and your Nov 1 breakdown's
  32/64 px three-head recipe. Section A of the sheet is that recipe: a 64x64 anchor in the Resurrect 64
  palette (16 candidates; 0, 8 and 12 read best to me; the gauntlet lands on the wrong arm in most, an
  inpaint fixes that). Pick a scale and, if 64, a candidate and a palette (Resurrect 64 is a proposal;
  Apollo, Endesga 64 and Jehkoba64 are saved beside it) and every later request follows it.
- **Window frame A or B?** A = the palette-locked 9-slice frame in the sheet (section C); B = the asset
  team's navy-and-gold dialogue box and menu kit (now in `assets/ui/generated/`). The dialogue box stays
  code-drawn until you choose.
- **Textures:** the twelve U0 textures are in the rooms now (screenshot 21). Say which to redo; they cost
  one generation each.
- **The asset team's 256 px sets.** About fifty canonical `TRIGGER <Name> field v3` characters on the
  account are at 128 or 256 px and are not imported (DECISIONS, "Direction"). Do you want the team told
  to stop at that size and re-spec from the 64 px anchor once it is approved? I can post the note in
  #all-trigger, or you can.

## Repository (2026-11-02)
- **Tag the Trigger repository.** `prototype/` is deleted from this repository; the bibles now point at
  iteatsthesalt/Trigger @ aea60a2. Please add a tag there (`prototype-snapshot-2026-10-29`) so the reference
  survives branch cleanup, and say whether that private repository should stay private (ChatGPT and Cursor
  cannot read it) or be made public.
- **The four draft PRs on Trigger (T-2 to T-5).** The main game has superseded GameState and the dialogue system;
  the three-part boss framework and the balance-sheet test are worth porting when a boss needs parts. Close or
  keep?
