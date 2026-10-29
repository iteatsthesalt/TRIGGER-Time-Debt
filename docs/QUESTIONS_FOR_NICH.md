# Questions for Nich

Things I'd like your view on when you have a moment. None of them block the build; I made a call on each and noted it in DECISIONS.md.

1. **The Lv3 shave bonus timing.** I apply the +1 on the first matching strike of an action (total shave unchanged). The bible's pseudocode adds it after the last hit. Do you want the Break to be able to land one hit earlier like this, or strictly at the end?
2. **Crono's first lie.** I added "hold the wrist out" as a third option in the kitchen (Light +5). Is an honest Crono in the Prologue acceptable, or should the lie be forced so the Chapter 1 hearth is his first chance to tell?
3. **Dialogue data format.** Story scripts are JSON command lists (data/dialogue). If you'd rather write in a screenplay-like text format, I can add a converter.

## Art (2026-10-29, run 2)
- **Marle's proportions.** Your `npc_marle` is realistic (5.5 heads, 124 px); Crono/Sera/Krona are chibi (3.5
  heads, 86–101 px). Keep it as her field sprite, or regenerate a chibi v2 for field and use this one as her
  action-tier base? (ASSET_REQUESTS #3.)
- **Krona.** Two exist: mine with the nodachi in hand (`6af5c834…`, wired, idle + walk) and the bot's with
  them on her back (`364e2216…`). Which do you want animated? (ASSET_REQUESTS #2.)
- **Action-tier directions.** Cut-ins currently need south, west and east only; say if you want all eight for
  any sequence (it triples the clip cost).
