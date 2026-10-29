# Trigger — Combat Architecture Audit

Audited: *Hybrid Chrono Octopath Combat Architecture* (v1, project upload) and its v2 found inside Foundational Source 02 (adds HUD, shield plates, AoE shader, sandbox bootstrap).
Method: every script rebuilt in Godot 4.3, run headless, covered by 65 automated checks (`tests/run_tests.gd`), linted with gdlint, and exercised end-to-end in `scenes/combat_sandbox.tscn`.

Severity: **Critical** = crash, hang or softlock · **Major** = wrong numbers or broken rule · **Minor** = robustness/clarity · **Doc** = text error.
"v1/v2" says which version had the problem.

## Critical

| # | Problem | Where | Fix |
|---|---|---|---|
| C1 | **Sync Hold softlock.** A held ally is skipped by the timeline and only leaves the pool by casting a co-op Tech. If the partner acts solo, the held ally is never prompted again. | Coordinator v1, v2 | Held allies are re-prompted after any party action; `request_command()` (HUD key W) wakes them any time. Test: `test_sync_hold_deadlock_fixed`. |
| C2 | Casters passed as `Array[Node3D]` into an `Array[Node]` parameter — Godot 4 typed arrays are invariant, so this errors at runtime. | `execute_tech_command` → `calculate_damage` v1 | Damage takes `Array[CombatantStats]`. |
| C3 | Stats read off the actor body (`caster.get("elemental_attack")`) instead of the `CombatantStats` child → `null` arithmetic. | `TechResource` v1 | `CombatantStats.of(actor)` helper. |
| C4 | `await tween.finished` on a tween with no tweeners (no camera assigned) never completes — encounter never starts. | `start_seamless_encounter` v1, v2 | Tween only created when a camera exists. |
| C5 | Targets without a `ShieldComponent` crash (`shield.evaluate_incoming_hit` on null). | Coordinator v1, v2 | Null-guarded; such targets take neutral hits. |
| C6 | `CLEAVE_CONE` declared but unhandled — the cast silently reuses the previous Tech's shape. | `TacticalPositioner3D` v1, v2 | Implemented; preview decal also draws cones. |
| C7 | Encounter `Area3D` contains its own enemy bodies, so `body_entered` fires on enemies, not just the player. | Scene tree v1, v2 | `EncounterZone` filters to `party_leader`, fires once, layers separated. |
| C8 | Enemies never act (stub), no victory/defeat check, `combat_ended` never emitted, exploration never unlocked. | v1, v2 | Placeholder AI, win/lose detection, transition out, `exploration_lock_changed`. |
| C9 | v2 sandbox: party and enemies have no `CombatantStats`, so enemies can't take damage and the fight can't end. | `BattleSandboxBootstrap` v2 | New generated sandbox with full components. |

## Major

| # | Problem | Fix |
|---|---|---|
| M1 | `hit_count` multiplied Shield shave but not damage. | Strikes resolved one at a time; `base_multiplier` is per strike. |
| M2 | A Break on strike 1 still left strike 2 at 1.3×, contradicting the doc's own 2.0× Break rule. | Per-strike evaluation; the breaking strike is 1.3×, later strikes 2.0×. |
| M3 | Co-op list ignored who was asking and offered partners' Single Techs (v1). | `get_available_techs(actor)` requires the actor to be a participant. |
| M4 | Actor identity by node name — `TravelerActor` can't be two characters; v2 used `&"Crono"`, v1 `&"crono"`. | `CombatantStats.actor_id`. |
| M5 | MP never deducted. | Checked for every caster up front; nothing is spent if the command is refused. |
| M6 | Boost dim and restore tweens started in the same frame and fought; exposure restored to hard-coded `1.0`, wiping the era's own value. | One sequenced tween; restores the environment's starting exposure. |
| M7 | "Reaching the Action Gate pauses enemy drift" was in the design table but not implemented. | Drift requests stop while anyone waits in the Ready Pool. |
| M8 | Break recovery refilled at a flat 18/s regardless of the enemy's speed, so a Break could be *shorter* than a normal turn. | Break pushes the gauge to −100 (exactly one lost turn at the enemy's own speed); recovery acts with top priority. |
| M9 | Duplicate tags (`[FIRE, FIRE]`) double-counted a weakness. | Distinct tags only. |
| M10 | MAX Boost bonus shave was folded into the hit-count formula; v2 HUD preview used a different formula from the hit. | Bonus applies to the first weakness strike; HUD uses `ShieldComponent.preview_action()`, the same rules as the hit. |
| M11 | Boost level above what the casters actually hold was silently downgraded. | Refused with a reason; HUD caps the selector at pooled BP. |
| M12 | Source-review balance issue: a MAX-boosted Fire Whirl on a SWORD+FIRE boss strips 5 shields in one action. | Kept as designed (still 5) but added `max_shield_shave_per_action` knob. Test confirms both. |

