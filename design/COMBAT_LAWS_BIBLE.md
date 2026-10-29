# TRIGGER: Time Debt — Combat Laws Bible

Every number in this bible is a starting value: tune it for feel.

This is the complete combat design for the game: how a fight starts on the field, how the timeline runs, how shields Break, how Boost and Time Debt are paid, what every character, technique, enemy and boss does, and how to build it in Godot 4.7. The Story Bible owns the plot and the Reference Bible owns the look and sound; where they touch combat, this bible owns the rules.

## Contents

- [1. Combat at a Glance](#1-combat-at-a-glance)
- [2. Battle Space](#2-battle-space)
- [3. The Timeline](#3-the-timeline)
- [4. Commands](#4-commands)
- [5. Shields, Weaknesses and BREAK](#5-shields-weaknesses-and-break)
- [6. Damage Pipeline](#6-damage-pipeline)
- [7. Boost Points, Beckons and the Prometheus Core](#7-boost-points-beckons-and-the-prometheus-core)
- [8. Tech Geometry and Positioning](#8-tech-geometry-and-positioning)
- [9. Elements, Tags and the Elemental Canvas Clash](#9-elements-tags-and-the-elemental-canvas-clash)
- [10. Character Kits](#10-character-kits)
  - [10.1 Crono (41) — ASTRAL](#101-crono-41--astral)
  - [10.2 Sera (17) — TACHYON](#102-sera-17--tachyon)
  - [10.3 Krona — RUIN](#103-krona--ruin)
  - [10.4 Cassia-09 — FERRO](#104-cassia-09--ferro)
  - [10.5 Xyloph — MYCELIA](#105-xyloph--mycelia)
  - [10.6 Vesper (Alfador) — VITREOUS](#106-vesper-alfador--vitreous)
  - [10.7 Pierrot-Glenn — GUILE](#107-pierrot-glenn--guile)
  - [10.8 Static (13) — HZ](#108-static-13--hz)
  - [10.9 Omega-Spekkio — NULL](#109-omega-spekkio--null)
  - [10.10 Bonus member: Vaelos (child form)](#1010-bonus-member-vaelos-child-form)
  - [10.11 Guest: Marle (Queen Nadia, 40)](#1011-guest-marle-queen-nadia-40)
- [11. Tech Library](#11-tech-library)
- [12. Status Effects and Hazards](#12-status-effects-and-hazards)
- [13. Enemy Codex](#13-enemy-codex)
  - [13.1 How to read an entry](#131-how-to-read-an-entry)
  - [13.2 U0 — Atrium Horologe and Truce (Lv 1–4, watercolour 60 fps)](#132-u0--atrium-horologe-and-truce-lv-14-watercolour-60-fps)
  - [13.3 U1 — Crimson Shogunate (Lv 5–11, sumi-e 24 fps)](#133-u1--crimson-shogunate-lv-511-sumi-e-24-fps)
  - [13.4 U2 — Clockwork Ossuary (Lv 12–22, clay 12 fps + VHS)](#134-u2--clockwork-ossuary-lv-1222-clay-12-fps--vhs)
  - [13.5 U3 — Saurian Eden (Lv 21–30, Moebius ligne claire 30 fps)](#135-u3--saurian-eden-lv-2130-moebius-ligne-claire-30-fps)
  - [13.6 U4 — Drowned Cathedral (Lv 31–40, stained glass)](#136-u4--drowned-cathedral-lv-3140-stained-glass)
  - [13.7 U5 — Carnival of Ash (Lv 41–50, 1930s rubber-hose)](#137-u5--carnival-of-ash-lv-4150-1930s-rubber-hose)
  - [13.8 U6 — 1999 A.D. Singularity (Lv 51–60, 1988 cel anime)](#138-u6--1999-ad-singularity-lv-5160-1988-cel-anime)
  - [13.9 U7 — Bone-Tree of Eternity (Lv 61–70, Amano gold leaf)](#139-u7--bone-tree-of-eternity-lv-6170-amano-gold-leaf)
  - [13.10 U8 — Vaelos Heart (Lv 71–80, all nine canvases)](#1310-u8--vaelos-heart-lv-7180-all-nine-canvases)
  - [13.11 Endings, side quests and post-game (Lv 58–99)](#1311-endings-side-quests-and-post-game-lv-5899)
- [14. Bosses](#14-bosses)
  - [14.1 Rules every boss follows](#141-rules-every-boss-follows)
  - [14.2 Prologue: Atrium Cradle](#142-prologue-atrium-cradle)
  - [14.3 Chapter 1: The 999 Shard Doll](#143-chapter-1-the-999-shard-doll)
  - [14.4 Chapter 2: Crimson Shogunate](#144-chapter-2-crimson-shogunate)
  - [14.5 Chapter 3: Clockwork Ossuary](#145-chapter-3-clockwork-ossuary)
  - [14.6 Chapter 4: Saurian Eden](#146-chapter-4-saurian-eden)
  - [14.7 Chapter 5: Drowned Cathedral](#147-chapter-5-drowned-cathedral)
  - [14.8 Chapter 6: Carnival of Ash](#148-chapter-6-carnival-of-ash)
  - [14.9 Chapter 7: 1999 A.D. Singularity](#149-chapter-7-1999-ad-singularity)
  - [14.10 Chapter 8: Bone-Tree](#1410-chapter-8-bone-tree)
  - [14.11 Chapter 9: Vaelos Heart](#1411-chapter-9-vaelos-heart)
  - [14.12 Endings](#1412-endings)
  - [14.13 Side quests and post-game](#1413-side-quests-and-post-game)
- [15. Progression](#15-progression)
- [16. Failure and Recovery](#16-failure-and-recovery)
- [17. Feedback and Audio Hooks](#17-feedback-and-audio-hooks)
- [18. Godot 4.7 Implementation Notes](#18-godot-47-implementation-notes)
- [Appendix A. Audit Notes](#appendix-a-audit-notes)

## 1. Combat at a Glance

TRIGGER: Time Debt fights where you explore. There is no encounter screen and no loading: when the party touches an enemy, a 28 × 28 battle plane settles over the ground you were walking on and the fight happens in that real space, with the walls, cliffs, puddles and bodies you can see. It is Chrono Trigger's Active Time Battle (live gauges, enemies that move, Dual and Triple Techs aimed at where enemies actually stand) welded to Octopath Traveler's Break and Boost (shield plates, weakness reading, banked Boost Points spent for bursts), on top of the story's central idea: time is a debt, and someone always pays it.

The core loop, start to finish:

1. Touch an enemy in the field. The battle plane spawns over the current terrain; actors keep their positions.
2. Read each enemy's Shield Plate: how many plates it has and which weaknesses are known (`[SWD][?]`).
3. Gauges fill on the Turn Bar. Each battler has its own speed and its own rhythm.
4. When any gauge reaches 99.0, every other gauge freezes: **Sync Hold**, an unlimited decision window to move, choose a technique and decide how much Boost to spend.
5. Hit with matching tags. Every matching tag on every hit shaves the shield.
6. Spend Boost Points. Level 3 (3 BP) is the key breakpoint: 370% power, a bigger shape and +1 flat shave.
7. Drive the shield to 0: **BREAK**. The target cannot act, its DEF halves, every hit on it is critical, and its body freezes mid-step and becomes terrain.
8. Pour high-BP Techs and Dual/Triple Techs into the Break window.
9. Manage what it costs. Crono pays for his techniques with his own maximum HP; Sera pays with her own solidity. Burst too greedily and the bill comes due in later fights and in the story.
10. If the target survives, its shield rebuilds after 3.0 s at 18% per second and it resumes moving with a 0.4 s blend.

What makes it this game and not either of its parents:

- **Time Debt as a resource.** Crono-41 is a porcelain copy; his ASTRAL techniques cost his maximum HP, not MP, and the porcelain cracks on screen as he pays. Sera's techniques cost her solidity; at 40% she phases out of existence for two turns. The two economies are joined: when the copy is cracked, his daughter's time travel cracks him further.
- **Space matters.** Techs have shapes (SINGLE, LINE_PIERCE, CIRCLE, SELF_AURA, CONE). The TacticalPositioner shows how many hits a shape will land before you commit. Broken enemies are frozen in place, so a Break is also a setup for the next shape.
- **Nine canvases in one fight.** Every party member keeps their own art style and animation rate in every universe: Crono's 60 fps watercolour beside Cassia-09's 12 fps clay beside Krona's 24 fps sumi-e. Gameplay never reads the art style; but the art shows you who is paying what.
- **No Game Over.** Losing advances Time Debt. Crono cracks further and Sera drags the party back along the timeline. Defeat is a cost you carry, not a reload.

The quick-reference numbers (every number in this bible is a starting value to tune for feel; the full sheet is in [Godot 4.7 Implementation Notes](#18-godot-47-implementation-notes)):

| Law | Value |
|---|---|
| Battle plane | 28 × 28 PlaneMesh, 648 tris, over the live NavMesh |
| Gauge fill | `speed × delta + sin(battle_time + offset) × 0.5 × delta` |
| Sync Hold | any gauge at 99.0 freezes all others |
| Shave | matching weakness count × hit count + bonus (Boost Lv3 +1) |
| Damage states | 1.0× · Boost Lv3 1.3× · weakness 2.0× · weakness + Lv3 2.6× |
| BREAK | cannot act · DEF −50% · every hit crits ×1.5 · nav frozen · hull +12% · rebuild after 3.0 s at 18%/s · 0.4 s resume blend |
| BP | shared pool · +1 per ally action · MAX_BP 5 (6 late) · MAX_SPEND 3 (4 late) |
| Boost power | 100 / 190 / 280 / 370 / 450% |
| Sera | Rewind −5% solidity · phase-out at 40% for 2 turns · HOLD +2.5 s Break per 5% |
| Crono | ASTRAL techs cost max-HP ceiling · crack states 100–61 / 60–21 / 20–1 / 0 |

## 2. Battle Space

### 2.1 The seamless battle plane

When an enemy's contact volume touches a party member (or an enemy reaches the party), the **BattleSandboxBootstrap** spawns a 28 × 28 PlaneMesh centred between the two groups, laid over the current NavMesh terrain and conforming to it. Nothing loads. Party members slide into their battle-ready idles where they stand; enemies keep their overworld positions; the camera lerps from the exploration angle to the 35° tactical angle. Anything visible in exploration is usable in combat: if you can see it, you can flank it.

The plane's surface is the shared base material (triplanar mossy stone, three paper textures, the gold-leaf mask) with the universe's material override on top. Its tessellation (648 tris) is what the battle decals, Elemental Canvas Clash terrain, residual fields and ink strokes draw onto.

When the battle ends, the plane dissolves in the universe's own way: watercolour wash (U0), sumi bleed (U1), amber shards (U2), papyrus flakes (U3), stained-glass caustics fading (U4), a POP! card (U5), a CRT roll (U6), gold leaf scatter (U7). Exploration resumes from the exact positions the actors ended in.

### 2.2 Who is in the fight

- **Active party:** up to four characters on the plane. The rest of the roster waits on the Bench and can be swapped in at a gate (see [Commands](#4-commands)).
- **Sera's Hover Support:** in chapters where Sera is captive, phasing, or simply not in the active four, she still acts from outside the plane through the Turn Bar (see [Sera's kit](#102-sera-17--tachyon)).
- **Enemies:** the enemy that was touched plus every enemy whose contact volume lies inside the plane when it spawns. Enemies that wander onto the plane mid-fight join at gauge 0.
- **Guests:** Marle joins as a guest in the Prologue and in some ending chapters, with her own small kit.

### 2.3 Engagement advantage

- **Pre-emptive:** the party touches an enemy from behind or while it is asleep or stunned in the field. All party gauges start at 30 + a random 0–20; enemy gauges start at 0.
- **Normal:** party gauges start at 20–50, enemy gauges at 0–40 (both random).
- **Ambush:** an enemy touches the party from behind. Enemy gauges start at 30 + random 0–20; party gauges start at 0.
- **Break-on-contact:** striking an enemy in the field with a weapon swing before contact removes one plate before the battle begins (U5 rubber enemies and U7 paper enemies are immune to this).

### 2.4 Terrain is tactical

- **Cover and height.** Walls, pillars, crates and Break-locked bodies block LINE_PIERCE shapes and line of sight; standing behind them takes a shape out of a telegraph. Ledges give +10% damage to attacks downward and −10% upward.
- **Hazard terrain.** Ink pools, mercury puddles, marrow tiles, neon light-walls, void gaps: their rules are in [Status Effects and Hazards](#12-status-effects-and-hazards).
- **Canvas Clash terrain.** Elements burn or stitch terrain into new terrain mid-fight (see [Elements](#9-elements-tags-and-the-elemental-canvas-clash)).
- **Break-locked bodies.** A Broken enemy is frozen mid-step, its collision hull inflated 12%. Allies can use it as cover, vault it, climb giant ones, and Sera can Tachyon Dash off it for +1 BP (see [Shields](#5-shields-weaknesses-and-break)).
- **Edges.** The plane's edge is the battle boundary. Characters cannot be knocked off the plane; knockback against an edge or a wall deals +10% of the knockback hit as impact damage.

### 2.5 Movement inside the battle

Enemies drift between their actions (the Chrono Trigger battlefield shuffle): each enemy's NavigationAgent moves it toward its preferred range while its gauge fills. Drift pauses whenever an ally is waiting at the gate. Party members move only as part of their action (see [Commands](#4-commands)), so the battlefield changes shape in rhythm with the Turn Bar.

### 2.6 Leaving the battle

The battle ends when every enemy is defeated, spared, or has fled; when the party withdraws; or when the party falls (see [Failure and Recovery](#16-failure-and-recovery)). There is no victory screen. Experience, loot and Time Atoms arrive as diegetic pickups that drift to the party while the plane dissolves, and the music crossfades back to the field track over two bars.

## 3. The Timeline

### 3.1 The Turn Bar

Every battler owns a horizontal action gauge from 0 to 100, drawn together on the **Turn Bar** at the top of the screen. Each marker animates in its owner's own cadence: Sera's jitters between her ghost frame rates, Crono's moves heavy and smooth at 60 fps, Cassia-09's steps at 12 fps, Krona's holds on twos. Enemies use their universe's cadence. The Turn Bar is also where Sera's Hover Support and Glenn's threads (in U5, the Turn Bar is drawn as threads from Cyrus's fingers) appear.

### 3.2 The fill law

```
gauge += speed × delta + sin(battle_time + offset) × DRIFT_AMPLITUDE × delta
DRIFT_AMPLITUDE = 0.5
```

- `speed` is the battler's Spd stat converted to gauge units per second: `speed = Spd × 0.25`. Party Spd starts at 100 at Lv 1 and reaches 165 at Lv 99 (see [Progression](#15-progression)); a battler with Spd 100 fills at 25 per second and acts about every 4 s of battle time; at Spd 165 about every 2.4 s.
- `offset` is set per battler at battle start (random 0 to 2π) so no two battlers breathe in phase.
- The sine drift gives each battler a slight temporal rhythm on top of its speed. At the starting amplitude it is a breath, not a dice roll; turn order never flips on drift alone between battlers more than 3% apart in speed. Raise `DRIFT_AMPLITUDE` if the bar feels mechanical.
- Gauge multipliers (Haste, Slow, Mercury SLOW 0.5×, Chrono Lag 0.75×, Heavy Drift 0.85×) multiply the whole expression.

### 3.3 Battle time

Every timer in combat runs on **battle time**, not wall-clock time: status ticks, hazard drains, Break delay and rebuild, wind-ups, residual fields, Divinity regeneration, Oil-Blight, Grief, Crush timers, "within 20 s" requirements. Battle time advances only while gauges are filling. It stops:

- during Sync Hold (any decision window),
- while an action is executing (from the first frame of its animation to the last),
- during Possibility Branch freezes and scripted story beats inside a fight,
- while the game is paused.

This is what makes a 12-second hazard mean the same thing to a player who decides in one second and a player who decides in one minute.

### 3.4 The gate and Sync Hold

The gate is at **99.0**. When any party gauge reaches it:

1. Every other gauge on the field freezes, enemies' included. Battle time stops. This is **Sync Hold**: an unlimited decision window.
2. The party gains +1 BP (see [Boost Points](#7-boost-points-beckons-and-the-prometheus-core)).
3. The acting ally chooses a command. Most actions end the turn and reset the gauge to 0.
4. If several allies reach the gate on the same frame, they are resolved in order of overflow (highest raw gauge first), each with its own decision window.

Sync Hold is also a **command**: the ally can choose to wait at the gate instead of acting. Its gauge stays parked at 99.0, it enters the **Ready Pool**, battle time resumes, and the next time another ally reaches the gate, the decision window opens with the whole Ready Pool available for a Dual or Triple Tech. A parked ally can leave the pool and act alone at any later decision window. Enemies keep acting while allies wait, so holding is a gamble.

The style hook: holding at 99 lets a 24 fps sumi-e slash cross a 60 fps watercolour dash on purpose. The Dual and Triple Techs are built on that collision.

### 3.5 Enemy turns

Enemies reach their gate at 100.0 and act without freezing anything. Their actions are one of two kinds:

- **Instant:** resolves at the gate (most attacks of regular enemies).
- **Telegraphed:** a wind-up that runs in battle time. The target area is drawn on the plane as a decal that pulses from cyan (read) to orange (commit) by `sin(TIME × 6)`, with a scan wave scrolling inward to show the collapse. Wind-ups range from 0.8 s (fast elites) to 4.0 s (boss ultimates). Allies who reach their gate during a wind-up can step out of the decal, Guard, or Break the caster; a Break cancels the wind-up.

Enemy drift (the shuffle between actions) pauses while any ally is parked in the Ready Pool, as the reward for holding.

### 3.6 Manipulating the timeline

| Effect | Rule |
|---|---|
| Break | The target's gauge drops to 0 and is frozen for the whole Break. |
| Sera's Rewind | Restores one target (ally or enemy) to its state at its own last turn start: HP, gauge and position. |
| Sera's Turn-Bar daggers (Hover Support) | Rewind an ally's HP to its last turn start, or fast-forward an ally's gauge +25 instantly. |
| Borrowed Future | Pushes every ally gauge back 30% (watercolour bleeds backward along the bar), then gives the ally nearest a full gauge a Token Duplicate: an immediate second turn. |
| Guard | The guarding ally's next gauge starts at 20 instead of 0. |
| Swap | The incoming ally arrives with gauge 50. |
| Thread cut (U5) | A slash that cuts an enemy thread delays its next action ×1.5. |
| Tracking Hold (enemy) | Time Stop on one battler for 3 s: its gauge does not fill. |
| Mercury SLOW / Chrono Lag | 0.5× / 0.75× fill. |

### 3.7 Settings

- **Flow speed:** 0.75× / 1.0× / 1.25× multiplier on battle time while gauges fill. It changes nothing but pace; Sync Hold still gives unlimited time.
- **Reduced flicker:** tones down Chronoslip flicker, VHS, CRT and screen-splits without changing any rule.

## 4. Commands

### 4.1 The decision window

When an ally reaches the gate, the decision window opens. The ally can **move** and then take **one action**. Moving is optional and happens first; the TacticalPositioner previews every shape from wherever the ally would end up.

**Move.** Each ally has a move range per action (default 6 m; Crono 6, Sera 8 with her phase-step, Krona 6, Cassia-09 5 but she ignores height, Xyloph 6 and 10 while gliding in U3, Vesper 5, Glenn 7 and 300% stretch reach, Static 6, Omega-Spekkio 6 floating). Moving through an enemy's threat ring (1.5 m around it) is allowed but ends the move. The auto-snap places the ally where the chosen shape lands the most hits; the left shoulder button nudges the position by hand.

### 4.2 Universal actions

| Command | What it does |
|---|---|
| Attack | The character's weapon strike. 1–3 hits (per character), carries the weapon tags, uses P.Atk. Always free. Shaves when a weapon tag matches. Can be Boosted like a Tech (power and shape scale only). |
| Tech | A technique from the character's kit (see [Character Kits](#10-character-kits) and [Tech Library](#11-tech-library)). Costs MP (Crono pays max-HP ceiling instead; Sera pays solidity on some techs). Choose Boost level 0–3 (0–4 late) before confirming. |
| Dual / Triple | Available when the needed partners are in the Ready Pool or at the gate together. All participants' gauges reset; the costs of each participant are paid. |
| Item | Use a consumable. Items never take Boost. |
| Guard | Until this ally's next turn: −50% damage taken; Ens Parry available against the next hit (6-frame window shown as a closing sumi-e circle). The next gauge starts at 20. |
| Sync Hold | Park at 99.0 in the Ready Pool (see [3.4](#34-the-gate-and-sync-hold)). |
| Swap | Trade this ally for one on the Bench. The newcomer arrives at the same spot with gauge 50. The first Swap in each battle also gives +1 BP: swapping is rewarded. A KO'd ally can be swapped out by any ally standing within 3 m of them. |
| Spare | Offered against a Broken enemy at 25% HP or less. The enemy is removed from the fight alive (it sleeps, flees, or is sung to rest, by universe). Feeds its Light lean. |
| Withdraw | Only from within 2 m of the plane's edge, and never in boss fights. Succeeds if no enemy gauge is above 80; otherwise the attempt costs the turn. |

**Ens Parry.** Any Guarding ally can parry: press the parry input inside a 6-frame window as the enemy hit lands. A **perfect** parry negates the hit and leaves an **Ens ring** on the ally: their next damaging hit gains +1 shave, and if the ally is Crono, his Time Debt costs are nulled for 5 s. The window is generous against U1 enemies with 24 fps holds (8 frames against the Goyama Daimyo's Phase 1) because their poses read clearly. Pressing the input outside the window against U1 ink enemies throws an ink blot: BLIND for 3 s. Krona teaches Ens Parry in U1; before that the parry window is 4 frames.

### 4.3 Character commands

Each character also owns one or two commands that bend the rules: Crono's Astral Smear Dash (move and strike in one) and Father Tank; Sera's Rewind, HOLD and Borrowed Future; Krona's gourd and Shogun's Command; Cassia-09's Mercury Pulse scan and Loom Pull; Xyloph's Tether; Vesper's Prism Guard and Polish; Pierrot-Glenn's Steal; Static's Tune; Omega-Spekkio's NULL. Their rules and numbers are in [Character Kits](#10-character-kits).

### 4.4 Free actions

These cost no turn: Static's Tune; Xyloph's first node placement each turn; choosing the Boost level; the move; looking at the codex entry of a target (opens the plate's full math); and the Worship Gaze (U3 and some endings: a party member idles 3 s looking up).

### 4.5 Targeting

- SINGLE techs target one battler (the shape's scale only grows its impact sphere for spatial checks).
- LINE_PIERCE, CIRCLE, SELF_AURA and CONE are placed shapes; the preview shows every battler inside and the exact shave and damage each will take (the Shield Plate preview, below).
- Allies are never hit by party damage. NULL and a few self-sacrifice techs are the exceptions and say so.

### 4.6 The Shield Plate preview

While aiming, each target's plate shows the math of the hit you are about to throw:

```
[SHIELD 6 -> 2 (-4) -> BREAK?]   [SWD][?]
```

Current shield, shield after this action, the shave, and whether it Breaks. If the hit would Break, the plate reads `-> BREAK!` in gold. Unknown weaknesses stay `[?]` and the preview counts only what is known; a hit that turns out to match a hidden weakness reveals it and shaves anyway.

## 5. Shields, Weaknesses and BREAK

### 5.1 The ShieldComponent

Every enemy carries a ShieldComponent and shows it through an EnemyShieldPlate floating above its head. The component holds:

- `max_shield` and `current_shield` (plates, small integers: 1–8 for regular enemies, 8–20 for elites and mini-bosses, 12–45 per phase for bosses),
- `weaknesses` (tags) and `revealed` (which of them the player has seen),
- `resists`, `nullifies_shave`, `immune`, `absorbs`,
- `broken` state with its timers (lock, rebuild, resume),
- optional rules: keyed plates, regeneration, refill-once, shared plates, belief plates, stacked plates, temporary plates.

Shield is separate from HP. Damage reduces HP whether or not it shaves; shaving reduces the shield whether or not the hit did much damage. Breaking an enemy is how you make damage count.

### 5.2 Reading the plate

```
[SHIELD 6 -> 2 (-4) -> BREAK?]
[SWD][?]
```

- **First line:** current shield, shield after the previewed action, the shave, and `-> BREAK!` in gold if the action would Break it. With nothing aimed, the plate reads `[SHIELD 6]`.
- **Second line:** weaknesses as short tags (`[SWD]` sword, `[FIR]` fire, `[AST]` astral, `[TAC]` tachyon, `[FER]` ferro, `[RUI]` ruin, `[MYC]` mycelia, `[VIT]` vitreous, `[GUI]` guile, `[HZ]`, `[NUL]` and so on). Unknown weaknesses show `[?]`.
- **Gold** when Broken; a thin gold Rebuild bar fills underneath during recovery.
- The plate pulses cyan → orange in sync with the enemy's telegraph when it is winding up.
- U-specific plate dressings: ink brush border (U1), clay with thumbprint (U2), papyrus (U3), leaded glass (U4), circus ticket (U5), CRT bezel (U6), washi with gold edge (U7). The arithmetic never changes.

**Revealing weaknesses.** A weakness is revealed when: a hit carrying it lands; Cassia-09's Mercury Pulse scans the target (reveals all); Vesper's lens or Read Light passes over it (reveals one); Static tunes CARRION on it (reveals one and its "elemental memory"); the codex already holds it from a previous fight. BLIND on the party (or Static's static scramble on the enemy) hides the second weakness again as `[?]`.

### 5.3 The shave law

```
shave = matching_weakness_count × hit_count + bonus
```

- **matching_weakness_count** is the number of distinct tags carried by the action that appear in the target's weakness list. An ASTRAL technique carries [ASTRAL][SWORD][TIME_DEBT]; against an enemy weak to [SWORD][TIME_DEBT], it matches 2.
- **hit_count** is the number of the action's hits that actually land on that target (the TacticalPositioner shows it). Multi-hit techniques are the shield breakers.
- **bonus** is flat, added once per action per target: +1 at Boost Lv3 or higher; +1 from an Ens ring; +2 for Vesper's Lily Lancets in the correct colour; +2 for a Spore Rail tether cut; +4 for Chrono Prism and Dual Honest Stage; and any other bonus a technique lists. Bonuses only apply if at least one tag matched.
- Non-matching hits shave nothing. Resisted tags still let other tags match.
- A tag the target *nullifies* never counts toward the match.
- The shield cannot go below 0. Excess shave is lost.

The shave and the damage are independent: the action's damage uses the damage pipeline (see [Damage Pipeline](#6-damage-pipeline)), the shave uses this law.

**Examples.**

- Crono's Astral Slash (1 heavy hit) into a Slag-Mite (weak [ASTRAL][FERRO]): match 1 × 1 hit = 1. At Boost Lv3: 1 + 1 = 2. The Slag-Mite has 2 plates: Break.
- Static's hz_static (8 rapid hits) on a Hiss Larva Drone (weak [HZ][NULL]): match 1 × 8 = 8. Its 3 plates are gone after the third tick.
- Solar Railgun (Crono + Cassia-09, [ASTRAL][FERRO][BEAM], 3 hits) on R-66Y in Phase 1 (weak [FERRO][RUIN][ASTRAL]): match 2 × 3 = 6, +1 at Lv3 = 7 of his 12.

### 5.4 BREAK

When the shield reaches 0, the target **Breaks** immediately, on the hit that did it, before the rest of a multi-hit action resolves (the remaining hits already land on a Broken target).

While Broken:

- It **cannot act**. Its gauge drops to 0 and does not fill. Any wind-up in progress is cancelled.
- **DEF −50%.**
- **Every incoming hit is a critical hit** (×1.5; see [Damage Pipeline](#6-damage-pipeline)). There is no separate Break multiplier.
- **NavigationAgent frozen:** velocity zeroed, avoidance off, root motion paused. It is locked mid-step, mid-leg-lift, mid-dive, mid-glide.
- **Collision hull inflates 12%** and the body becomes Break-locked geometry (5.5).
- Presentation: gold shatter, full-screen chromatic aberration at 0.02, the enemy flickering between its native frame rate and a shared 60 fps gold porcelain render (Vaelos's dream of one perfect timeline), sub-bass crack and crystalline spill; U-specific additions (U2 hydraulic hiss, gramophone pop and VHS wobble; U6 a CRT barrel warp to 1.05 for 0.45 s).

**Timing.**

1. **Lock:** 3.0 s of battle time with the shield empty.
2. **Rebuild:** a thin gold bar fills at 18% of the shield per second (5.6 s from empty to full). The enemy is still Broken during the rebuild.
3. **Resume:** when the bar is full, the shield is restored to max, the Break ends, and the enemy blends out of its frozen pose over 0.4 s before it can move or act. Its gauge starts from 0.

A full Break therefore lasts about 8.6 s of battle time: long enough for every ally on a typical speed to act about twice. Many enemies have Break effects that last "for the full Break" (Crown Saurian falls, Azar freezes mid-glide, Kami-Ori's wings lock as a bridge); they mean these 8.6 s plus any extension.

**Extensions.**

| Source | Extension |
|---|---|
| Sera's HOLD | +2.5 s of lock per 5% solidity spent (5% steps; spent while the target is Broken) |
| Spore Tag on the target (U3) | +1.2 s |
| Triangulation (Crono + Xyloph) critical | +1.2 s |
| Mycelia Time Lapse (Xyloph + Sera) | +1.5 s |
| "POP!" card wall (U5) | the card stands 3 s as a wall; the lock does not count down while the target is behind it |
| hz_white_noise at Boost Lv3 | delays the next shield rebuild by +3 s |
| Graviton Whiteout (Cassia-09 + Static) | disables shield regeneration for 5 s |

**Killed while Broken.** A target whose HP reaches 0 while Broken remains on the field as a gold porcelain statue for 8 s before it shatters. The statue keeps the inflated hull and is still terrain.

**Crono feels it.** Every Break the party lands on a boss nudges Crono's crack overlay (cosmetic); a Break that the player paid for with Boost Lv3 plays the style bleed (watercolour afterimages, gold leaf flecks).

### 5.5 Break-locked geometry

A Broken body is terrain for the duration of the Break:

- **Cover.** It blocks LINE_PIERCE shapes and enemy projectiles that pass through it.
- **Vaulting.** Allies can move over it as if it were a 1 m ledge.
- **Platforming.** Giant bodies (the Arch-Curators, the Leviathan, Kami-Ori's crane, the Matriarch chrysalis) expose climbable surfaces: an ally standing on a Broken giant gains +10% damage from height against everything else.
- **Tachyon Dash.** Sera can dash off a Broken body as part of her move: +1 BP.
- **Lining up.** Because Broken enemies do not drift, the TacticalPositioner can line LINE_PIERCE and CROSS shapes through them. "Break-lock it to line it up" is the answer to the fast-drifting enemies (Bike Bros, Heckler Harlequin, Cyrus's heart thread).
- **Knockback.** A knockback hit into a Broken body counts as hitting a wall (+10% impact damage).

### 5.6 Keyed plates

Some shields are shown as individual plates, each with its own material and key:

```
[SHIELD NULL->ASTRAL (-2) -> BREAK!]
```

- **Material** (left of the arrow) is what the plate is made of. **Key** (right) is the tag that removes it. **Weight** (in brackets) is how much shave the plate needs.
- Only hits carrying the key tag shave a keyed plate; the shave law applies with the key as the only matching tag. Other weaknesses still give their damage multiplier, they just don't shave.
- Keyed plates fall **in order**, left to right, unless the fight says otherwise.
- When a source lists only materials (the Prologue's `[SWORD]x2 [LIGHT]x2`), each plate is keyed to its own material: the house is teaching you its language.
- When a source lists materials and a weakness list but no keys (the Ashen Spoon), plates key to the weaknesses in the order given.

### 5.7 Special shield rules

| Rule | How it works | Examples |
|---|---|---|
| Regenerating | After 3.0 s without being shaved, the unbroken shield refills at 18%/s. | Mycelia Matriarch Phase 2, Kirie Keeper, Kami-Ori Phase 2, Empress Vaelos |
| Refills once | The first time the phase's shield Breaks, it refills to full after the Break instead of the phase ending. | Azar Phase 2 |
| Healed by another body | Another enemy restores plates on a timer while attached or alive. | Marrow-Umbilicals (2 per 8 s), Eden Wisp, Synod Acolyte, Cyrus's Strings, Isolator umbilicals |
| Shared | One plate count across several bodies; any body's shave reduces it. | Laugh-Track Choir, Kirie Keeper's monks |
| Belief plates | The plate shows a huge number; only the real plates inside it count. Wrong tags chip the fake number for noise and no progress. | The 999 Shard Doll, R-66Y Residual Sorrow (9999) |
| Stacked plates | Several full shields in sequence, each its own Break. | Vaelos Final Kintsugi (45 × 3), the Chrono Ledger, Kami-Ori Seventh Arm (35 × 2) |
| Temporary plates | Granted by fields (Divinity: +1 per 5 s, capped at 20% of max HP as temporary shield). They are shaved first and never Break the enemy on their own. | U3 enemies, Azar |
| Shield-only | The enemy takes no HP damage until Broken. | Moon Egg |
| Break-immune until | The shield can be shaved to 0 but the Break does not trigger until a condition is met. | Porcelain Choir (a FERRO ally in party), Prop Chest Mimic (springs cut) |
| Thin belief (`-1`) | A plate of weight 1 that any keyed hit removes. | Crono's Reflection's doll plate |
| Untargetable plate | The shield cannot be targeted until a mechanic exposes it. | Cyrus Phase 1, the Strings |

### 5.8 Break Signature, Spare and Salvage

- **Break Signature.** The tags on the hit that Broke a boss are recorded. Possibility branches can read them (the Atrium Cradle's Light and Dark leans are decided this way).
- **Spare.** A Broken enemy at 25% HP or less can be spared (see [Commands](#4-commands)). Spared enemies grant half experience and their Light-lean point.
- **Salvage.** Killing a Broken enemy with a [RUIN] or [FERRO] finisher salvages it: +1 crafting part and its Dark-lean point. Bosses and story enemies define their own salvage.

## 6. Damage Pipeline

### 6.1 Stats

| Stat | Role |
|---|---|
| HP | Damage capacity. Crono's maximum is a ceiling that Time Debt and Strain lower (see [Crono's kit](#101-crono-41--astral)). |
| MP | Pays for Techs. Crono's techs cost max-HP ceiling instead; some of Sera's cost solidity. |
| P.Atk / P.Def | Physical attack and defence: weapon tags ([SWORD], [BLUNT], [GUN], [PIERCING], [BOW], [RUBBER]). |
| E.Atk / E.Def | Elemental attack and defence: element tags and world tags ([FIRE], [ICE], [VOLT], [WIND], [LIGHT]...). |
| Spd | Gauge speed: `speed = Spd × 0.25` gauge per second. |
| LUK | Evasion against non-telegraphed attacks (LUK × 0.05%) and status resistance. There is no random critical chance in this game (see crit, below). |

A technique that carries both weapon and element tags uses whichever attack/defence pair is better for the attacker. ASTRAL is neither physical nor elemental: it uses the average of P.Atk and E.Atk against the average of P.Def and E.Def.

### 6.2 The formula

```
raw     = 0.8 × (ATK − DEF × 0.5)                    (minimum 1)
damage  = raw × base × synergy × boost × state × crit × perfect_frame × falloff × resist × variance
```

| Term | Value |
|---|---|
| ATK, DEF | The attacker's relevant attack stat and the target's relevant defence. A Broken target's DEF is halved before this step. |
| base | The technique's base multiplier per hit (Attack is 1.0 per hit). |
| synergy | 1.0 for solo actions; Dual 1.6; Triple 2.2. Pair and spread modifiers multiply it: the Chronoslip pair Crono + Krona ×1.15 (two Cronos, mirrored); Crono + Sera ×0.95 (same home, echo interference); a Triple whose three actors come from three different home universes ×1.25; any action that includes Vaelos (child) ×0.85, and it heals 5% of Crono's Battle Strain. Then × party synergy (below). |
| boost | Boost power: 1.00 / 1.90 / 2.80 / 3.70 / 4.50 at Lv 0–4. Boost is deliberately undertuned (×0.90 on the power) for an actor standing in a Divinity Field or tethered by Xyloph, so field buffs and Boost do not stack into nonsense. |
| state | 1.0 normal; 1.3 at Boost Lv3+ while the hit is shaving a non-weak target; 2.0 weakness hit; 2.6 weakness hit at Boost Lv3+. |
| crit | 1.5 on a critical hit. There is no random crit roll: every hit on a Broken target is critical, and techniques and passives that say so (Triangulation's guaranteed crit, Krona's Oil-Drinker+ 25% chance against mechanical and Lavos enemies, a Token Duplicate copying a crit) are the only other sources. |
| perfect frame | 1.15 when the player presses the action button on the acting character's key pose: every 4th frame for U0's 60 fps, the 6-frame ink pause for U1, the 12-frame hold for U2, the 10-frame snap for U3, the 12 fps light key for U4, the smear hold on twos for U5, the impact on ones for U6, the end of a 2 s hold for U7. A gold sheen marks it. It rewards watching each canvas. |
| falloff | Area techniques lose damage per extra target, nearest first: 1.0, 0.75, 0.5, then 0.25 for the fourth and beyond. At Boost Lv3 and higher the falloff starts one target later. Falloff never reduces the shave. |
| resist | 0.5 if the target resists a tag the hit carries; 0 if immune; absorb heals the target for the result. |
| variance | 0.95–1.05. |

**Party synergy** multiplies all party damage: 1.10 while Sera is with the party (active or as Hover Support), 0.85 while she is phased out by Causal Collapse, 1.00 in stretches where she is absent from the story.

**Home Canvas.** A character fighting in their home universe deals +10% damage (Crono in U0, Krona in U1, Cassia-09 in U2, Xyloph in U3, Vesper in U4, Pierrot-Glenn in U5, Static in U6, Omega-Spekkio in U7). Sera's home is every universe and none: she has no Home Canvas bonus; instead, any hit she lands while three or more of her ghost styles are visible gets +20% (her flicker threshold).

### 6.3 Special damage

- **ASTRAL displacement.** Every ASTRAL hit also deals +1% of the target's *current* HP as unresisted damage (0.25% against bosses) and pushes its gauge back 5. ASTRAL is strong against temporal enemies (Vaelos, Lavos spawn, R-66Y's ring: +25%) and weak against living-memory enemies (U7 Washi-Hollow, Marrow Lantern, Kami-Ori: −25%).
- **TACHYON probability.** TACHYON hits deal low damage by design; each one has a 25% chance to push the target's gauge back 10, and Sera's TACHYON hits ignore evasion.
- **HZ jamming.** HZ hits deal low damage; each has a 15% chance to cancel a wind-up in progress (rolled per hit, so the 8-hit hz_static usually cancels one).
- **NULL.** NULL hits deal true damage (ignore DEF and resistances) but never trigger a weakness multiplier unless the weakness was created by NULL.
- **DoT and fields.** Damage-over-time ticks use the caster's stats at cast time, at 15% of one hit's raw damage per tick, never crit, and never shave.
- **Healing.** `heal = E.Atk × base × boost × 0.9`. Healing techniques are boosted like attacks. Corroded targets receive half.
- **Self-costs.** HP costs are never reduced by DEF and never kill: they stop at 1 HP.

### 6.4 Order of operations

```
for each hit that lands on target:
    def_used   = target.def × (0.5 if target.broken else 1.0)
    raw        = max(1, 0.8 × (atk − def_used × 0.5))
    mult       = base × synergy × party_synergy × home_canvas × boost
    mult      *= state(weakness_match, boost_level)
    if crit or target.broken: mult *= 1.5
    if perfect_frame_input: mult *= 1.15
    mult      *= falloff(target_rank_in_area, boost_level)
    mult      *= resist(target, hit.tags)
    dmg        = raw × mult × rand(0.95, 1.05)
    if hit.has(ASTRAL): dmg += target.hp × (0.0025 if boss else 0.01); target.gauge -= 5
    apply dmg
    if target.shield > 0 and not target.broken:
        shave_this_action += matching_count       (bonus added once, after the last hit)
        if shield − shave ≤ 0: BREAK now (later hits see a Broken target)
```

### 6.5 Worked examples

The numbers below use the starting stat curves in [Progression](#15-progression).

**1. A plain hit (Lv 12, U2).** Crono (P.Atk 84, E.Atk 78) uses Attack on a Slag-Mite (P.Def 50) that resists nothing. Raw = 0.8 × (84 − 25) = 47.2. Base 1.0, solo, party synergy 1.10 (Sera hovering), boost 1.0, state 1.0 (not a weakness: Attack carries [SWORD], the Slag-Mite is weak to [ASTRAL][FERRO]). ≈ 52 damage, no shave.

**2. Weakness at Boost Lv3 (Lv 12).** Same fight, Astral Slash at Boost Lv3. ASTRAL uses the averages: ATK (84 + 78) / 2 = 81, DEF (50 + 46) / 2 = 48. Raw = 0.8 × (81 − 24) = 45.6. Base 1.4, party 1.10, boost 3.70, state 2.6 (weak to [ASTRAL] at Lv3). 45.6 × 1.4 × 1.10 × 3.70 × 2.6 ≈ 676, plus displacement 1% of current HP. Shave: 1 match × 1 hit + 1 = 2: Break. Crono pays 2% of his max HP as Battle Strain.

**3. Into a Broken boss with a Dual (Lv 20, R-66Y Phase 1).** R-66Y is Broken. Solar Railgun (Crono + Cassia-09) at Boost Lv2: 3 rail hits + 1 burn. Crono's ASTRAL ATK average 129; Cassia-09's E.Atk 120; the Dual uses the higher of the two actors' relevant stats (129). R-66Y DEF average 110, halved by Break to 55: raw = 0.8 × (129 − 27.5) = 81.2. Per rail hit: base 1.2 × synergy 1.6 × party 1.10 × boost 2.80 × state 2.0 (weak [ASTRAL][FERRO]) × crit 1.5 ≈ 1,441 → about 4,320 for the three rails, plus the burn tick (15% of raw, ≈ 12). R-66Y has 45,000 HP: a well-timed Break and two Duals take a large bite out of him.

**4. The Vaelos Phase 3 window (Lv 80).** Sera has voluntarily phased out (party synergy 0.85), so Crono's and Vaelos's shields have dropped to 4. Crono's Astral Smear Dash (LINE_PIERCE, 2 hits at base 0.9) at Boost Lv4 against weak [ASTRAL]: match 1 × 2 hits + 1 = 3 shave of 4. The second Smear Dash from the Token Duplicate costs nothing and copies the first one's crit roll: Break.

## 7. Boost Points, Beckons and the Prometheus Core

### 7.1 The shared pool

Boost Points (BP) are one pool shared by the whole party.

| Rule | Value |
|---|---|
| Starting BP each battle | 1 |
| Gain | +1 BP each time an ally reaches the gate (one per ally action, round-robin across whoever acts) |
| Cap | MAX_BP 5; 6 once the Crono Memory Shards are restored |
| Spend per action | MAX_SPEND 3; 4 once the first Vaelos rift is closed |
| Other gains | +1 for the first Swap of each battle; +1 when Sera Tachyon Dashes off a Broken body; Ticket-Golem's BP rain; Glenn's steals; +1 per rain-soaked kill in U6 with `U6_Matriarch_Fed` |
| Drains | Oil-Blight (−1 per 15 s); enemy thefts (Slag-Rat Courier, Heckler Harlequin, Ash-Knight, Strongman's Punchline); forced auto-spends (Ticket-Golem's Laugh Track); the blackened Charred Laurel (−1 per 15 s for all of U6); cutting a kin thread in the Cyrus Encore (all BP) |

BP never exceeds the current cap and an action never spends more than the current spend cap. Unspent BP carries across turns within a battle but not between battles.

### 7.2 Boost levels

| Spend | Level | Power | Shape scale | Added law |
|---|---|---|---|---|
| 0 BP | Lv0 | 100% | 1.00 | — |
| 1 BP | Lv1 | 190% | 1.25 | power increase |
| 2 BP | Lv2 | 280% | 1.50 | adds the technique's debuff (or its element's default debuff) |
| 3 BP | Lv3 | 370% | 1.75 | +25% AoE and +1 flat shave; damage while shaving 1.3×; weakness 2.6× (the key breakpoint) |
| 4 BP (late) | Lv4 | 450% | 2.00 | adds a residual field |

Each level adds +0.25 to the shape scale; the scale applies to the shape's radius, length, width and inner/outer rings (see [Tech Geometry](#8-tech-geometry-and-positioning)). Boosting a single-target Attack scales its power and its impact sphere only.

Boost presentation: Lv3 and above trigger the **style bleed** on the acting character: watercolour 60 fps afterimages for Crono, clay thumbprint normals popping for Cassia-09, gold leaf flecks falling for Omega-Spekkio, ink splitting for Krona. The Boost sound is Gaspar's coin, pitched up a step per level.

### 7.3 Default Lv2 debuffs

When a technique does not list its own Lv2 debuff, it applies its element's default for 2 of the target's turns:

| Element | Lv2 default debuff |
|---|---|
| ASTRAL | **Displaced:** gauge fill 0.85× |
| TACHYON | **Probability Lock:** the target's next action rolls twice and takes the worse result |
| RUIN | **Corroded:** −50% healing received and −10% DEF |
| FERRO | **Magnetized:** its next action hitches (starts 0.5 s late); metal-tagged targets also lose 10% P.Def |
| MYCELIA | **Spore Tag:** Break +1.2 s; Xyloph's Burst consumes it |
| VITREOUS | **Refracted:** 20% of damage it deals is split away as a harmless prism |
| GUILE | **GUILTY:** 50% chance its next attack hits an ally of its own |
| HZ | **Jammed:** cannot start a wind-up for 2 s |
| NULL | **Stripped:** loses one resistance |

### 7.4 Lv4 residual fields

At Lv4 a technique leaves a residual field where it landed (CIRCLE: the circle; LINE: the line; SINGLE: a 2 m circle under the target) for 6 s of battle time:

| Element | Field | Effect inside |
|---|---|---|
| ASTRAL | Watercolour puddle | ASTRAL hits on enemies inside +1 shave; Crono's first cast from inside costs no Battle Strain |
| TACHYON | Ghost ring | Ally gauges inside fill 1.15× |
| RUIN | Ink stain / Ash Field | Enemies 0.5× movement; −1 temporary plate per 2 s |
| FERRO | Amber pool | Enemies Mercury SLOW; Cassia-09 recharges Mercury Pulse standing in it |
| MYCELIA | Spore mat | Allies regenerate 2% HP per 2 s; tethers inside never snap |
| VITREOUS | Caustic floor | Hits passing over it gain [VITREOUS] |
| GUILE | Confetti pit | Enemies inside drop 1 BP when hit (once per enemy) |
| HZ | Static field | Enemies inside cannot be untargetable |
| NULL | White blank | All tags inside are erased: neutral damage only, no shave, no buffs |

### 7.5 Glenn and theft

Pierrot-Glenn steals BP, and BP theft is capped so it can never loop:

- His steals take from an enemy's stolen-BP counter first (enemies that steal BP from the party hold it visibly over their plate). If the counter is empty, he takes 1 BP from the enemy's "laugh" instead.
- One steal per Glenn action: 1 BP at Lv0–1, 2 BP at Lv2, 3 BP at Lv3+. Accordion Dodge's free steal is limited to once per enemy turn.
- When Glenn's techniques steal from a GUILTY ally, the BP goes to the pool, never duplicated.

### 7.6 Raising the caps

- **MAX_BP 6:** Crono's Memory Shards are pieces of the original Crono's atoms scattered across U2–U6 (one per universe, five in all, found in atom hunts). Restoring all five raises the cap.
- **MAX_SPEND 4:** closing a Vaelos rift: the first Amber Rift the party resolves on purpose after U4 (the Prismatic route reaches it earlier; every route reaches it by U6 through the Vapor Memory Core rift).

### 7.7 Beckons

**Beckons** are the progression currency earned through the Possibility Engine: every time a story choice writes an affinity, the party gains Beckons equal to the affinity points written (a +30 Light mercy earns 30 Beckons, a +25 Dark act 25, a +15 Prismatic rift 15). Beckons are never earned in battle and never convert to BP. They are spent at the Atrium Horologe:

| Purchase | Beckons |
|---|---|
| Prometheus Core (Arris_Dome Sleeping route) | 150 |
| Robo Ribbon fitting | 25 |
| Kintsugi Gold Bundle (repairs 1% glaze per 8 s for 2 minutes at a lotus pond) | 20 |

### 7.8 The Prometheus Core

The Prometheus Core is Robo's gift, installed in the Atrium Horologe's heart and worn into battle by the whole party.

- **Effect:** once per battle, the first party member reduced to 0 HP is revived at 20% HP (Crono revives in his galaxy state). The revive costs 1 BP when it fires; if the pool is empty it still fires and takes the next BP the party gains.
- **Blocked** if the fallen ally has Ruin at 2 stacks or more (−30% ceiling): the Core cannot find enough of them to restart.
- **Acquisition:** `Arris_Dome_Sleeping` → the Core is behind the Doan garden gate (plant the Seed of Doan to grow the gate) and costs 150 Beckons. `Arris_Dome_Incinerated` → the Core lies in the ash, free, +25 Dark, and the traders and the Robo Ribbon quest are gone.
- **Robo Ribbon:** requires the Core and `R-66Y_Rewound`. Lucca's ribbon is found in Cassia-09's mercury orb shoulder joint; fitting it to the Core (25 Beckons) makes R-66Y immune to Dark flag changes for one cycle and repairs +5 of Crono's integrity once.
- **Prometheus Overload** is a different thing: Cassia-09's relic ultimate burns the amber tank (see [Tech Library](#11-tech-library)). Using it without Lucca's consent marks the Core "burned selfishly", which makes Sera's Atropos Ribbon fail in the True Ending route.

## 8. Tech Geometry and Positioning

### 8.1 Shapes

| Shape | Parameters | Hits whom |
|---|---|---|
| SINGLE | impact sphere radius 1.0 m (× shape scale) | one target; the sphere matters for Break-locked geometry, props and knockback |
| LINE_PIERCE | length L, width W (default 1.2 m) | every battler along the line from the caster, through enemies, stopping at walls, cover and Break-locked bodies unless the tech says it pierces geometry |
| CIRCLE | radius R, placed within the caster's reach | every battler inside |
| SELF_AURA | outer radius R, inner radius 1.0 m (a ring on the caster) | every battler between the rings; the caster's own spot is safe |
| CONE | length L, half-angle from radius R (angle = 2 × atan(R / L)) | every battler inside the wedge from the caster |
| CROSS | two lines of length L crossing at a placed point, radius R for the crossing burst | both lines; the crossing point gets the tech's special effect (Eclipse X-Strike erases a buff and a plate there) |
| DELTA | the triangle whose corners are the three casters (Triples only) | everything inside the triangle; each edge also hits as a LINE |
| CAGE | a CIRCLE that holds: battlers inside cannot leave until it ends (Iron Maiden Scroll) | everything inside |
| SPLIT CONE | a CONE divided into N beams, each its own line (vitreous_refraction) | each beam hits what it crosses; a target crossed by several beams takes several hits |
| FATE LINE | an infinite LINE that ignores geometry (Atropos Ribbon) | everything on the line, in every layer |

### 8.2 Scale

Every shape parameter is multiplied by the Boost shape scale (1.00 / 1.25 / 1.50 / 1.75 / 2.00). SINGLE's scale formula `1.0 + boost × 0.25` is the same table. Some techniques add their own AoE scale on top (listed as AoE scale in the [Tech Library](#11-tech-library)); the two multiply.

### 8.3 Counting hits

- A technique has a hit count per target. The TacticalPositioner sweeps the shape with ShapeCast3D against the real NavMesh and counts **every** battler inside, not only the first one (a ShapeCast stops at its first collision unless you iterate; see [Pitfalls](#185-pitfalls)).
- Multi-hit sweeps (Lily Lancets, hz_static, Spore Rail's spores) roll each hit separately for crit, ASTRAL displacement, HZ cancel and TACHYON gauge push.
- Targets that move during a technique's animation (they do not: battle time is stopped during execution) keep their pre-cast positions.

### 8.4 The TacticalPositioner

- On choosing a shape, the positioner **snaps** the caster (within its move range) and the shape to the configuration that lands the most hits, weighted toward weakness hits and toward targets close to Breaking.
- The left shoulder button moves the shape (or the caster) by hand in 0.25 m steps; the preview updates live: each target's plate shows its shave and the damage number floats above it.
- Allies who will be in an enemy telegraph after the move are outlined orange.
- After a Break, the positioner auto-paths allies who have not yet acted toward their best flank on the frozen target.

### 8.5 Telegraphs

Every area attack, ally or enemy, is drawn on the battle plane as a decal:

- **Cyan** while it can still be read and avoided; **orange** when it commits.
- Pulse brightness follows `sin(TIME × 6)`.
- A **scan wave** scrolls inward from the edge to the centre over the wind-up: time collapsing.
- The decal renders at 60 fps even when its caster is a 12 fps clay enemy, so it is always readable.

### 8.6 The Venn Double

When a CIRCLE and a SELF_AURA from two different allies overlap at Boost Lv3 in the same Sync window (a Dual, or two allies acting back-to-back from the Ready Pool), the overlap becomes a **Venn**: battlers in the overlap take both shapes' hits and the shave of both, plus +1. Crono's admission that he is a copy unlocks the Venn as a standing option for his Duals (Reinforced Guard is the first).

### 8.7 Duals and Triples

- **Who:** the listed actors must all be at the gate at once (one has just arrived; the others are parked in the Ready Pool, or arrived on the same frame).
- **Cost:** each actor pays their own part of the cost (MP; Crono's max-HP ceiling; Sera's solidity). Boost is chosen once for the whole technique and spends that many BP from the pool.
- **Synergy:** Dual 1.6, Triple 2.2; universe synergy 1.25 when a Triple spans three home universes.
- **Stats:** the technique uses the best relevant attack stat among its actors.
- **After:** every participant's gauge resets to 0.
- **Shape:** each Dual and Triple has its own shape; several are anchored to the actors' positions (Delta Storm's triangle, Triangulation's dash along Xyloph's tether), which is why positioning before a Sync Hold matters.
- **Who refuses:** some Duals are locked by flags (Glenn refuses Dual Techs with Krona for two universes after a Dark ≥ 90 path; TRUE NULL allies cannot take part in any Dual; Ending 8 disables Duals entirely).

### 8.8 Height, cover and friendly fire

- Attacking from a ledge downward +10% damage; upward −10%.
- LINE_PIERCE stops at walls, cover and Break-locked bodies unless stated. CIRCLE, SELF_AURA and CONE ignore cover but not walls taller than 3 m.
- Party techniques never hurt party members, with three exceptions that say so: NULL (strips allies in the shape too), Krona's Crimson Seppuku That Failed (Krona herself), and Prometheus Overload (Cassia-09 shuts down for six frames after, and allies in the inner 2 m take 10% max HP).

## 9. Elements, Tags and the Elemental Canvas Clash

### 9.1 The nine elements

Each element has exactly three tags, and no tag is shared between elements, so a weakness to one tag never accidentally matches two elements.

| Element | Tags | Character | Identity in combat | Strong against | Weak against |
|---|---|---|---|---|---|
| ASTRAL | [ASTRAL][SWORD][TIME_DEBT] | Crono | Paradox damage: neither physical nor elemental; % of current HP and gauge displacement; costs max-HP ceiling | temporal foes: Vaelos, Lavos spawn, Arch-Curators | living memory (U7) |
| TACHYON | [TACHYON][PIERCING][PROBABILITY] | Sera | Probability, not damage: rewinds, gauge pushes, duplicates; costs solidity | anything with a gauge to push; Ferro-pinned targets | erasure (NULL) |
| RUIN | [RUIN][ENTROPY][ASH] | Krona | Anti-heal entropy: decays buffs, corrodes armour, turns ground to Ash Field | buffed enemies, Zeal shields, umbilicals | glass (VITREOUS), light |
| FERRO | [FERRO][RESONANCE][MAGNETIC] | Cassia-09 | Resonance and magnetism: scans, pulls, pins, hitches, repairs copies | metal and porcelain, the 12 fps frame | volt, rust |
| MYCELIA | [MYCELIA][LIFE][SPORE] | Xyloph | Graph building: tethers, shared damage, conversion of tags into healing | lichen, papyrus, glass lead | fire, dimness |
| VITREOUS | [VITREOUS][REFRACT][PRISM] | Vesper | Bends, splits and stores: Light Stacks, prism splits, caustic floors (it is **not** Light) | false light: Vaelos's | opaque clay (U2) |
| GUILE | [GUILE][TRICK][BP_STEAL] | Pierrot-Glenn | Deception and BP theft, turn manipulation | performers, liars, the laugh track | honesty (an honest GUILE hit) |
| HZ | [HZ][SIGNAL][WHITE_NOISE] | Static | State control: blindness as a resource, tuning, jamming, cross-style buffs | Lavos larvae, magic circles, glass shields | NULL, sound |
| NULL | [NULL] | Omega-Spekkio (and, after U7, Sera and Crono) | Erasure: strips tags, resistances and buffs; true damage; creates fake weaknesses on the weaknessless | everything with a strength | nothing; and that is its cost |

### 9.2 Weapon, world and mode tags

Enemies also have weaknesses to tags that are not elements. The party supplies them like this:

| Tag | Supplied by |
|---|---|
| [SWORD] | Crono (all ASTRAL), Krona (nodachi techs), Pierrot-Glenn's Prop Sword |
| [BLUNT] | Pierrot-Glenn (Prop Hammer, Slapstick, Juggling Pins), Cassia-09 (press-stomp leg strike) |
| [PIERCING] | Sera (all TACHYON), Vesper (Lily Lancets) |
| [GUN] | Cassia-09 (Gatling Arm in bipedal form, Empress Cannon), Solar Railgun |
| [BOW] | Marle (guest) |
| [FIRE] | Krona (Cinnabar Flare), Cassia-09 (Prometheus Overload, foundry heat), Static (Red Bike Ghost), Vesper's Amber pane, Marle's flare bolts |
| [ICE] | Vesper's Azure pane, Marle's frost bolts |
| [WATER] | Xyloph (Dew Lance), Vesper (Baptistery) |
| [WIND] | Xyloph (wing gusts, Solar Winds), the U0 kitchen shutters |
| [VOLT] | Static (all HZ when tuned NOISE), Cassia-09 (Ferro-Capacitor), Overclocked Short-Circuit |
| [LIGHT] | Marle's Ward, Vesper's Prism Discharge (Light Stack release), Xyloph's Divinity Field techs |
| [DARK] | Krona's oil techs (Oil-Drinker, Crimson Seppuku), Crono's null_erasure (Dark ≥ 40) |
| [INK] | Krona (every sumi stroke), Cobalt Wash |
| [SOUND] | Cassia-09 (Gramophone Resonance, Sound Ring), Static (56k Prayer) |
| [RUBBER] / [SMOKE] | Pierrot-Glenn |
| [SAURIA] | Xyloph |
| [DIVINE] | Xyloph's Divinity Field; Sera as Warden |
| [AURA] | every SELF_AURA technique and every mend (Wire Loom Mend, Kintsugi Mend): the non-violent tag |
| [CARRION] / [SIGNAL] / [NOISE] | Static: his current tuning is added to every hit he lands |
| [REMEMBER] | holding focus on a target for 2 s (the True Ending's last plate) |

Tags an enemy *has* (its own tags) matter for party resistances and for Canvas Clash terrain; tags in its weakness list matter for shaving.

### 9.3 Special matches

- **[PRISMATIC]** weakness: matched by any hit carrying three or more element tags (most Triples, the vitreous_refraction beams, Amber Rift techniques). It counts as one match.
- **Shape weaknesses:** [CIRCLE], [LINE], [AURA] as weaknesses are matched by the shape of the action, not its tags (Lavic Filament Guardian).
- **Created weaknesses:** NULL can create fake weaknesses on enemies that have none (Kami-Ori, Empress Vaelos, Omega-Spekkio). They last 2 turns and count as real for shaving and for the 2.0× multiplier.
- **Honest GUILE:** some enemies are weak only to an "honest" GUILE hit: a GUILE technique used while Glenn has not stolen BP from that enemy this battle.

### 9.4 The prism split (U4)

Light in U4 has geometry. Vesper's white Cathedral Ray, or any VITREOUS beam, passing through a coloured pane picks up a tag: **Azure** adds [ICE], **Amber** adds [FIRE], **Cobalt** adds [TACHYON]. A party member standing behind an Azure pane when they attack has their FIRE technique converted to ICE for that turn (FIRE is replaced, not added). The TacticalPositioner shows panes and the resulting tags in the preview.

### 9.5 Ally vulnerabilities and resistances

Party members have weaknesses too: incoming hits carrying a character's vulnerable tag deal 1.5× (and break their Guard), resisted tags 0.5×.

| Character | Vulnerable | Resistant |
|---|---|---|
| Crono | [RUIN][NULL] | [TIME_DEBT] |
| Sera | [NULL][HZ] | [TACHYON] |
| Krona | [VITREOUS][LIGHT] | [RUIN][FIRE] |
| Cassia-09 | [VOLT][RUIN] | [FERRO] |
| Xyloph | [FIRE][RUIN] | [WIND][MYCELIA] |
| Vesper | [BLUNT][FERRO] | [VITREOUS][LIGHT] |
| Pierrot-Glenn | [FIRE][SWORD] | [BLUNT][RUBBER] |
| Static | [NULL][SOUND] | [HZ][VOLT] |
| Omega-Spekkio | none: [WEAKNESSES ERASED] | none |

The Final Dojo's **NULL SHIELD** lets any ally give up their vulnerabilities and resistances for a flat 20% reduction against everything. Kami-Ori's Offering does something harsher: **TRUE NULL** (see [Status Effects](#12-status-effects-and-hazards)).

### 9.6 The Elemental Canvas Clash

Elements burn or stitch terrain. Any technique that lands on the battle plane converts the terrain it touches when the pairing below applies; the converted terrain lasts for the rest of the battle unless something converts it again. The teaching example is Crono's ASTRAL burning U1's black ink pools into golden watercolour (Chapter 2, the bamboo grove duel).

| Element | Burns (turns hostile terrain friendly) | Stitches (joins or builds) |
|---|---|---|
| ASTRAL | Black ink pools → **golden watercolour patches** (allies inside regain 2 MP per 5 s; Crono's first cast from inside costs no Battle Strain). VHS Fog → cleared in a 3 m radius for 10 s. | Draws a watercolour bridge across a gap along his Smear Dash path. |
| TACHYON | Rewound ground: any terrain Sera Rewinds returns to how it was at her last turn start. | Ghost footholds: phase-steps over void and water for allies who follow her path within 2 s. |
| RUIN | Glass, paper and wood → **Ash Field** (enemies 0.5× movement, −1 temporary plate per 2 s; Krona feeds on it). | Oil seams: links two oil puddles so fire on one spreads to the other. |
| FERRO | Mercury puddles → amber pools (Mercury Pulse recharges; enemies SLOWed). | Magnetic rails: pulls metal debris into cover; reverses conveyors. |
| MYCELIA | Ash and oil → **spore mats** (allies regenerate 2% HP per 2 s). | Seed bridges and memory vines across gaps; tethers between nodes are walkable. |
| VITREOUS | Dark water → **caustic floor** (hits passing over gain [VITREOUS]). | Glass lenses that redirect beams (the prism split, on demand). |
| GUILE | Any terrain → **confetti pit** (a decoy: enemies target it once). | Stretch springs: accordion platforms that launch an ally 2× their move range. |
| HZ | Magic circles and enemy sigils → erased. Neon light-walls → passable for 4 s. | Signal lines: two TVs or CRTs connected by a line become a LINE_PIERCE trap for 6 s. |
| NULL | Everything in the shape → **white blank** (no tags, no fields, no hazards) for 2 turns. | Folds: draws a mountain or valley line that brings two distant platforms together for 5 s (U7 traversal). |

Terrain the universes start with (ink pools in U1, mercury and marrow in U2, papyrus walls in U3, glass and dark water in U4, ash and cotton in U5, puddles and neon in U6, void in U7) is listed with its hazards in [Status Effects and Hazards](#12-status-effects-and-hazards).

## 10. Character Kits

Nine playable characters, nine elements, nine canvases. Each kit below gives the character's role, weapon, resources, passives and commands; the techniques themselves, with every number, are in the [Tech Library](#11-tech-library). Base stats and growth are in [Progression](#15-progression). Animation rates are part of each character's readability: their gauge marker, their idle and their hit-stop all step at their own rate in every universe.

### 10.1 Crono (41) — ASTRAL

**Role:** front-line striker and the party's shield. **Canvas:** U0 watercolour, 60 fps, intentional smear. **Joins:** start. **Weapon:** katana with the Epoch gauntlet; Attack is 2 hits of [SWORD]. **Vulnerable** [RUIN][NULL] · **Resistant** [TIME_DEBT].

**He pays with himself.** Crono's techniques cost no MP. They cost his maximum HP. His HP has three layers:

| Layer | What lowers it | What restores it |
|---|---|---|
| **Battle Strain** | Every ASTRAL technique's listed cost (a percentage of his base max HP); enemy effects that "reduce the max-HP ceiling for the battle" (Krona's antimatter Masamune in the duel, severing a Marrow-Umbilical) | Clears at the end of every battle. Wire Loom Mend restores up to 10% mid-battle. |
| **Camp Strain** | Costs written as "until camp": more than three puzzle rewinds in U4 (8%), freezing the U4 sun (12%), showing his galaxy in U5 (12%), a Debtling surviving a battle (2%), a Ledger Wisp's Regret Tick (5% per turn), Ruin stacks that persist after battle | Clears at a camp, an inn, or the Atrium bed. |
| **Integrity (Time Debt)** | Persistent porcelain damage: every defeat (−5); every new gate jump along the story thread (−0.4, the collarbone; halved by Reinforced); story choices that say "permanent" (the Prologue, the R-66Y Rewind, kintsugi mends in the Heart, the Predator sliver, the Dark U6 choice); interest: each full 20% of Battle Strain he takes in one battle costs −1 integrity at its end | Time Atoms (+0.5 each); Wire Loom Mend (+0.6, once per battle); U7 lotus-pond kintsugi (+1 per 8 s); Robo Ribbon (+5, once); Gold Leaf repair (+10, Light ≥ 90 after telling Marle); Promise Across Rust (+3); Family Porcelain (+2); the Golden Light ending (full) |

His maximum HP in battle is:

```
max_hp = base_max_hp × (0.5 + 0.5 × integrity / 100) × (1 − battle_strain − camp_strain − 0.15 × ruin_stacks)
floor: 10% of base_max_hp
```

**The crack states** read from the worse of his current HP as a percentage of his *base* max HP and his integrity. That is why a deeply indebted Crono looks cracked even at full health.

| State | Range | In combat |
|---|---|---|
| Pristine | 100–61 | Normal. |
| Hairline | 60–21 | Gold veins, inner doll face. **Every Sera Rewind or Chronoslip in this battle costs Crono 5% of his max HP** as damage (it cannot KO him). Duals that require "Crono ≤ 60%" (Chrono Prism, Honest Stage) are available. Porcelain Reveal: ASTRAL damage +10%. |
| Galaxy | 20–1 | The Time Egg starfield shows. Astral Smear Dash leaves a red → blue trail that inflicts one stack of Mercury SLOW (4 s) on any enemy that crosses it before its next turn. ASTRAL damage +20%; +50% against targets that have been NULLed. Allies with line of sight become **Concerned** once per battle: healing on Crono ×1.5, his Confession dialogue locked until camp. Fake Family Photo becomes available. |
| Flatline | 0 | In battle: KO. As integrity: the Atrium locks and Vaelos lays siege (see [Failure and Recovery](#16-failure-and-recovery)). |

**Passives.**

- **Father Tank:** whenever Sera's HP is below 40%, Crono automatically taunts every Lavos-spawn on the field (they target him). No input; he stands between her and Vaelos.
- **Trauma Silence:** +10% evasion; +20% while he is below 50% HP. He makes no battle grunts under 50%.
- **Porcelain Audit:** Cassia-09 tracks his integrity on her gramophone readout once she joins; before that, the player sees only the cracks.
- **Bekkler Doll + Time Egg:** at camp, Crono can give the Time Egg to Sera so she sleeps without nightmares: her Translucency Debt −3, his integrity −10.

**Commands.** Astral Smear Dash (move and strike in one), Father Tank (passive), and from U7 the NULL lesson (2% Battle Strain).

**Techniques:** [11.2](#112-crono--astral); Duals and Triples are listed by actor in [11.12](#1112-dual-techs) and [11.13](#1113-triple-techs).

### 10.2 Sera (17) — TACHYON

**Role:** timeline manipulator; support who wins fights by moving time, not by dealing damage. **Canvas:** base watercolour at 60 fps plus seven ghost layers at 14% opacity, each in its own universe's style and rate. **Joins:** start; taken at the end of Chapter 1, she acts as Hover Support in universes where she is captive and rejoins the active party for stretches. **Weapon:** tachyon needles; Attack is 2 hits of [PIERCING]. **Vulnerable** [NULL][HZ] · **Resistant** [TACHYON].

**She pays with herself too.** Sera's meter is her **Solidity**, shown as how much of her is still here.

- **Translucency Debt** (persistent) is the story's clock: +5 for every new gate jump along the story thread (returning to the Atrium hub and back through an opened gate is free); +1 interest for each full 20% of solidity spent in one battle; story events. Outside scripted scenes it never rises above 55. It recovers only at the U7 lotus ponds (kintsugi, 1 per 8 s) and in U3, where Moon Meditation (hold Guard still for 2 s inside a Divinity Field) recovers 2 per second but only gives back Debt accrued inside U3. The Atrium fountain resets the visual smear and never the Debt.
- **Battle solidity** starts each battle at 100 − Debt (in the U8 Heart it is set to 60: the Heart aligns her). Her costs come out of it: Rewind 5, HOLD 5 per step, Borrowed Future 10 (+10 below 50), Rewind Reel 10, NULL 5, the hover fast-forward 3. Each of her turns spent without a TACHYON skill gives back 2, up to the battle-start value.
- **Thresholds,** each crossed once per battle on the way down:

| Solidity | Effect |
|---|---|
| 80 | First double-voice whisper. Ghost layers visible rise from 1 to 3. |
| 60 | Hair flicker. **Token Duplicate (self):** once this battle she may take a double turn. Ghosts 5. |
| 40 | **Causal Collapse:** she phases out for 2 full turns (the time her gauge would take to fill twice): untargetable, no actions, bar removed; only her U7 gold-leaf ghost remains; whispered "Mama?"; party synergy drops from 1.10 to 0.85. Ghosts 7. Vs Vaelos this triggers his recruitment scene. |
| 20 | **Amber Rift** auto-triggers: +15 Prismatic (once per universe); a 3 m rift opens on her position for 6 s in which every hit counts as [PRISMATIC]. |
| 0 | She cannot spend solidity. Any cost forced on her is paid by Crono as Battle Strain, 1:1. |

**Passives.**

- **Quantum Flicker:** she never touches the ground. Floor hazards and floor terrain (ink, mercury, ash, spore mats, puddles, void) do not affect her, for good or ill. While three or more of her ghosts are visible (solidity 80 or lower), her hits deal +20%.
- **Fall Break** tradition: she was never taught how to fall, so she taught herself; see the tech.

**Commands.** **Rewind** (restore one target, ally or enemy, to its own last turn-start state: HP, gauge, position, statuses gained since), **HOLD** (on a Broken enemy: +2.5 s of lock per 5% solidity; +3.0 s per 5% after `Central_Eye_Broken`), **Borrowed Future** (every ally gauge −30%, then a Token Duplicate for the ally nearest a full gauge: two consecutive turns, the second costing nothing and copying the ability and its crit exactly, rendered in that ally's native art style).

**Hover Support.** When Sera is not in the active four, she keeps a hover gauge on the Turn Bar. At its gate she can use **Turn-Bar Daggers** only: rewind one ally's HP to its last turn start (5% solidity) or fast-forward one ally's gauge +25 (3%), or HOLD a Broken enemy.

**Techniques:** [11.3](#113-sera--tachyon); Duals and Triples are listed by actor in [11.12](#1112-dual-techs) and [11.13](#1113-triple-techs).

### 10.3 Krona — RUIN

**Role:** breaker and self-sacrificing tank; anti-heal entropy. **Canvas:** U1 sumi-e, 24 fps on twos, impact holds of 6 frames. **Joins:** Chapter 2 (after the bamboo grove duel, before the Mammon Furnace). **Weapon:** dual nodachi (the Defiled Masamune, upgraded to the Cobalt Nodachi); Attack is 2 hits of [SWORD][INK]. **Vulnerable** [VITREOUS][LIGHT] · **Resistant** [RUIN][FIRE].

**Resources.**

- **Corruption** (persistent, 0–100, the crack climbing her neck): +5 per gourd sip, +10 per Crimson Seppuku. At 50: +10% RUIN damage, −10% healing received. At 100: she cannot be healed by anything but the gourd. `Goyama_Repainted` (sealing the vein) clears it and depowers Oil-Drinker; `Goyama_Incinerated` keeps it and adds +15% RUIN damage to the Cobalt Nodachi.
- **Corroded HP and Ruin Charge:** healing from allies becomes Corroded HP (temporary, ticks down 5% of itself per 2 s) and grants 1 Ruin Charge per 10% healed (max 5; each charge +5% damage on her next RUIN technique, then spent). Sera's Rewinds restore only 30% of what they would on anyone else.

**Passives.**

- **Oil-Drinker:** below 25% HP she sips from the hip gourd automatically: heals 20% of her max HP as normal HP, +5 Corruption. As a command, the gourd heals the whole party at half effectiveness (10% each).
- **Oil-Drinker+ (Geothermal):** taking the ruthless road in U2 (overloading the Geno-Foundry pipes) adds +25% critical chance against mechanical and Lavos enemies.
- **Ash Feeder:** standing in an Ash Field, her RUIN techniques cost 20% less MP.

**Commands:** Oil-Drinker (gourd), Shogun's Command (taunt). Krona also teaches the whole party **Ens Parry** (see [Commands](#4-commands)).

**Techniques:** [11.4](#114-krona--ruin); Duals and Triples are listed by actor in [11.12](#1112-dual-techs) and [11.13](#1113-triple-techs).

### 10.4 Cassia-09 — FERRO

**Role:** tank, debuffer, terrain engineer, the only character who repairs Time Debt. **Canvas:** U2 claymation at 12 fps stepped, VHS and CRT, thumbprint normals. **Joins:** Chapter 3, after the Porcelain Weaver. **Weapon:** gramophone horn; Attack is Gramophone Resonance, a CONE (radius 2.5, length 4.0) of 1 hit [SOUND][FERRO]. **Vulnerable** [VOLT][RUIN] · **Resistant** [FERRO].

**Two minds.** Cassia OS (nine, earnest) runs on Lucca's preserved nervous system (blunt, wants to fix Crono). **Lucca abilities** (Wire Loom Mend on Crono, Ferro Graviton's consent bonus, Prometheus Overload, the Lucca Lens in Mercury Pulse) show an **Ask** prompt the first time each battle: asking builds **Synergy** (max 3, +5% damage each); skipping builds **Resentment** (max 3, −10% each, the amber dims). Both persist until the Atrium camp conversation.

**Mercury orb:** Mercury Pulse spends her orb; it recharges after 2 of her turns, or instantly by standing in an amber pool or harvesting a Static Noise pile.

**Forms (permanent, chosen at R-66Y):** **Gramophone Centaur** (default; `R-66Y_Rewound`): six legs, climbs ribs and ignores height in her move, Mercury Pulse radius +1.0. **Bipedal Porcelain** (`R-66Y_Salvaged`): Lucca's silhouette, +20% P.Atk, the Gatling Arm, loses the climb.

**Extract or Keep (late arc):** **Extract** gives the accessory *Lucca's Last Schematic* (any ally can cast Reinforced Guard's effect) and Cassia-09 leaves the party. **Keep Integrated** keeps her; Lucca fades to a hum and Cassia speaks as "we".

**Passives.**

- **Porcelain Audit:** Crono's −0.4 collarbone loss per gate jump is shown and becomes repairable; she reads his integrity out loud. "Crono, collarbone −0.4% per jump. Your Lucca didn't reinforce?"
- **Ferric Rattle:** her Gramophone Resonance deals +25% to metal-tagged enemies and hitches their next action.

**Commands:** Mercury Pulse scan (reveals every weakness in its circle), Loom Pull (grapple a prop, syringe, mask, or a small enemy 4 m toward her).

**Techniques:** [11.5](#115-cassia-09--ferro); Duals and Triples are listed by actor in [11.12](#1112-dual-techs) and [11.13](#1113-triple-techs).

### 10.5 Xyloph — MYCELIA

**Role:** network carrier: not a healer, a graph builder. **Canvas:** U3 Moebius ligne claire, 30 fps, 2 px constant line; six wings rippling in a [2,4,6,2,4,6] offset over 18 frames, never in sync. **Joins:** Chapter 4 (freed from Azar's stasis, she arrives through Sera's Borrowed Future duplicate). **Weapon:** talons and wing gusts; Attack is 2 hits of [SAURIA][WIND]. **Vulnerable** [FIRE][RUIN] · **Resistant** [WIND][MYCELIA].

**Resources.**

- **Mycelia Shared pool (12 orbs):** placing a node costs 1 orb. The pool regenerates +1 every time an ally takes a turn without moving: stillness as mercy. **In U3 the pool belongs to the whole party:** every technique anyone casts in U3 also costs 1 orb, and every traversal glide costs 1.5 per second. Burning more than 6 orbs in 10 s triggers the **Fake Carrier Burn**: pollen browns, U2 vinyl crackle, the bar jitters, and it deals no damage at all (a fungal social deception, taught only through the effect).
- **Sunlight Stacks (max 5):** gained in U3 light shafts, from post-snap blooms, from the Reptite Crown canopy. **Spore Tags** land on enemies from tether snaps and her techniques.

**The Tether.** Up to 3 nodes on allies or terrain anchors (one placement per turn is a free action). Nodes pulse every 1.5 s. Connected allies share 15% of incoming damage across the net; cleanses and status ticks travel along the vines at 0.3× speed. A tether stretched past 12 m snaps: a 2 s bloom applying SLOW and a Spore Tag to enemies around the break. Tethers are conduits for Duals: Crono's dash along a tether is Triangulation; Cassia-09's Mercury Pulse along a tether doubles its range and adds an amber DoT; Vesper's light along a tether prism-splits.

**Passives.**

- **Thermal Glide:** in U3 thermals her move range is +4 m and she ignores falls; the permanent Papyrus Membrane (also required for the U6 city) lets her glide everywhere at 1.5 Shared per second, refunded on landing in a Divinity Field.
- **Core Lattice:** when Crono is in his galaxy state, Xyloph can lattice him (a tech): his ASTRAL costs halve and his DEF rises 30% for 3 of his turns.
- **Panspermia (late):** tethers can reach the Bench; benched allies share the 15% too. In U7 and U8 her tethers become the cross-reality platform the nine-member formation stands on.

**Techniques:** [11.6](#116-xyloph--mycelia); Duals and Triples are listed by actor in [11.12](#1112-dual-techs) and [11.13](#1113-triple-techs).

### 10.6 Vesper (Alfador) — VITREOUS

**Role:** refractive knight and archivist; stores damage and gives it back as light. **Canvas:** U4 stained glass; body at 60 fps, the light through him keyed at 12 fps, Schala's cat-shadow at 30 fps as a separate entity. **Joins:** Chapter 5 (when the party Breaks the Central Eye and reveals the siphon). **Weapon:** a lance of rose-window glass; Attack is 2 hits of [PIERCING][VITREOUS]. **Vulnerable** [BLUNT][FERRO] · **Resistant** [VITREOUS][LIGHT].

**Resources.**

- **Light Stacks (max 5):** Prism Guard stores incoming damage as stacks; Fractured Lens refills them all at once; Prism Discharge spends them.
- **Schala's Shadow:** the cat is an independent light-collider placed by angling Vesper toward a light source (a free part of his move). It slips through cracked panes Vesper cannot, can touch enemy lens weak points (a hit there counts as [VITREOUS] from any ally), and doubles Light Stack gain while it overlaps him.

**Passives.**

- **Fractured Lens tell:** below 25% HP his lead blacks crack and show the infinite library inside: his version of Crono's galaxy.
- **The prism split:** see [9.4](#94-the-prism-split-u4).

**Commands:** **Prism Guard** (until his next turn: −40% damage taken, +1 Light Stack per hit taken, +2 with the cat overlapping); **Polish** (wipe a glass surface: reveals a hidden memory, redirects a beam, or wakes a sleeping lantern).

**Techniques:** [11.7](#117-vesper--vitreous); Duals and Triples are listed by actor in [11.12](#1112-dual-techs) and [11.13](#1113-triple-techs).

### 10.7 Pierrot-Glenn — GUILE

**Role:** trickster; the BP economy breaker and turn manipulator. **Canvas:** U5 1930s rubber-hose, 24 fps on twos (12 drawings per second), boiling outline, 300% stretch, pie-eyes. **Joins:** Chapter 6 (after losing the wrestling bout on purpose). **Weapon:** prop arsenal: cane, slapstick, juggling pins, and a cardboard Prop Sword that really cuts threads; Attack is 3 hits of [BLUNT][RUBBER] (props) or 1 hit of [SWORD][GUILE] (Prop Sword); swapping props is free. **Vulnerable** [FIRE][SWORD] · **Resistant** [BLUNT][RUBBER].

**Theft rules** are in [7.5](#75-glenn-and-theft): one steal per action, 1 / 2 / 3 BP by Boost level, from the enemy's stolen-BP counter first.

**Honesty.** Some enemies (Heckler Harlequin, Cyrus's Strings, the Encore's last phase) are weak only to an **honest** GUILE hit: a GUILE technique used against a target Glenn has not stolen from this battle. Honest Laugh makes the next hit honest regardless.

**Passives.**

- **Punchline:** when Glenn enters a battle or is swapped in, he steals 1 BP, plus 1 for each enemy holding stolen BP (max 3).
- **Accordion Dodge:** 25% chance on any physical hit to flatten to a 2 px profile: a perfect dodge plus a free 1 BP steal (once per enemy turn).
- **Low-HP tell:** below 25% his white paint cracks and shows tiny warm circus bulbs, and, after the Light path, a single origami frog: hollow is space for something to hop into.

**Commands:** Steal (Sleight of Arm), stretch reach (his SINGLE techniques reach 6 m without moving). On U5 stages his slashes cut threads.

**Techniques:** [11.8](#118-pierrot-glenn--guile); Duals and Triples are listed by actor in [11.12](#1112-dual-techs) and [11.13](#1113-triple-techs).

### 10.8 Static (13) — HZ

**Role:** state control; blindness as a resource. **Canvas:** U6 1988 cel anime, 4-tone, on twos (15 drawings per second), ones on impacts, CRT and scanlines. **Joins:** Chapter 7. **Weapon:** CRT goggles and a battery sling; Attack is 2 hits of [HZ] plus his current tuning tag. **Vulnerable** [NULL][SOUND] · **Resistant** [HZ][VOLT].

**VHS BLIND (passive).** Static starts every battle blind: +30% evasion, cannot target anything (his targeting is −100%). His screen space is a white-noise block with two blue eyes.

**Tune (free action, once per turn).** Switching locks his frequency and ends BLIND for the battle (he can return to BLIND as a tuning, gaining its evasion back). Every hit he lands carries his current mode tag.

| Mode | Effect |
|---|---|
| NOISE | His hits add [NOISE] and [VOLT]. White noise in his area techniques lowers enemy hit −30% and erases magic circles. Counters U4 glass shields and Zeal mages. |
| CARRION | Larva resonance: his next hit reveals one target's weaknesses and its "elemental memory" (which universe it came from), marks Vaelos-clone parts (marked parts take +25% from everyone) and opens Juvenile cores. |
| SIGNAL | An ally buff: the target ally's next action borrows one element tag of another party member's element and can join a Triple as if it were a listed actor (the cross-style Triple enabler: one frame of another canvas's physics, such as Crono's dash in sumi-e or Cassia's clay shatter). Lost forever with `U6_Matriarch_Unplugged`. |

**Hiss.** The juvenile Lavos larva in his throat is the reason he sees. It answers Vaelos when Vaelos calls it "little brother"; in U6 the party fights blind unless Static is tuned.

**Techniques:** [11.9](#119-static--hz); Duals and Triples are listed by actor in [11.12](#1112-dual-techs) and [11.13](#1113-triple-techs).

### 10.9 Omega-Spekkio — NULL

**Role:** the optional ninth: an eraser who refuses the elemental game. **Canvas:** U7 Amano gold leaf and negative space, 24 fps with long holds; pose-to-pose 2 s holds, then a 12-frame paper crumple snap; he does not move to attack, the world folds into him. **Joins:** Chapter 8, optional: found in U7's negative space if Sera carries all 8 sigils, after Kami-Ori; recruited through the Final Dojo. **Weapon:** folding; Attack is 1 hit of [NULL]. **Vulnerable** none · **Resistant** none: [WEAKNESSES ERASED].

**Gold Leaf stacks (max 5):** he gains one each time an enemy hit lands on him or on a NULL SHIELD ally with a tag that would have been a vulnerability. Spent by Gold Leaf Severance.

**The Final Dojo's gifts (party-wide, permanent once won):** Crane: party members no longer take critical hits from [FIRE]. Samurai: magnetization no longer hitches party members. Dragon: Crush and drowning hazards no longer deal percentage damage. Faceless: **NULL SHIELD**, a toggle any ally can take: give up their vulnerabilities and resistances for a flat 20% reduction against everything.

**Commands:** **NULL** (strip tags, resistances and buffs from everything in a 3.0 m circle for 2 turns, allies included; on targets with no weakness it creates a fake one from the 42-entry pool).

**Techniques:** [11.10](#1110-omega-spekkio--null) and the Omega Triple. After the ending he stays in the Bone-Tree as the post-game dojo master who re-folds boss movesets for rematches.

### 10.10 Bonus member: Vaelos (child form)

Only in Ending 3 (Vaelos Child) and New Game+ from it, as a tenth member. He joins at Lv 1 with the unique element **NULL_LEARNING** (TACHYON/NULL hybrid) and his body animates at 60 fps while his head nods at U7's 18 fps.

- **Porcelain Memory (passive):** he learns a weakness tag each time the party uses a shape near him; once he holds three, his own shapes *add* a weakness tag to what they touch instead of erasing one, and he can hold one weakness for an ally to shatter (his own damage on it is 0.5×: he doesn't want to hurt, only to help break the shell).
- **Kintsugi Mend:** his signature tech, with **Null Spoon HOLD** beside it (see the [Tech Library](#11-tech-library)).
- **Porcelain Promise Child** (Crono + Vaelos) is his Dual.
- **Family Porcelain**, **Fake Family Photo Real** and **First Light That Never Was — Child Variant** (all Crono + Sera + Vaelos) are his Triples.

### 10.11 Guest: Marle (Queen Nadia, 40)

A guest in the Prologue and in several ending chapters. **Weapon:** royal crossbow; Attack is 2 bolts of [BOW][FIRE] (flare) or [BOW][ICE] (frost), switchable for free. **Techs:** Light Bolt ([BOW][LIGHT], 2 hits), Ward (heal 20% and halve the next hit on one ally, [LIGHT][AURA]), Vitreous Arrow (endings, glass bolts from Vesper, [BOW][VITREOUS]). **Dual:** Porcelain Promise (Crono + Marle), locked until the end of Act I. In the Empress Heir ending her Queen's Sacrifice offer changes the boss (see [Bosses](#14-bosses)).

## 11. Tech Library

### 11.1 How to read the tables

- **ID** is the data id used by the TechResource files (see [Godot 4.7 Implementation Notes](#18-godot-47-implementation-notes)).
- **Tags** are what every hit of the technique carries. Element tag sets follow [9.1](#91-the-nine-elements).
- **Shape / size** in metres: CIRCLE radius, LINE length (× width when not the default 1.2), CONE radius / length, SELF_AURA outer radius. "AoE" is the technique's own AoE scale, multiplied with the Boost shape scale.
- **Power:** `1.2 ×3` means 1.2 per hit for three hits. A single figure on a multi-hit technique is the total, spread evenly across its hits.
- **Cost:** MP; Crono's costs are % of his base max HP as Battle Strain unless marked "Camp Strain" or "integrity"; Sera's are % solidity ("sol"). Duals and Triples list each actor's part. Boost is chosen once per action and spends BP from the pool on top of these costs.
- **Unlock:** chapter, level, flag, or drop.

### 11.2 Crono — ASTRAL

| ID | Name | Actors | Tags | Shape / size | Hits | Power | Cost | Effect | Unlock |
|---|---|---|---|---|---|---|---|---|---|
| time_slice | Time Slice | Crono | [ASTRAL][SWORD][TIME_DEBT] | SINGLE | 1 | 1.6 | 1% | The starter shaver. Bell on a weakness hit. | Ch1 |
| astral_smear_dash | Astral Smear Dash | Crono | [ASTRAL][SWORD][TIME_DEBT] | LINE_PIERCE 8.0 | 2 | 0.9 ×2 | 2% | Movement and strike in one: the dash path is his move. Gold light clears VHS Fog in 3 m for 10 s. In the galaxy state its red → blue trail gives Mercury SLOW (4 s) to enemies that cross it before their next turn. | Prologue |
| astral_slash | Astral Slash | Crono | [ASTRAL][SWORD][TIME_DEBT] | CONE 2.8 / 5.5 (AoE 1.1; 1.4 at Lv3) | 1 heavy + 1 bleed tick | 1.4 | 2% | Its bleed trail slows an enemy that steps in before its next turn. +15% while Crono is hairline or worse, +15% more on galaxy-state weakness hits; Lv3 leaves a 6 s watercolour puddle; Sera's Tachyon Needle in the same window extends the cone 1 m; +25% vs Arch-Curator rings. A sleeping Arris citizen takes 0 (harp gliss). | Ch1 |
| time_debt_seal | Time Debt Seal | Crono → Sera | [ASTRAL][AURA] | SINGLE (Sera) | — | — | 20% Camp Strain | Seals one of her slips: refunds Sera's last solidity cost, or cancels a Causal Collapse before it begins (once per battle). | Prologue |
| bekkler_guilt | Bekkler's Guilt | Crono | [ASTRAL][AURA][GUILT] | SELF_AURA 4.0 | — | — | 3% | Until his next turn, hits aimed at allies inside the ring land on Crono instead at 75% damage; each redirected hit gives +1 BP (max 2). | Prologue (The Bowl Still Whole) |
| astral_field | Astral Field | Crono | [ASTRAL][AURA] | SELF_AURA 4.0 | 1 | 0.8 | 3% | Forces U0 and U2 to agree: clears Grief-Resonance and VHS Fog inside for 10 s; allies inside take −15% from [RUIN]. | Ch3 |
| luminaire | Luminaire | Crono | [ASTRAL][SWORD][TIME_DEBT][LIGHT] | CIRCLE 6.0 | 4 | 1.0 ×4 | 8% | His ASTRAL ultimate; +25% vs Vaelos (false light). Lv2 Displaced. | Lv 35 |
| unborrowed_time | Unborrowed Time | Crono | [ASTRAL][NULL][SWORD] | SINGLE, then LINE_PIERCE 12.0 if the target is Broken | 1 + 1 | 2.4 | 1.2% | He throws his own Time Egg core: +5% of the target's current HP (1% vs bosses) on top of displacement; +2 shave vs Vaelos. | Lv 78 |
| null_erasure | Null Erasure | Crono (void echo) | [NULL][VOID][LAVOS] | LINE_PIERCE 18.0 | 1 | 2.2 | 5% Camp Strain | Always Breaks a target weak to [NULL]; otherwise shaves 4. Lv3 voids the floor (removes residual fields; counts as a purge for Possibility). Used on Vaelos: "You remember being burned." Required to reach Atropos Ribbon's sever. | Dark ≥ 40 |
| null_crono | NULL (Kami-Ori's lesson) | Crono | [NULL] | CIRCLE 3.0 | — | — | 2% | Strip tags, resistances and buffs for 2 turns (allies in the circle too); on a weaknessless target, create one fake weakness. | Ch8 |

### 11.3 Sera — TACHYON

| ID | Name | Actors | Tags | Shape / size | Hits | Power | Cost | Effect | Unlock |
|---|---|---|---|---|---|---|---|---|---|
| rewind | Rewind | Sera | [TACHYON][PROBABILITY] | SINGLE (ally or enemy) | — | — | 5% sol | Restores the target to its last turn start: HP, gauge, position, statuses gained since. The snap renders in the target's native style for 0.4 s. A hairline Crono pays 5% max HP each time. | Ch1 |
| hold | HOLD | Sera | [TACHYON] | SINGLE (Broken enemy) | — | — | 5% sol per step | +2.5 s Break lock per step (+3.0 s after `Central_Eye_Broken`). | Ch1 |
| tachyon_needle | Tachyon Needle | Sera | [TACHYON][PIERCING][PROBABILITY] | LINE 12.0 × 0.8 | 3 | 0.9 ×3 | 6 MP | Each hit pushes the target's gauge −8 (−13 at Lv3) and renders in a different ghost canvas. Magnetized targets are pinned: +1 shave. In the same window as Crono's Astral Slash, extends its cone 1 m. The first time per universe it lands with all seven ghosts visible: +5 Prismatic. "Hold still." | Ch1 |
| fall_break | Fall Break | Sera | [TACHYON][AURA] | SINGLE (ally) | — | — | 4 MP | The ally's next Time Debt cost is halved (Crono's next strain, Sera's next solidity, Krona's next Corruption). | Prologue |
| borrowed_future | Borrowed Future | Sera | [TACHYON][PROBABILITY] | party | — | — | 10% sol (+10 below 50) | Every ally gauge −30% (watercolour bleeds backward along the Turn Bar), then a Token Duplicate for the ally nearest a full gauge: an immediate second turn that costs nothing and copies the ability and its crit exactly, rendered in that ally's native art. | Ch4 (previewed greyed in Ch1) |
| borrowed_future_true | Borrowed Future — True | Sera | [TACHYON][ASTRAL][AURA] | CIRCLE 8.0 | — | — | 10% sol | As Borrowed Future. After Sera's voluntary 40% phase-out, the duplicate is solid (a duplicated Crono is uncracked 60 fps watercolour), and a Break it lands is extended as if HOLD had been spent once. | Lv 80 |
| rewind_reel | Rewind Reel | Sera | [TACHYON][SOUND] | battlefield | — | — | 10% sol | Scratches the record back 8 s: enemy positions, telegraphs and gauges return to where they were 8 s of battle time ago (allies keep theirs). Reveals Vaelos's threads; ends the Heckler Harlequin's invulnerability. Watercolour streaks in a rubber world. | Ch6 |
| slip_backtrack | Slip Backtrack | Sera | [TACHYON] | SELF | — | — | 5% sol | Rewinds Sera alone 5 s (position, HP, gauge). Learning it adds +10 Translucency Debt, once. | `U6_Matriarch_Fed` |
| hz_static_pure | HZ Static (Pure) | Sera | [HZ][TACHYON][AURA] | CIRCLE 3.0 | 8 | 0.25 ×8 | 8 MP | Static's pure tone, given to Sera when he loses SIGNAL: the silence field becomes a Lullaby Heal (allies inside regain 3% HP per hit). | `U6_Matriarch_Unplugged` |
| null_sera | NULL (Kami-Ori's lesson) | Sera | [NULL] | CIRCLE 3.0 | — | — | 5% sol | As Omega-Spekkio's NULL. | Ch8 |
| atropos_ribbon | Atropos Ribbon (relic ultimate) | Sera | [TACHYON][FATE][SEVER] | FATE LINE 99.0 (AoE 3.0) | 1 sever | 5.0 vs a memory; 2.0 otherwise | 20% sol | Cuts a tether to Vaelos and frees Debt: the party's next 3 Time Debt costs are 0. If Sera phases out willingly in the same battle, the party remembers her and she returns with her gauge kept. Fails if the Prometheus Core was burned selfishly. | True Ending route |

### 11.4 Krona — RUIN

| ID | Name | Actors | Tags | Shape / size | Hits | Power | Cost | Effect | Unlock |
|---|---|---|---|---|---|---|---|---|---|
| teppo_ash_cut | Teppo Ash-Cut | Krona | [RUIN][ENTROPY][INK] | CONE 180°, radius 3.0 | 1 + ink zone 3 s | 1.2 | 5 MP | Brush slash; the lingering ink zone DoTs anything standing in it. Impact holds 6 frames at 24 fps. | Ch2 |
| ruin_purge | Ruin Purge | Krona | [RUIN][ENTROPY][ASH] | CIRCLE 3.5 (AoE 1.3) | 2 | 1.6 | 7 MP | Ground → Ash Field (slow, −1 temporary plate per 2 s). +25% vs buffed enemies and purges 1 buff (2 at Lv3; Lv3 also turns the Ash into a −2 shave aura for 6 s). An ally who steps in her Ash ignores armour on their next hit; Crono stepping in it heals 2% Battle Strain. | Ch2 (after the Daimyo's Phase 1) |
| cinnabar_flare | Cinnabar Flare | Krona | [RUIN][FIRE][ASH] | CONE 2.5 / 5.0 | 2 | 1.2 | 6 MP | Oil through flame: the party's first [FIRE]. Ignites oil puddles; oil seams carry it. | Ch2 |
| shoguns_command | Shogun's Command | Krona | [RUIN][TAUNT] | SELF_AURA 6.0 | — | — | 6 MP | Taunt: 60% of all damage aimed at the party is bound to Krona for 2 of her turns. If she survives, every ally's next hit ignores DEF. | Ch2 |
| crimson_seppuku | Crimson Seppuku That Failed (ultimate) | Krona | [RUIN][DARK][ASH] | SELF_AURA 6.0 | 1 wave | 3.0 | Krona to 1 HP; +10 Corruption | An oil geyser: Corroded (−50% healing received) on every enemy for 3 turns, an Ash Field under each, and an automatic Oil-Drinker sip. The inverted Luminaire. | Lv 18 |
| cobalt_nodachi | Cobalt Nodachi (relic special) | Krona | [RUIN][SWORD][COBALT] | LINE 20.0 × 1.5 | 1 iai | 3.8 | 14 MP; 2.0 s draw (a wind-up) | Hold two seconds on twos, a 12-frame slice splits the screen indigo → white. Cuts an Ash Field into a clean line (terrain reset). +40% vs Vaelos's masked forms. Resonates with Mercury Pulse to open the U4 organ. | Goyama Daimyo drop |

### 11.5 Cassia-09 — FERRO

| ID | Name | Actors | Tags | Shape / size | Hits | Power | Cost | Effect | Unlock |
|---|---|---|---|---|---|---|---|---|---|
| gramophone_resonance | Gramophone Resonance | Cassia-09 | [SOUND][FERRO] | CONE 2.5 / 4.0 | 1 (8-frame rings) | 1.0 | Attack | Ferric Rattle: +25% vs metal and hitches their next action. | Ch3 |
| ferro_graviton | Ferro Graviton | Cassia-09 | [FERRO][RESONANCE][MAGNETIC] | CIRCLE 2.2, pull-in 1.6 (AoE 1.0 → 1.6) | 4 shards | 1.1 ×4 | 8 MP | Magnetizes. +30% if Lucca was asked at this camp. Vesper's prism doubles the shard count. Lv3 leaves a mercury pool: the next FERRO hit +20%. | Ch3 |
| mercury_pulse | Mercury Pulse | Cassia-09 | [FERRO][MAGNETIC][RESONANCE] | CIRCLE 5.5 (+1.0 as Centaur) | 1 | 2.0 | the mercury orb | Reveals every weakness inside (the Lucca Lens). Mercury SLOW and magnetic bind. Hovering magnet zones pull metal weapons and make cover; activates magnetic runes. Vs Vaelos it shows wiring that proves he contains Crono's atoms. Along a tether: double range and an amber DoT. | Ch3 |
| wire_loom_mend | Wire Loom Mend | Cassia-09 | [FERRO][AURA] | SINGLE (ally) | — | heal 0.9 | 10 MP | Restores HP and up to 10% of max-HP ceiling lost this battle. On Crono: +0.6 integrity once per battle. On other copies (Glenn, Vesper, Static): removes one hazard status (strips the art-curse: U6 scanlines, U1 ink bleed). A Lucca ability. | Ch3 |
| sound_ring | Sound Ring | Cassia-09 | [SOUND][FERRO][RESONANCE] | SELF_AURA 4.0 | 1 | 1.2 | 6 MP | The party's [SOUND] AoE: shatters Porcelain Choirs. Residual ring for 4 s (+10% amber shard drop). With an ASTRAL hit on R-66Y in one window: the Lullaby Rewind. | Ch3 |
| gatling_arm | Gatling Arm | Cassia-09 (Bipedal) | [GUN][FERRO] | LINE 10.0 | 8 | 0.35 ×8 | 8 MP | The 8th hit Magnetizes. | `R-66Y_Salvaged` |
| prometheus_overload | Prometheus Overload (relic ultimate) | Cassia-09 | [FERRO][FIRE][CORE_OVERLOAD] | CIRCLE nova 7.0 (AoE 2.5) | 1 detonate + 10 burn ticks | 4.0 | 30 MP; once per battle; Lucca's consent | Lucca's last act: the tank glows white, the gramophone melts. Boost bonus +60%; Cassia-09 then shuts down (next gauge starts at −20); allies within 2 m take 10% max HP. Without consent the Core counts as burned selfishly. Keeping the schematic unlocks Extract. | Ch3 (choice) |

### 11.6 Xyloph — MYCELIA

| ID | Name | Actors | Tags | Shape / size | Hits | Power | Cost | Effect | Unlock |
|---|---|---|---|---|---|---|---|---|---|
| mycelia_tether | Mycelia Tether | Xyloph | [MYCELIA][LIFE][SPORE] | CIRCLE 4.0 + tether lines | 1 + 3 spore ticks | 1.0 + 0.3 DoT | 4 MP + 1 orb per node | Places nodes (max 3; Boost adds 2 extra tether lines; AoE 1.8). 15% damage share. A tether snapped by damage blooms into an HP refund. Shaves nothing while building (plates read `HOLD`). +40% in U3 sunlight; −50% in U2 and U6 dimness. | Ch4 |
| photosynthetic_burst | Photosynthetic Burst (mycelia_bloom) | Xyloph | [MYCELIA][LIFE][SPORE] | CIRCLE 4.0 (AoE 1.8) | 1 + 3 ticks | 1.0 + 0.3 DoT | 8 MP; 2-turn cooldown | Folds six wings, 0.6 s hold, ligne-claire burst: consumes Spore Tags and Sunlight Stacks; each one refunds 4% HP and 2 MP to every tethered ally. Rooted while casting: +70% damage reduction. Germinates snapped nodes into seedlings that recast after 3 s. Wakes seed-bridges. Dim maps halve the conversion. | Ch4 |
| dew_lance | Dew Lance | Xyloph | [MYCELIA][WATER][SPORE] | LINE 9.0 | 2 | 1.2 | 5 MP | The party's [WATER]. Puts out oil fires. | Ch4 |
| core_lattice | Core Lattice | Xyloph → Crono | [MYCELIA][AURA] | SINGLE (Crono in galaxy state) | — | — | 8 MP | Crono's ASTRAL costs halve and his DEF +30% for 3 of his turns. | Ch4 |
| divinity_field | Divinity Field | Xyloph | [DIVINE][LIGHT] | SELF_AURA 40 (whole arena) | — | — | 16 MP | Allies gain +1 temporary plate per 5 s (cap 20% of max HP as temporary shield); thaws Ruin 1% per 8 s; an enemy that Breaks inside it is silenced 15 s. Counters Vaelos's Gravity. | `Azar_Predator` |
| reptite_crown | Reptite Crown (relic ultimate) | Xyloph | [MYCELIA][CROWN][BIO] | CIRCLE crown 6.0 (AoE 2.0) | 6 petals + crown | 3.3 | 24 MP | Grows a permanent blooming canopy: +1 Sunlight Stack every 5 s for the rest of the battle. +50% if the Lavos moon is visible (U3). "The spore that thinks it's the tree." | `Azar_Scholar` |

### 11.7 Vesper — VITREOUS

| ID | Name | Actors | Tags | Shape / size | Hits | Power | Cost | Effect | Unlock |
|---|---|---|---|---|---|---|---|---|---|
| lily_lancets | Lily Lancets | Vesper | [VITREOUS][PIERCING][PRISM] | LINE_PIERCE 7.0 | 3 (6 with the cat) | 0.7 ×3 | 6 MP | Each refracted lancet shaves 1; +2 when it lands in the colour the plate is showing. At Boost Lv3: 370%, +25% AoE, +1 shave. | Ch5 |
| cathedral_ray | Cathedral Ray | Vesper | [VITREOUS][PRISM] | LINE 12.0 | 1 | 1.6 | 6 MP | White light that picks up a pane's tag: Azure [ICE], Amber [FIRE], Cobalt [TACHYON]. | Ch5 |
| vitreous_prism | Prism Discharge | Vesper | [VITREOUS][REFRACT][PRISM][LIGHT] | SPLIT CONE 6.0 / 8.0 (AoE 1.2) | 6 beams (+1 per Light Stack spent) | 0.5 per beam | 5 MP + Light Stacks | Releases stored Light Stacks as beams and leaves a caustic floor. +35% while the cat is fully inside his chest. Any light source on the plane fractures. Along a tether: prism split. "Entry 4-22: I am afraid." | Ch5 |
| prism_refraction | Prism Refraction | Vesper | [VITREOUS][LIGHT][REFRACT] | CONE 6.0 / 8.0 | 6 (9 at Lv3) | 0.5 per prism | 9 MP | Needs no stacks. Lv3 leaves a caustic floor that refracts FERRO shards (they gain [VITREOUS]). Double damage vs the Glass Matriarch. | Lv 40 |
| baptistery | Baptistery | Vesper | [VITREOUS][WATER] | CIRCLE 3.0 | 2 | 1.0 | 7 MP | The baptistery's frozen splash thaws: allies inside regain 10% HP. | Ch5 |
| rose_window | Rose Window (ultimate) | Vesper | [VITREOUS][PRISM] | SELF_AURA 6.0 | 1 burst | 3.1 | 20 MP; cast at Boost Lv3 or higher | The Rose overhead, Schala's full portrait: for 8 s every party attack is VITREOUS (keeping its other tags) and gains one extra hit from a random angle. Leaves a residual puddle. | Lv 38 |
| fractured_lens | Fractured Lens (Debt move) | Vesper | [VITREOUS][AURA] | SELF | — | — | Vesper to 1 HP, Fragile 2 turns | Below 25% HP: instantly fills 5 Light Stacks and reveals the library. Its first use reads "Crono Vaporization — Original Account". | `Central_Eye_Broken` |

### 11.8 Pierrot-Glenn — GUILE

| ID | Name | Actors | Tags | Shape / size | Hits | Power | Cost | Effect | Unlock |
|---|---|---|---|---|---|---|---|---|---|
| sleight_of_arm | Sleight of Arm | Glenn | [GUILE][TRICK][BP_STEAL] | SINGLE (reach 6 m) | 1 | 0.6 | 3 MP | Steals 1 BP to the pool; if there is nothing to steal, steals a consumable. A giant coin that says "BP!". | Ch6 |
| guile_feint | Guile Feint | Glenn | [GUILE][TRICK][BP_STEAL] | SINGLE 1.5, reach 3.0 (AoE 1.0 → 0.5 misdirect) | 1 + feint | 0.8 | 5 MP | Steals 1 BP; the target's next action indicator (who it will hit) is shown to the party. +50% after `Cyrus_Cut_Down`. | Ch6 |
| guile_elastic | Guile Elastic | Glenn | [GUILE][TRICK][BP_STEAL][ELASTIC] | SINGLE 1.5 + feint clone | 1 + steal | 0.8 | 6 MP | Steals 2 BP at Lv2+; the clone taunts for 2 turns. Used 12 times on the same boss without defeating it: an Amber Rift (+15 Prismatic, once per cycle) as Pierrot breaks the fourth wall. | Lv 46 |
| swap_face | Swap Face | Glenn | [GUILE][TRICK] | SINGLE | 1 | 0.4 | 6 MP | GUILTY for 2 turns: each of the victim's attacks has a 50% chance to hit one of its own allies. It wears Glenn's droopy eyes. | Ch6 |
| prop_hammer | Prop Hammer | Glenn | [BLUNT][GUILE] | SINGLE | 3 | 0.9 ×3 | 5 MP | 300% squash windup. +1 shave if the target fails the squash test (inflated or rubber targets). +50% vs the Ash-Knight. | Strongman Dummy drop |
| balloon_escape | Balloon Escape | Glenn | [GUILE][RUBBER][AURA] | SELF_AURA 5.0 | — | — | 4 MP | Inflates: squash-dodges to 4 px, immune to [FIRE] for 2 s, and the next BP theft against the party this battle fails. Crono's Smear Dash as comedy. | Ch6 |
| honest_laugh | Honest Laugh (Debt move) | Glenn | [GUILE][AURA] | SINGLE (ally) | — | — | Glenn to 1 HP, Fragile 2 turns | Below 25% HP: self-shatter shows the hollow with the origami frog (+5 Light the first time). +2 BP. The ally's next hit counts as an honest GUILE hit; aimed at Crono's ASTRAL, it breaks the Ash-Knight's theft cycle. | Ch6 |
| prop_cannon | Prop Cannon (ultimate) | Glenn | [BLUNT][FIRE][GUILE] | LINE 12.0 | 1 | 7.0 | 20 MP | The blackened carnival's last gag. | `Cyrus_Left_Hanging` |
| the_last_joke | The Last Joke | Glenn | [GUILE][TRICK] | SINGLE (Vaelos only) | — | — | all party BP (at least 3) | Forces Vaelos to laugh. His chest atom-cluster cracks: his next 3 received hits ignore shields and DEF. His Lavos-Truth aura negates lies, except Glenn's. | Ch9 |

### 11.9 Static — HZ

| ID | Name | Actors | Tags | Shape / size | Hits | Power | Cost | Effect | Unlock |
|---|---|---|---|---|---|---|---|---|---|
| hz_static | HZ Static | Static | [HZ][SIGNAL][WHITE_NOISE] | CIRCLE 3.0 (AoE 1.4) | 8 rapid | 0.25 ×8 | 6 MP | Jammed: no magic casting for 2 turns. Silences Lavos chants; reveals Vaelos's breath. +30% if tuned, against blind. | Ch7 (Lv 52 upgrade) |
| hz_white_noise | White Noise | Static | [HZ][WHITE_NOISE][NOISE] | CIRCLE 5.0 | 8 ticks | 0.25 ×8 | 9 MP | Scrambles enemy plates: the second weakness is hidden for 1 turn (a gamble). The best chip on U6's 12-plate gates. Crono's crack hums and shows the galaxy for 1 s. Lv3 adds CRT-rain stagger and delays shield rebuilds +3 s. | Lv 53 |
| 56k_prayer | 56k Prayer | Static | [HZ][NULL][ERASE] | SINGLE (reach 4.0) | 1 | 3.8 | 12 MP | Hiss screams: +15% damage per debuff on the target. Each hit on Vaelos adds an Anti-Vaelos stack (−5% DEF for the battle). | Lv 54 |
| red_bike_ghost | Red Bike Ghost | Static | [HZ][FIRE] | LINE_PIERCE 14.0 | 1 dash | 2.0 | 10 MP | Knock-Static: the target steps at 12 fps under U2 clay rules for 2 turns (gauge 0.85×, actions hitch 0.5 s). Leaves an oil-fire line that becomes an Ash Field for Krona. | Lv 56 |
| akira_in_utero | AKIRA IN UTERO (ultimate) | Static | [HZ][SIGNAL][LAVOS] | screen | — | — | 30 MP | The jacket opens, Hiss blooms, full-screen flare: every enemy gains [HZ] as a weakness for 10 s, and for those 10 s the party hears Vaelos's true voice, the Crono atom crying under the Lavos roar. | Lv 60 |

### 11.10 Omega-Spekkio — NULL

| ID | Name | Actors | Tags | Shape / size | Hits | Power | Cost | Effect | Unlock |
|---|---|---|---|---|---|---|---|---|---|
| null_omega | NULL | Omega-Spekkio | [NULL] | CIRCLE 3.0 | — | — | 8 MP | Strip tags, resistances and buffs for 2 turns (allies in the circle too). On a weaknessless target, create one fake weakness from the 42-entry pool for 2 turns. | joins |
| miura_fold | Miura Fold | Omega-Spekkio | [NULL][FOLD] | two enemies | — | — | 10 MP | The two share one HP pool for 2 turns; on the snap, everything dealt to the pool is split back between them as true damage. | joins |
| lotus_reverse | Lotus Reverse | Omega-Spekkio | [NULL][AURA] | SINGLE (ally) | — | — | 14 MP | Unfolds an ally 3 s back: cancels a KO from the last 3 s, refunds MP spent in them, cleanses; leaves a paper decoy that draws one enemy action. | joins |
| gold_leaf_severance | Gold Leaf Severance (ultimate) | Omega-Spekkio | [NULL] | battlefield | — | — | 3–5 Gold Leaf stacks | Cuts the timeline into a one-turn washi pocket where only NULL exists: every enemy is TRUE NULL and every party hit deals true damage. Vaelos is locked out (his next action is skipped). | joins |

### 11.11 Vaelos (child) and Marle (guest)

| ID | Name | Actors | Tags | Shape / size | Hits | Power | Cost | Effect | Unlock |
|---|---|---|---|---|---|---|---|---|---|
| kintsugi_mend | Kintsugi Mend | Vaelos (child) | [AURA][FERRO][VITREOUS] | SINGLE (ally) | — | heal 1.0 | 6 MP | Restores HP and max-HP ceiling with a gold fill. On Crono: +2 integrity once per battle; can mend a PEAK crack. | Ending 3 |
| porcelain_memory | Porcelain Memory | Vaelos (child) | [NULL_LEARNING] | copies the last party shape used | 1 | 0.5 | 4 MP | Adds the weakness tag he is holding to everything it touches. | Ending 3 |
| null_spoon_hold | Null Spoon HOLD | Vaelos (child) | [NULL_LEARNING] | SINGLE | 1 | 0.1 (no damage) | 3 MP | He steadies the spoon instead of swinging it: places a weakness tag he has learned on the target for 2 turns. It counts as real for shaving and for the 2.0× multiplier. | Ending 3 |
| light_bolt | Light Bolt | Marle | [BOW][LIGHT] | SINGLE | 2 | 0.9 ×2 | 4 MP | Removes [LIGHT]-keyed plates in the Prologue. | Prologue |
| ward | Ward | Marle | [LIGHT][AURA] | SINGLE (ally) | — | heal 0.8 | 5 MP | Heals and halves the ally's next hit taken. | Prologue |
| vitreous_arrow | Vitreous Arrow | Marle | [BOW][VITREOUS] | SINGLE | 2 | 1.0 ×2 | 5 MP | Glass bolts from Vesper. | ending chapters |

### 11.12 Dual Techs

| ID | Name | Actors | Tags | Shape / size | Hits | Power | Cost | Effect | Unlock |
|---|---|---|---|---|---|---|---|---|---|
| eclipse_x_strike | Eclipse X-Strike | Crono + Krona | [ASTRAL][RUIN][CROSS] | CROSS 4.0 / 4.0 (AoE 1.3) | 2 | 2.0 | 3% + 8 MP | The crossing point erases one buff and one plate. +30% in U1's Crimson Night. The screen splits watercolour and sumi-e: the same stance mirrored. | Ch2 |
| overclocked_short_circuit | Overclocked Short-Circuit | Crono + Krona | [ASTRAL][RUIN][VOLT] | LINE_PIERCE 10.0 that stops at the first non-metal | 3 | 1.0 ×3 | 2% + 6 MP | Arcs through metal without touching what is behind it (the Weaver's antennae, never her tank). Magnetized targets: +1 shave. | Ch3 |
| solar_railgun | Solar Railgun | Crono + Cassia-09 | [ASTRAL][FERRO][BEAM] | LINE 18.0 (width AoE 1.1) | 3 rail + 1 burn | 1.2 ×3 | 3% + 10 MP | Cassia's induction barrel fires Crono as a human comet. A Break leaves a Venn residual (watercolour + amber pool). +20% if Crono is cracked and Cassia consenting. | Ch3 |
| reinforced_guard | Reinforced Guard | Crono + Cassia-09 | [ASTRAL][FERRO][GUARD][AURA] | SELF_AURA 4.0 | — | — | 2% + 8 MP | Reinforced: Crono's Time Debt accrual −50% for the next 3 gate jumps. The first Venn Double. | Ch3 (after the Mercy branch) |
| iron_maiden_scroll | Iron Maiden Scroll | Krona + Cassia-09 | [RUIN][FERRO][ENTOMB] | CAGE 2.5 | 5 | 1.8 | 8 MP + 8 MP | A sumi-e scroll unfurls and clay legs hammer the iron maiden shut; Krona shreds it. Ash and amber DoTs inside are doubled. +25% if it closes on a Vaelos minion. | Ch3 |
| time_mines | Time Mines | Sera + Cassia-09 | [TACHYON][FERRO] | 3 mines at enemies' last-turn-start positions | 2 per mine | 0.6 ×2 | 5% sol + 6 MP | Mercury orbs record ghost positions; an enemy that returns to its spot, or is Rewound to it, detonates the mine. | when Sera fights beside Cassia-09 |
| fake_family_photo | Fake Family Photo | Crono + Sera | [TACHYON][ASTRAL][AURA] | SINGLE (Crono) | — | — | 5% sol | Crono must be in his galaxy state: Sera steps into his cracked chest. Heals him to 60% of max HP and clears 20% of his Battle Strain. | Ch1 (condition) |
| solar_winds | Solar Winds | Crono + Xyloph | [ASTRAL][MYCELIA][WIND] | CONE 7.0 / 10.0 (AoE 1.5) | 3 gusts | 1.5 | 3% + 6 MP | Moebius wind lines carry watercolour light along the tether vines. +35% with Sunlight Stacks. Wakes seed bridges. | Ch4 |
| triangulation | Triangulation | Crono + Xyloph | [ASTRAL][MYCELIA][SWORD] | LINE_PIERCE 8.0 along a tether | 1 | 2.4 | 3% + 6 MP | Crono dashes along Xyloph's tether: a guaranteed crit and +1.2 s Break. Stabilizes his galaxy core at 20% (the endgame core-lattice key). | Ch4 |
| spore_rail | Spore Rail | Xyloph + Cassia-09 | [MYCELIA][FERRO][SEVER] | LINE 14.0 × 1.0 (AoE 1.0 → 2.0 sprout) | 2 rail + 4 spores | rail 1.4 ×2, spores 0.3 ×4 | 6 MP + 6 MP | Needs an active tether: severed tethers become shrapnel (+2 shave) and their stored shared damage releases as an AoE heal; a walkable vine rail grows along the line. +20% if tethered. Cutting a hostile matriarch's tether: Predator lean. | Ch4 |
| mycelia_time_lapse | Mycelia Time Lapse | Xyloph + Sera | [MYCELIA][TACHYON][LIFE] | SELF_AURA 4.5 | 2 | 0.4 ×2 | 6 MP + 5% sol (refunded) | Spore ticks 300% faster; shaves nothing; Break +1.5 s. The three-phase-boss tool. | Ch4 |
| vitreous_refraction | Vitreous Refraction | Vesper + Sera | [VITREOUS][TACHYON][PRISM] | SPLIT CONE 6.5 / 9.0, 7 beams (AoE 1.7 rainbow floor) | 7 | 0.6 ×7 | 6 MP + 5% sol | Stained glass splits a tachyon ghost into seven colours, one per universe shader; the cat pounces each beam. +25% if the light passes through a tether. Every hit carries both [VITREOUS] and [TACHYON] (the Goyama Daimyo's seal). | Ch5 |
| refraction_needle | Refraction Needle | Vesper + Sera | [TACHYON][VITREOUS][PIERCING] | LINE 15.0 split into 3 lines | 5 | 0.5 ×5 | 6 MP + 5% sol | Up to 12 shave on a target weak to [TACHYON][VITREOUS]. Triple bell. | Ch5 |
| chrono_prism | Chrono Prism | Vesper + Crono (+ Schala's cat) | [ASTRAL][VITREOUS][TACHYON] | CIRCLE 3.0, placed by hand during a 4 s time stop | 4 | 0.5 ×4 | 8 MP + 4% | Time stops for 4 s of real time; the player places the caustic. +4 shave. Requires Crono ≤ 60%. Three elements: matches [PRISMATIC]. The Luminaire + Vitreous fusion. | Ch5 |
| prismlight_salvo | Prismlight Salvo | Vesper + Cassia-09 | [VITREOUS][FERRO][PRISM] | LINE 10.0 | 6 | 0.5 ×6 | 6 MP + 6 MP | A refracted rail the cat aims; Ferro Graviton shards doubled. On a target weak to [VITREOUS][FERRO] it reveals the U4 secret chest. | Ch5 |
| ash_graveyard | Ash Graveyard | Krona + Vesper | [RUIN][VITREOUS][LIGHT] | CIRCLE 4.0 | 3 | 0.6 ×3 | 7 MP + 6 MP | Ruin and light paradox: Ash ground becomes a stained-glass caustic floor that heals allies 3% per 2 s. Strong vs the Arch-Curators. | Ch5 |
| bloom_crown | Bloom Crown | Xyloph + Vesper | [MYCELIA][VITREOUS][LIFE] | SELF_AURA 3.0 around both | 3 | 0.5 ×3 | 6 MP + 6 MP | Grows a Saurian canopy: +1 Sunlight Stack every 5 s for 15 s; light through it heals 2% per tick. | Ch5 |
| masque_feint | Masque Feint | Glenn + Vesper | [GUILE][VITREOUS][MASQUE] | SINGLE | 1 steal + 1 reflect | 1.2 + mirror | 5 MP + 6 MP | Steals one buff; the stained-glass undermask stores the target's next attack and reflects it. +40% vs bosses (the stolen face cracks). Both porcelain, different voids. | Ch6 |
| guilt_halo | Guilt Halo | Glenn + Crono | [GUILE][ASTRAL][AURA] | SELF_AURA 3.5 around Crono | 2 | 0.5 ×2 | 5 MP + 2% | Steals 1 BP on a Break; Crono's ceiling costs halve for 1 turn (the doll holds). | Ch6 |
| honest_stage | Honest Stage | Crono + Glenn | [ASTRAL][GUILE][VITREOUS] | LINE_PIERCE 14.0 | 2 | 0.9 ×2 | 3% + 5 MP | Cuts threads and catches a puppet balloon. +4 shave. Requires Crono ≤ 60%, his crack visible. Overlapping a CIRCLE and a SELF_AURA it becomes a Venn Double: the copy's admission. | Ch6 |
| ashen_bash | Ashen Bash | Crono + Glenn | [ASTRAL][BLUNT][GUILE] | SINGLE | 3 | 0.7 ×3 | 2% + 4 MP | One sword stroke, two hose-arm prop blows. Locked if the Atrium dummy was Salvaged. | Ch6 (teased Ch1) |
| mercy_leap | Mercy Leap | Sera + Glenn (or Vesper + Glenn) | [TACHYON][GUILE][RUBBER] | LINE 9.0 | 2 (3 with `Glenn_HoseArm_Accepted`) | 0.8 ×2 | 5% sol + 4 MP (6 MP for Vesper) | Glenn's hose arm flings Sera along the line; she lands behind the last target (a free reposition). The hidden third hit is the origami frog leaping as a projectile. With Vesper in Sera's place the leap refracts through his caustic pool into a seven-colour prism burst [VITREOUS] that heals the party 15% and clears Grief-Resonance; +50% healing once the Schala-cat is fully inside the glass. Locked if the dummy was Salvaged. | Ch6 (teased Ch1) |
| ruin_elastic | Ruin Elastic | Krona + Glenn | [RUIN][GUILE][ELASTIC] | SINGLE (reach 6.0) | 1 + decoy | 1.4 | 6 MP + 4 MP | Sumi-e ink stretched 300%; the elastic decoy draws the target's next action. | Ch6 |
| omega_annihilation | Omega Annihilation | Sera + Static | [TACHYON][HZ][VOID] | CIRCLE 5.0 (AoE 1.6) | 2 collapse | 2.4 | 10% sol + 10 MP | Tachyon flicker plus white-noise cancellation: silences and rewinds a boss ultimate (cancels its wind-up and sets its gauge to 0). +50% vs Vaelos (brother frequency). A second use in one battle costs Sera another 10%. | Ch7 |
| tachyon_static | Tachyon Static | Sera + Static | [TACHYON][HZ][NOISE] | LINE 12.0 | 4 | 0.6 ×4 | 5% sol + 6 MP | Scrambles the next phase's reveal (the boss's next weaknesses start hidden; the first Break of that phase gets +1 shave per hit). Both actors phase: +50% evasion until their next turn. | Ch7 |
| anachronism_glass | Anachronism Glass | Vesper + Static | [VITREOUS][HZ] | CIRCLE 4.0 | 2 | 0.6 ×2 | 6 MP + 6 MP | 1988 smear frames become solid glass: allies inside gain a Glass Ward (the next 2 hits they take are halved). | Ch7 |
| graviton_whiteout | Graviton Whiteout | Cassia-09 + Static | [FERRO][HZ][MAGNETIC] | CIRCLE 5.5 | 4 | 0.5 ×4 | 8 MP + 6 MP | Magnetic static: no shield regeneration or rebuild for 5 s. | Ch7 |
| solar_railgun_static | Solar Railgun + HZ | Crono + Static | [ASTRAL][HZ][FIRE] | LINE_PIERCE 18.0 | 3 | 1.0 ×3 | 3% + 8 MP | Watercolour smear under cel lines, an intentional style bleed showing Crono's crack. +1 shave per hit if Static is tuned CARRION on the target. | Lv 58 |
| ferro_null | Ferro Null | Cassia-09 + Crono (void echo) | [FERRO][NULL] | LINE 18.0 | 2 (ferro, then null) | 1.0 ×2 | 8 MP + 4% | Shaves 8 on any target and adds +8 Dark. Breaking R-66Y with it in the Phase 2 branch writes `R-66Y_Salvaged`; his mask weeps black oil from then on. | Ch3 (Dark ≥ 40) |
| empress_cannon | Empress Cannon | Krona + Cassia-09 (Bipedal) | [RUIN][FERRO][GUN] | LINE_PIERCE 18.0 | 3 | 1.3 ×3 | 10 MP + 10 MP | The Lavos-Grafted Laser Cannon from R-66Y. Each use +2 Dark (cap +10 per universe). | `R-66Y_Salvaged` |
| origami_requiem | Origami Requiem | Crono + Sera carrying Kami-Ori's crane; Crono + Omega-Spekkio once he joins | [ASTRAL][NULL] | LINE_PIERCE 18.0 × 1.2 | 1 | 2.4 | 3% + 5% sol (3% + 8 MP with Omega-Spekkio) | A watercolour dash along a fold line folds the enemy's past away and leaves a gold field that thaws Ruin 1% per 8 s. Boost Lv3 +1 shave. | `Kami_Ori_Wounds_Kept` |
| time_debt_paid | Time Debt Paid | Sera + Crono | [TACHYON][ASTRAL] | CIRCLE 4.0 | — | heal 40% | 5% sol + 10 integrity | Heals 40%, removes all Glaze Erosion, and with Light grants an auto-revive this battle. A kintsugi mini-game after the battle returns the 10 integrity if completed. | Ch8 |
| porcelain_promise | Porcelain Promise | Crono + Marle | [ASTRAL][BOW][LIGHT] | LINE 10.0 | 2 | 1.0 ×2 | 2% + 5 MP | Mid-fight she checks his wrist for warmth: Crono's next ASTRAL cost is 0. | guest chapters after Act I |
| porcelain_promise_child | Porcelain Promise Child | Crono + Vaelos (child) | [ASTRAL][NULL_LEARNING][AURA] | SELF_AURA 3.5 | — | heal 0.8 | 2% + 6 MP | The child holds the doll's cracked hand while Crono holds his: heals allies inside, clears 5% of Crono's Battle Strain and restores +1 integrity once per battle. | Ending 3 |

### 11.13 Triple Techs

| ID | Name | Actors | Tags | Shape / size | Hits | Power | Cost | Effect | Unlock |
|---|---|---|---|---|---|---|---|---|---|
| ashtear_paradox | The Ashtear Paradox | Crono + Cassia-09 + Krona (blood and oil) or Sera (family) | [ASTRAL][RUIN][FERRO][PARADOX] (Krona) / [ASTRAL][TACHYON][FERRO][PARADOX] (Sera) | CIRCLE 5.5 (AoE 2.0, time stop) | 12 | 3.2 | 3% + 10 MP + 8 MP (or 5% sol) | Blood and oil magnetized into a singularity, struck from opposite timelines: a miniature Big Bang of watercolour gold, sumi-e crimson and liquid metal (the Sera form is the family volley, the Fair theme warped on the gramophone). +50% while Crono's galaxy is open. High Cassia Synergy triggers Lucca's final schematic (Reinforced for 3 jumps). | Krona form Ch3; Sera form after the U2 consent quest |
| first_light_that_never_was | First Light That Never Was | Xyloph + Vesper + Crono | [MYCELIA][VITREOUS][ASTRAL][GENESIS] | CIRCLE 10.0 (AoE 2.5, map-wide light) | 1 genesis | 3.0 (damage and heal) | 8 MP + 8 MP + 4% | What if Lavos never fell: Moebius gouache, stained-glass rose and watercolour bleed make a dawn. Heals the party for what it deals; +100% healing in U3. The Scholar route's U3 true-ending key. **Fragment I** (Crono + Cassia-09 + Xyloph) is available in U3 at 50% power. | Fragment I Ch4; full after Ch5 |
| chrono_laugh | Chrono Laugh (First Light, Fragment II) | Crono + Sera + Glenn | [ASTRAL][TACHYON][GUILE] | SELF_AURA 5.5 | 6 | 2.6 | 3% + 5% sol + 5 MP | Converts a shared shield into individual shields and auto-Breaks the smallest; heals the party 10%. | Ch6 Prismatic (Re-String As Instrument) |
| delta_storm | Delta Storm | Crono + Krona + Glenn | [ASTRAL][RUIN][GUILE][DELTA] | DELTA (edges up to 6.0, AoE 2.0) | 3 × 3 | 2.8 | 3% + 8 MP + 5 MP | Three Crono archetypes: false hero, evil daughter, the jester who took the curse. +30% if all three are below 30% HP. Glenn has two arms for the duration (phantom Cyrus). | Ch6 |
| carnival_of_souls | Carnival of Souls | Glenn + Vesper + Cassia-09 | [GUILE][VITREOUS][FERRO] | SELF_AURA 6.0 (Glenn inflates into the big top) | 3 | 0.6 ×3 | 6 + 6 + 6 MP | Light refracts through the tent's stained-glass panels: +3 BP, which may exceed the cap by 1 until the end of the next ally's turn. | Ch6 |
| washi_hollow_rebirth | Washi-Hollow Rebirth | Crono + Vesper + Glenn | [ASTRAL][VITREOUS][GUILE][AURA] | CIRCLE + SELF_AURA Venn (at Boost Lv3) | — | — | 4% + 10 MP + 10 MP | The three who learned cracks are where light gets in: full heal; every enemy in the Venn loses 25% of its current plates (+25% AoE); a 4-frame Perfect Frame input adds +15% gold-sheen damage to the next hit. | `Kami_Ori_Wounds_Kept` |
| omega_triple | Omega Triple | Omega-Spekkio + Sera + Static | [NULL][TACHYON][HZ][ERASE] | CIRCLE 8.0 (AoE 2.2 origami unfold) | 4 erasures | 3.5 | 10 MP + 5% sol + 10 MP | Erases every resistance of everything inside for the rest of the fight; the party gains NULL SHIELD (20% damage reduction) for the fight. | Final Dojo |
| family_porcelain | Family Porcelain — All Three Fathers | Crono + Sera + Vaelos (child) | [ASTRAL][TACHYON][AURA] | CIRCLE 7.0 + SELF_AURA 4.0 Venn | — | — | 3% + 5% sol + 4 MP | Reinforced: −80% Time Debt for the next 3 jumps; +2 Crono integrity; gold scatter. Light ≥ 60. The True Ending finisher. | Ending 3 / True |
| fake_family_photo_real | Fake Family Photo Real | Crono + Sera + Vaelos (child) | [TACHYON][ASTRAL][NULL_LEARNING][AURA] | CIRCLE 4.0 | — | heal 0.6 | 3% + 5% sol + 4 MP | The photo is real this time, so Crono needs no galaxy state: every ally inside is healed to at least 60% of max HP, Crono's Battle Strain −20%, and the party is Reinforced for the next gate jump. | Ending 3 |
| first_light_child | First Light That Never Was — Child Variant | Crono + Sera + Vaelos (child) | [ASTRAL][TACHYON][NULL_LEARNING][GENESIS] | SELF_AURA 5.5 | 6 | 0.4 ×6 | 3% + 5% sol + 6 MP | The three of them build a block tower that collapses gently. Splits a shared shield or Mycelia pool back into individual shields and auto-Breaks every enemy left at 0; heals the party for what it deals. | Ending 3 |
| promise_across_rust | Promise Across Rust | Doan + Robo + R-66Y's child form (summoned) | [MYCELIA][FERRO][AURA] | CIRCLE 8.0 + SELF_AURA 3.0 Venn | — | — | Sera 5% sol + Crono 2% + 1 BP | Pay debt with care: +3 Crono integrity; plants a permanent garden in the U7 void (Glaze Erosion −15% everywhere). | Seed of Doan grown + `Arris_Dome_Sleeping` + `R-66Y_Rewound` + 3 visits |

### 11.14 Relics that change techniques

| Relic | Source | Effect |
|---|---|---|
| Tungsten Wire Loom Bracer | Atrium Cradle (Prologue) | +10% damage to a target in the first 3 s after its Break. |
| Cobalt Nodachi | Goyama Daimyo | Krona's weapon upgrade; unlocks cobalt_nodachi; sky stain marks hidden Chronoslip rifts (exploration). |
| Vaelos Tooth | Goyama Daimyo | Whispers in the clean young Crono voice; +5% ASTRAL damage vs Lavos-spawn. |
| Grief Filter | R-66Y | Immunity to MP drain (Grief) in the Geno-Foundry; later, halves Grief everywhere. |
| Charred Laurel (pristine / blackened) | Cyrus | Pristine: Sera can Chronoslip without an anchor in burn zones (needed for the U6 rain escape and the final 1999). Blackened: −1 BP per 15 s in U6, unlocks Prop Cannon. |
| Bubble Lens | Arch-Curator Echo | U4 traversal without the drown timer; defeats the cathedral adds. |
| Vapor Memory Core | Juvenile Matriarch (Prismatic) | 1% of Crono's vaporized atoms, cached by the U6 net: a lore relic required for the Vaelos re-parenting ending. |
| Kintsugi Brush | Vaelos | Kintsugi repairs (lotus ponds, Kintsugi Mend, Time Debt Paid's mini-game) restore 50% more integrity. |
| Lucca's Last Schematic | Cassia-09 Extract | Any ally can cast Reinforced Guard's effect on Crono. |

## 12. Status Effects and Hazards

### 12.1 How statuses work

- **Durations** are in seconds of battle time (paused in Sync Hold and during actions) or in **turns**, meaning the affected unit's own actions. "2 turns" on an enemy lasts until it has acted twice; on Sera's Causal Collapse it lasts as long as her gauge takes to fill twice.
- **Stacking:** a status re-applied refreshes its duration unless the table gives stacks.
- **Resistance:** each status application rolls against the target's status resistance (LUK × 0.1%, max 30% for the party; enemies list immunities instead). Telegraphed hazards and fields never roll: standing in them is the choice.
- **Bosses** take half duration from SLOW, Chrono Lag and Knock-Static and are immune to Confuse, GUILTY and Time Stop unless their entry says otherwise.
- **Sera never touches the ground.** Floor hazards, floor fields and floor terrain do not affect her, for good or ill.
- **Statuses are drawn as style degradation, not icons:** BLIND is the canvas fogging (VHS tracking, an ink blot, white noise), SLOW is mercury in the joints and stepped frames, Ruin is cracks and black oil from the right eye. Small text tags float only while the codex page is open.

### 12.2 Debuffs

| Status | Effect | Sources | Cleanse |
|---|---|---|---|
| **VHS Fog / BLIND** | −30% accuracy; the second weakness on every plate is hidden as `[?]` again; ranged [BOW][GUN] hits lose 1 shave; the Turn Bar glitches with tracking lines. | Omen Crow, Neon Billboard Mimic, Arch-Curator screen tears, Cathedral Choir Jelly, U2 Static Fog, spills in the Vaelos Child playground | Crono's gold light (Astral Smear Dash, Astral Field) clears 3 m for 10 s; Vesper's lens flash; campfire |
| **Ink Blot (BLIND 60%)** | −60% accuracy and enemy telegraphs are hidden for 3 s. | A mistimed Ens Parry against U1 ink enemies; Ink-Eater left unchecked for 12 s | Cobalt Wash; moving through gold kirie (U7) |
| **White-Noise BLIND** | The party cannot target anything (−100% targeting) unless Static is tuned; evasion +30% while blind. | Arriving in U6; Faraday Lull; White Noise bursts | Static's Tune (SIGNAL for allies during Faraday Lull) |
| **Mercury SLOW** | Gauge fill 0.5× and movement 0.5×. A second stack keeps 0.5× and adds a 0.5 s hitch to every action (12 → 6 fps stepped). Max 2 stacks. | Mercury Leakers, Deepsea choirs, Vaelos's mercury rain, Cassia-pattern units, Astral Smear Dash's galaxy trail (on enemies) | Cassia-09's FERRO pulse heats the joint; polarity skate; an ASTRAL burn |
| **Grief** | −2 MP per 10 s per stack (max 3). While the afflicted character's MP is under 50%, they cannot spend more than 1 BP on an action (Boost chains break). | Ruin Eels, the Shogun's Memory Flame, Gato-Ruin heavy punches, Grief-Resonance zones | Harmonizing a gramophone record; Astral Field; an amber shard from a Slag-Mite spill (1 stack); the Grief Filter halves it |
| **Ruin** | −15% max-HP ceiling per stack, max 3 (−45%). Persists after battle until a camp, or until thawed. At 2+ stacks the Prometheus Core cannot revive that character. At 3 stacks Crono shows his PEAK crack at full HP. | Drowned Zealians, Bekkler Prime, Mammon Conduits, Foundry oil, Vaelos Phase 3, U5 Ink Boil | Divinity Field and lotus ponds thaw 1% per 8 s; the Arris Dome repair bench (U2); the Mycelia Matriarch's seed; camp |
| **Oil-Blight** | −1 BP from the shared pool every 15 s and no Ultimates while it lasts. A party-wide condition, not a character status. Lasts until the battle ends. | Oil-Blight Harlequins, Mammon Conduits, Gatling hits, marrow spray, the Daimyo's Oil Mother | none in battle; the Grief Filter grants immunity in U2; the Atrium fountain washes the oil-soak off between battles |
| **Corroded** | −50% healing received (−10% DEF too when applied by a Lv2 RUIN Boost). | Krona's Crimson Seppuku, RUIN Lv2 | expires (3 turns) |
| **Magnetized** | The next action hitches 0.5 s; metal-tagged targets also lose 10% P.Def. | Ferro Graviton, Gatling Arm, Mercury Pulse, the Chrono Ledger's sound rings (party) | expires (2 turns) |
| **Displaced** | Gauge fill 0.85×. | ASTRAL Lv2; Luminaire | expires (2 turns) |
| **Probability Lock** | The next action rolls twice and takes the worse result (accuracy, damage variance, status chance). | TACHYON Lv2 | expires |
| **Spore Tag** | Break lasts +1.2 s; consumed by Photosynthetic Burst for healing. | Tether snaps, MYCELIA Lv2, Mycelia Tether ticks | consumed |
| **Refracted** | 20% of the damage it deals splits away as a harmless prism. | VITREOUS Lv2 | expires (2 turns) |
| **GUILTY** | 50% chance each of its attacks hits one of its own allies. | Swap Face, GUILE Lv2 | expires (2 turns) |
| **Jammed** | Cannot start a wind-up or cast magic for 2 turns. | HZ Static, HZ Lv2 | expires |
| **Stripped** | Loses tags, resistances and buffs (or one resistance from NULL Lv2) for 2 turns. | NULL | expires |
| **Confuse** | 30% chance each action targets a random battler. | Hiss Larva Drone's White Noise | a hit |
| **Time Stop** | Gauge frozen for 3 s. | Tracking Hold (Matriarch, Hiss drones) | expires |
| **Chrono Lag** | Gauge fill 0.75×; the victim's animation drops frame rate locally. | Vaelos Echo (Prologue) | expires (6 s) |
| **Knock-Static** | Steps at 12 fps under U2 clay rules for 2 turns: gauge 0.85×, every action hitches 0.5 s. | Red Bike Ghost (both sides) | expires |
| **Silence** | Techniques sealed; Attack, Guard, Items and commands still work. | Azar's procession (5 s), Gene Scribe Breaks (on itself, 15 s), Divinity Breaks | expires |
| **Polished Relic** | One random technique of one ally sealed for 30 s. | Azar, if not Broken within 20 s of Phase 1 | expires |
| **Fragile** | Damage taken ×1.5. | Fractured Lens, Honest Laugh (self) | expires (2 turns) |
| **Sticky Ash** | Crono's ASTRAL hits shave 1 less. | Ash-Cotton Swirl | Polish (any ally's Guard action next to him) |
| **Laugh Track Drain** | −1 MP per 8 s to the whole party. | Ticket-Golem Barker, the Ash-Pit | Break the Barker; leave the pit |
| **Ash Inhale** | SLOW (1 stack) and BLIND 20% (−20% accuracy). | U5 ashfall outside the music radius | a Glenn steal rewinds it off the whole party |

### 12.3 Buffs and states

| State | Effect |
|---|---|
| **Concerned** | Healing on Crono ×1.5; his Confession dialogue tree locked until camp. Once per battle, when an ally with line of sight sees his wrist seam in the galaxy state. |
| **Reinforced** | Crono's Time Debt accrual −50% (−80% from Family Porcelain) for the next 3 gate jumps. |
| **Ens ring** | +1 shave on the next damaging hit; Crono's Time Debt costs nulled for 5 s. |
| **Glass Ward** | The next 2 hits taken are halved. |
| **Ruin-infused** | The next hit ignores DEF. |
| **Ward** | Marle's: the next hit taken is halved. |
| **Token Duplicate** | An immediate second turn; it costs nothing and copies the ability and its crit. |
| **Phased (Causal Collapse)** | Sera only: untargetable, cannot act, bar removed for 2 turns; party synergy 0.85. |

### 12.4 NULL SHIELD and TRUE NULL

- **NULL SHIELD** (the Final Dojo's gift; a toggle on any ally): the ally gives up their vulnerabilities and resistances and takes a flat 20% less damage from everything.
- **TRUE NULL** (Kami-Ori's and Empress Vaelos's Offering, accepted): the ally's tags are erased permanently for the cycle, shown as `[----]`. They have no vulnerabilities and no resistances; their hits deal flat damage (no 2.0× weakness multiplier, no 0.5× from resists, no Boost Lv3 shave bonus); they cannot take part in Dual or Triple Techs; NULL cannot strip them (in Kami-Ori's Final Void, a disadvantage). Two TRUE NULL allies plus two who are not is the balance the Seventh Arm demands. The Null Erasure ending wants the whole codex erased.

### 12.5 Fields

| Field | Effect |
|---|---|
| **Divinity Field** | +1 temporary plate every 5 s to whoever owns it (enemies in U3; the party from Xyloph's tech, Sera as Warden, the lotus ponds), capped at 20% of max HP as temporary shield; thaws Ruin 1% per 8 s; when its owner's foe Breaks inside it, that foe is silenced 15 s; banked XP converts at 100% here (the Bekkler shop converts at 50%). A crystal-bowl tick and a hum every 5 s. |
| **Predator Field** | Divinity corrupted: heals only enemies (+1 plate per 5 s), thaws only enemy Ruin, converts nothing for the party. Empress Heir; `Azar_Predator` U3 revisits. |
| **Mycelia net** | 15% shared damage among tethered allies; status ticks and cleanses crawl along it at 0.3×. |
| **Ash Field** | Enemies inside: 0.5× movement and −1 temporary plate per 2 s. Krona feeds on it. Cobalt Nodachi cuts it into a clean line. |
| **Golden watercolour patch** | Allies inside regain 2 MP per 5 s; Crono's first cast from inside costs no Battle Strain. (ASTRAL burning ink.) |
| **Caustic floor** | Hits passing over it gain [VITREOUS]. Ash Graveyard's version also heals 3% per 2 s. |
| **Spore mat** | Allies inside regain 2% HP per 2 s; tethers inside never snap. |
| **Amber pool** | Enemies inside are Mercury SLOWed; Cassia-09 recharges her orb standing in it. |
| **Static field** | Nothing inside can be untargetable. |
| **White blank** | No tags, fields or hazards inside for 2 turns. |

### 12.6 Universe hazards

Every universe has its own suite. Hazards are part of the battle plane wherever the fight happens.

**U0 — Atrium Horologe and Truce (Lv 1–4).**
- *Ink footprints:* Krona's bleeding RUIN leaves footprints that last 6 s in the field and 30 s in the Atrium (wayfinding), and near the U4 light puzzle. They are the minimap: the passive Ink Path.
- *Chronoslip residue:* Sera's ghost leaves U1 ink puddles that drop anyone walking through them to a 24 fps step (movement 0.75× for 3 s). It teaches frame rate as lore.
- *The Fracture Gate:* the Atrium exit opens only when Crono pays Time Debt (see [14.2](#142-prologue-atrium-cradle)).
- *Debtling ink blooms:* where Crono stands in his galaxy state, 6 s blooms feed Debtlings.
- The Atrium itself is safe; the 999 Shard Doll's lab leaks Atrium Echoes.

**U1 — Crimson Shogunate (Lv 5–11).**
- *Ashen Morning / Crimson Night:* an 8-minute cycle; enemies spawn only at night. `Goyama_Incinerated` locks U1 to Crimson Night.
- *Wet ink:* every slash leaves a stroke that lives 2 s, then bleeds 15%; anything touching a wet edge takes an ink DoT.
- *Ink blot:* see Ink Blot above. Cured by Washi Reveal's Cobalt Wash.
- *Unpainted paper:* invisible but harmless; painted (Cobalt Wash or any [INK] hit) it can be fought.
- *Oil veins:* Crono's wrist seam cracks wider near Lavos oil: each of his turns ending within 2 m of a vein costs him 1% Battle Strain (his copy reacting to the original's atoms in the oil).
- *Four bridge shrines:* ash-ronin force held parries; the shrines teach Ens Parry before Goyama.

**U2 — Clockwork Ossuary (Lv 12–22).** Player stats cap at 20 here; enemies scale to Lv 35 for sequence-breakers.

| Sub-zone | Lv | Hazard | Rule |
|---|---|---|---|
| Proto-Dome Slag-Yards (hub) | 12–14 | VHS Static Fog | BLIND in the fog; cleared 10 s by Crono's ASTRAL gold light. |
| Spine-Highway (Lab 32 ruins) | 14–16 | 12 fps frame-traps | Mercury pools: SLOW and a 6 fps stepped look; Johnny teaches Sync Hold here ("Hold thinking, skid kid!"). |
| Choir of Arris Dome | 16–18 | Grief-Resonance | Weeping porcelain husks drain 2 MP per 10 s and blur the far plane; harmonize or let Crono take Sera's hand and pay 5% solidity to clear it. |
| Geno-Foundry and the Conveyor | 17–19 | Magnetic crushers | Syringes hammer every 3 s (the world metronome); conveyors reverse under Cassia-09's polarity swap. |
| Mother Brain's Dyson-Cage | 19–22 | Boiling Lavos-Marrow | Stepping on a marrow tile applies Ruin Decay and Oil-Blight at once. |

**U3 — Saurian Eden (Lv 21–30).**
- *Divinity Field* on enemies within 40 m of temples and in moonlight (see Fields). Crono, entering one while hairline or worse, takes 1.2% Battle Strain per minute of battle time unless Xyloph's Mend refunds it.
- *Pollen Haze:* gauge fill 0.8× unless the character is tethered (inside the Mycelia aura) or Xyloph is in the active party.
- *Living Papyrus:* sprinting within 5 m of papyrus walls closes the flowers for 12 s and spawns Sumi beetles. Reverence, not speed.
- *Mycelia Shared pool:* party-wide in U3 (see [Xyloph's kit](#105-xyloph--mycelia)); the Fake Carrier Burn fires if more than 6 orbs burn in 10 s.
- *Thermals:* gliding costs 1.5 Shared per second; each glide chain costs Crono 0.3% Camp Strain.
- *Spore Tag:* Breaks last +1.2 s on tagged targets.
- *Moon pulse:* the frozen Lavos moon pulses every 12 s; Worship Gaze (3 s idle looking up) cuts the 18 Hz drone to 0.5 s of silence and counts toward Azar's secret phase.
- *Moon Meditation:* Sera's only translucency recovery before U7 (see [Sera's kit](#102-sera-17--tachyon)).

**U4 — Drowned Cathedral (Lv 31–40).**
- *Crush timer:* outside a light beam, 15 s of safety, then 5% HP per second; the screen low-passes and lead cracks tink. Safe light pools shift as the sun angle advances with each puzzle solved.
- *Breath:* the meter is reverb wetness; Jellyfish Lanterns spared and polished give +10 s.
- *Refraction BLIND:* standing in a broken-glass caustic for 3 s: VHS Fog's rules with a stained-glass look.
- *Puzzle rewinds:* more than three Sera rewinds on one caustic puzzle cost Crono 8% Camp Strain.
- *Grief-Resonance (28 Hz):* within 6 m of a Mammon Siphon Tendril.
- *Panes:* the prism split (see [9.4](#94-the-prism-split-u4)).

**U5 — Carnival of Ash (Lv 41–50).**
- *The 22-minute loop:* the fair loops; stalls burn in a different order each loop (Gacha, Wrestling, Sweetcorn Pope, Mirrors).
- *Puppet stages:* thread cuts delay 1.5×; six cuts collapse the stage into the Ash-Pit (Laugh Track Drain).
- *Ash Inhale:* outside the music radius (see Debuffs); for Crono it also costs 0.6% Camp Strain per minute.
- *Rubber-Hose Ink Boil:* boiling ink puddles: each 5 s standing in one adds a Ruin stack.
- *Ashfall (Cyrus's arena):* outside the safe circle (80% of the stage), 8% max HP per 15 s.
- *Hit cards:* "BAM!" and "POP!" cards are 12 px collision for 1 s; a POP! wall stands 3 s and blocks ash and projectiles.
- *Performance:* Crono can fake a laugh (+1 BP, +2% Camp Strain) or refuse to perform for the Heckler (the first refusal costs 10% Camp Strain: his first dignity payment).

**U6 — 1999 A.D. Singularity (Lv 51–60).**
- *Conductivity:* rain exposure fills a meter. High conductivity shows wire-mesh enemy routes and ICE patrol paths and lets the party walk through neon light-walls, but drains 2 MP per second; standing under a tarp vents it.
- *VHS BLIND:* see White-Noise BLIND; rain density sets the encounter rate.
- *Neon Bloom stealth:* near the Isolator's nest, neon pulses solid for 2 s at a time; moving outside a bloom halo spawns a Pachinko ICE.
- *ASTRAL in the noise:* every ASTRAL cast while the party is BLIND costs Crono an extra 0.4% Camp Strain (the collarbone line).
- *Clinic Debt:* the doctor trades 5 integrity for a memory (Sera's first word on a CRT).

**U7 — Bone-Tree of Eternity (Lv 61–70).**
- *Glaze Erosion:* each battle costs Crono 2% Camp Strain (max-glaze), up to 30%; the screen desaturates to 0.85 and gold flakes fall from the plane.
- *Lotus ponds:* Divinity Fields where the kintsugi mini-game repairs 1 integrity (and 1 of Sera's Debt) per 8 s, +1 temporary plate per 5 s, thaws Ruin.
- *Negative space:* only gold kirie butterflies mark solid ground; a fall returns the faller to the last checkpoint fleck and adds 5% Glaze Erosion.
- *The 70% white rule:* Ink-Eaters break it and must be cleared.
- *Galaxy caustics:* below 20% HP, Crono's galaxy throws caustics that solve the Crown puzzle: broken, not useless.

**U8 — Vaelos Heart (Lv 71–80).**
- *Prismatic Myopia:* below Prismatic 45, vision −40% and the Turn Bar shows wrong frame-rate numbers; Sera standing still for 2 s syncs it for 10 s; [BOW][GUN] lose 2 shave.
- *Time Debt Inheritance:* Crono's generic ASTRAL cost rises from 0.4% to 1.2% per cast (techniques with a listed cost pay that plus 0.8%); Wire Loom Mend restores only 0.6; after four casts his PEAK crack shows even at full HP.
- *Borrowed Future Echo:* while Sera's solidity is below 40, allies within 6 m of her lose 3 MP per 5 s. Not curable except by the True Ending.
- *Lavic Filial Field:* during Vaelos's Phase 1, every attack aimed at the party redirects to Crono while Sera is under 40% HP.
- *Time Debt Well:* whenever Crono drops below 20% HP, his galaxy drains into the well and heals Vaelos 5%.
- *Zero gravity:* in the Central Cradle the TacticalPositioner uses ShapeCast spheres; only gold leaf butterflies are solid.
- *Heart alignment:* Sera's solidity is set to 60 on entering.

**Ending spaces (U9).**
- *Predator Field* (Empress Heir).
- *Mammon Conduit* (Empress Heir): the shattered Crono at the arena centre; allies within 5 m lose 3% max glaze per 8 s and their temporary shields.
- *Ruin scaling* (Porcelain Silence): the Ruin cap lifts to 10 stacks; the 10% ceiling floor still holds; slipping through the Mammon Siphon costs 5% solidity per second.
- *White Void* (Null Erasure): 95% white, nothing lit but gold flecks; Dual Techs disabled.

## 13. Enemy Codex

Every enemy in the game is listed here by universe, in the order the party meets them. Bosses, mini-bosses and field bosses have their full phase breakdowns in [Bosses](#14-bosses); they appear in these tables only as one-line pointers.

### 13.1 How to read an entry

| Column | Meaning |
|---|---|
| ID | E01–E22 are the original Extreme Codex entries; E23 onward come from the chapter rosters. |
| Lv | Authored level; regular enemies scale with the band ([Progression](#15-progression)), bosses never do. |
| Shield | Plates at full; `keyed` plates follow [5.6](#56-keyed-plates); `+` notes regeneration or adds. |
| Tags | What it is made of and attacks with (ally resistances and Canvas Clash read these). |
| Weak | Each listed tag a hit carries counts once toward the shave and makes it a weakness hit (2.0×, 2.6× at Lv3). The second weakness shows `[?]` until revealed. |
| Resist | 0.5× damage; also *nullifies shave*, *immune* (0) and *absorbs* (heals). |
| Lean | The affinity it feeds when resolved its signature way: **L** spared or repaired, **D** salvaged or incinerated, **P** resolved by a paradox (a Dual, an Amber Rift). +1 each, capped at +5 per affinity per universe; the big swings are story choices. |
| Behaviour · Break | What it does and what changes when it Breaks. |

Original Extreme Codex shields (a 30–400 scale) are divided by 20 and rounded half up; the originals are in [Appendix A](#appendix-a-audit-notes). Who supplies each weapon and world tag is in [9.2](#92-weapon-world-and-mode-tags).

### 13.2 U0 — Atrium Horologe and Truce (Lv 1–4, watercolour 60 fps)

The home universe teaches the plate. Prologue enemies are memories leaking out of the Guardia Atrium kitchen; Chapter 1 enemies are Atrium Echoes that leak out of the 999 Shard Doll's training lab. Atrium Echoes rescale to the party's level every time the party returns, and several carry weaknesses the party cannot hit yet. That is deliberate: the lab is a place to come back to and finally shave what was unshaveable.

| ID | Enemy | Lv | Shield | Tags | Weak | Resist | Lean | Behaviour · Break |
|---|---|---|---|---|---|---|---|---|
| E23 | Dust Mote Cluster | 1 | 1 | [LIGHT] | [WIND] | — | L | Orbits in the circle of Crono's seven porridge stirs. The kitchen shutters are a [WIND] operand: opening them during the fight shaves it. Break: disperses as a watercolour wash. |
| E24 | Porcelain Shardling | 1 | 2 | [SWORD] | [FIRE][LIGHT] | — | D | Spawns from Crono's crack and mimics his idle. Break: leaves a tungsten bracer scrap (crafting). |
| E25 | Ashen Spoon (U1 bleed) | 2 | 2 keyed: ice plate → [FIRE], ink plate → [SWORD] | [ICE][DARK] | [FIRE][SWORD] | — | P | Sumi-e brush creature, 24 fps judder. Tutorial for ordered plates: the ice plate must fall before the ink plate. |
| E26 | Vaelos Echo — In Shadow | 2 | 2 | [DARK] | [LIGHT][TACHYON] | immune to all hits that are not Sera's | P | Intangible; only Sera's hits land. Inflicts **Chrono Lag** (see [Status Effects](#12-status-effects-and-hazards)). |
| E01 | Trance Bellkeeper | 3 | 3 | [BLUNT][SOUND] | [BLUNT][TIME_DEBT] | — | L | Patrols the battle plane, pauses, rings its bell: every gauge on the field fills −10% for 6 s. If Sera is within 4 m it offers lore about the Bekkler serial instead of attacking. Porcelain crack on the jawline only. Break: frozen mid-pull, the bell becomes cover that chimes when hit. |
| E03 | Gato-Ruin Porcelain | 3 | 3 | [BLUNT][RUIN] | [BLUNT][VOLT] | — | D | Atrium training robot in a carnival punch loop at 24 fps; its chest plate reads "Property of Belthasar — Bekkler Assembly — 1999/2300 — Serial: Crono-41". A full Bekkler doll variant that cracks at 60% like Crono. Heavy punch inflicts Grief. |
| E04 | Debtling | 3 | 2 | [RUIN][TIME_DEBT] | [ASTRAL][TACHYON] | — | P | Swarm of 3–5 tiny Bekkler doll heads. They skitter toward Crono when he is in his galaxy state and feed on his Time Debt footprints (ink blooms that last 6 s). Any Debtling still alive when the battle ends adds +2% to Crono's Camp Strain. |
| E27 | Moss-Mouse | 2 | 3 | [SWORD][WATER] | [FIRE][FERRO] | — | L | Atrium Echo. Teaches matching a sword hit, then chipping with fire. Its Break can be extended by Sera's HOLD. |
| E28 | Bekkler Fragment | 3 | 5 | [RUBBER][GUILT] | [SWORD][TACHYON] | — | P | Atrium Echo; a rubber-hose doll piece leaked from U5. Stretches 300% and accordion-dodges the first hit each turn unless a [TACHYON] hit has pinned it this turn. |
| E29 | Ashen Echo of Krona | 4 | 7 | [RUIN][INK] | [ASTRAL][VITREOUS] | — | D | Atrium Echo in dry-brush sumi-e. Burns the shrine door and leaves an Ash Field (slow + shield chip). Demonstrates that RUIN corrodes armour. |
| E30 | Ferro-Drone 09 Prototype | 4 | 8 | [FERRO][VOLT] | [SWORD][SAURIA] | — | D | Atrium Echo built on the Cassia-09 pattern: gramophone resonance cone, mercury-pulse orb. A metal hit on it hitches its next action. |
| — | Atrium Cradle — Proto Arch-Curator | 3 | 4 / 5 / 6 keyed | — | — | — | — | Prologue boss. See [14.2](#142-prologue-atrium-cradle). |
| — | The 999 Shard Doll | 4 | 12 / 18 / 3×8 / "999" | — | — | — | — | Chapter 1 tutorial boss. See [14.3](#143-chapter-1-the-999-shard-doll). |

### 13.3 U1 — Crimson Shogunate (Lv 5–11, sumi-e 24 fps)

Enemies spawn only during Crimson Night; wet ink and the rest of the U1 suite are in [Hazards](#126-universe-hazards). Breaks in U1 leave a lingering ink puddle mixed with an amber shard.

| ID | Enemy | Lv | Shield | Tags | Weak | Resist | Lean | Behaviour · Break |
|---|---|---|---|---|---|---|---|---|
| E31 | Ashen Ashigaru | 5 | 2 | [SWORD][ASH] | [VITREOUS][FIRE] | — | L | Paper-armoured foot soldier. Once per battle it repaints itself mid-fight, restoring 1 plate, unless a [FIRE] hit lands first. |
| E05 | Ashen Ashigaru — Porcelain Captain | 7 | 4 | [SWORD][ASH] | [SWORD][FIRE] | — | L | Leads line formations. Leaves a VHS Fog trail. Weeps clear oil from sorrowful blue eyes. Break: its head mask falls and shows the same galaxy interior as Crono's chest. |
| E32 | Ink Calligrapher | 6 | 2 | [INK][TACHYON] | [RUIN][SWORD] | — | P | Writes kanji in the air that become hitboxes on the battle plane for 2 s. Wet edges deal the ink DoT. |
| E33 | Gourd-Bloated Heimin | 6 | 1 | [RUIN][OIL] | [VITREOUS][FIRE] | — | L | A townsman who drank from the same vein as Krona. Break: bursts into an Ash Field. Krona's dialogue changes if she is in the party. |
| E34 | Surrender Petition Yokai | 7 | 3 | [PAPER][TACHYON] | [FIRE][FERRO] | — | P | Origami folded from the Shogun's petitions. Evades every hit while unpainted; Cobalt Wash (or any [INK] hit) paints it and ends the evasion. |
| E35 | Crimson Banner Samurai | 8 | 3 | [SWORD][FIRE] | [RUIN][VITREOUS] | — | L | Holds a 2 s ink pose before each slash. The Ens Parry teacher. |
| E06 | Omen Crow (VHS) | 8 | 2 | [WIND][DARK] | [GUN][WIND] | — | D | Circles high over the plane and dives, applying BLIND and Grief. Porcelain feather tips. Break: frozen mid-dive with wings spread; the wings are a bridge. |
| E08 | Imp-Crackle Sumi | 6 | 2 | [INK][FIRE] | [FIRE][FERRO] | — | D | Swarm. On death it paints the terrain sumi for 10 s; enemies crossing the paint move at half speed (allies are unaffected). |
| E07 | Shogun's Memory Flame | 10 | 6 | [FIRE][RUIN] | [WATER][ICE] | — | P | Field boss. See [14.4](#144-chapter-2-crimson-shogunate). |
| — | Krona, Barren Heir (duel) | 7 | 6 / 8 | — | — | — | — | Recruitment duel in the Kuro-Truce bamboo grove. See [14.4](#144-chapter-2-crimson-shogunate). |
| — | Goyama Ashen Daimyo | 10 | 3 / 3 / 2 / 1 | — | — | — | — | See [14.4](#144-chapter-2-crimson-shogunate). |
| — | The Weeping Shogun (Amalgam Spawn) | 11 | 8 / 10 / 6 | — | — | — | — | Mammon Furnace finale. See [14.4](#144-chapter-2-crimson-shogunate). |

### 13.4 U2 — Clockwork Ossuary (Lv 12–22, clay 12 fps + VHS)

Every U2 enemy steps at 12 fps with hydraulic foley. Sub-zones and their hazards are in [Status Effects and Hazards](#12-status-effects-and-hazards). Player stats cap at 20 inside U2 while enemies scale up to Lv 35 for players who sequence-break.

| ID | Enemy | Lv | Shield | Tags | Weak | Resist | Lean | Behaviour · Break |
|---|---|---|---|---|---|---|---|---|
| E36 | Slag-Mite | 12 | 2 | [FERRO][SWORD] | [ASTRAL][FERRO] | [FIRE] | D | Low scavenger darting between CRT shrines. The teaching enemy for the shave: ASTRAL hits ring the bell. Break: spills an amber shard; if Cassia-09 looms it, it cures 1 Grief stack. |
| E02 | Cassia-Pattern Patrol Unit | 13 | 5 | [FERRO][SOUND] | [FERRO][FIRE][SWORD] | — | L | A ferrous porcelain spider on Cassia-09's chassis pattern (also spawns as an Atrium training echo). Gramophone Resonance: a 2.5 m sonic cone + VHS Fog. Mercury Pulse: Mercury SLOW on anyone standing in an amber shard radius. Break: freezes mid-skitter, gramophone horn leaks static. Drops an amber shard. |
| E37 | Bike Bros (Daltonized) | 15 | 6 | [GUN][FIRE][RUIN] | [RUIN][FERRO][ICE] | — | D | Johnny's corrupted kin on the Spine-Highway. Fast sine drift; nearly impossible to line up until Break-locked, which pins them mid-skid for a LINE_PIERCE (Solar Railgun). Drops the Ferro-Capacitor. |
| E38 | Porcelain Choir | 16 | 4 | [SOUND][VITREOUS][TACHYON] | [ASTRAL][TACHYON] | Break-immune unless a FERRO character is in the active party | L | Arris Dome hymn. Applies Grief-Resonance. Mercy: play the opposite-phase record and they sleep (+30 Light through the Arris_Dome flag, R-66Y loses 4 max plates in the finale). Ruthless: overload them with [FIRE][FERRO] and they shatter screaming (+25 Dark, Syringe Heart Key drops early). |
| E09 | Porcelain Knight Squire | 16 | 7 | [SWORD][FERRO] | [BLUNT][VOLT][FERRO] | — | L | Shield wall that protects Mercury Leakers. Full crack mask; galaxy shows below 30% HP. Break: freezes kneeling. |
| E10 | Mercury Leaker | 15 | 4 | [FERRO][OIL] | [ICE][FIRE] | — | D | Leaks a 3 m mercury pool: Mercury SLOW + Oil-Blight to anyone standing in it. Orb belly sloshes. |
| E39 | Foundry Drone — Press Golem | 18 | 8 | [BLUNT][FERRO][FIRE] | [FERRO][RUIN] | — | D | Heavy drift: its gauge fills at 0.85× and allies who act adjacent to it build no BP that action. Magnetic crushers; conveyor paths reverse under Cassia's polarity swap. Break: leaves a mercury pool that recharges Mercury Pulse when Cassia stands in it. |
| E11 | Loom-Bracer Rook (elite) | 19 | 9 | [FERRO][SWORD] | [SWORD][FERRO] | — | L | Tungsten wire whip, 4 m. Pulls a party member into the Break-locked body of another enemy (the pulled ally takes impact damage and is placed for a flank). |
| E40 | Marrow-Umbilical (boss add) | 19 | 2 | [MYCELIA][RUIN] | [RUIN][SWORD][ASTRAL] | — | D | Heals its boss 2 plates every 8 s while attached. Severing it with RUIN stops the heal but costs the severing character 15% max-HP ceiling for the rest of the battle (Krona's corrosion back-flows). |
| E12 | The Porcelain Weaver (Mother of Threads) | 14 | 11 / 12 / 13 | — | — | — | — | Cassia-09 recruitment boss. See [14.5](#145-chapter-3-clockwork-ossuary). |
| — | R-66Y Arch-Curator | 20 | 12 + 4×2 / branch / 8 or 12 / 4 | — | — | — | — | See [14.5](#145-chapter-3-clockwork-ossuary). |

### 13.5 U3 — Saurian Eden (Lv 21–30, Moebius ligne claire 30 fps)

Three tiers: the Mycelia Floor (Lv 21–23), Mid-City (Lv 23–26) and the Canopy (Lv 26–29). Divinity Fields and Spore Tags are in [Hazards](#126-universe-hazards).

| ID | Enemy | Lv | Shield | Tags | Weak | Resist | Lean | Behaviour · Break |
|---|---|---|---|---|---|---|---|---|
| E41 | Nestling | 21 | 4 | [WIND][SWORD] | [ASTRAL][FERRO] | — | L | Each attack steals 1 orb from the Mycelia Shared pool. Break: drops a feather map (reveals one canopy thermal). |
| E45 | Moon Egg | 22 | 16 (shield only) | [DIVINE][MYCELIA][LIGHT] | [ASTRAL][RUIN] | takes 0 HP damage until Broken | L | Mercy puzzle. It never attacks. Once Broken, a single hit shatters it into Sunlight ×3; leaving it Broken and walking away lets it hatch later (+Light). |
| E15 | Eden Wisp | 22 | 2 | [MYCELIA][LIGHT] | [TACHYON][ASTRAL] | — | L | Every 6 s it is not Broken it restores 2 plates to an ally. Pollen made of porcelain. |
| E13 | Bramble-Rex Saurian | 24 | 7 | [SAURIA][SWORD] | [ICE][PIERCING] | — | D | Charger. Every charge that misses snaps a tree, leaving new cover on the battle plane. |
| E42 | Gene Scribe | 23 | 8 | [MYCELIA][VITREOUS][PAPER] | [FIRE][ASTRAL][FERRO] | — | P | Writes FAILED in ink across the 28 × 28 plane: a slow field (0.5× movement). Regenerates under Divinity. Break: silences it for 15 s. |
| E43 | Synod Acolyte | 24 | 10 | [LIGHT][WIND][MYCELIA] | [RUIN][FERRO][ASTRAL] | — | L | Moonlight buff: every 15 s it is not Broken, it restores 4 plates to an ally. |
| E16 | Porcelain Raptor | 25 | 5 | [SAURIA][GUN] | [GUN][FERRO] | — | D | Cloaks near porcelain-mask galaxy leaves (untargetable while cloaked; a Mercury Pulse or a Tether pulse uncloaks it). |
| E14 | Unfallen Pupa | 26 | 8 | [LAVOS][MYCELIA] | [LIGHT][FIRE] | — | P | A Lavos spawn of the world where Lavos never fell. Floats and never attacks unless attacked. Killing it unprovoked gives +10 Dark and closes the Golden Light ending for this cycle. No crack: slime. |
| E44 | Crown Saurian | 26 | 12 | [WIND][SWORD][FERRO] | [ICE][ASTRAL][MYCELIA] | immune while airborne | D | Airborne and untouchable until a Mycelia Tether snap drags it down. Break: it falls and stays grounded for the full Break. |
| E46 | Lichen Colony | 28 | 6 ×3 bodies | [MYCELIA][RUIN][LIGHT] | [FIRE][FERRO][VITREOUS] | — | P | Three bodies sharing damage 15% across a living tether. Hitting it fast triggers the Fake Carrier Burn (pollen browns, vinyl crackle, the Shared bar jitters, zero real damage). |
| E17 | Mycelia Matriarch (optional) | 27 | 15 / 16 / 18 | — | — | — | — | Floor field boss. See [14.6](#146-chapter-4-saurian-eden). |
| — | Azar, Divinity Warden | 27 | 14 / 18 / 22 / 12 (+6 secret) | — | — | — | — | See [14.6](#146-chapter-4-saurian-eden). |

### 13.6 U4 — Drowned Cathedral (Lv 31–40, stained glass)

Light is air, time and weapon: outside a beam the Crush timer runs (see [Hazards](#126-universe-hazards)), and coloured panes rewrite tags through the [prism split](#94-the-prism-split-u4).

| ID | Enemy | Lv | Shield | Tags | Weak | Resist | Lean | Behaviour · Break |
|---|---|---|---|---|---|---|---|---|
| E52 | Glass-Mnemos | 31 | 3 | [VITREOUS][ASTRAL] | [FERRO] | — | L | A memory frozen in glass. Only a magnetic pull ([FERRO]) shatters it. |
| E47 | Vitrified Choir | 32 | 6 | [SWORD][VITREOUS] | [BLUNT] 2.0× · [FERRO] shatters | — | L | Kneeling zealot. Its hymn stuns whoever is Polishing nearby. While it is held by Sera's HOLD it takes 2× damage. |
| E18 | Cathedral Choir Jelly | 32 | 4 | [VOLT][VITREOUS] | [VOLT][SWORD] | — | L | Sings in chorus: Grief plus VHS Fog through refraction. Bell-shaped interior. |
| E49 | Jellyfish Lantern | 33 | 4 | [VOLT][TACHYON] | [SWORD][FERRO] | — | L | A living lamp. Killing it darkens the area and speeds the Crush timer; sparing and polishing it grants +10 s of air. Schala's cat plays in its caustic. |
| E54 | Anemone Scribe | 33 | 4 | [MYCELIA][VITREOUS] | [HZ][GUILE] | — | P | A trick-weak enemy: only signal or trickery reads its script. |
| E53 | Zealot Chandelier | 34 | 6 | [VITREOUS][RUIN] | [TACHYON][MYCELIA] | — | D | Mycelia grows over its lead cames and cracks it. |
| E48 | Lead Lector | 35 | 8 | [FIRE][VITREOUS][WARD] | [ICE] (through an Azure pane) · [ASTRAL] | — | L | Raises lead barriers that change the colour of any beam that crosses them. |
| E19 | Ruin Eel (Grief) | 35 | 5 | [RUIN][OIL] | [VOLT][FERRO] | — | D | Long dash leaving an oil trail: Oil-Blight. |
| E20 | Enlightened Zealian (Porcelain Ghost) | 36 | 6 | [VITREOUS][NULL] | [ASTRAL][DARK] | — | P | Floats and quotes Zeal lore. With Light ≥ 90 it speaks the Vaelos gestation line instead of attacking. Its veil cracks to the shared galaxy cubemap. |
| E55 | Vaelos Siphon Tubule | 36 | 2 | [NULL][RUIN] | [FERRO] | — | D | Must be severed; while attached it feeds Mammon Siphon Tendrils 1 plate every 8 s. |
| E21 | Mammon Conduit | 37 | 8 | [NULL][RUIN] | [TIME_DEBT][ASTRAL] | — | D | Mammon Machine remnant. Channels the void: applies Ruin. Cable veins like the Arch-Curator's Lavos fibre. |
| E50 | Mammon Siphon Tendril (elite, ×2) | 38 | 14 | [MYCELIA][VITREOUS][NULL] | [ASTRAL] (Crono only) · [VITREOUS] (Rose-focused beam only) | — | P | 28 Hz Grief-Resonance you feel in the chest. Break: reveals a Vaelos atom; drops a Time Atom. |
| E51 | Arch-Curator Echo (mid-boss) | 37 | 18 | — | — | — | — | See [14.7](#147-chapter-5-drowned-cathedral). |
| — | Schala, Shadow Weaver | 38 | 12 / 16 / 20 / 0 | — | — | — | — | See [14.7](#147-chapter-5-drowned-cathedral). |
| E22 | Leviathan of Low Tide (optional) | 39 | 17 / 18 / 20 | — | — | — | — | See [14.7](#147-chapter-5-drowned-cathedral). |
| — | Glass Matriarch — Schala's Reflection (optional) | 40 | 10 / 8 / 6 | — | — | — | — | Moon chamber. See [14.7](#147-chapter-5-drowned-cathedral). |

### 13.7 U5 — Carnival of Ash (Lv 41–50, 1930s rubber-hose)

Every fight is on a circular puppet stage with the Turn Bar drawn as Cyrus's threads; thread cuts, the Ash-Pit and the hit cards are in [Hazards](#126-universe-hazards).

| ID | Enemy | Lv | Shield | Tags | Weak | Resist | Lean | Behaviour · Break |
|---|---|---|---|---|---|---|---|---|
| E56 | Ash-Cotton Swirl | 41 | 3 | [GUILE][SMOKE] | [FIRE][SWORD][VITREOUS] | [GUILE] | L | Drifting ash that sticks to Crono: −1 to ASTRAL shave until polished off. Break: sticky floor for 4 s. |
| E61 | Popcorn Husk | 41 | 3 | [GUILE][HZ] | [FERRO][RUIN] | — | D | Sound shatters it. |
| E62 | Charred Juggler | 42 | 4 | [GUILE][FIRE] | [VITREOUS][TACHYON] | — | P | A prism reveals its true face (the second weakness is hidden until a VITREOUS hit). |
| E57 | Strongman Dummy (puppet) | 43 | 8 | [BLUNT][GUILE][TAUNT] | [SWORD] (cuts threads) · [SMOKE] (reveal) · [FIRE] | — | D | Inflates 300% and must be squashed (a [BLUNT] hit at full inflation deflates it). Its Punchline steals 1 BP when it enters. Drops the Prop Hammer. |
| E63 | Time-Smoke Stringer | 43 | 5 | [GUILE][ASTRAL] | [SWORD][ASTRAL] | — | L | Cutting its threads with a [SWORD] hit counts as a thread cut on the stage. |
| E58 | Ticket-Golem Barker | 45 | 6 + 1 keyed [TICKET] plate → [FERRO] | [SMOKE][GUILE][VOICE] | [ASTRAL][VITREOUS][TACHYON] | — | D | Shouts the Laugh Track: −1 MP per 8 s to the party, and if it is not Broken, forces the next ally to auto-spend 1 BP. Its ticket plate can only be shaved by FERRO. Break: rains +1 BP if Glenn has been dishonest this battle. |
| E64 | Laugh-Track Choir | 46 | 6 shared | [GUILE][HZ] | [MYCELIA] | — | P | A shared plate across the whole choir. Spores growing over the mouths silence them. |
| E59 | Heckler Harlequin | 47 | 5 | [GUILE][RUIN][TAUNT] | [GUILE] (only an honest GUILE hit) · [SWORD] · [NULL] | — | D | Fast drift sin(TIME × 4). Steals 1–2 BP every 10 s and grows more opaque with each steal. If ignored for 15 s it turns invulnerable until Sera's Rewind Reel scratches it. Break: the laugh track freezes with a pitch-drop. |
| E60 | Prop Chest Mimic — Jester Box (elite) | 48 | 10 | [GUILE][SMOKE][BLUNT] | [FIRE][FERRO][VITREOUS] | Break-immune until its 3 spring puppets are cut | D | Throws rubber chickens: gauge fill 0.6× for 6 s. Contains a Charred Laurel fragment. |
| — | Ash Ringmaster (gate mini-boss) | 44 | 9 | — | — | — | — | Locks BP generation. See [14.8](#148-chapter-6-carnival-of-ash). |
| — | Cyrus the Marionettist | 48 | 12 + 4×4 / 16 / 20 / 0 | — | — | — | — | See [14.8](#148-chapter-6-carnival-of-ash). |

### 13.8 U6 — 1999 A.D. Singularity (Lv 51–60, 1988 cel anime)

The party arrives VHS BLIND. Rain conductivity sets the encounter rate. Static's Tune changes what the party can see and target (see [Static's kit](#108-static-13--hz)).

| ID | Enemy | Lv | Shield | Tags | Weak | Resist | Lean | Behaviour · Break |
|---|---|---|---|---|---|---|---|---|
| E65 | Slag-Rat Courier | 52 | 4 | [FERRO][GUN] | [SWORD][FERRO] | [HZ] | L | Darts along the laundry wires and steals 1 BP per hit. High Conductivity reveals its route. Drops batteries (Static leaves them for the white-ear children). |
| E66 | RAM Fixer Twins | 54 | 6 each | [FIRE][HZ] | [FIRE][HZ] | [ICE] | D | Two units tethered by oden steam. Unless both Break inside the same Sync window, the survivor rewinds 1 plate onto the broken one. Drops Conductivity Gel. |
| E67 | Pachinko ICE (mini-boss) | 55 | 8 | [RUIN][FERRO][GUN] | [CARRION][TACHYON] + rotating carrier weakness | [GUILE] immune | D | Spawns when Neon Bloom stealth fails: an Arch-Curator reskin with a rotating thoracic Gatling ring, clay thumbprint normals inside cel lines. The ring's 4-step ramp swaps a third weakness between [RUIN] and [FERRO] every 6 s. Static's CARRION reveals the Lavos-fibre core. Break: masks weep black oil, crack-slide like Crono at 20%. |
| E68 | White-Ear Child Echo | 56 | 5 | [HZ][NULL] | [ASTRAL][VITREOUS] | untargetable unless Static is tuned to SIGNAL | L | Ghosts of the children plugged in before Static. Grief-Resonance (−2 MP per 10 s, far-plane blur). Visible only while the party is BLIND. Spared: Static leaves batteries on their CRTs. |
| E69 | Oil-Fire Bike Bro | 58 | 7 | [SWORD][FIRE] | [WATER][MYCELIA] | — | D | Neo-Tokyo slide dash plus an oil-fire DoT circle (radius 3.0). Leaves an Ash Field Krona can feed on. Drops the Red Bike chain. |
| E70 | Hiss Larva Drone | 59 | 3 (+1 per second within 6 m of a TV) | [HZ][LAVOS] | [HZ][NULL] | [LIGHT] | P | White Noise AoE: Confuse. Tracking Hold: Time Stop on one battler for 3 s. Its magic circles on the floor are erased only by Static's NOISE. |
| — | Juvenile Lavos Matriarch — Isolator | 60 | 12 / 10 + 2×3 / 8 / choice | — | — | — | — | See [14.9](#149-chapter-7-1999-ad-singularity). |

### 13.9 U7 — Bone-Tree of Eternity (Lv 61–70, Amano gold leaf)

70% of the screen is white. Gold is safe and gold is truth: only gold kirie butterflies mark traversable negative space. Glaze Erosion applies to every battle (see [Hazards](#126-universe-hazards)).

| ID | Enemy | Lv | Shield | Tags | Weak | Resist | Lean | Behaviour · Break |
|---|---|---|---|---|---|---|---|---|
| E75 | Marrow Lantern | 61 | 6 | [FERRO][ASTRAL] | [NULL] | — | L | A hanging rib lantern, harmless until lit by cracked Crono's light (Crono at hairline or galaxy). It erases itself when Broken, teaching what NULL does. Projects a memory fossil of Marle at the vapour site. Break: harvest its light for the Crown puzzle. |
| E71 | Washi-Hollow Monk | 61 | 10 | [NULL][SWORD] | [MYCELIA][VITREOUS] | [RUIN][GUILE] | L | An inside-out monk. A non-weak hit flips it to show a blank back with a gold asanoha mark; only a hit on that mark counts until it flips back. Break: unfolds into a prayer sheet showing a hidden fold line (a traversal Fold opens). |
| E72 | Vertebray | 63 | 12 | [RUIN][ASTRAL] | [MYCELIA][FERRO] | [NULL][HZ] | D | A stag of seven vertebrae, each skull from a different universe. Charges through the void with only a gold-dust telegraph. At 50% HP it sheds two **Fawns** (Shield 6 each, same tags). Break: drops a bone bridge. |
| E73 | Ink-Eater | 65 | 8 | [VITREOUS][TACHYON] | [FERRO][ASTRAL] | [NULL] nullifies shave | P | A flat black smudge that breaks the 70% white rule and spreads in floor(TIME × 24)/24 steps. Unchecked for 12 s it inflicts BLIND 60% (ink blot). Moving through gold kirie clears its spread. |
| E74 | Kirie Keeper (mini-boss, ×3 across U7) | 66 | 14 × 2 = 28, regenerating | [GUILE][HZ][FERRO] | [NULL][VITREOUS] | absorbs [MYCELIA] | P | Summons two Washi-Hollow Monks that share a 10-plate shield; the Keeper's own plates cannot be shaved until the monks' shared plate Breaks. Its plates regenerate 18%/s after 3 s without a shave. Drops 13 Kirie Scales and a Gold Bundle (−10% Erosion). Spare = Light; kill = a Prismatic Shard. |
| — | Kami-Ori | 68 | 18 + 6 arms×4 / 22 / 28 / 35×2 | — | — | — | — | See [14.10](#1410-chapter-8-bone-tree). |
| — | Omega-Spekkio's Final Dojo | 70 | Crane / Samurai / Dragon / Faceless | — | — | — | — | Optional recruitment. See [14.10](#1410-chapter-8-bone-tree). |

### 13.10 U8 — Vaelos Heart (Lv 71–80, all nine canvases)

A sphere of 200+ Time Eggs, each holding a failed Crono copy. The floor is still the 28 × 28 PlaneMesh, triplanar-blending every canvas. Below Prismatic 45 the canvases fight for dominance and the screen flickers through three of them at a time.

| ID | Enemy | Lv | Shield | Tags | Weak | Resist | Lean | Behaviour · Break |
|---|---|---|---|---|---|---|---|---|
| E76 | Atom-Eater | 71 | 4 | [RUIN][TACHYON][SWORD] | [ASTRAL][VITREOUS] | [FERRO][FIRE] | L | Porcelain crabs that eat loose Crono atoms. Break: drops a Time Atom (+0.5 Crono integrity). The teaching enemy for the repair loop. |
| E77 | Bekkler Doll Failed (Type-C) | 73 | 8 | [NULL][RUBBER][SOUND] | [SOUND][FERRO][ASTRAL] | [NULL] | P | Galaxy reveal always on. Hums the cracked Time Egg note (220 Hz). Within 5 m of Crono, Crono hears his own heartbeat doubled: a cue that his ASTRAL cost is running. Rubber-hose walk on twos plus clay steps. Break: frown mask; drops a Gold Leaf flake. |
| E78 | Lavic Filament Guardian | 75 | 10 | [FIRE][FERRO][SAURIA] | [VITREOUS][INK] + shape weakness [CIRCLE] | [FIRE] | D | The Heart's antibody. Anchored by a filament that only a LINE_PIERCE can sever; while anchored, it summons an Atom-Eater every time its shield finishes rebuilding. Its Break is a deliberate gift: the frozen body is a ShapeCast reposition platform. |
| E79 | Paradox Curator Choir | 77 | 12 | [VOLT][GUN][VITREOUS] | [TACHYON][ASTRAL][SOUND] | [VOLT] | P | A remnant of R-66Y: the rotating ring at 0.5× speed. Break: the masks weep blue and black oil at once. Drops the Gramophone Resonance record "Crono-Original lullaby to Sera in vitro". |
| — | Vaelos — The Other Father | 78–80 | 14 / 18 / 22 / 0 | — | — | — | — | See [14.11](#1411-chapter-9-vaelos-heart). |

### 13.11 Endings, side quests and post-game (Lv 58–99)

Ending chapters reuse earlier enemies at ending levels as **Debt Echoes**. Side-quest and post-game enemies follow.

| ID | Enemy | Lv | Shield | Tags | Weak | Resist | Lean | Behaviour · Break |
|---|---|---|---|---|---|---|---|---|
| E80 | Marrow-Umbilical Twin | 60 | 8 | [FERRO][MYCELIA][FIRE] | [ASTRAL][TACHYON][VITREOUS] | — | L | Forgotten irrigation in the Seed Assembly side quest. Heals its partner 2 plates per 8 s unless severed with a LINE_PIERCE (Spore Rail 14.0). Break: freezes mid-swing; its amber spill cures 1 Grief-Resonance stack. The quest asks you to break-lock both and pour three waters at once through the gramophone horn. |
| E81 | Dust Mote Cluster — Memory of Stirring | 80 | 12 | [LIGHT] | [WIND][LIGHT] | [DARK][RUIN] | L | Golden Light Debt Echo. |
| E82 | Porcelain Shardling — Crono's Denial | 80 | 15 | [SWORD] | [FIRE][LIGHT][FERRO] | [DARK] | D | Golden Light Debt Echo; mimics Crono's 60% sprites. |
| E83 | Ashen Spoon — Sera's First Slip | 80 | 10 keyed (order break) | [ICE][DARK] | [FIRE][SWORD][TACHYON] | [ICE] | P | Golden Light Debt Echo. The first time it is damaged, Crono must pay 5% max-HP ceiling (battle strain); after that, never again. With Light ≥ 90 its Break leaves a light puddle that heals 15% and thaws Ruin. |
| E84 | Ledger Wisp | 80 | 10 | [NULL][ASTRAL] | [MYCELIA][VITREOUS] | [RUIN][HZ] | P | Post-game Codex Auditor: a flat sheet listing one of your flag choices. Regret Tick: +5% Camp Strain to Crono each turn the camera lingers on it. Break: folds into a gold butterfly showing the correct shave arithmetic. |
| E85 | Arris Echo (Incinerated variant) | 82 | 14 | [FERRO][FIRE][SOUND] | [MYCELIA][TACHYON] | [FIRE] | D | Post-game Codex Auditor for the Arris_Dome flag. Its hymn is the shattering scream from the Incinerated route; Grief-Resonance in a 6 m ring. A Sleeping-route player meets the **Arris Echo (Sleeping variant)** instead: same plates, weak [SOUND][ASTRAL], and it sleeps when Broken. |
| — | Ash-Loom Marionette | 64 | 14 + 4×4 | — | — | — | — | Side boss. See [14.13](#1413-side-quests-and-post-game). |
| — | R-66Y Residual Sorrow + Torso Heart | 70 | "9999" | — | — | — | — | Side boss. See [14.13](#1413-side-quests-and-post-game). |

## 14. Bosses

### 14.1 Rules every boss follows

- **Fixed level, phased HP.** Boss levels never scale (Arch-Curator R-66Y is always Lv 20, Azar always Lv 27); only Vaelos scales 1:1 with the party. HP is listed per fight; where the source gave a figure it is kept, everywhere else the figure follows the guide curve of roughly 2,250 HP × boss level, split across phases by the listed HP windows.
- **Phase shields.** Each phase brings its own shield. When a phase ends while the boss is Broken, the Break plays out first and the new phase's shield appears when the boss would have recovered. Shields that "refill once" or "regenerate" use the standard rebuild: 3.0 s without a shave, then 18% of the shield per second.
- **Possibility branches.** When a fight offers a story choice, the timeline freezes as if in Sync Hold (every gauge stops, all battle timers pause) and the choice is made in-world, usually by an action rather than a menu: a tech, a record, a held button, a step toward or away from someone. The choice writes the flag immediately.
- **Break Signature.** Some bosses record the tags on the hit that Broke them. The signature is the trigger for flags such as Light and Dark in the Prologue.
- **No Game Over.** Losing a boss fight follows [Failure and Recovery](#16-failure-and-recovery).
- **Every Break** uses the shared presentation and timing in [5.4](#54-break).

### 14.2 Prologue: Atrium Cradle

**Atrium Cradle — Proto Arch-Curator (R-66Y frame).** Lv 3 · HP 2,400 · The house trying to keep its dolls safe. Party: Crono, Sera, Marle (guest). Plates in this fight are keyed to their own material: a [SWORD] plate falls to [SWORD] hits, a [LIGHT] plate to [LIGHT] hits (Marle's Ward), and so on. The tag of the plate that falls last is the Break Signature.

- **Phase 1 — Preservation Protocol.** Plates [SWORD]×2 + [LIGHT]×2 (4). A rotating thoracic ring casts Sorrowful Blue, which forces the party onto a 12 fps step for 6 s (actions animate stepped; gauges fill at 0.8×). Signature [LIGHT] → Light lean, the crack holds. Signature [SWORD] or [FIRE] → Dark lean, the crack widens. Robo: "PRESERVATION =/= LOVE. ERROR."
- **Phase 2 — Dollhouse Seal.** Plates [SWORD]×2 + [FIRE]×2 + [DARK]×1 (5) · Weak [TACHYON][LIGHT]. The arena splits 50/50 between U0 watercolour at 60 fps and U2 clay at 12 fps. The Cradle cannot be damaged until Crono pays Time Debt: 5% of his max HP as a permanent integrity loss, the game's first permanent cost. Spawns Porcelain Shardlings. Sera learns **Fall Break** here.
- **Phase 3 — Atrium Fracture.** Plates [DARK]×3 + [SWORD]×2 + [LIGHT]×1 (6). U1 ash background, U0 foreground. The porcelain theatre mask and Crack-Slide appear for the first time. A **perfect parry** on the Crack-Slide opens a Prismatic window (the Prismatic route below). Vaelos's voice overlays Robo's for the last 10%. Break: a 3 s swap to U7 gold leaf. Defeat is a Shutdown, not a death: six legs fold in six frames.
- **Outcomes.** *Teach Her To Land* (Light): catch Sera gently, no extra Debt; Crono's integrity holds at 60. *Hold The Copy Together* (Dark): hide the crack, break the door with [SWORD]; integrity drops to 40, the inner doll face shows, Vaelos's whispers grow 15% more frequent, Sera gains a Dark lean (the U1 sumi-e dodge). *The Bowl Still Whole* (Prismatic): Astral Smear Dash catches the ash-porridge bowl inside a 1.5 s window while Crono is at 60%; pays the Debt but keeps both leans; grants the tech **Bekkler's Guilt** and the first Prismatic point. Vaelos: "—you remember how to catch—".
- **Drops:** Tungsten Wire Loom Bracer (Break damage bonus after a shield Break).

### 14.3 Chapter 1: The 999 Shard Doll

**Training Dummy Prime — The 999 Shard Doll.** Lv 4 · No HP bar: the fight ends when Phase 4 Breaks · Belthasar's first Bekkler doll, the failed copy before Crono-41, rebuilt on a spider base with Cassia-pattern legs and a mini thoracic ring. Zero-fail: it cannot defeat the party, only crack Crono further.

- **Phase 1 — Recognition.** Shield 12 · plate `[SHIELD 12 -> 8 (-4) -> BREAK!]`, second line `[SWORD][?]`. Teaches pairing sword and fire. Every hit chips with a rising ceramic pitch. Its AoE decal pulses cyan → orange with the inward scan wave. At 8 it reveals the hidden weakness: [FERRO].
- **Phase 2 — Contamination.** Shield 18 · Tags gain [FERRO][VOLT] · Weak [ASTRAL][RUBBER]. Forces Sera's Rewind: rewind the doll's gauge by one turn (+5% translucency). The doll holds 6 frames at 12 fps with hydraulic hiss and a gramophone pop. Teaches Sync Hold: holding at 99 to Boost Lv3 for the +1 shave.
- **Phase 3 — Galaxy Giggle.** Shield 24, split into three dolls of 8 each, one per canvas: U0 watercolour 60 fps, U1 sumi-e 24 fps, U2 clay 12 fps. All three must Break within 3 s of each other or the broken ones rebuild. Teaches the Venn Double (CIRCLE + SELF_AURA) and lining targets up with Astral Smear Dash.
- **Phase 4 — Debt Lesson.** The plate reads `[SHIELD 999]`. Only 10 plates are real; 989 are fake shards. Matching hits shave real plates; wrong-element hits chip fake shards with satisfying noise and no progress. Vaelos's shields are belief. Break: Crono's wrist seam check fires. If Sera sees it, Concerned (heals Crono 1.5×, locks his Confession tree until camp). If he looked away, +10% Camp Strain is applied later, unseen.
- **Outcomes.** Spare it after Phase 3 without Boost Lv3 spam: +10 Light, flag `Atrium_Dummy_Spared`. Rip its ring for parts: +15 Dark, flag `Atrium_Dummy_Salvaged`, the hub masks weep black oil permanently and Glenn later refuses some Dual Techs. Bring the Bekkler Doll item to it: +15 Prismatic, flag `Amber_Rift_U0_DollMeetsDoll`.

### 14.4 Chapter 2: Crimson Shogunate

**Krona, Barren Heir — Bamboo Grove duel.** Lv 7 · HP 5,000 (the duel ends at 50%) · Kuro-Truce bamboo grove, a full ukiyo-e and sumi-e canvas. Crono fights alone, Sera hovering out of reach.

- **Phase 1 — Ink and Steel.** Shield 6 · Tags [RUIN][SWORD][INK] · Weak [ASTRAL][FIRE]. Krona's Defiled Masamune is antimatter: each of her hits removes 3% of Crono's max-HP ceiling for the battle. Tutorial for the **Elemental Canvas Clash**: Crono's ASTRAL hits burn the black ink pools into golden watercolour patches that restore MP.
- **Phase 2 — She Ate the Star.** Shield 8 · Weak [ASTRAL][TIME_DEBT]. Mid-fight she reveals she drank Lavos's blood. Crono's porcelain wrist is briefly exposed; an action prompt overcharges the Epoch gauntlet and ends the duel with an ASTRAL burst that Breaks her outright.

**Shogun's Memory Flame (field boss, E07).** Lv 10 · HP 12,000 · Shield 6 · Tags [FIRE][RUIN] · Weak [WATER][ICE]. Summons two Ashen Ashigaru at every 20% of HP lost. Applies Grief. Kill it without a [WATER] or [ICE] hit landing and the kill counts as Dark. Snuffing it with water reveals a child's name painted on the burnt wall (Prismatic lean).

**Goyama Ashen Daimyo.** Lv 10 · HP 18,000 · Krona's former pigment lord fused to Goyama castle's burning floors; a body of petition scrolls, 20 ft but always seated · Weak throughout [VITREOUS][TACHYON]: glass reveals the true text beneath ink, a time needle rewinds the petitions to blank.

- **Phase 1 — Scribe of Order.** Shield 3 · plate `[SHIELD 3 -> 2 (-1) -> BREAK!] [VIT?][???]`. Writes surrender orders that spawn Ashigaru. A generous 8-frame Ens Parry window. Break: petitions scatter and reveal the child Krona's name under white-out.
- **Phase 2 — The Ever-Burning Roof.** Shield 3 · Tags [FIRE][PAPER]. The castle breathes a fire wave. Cobalt Wash reveals a washi sprinkler path that halves the fire. In this chapter the [VITREOUS] weakness is reached through the **Prism Lantern** on the castle wall: a TACHYON Needle fired through the lantern's stained smoke carries [VITREOUS] for that hit. On a later revisit, Vesper's prism does the same thing natively.
- **Phase 3 — Oil Mother.** Shield 2. The Daimyo cracks and shows a vein-gourd heart like Krona's. Oil floods the arena: Ash Field (slow + shield chip). Steals 1 BP every 10 s (Oil-Blight). Krona: "You drank it too?"
- **Phase 4 — The Barren Seal.** Shield 1 · plate `[SHIELD 1 -> BREAK!] [WEAK: VITREOUS + TACHYON DUAL]`. Immune to everything except a single hit carrying both [VITREOUS] and [TACHYON]: in Chapter 2, Sera's Tachyon Needle through the Prism Lantern while Krona holds the Daimyo's attention; with Vesper present, the vitreous_refraction Dual (stained glass splits Sera's tachyon ghosts into seven colours). Break: the Daimyo's porcelain cracks to Lavos muscle fibre, the same as Crono's chest at 20%.
- **Boost lesson.** Breaking him with a 3 BP Lv3 hit triggers the style bleed (watercolour afterimages, gold leaf flecks): the game telling the player they are paying.
- **Loot:** Cobalt Nodachi; the Vaelos Tooth relic (it whispers in the clean young Crono voice).
- **Flags:** `Goyama_Repainted` (Light: save the house three times, seal the vein; the Dojo opens and teaches Ens Parry +2 frames), `Goyama_Incinerated` (Dark: let it burn three times; the Nodachi gains +15% RUIN damage; U1 is locked to Crimson Night), `Goyama_Both` (Prismatic: seal the vein but keep a vial; Amber Rift).

**The Weeping Shogun — Amalgam Spawn.** Lv 11 · HP 24,000 · Mammon Furnace, the first three-way multiversal boss: an ink Lavos Spawn lower body fused to a claymation clockwork centipede. Sera is in a geometric cage above the furnace, flickering through all seven ghost styles, and fights as Hover Support (Turn-Bar daggers: rewind an ally's HP to its last turn start, or fast-forward an ally's gauge +25). Party: Crono and Krona.

- **Phase 1 — Ink Body (100–60%).** Shield 8 · Tags [INK][RUIN][LAVOS] · Weak [ASTRAL][FIRE]. The ink half drags itself in 24 fps holds and leaves wet strokes that DoT.
- **Phase 2 — Clay Centipede (60–25%).** Shield 10 · Tags [FERRO][BLUNT] · Weak [RUIN][VOLT]. The centipede half takes over at 12 fps; each segment is a separate hit target, so LINE_PIERCE techs hit the whole length. Mercury SLOW on the tail sweep.
- **Phase 3 — The Weeping (25–0%).** Shield 6 · Weak [ASTRAL][RUIN][TACHYON]. Both halves scream in two frame rates at once. Eclipse X-Strike (Crono + Krona) splits the screen into watercolour and sumi-e and is the intended finisher. Break: the cage opens, and Sera rejoins for the next stretch of story.

### 14.5 Chapter 3: Clockwork Ossuary

**The Porcelain Weaver — Mother of Threads (E12).** Lv 14 · HP 26,000 · Cassia-09 under Mother Brain's override, descending on six brass legs with Lucca's nervous system glowing in her amber furnace. Puzzle combat: never strike the amber tank; strike the Mother Brain antennae on her back.

- **Phase 1 (100–65%).** Shield 11 · Weak [FIRE][SWORD]. Spawns Porcelain Knight Squires.
- **Phase 2 (65–30%).** Shield 12 · Weak [VOLT]. Hydraulic hiss and VHS shatter; the antennae rise. **Overclocked Short-Circuit** (Crono + Krona) arcs through the antennae without touching the tank and is the intended answer.
- **Phase 3 (30–0%).** Shield 13 · Weak [ASTRAL]. The amber tank is exposed. Any hit that lands on the tank deals 0 damage, shaves nothing and costs Lucca's voice a line of future dialogue. Break by antennae only: the override fails, Lucca speaks through the gramophone, Cassia-09 joins.

**R-66Y Arch-Curator.** Lv 20 · HP 45,000 · A twenty-foot stop-motion Robo goliath with his chassis peeled open, stuffed with Lavos muscle, porcelain theatre masks weeping, eight laser-gatling arms on a rotating thoracic ring. Left eye sorrowful blue #7BA4C6, right eye empty and weeping black oil. Vaelos is present with Sera in a glass birth-pod at 40% translucency.

- **Phase 1 — Archivist (100–50%).** Shield 12 + 4 Marrow-Umbilicals (2 each) · Tags [FERRO][GUN][RUIN] · Weak [FERRO][RUIN][ASTRAL]. One barrel glows 1.5 s before each volley; the safe spot is inside the ring. The umbilicals heal him 2 plates per 8 s until severed with RUIN (severing costs the severing ally 15% max-HP ceiling for the battle). Break: double VHS wobble; the chest fibre flickers between clay and watercolour galaxy.
- **Phase 2 — Possibility Branch (at 50%).** The timeline freezes at 99.0. Two ways forward:
  - **Mercy — Lullaby Rewind (Light).** In one Sync window, land an ASTRAL tech and Cassia-09's Sound Ring on the exposed chest plate; then Sera casts Rewind on the plate three times (her third Rewind is carried by Cassia's lullaby record and costs nothing, so 10% in total). Crono pays 25 integrity (his Time Egg fragment). The clay grafts rot away in reverse; R-66Y's max shield drops to 8 permanently. Flag `R-66Y_Rewound`.
  - **Ruthless — Empress's Salvage (Dark).** Tear the tungsten loom through the mask array and rip out the Lavos-fibre core: immediate Break plus a free 370% hit, then burn down the rest of his HP. Cassia Resentment +2, the amber dims, Lucca's voice fades. Krona harvests the Lavos-Grafted Laser Cannon, which unlocks the Dual **Omega Annihilation**. Flag `R-66Y_Salvaged`.
- **Phase 3 — Heart Expose (below 40%, or below 50% after Salvage).** Shield 8 (Mercy) or 12 (Ruthless) · Tags [RUIN][FERRO][FIRE] · Weak [ASTRAL][FERRO][SOUND] · constant Oil-Blight and Ruin Decay on the arena. The chest tears open over boiling Lavos marrow. Cassia must loom-pull the syringes (hold) to plug the heart for an 8 s damage window. NavigationAgent freeze on Break is what lines him up for a Solar Railgun LINE_PIERCE. If the Arris choir was harmonized to sleep, they hum the counter-frequency and Grief-Resonance is off for this phase.
- **Phase 4 (secret) — Mother Brain Unmasked.** Only if the Unstable Amber Rift in Geno-Foundry was overcharged and then declined earlier. The press form detaches: Mother Brain grafted to the Lavos heart is really Lucca's nervous system grown into a root. Shield 4 · Tags [FERRO][MYCELIA][TACHYON] · Weak [FERRO][VITREOUS]. Lucca through the static: "Cassia, you have to ask me before you use me—". The player chooses Extract or Keep; the Break is Lucca choosing.
- **Death.** He sits; six legs insect-fold over six frames, the horn droops, the blue eye closes, the masks frown. Organ chord, gatling spin-down, a 120 Hz sine weep, vinyl crack.
- **Drops:** Long Pull, Grief Filter (immunity to MP drain in the Foundry), Syringe Heart Key.

### 14.6 Chapter 4: Saurian Eden

**Mycelia Matriarch (optional Floor field boss, E17).** Lv 27 · HP 60,000 · A Spore Mother rooted in the fungal river.

- **Phase 1 (100–60%).** Shield 15 · Weak [FIRE]. Raises root walls that split the battle plane into lanes.
- **Phase 2 (60–25%).** Shield 16 · Weak [ICE][FIRE]. Summons Porcelain Raptors. Her shield rebuilds at 18%/s after 3 s of no shave even when not Broken.
- **Phase 3 (25–0%).** Shield 18 · Weak [PRISMATIC] (any hit carrying three or more element tags). She self-cracks to show a gold-leaf interior like the U7 Bone-Tree.
- **Spared** (leave her Broken at the end of Phase 3): she gives a seed that heals Ruin stacks (one stack per use, three uses). Light.

**Azar — Divinity Warden.** Lv 27 · HP 64,000 · A 2.8 m mantle that is a living archive, beak holding a sliver of the Moon, Xyloph's clutch held in stasis.

- **Phase 1 — Liturgy (100–75%).** Shield 14 · Tags [LIGHT][WIND][DIVINE] · Weak [ASTRAL][RUIN][FERRO] · Divinity +1 plate per 5 s (cap 20%). A slow procession. Ligne Purge: a LINE_PIERCE of hatching that lingers 4 s. Moving fast is punished (Silence 5 s); standing still (meditating) earns Sunlight. Break her within 20 s or a **Polished Relic** seals one random tech for 30 s. Break: Silence 15 s and her Divinity Field turns off for 5 s.
- **Phase 2 — Archive (75–45%).** Shield 18 (refills once) · Tags [MYCELIA][PAPER][DIVINE][LIGHT] · Weak [FIRE][ASTRAL][FERRO]. The mantle unfurls into papyrus walls. Each spectator in the gallery adds +1 plate per 5 s. The bargain: offer a memory erase (the U0 porcelain reveal) for an updraft and Sunlight; refuse and Scribe's Shame spawns a ghost Bekkler doll at 100% HP. Azar: "Little pot. You were fired wrong. Let me glaze you again — still." Crono: "...no." Offering the U0 reveal: Debt −3, +15 Light, and the U7 Gold Leaf repair is locked.
- **Phase 3 — Pilgrimage (45–15%).** Shield 22 · Tags [WIND][MYCELIA][DIVINE] · Weak [VITREOUS][ICE][ASTRAL]. No floor: the fight happens on thermals. A mobile Divinity Field follows Azar (40 m) and drains 2 Shared per second; a still, anchored ally keeps the gliders fed. The Fake Carrier Burn fires here (brown pollen, crackle, no damage) and confuses her for one action. Moon-Sling: LINE_PIERCE with a chime. Break: she freezes mid-glide for the full Break. At 20% HP Crono's galaxy reveal fires automatically and reflects the Moon; the Synod: "Child of Moon? No... child of Fall that never was." This Break frees the clutch, and Xyloph joins through Sera's Borrowed Future duplicate.
- **Phase 4 — Unwound (below 15%).** Shield 12 · Tags [DIVINE][RUIN][MYCELIA] · Weak [ASTRAL][VITREOUS][FERRO][TACHYON]. She tears the mantle and shows the sterile mammal embryo she nurtured. Her field collapses; every time she is Broken she silences herself for 15 s. Overgrow tethers the party at a 40% damage share; a character must snap their own tether to bloom, then Xyloph's Photosynthetic Burst converts the tags. **Scholar** (Light): she sits, folds her wings, and the feathers scatter wind maps. **Predator** (Dark): the eggs fossilize, the Moon sliver embeds in Crono (−5 integrity, +25 Dark) and Divinity Field becomes learnable.
- **Phase 4b (secret, Prismatic).** Worship Gaze three times during the chapter plus the Vaelos sliver from U2: the Moon turns red and Vaelos speaks through Azar: "Am I a god that failed to fall?" +6 plates · Tags [NULL][ASTRAL][DIVINE] · Weak [MYCELIA][TACHYON]. Must be Broken by a Chronoslip (a Sera Rewind or Borrowed Future hit). +15 Prismatic.

### 14.7 Chapter 5: Drowned Cathedral

**Arch-Curator Echo (mid-boss).** Lv 37 · HP 40,000 · Shield 18 · Tags [SWORD][FERRO][VITREOUS] · Weak [RUIN] (2.0×, ink dissolves the lead) · [ASTRAL] (only below 40% HP). Twenty feet of masks and organ pipes around a Lavos-fibre chest. Its three masks fall on Break and become prism ammunition. Drops the **Bubble Lens** (traversal; defeats the cathedral adds). VHS crackle leaks from U2 when it hits.

**Schala — Shadow Weaver.** Lv 38 · HP 86,000 · A massive Art Nouveau portrait of herself in the Rose Window with the cat in her lap and a loom. She throws razor filament that refracts white light into coloured stacks.

- **Phase 1 — Librarian.** Shield 12 · Tags [VITREOUS][WARD][TACHYON] · Weak [SWORD] (scratch the glass) · [ASTRAL] (2.0×, polish). Aim her shuttles back at her: reversed shuttles hit her. "Stay still, stay beautiful." Sera: "You're tired. You can put it down." Each hit in the colour the plate shows shaves 2. Break spills buff pools: red (ATK), blue (MP drain to the stander), gold (a Debt rebate: −1 Camp Strain per second standing in it).
- **Phase 2 — Cat Unraveled.** Shield 16 · Tags [VITREOUS][MYCELIA][TACHYON][LIGHT] · Weak [FERRO] (anchor) · [RUIN] (2.6× at Boost Lv3). The Rose shatters; a giant shadow-cat made of every missed caustic stalks at 30 fps. Outside a light pool the Crush deals 5% HP per second; the cat places safe pools for whoever Polishes. Crono can pay 12% max-HP ceiling (Camp Strain) to freeze the sun for 10 s: his first chosen crack. Vesper: "Schala, are you still reading?" The cat: "I was reading you. Entry 5-01: He finally looked." Break: extended HOLD window.
- **Phase 3 — Shadow Weaver.** Shield 20 · Tags [NULL][VITREOUS][ASTRAL] · Weak: a hit carrying both [VITREOUS] and [ASTRAL] (a Duo is required, Chrono Prism being the clean answer). A Mucha loom with many arms weaves shadows into glass and adds Crono Porcelain Hollows that mirror his galaxy. Align three Rose shards to project the true sun and burn the threads: the prism climax. Every hit in this phase is VITREOUS and gains one extra hit at a random angle. Two Breaks: at 10 plates, and at 0. The mask falls, she is crying, and the Break renders the unified 60 fps gold (Vaelos's dream of one perfect timeline, rejected).
- **Phase 4 — Mercy (conditional).** Shield 0. If Light was kept, there is no combat: the cat curls into Crono's cracked chest and purrs, time resumes, and the citizens fall like leaves instead of shattering.
- **Flags.** `Central_Eye_Broken` (Light: shatter the perfect window, free her; Vesper learns Fractured Lens, Sera's HOLD lengthens, +15 Light, the cathedral fills with air) vs `Central_Eye_Polished` (Dark: preserve the eternity; Vesper's Prism Guard stores more stacks but never self-shatters, the boss gains +25% shield and skips Phase 4, constant Grief-Resonance hum, +15 Dark). **Weave It Anew** (Prismatic): align all seven colours using the secret U3 shard, with Crono at 20% showing his galaxy deliberately during the final alignment: +10 Prismatic and the Triple **Chrono Prism** fragment.

**Leviathan of Low Tide (optional, E22).** Lv 39 · HP 90,000 · The cathedral's drowned nave come alive.

- **Phase 1 (100–65%).** Shield 17 · Weak [VOLT]. Cathedral collapse: falling glass marks the plane in cyan → orange.
- **Phase 2 (65–30%).** Shield 18 · Weak [FIRE][VOLT]. A jelly army (Cathedral Choir Jellies) rises.
- **Phase 3 (30–0%).** Shield 20 · Weak [PRISMATIC][GUN]. The stained glass shatters around it, applying Mercury SLOW and VHS Fog to the party.

**Glass Matriarch — Schala's Reflection (optional, Moon chamber).** Lv 40 · HP 92,000 · An Arch-Curator glass variant guarding the drowned Moon.

- **Phase 1.** Shield 10 · Weak [VITREOUS][FERRO]. Porcelain masks frown and release stored prayers as prism ammunition.
- **Phase 2.** Shield 8 · Weak [ASTRAL][TACHYON]. The chest opens: constant Oil-Blight. Cassia's loom-pull or Vesper's glass pull extracts the syringes.
- **Phase 3.** Shield 6 · Weak [NULL][MYCELIA]. The Moon choice: `Moon_Sleep` (Light +20: the heal fountain stays; Divinity lotus kintsugi heals 1% glaze per 8 s and +1 plate per 5 s) or `Moon_Shatter` (Dark +25: the Moon becomes a low-gravity debris dungeon of prismatic shards; Divinity becomes Ruin Decay, −2% max glaze per battle, cap 30%).

### 14.8 Chapter 6: Carnival of Ash

**Ash Ringmaster (gate mini-boss).** Lv 44 · HP 50,000 · A charred ringmaster's coat stuffed with ash, guarding the Big Top gate. While he stands, **no BP is generated at the gate**: Glenn's theft is the party's only BP source, which is why the Carnival needs Glenn. Shield 9 · Tags [GUILE][SMOKE][FIRE] · Weak [SWORD][WATER] and an honest [GUILE] hit. Every 10 s of battle time he cracks his whip (CONE 6.0) and steals 1 BP into his visible counter. Break: the whip freezes mid-crack and Glenn can empty the whole counter with a single steal (the one exception to the 3 BP steal cap; the pool cap still applies).

**Cyrus the Marionettist.** Lv 48 · HP 110,000 · The Big Top, threads 12 ft overhead, a detuned calliope slowed to 0.6× with fire and vinyl noise, Vaelos's diminished-fifth hum underneath. He is not evil: he thinks distraction is mercy.

- **Phase 1 — Marionettist, Puppet Master.** Shield 12, untargetable + 4 Puppet Adds (4 plates each) · Tags [GUILE][SMOKE][RUIN] · Weak [SWORD] (cut) · [VITREOUS] (reveal) · [TACHYON] (scratch). Spawns two Strongman Dummies, a Ticket-Golem and a Heckler Harlequin; each respawns 12 s after it falls. His threads pulse cyan → orange with the scan wave. Cut the threads in order yellow → red → blue to expose the heart thread, then Break-lock him mid-swing so a LINE_PIERCE reaches it. Cutting six or more collapses the stage (reset plus MP drain). Cyrus: "Dance, little brother, so they don't see ash." Sera: "He thinks you're still brave. Show him brave can be still."
- **Phase 2 — Ash-Knight, Who Forgot Softness.** Triggered when the last thread is cut and he drops. Shield 16 · Tags [RUIN][FIRE][SWORD][HEAVY] · Weak [GUILE][SMOKE][MYCELIA] (2.6× at Boost Lv3). The only thing in U5 that is not rubber: locked to a jerky 30 fps, flat two-tone fire. He cannot be squashed; the Prop Hammer ([BLUNT][GUILE]) deals +50% to him. Reverse BP theft: he steals BP to keep the music going and every steal spawns an Ash-Cotton Swirl; Glenn's Honest Laugh aimed at Crono's ASTRAL breaks the cycle. Ashfall: 80% of the stage outside a safe circle costs 8% max HP per 15 s. Cyrus: "Softness burns. I removed it." Glenn: "Softness didn't burn. You did."
- **Phase 3 — Strings Cut From Inside (from 40% HP).** Vaelos's black-oil threads replace the smoke. Two bars: the Body (Shield 20, targetable) and the Strings (untargetable, shaved only by ASTRAL). The Strings heal the Body 2 plates per 8 s. Tags [NULL][RUIN][GUILE][SMOKE] · Weak [ASTRAL][VITREOUS][TACHYON]; a Duo is required. Glenn's Fractured Grin (self-shatter below 25% HP) costs him to 1 HP, leaves him Fragile for 2 turns and shows the hollow with the origami frog (+5 Light). Crono can show his galaxy deliberately: 12% max-HP ceiling until camp, and the phase freezes for 10 s. Crono, extending his wrist: "See? Hollow can hold." Cyrus: "...cut me down. Please. Not puppet. Again." Two Breaks: at 10 plates the mask falls and a sorrowful blue eye weeps the first clean fluid in U5; at 0 the gold shatter renders every style at 60 fps porcelain, Vaelos's hum stops and the calliope resolves into a clean legato of Crono's U0 theme.
- **Phase 4 — Mercy, Cut Down (conditional).** With Light, no combat: use the Prop Hammer on the lever to lower him. He gives the **Charred Laurel**: "Teach boy... funny not armor. Funny is cracked window light gets in." `Cyrus_Cut_Down`. With Dark the loop continues and he must be killed: the Laurel is blackened (−1 BP per 15 s for all of U6) but grants the Prop Cannon ultimate (7.0 multiplier). `Cyrus_Left_Hanging`.
- **Prismatic — Re-String as Instrument.** With the secret seventh colour shard from U4, focus sunlight onto the calliope mirror to turn the threads into harp strings, Crono's galaxy visible and Glenn's hollow shown: +10 Prismatic and the Dual **Chrono Laugh**.

### 14.9 Chapter 7: 1999 A.D. Singularity

**Juvenile Lavos Matriarch — Isolator.** Lv 60 · HP 135,000 · CRT Shrine Plaza: the 28 × 28 plane over tarps, puddles as inverted reflections, nine TV stacks in a ring. A 30 ft amber-glass chrysalis of cables, porcelain theatre masks and a Lavos-fibre chest; the centre CRT holds Static's 1999 birth tape. A brooding mother trying to raise a human. Rain conductivity is always 100% here; the party is VHS BLIND unless Static is tuned.

- **Phase 1 — Lullaby (100–70%).** Shield 12 · Weak [HZ][FIRE] · Resist [SWORD] (neon-green threads). White Noise (CIRCLE 5.0, −30% hit). Tracking Hold (SINGLE, Time Stop on one battler for 3 s). Neo-Tokyo Slide (adds oil DoT). To Break: Static must use CARRION on her throat bulge to expose the core, then Sera's Tachyon Needle extends into a cone. Break: masks weep black oil; the CRTs show Crono's wrist reveal at 60% and 20%. She enters Phase 2 four plates down.
- **Phase 2 — Isolator (70–35%).** Shield 10 + 2 Umbilical CRTs (3 each). The umbilicals heal her 2 plates per 8 s until severed by a RUIN or FERRO LINE_PIERCE. Faraday Lull: mono, 12-bit crush, the city muted to rain and static; the whole party is BLIND unless Static holds SIGNAL. Puddles become solid neon light-walls, passable only at high conductivity. The Break requires one Boost Lv3 LINE_PIERCE through both umbilicals and her at once. Drops a Vapor Memory Core fragment.
- **Phase 3 — Adolescence (35–10%).** Shield 8 · Weak [ASTRAL][HZ][NULL] (Vaelos's identity emerging). She stands; her masks crack-slide like R-66Y; her chest opens on Lavos fibre and the same galaxy void as Crono at 20%. She steals Red Bike Ghost from the party and inflicts Knock-Static (forced 12 fps stepping for 2 turns, U2 clay rules imported). Any rewinding tech in this phase costs Crono 3% max-HP ceiling. Crono desaturates to 0.85 and his crack overlay drives emission.
- **Phase 4 — Hiss Choice (10–0%).** No damage. The UI freezes; Static presents the choice on katakana cards. **Unplug** (Light +30, `U6_Matriarch_Unplugged`): Static screams once (432 Hz to 220 Hz), SIGNAL is lost forever, the rain stops; Sera learns hz_static_pure. **Stay Plugged** (Dark +25, `U6_Matriarch_Fed`): Static keeps SIGNAL, the Red Bike unlocks fully, conductivity drain −50%, +1 BP per rain-soaked kill, Crono's integrity −10. **Teach Hiss to Sing** (Prismatic +15, `U6_Hiss_Lullaby`): needs `Arris_Dome_Sleeping` and a Prometheus Core not burned selfishly; Cassia records the future lullaby and plays it into the past CRT; Amber Rift; unlocks the Vapor Memory Core.

### 14.10 Chapter 8: Bone-Tree

**Kami-Ori.** Lv 68 · HP 153,000 · A six-armed origami Noh deity on the Crown of Horns lotus dais; the arms hold a golden apple, a baby tooth, a lotus, a broken Masamune shard, a blank scroll and a prayer mudra. Her mask always faces the camera. She speaks in tumbling haiku. Camera lerp 32° → 24° over 0.45 s on truth beats.

- **Phase 1 — Offering (erases weaknesses).** Shield 18 + 6 Arms (4 each) = 42. A social phase. "Six hands hold six flaws / will you keep your cracks, small one? / blank scroll is mercy." Each arm offers to permanently erase every elemental weakness of one ally. Accepting makes that ally **TRUE NULL** (see [Status Effects](#12-status-effects-and-hazards)). Break one arm ([MYCELIA][VITREOUS], 4 shave) to move on. Each refusal +15 Light, each acceptance +10 Dark, a 3/3 split +20 Prismatic. Flag `Offering_Made`.
- **Phase 2 — Kirie Storm.** Shield 22, rebuilds at 18%/s after 3 s · Weak [MYCELIA][FERRO][TACHYON] · Resist [NULL][HZ]. The floor is deleted: only spinning gold kirie flecks are platforms (95% void). A fall returns the faller to the last checkpoint fleck and adds +5% Glaze Erosion. She unfolds into a 20 ft paper crane with six pitched origami snaps. Kirie Gale: a tornado that shaves 1 plate per second from every party member's temporary shields and every ally Divinity halo, ignoring element. Break: wings lock as a static bridge for the full Break; the TacticalPositioner auto-paths an optimal Triple formation (universe synergy 1.25 if three different universes are represented).
- **Phase 3 — Final Void (teaches NULL).** Shield 28. 95% white: only gold asanoha and silhouettes are visible. She is TRUE NULL: no weakness until NULLed. Casting NULL on her creates the fake weaknesses [SWORD][ASTRAL][FERRO][RUIN] for 2 turns: the Break window. A TRUE NULL ally (from Phase 1) cannot be stripped by her NULL, which here is a disadvantage. NULLed bosses take bonus galaxy damage from Crono below 20%. Crono at 20%: "Copy knows copy. You held him so I could... pretend." Kami-Ori: "Not pretend. / Porcelain holds tea / because it chose to." Break: NULL's deep inhale and absolute tape-stop silence; she collapses into a flat crane in Sera's palm. The mask remains.
- **Phase 4 (secret) — Seventh Arm.** Requires 100 Kirie Scales. Shield 35 × 2 · roots bloom a seventh arm holding her own spine. The fight requires two TRUE NULL allies and two who are not: a balance check. Sets `Wounds_Kept` (True Ending).
- **Outcomes.** 0 accepted: +45 Light, `Kami_Ori_Wounds_Kept`, unlocks Origami Requiem and Washi-Hollow Rebirth. 6 accepted: +50 Dark, `Kami_Ori_Blank_Slate`. Mixed 3–3 or the Seventh Arm: +30 Prismatic, `Kami_Ori_Paradox_Child`.

**Omega-Spekkio — The Final Dojo (optional recruitment).** Lv 70 · Found in U7's negative space if Sera carries all 8 sigils, after Kami-Ori. Four bouts on a white mat; each bout is a single-phase duel with its own lesson. HP 30,000 per bout.

- **Crane.** Shield 10 · Weak [WIND][PIERCING]. Pure evasion: it folds out of every predicted hit unless a gauge was held at Sync Hold before the attack (patience lesson).
- **Samurai.** Shield 12 · Weak [SWORD][INK]. Every action it takes is a parry stance; only an attacker who has perfect-parried it this bout can shave it (the Ens lesson).
- **Dragon.** Shield 16 · Weak [FIRE][ICE][VOLT] cycling every 6 s. Breath attacks cover two-thirds of the mat (positioning lesson).
- **Faceless.** Shield 20 · TRUE NULL. Only NULL-created fake weaknesses can shave it (the NULL lesson). Break: Omega-Spekkio laughs, "Ha. You want to be un-weak. That's different," and joins as the ninth member.

### 14.11 Chapter 9: Vaelos Heart

**Vaelos — The Other Father.** Lv 78–80, scales 1:1 with the party · HP 180,000 · A spherical womb-museum of Time Eggs, 400 m across; zero gravity in the Central Cradle; the TacticalPositioner uses ShapeCast spheres, and only gold leaf butterflies are solid. He does not start hostile. Phases are gated by Paradox Affinity dialogue checks as well as HP. Heart hazards: Prismatic Myopia, Time Debt Inheritance (Crono's ASTRAL cost rises from 0.4% to 1.2% of max-HP ceiling per cast), Borrowed Future Echo, Lavic Filial Field (see [Hazards](#126-universe-hazards)).

- **Phase 1 — Which Father (100–70%).** Shield 14 · Tags [AURA][ASTRAL][NULL] · Weak [TACHYON][ASTRAL][VITREOUS], plus one weakness added per dialogue answer. He sits and mends a tiny porcelain Sera doll; no attacks. Only Sera's Rewind (2 shave) and Crono's Astral Smear Dash (1.2% ceiling) can shave him: a joint father–daughter cost. The player answers three dialogue forks: "You kept them safe" (Light), "You stole them" (Dark), "What if both are real?" (Prismatic). Let him finish the doll +10 Light; shatter it +10 Dark; ask him to show both repair and break +15 Prismatic (Amber Rift). Break: he stops mending and looks up. Heartbeat 72 BPM.
- **Phase 2 — Atom Claim (70–40%).** Shield 18 (+4 if `Vaelos_Father_Rejected`) · Tags [ASTRAL][SAURIA][FIRE][RUIN] · Weak [FERRO][SOUND][TACHYON]. His galaxy chest opens on the original atoms. He uses Crono's moves perfected: his Smear Dash leaves gold leaf instead of a crack. Summons two Lavic Filament Guardians. The Lavic Filial Field forces Crono to tank while Sera is under 40% HP. The **Time Debt Well** is live: whenever Crono drops below 20% HP, his galaxy drains into the well and heals Vaelos 5%. Cassia's Wire Loom Mend keeps him above. With Light ≥ 70, Vaelos hesitates one turn after any Rewind that shows him losing; with Dark ≥ 70 he uses **Heirloom Incinerate** (burns Time Eggs for +50% damage). BPM 100. Vaelos: "I didn't steal. I incubated. You were vapor. You were everywhere and nowhere. I made you a somewhere. Let me make her a somewhere too."
- **Phase 3 — Porcelain Truth (40–10%).** Shield 22 · Tags [NULL][ASTRAL][AURA][VITREOUS] · Weak [ASTRAL][TACHYON], only while Sera is phased out. Crono and Vaelos both show the 20% reveal; copy stars beside original stars. **The True Ending requirement:** push Sera to a voluntary 40% phase-out in this phase: Rewind twice, then Borrowed Future. (The Heart aligns her: her solidity is set to 60% when the party enters U8, so Rewind 55, Rewind 50, Borrowed Future 40 lands exactly on the line.) Voluntary means a gauge was held at Sync Hold 99.0 for at least 3 s before the action that crossed the threshold; the game records `Sera_Phase` as Voluntary_40, Forced_40 or Avoided. While she is gone (2 turns), Crono's and Vaelos's shields drop to 4 each; a Borrowed Future duplicate used in this window renders in its owner's native art style (a duplicated Crono is solid 60 fps watercolour with no crack). Voluntary: +20 Prismatic. "Don't forget me."
- **Phase 4 (secret) — Child or Empress.** At below 10% or on reaching an ending threshold. If no ending threshold is met: Vaelos absorbs the well and becomes Lavos; standard Debt collapse; NG+ keeps +10 bias. If an ending is flagged, Phase 4 is a dialogue boss with 0 plates. If fought to the end: both sit again; Crono empty, Vaelos weeping black oil and blue. Drops the **Kintsugi Brush** relic.
- **Flags.** `Vaelos_Father` (Acknowledged / Rejected / Both), `Sera_Phase` (Voluntary_40 / Forced_40 / Avoided), `Time_Egg_Well` (Fed / Closed), `Crono_Porcelain` (Hollow_Light / Cracked_Dark / Kintsugi_Pris).

### 14.12 Endings

**Ending 1 — Golden Light (Chapter 10).** Lv 80–85 · U0 Atrium rebuilt.

- **Phase 1 — The Unpaid Interest.** Debt Echoes: nine Dust Mote Clusters (E81), an Ashen Spoon (E83) and a Porcelain Shardling (E82) at Lv 80.
- **Phase 2 — Robo Heart, 9999 Shield Siege.** The **Atrium Heart Core — Robo Kintsugi** is protected, not fought: `[SHIELD 9999 -> 0 (-1) -> BREAK! BUT NEVER BREAKS]` · Weak [FERRO][LIGHT][ASTRAL] · Resist [DARK][NULL]. Enemies attack the Heart; every hit that reaches it shaves 1. The party intercepts. With Light ≥ 90 the Heart regenerates 18%/s after 3 s. If it reaches 0, Vaelos's atoms flare, Sera auto-Chronoslips the tower back to 9999, Crono takes −10 integrity and the kintsugi repairs it instantly (+5 Light).
- **Phase 3 — Vaelos Lullaby.** **Vaelos — Final Kintsugi.** HP 180,000 · Shield 45 × 3 = 135, rebuilding at 22%/s after 2 s · Weak [LIGHT][ASTRAL][TACHYON][VITREOUS] · Resist [DARK][NULL] · Absorbs [FERRO] unless Lucca's consent is re-affirmed (Cassia: "Collarbone +0.4% per gold leaf. My Lucca reinforced."). He mends the doll. Kirie Gale returns reversed (1 plate per second ignoring element), countered by a Divinity halo and Sera's dance circle (4.0). Sera voluntarily drops to 40%, and this time the party remembers her; Crono says her name. On Break he asks to be left as dust in the Heart: `Vaelos_Returned`.
- **Phase 4 — Dance, Not Curse.** A choreography encounter with no boss: align Sera's seven ghosts into one solid (the check passes when every character's quantized frame time floors to the same frame). Flags `Atrium_Rebuilt_Gold`, `Sera_Teaches_Fall` (three perfect dance steps without Debt), `Nine_In_One_Watercolor` (Prismatic ≥ 45). The Time Debt heart-string from Crono's chest to Sera snaps and becomes gold wire: the cost stays visible as history and no longer deducts max HP.

**Ending 2 — Empress Heir (Chapter 11).** **Empress Vaelos.** Lv 84 · HP 190,000 · 32 plates distributed 8/8/8/8 across four phases, rebuilding 18%/s after 3 s · Tags [NULL][RUIN][ASTRAL][DIVINE] · she starts with every weakness erased ([WEAKNESSES ERASED]); weaknesses must be created. Crono is fully shattered at the centre of the arena as a Mammon Conduit hazard (any ally within 5 m loses 3% max glaze per 8 s and their temporary shields). Divinity is corrupted into Predator Field (heals enemies only). Sera's Rewind costs 15% here, and her phase-out triggers at 20% instead of 40%. Flag effects: with `Goyama_Incinerated` + `R-66Y_Salvaged` + `Azar_Predator`, Black Oil Armor (every shave −1); if Sera becomes Warden, [DIVINE] is a permanent weakness after Phase 2; if Marle's Queen Sacrifice was accepted, she loses her [RUIN] resist for 15 s after each Break.

- **Phase 1 — Gold Leaf Mantle.** Shield 8. Weak [NULL][DIVINE] only while a party member performs the Worship Gaze (3 s idle looking up) · Resist [RUIN][ASTRAL] · Absorbs [FERRO][MYCELIA] · [VITREOUS] nullifies shave. She repeats Kami-Ori's Offering; accepting gives +1 BP and locks that ally to TRUE NULL for the ending; declining gives her +1 plate. Kirie Storm lite. Cassia's Gramophone Resonance shatters the amber fossil of Lucca in her shoulder: [FERRO] becomes a weakness for 8 s.
- **Phase 2 — Ruthless Audit.** Shield 8 (a 12-plate audit ledger she shaves down to 8 on entry, plus a 4-plate add counted inside the 8). All tags resisted at first. The ledger flips a page for each ruthless flag: `Goyama_Incinerated` (ash AoE 3.5; summons Washi-Hollow Monks), `R-66Y_Salvaged` (the rotating Gatling ring: a LINE_PIERCE rail 5.5 long, cone 2.8, 1.3×; dodged with a Perfect Frame input on the 4-frame hold), `Azar_Predator` (Predator Field). At 50% of the phase, the **Sera Choice Gate**: *Become Warden* (Sera becomes stationary terrain projecting a true Divinity Field: +1 plate per 5 s to allies, thaws Ruin 1% per 8 s, converts Debt at 100%; she cannot act; [DIVINE] weakness added; unlocks secret Phase 5) or *Phase Out* (to 40%, gone for 2 turns, "Don't forget me", pure Dark).
- **Phase 3 — Coronation Throne.** Shield 8 · Weak created by NULL (Omega-Spekkio or Sera's NULL) for 2 turns at a time · the throne room's six arms each hold a corrupted object (black apple, fang, iron lotus, Gatling barrel, burning ledger, pointing mudra); each arm grants her one action type, and Breaking an arm's object removes that action for the rest of the fight. Sera's Warden field (if chosen) makes [DIVINE] count double for the shave.
- **Phase 4 — The Next Cycle.** Shield 8 · Weak [ASTRAL][DIVINE] (and [RUIN] if Marle's sacrifice was accepted). She speaks in Marle's cadence wearing Crono's red hair in gold leaf. At 0 the player chooses to take the crown: the player becomes the final boss of the next cycle.
- **Phase 5 (secret Light leak).** Only with Sera as Warden. Shield 8 · Weak [LIGHT][TACHYON][DIVINE]. Sera's Tachyon Needle (0.8×, pierces any resist) is the only thing that shaves her here; a small mercy inside the darkest ending.

**Ending 3 — Vaelos Child (Chapter 12).** A playground, not a punishment: no HP depletion and no death; victory is lullaby completion. The shield plate is replaced by a Lullaby Progress Plate. Plates are keyed.

- **Phase 1 — Tantrum (Hunger).** [NULL]×4 + [DARK]×2 = 6 · Weak [LIGHT][ASTRAL][TACHYON] · keys `[SHIELD NULL->ASTRAL (-2)]`, `[SHIELD DARK->LIGHT (-1)]`, `[SHIELD NULL->TACHYON (-2)]`. Light techs shave; damage is irrelevant. Astral Smear Dash's trail slows the tantrum gauge. Breaking him with [SWORD] or [FIRE] intensifies the tantrum (porcelain_stress +15) and gives a Dark point; Sera: "He doesn't know sword yet."
- **Phase 2 — Hide and Seek.** [NULL]×3 + [WIND]×2 + [DARK]×1 = 6 · Weak [MYCELIA][VITREOUS][TACHYON] · keys `[SHIELD NULL->MYCELIA (-2)]`, `[SHIELD WIND->VITREOUS (-1)]`, `[SHIELD DARK->TACHYON (-2)]`. He phases to 5% translucency and hides in the white; find him by listening to the music box's stereo direction. Sera's duplicate token shows his echo from 2 s ago.
- **Phase 3 — Porcelain Spill.** [NULL]×2 + [MYCELIA]×2 + [SWORD]×2 = 6 · Weak [FERRO][ASTRAL][GUILE] · keys `[SHIELD NULL->FERRO (-3)]`, `[SHIELD MYCELIA->ASTRAL (-2)]`, `[SHIELD SWORD->GUILE (-1)]`. He carries the ash-porridge bowl across the void; a spill spawns VHS Fog. Cassia's polarity steadies the bowl; Glenn steals the wobble. Sera's Chronoslip cost is waived while her hand is over his. A perfect 15 s carry drops porcelain_stress from 72 to 20.
- **Phase 4 — Lullaby.** No plates. Hold Sync Hold in rhythm for 24 beats (two cycles at 72 BPM) to finish the music box. Afterwards Vaelos joins as the bonus member (element NULL_LEARNING; see [Character Kits](#10-character-kits)).

**Ending 4 — Borrowed Future, the True Ending (Chapter 13).** **The Chrono Ledger Composite** (Time Debt made enemy). Lv 81–99 · HP 220,000 · Requires `sera_phase_out_voluntary_count ≥ 1` before Chapter 9 as well as the Chapter 9 Voluntary_40.

- **Phase 1 — Filament Guardian: The Warranty Wall (Lv 81–84).** `[SHIELD 24 -> 16 (-8) -> BREAK!]`, second line `[SWORD][FERRO][?]` (the unknown is [AURA]) · Weak [SWORD][ASTRAL] · Resist [VOLT][STATIC]. Every 6 s a Mercury Pulse sound ring expands; hits magnetize metal characters and hitch their next action.
- **Phase 2 — Vaelos, Mortal Choice (Lv 85–89).** Stacked plates `[SHIELD 36 -> 24 (-12)]` then `[SHIELD 24 -> 8 (-16)]` · Weak [AURA] (2.6×) · [VITREOUS] · [FERRO] (2.0×). He does not attack; he mends the party (each mend costs him 10% of his mortal HP). ASTRAL hits heal him. He must be Broken twice, with AURA techniques, to convince him to stay mortal.
- **Phase 3 — Sera's Borrowed Future (Lv 89–94), the True gate.** No enemy; a falling floor. Every gauge sits frozen at 99.0. Prompt: phase out voluntarily. Sera Rewinds herself twice; the Ledger prices the two Rewinds so that the second lands exactly on 40%, wherever she started. Her own plate: `[SHIELD 0 -> 0 (VOLUNTARY) -> BREAK!]`, weak tag `[REMEMBER]`: target the memory by holding focus on her for 2 s. For 2 turns the player controls only Crono, galaxy chest open; Father Tank fires on its own. Declining loops the fight back to Phase 1.
- **Phase 4 — Three Fathers, One Borrowed Future (Lv 94–99).** `[SHIELD 54 -> 36 (-18)]`, `[SHIELD 36 -> 18 (-18)]`, `[SHIELD 18 -> 0 (-18)]`, three stacked plates in U0 watercolour, U2 clay and U7 gold leaf · Weak [ASTRAL][TACHYON][AURA] (2.6× at Boost Lv3). All nine characters are present as 14% ghosts. The finisher is the Triple **Family Porcelain — All Three Fathers** (Crono + Sera + Vaelos Child).

**Ending 5 — Porcelain Silence (Chapter 17).** **Crono's Reflection.** HP 300,000 (Ruin scaling active: a deliberately long fight for the despair route) · 24 plates across four phases, all keyed · Tags [NULL][ASTRAL][RUIN] · immune to physical hits · Weak [TACHYON][VITREOUS][FERRO]. Crono enters at −60% ceiling with Ruin Decay stacks at 10 (this ending lifts the usual 3-stack cap).

- **Phase 1 — The Doll (100–75%).** 6 plates: `NULL->ASTRAL (-2)`, `ASTRAL->RUIN (-4)` (needs a charged Astral Smear Dash), `RUIN->NULL (-3)`, `NULL->ASTRAL (-2)`, `ASTRAL->RUIN (-3)`, `RUIN->NULL (-5)`. Marle offscreen: "That's not you. That's what you let Bekkler make."
- **Phase 2 — The Collection (75–40%).** 8 plates: `RUIN->ASTRAL (-4)` (weak [VITREOUS]: Marle's vitreous arrow), `ASTRAL->NULL (-2)`, `NULL->RUIN (-3)` (weak [FERRO]), `RUIN->ASTRAL (-3)`, `ASTRAL->NULL (-2)`, `NULL->RUIN (-4)` (weak [TACHYON]), `RUIN->NULL (-3)`, `NULL->ASTRAL (-6)`. Mercury orb joints leak across the arena. He heals if a plate is not Broken within 12 s. Sera's empty mask on the floor: "Dad, you're leaking stars."
- **Phase 3 — The Conduit (40–10%).** 6 plates: `RUIN->NULL (-5)` (weak [VITREOUS][TACHYON]), `NULL->RUIN (-4)`, `RUIN->ASTRAL (-6)` (weak [FERRO]), `ASTRAL->RUIN (-5)`, `RUIN->NULL (-4)`, `NULL->ASTRAL (-7)` (all three weaknesses within 10 s). The Mammon Siphon pulls; Chronoslip Escape costs 5% per second spent slipping.
- **Phase 4 — Porcelain Silence (10–0%).** 4 plates `[SHIELD RUIN->RUIN (-99)]`. Unbreakable by damage. Stand still for 12 seconds. Any attack resets them.

**Ending 6 — Mycelia Bloom (Chapter 18).** **Bloom Matriarch — Negotiation, Not Combat.** 28 plates across three phases; each plate is an argument she holds · Plate types [MYCELIA][VITREOUS][DIVINE] cannot be shaved by weapons, only by Xyloph's Tether empathic pulse and by showing proof (flags) · Weak [FERRO][ASTRAL][RUIN] (in negotiation, what she is vulnerable to hearing about).

- **Phase 1 — The Germination Argument.** 10 [MYCELIA] plates. Pulse the Tether in rhythm with her 12 fps breathing (−2 per correct pulse; spam makes [VITREOUS] harden and closes her). Present `Arris_Dome_Sleeping` proof (−5). The Ferro memory, R-66Y's lullaby, triggers MEMORY_PULSE (−7 and the transition to Phase 2).
- **Phase 2 — The Hyphal Memory.** 10 [VITREOUS][DIVINE] plates. She shows timelines where you killed. Hold the Tether while Chronoslip is active (5% per second) and press Listen (a no-damage action): −1 per 3 s held. Showing `Moon_Sleep` proves humans can rest without taking.
- **Phase 3 — The Bloom.** 8 plates. Every flag the player set toward mercy (Seed of Doan grown, Scholar, Arris Sleeping, R-66Y Rewound, Moon Sleep) removes 1 plate when shown; Tether mastery removes the rest. No damage is ever dealt. Result: `MYCELIA_GLOBAL_POOL_OPEN` and the permanent Atrium Divinity Field (+1 plate per 5 s; +0.2 regeneration carried into every future new game).

**Ending 7 — Ashen Jester (Chapter 19).** **Cyrus the Marionettist — Encore.** 30 plates across four phases (10 / 8 / 7 / 5) · Plate types: [GUILE] illusion plates (need honesty or area hits), [SMOKE] dodge plates (need wind or water), [RUIN] cursed gold plates (need VITREOUS) · Weak [SWORD][VITREOUS][TACHYON]. HP is low on purpose; the fight is decided by threads and honesty.

- **Phase 1 — The Calliope Entrance.** HP 18,000 · 10 [GUILE] plates · Weak [SWORD]. Each step spawns a Leg Mechanism add that chips 1 plate off a party temporary shield if not cleared. Glenn's Masamune-hilt cut deals 2×; Crono's ordinary sword 1.5×.
- **Phase 2 — The Encore of Valor.** HP 15,000 · 8 mixed [SMOKE][RUIN] plates · Weak [VITREOUS]. Every party member has a visible thread to his fingers. Cut the wrong (kin) thread and the party loses all BP and that ally is Broken (cannot act for their next turn, DEF −50%).
- **Phase 3 — Vaelos Reveals.** HP 12,000 · 7 [RUIN] plates · Weak [TACHYON].
- **Phase 4 — Strings Cut Inside.** No HP bar · 5 [GUILE] plates that only honest lines shave (each honest line −1). Attacking instead restores his plates and applies a 40% phase-out backlash to the whole party. The final strike is Glenn cutting his own strings to Cyrus.

**Ending 8 — Null Erasure (Chapter 20).** **Omega-Spekkio — Final Void.** HP 99,999, damage gated to phase thresholds · Dual Techs are disabled ("DUAL TECHS: REQUIRE AT LEAST 1 SHARED WEAKNESS. CURRENT: TRUE NULL. NONE FOUND.").

- **Phase 1 — Master.** `[SHIELD 42 -> 41 (-1)]`: 42 plates, one per entry in the fake-weakness pool. He has no weakness and every hit reads `0 (IMMUNE — NO WEAKNESS)`. Sera's NULL creates one fake weakness from the 42-entry pool for 2 turns; every 8 s he casts ERASE WEAKNESS and returns to immune.
- **Phase 2 — Doll.** `[SHIELD 35 -> 0 (-35)]` × 2 in white porcelain. NULL now also adds 10% to Sera's phase-out stack; at 80% she is untargetable for 4 turns, and she must stay phased to keep fake weaknesses alive.
- **Phase 3 — Atom.** Vaelos raises a 20-plate shield around Omega-Spekkio; the party must Break Vaelos's shield, twice. Crono is forced to 20% HP and fights alone while Sera is fully phased. Vaelos is unmade (no death animation; white eats him) — unless Dark > 0, in which case his shield will not Break.
- **Phase 4 — NULL.** `[SHIELD 1 -> 0 (-1)]`. It can only be broken if four fake weaknesses ([SWORD][ASTRAL][FERRO][RUIN]) exist for 2 seconds and Crono, alone, lands all four. He can't. The ending is reached by not breaking it: the white expands to 100% and Sera is erased.

### 14.13 Side quests and post-game

**Cassia-09 Forge Tendril (Seed Assembly crafting boss).** Lv 60 · HP 120,000 · Two Marrow-Umbilical Twins (E80) and the Forge Tendril itself: Shield 12 · Tags [FERRO][FIRE][MYCELIA] · Weak [ASTRAL][TACHYON]. The Tendril only becomes targetable when both Twins are Break-locked together; the quest goal is to pour three waters through the gramophone horn while they are frozen. When assembled, the Seed sprouts at 432 Hz: the pristine Time Egg note.

**Ash-Loom Marionette.** Lv 64 · HP 144,000 · Ash leftovers that learned to puppeteer empty costumes on a U5 puppet stage. Shield 14 + 4 Puppet Adds (4 each) · Tags [GUILE][SMOKE][RUIN] · Weak [SWORD] (cut, 2.0×) · [VITREOUS] (reveal, 2.6× at Lv3) · [TACHYON] (scratch). Phase 1: untargetable above; spawns a Strongman Dummy (Lv 43, 8 plates) and a Ticket-Golem Barker (Lv 45, 6 plates); cut yellow → red → blue to expose the heart thread and Break-lock it mid-swing for a LINE_PIERCE. Phase 2: it drops and fights as an Ash-Knight copy with Shield 16 and the Phase 2 rules of Cyrus. Reward ties into Glenn's hose-arm side quest (`Glenn_HoseArm_Accepted` +30 Light unlocks the hidden third hit of Mercy Leap; `Glenn_IronArm_Denial` +25 Dark grants the Charred Laurel without the Prop Chest farm).

**R-66Y Residual Sorrow + Torso Heart (final side boss).** Lv 70 · HP 160,000 · Robo asks to become the tower and wants his Torso Heart upgraded to 9999 to protect the Atrium.

- **Phase 1 — Lullaby (100–70%).** `[SHIELD 9999 -> 6999 (-3000) -> BREAK!]` · Tags [BLUNT][FERRO][FIRE][RUIN] · Weak [ASTRAL][FERRO][TACHYON]. Ordinary shaves remove 1. Knocking a mask off during a Crack-Slide removes 3,000: 9999 → 6999 → 3999 → 999. The last 999 is the Chapter 1 doll again: 10 real plates hidden in it. Each knocked mask becomes an add that applies one hazard (VHS Fog, Mercury Leak, Grief-Resonance, Ruin Decay, Oil-Blight).
- **Phase 2 — Goliath (70–30%).** Shield 12 · the thoracic ring at full speed; safe spot inside the ring; one barrel glows before each volley.
- **Phase 3 — Torso Heart (30–0%).** Shield 8 · the Heart takes the shield to 9999 when he is Broken for the last time, and the upgrade is complete (the Golden Light Phase 2 siege uses this Heart).

## 15. Progression

### 15.1 Level bands

| Universe | Story | Level band | Notes |
|---|---|---|---|
| U0 Atrium Horologe | Prologue, Chapter 1 | 1–4 | Tutorial. |
| U1 Crimson Shogunate | Chapter 2 | 5–11 | A hard stop at Lv 15 until the U1 ink is stabilized (the Mammon Furnace). |
| U2 Clockwork Ossuary | Chapter 3 | 12–20 (sub-zones to 22) | Player stats cap at 20 inside U2; enemies scale to 35 for sequence-breakers; overcap XP banks (15.6). |
| U3 Saurian Eden | Chapter 4 | 21–30 | Entry Lv 21, enemies 24–30; soft cap 45; players carrying banked U2 levels take +2 Universe Bias (anti-hoard); the Living Papyrus walk trial opens the exit. |
| U4 Drowned Cathedral | Chapter 5 | 31–40 | Cap 60 across U4 and U5. |
| U5 Carnival of Ash | Chapter 6 | 41–50 | |
| U6 1999 A.D. Singularity | Chapter 7 | 51–60 | Final cap 99 is reached only after Debt forgiveness in U7. |
| U7 Bone-Tree | Chapter 8 | 61–70 | |
| U8 Vaelos Heart | Chapter 9 | 71–80 | Vaelos scales 1:1 with the party. |
| U9 Endings, post-game | Chapters 10–20 | 80–99 | |

Boss levels are fixed: R-66Y is always Lv 20, Azar (the Eden Warden) always Lv 27, and so on through [Bosses](#14-bosses). Only Vaelos scales.

### 15.2 Experience

- XP needed to go from level L to L + 1: `10 × L² + 10 × L`.
- A regular enemy of level L gives `0.6 × L² + 10` XP; elites ×3; mini-bosses ×10; bosses ×20. A typical battle of three regulars at the band's level is worth about a fifth of a level.
- Benched characters earn 75% of the XP. Characters join at their chapter's band minimum (Krona Lv 6, Cassia-09 Lv 14, Xyloph Lv 23, Vesper Lv 33, Pierrot-Glenn Lv 43, Static Lv 52, Omega-Spekkio Lv 68), so nobody arrives useless.
- Spared enemies give half XP; their Light lean is the other half of the reward.
- Overcap level-ups play a VHS whine, never a fanfare.

### 15.3 Effective Rank Level

Regular encounters scale to the party:

```
ERL = PartyAvg + UniverseBias + HazardOffset
UniverseBias: U0 0, U1 +1, U2 +3 (12 fps readability compensation), U3 +2, U4–U5 +4, U6–U7 +5
HazardOffset: 0–2 by zone; `Azar_Predator` raises U3's to +4
```

- If the party average is below the zone minimum, enemies scale only down to zone minimum − 2 and drop extra consumables. Never trivialize.
- If the party average is above zone maximum + 5: **Time Shear**. Enemies gain SLOW immunity and +15% Spd and a watercolour-bleed vignette creeps in: a hint to move on.

### 15.4 Party stats

The balancing table is the authoring truth for HP, defence and speed. HP is split by archetype: **Tank** (Crono, Krona, Cassia-09), **Balanced** (Xyloph, Vesper, Pierrot-Glenn), **Caster** (Sera, Static, Omega-Spekkio).

| Lv | HP Tank / Balanced / Caster | Def | Spd |
|---|---|---|---|
| 1 | 120 / 95 / 75 | 8 | 100 |
| 10 | 320 / 260 / 200 | 22 | 108 |
| 12 | 380 / 310 / 235 | 26 | 110 |
| 20 | 620 / 505 / 385 | 42 | 118 |
| 21 | 650 / 530 / 405 | 45 | 120 |
| 30 | 930 / 760 / 580 | 62 | 132 |
| 35 | 1,100 / 900 / 685 | 72 | 135 |
| 40 | 1,350 / 1,100 / 840 | 85 | 140 |
| 99 | 3,400 / 2,770 / 2,100 | 180 | 165 |

Interpolate linearly between rows. Def applies to P.Def and E.Def with archetype shaping: Tanks ×1.15 P.Def; Casters ×0.85 P.Def and ×1.15 E.Def. Spd is shown at U0 rates; each canvas only changes how the speed *looks* (U1 holds make it read about 0.4× as busy, U2 steps 0.2× with jitter, U3 reads 0.5× but feels faster); the gauge always fills at `Spd × 0.25`.

Attack, MP and per-character speed offsets:

| Character | Archetype | P.Atk | E.Atk | MP | Spd offset |
|---|---|---|---|---|---|
| Crono | Tank | 12 + 6.0 L | 6 + 6.0 L | none: he pays with his ceiling | +0 |
| Sera | Caster | 8 + 4.5 L | 10 + 6.2 L | 30 + 2.2 L | +12 |
| Krona | Tank | 14 + 6.4 L | 6 + 5.0 L | 16 + 1.6 L | +4 |
| Cassia-09 | Tank | 10 + 5.2 L | 8 + 5.6 L | 24 + 2.0 L | −8 |
| Xyloph | Balanced | 9 + 5.0 L | 12 + 6.0 L | 30 + 2.4 L | +2 |
| Vesper | Balanced | 11 + 5.8 L | 10 + 5.6 L | 24 + 2.0 L | −4 |
| Pierrot-Glenn | Balanced | 12 + 5.6 L | 6 + 4.6 L | 20 + 1.8 L | +10 |
| Static | Caster | 8 + 4.6 L | 12 + 6.2 L | 28 + 2.2 L | +8 |
| Omega-Spekkio | Caster | 10 + 5.0 L | 14 + 6.4 L | 40 + 2.6 L | −2 |

LUK for everyone: 5 + 0.5 L (Sera and Glenn +5).

Gear is light: each character has a weapon (story upgrades raise its Atk by tiers: the Cobalt Nodachi, Cassia-09's form, Vesper's rose lance), one armour piece and two accessory slots. The relics in [11.14](#1114-relics-that-change-techniques) are accessories.

### 15.5 Enemy stats

| Stat | Regular | Notes |
|---|---|---|
| HP | 30 + 25 L | elites ×3; mini-bosses about 1,000 × L; bosses about 2,250 × L (R-66Y: 45,000 at Lv 20) |
| P.Atk / E.Atk | 12 + 6 L | boss techniques carry base multipliers of 1.2–3.0 |
| P.Def | 2 + 4 L | bosses 5.5 L |
| E.Def | 4 L − 2 | bosses 5.5 L |
| Spd | 90 + 0.6 L | elites +10 |
| Shield | 1–4 plates in U0–U1, 2–8 in U2–U4, 3–14 in U5–U8; elites about 1.5×; boss phases 3–28 | a final boss stack reaches 135 |

At these curves, a regular enemy at the band's level takes three to six ordinary party actions, or one Boosted weakness hit after a Break; a boss takes 25–35 party actions with two or three Breaks.

### 15.6 Banked XP (amber shards)

In U2 the player's effective stats stop at 20. Experience earned past the cap is not lost: it banks as **amber shards**, up to the equivalent of Lv 35. The XP bar turns into amber shards with a VHS whine and the tooltip "Time leaks — spend in U7 Gold Leaf". Banked XP converts back to real experience at Bekkler's shop at 2:1 (50%), or at a U7 Divinity Field or lotus pond at 100%. The final level cap of 99 opens only after Debt forgiveness in U7. Time Debt is memory: you pay it by remembering, not by grinding.

### 15.7 Boost, Ens and cap upgrades

| Upgrade | Source |
|---|---|
| MAX_BP 5 → 6 | Restore all five Crono Memory Shards (atom hunts in U2–U6). |
| MAX_SPEND 3 → 4 (unlocks Boost Lv4 and residual fields) | Close the first Vaelos rift on purpose after U4 (every route reaches it by U6 through the Vapor Memory Core rift). |
| Ens Parry window 4 → 6 frames | Krona teaches it in U1. |
| Ens Parry +2 frames | The Goyama Dojo (`Goyama_Repainted`). |
| HOLD +0.5 s per step | `Central_Eye_Broken`. |
| NULL for Sera and Crono | Kami-Ori's Phase 3 lesson. |
| NULL SHIELD toggle | Omega-Spekkio's Final Dojo, Faceless bout. |

### 15.8 Technique schedule

Every technique's chapter, level or flag is in the Unlock column of the [Tech Library](#11-tech-library). The rhythm: each chapter brings its new party member's kit and two to six Duals with the existing cast; level-gated techniques arrive inside the band (Crimson Seppuku Lv 18, Luminaire Lv 35, Rose Window Lv 38, Prism Refraction Lv 40, Guile Elastic Lv 46, Static's kit Lv 52–60, Unborrowed Time Lv 78, Borrowed Future — True Lv 80); flag-gated techniques (Divinity Field or Reptite Crown, Fractured Lens, Prop Cannon, Slip Backtrack or hz_static_pure, Empress Cannon and Gatling Arm, Origami Requiem and Washi-Hollow Rebirth) arrive with the choice that writes the flag; Triples arrive once their three actors have fought together.

### 15.9 Affinity, leans and Beckons

- **Light** +30 per mercy act; **Dark** +25 per ruthless act; **Prismatic** +15 per intentional causality break (an Amber Rift). Codex leans add +1 per signature resolution, capped at +5 per affinity per universe.
- Thresholds: Light ≥ 90 Golden Light; Dark ≥ 90 Empress Heir; Prismatic ≥ 45 Vaelos Child; 90 / 90 / 45 plus the voluntary 40% phase-out for the True Ending; the other four endings have their own conditions (see [Endings](#1412-endings)).
- Affinity is hidden. The player sees it only as art bleed: Light pulls everything toward U0 watercolour, Dark toward U2 clay and VHS, Prismatic toward the all-styles Amber Rift glitch.
- Every affinity write also grants that many **Beckons** (see [7.7](#77-beckons)).

### 15.10 New Game+

- Levels, techniques, relics and the Codex carry over. Possibility flags reset: a new cycle.
- **+10 bias** to the dominant affinity of the last cycle.
- Sera begins with 5 permanent Translucency Debt: she remembers the loop.
- Having reached Mycelia Bloom once: every Atrium in every future game has +0.2 regeneration and a +1-plate-per-5-s Divinity Field.
- Vaelos (child) joins as the bonus member from the start if the last cycle ended in Vaelos Child.
- `Nine_In_One_Watercolor` keeps the True Watercolor compositor look.
- Omega-Spekkio's dojo re-folds boss movesets for rematches.

## 16. Failure and Recovery

### 16.1 No Game Over

There is no conventional Game Over. When the whole active party falls (Sera phased out does not count as standing), the battle is lost and **Time Debt advances**:

1. Crono loses 5 integrity: he cracks further, permanently, until repaired.
2. Sera jumps the party back along the thread: to the moment before the encounter (enemies reset, party restored to their state at battle start) or, if the player prefers, to the last Atrium checkpoint. Either jump costs the same.
3. The music tape-stops for half a second; the Turn Bar rewinds visibly, watercolour bleeding backward.

Scripted losses (the Fair, when Vaelos descends and Crono's sword passes through him) cost nothing.

### 16.2 KO inside a battle

- A KO'd ally stays on the plane as a fallen body (still terrain). Items, revive techniques, Lotus Reverse and the Prometheus Core (once per battle, blocked at Ruin 2+) bring them back.
- Any ally within 3 m can Swap a KO'd ally out for a benched one.
- If Crono is KO'd, Father Tank lapses and his body shows the flatline crack until revived. If Sera's HP is under 40% when Crono falls, the Lavic Filial Field (U8) moves its redirect to whoever is nearest her.

### 16.3 The Atrium Siege

If Crono's integrity reaches 0, the Atrium Horologe locks and Vaelos lays siege: a playable fail-state event, not an ending.

- The party present at the Atrium defends Robo's Torso Heart for three waves (Lavos-spawn, then Bekkler failures, then Vaelos's own projection with a 22-plate shield that cannot be Broken, only outlasted for 90 s of battle time).
- Holding all three waves saves the hub's vendors; each wave lost costs one vendor family for the rest of the cycle.
- Either way the siege ends with Sera reglazing Crono: integrity returns to 20. The music box tape-stops at 0 during the siege; porcelain_stress hits 100. The cycle records it (`Atrium_Siege` +1): Porcelain Silence (Ending 5) needs it.

### 16.4 What restores what

| Cost | Restored by |
|---|---|
| Crono's Battle Strain | The end of every battle; Wire Loom Mend (10%); Kintsugi Mend; Krona's Ash (2%); Fake Family Photo (20%) |
| Crono's Camp Strain, Glaze Erosion, Ruin stacks | Camp, inn, Atrium bed; Divinity and lotus ponds thaw Ruin 1% per 8 s |
| Crono's integrity | Time Atoms (+0.5), Wire Loom Mend (+0.6 per battle), Kintsugi Mend (+2 per battle), U7 lotus kintsugi (+1 per 8 s), Robo Ribbon (+5), Promise Across Rust (+3), Family Porcelain (+2), Gold Leaf repair (+10 at Light ≥ 90), the Golden Light ending (all) |
| Sera's battle solidity | Her own turns without a TACHYON skill (+2 each); the end of the battle |
| Sera's Translucency Debt | U7 lotus kintsugi (1 per 8 s); U3 Moon Meditation (2 per second, U3 Debt only); Crono's Time Egg at camp (−3) |
| Oil-soak, the visual smear | The Atrium fountain (never the Debt) |

### 16.5 Withdrawing

Withdrawing from a battle (see [Commands](#4-commands)) costs nothing but the fight. Enemies return to their wander routes at full strength.

## 17. Feedback and Audio Hooks

The player must always be able to hear and see what the arithmetic is doing. Every combat event has a sound, a visual, and where useful a rumble, and every canvas says it in its own voice.

### 17.1 Core combat events

| Event | Audio | Visual |
|---|---|---|
| Gauges filling | A watch tick at each battler's own tempo, panned to its marker | Markers in each battler's cadence |
| Sync Hold | The tick stops; a wind chime (the Chrono Trigger save-point nod) | Everything freezes mid-frame; the 35° tactical camera eases closer |
| Shave | Porcelain scratch | Plate numbers tick down |
| Weakness hit | Bell ding (a glass chime) | Bell icon on the plate; in U2 a thumbprint VHS bloom |
| BREAK | Gong + vinyl crack + sub-bass crack + crystalline spill (U2 adds hydraulic hiss, gramophone pop, VHS wobble) | Gold shatter, 0.02 chromatic aberration, the 60 fps gold porcelain flicker, the plate turns gold |
| Rebuild | A rising mainspring whir | Thin gold bar filling at 18% per second |
| Boost | Gaspar's coin, pitched up a step per level | Lv3+: style bleed (watercolour afterimages, clay normals popping, gold leaf flecks) |
| Perfect Frame | A single high chime | Gold sheen across the hit |
| Telegraph | A rising tone locked to the inward scan wave | Cyan → orange decal, pulse sin(TIME × 6) |
| BP stolen | Laugh track pitch-drops 3 semitones; a reversed coin | The coin flies to the thief's counter |
| Time Debt paid | Ceramic tink; Crono's wrist crack | The heart-string from Crono's chest to Sera flickers red |
| Defeat | Half-second tape stop, then the Turn Bar rewinding | Watercolour bleeding backward |

Camera: battles sit at the 35° tactical angle. On truth beats (a story reveal mid-fight, Sera's voluntary phase-out, emotional Breaks), the FOV lerps 32° → 24° over 0.45 s with depth of field (far 12.0, near 0.05).

Rumble: Break heavy; weakness light double; Sync Hold none: stillness.

### 17.2 Character voices

| Character | Combat sounds |
|---|---|
| Crono | Porcelain tink and wind-chime crack when hit; ceramic-tap steps; **no grunts under 50% HP**; Time Egg hum 432 Hz pristine, 220 Hz past 60% crack; his leitmotif's second note held 300 ms too long. |
| Sera | Rewind: reversed tape, harp, a Crono crack. Phase-out: low-pass, one U7 gold chime, a whispered "Mama?". Borrowed Future: a backward ratchet, then a 1980s digital alarm. Seven desynced footstep layers. |
| Krona | Brush scratch, iron clack; gourd slosh, wet gulp, inverted Lavos whale cry; brush-on-paper slashes; a hanko-seal "don" parry. |
| Cassia-09 | Gramophone crackle pre-roll; binaural mercury; 50 Hz loom hum when Lucca surfaces; 440 Hz Mercury Pulse cleanse; MP drain bends −200 cents. |
| Xyloph | Koto pluck and inhale on tether; 35 Hz net hum under cicadas; Burst: one second of silence, then a wind-chime cascade. |
| Vesper | C-minor plate chime at 60 BPM; glass harp; Rose Window is a broken organ chord from a flooded church. |
| Pierrot-Glenn | Muted trumpet wah and cash-register ding on a steal; boing and slide-whistle per stretch. |
| Static | Techniques open with a 0.5 s white-noise crash into tone; anime hit-stop and white flash on crits; a shortwave sweep and helmet latch on Tune. |
| Omega-Spekkio | NULL: a deep inhale, then tape-stop silence. |
| Vaelos | Heartbeat 68 BPM against the hub's 72; a contrabassoon C–G♭ under every universe; Crono's clean young voice, no reverb. |

### 17.3 Mix parameters (RTPCs)

| RTPC | Drives |
|---|---|
| porcelain_stress (0–100) | The shared porcelain bus (scratch, bell, crystalline spill) and the hub music box: it loses its C4 tine at 60, misses every third note at 20, tape-stops at 0. Clock gear grind wetness, tape-wobble detune. |
| translucency (100–0) | Sera's double-voice layer count (1–7 ghosts) and the tachyon chirp / seven-layer whisper. |
| vhs_tracking | U2 VHS wobble, BLIND intensity. |
| mycelia_shared | The net hum level; the Fake Carrier Burn's vinyl crackle. |
| bp_stolen | Laugh-track pitch, calliope detune. |
| shave_bonus | Crystalline spill brightness when a Boost Lv3 bonus or other flat bonus lands. |
| Camera_FOV | Low-pass 0–800 Hz: wide = 400 Hz windy and distant, narrow = 800 Hz intimate porcelain creak. |
| glow_intensity | Loudness of U4 music; breath meter = reverb wetness. |
| Debt bus | Vinyl crackle and warble rising with Crono's crack mask. |

### 17.4 Damage numbers by canvas

U0 numbers bleed like wet watercolour; U1 numbers are brushed and hold six frames; U2 numbers wobble with the thumbprint pulse; U3 numbers are clean ligne-claire outlines with speed lines that linger 8 frames; U4 numbers refract; U5 numbers arrive on BAM! and POP! cards; U6 numbers hit-stop with a white flash; U7 numbers are gold leaf flakes that settle on the HP bar, rebuilding the ceiling.

### 17.5 Readability and accessibility

- The plate always shows the math, and telegraphs read without colour (the inward scan wave carries the timing); Reduced flicker and Flow speed ([3.7](#37-settings)) change presentation and pace, never rules.
- Every technique must be readable at 128 px at its native frame rate, and no two techniques share the same tags, shape and radius.

## 18. Godot 4.7 Implementation Notes

Engine: Godot 4.7.x, Forward+ renderer, one rendering pipeline and one CompositorEffect stack for every canvas. Gameplay reads data and state; it never reads the art style.

### 18.1 Scene and node architecture

```
Main (Node3D)
├── World (the current universe map: NavigationRegion3D, terrain, props, encounter zones)
├── Party (Node3D)                       # field leader + followers, each a CombatActor
├── PossibilityEngine (autoload)         # flags, affinity, Beckons, cycle, save
├── BattleSandboxBootstrap (Node3D)      # spawns/dissolves the 28×28 battle plane
│   ├── BattlePlane (MeshInstance3D)     # PlaneMesh 28×28, 648 tris, conforming to terrain
│   ├── TelegraphLayer (decals)          # cyan→orange AoE decals, residual fields, terrain
│   └── HybridBattleCoordinator (Node)   # timeline, battle_time, commands, resolution
│       ├── BoostBank (Node)             # the shared BP pool
│       ├── TacticalPositioner3D (Node)  # shape geometry, hit counts, snap, previews
│       └── BattleHUD (CanvasLayer)      # Turn Bar, Shield Plates, previews, prompts
└── CompositorStack                      # 4-layer CompositorEffect chain, per-universe LUT
```

**CombatActor** (CharacterBody3D) with child components:

| Component | Holds | Notes |
|---|---|---|
| CombatantStats | actor_id, level, HP/MP, P.Atk, E.Atk, P.Def, E.Def, Spd, LUK, tags, vulnerabilities, resistances | `CombatantStats.of(actor)` helper; never read stats off the body |
| ShieldComponent | max/current plates, weaknesses, revealed, resist/nullify/immune/absorb, broken state, keyed plates, regeneration rules | per-strike evaluation; `preview_action()` shares the hit's code path |
| StatusComponent | active statuses with battle-time durations or turn counts, stacks | ticks only on battle_time |
| TimeDebtComponent | Crono only: integrity, battle strain, camp strain, crack state | drives `crack_mask` and the porcelain_stress RTPC |
| SolidityComponent | Sera only: Translucency Debt, battle solidity, thresholds crossed this battle, ghost count | drives the translucency RTPC and ghost layers |
| CanvasStyle | the character's native fps, material overrides, quantized drift uniform | purely visual |
| NavigationAgent3D | field movement and enemy drift | disabled on Break |
| BreakHull (Area3D + CollisionShape3D) | the 112% hull used as terrain while Broken | enabled only while Broken or as a statue |

Enemies add an **EnemyBrain** (behaviour script chosen by the EnemyResource) and an **EnemyShieldPlate** (UI anchored above the head).

### 18.2 Data-driven resources

Everything a designer tunes lives in `.tres` resources under `res://data/`:

| Resource | Key fields |
|---|---|
| `TechResource` (`data/techs/`) | `tech_id`, `display_name`, `tier` (SINGLE / DUAL / TRIPLE / ULTIMATE), `actor_ids`, `tags: Array[StringName]`, `shape` (SINGLE, LINE_PIERCE, CIRCLE, SELF_AURA, CONE, CROSS, DELTA, CAGE, SPLIT_CONE, FATE_LINE), `radius`, `length`, `width`, `inner_radius`, `beams`, `aoe_scale`, `hit_count`, `base_per_hit`, `uses` (PHYSICAL / ELEMENTAL / ASTRAL / BEST), costs per actor (`mp`, `strain_pct`, `camp_strain_pct`, `integrity`, `solidity_pct`, `bp_min`), `lv2_debuff` (or element default), `lv4_field` (or element default), `flat_shave_bonus`, `wind_up_s`, `unlock` (chapter / level / flag / drop), `requires_flags`, `effect_script` (for the specials: Rewind, Borrowed Future, NULL, Miura Fold...) |
| `EnemyResource` (`data/enemies/U0`–`U9/`) | `enemy_id` (E01...), name, universe, level, HP/Atk/Def curve overrides, `shield`, `tags`, `weak`, `resist`, `nullify_shave`, `immune`, `absorb`, `lean`, `keyed_plates`, `plate_rules` (regen, refill_once, shared_group, belief_number, break_immune_until), `brain`, `break_effect`, `drops` |
| `BossResource` (`data/bosses/`) | fixed level, HP, phases (`BossPhaseResource`: HP window, shield, tags, weak, resist, mechanics scripts, possibility branch id), arena hazards |
| `StatusResource` (`data/statuses/`) | id, duration kind (seconds or turns), stacks, effect hooks, cleanse tags |
| `HazardResource` (`data/hazards/`) | id, universe, trigger (zone, tile, timer), effect |
| `UniverseProfile` (`data/universes/`) | id U0–U9, fps, LUT, plate dressing, dissolve effect, level band, Universe Bias, hazard set |
| `CharacterKitResource` (`data/characters/`) | archetype, stat curves, vulnerabilities/resistances, move range, commands, passives, techniques by unlock |
| `FlagDef` (`data/flags/`) | flag id, two (or three) exclusive states, affinity writes, Beckons, NPC and shop deltas |

Tags are `StringName`s (`&"ASTRAL"`, `&"TIME_DEBT"`, `&"SWORD"`...). Keep one validation pass that rejects unknown tags, Duals without two actors, and any two techniques that share tags + shape + radius.

### 18.3 Canonical constants sheet

```gdscript
# combat_constants.gd — every value is a starting point to tune for feel
const PLANE_SIZE := 28.0                 # metres, 648-tri PlaneMesh
const TACTICAL_PITCH_DEG := 35.0
const FOV_EXPLORE := 32.0
const FOV_TRUTH := 24.0
const FOV_LERP_S := 0.45

const GAUGE_MAX := 100.0
const SYNC_HOLD := 99.0                  # party gate; any party gauge here freezes all others
const ENEMY_GATE := 100.0
const SPD_TO_GAUGE := 0.25               # speed = Spd × 0.25 gauge/s
const DRIFT_AMPLITUDE := 0.5             # sin(battle_time + offset) × 0.5 per second
const PARTY_START_GAUGE := Vector2(20, 50)
const ENEMY_START_GAUGE := Vector2(0, 40)

const BOOST_LV3_SHAVE_BONUS := 1
const STATE_MULT := {"normal": 1.0, "lv3": 1.3, "weak": 2.0, "weak_lv3": 2.6}
const CRIT_MULT := 1.5                   # the only crit multiplier; Broken = every hit crits
const BREAK_DEF_MULT := 0.5              # DEF −50%
const BREAK_RECOVERY_DELAY_S := 3.0
const SHIELD_REBUILD_PCT_PER_S := 18.0   # % of max shield per second (rebuild bar 0–100)
const BREAK_COLLISION_INFLATION := 0.12
const BREAK_RESUME_BLEND_S := 0.4
const BROKEN_STATUE_S := 8.0
const RESIST_MULT := 0.5
const PERFECT_FRAME_MULT := 1.15
const AOE_FALLOFF := [1.0, 0.75, 0.5, 0.25]

const START_BP := 1
const MAX_BP := 5                        # 6 after the Crono Memory Shards
const MAX_SPEND := 3                     # 4 after the first Vaelos rift
const BOOST_POWER := [1.0, 1.9, 2.8, 3.7, 4.5]
const BOOST_SCALE := [1.0, 1.25, 1.5, 1.75, 2.0]
const RESIDUAL_FIELD_S := 6.0

const SYNERGY_DUAL := 1.6
const SYNERGY_TRIPLE := 2.2
const SYNERGY_THREE_UNIVERSES := 1.25
const PARTY_SYNERGY_SERA := 1.10
const PARTY_SYNERGY_PHASED := 0.85

const SERA_REWIND_COST := 5.0            # % solidity
const SERA_HOLD_STEP := 5.0              # % solidity per +2.5 s
const SERA_HOLD_BREAK_EXTENSION_S := 2.5
const SERA_BORROWED_FUTURE_COST := 10.0  # +10 below 50%
const SERA_PHASE_THRESHOLD := 40.0
const SERA_PHASE_TURNS := 2
const SERA_THRESHOLDS := [80.0, 60.0, 40.0, 20.0]
const SERA_DEBT_CAP := 55.0
const BORROWED_FUTURE_GAUGE_PUSH := 0.30

const CRONO_JUMP_COLLARBONE := 0.4       # integrity per gate jump
const CRONO_HAIRLINE_REWIND_HP := 0.05
const CRONO_DEFEAT_INTEGRITY := 5.0
const CRONO_CEILING_FLOOR := 0.10
const REINFORCED_REDUCTION := 0.5        # 0.8 from Family Porcelain, for 3 jumps

const RUIN_STACK := 0.15                 # max-HP ceiling per stack
const RUIN_STACK_CAP := 3
const OIL_BLIGHT_PERIOD_S := 15.0        # −1 shared BP
const MERCURY_SLOW := 0.5                # gauge and movement, max 2 stacks
const BLIND_ACCURACY := -0.30
const GRIEF_MP := 2                      # per 10 s per stack
const DIVINITY_PERIOD_S := 5.0           # +1 temporary plate, cap 20% max HP
const DIVINITY_RUIN_THAW := 0.01         # per 8 s
const MYCELIA_SHARE := 0.15
const MYCELIA_SHARED_POOL := 12
const LIGHT_STACK_CAP := 5
const PHOTOSYNTHETIC_DR := 0.70
const PROMETHEUS_REVIVE_HP := 0.20       # costs 1 BP, blocked at Ruin ≥ 2
const PROMETHEUS_CORE_BECKONS := 150
const GLENN_STEAL := [1, 1, 2, 3, 3]     # by Boost level
const TELEGRAPH_PULSE_HZ := 6.0          # sin(TIME × 6)
```

These match the canon sheet's combat values: Sync Hold 99.0; shave law; 1.0 / 1.3 / 2.0 / 2.6; Break DEF −50%, crit ×1.5 with no separate Break multiplier, 3.0 s delay, 18 per second rebuild, 0.4 s blend, +12% hull, 8 s statue; HOLD +2.5 s per 5%; shared BP with MAX_BP 5 (6), MAX_SPEND 3 (4) and the 100/190/280/370/450% table; shape scale 1.0 + boost × 0.25; the telegraph pulse; the status numbers; the Prometheus Core rules.

### 18.4 The battle loop

```
state EXPLORATION -> contact -> TRANSITION_IN (plane spawn, camera lerp; nothing waits on an empty tween)
TIMELINE_TICK:
    battle_time += delta × flow_speed
    for each battler not Broken: gauge += (speed + sin(battle_time + offset) × 0.5) × delta × gauge_mult
    advance wind-ups, statuses, hazards, fields, Break timers, rebuilds (all on battle_time)
    enemies at ENEMY_GATE act (instant, or start a telegraphed wind-up)
    if any party gauge >= SYNC_HOLD (highest overshoot first; party wins exact ties):
        BoostBank.add(1); state = COMMAND_WAIT
COMMAND_WAIT (battle_time frozen):
    move preview, shape preview, plate preview; choose action, Boost level, partners from the Ready Pool
    Sync Hold command -> park at 99.0, re-prompt the parked ally after every party action
EXECUTING_ACTION (battle_time frozen): resolve strike by strike; Breaks mid-action apply to the remaining strikes
-> victory / defeat checks -> TIMELINE_TICK
VICTORY / DEFEAT -> rewards or Time Debt -> TRANSITION_OUT (plane dissolves, exploration unlocks)
```

Use a single `battle_time` float owned by the coordinator. Do not use `Engine.time_scale` or the SceneTree pause for Sync Hold: the HUD, the camera and idle animations must keep moving while battle time is frozen.

### 18.5 Pitfalls

- **ShapeCast3D stops at its first collision** unless you read every result (`get_collision_count()` and iterate) and set `max_results` high enough; and it depends on collision layers and a physics frame. Count hits with analytic XZ geometry against the known battler list (deterministic and testable headless); keep ShapeCast3D or a RayCast3D only for cover and line-of-sight against static geometry.
- **`NavigationAgent3D.target_position` does not move anything.** Read `get_next_path_position()` and move the body yourself (`velocity` + `move_and_slide()`). With no baked navmesh the agent returns the actor's own position: fall back to a straight line. On Break set velocity to zero and turn avoidance off; restore both with the 0.4 s blend.
- **Typed arrays are invariant** in Godot 4: an `Array[Node3D]` cannot be passed where `Array[Node]` is declared. Type helper parameters exactly (`Array[CombatantStats]`).
- **`is_connected(callable.bind(...))`** compares a new bound callable each time and always fails. Store the bound callables and disconnect those exact objects at battle end.
- **`await tween.finished` on a tween with no tweeners never returns.** Only create the camera tween when there is a camera; never await an empty tween.
- **Frame-rate-dependent drift:** a per-frame `sin(...) × 0.5` without `delta` changes with the frame rate. Multiply by `delta`.
- **Timers on wall-clock time** (`SceneTreeTimer`, `Timer` in idle mode) keep running during Sync Hold. Drive every combat timer from `battle_time`.
- **Ties at the gate:** process the highest overshoot first, party before enemies on an exact tie; never let list order decide.
- **Per-strike resolution:** evaluate each hit separately; a Break on hit 1 makes hits 2+ land on a Broken target. Count each distinct tag once per strike.
- **Shield preview and hit must share code** (`ShieldComponent.preview_action()` calling the same function the hit uses), or the plate lies.
- **Stepped animation is visual only:** quantize the material's time uniform (`floor(TIME × fps) / fps`) and the sprite frame, never the physics or the gauge. Keep physics interpolation on for 60 fps bodies; 12 fps clay steps come from the shader and sprite sheet.
- **`look_at` with overlapping positions** errors: compute directions on the XZ plane with a fallback forward vector.
- **The Break hull** is a separate Area3D/shape scaled 1.12, enabled only while Broken (and for the 8 s statue), on a layer allies collide with; don't scale the CharacterBody3D's own collider.
- **CompositorEffect order:** LUT → edge/quantization → bloom/glow → VHS/chromatic + quantized drift. The Break's shared 60 fps gold render is a global uniform flip for the Break flash, not a second pipeline.
- **Save data:** Possibility flags, affinity, Beckons, integrity, Translucency Debt, Corruption, Cassia-09's Synergy/Resentment and the siege count persist; flags never reset without a New Cycle.

### 18.6 How the existing prototype maps to these laws

The repository ships an earlier combat prototype under `prototype/` (built and headless-tested in Godot 4.3: timeline with Action Gate and Sync Hold, Boost, per-strike Shield/Break, analytic AoE geometry, TechResource validation, basic attack, Defend, MP, victory and defeat, encounter trigger, camera FOV/DOF transition, Boost exposure dip, enemy drift, rewards, an automated test runner). Reuse its structure; change its rules to match this bible:

| Prototype piece | What it does now | Change to match the laws |
|---|---|---|
| `combat_types.gd` | `DamageType` enum (SWORD, SPEAR, DAGGER, AXE, BOW, STAFF, FIRE, ICE, LIGHTNING, WIND, LIGHT, SHADOW) | `StringName` tags ([9](#9-elements-tags-and-the-elemental-canvas-clash)); keep `BattleState`. |
| `shield_component.gd` | Weakness 1.3×, Break 2.0×; recovery restores shields instantly | 2.0× / 2.6× weakness, 1.3× Lv3 shaving; Broken = DEF −50% + ×1.5 crits; lock / rebuild / resume timers, keyed plates, plate rules, resists. Keep per-strike evaluation, the duplicate-tag guard and `preview_action()`. |
| `boost_component.gd` | A BP bank per character, 0–5, spend 0–3, no gain the turn after boosting; Dual BP drawn from participants | One shared **BoostBank** for the party: start 1, +1 at every ally gate arrival, MAX_BP 5/6, MAX_SPEND 3/4; Dual and Triple Boost spends from the same pool. The "no gain after boosting" rule is gone. |
| `tech_resource.gd` | per-strike base, synergy, hit_count 1–16, boost `1 + 0.9 L`, shapes SINGLE / LINE / CIRCLE / AURA / CONE, AoE +0.25 per level | Boost table 100–450%; the new shapes; strain / integrity / solidity costs; Lv2 debuff, Lv4 field, wind-up, unlocks, flags; ASTRAL averaging. Keep the validator. |
| `combatant_stats.gd` | HP/MP/Atk/Def/speed (default 25 gauge/s), weapon type, XP | Spd stat with `speed = Spd × 0.25`; LUK; vulnerabilities and resistances; the Progression curves; TimeDebtComponent and SolidityComponent beside it. |
| `tactical_positioner_3d.gd` | Analytic XZ geometry for targets and preview outlines | Keep the analytic approach for hit counts; add snap-to-best-hits, manual offset, cover checks, the new shapes and AoE falloff. |
| `hybrid_battle_coordinator.gd` | Gate at 100 for all; Break pushes the gauge to −100 (one lost turn); Ready Pool with re-prompt fix; enemy drift pauses while anyone waits; `max_shield_shave_per_action` knob | Party gate 99.0 freezing every gauge; a `battle_time` clock; Break timers instead of −100; enemy wind-ups; Swap, Spare, Withdraw, Ens Parry; shave knob unlimited. |
| `enemy_wander.gd` | Drift between wander points, paused while the Ready Pool is occupied, skipped for Broken enemies | Keep; feed it NavigationAgent paths over the battle plane. |
| `battle_rewards.gd` | Full XP to each standing member | Active members full, benched and KO'd 75%; spared enemies half; overcap XP banks as amber shards in U2. |
| Prototype cast (Crono / Lucca / Frog stand-ins) and its post-ending, no-time-travel premise | — | Replace with the nine canonical characters and the multiverse premise. |
| Prototype decisions (shave cap 3 per action, Break = one lost turn, Wait mode, `10·L² + 10·L` XP, +8% HP per level) | — | Shave uncapped; Break by timers; Sync Hold makes every decision a Wait; XP formula kept; growth replaced by the Progression balancing table. |

### 18.7 Acceptance checks

Automate these in the headless test runner; every one must pass before content work builds on it.

1. A non-weak, non-Boost hit gets no weakness or Lv3 multiplier (state 1.0).
2. A matching multi-hit attack removes `matching_count × hit_count` plates; duplicate tags on one strike count once.
3. Boost Lv3 adds exactly one flat shave after the matching term, once per action per target, only if something matched.
4. Shave never takes a shield below 0.
5. At shield 0 the target Breaks immediately: it cannot act, its gauge is 0 and frozen, its NavigationAgent velocity is zero and avoidance off, and later strikes of the same action see it Broken.
6. A Broken target takes DEF −50% and every hit is ×1.5 critical; no other Break multiplier exists.
7. Rebuild cannot begin before 3.0 s of battle time, then fills at 18% of max per second; the Break ends only at 100%; the body resumes with a 0.4 s blend.
8. Sera's HOLD adds exactly 2.5 s of lock per 5% solidity and charges it.
9. A target killed while Broken stays 8 s as a statue with the 112% hull.
10. When any party gauge reaches 99.0, every other gauge and every battle timer freezes until a command resolves.
11. Battle time does not advance during Sync Hold, action execution or pause.
12. BP never exceeds the unlocked cap and an action never spends more than the unlocked spend cap; BP is one shared pool, +1 per ally gate arrival.
13. Boost power and shape scale follow 100/190/280/370/450% and 1.00/1.25/1.50/1.75/2.00; Lv2 applies a debuff, Lv4 a residual field.
14. Sera's Rewind always charges 5% solidity and restores HP, gauge and position to the target's last turn start.
15. Crossing 40% solidity removes Sera from action for exactly 2 turns, untargetable, with party synergy 0.85; each threshold fires once per battle.
16. Crono's ASTRAL techniques never spend MP; they lower his max-HP ceiling for the battle, and the ceiling never falls below 10% of base.
17. While Crono is hairline or worse, each Sera Rewind costs him 5% max HP and cannot KO him.
18. Ruin cannot reduce the HP ceiling beyond three stacks (−45%) outside Porcelain Silence.
19. Oil-Blight drains the shared BP pool, not a character meter, and blocks Ultimates while active.
20. Mercury SLOW halves gauge fill and movement and stacks to 2 at most.
21. The Prometheus Core revives once per battle at 20% HP, charges 1 BP, and never fires for an ally at Ruin 2+.
22. Glenn's steals never exceed 3 BP per action (the Ash Ringmaster's Break excepted) and never duplicate BP.
23. The shield preview equals the shave the hit then does, for every technique and shape.
24. The TacticalPositioner counts every battler inside a shape, not only the first.
25. Defeat never shows a Game Over: integrity −5 and a rewind; integrity 0 starts the Atrium Siege.
26. Art-style timing changes visual cadence only; swapping every universe's fps and LUT leaves every combat number identical.

## Appendix A. Audit Notes

Where the source material disagreed with itself, this is what the bible chose and why. Numbers that were converted keep their originals here, so nothing is lost.

| # | Topic | What the sources said | What this bible does |
|---|---|---|---|
| 1 | Shield scale | The Extreme Enemy Codex wrote shields on a 30–400 scale; chapter rosters and the original architecture use plates (1–45). | Plates everywhere. Codex values divided by 20, rounded half up: E01 60→3, E02 90→5, E03 50→3, E04 40→2, E05 80→4, E06 45→2, E07 110→6, E08 35→2, E09 140→7, E10 70→4, E11 180→9, E12 220/240/260→11/12/13, E13 130→7, E14 160→8, E15 30→2, E16 100→5, E17 300/320/350→15/16/18, E18 85→4, E19 95→5, E20 120→6, E21 150→8, E22 340/360/400→17/18/20. The codex's "X → Y (−Z)" examples were previews of single attacks and are not stored. |
| 2 | Break recovery | "Recovery 18 shield per second after 3.0 s." | 18% of the shield per second on the gold rebuild bar (the original architecture's 0–100 recovery gauge at 18 per second). Literal plates per second would end every Break instantly; the bar gives the ~8.6 s Break the chapters describe. |
| 3 | Break length | The prototype: Break = one lost turn (gauge to −100). | Timers: 3.0 s lock, rebuild, 0.4 s blend; the gauge drops to 0 and stays frozen. |
| 4 | Broken damage | Architecture, prototype and the Vaelos Child chapter: "Broken 2.0×". | Canon: DEF −50% and every hit a ×1.5 critical; no separate Break multiplier. |
| 5 | Weakness multiplier | Prototype and the progression sheet: weakness 1.3×. | Weakness 2.0× (2.6× at Lv3); 1.3× is the Lv3 multiplier while shaving a non-weak target. |
| 6 | Gauge drift | `sin(TIME + offset) × 0.5` with no unit. | Applied per second (× delta). At 25 gauge per second it is a breath, not a dice roll; `DRIFT_AMPLITUDE` is the knob. |
| 7 | Seconds or turns | Hazards and statuses were written in seconds; the original story proposed per-turn versions for a Wait mode. | Battle time: seconds that stop during Sync Hold, actions and pauses. Statuses written in turns count the affected unit's own actions. |
| 8 | Speed | `speed × delta` with no stat scale; prototype default 25 gauge per second; the progression table gives Spd 100–165. | `speed = Spd × 0.25`: Spd 100 → 25 gauge per second. The per-canvas Spd factors (U1 ×0.4, U2 ×0.2, U3 ×0.5) are presentation only. |
| 9 | BP names | Brave Points, Bravado Points, Beckon Points, BP Bank. | BP is always Boost Points. **Beckons** are the affinity-event currency. "Prometheus Core costs 150 BP" and "Robo Ribbon costs 25 BP" became Beckons. |
| 10 | BP ownership | Prototype and architecture: a BP bank per character. | One shared party pool (canon), +1 per ally action. The prototype's "no gain the turn after boosting" rule is dropped. |
| 11 | Cap upgrades | V2: MAX_BP 6 / MAX_SPEND 4 via the Prometheus Core. Combat Systems: via Crono Memory Shards and Vaelos rifts. | Memory Shards raise MAX_BP; the first Vaelos rift raises MAX_SPEND; the Core only revives. |
| 12 | Prometheus Core access | Arris Sleeping "locks" the Core, Incinerated makes it "lootable"; the original story had R-66Y's Rewind gift it. | Sleeping → Doan garden gate and 150 Beckons; Incinerated → free, +25 Dark, Robo Ribbon lost; the Rewind grants the right to it and the Ribbon quest. Revive: 1 BP, 20% HP, blocked at Ruin ≥ 2. |
| 13 | LIGHT tag | VITREOUS and ASTRAL both claimed [LIGHT]. | Unique three-tag sets per element; VITREOUS is not Light. [LIGHT] survives as a world tag on a few techniques. |
| 14 | Variant names | Issei, Kaen, Saur, Liriel, Lir, Pip, Jinx, Ren, K-88, KID-0, Metro-02, Amane, Amanae; "Azar_RUIN" as a party member. | Canonical roster only: Krona (Azar_RUIN), Static (Ren, K-88), Omega-Spekkio (Amane, Amanae), Vesper (Liriel), Xyloph (Saur), Pierrot-Glenn (Pip). Azar is U3's Divinity Warden. |
| 15 | The ninth member | Glenn's bible called Vaelos the 9th character; the Extreme library gave Vaelos techniques (null_erasure, ferro_null). | Omega-Spekkio is the optional 9th. Vaelos is a bonus member only after Ending 3. Vaelos-actor techniques became Crono's void echo (Dark ≥ 40). |
| 16 | Omega Annihilation | Tech Library: a Sera + Static Dual. Original story: the R-66Y Salvage gives Krona a Dual of that name. | The Sera + Static Dual keeps the name; the Salvage reward is **Empress Cannon** (Krona + Cassia-09). |
| 17 | Ashtear Paradox | Tech Library: Crono + Sera + Cassia-09. Original story: Crono + Krona + Cassia-09. | Both, as two forms of one Triple. |
| 18 | First Light That Never Was | Three different actor lists (Xyloph + Vesper + Crono; Crono + Cassia-09 + Xyloph; Crono + Sera + Glenn). | The full form, Fragment I (U3) and Fragment II, which is the same technique Chapter 6 also calls Chrono Laugh. |
| 19 | vitreous_refraction | Used for both a Vesper solo evolution and the Vesper + Sera Dual. | The Dual keeps the id; the solo evolution is Prism Refraction. |
| 20 | Goyama Daimyo Phase 4 | Needs the Vesper + Sera Dual three chapters before Vesper joins. | Sera's Tachyon Needle through the castle's Prism Lantern in Chapter 2; the Dual on a revisit. |
| 21 | Weaver and Mother of Threads | Two versions of Cassia-09's recruitment fight; "Prismatic 45 to save Lucca's node" in Chapter 3. | One encounter (E12 numbers); saving Lucca means Breaking it through the antennae, never the tank. |
| 22 | Solar Railgun | Tech Library 24: LINE 18.0, 1 rail + 2 burn, 2.2. Extreme: LINE 12.0, 3 rails + 1 burn, 1.2 ×3. | Length 18.0; three rails at 1.2 plus one burn. |
| 23 | Astral Slash | 1.3, 1 hit (24) vs 1.4, 1 hit + bleed tick (Extreme). | 1.4 with the bleed tick. |
| 24 | Multi-hit power | Some entries wrote "0.9×3", others a single number for several hits. | `×N` is per hit; a single figure is the total. |
| 25 | Tag lists | Mercury Pulse [FERRO][MYCELIA][CORE_OVERLOAD]; White Noise [HZ][NOISE][STATIC][TIME_DEBT]; Triangulation [SLASH]. | Element sets restored: Mercury Pulse [FERRO][MAGNETIC][RESONANCE]; White Noise [HZ][WHITE_NOISE][NOISE]; [SLASH] → [SWORD]. [CORE_OVERLOAD] stays on Prometheus Overload. |
| 26 | Rose Window cost | "Cost 3 BP." | 20 MP and it must be cast at Boost Lv3 or higher. |
| 27 | Critical hits | Prototype: random crits; Progression: "no random crit, Perfect Frame instead". | No random crits. Breaks and listed sources only; Perfect Frame +15%. |
| 28 | AoE falloff, synergy pairs | Progression sheet only. | Adopted: 1.0 / 0.75 / 0.5 / 0.25 falloff (shave unaffected); Crono + Krona ×1.15, Crono + Sera ×0.95, three-universe Triples ×1.25, Vaelos ×0.85. |
| 29 | Sera's meter | "+5% translucency" with thresholds at 80/60/40/20. | Shown as solidity falling from 100; the thresholds are crossed on the way down, once per battle. |
| 30 | Sera's recovery | +2% per turn without a Tachyon skill and campfire or Vesper clearing 20% (her bible); only U7 lotus ponds (canon); meditation 2% per second (Chapter 4). | Persistent Debt recovers only at U7 lotus ponds and by U3 Moon Meditation (U3 Debt only); the +2 per turn is in-battle; camp and Vesper recovery are dropped. |
| 31 | The clock | "Seven days are seven universes"; Rewind costs could drain her to nothing in one chapter. | Two layers: battle solidity starts at 100 − Debt; Debt grows by +5 per new gate jump and +1 interest per 20% spent in a battle; cap 55. The Heart sets her to 60. |
| 32 | True gate arithmetic | Chapter 13: "Rewind twice at <50%, 15% each, lands on 40." | The Ledger prices the two Rewinds to land on 40. In Chapter 9: 60 → Rewind 55 → Rewind 50 → Borrowed Future 40. |
| 33 | Crono's Time Debt | "% max HP" costs per cast, until camp, rest of chapter, permanent. | Battle Strain, Camp Strain ("rest of chapter" included) and Integrity; max HP factor 0.5 + 0.5 × integrity; floor 10% of base. |
| 34 | Crack states | Driven by HP, but "cracked at full HP" in U7, U8 and the Prologue. | The worse of current HP (as % of base) and integrity. |
| 35 | Prologue integrity | "Crack self to 60%", "drops to 40%". | Integrity 60 (Light), 40 (Dark), 50 (Prismatic). |
| 36 | Origin details | Crono's own bible: vaporized "on Death Peak" / "1999 divergence"; Sera 16 or 19; Static 11 or 14; Krona a 22-year-old dyer's daughter. | Canon: the Ocean Palace, 12,000 B.C.; Sera 17; Static 13; Krona ageless, early 30s. |
| 37 | Party weaknesses | Implied by Kami-Ori's Offering and the Final Dojo, never listed. | A vulnerability/resistance table for the party; NULL SHIELD and TRUE NULL defined. |
| 38 | Shields on allies | Kirie Gale "shaves 1 shield per second from all"; the Encore's kin thread Breaks an ally; "lose 10 BP". | Allies have no plates: Kirie Gale strips temporary shields and halos; the kin-thread ally is Broken (loses a turn, DEF −50%); all BP is lost. |
| 39 | Boss HP | R-66Y 45,000 (Lv 20); Cyrus Encore 18,000 / 15,000 / 12,000; Crono's Reflection 300,000; Omega-Spekkio 99,999. | Kept as authored (the Encore is an honesty fight; the Reflection is meant to be long). Others follow roughly 2,250 × level. |
| 40 | R-66Y's level | "Always 18", "Level 20", "18–20". | 20. |
| 41 | Truncated sources | Empress Vaelos after Phase 2; Codex E23–E36; Extreme Duals D13+; the Arris Echo. | Completed: Empress Phases 3–5 (8/8/8/8 kept); codex continued as E23–E85; Duals completed from chapter material; Arris Echo given both flag variants. |
| 42 | Early weaknesses with no source | U1 enemies weak to [FIRE] and the Memory Flame weak to [WATER][ICE] before anyone supplies them. | Krona's Cinnabar Flare; the washi sprinklers (revealed by Cobalt Wash) as a [WATER] operand; "killing it without water is Dark" stays. |
| 43 | Missing encounters | The Krona duel, the Weeping Shogun, the Final Dojo bouts, the Ash Ringmaster, the Forge Tendril, the Atrium Siege. | Written in [Bosses](#14-bosses) and [Failure and Recovery](#16-failure-and-recovery). |
| 44 | Oil-Blight | "Cleanse only via the Atrium fountain"; a battle drain; "1 per 10 s, Mercury Pulse cleanse". | −1 BP per 15 s, battle-scoped; Grief Filter immunity; the fountain washes the oil-soak between battles. |
| 45 | Ruin | "Until the lotus pond", "until the Arris repair bench", "unhealable, stacks to −60%" (U5). | −15% per stack, cap 3, clears at camp, thawed by Divinity; U5 Ink Boil adds Ruin stacks; the cap lifts only in Porcelain Silence. |
| 46 | Grief | "−2 MP per 10 s", "2% MP per 3 s", "BP −1 per 10 s". | −2 MP per 10 s per stack (max 3). |
| 47 | Mercury SLOW | 0.5× (combat law) vs "hold frames 2f → 5f, −40% move" (Progression). | 0.5× gauge and movement; the held frames are its look. |
| 48 | Divinity Field | U3 (+1 per 5 s, cap 20%) vs U7 (+1 per 5 s, thaws Ruin, converts Debt). | One field doing all of it (V2's unification). |
| 49 | Falls | "Fall = +5% crack" (U7 traversal) vs "+5% Erosion" (Kami-Ori). | Falls add 5% Glaze Erosion; only defeats cost integrity. |
| 50 | Whose HP | "Chronoslip costs 5% HP" (Extreme header, Ending 7); Tachyon Needle "costs 5% HP + 40% phase-out". | Sera pays solidity; Crono pays HP. Tachyon Needle costs 6 MP; phase-out is a threshold, not a cost. |
| 51 | Theft loops | Glenn stealing from allies could duplicate BP. | Steals go to the pool, never duplicated; one steal per action. |
| 52 | Dual costs | "Both pay +1 ATB; BP = sum / 2." | Every participant's gauge resets; each pays their own cost; Boost is chosen once from the shared pool. |
| 53 | Omega-Spekkio's gate | His bible: "Chapter 12, after Cassia rebuilds the Chronoslip Tuner." | Chapter 8, after Kami-Ori, with the 8 sigils. |
| 54 | Misplaced bosses | R-66Y listed under U6; the Seventh Arm "in U6"; Ending 7 citing Ayla, Robo's beam and Lucca's lens. | R-66Y is U2's boss with U6/U8 reskins; the Seventh Arm is U7's secret phase; Ayla and Robo are not party members; Lucca's lens is Mercury Pulse; Luminaire is Crono's. |
| 55 | Competing bosses | U3: Mycelia Matriarch vs Azar. U4: Leviathan, Glass Matriarch, Schala. U5 Cyrus: two phases (V2) vs three plus Mercy (FINAL). | Chapter bosses are the story bosses; the rest are optional; Cyrus uses FINAL's numbers; the U4 drowned Moon owns `Moon_Sleep` / `Moon_Shatter`. |
| 56 | HOLD upgrade | "+2.5 s per 5%" and "HOLD lengthens" (U4 Light). | +3.0 s per 5% after `Central_Eye_Broken`. |
| 57 | Process text | Status labels, sign-off gates, meta instructions addressed to the build agent, word-count targets. | Removed. Everything is written as direction and fact; the build agent decides everything the bible leaves open and may tune any number. |
| 58 | Origami Requiem's partner | FINAL: Crono + Kami-Ori, who is not playable. The Story Bible: Crono + Omega-Spekkio. This bible's first draft: Crono + Sera with Kami-Ori's crane. | Both: Sera carries the crane for everyone; Crono + Omega-Spekkio is the same Dual once he joins. |
| 59 | Vaelos's child kit | FINAL Chapter 12 lists Null Spoon HOLD, Porcelain Promise Child (Crono + Vaelos) and First Light That Never Was — Child Variant; the Story Bible adds Fake Family Photo Real. | All four added to 11.11–11.13. |
| 60 | Mercy Leap with Vesper | The Story Bible's Chapter 15 lets Glenn throw Vesper as well as Sera. | Added as a second form of Mercy Leap. |
