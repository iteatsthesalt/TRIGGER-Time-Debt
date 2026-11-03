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

## Calls made while fixing the code audit (2026-11-02)
Each of these is built one way and recorded in DECISIONS ("Code-audit fixes, second pass"); say if you want it the
other way and the build lead changes the data or the rule.

### Gate toll and story runner
- Gate toll: Sera's +5 Translucency Debt is charged on every first gate traversal even while she is
  captive/hovering (her debt is 'the clock' of her seven days per Story Bible §9.5). Should a jump made without
  her cost her nothing instead?
- Gate toll: a direct jump from one non-hub universe to another (U1 → U2 without passing the Atrium) opens the new
  gate and pays once, the same as from the hub. Is that the intended reading of 'every new gate jump along the
  story thread'?
- Boot/debug runs that start in a non-U0 location (`--location=<u1 scene>`) now pay one gate toll on arrival (0.4
  integrity, +5 debt) because the Router sees the universe change. Fine for probes, or should boot starts be
  exempt?

### After a battle and Withdraw
- After a won battle, a member who fell stands up at 1 HP, per the style-breakdown note. Is 1 HP right, or should
  the fallen get more?
- Withdraw now takes two of the withdrawing ally's turns from the opening spots: a 6 m fall-back toward the edge,
  then the attempt. The ally teleports rather than walks. Is a two-turn retreat the feel you want, or should
  Withdraw be allowed from anywhere on the plane?
- Combat Laws 16.1 says a defeat jumps the party back to 'the moment before the encounter'. The game still puts
  them at the location's spawn marker. Should it put them where they stood before contact instead (the enemies
  would need to be moved back too)?
- Withdraw is not offered in story battles (the script decides their ending). Should some story battles allow it?
- After a withdraw the leader regroups where the withdrawing ally broke away, and the followers snap in behind.
  §2.1 says exploration resumes from the exact positions the actors ended in. Should each member instead stay
  where it stood on the plane, kept on the floor?

### Battle scene and sound ids
- 21 sound ids that scripts or dialogue play have no file under audio/sfx; lint_data.py now lists them. Examples:
  combat/phase_shift, weapons/parry_don, time/amber_chime, ui/heal_chime. Also not linted but missing:
  time/gate_open_u2..u8, and magic/<element>_contact for every element except astral/ruin/tachyon (Marle's Light
  Bolt plays nothing). Should these go into ASSET_REQUESTS for the asset team, or should some be aliased to
  existing placeholder sounds?
- Chapter 2's dialogue names sounds in a different scheme (sfx_magic_astral_burn, sfx_time_rewind, ...) that never
  resolves under audio/sfx/<folder>/<name>. Should the studio assistant's generator use the folder ids (e.g.
  time/rewind), or should the files be delivered under those names?

### Sera's look
- Sera's crack under her left eye: it is now drawn as the shader's hairline veins wherever the crack noise peaks
  across her sprite, spreading with her Debt (0.2 + Debt/100). It looks like nothing before her first Rewind (Debt
  0 in a new game). Keeping it under her left eye needs a sera_field_m.png mask plus a shader change that limits
  the state-2 veins to the mask, which is the render cluster's file. Do you want that mask requested, or is the
  body-wide hairline acceptable until then?
- Sera's field translucency is 1 - 0.005 x Debt (about 0.73 at the 55 cap). The sprite shader now fades it for
  real (a separate blended pass). Is that curve the look you want?

### Bosses
- Krona duel: taking the gauntlet overcharge now ends the duel at once with an outright ASTRAL Break, and 'Hold'
  lets it run to 50% HP. Is that the reading you want, or should the overcharge only become possible once she is
  at 50%?
- Shard Doll: with the Break now playing out between phases, a Lv 4 party crits it from 9,000 HP down to about
  2,800 by phase 2 (battle_probe). A strong party could kill it through HP before phase 4. Should it have an HP
  floor so it 'cannot be killed, only broken', or is a kill an acceptable early end?
- Goyama Daimyo: ch2_daimyo_phase2 opens with 'Break. The petitions scatter', but phase 2 begins on the 75% HP
  window, not on phase 1's Break. Should Scribe of Order use advance_on 'break' (the bible gives no HP windows for
  the Daimyo)?
- Possibility Branches are asked through the dialogue box until each chapter's director stages the in-world action
  the bible describes. Is a menu acceptable as the fallback?