## Minor

- `look_at` errors when caster and target overlap; direction was normalized *before* zeroing Y. → Geometry now done on the XZ plane with fallbacks.
- ShapeCast queries depended on collision layers, groups and a physics frame. → Exact XZ math against the known enemy list (testable headless). `preview_points()` gives decal outlines.
- `_physics_process` returned after the first unit reached the gate, so earlier units in the list always won ties. → Highest overshoot wins; party breaks exact ties.
- `is_connected(callable.bind(...))` compares a fresh bound callable each time. → Stored callables, disconnected at battle end.
- Held unit's gauge set to 99 was dead code (pooled units aren't ticked). → Removed.
- v2 HUD called the coordinator's private `_resolve_casters_for_tech`, rebuilt weakness labels with `queue_free` every refresh, and drift wrote `global_position` directly (bypassing physics and Break freeze). → Public API, synchronous rebuild, movement through `CombatActor`.
- New in this pass (own bug, fixed): with no baked navmesh `NavigationAgent3D` returns the actor's own position, so actors never moved. → Straight-line fallback.

## Doc errors

- **Corrupted formulas.** Both LaTeX blocks lost backslashes to escape codes: `\text` → tab + "ext", `\right` → carriage return + "ight", `\times` → tab + "imes".
  Correct: `Boost = 1.0 + 0.9 × L` and `Damage = 0.8 × (ΣAtk − 0.5·Def) × M_tech × M_synergy × (1 + 0.9·L)`.
- **Walkthrough BP impossible.** Everyone starts at 1 BP and gains 1 at the gate, so a first turn has 2 BP. v1 gives Frog 3 BP; v2 gives Crono 3 BP. The rebuilt walkthrough test uses 2 and still breaks the Ogre.
- Scene tree omits the `ShapeCast3D`/decal children `TacticalPositioner3D` expects, and `CombatantStats` is never defined.
- **Story conflict.** The doc frames maps as eras (600 / 1000 / 2300 AD). Source 01 settled the sequel as post-ending, no time travel, adult Crono, Guardia vs. Porre around 1005–1020 AD. Era presets should become regions/periods of one world.
- **Unverified numbers.** The +90%/BP skill boost, `0.8 × (Atk − Def/2)`, and Source 01's CT ATB timing (`5.0 s − 0.2 s × Speed`) are cited from fan wikis/guides or asserted without a source. Treat them as tuning defaults, not canon, until checked.
- Octopath Break is round-based (rest of this round + all of next, per the ChatGPT source). An ATB game has no rounds, so this build uses "lose one full turn". Flagged as a design decision.

## Design decisions made in this pass (not from the sources)

1. Strikes resolve individually; `base_multiplier` is per-strike potency.
2. MAX Boost +1 shave applies to the first strike that hits a weakness.
3. Break = gauge to −100; recovery takes top priority, restores shields, unfreezes.
4. Held allies are re-prompted after party actions, not after enemy actions.
5. Boosted basic attacks add strikes only (no damage scaling), per the doc's table.
6. AoE uses analytic XZ geometry instead of ShapeCast3D.
