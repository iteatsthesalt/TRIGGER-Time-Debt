# Decisions

What was decided where the bibles left something open or where a rule played better another way.
Each entry: what, why, which bible section it touches.

## Project and tooling

- **JSON for content, not .tres.** Techs, enemies, characters, flags, items, encounters and dialogue live in `data/**/*.json`, loaded by the `Data` autoload into typed `TechDef`/`EnemyDef` objects and validated on load (unknown tags, duplicate ids, dangling references). Reason: generated and edited by Python tools and subagents without resource UIDs; diffable; lintable outside Godot (`tools/build/lint_data.py`). Touches Combat Laws §18.2 (which named `.tres`; the fields are the same).
- **Tests load the suite at runtime.** `tests/run_tests.gd` is a bootstrap that loads `tests/suite_core.gd`, because a `--script` entry point compiles before autoload singletons exist. Touches Reference §10.1.
- **Autoload names:** `Data`, `Flags` (PossibilityEngine), `Game`, `Saves`, `Universe` (UniverseSwitcher), `Audio` (AudioDirector), `Router`, `Story`. Reference §10.1 named `TimeDebt` as an autoload; Crono's integrity and Sera's debt live on `Game` and are mirrored into the battle components.

## Combat

- **The Lv3 flat shave bonus lands on the first matching strike of an action**, not after the last hit. The total shave per action is identical to §5.3; the only difference is that a Break can arrive one hit earlier, which makes the +1 feel immediate and keeps per-strike resolution simple. The preview uses the same code path. Touches Combat Laws §5.3, §6.4.
- **Keyed plates spill only when the hit also carries the next key.** A multi-weight keyed plate that falls mid-strike passes its leftover shave to the next plate only if the hit's tags include that plate's key; otherwise the excess is lost. Touches §5.6.
- **Ens Parry is "armed".** Pressing parry while Guarding arms a window of `parry_frames / 60` seconds of battle time; a hit that lands while armed is a perfect parry. Pressing outside the window against U1 ink enemies throws the ink blot. This keeps resolution synchronous and headless-testable. Touches §4.2.
- **Voluntary phase-out** is recorded when any party gauge has been parked in the Ready Pool for ≥ 3 s of battle time when the 40% line is crossed (§10.2). The coordinator tracks hold time per parked ally.
- **Party synergy without Sera in the story is 1.00**; with Sera active or hovering 1.10; phased 0.85 (§6.2).
- **Enemy evasion rolls** apply only to non-telegraphed hits: LUK × 0.05% plus Trauma Silence (+10%, +20% under 50% HP) and status evasion.
- **Borrowed Future's Token Duplicate** re-runs the ally's last recorded action immediately with the same Boost level and a fixed variance of 1.0, so the copy matches the original; if the ally has no recorded action this battle, it is placed at the gate instead.
- **Prologue integrity values:** Teach Her To Land 60, Hold The Copy Together 40, The Bowl Still Whole 50 (Combat Laws Appendix A.35).
- **Krona's Oil-Drinker auto-sip** fires once per enemy action against her when she is below 25% HP; the command form heals the party 10% each.

## Rendering

- **One compute pass** implements the paper → grade → edge → VHS stages of the canvas stack (Reference §1.7 describes a four-layer chain). The stages run in order inside one shader on a scratch copy of the colour buffer, blended by the UniverseSwitcher weights. Equivalent output, fewer dispatches, one place to tune.
- **Grades are procedural, not LUT textures:** per-universe saturation, paper tint, ink quantisation (U1's four inks), posterisation (U6's four steps) and a gold lift (U7/U8). A real 32³ LUT can be dropped in later without changing the stack. Touches Reference §2.2.

## Story

- **Crono's first lie** in the kitchen is a three-way choice: "Burn. Old burn." (the bible's line), covering the wrist, or holding it out. The first two lean Dark (+5), the third Light (+5). The bible gives only the lie; offering the honest gesture early sets up the Chapter 1 hearth choice. Touches Story Bible Prologue beat 3.

## Atrium Cradle retune (Combat Laws §14.1, Story Bible Prologue)
The bible lists the Cradle at Lv 3 with 2,400 HP. On the §15 curves a Lv 1–2 party deals ~12 per hit
through intact plates, so that pool is ~140 hits, and a Lv 3 enemy ATK (30) three-shots Lv 1 Crono
(120 HP). Headless playthroughs lost every attempt. The Prologue boss is a teaching fight that a careful
first-time player should win at 60% integrity in three to four minutes, so it now ships at Lv 2 with
1,200 HP, softened action powers (ring swipe 0.9, Sorrowful Blue 0.5, clamp 1.0, seal pulse 0.7,
crack-slide 1.25, mask scream 0.8) and at most two Shardlings standing at once. Phase windows,
plates, mechanics and drops are unchanged.

## The Dollhouse Seal is paid from the deck
"It can be damaged only by spending Time Debt — 5% of Crono's max HP" is implemented as a real
command: while the Cradle is sealed, Crono's deck offers PAY TIME DEBT (5% integrity, a free action)
and the Seal lifts when he pays. The phase script explains it instead of paying silently.

## The Bowl Still Whole has two routes
The breakfast fall choice offers "[Astral Smear Dash] Catch the bowl" directly (the clearest moment
for a first-time player), and the Cradle's third phase keeps the bible's route: a perfect parry on the
Crack-Slide opens a 1.5 s Prismatic window in which Astral Smear Dash grants the flag if it is not set.