- A few authored phases can never be reached by HP because the phase before them ends at 0%: azar red_moon,
  guardian_triad dance_not_curse and r66y mother_brain_unmasked. Should they be director-entered, or should their
  windows change?

### Statuses
- Ruin is cleared at the end of each battle for now (there are no camps yet). When camps arrive, should Ruin, Camp
  Strain and Concerned all persist in Game (roster rows, saved) until the camp, as Combat Laws 12.2 and 12.3 say?
- A GUILTY enemy's turned area attack currently hits only the one ally it turned on. Should a turned AoE hit every
  one of its allies inside the shape instead?
- Under BLIND the plate preview shows the shave of a hit that lands, not the odds of a miss. Do you want an
  expected-shave readout or a 'miss risk' tag on the plate while the party is blinded?
- Confuse ('30% chance each action targets a random battler') has no reader. On party members it would change a
  target the player picked. Should it redirect the player's chosen target, or only affect enemies and autobattle?
- The Prop Chest Mimic's springs_cut condition waits on its three spring-puppet sub-targets, which don't exist
  yet. Until they do, the Jester Box can be shaved to 0 but never Breaks. OK for an unbuilt U5 elite?

### Resolution rules
- Divinity Field cap: I read '20% of max HP as temporary shield' as 4 temporary plates on a shielded body (one
  plate = 5% of max HP), and 5% of max HP of temp shield per 5 s on an ally, up to 20%. Is that the intent, or
  should an enemy's cap be 20% of its own plate count?
- NULL Lv4 white blank vs the Canvas Clash blank: I made only the Boost Lv4 residual strip the tags of hits inside
  it. The blank every NULL hit leaves is terrain only, so the fake weakness NULL creates can still be hit. Agree?
- Perfect frame (x1.15 on the key pose): the hook exists, but nothing calls it until battle sprites expose
  key-pose timing per canvas. Should it wait for the 64 px animated sprites, or should I ship a simple
  timed-confirm stand-in now?
- Divinity Field: the temporary-plate cap is now a flat 4 plates (1 plate = 5% max HP, the 20% cap) for every
  enemy. Under the old HP-scaled formula, a 64,000 HP boss could hold about 256 plates. Is a flat 4 the feel you
  want for U3 bosses inside Divinity?
- Height: should enemies also get the ±10% ledge term (and the damage preview show it), or should height favour
  the party only?

### Technique effects
- Ashtear Paradox: 'High Cassia Synergy triggers Lucca's final schematic'. I read this as the Triple's synergy at
  the three-universes level. If you meant Cassia-09's affinity with Crono (§15.9), the row's synergy_min condition
  should read that affinity instead.
- Rewind Reel says enemies go back to where they were '8 s of battle time ago'. The engine only remembers each
  body's last turn start, so for now they go back there. Do you want a real 8 s history recorder (a small
  per-battle ring buffer of enemy positions, gauges and telegraphs)?
- First Light That Never Was 'heals the party for what it deals'. I share the damage dealt out evenly across the
  party, not the full amount to each ally. Is that the intent?

### Progression and data
- Vaelos Child (Combat Laws 14.12): Tantrum and Hide and Seek list 6 plates, but their keys weigh 5. The data now
  plays 5. Should a sixth keyed plate be added? The file notes suggest a trailing DARK->LIGHT (-1) for Tantrum;
  Hide and Seek's materials do not match the stated counts at all.
- Coop techs: should a Dual/Triple be offered whenever any of its actors knows it, or only by the actor whose kit
  lists it (today's convention)? And which kits should list time_debt_paid (Ch8) and fake_family_photo (Ch1)?
  Today no kit lists them and no dialogue teaches them.
- Atropos Ribbon is now a `story` unlock (the True Ending route). Which chapter beat should teach it: the
  Atropos-00 ribbon rescue in the Geno-Foundry, or the Heart?
- Chapter 2 grants vaelos_tooth with key_item, but Combat Laws 11.14 makes it a relic. The catalogue says relic
  and Game.grant follows the catalogue; the chapter 2 generator should switch the verb to `relic` (lint warns).
- assets/enemies/citizen_husk/ holds a delivered painting that matches no enemy or boss. Which codex entry is it
  for, or is it an NPC?
- Effective Rank Level reads an enemy's authored level as its rank inside the universe band (ERL + authored - band
  minimum). Is that the intended reading, or should every regular enemy fight at plain ERL?

### Engine, music and endings
- The music now dulls with Crono's integrity (porcelain_stress = 100 - integrity drives a low-pass): about 13 kHz
  at 60 integrity, 9.5 kHz at 40, 2.5 kHz at the flatline. Is that the degradation you want for most of the game,
  or should the filter only start lower down (say below 40)?
- Atrium Siege: the first cut is only the frame (counter, Sera reglazes Crono to 20, a jump back to the last
  Atrium save). When should the three waves (Lavos-spawn, Bekkler failures, Vaelos's 22-plate projection) and the
  lost vendor families be built, and should an ordinary defeat ask 'the moment before the fight or the Atrium?' as
  Combat Laws 16.1 allows?
- Six new ending flags (Native_Duplicate_Given, Crono_Entered_Heart_At_20, Porcelain_Stress_Held_100,
  Seed_of_Doan_Full, Mycelia_Tether_Mastery, Codex_True_Null) got short Codex Keeper pages from the build lead.
  Keep them, or should the text writer redo them?

### Prologue and Chapter 1
- The hearth confession now pays Told Light +10 / Hidden Dark +10 from the flag data. The bible lists no affinity
  for Crono_Confession. Keep ±10, or set it to 0?
- A dry R press in the hub is now free (only a line). Do you want the field Rewind to cost Debt even when there is
  nothing to rewind, as the old line 'The Debt took its 5% anyway' did?
- When Leene Square is built, its first checkpoint should write the arrival autosave and set Sera's story state.
  Until then Chapter 1 ends with a caption at the Fair call. OK as a stopgap?

### Chapter 2 audio
- Chapter 2 now reuses existing sounds for two cues: porcelain/crack_large for the clay gear crashing into the
  pagoda, and ui/page for peeling the paper off a doorway. Should the asset team make dedicated cues for these
  (for example impact/clay_crash and ui/paper_tear)?
- The Furnace approach now plays mus_sera_theme, because the scene opens on Sera in the cage and the old id had no
  file or track brief. Do you want a separate approach track, or is Sera's theme right there?
- The Chapter 2 boss and interlude tracks are now the Reference Bible 8.5 ids: mus_u1_boss_daimyo,
  mus_u1_boss_weeping_shogun and mus_sera_interlude. They will play silence until someone delivers them; please
  confirm they belong on the audio schedule.

### Tooling
- check.sh now runs the three headless probes on every check, which adds about 3.5 minutes; ch1_probe alone is
  about 165 s. Keep it that way, or move ch1_probe into a nightly or --full step?
- Reference Bible 10.1/10.2 (TOOLS-11): should the bible drop gdlint, build_all.gd and the three unbuilt test
  scenes (canvas_switch, vfx_gallery, audio_board), or should they be scheduled? And which headless asset check
  comes first: palette per canvas, frame counts and fps, or loudness?
- Should the playable cast ever ship as a four-rotation character, now that the importer makes a 4-row sheet for
  one? Or should the importer refuse fewer than eight rotations for the cast?

### Rendering
- SDFGI: Reference 2.3 asks for it on at energy 0.2. It is off today because the cloud container cannot render it.
  Should it be on by default on your PC (with a low/high quality option), and do you want the glow as soft-light
  bloom 0.35 (today) or the MIX blend at 0.35? A side-by-side capture on your GPU would settle both.
- Section 12 of the breakdown versus Reference 2.2-2.3: we kept ACES, the 1.15/0.85/0.35/0.9 glow and the 2-split
  sun. Do you want AgX/Filmic, the 0.3-0.6/0.05/1.0 glow or the 4-split sun with blur and opacity tried in a
  capture first?
- Ghosts (the field and battle Rewind, the Boost style bleed), a phased Sera and the Debt fade now draw truly
  translucent and cast no shadow while faded. Is that the look you want, or should translucent sprites keep a
  faint shadow?
- Marle: the old animated assets/npcs/marle sheet was removed, so her only sheet is the one-frame realistic
  marle_field. She glides in her idle pose when the breakfast scene walks her. Regenerate her as a 64 px recipe
  sprite with a walk, or keep this one for the action tier?
- With any Translucency Debt, Sera is now drawn by the blended fade pass (so her opacity really thins), and that
  pass casts no shadow. Is a shadowless, slightly see-through Sera at low Debt what you want? Or should she keep
  her shadow and stay on the opaque pass until some Debt threshold (for example 20)?

### Techniques as built
- Rewind as built is literal: the target goes back to its turn start with the gauge at the gate. Rewinding an ally
  hands it its turn again (and +1 BP) for 5% solidity, which is more than Borrowed Future gives for 10%. Rewinding
  an enemy heals it and gives it its turn back. The Shard Doll phase 2 hint ('Sera: Rewind its gauge when it winds
  up') and the bible line 'rewind the doll's gauge by one turn' both read as a setback for the enemy. Should the
  turn start instead be the moment its last action ended (gauge 0, a wind-up in progress cancelled)? That would
  also move Time Mines' ghosts, which sit at last-turn-start positions.
- Fake Family Photo Real (CIRCLE 4.0, heal 0.6) has no `target` in data, so the deck aims it at enemies. Its
  handler, shared with the Dual, heals only Crono to 60% and clears 20% strain. The bible says every ally inside
  is healed to at least 60%, the strain drops and the party is Reinforced. Should the row say target 'party' and
  the handler heal every ally inside?
- Several techniques with no damage in the bible (Miura Fold, for example) carry TechDef's default power 1.0 and
  hits 1. Their previews are now empty because their handlers strike nothing, but should their rows say
  `is_attack: false` explicitly?

### From the final integration review
- Should a boss director's on_defeat also wait for the victory? It currently runs when the boss falls, which is
  right for presentation (the Cradle's message and canvas). But if a future director grants flags or counters in
  on_defeat, they would stick after a loss in which the adds won after the boss fell. Today only the Shard Doll
  does that, and its fight cannot be lost.
- A zone enemy keeps the Effective Rank level it spawned at, while its mid-battle summons use the party average at
  the time of the summon. If the party levels between battles, a re-fought summoner and its new adds can differ by
  a level or two. Should zone survivors be re-ranked when the zone re-arms?
- Guilt Halo now steals 1 BP per cast however many bodies Break, following §7.5 'one steal per Glenn action'. Did
  you mean 1 BP per Broken body, capped at 3 per action? Say if you want it per body and it becomes a one-line
  change.
- The bible gives three self-silences on Break with no implementation yet: the Gene Scribe (E42), Azar phase 1,
  and Azar phase 4 ('every time she is Broken she silences herself for 15 s'). With this fix they would now seal
  the enemy's techniques. Should they be wired as an enemy behaviour key (e.g. silence_on_break_s)?
- The preview still does not forecast the mercury pool's +20% on the first FERRO hit, or the damage change when a
  Break lands mid-action. Is that close enough for the aim line, or should the estimate simulate the strike
  sequence?
- Rewind and Ruin: I made Sera's Rewind take back Ruin gained since the target's turn start, for Crono and every
  ally alike, following the bible's 'statuses gained since'. Would you rather Ruin survive a Rewind because it
  'only thaws' (it is on the cleanse keep-list)? That is a one-line change in rewind_unit.
- Bekkler's Guilt now follows the §11 table: it no longer pulls every attack onto Crono. Only hits aimed at allies
  inside his 4 m ring are turned onto him, at 75% damage and +1 BP each (2 at most). Is that the intended feel for
  the Prologue reward?
- Ruin-infused (the Shogun's Command payoff) is read as 'the next landed strike ignores DEF', a single strike.
  Should it instead cover the whole next action, so every hit of a multi-hit tech ignores DEF?
- Battle placement: where the near side meets a wall or the void, the party fan now turns about the centre,
  sometimes to the far side of the enemies. Example: kitchen_spoons, with the hall's south wall 1.8 m away. After
  that fight the party is handed back near the neighbouring shardlings zone, so a second fight can start right
  after the first. Should the hall zones be spread further from the south wall and from each other, or is a
  chained encounter acceptable?
- Time Debt Seal is now learned silently at breakfast's 'TIME DEBT' beat, with no caption. Should the studio
  assistant write an announcement for it, as the Cradle does for Fall Break?
- Debug starts (--scene, --checkpoint and so on) now keep their saves in scratch unless you pass --save. Is that
  how you want hand-testing from the command line to work?
- Opening and time-skip captions now show over black at the top centre of the screen, where the in-scene caption
  label already sits. Do you want a centred title-card look for captions shown on black instead?
- Note: while checking that the tests catch the bugs, a temporary revert made one test run remove this container's
  shared user://scratch directory. That directory holds only probe and test scratch files, never player saves. If
  an older build's probe in another worktree on this machine failed around 03:22 UTC, re-run it.
- Should a KO end Sera's phase? Right now a DoT that kills a phased Sera leaves the phase running. A revive brings
  her back still phased and untargetable, and she now looks phased to match. The alternative is to clear the phase
  on a KO, so she revives targetable at her Debt opacity.
- README 'Boot arguments' needs a line for the new --debt=<n> (it sets Sera's Translucency Debt and counts as a
  debug start). README and the capture docs should also mention smoke.gd's --capture_after=<signal>:<seconds> and
  --max_frames=<n>. The gate's battle shot is now /tmp/captures/check_test_arena_battle_started.png, not
  check_test_arena_0120.png.
- Ens Parry tuning: a press is spent for 0.5 s of battle time, and a press arms only the guards a wind-up is aimed
  at (all guards when none is, or for an area attack). Should the recovery be shorter or longer, and should a
  perfect parry clear it at once so a quick follow-up can be parried too?
- There is no on-screen hint for the parry key (G / joypad L1) yet, and the bible's 'closing sumi-e circle' window
  art is not drawn. Should the Guard command's deck line show 'G: parry', and should the circle go on the asset
  request list?
- The headless probes still print exit leaks (about 46 ObjectDB / 22 resources, probably the same audio playbacks
  still mixing at quit). The gate does not fail on probe leaks yet. Should the probes drain audio the same way and
  fail on leaks too?
- H7 is pinned by a test that checks the text of check.sh and smoke.gd (--no-save on every smoke.gd call, and the
  reset_settings call), not by a run that proves a capture ignores a planted settings.cfg. Is that enough, or do
  you want a Linux-only behaviour test that runs smoke.gd against a fake user folder?
- Balloon Escape now foils one BP theft per cast (the next theft against the party), and every [FIRE] hit on the
  inflated body is a 'miss' for 2 s. Is that the reading you want?
- Should Sunlight Stacks, Static's Tune and Xyloph's tether nodes reset each battle, as built? Sunlight is also
  gained in U3 light shafts, which could be meant to carry over from the field.
- Miura Fold is now pending and not offered until there is a damage hook for its shared HP pool and the split on
  the snap. Is that acceptable for Omega-Spekkio (Chapter 8), or should it be built sooner?
- Oil-Drinker+ (Geothermal): which beat and flag earn it on the U2 ruthless road? Its +25% crit was dead code and
  is now listed as unbuilt.
- battle_coordinator.gd is now 815 lines, still above the ~600 rule. Should the timeline (advance, gauges,
  windows) be split into its own class next?

## Title, cast and the audit (2026-11-02)

1. **Release title and cast names.** The Nov 1 breakdown's section 14 says a release title must not contain 
   "Chrono" or "Trigger" and that Square Enix's characters, places and names must not be the game's own canon. 
   Today the project ships "TRIGGER: Time Debt", a title footer that said "a sequel to Chrono Trigger" (removed 
   today; README calls the title a working title) and a cast of Crono, Marle, Lucca, Robo, Glenn, Magus and the 
   rest by name in 54 data files. Nothing in the code depends on the names (ids are data), so a rename is a data 
   and text pass once you choose. Do you want (a) a new title now, (b) new names for the cast now, or (c) both 
   deferred until the story is locked? The prompts the asset team uses are already name-free either way.
2. **The asset team's open items** (from its hourly Slack status, still unanswered as of Oct 30 12:11 ET): Sera's 
   colours (proposed hair #C25A3C, jacket #3F7F7A, scarf #B3402F; note that the Direction decision now asks for
   the Resurrect 64 palette, so these need snapping or a palette decision first), Crono core 7 sign-off, which
   Krona to animate, whether Enemies and Bosses may spend below the 1,500 floor (the account now shows 9,074
   generations remaining of 18,710), whether the 12 world-map marker props skip the palette check, and the Bible
   section 6 plate count (8 world plates and 4 sheets vs the headings' 7 and 5). The team's deliveries are still
   at 128 and 256 px; per the Direction decision nothing new should be generated until the style gate (anchor,
   palette, frame) is confirmed, so the cheapest answer is the style gate itself.
3. **Audio in git** (HYG-8). About 98 MB of the 173 MB tracked is deterministic generated audio and 22 files
   already have several blob versions in history. Options: Git LFS for `audio/`, a release bucket with the build
   script fetching it, or leave it (the repository is still small enough to clone). Your call; the build lead can
   do any of the three in an hour.
