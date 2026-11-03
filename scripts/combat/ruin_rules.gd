## Ruin (Combat Laws Bible §12.2, §12.6, acceptance §18.7 #18, #21): −15% max-HP ceiling per stack, at most
## 3 stacks (−45%); Porcelain Silence's Ruin scaling lifts the cap to 10 and the 10% ceiling floor still holds.
## Crono's stacks live in his TimeDebtComponent, inside the §10.1 ceiling formula; every other battler's live
## in its StatusComponent entry, which CombatantStats.max_hp() reads. Crono's entry mirrors his component so
## the HUD and the queries see one number. Ruin is battle-scoped until camps exist (DECISIONS "Statuses").
class_name RuinRules
extends RefCounted

## An arena hazard that starts with this lifts the cap (data/bosses/cronos_reflection.json).
const SCALING_HAZARD := "ruin_scaling"


## Stacks on `u` (Crono's component first).
static func stacks(u: Node) -> int:
	var td := TimeDebtComponent.of(u)
	if td != null:
		return td.ruin_stacks
	var sc := StatusComponent.of(u)
	return sc.stacks(&"ruin") if sc != null else 0


## The max-HP factor `n` stacks leave a battler without a TimeDebtComponent.
static func ceiling_factor(n: int) -> float:
	return maxf(CombatConstants.CRONO_CEILING_FLOOR, 1.0 - CombatConstants.RUIN_STACK * float(n))


## Adds `n` stacks under the bearer's cap, lowers the ceiling and clamps HP to it. Returns the stacks gained.
static func add(u: Node, n: int = 1) -> int:
	var sc := StatusComponent.of(u)
	var td := TimeDebtComponent.of(u)
	var before: int = stacks(u)
	if td != null:
		td.add_ruin(n)
	if sc != null:
		var gained: int = (td.ruin_stacks - before) if td != null else n
		if gained > 0:
			sc.add(&"ruin", -1.0, -1, gained)
	var st := CombatantStats.of(u)
	if st != null:
		st.clamp_to_ceiling()
	return stacks(u) - before


## Thaws `n` stacks (a Divinity Field, §12.5): the ceiling comes back up; HP stays where it is.
static func thaw(u: Node, n: int = 1) -> void:
	var td := TimeDebtComponent.of(u)
	if td != null:
		td.thaw_ruin(n)
	var sc := StatusComponent.of(u)
	if sc != null:
		sc.remove_stacks(&"ruin", n)


## Rewind (§3.6) takes `u` back to a turn start where it bore `then` stacks: the stacks gained since thaw, through
## thaw(), so Crono's component and his mirror move together. Returns the stacks thawed.
static func rewind_to(u: Node, then: int) -> int:
	var n: int = stacks(u) - then
	if n > 0:
		thaw(u, n)
	return maxi(0, n)


## True when the Prometheus Core may not revive `u` (Ruin 2+, §7.8).
static func blocks_prometheus(u: Node) -> bool:
	return stacks(u) >= 2


## The cap this battle runs at: config "ruin_cap", else 10 when a boss's arena carries Ruin scaling, else 3.
static func battle_cap(enemies: Array, config: Dictionary = {}) -> int:
	if config.has("ruin_cap"):
		return int(config["ruin_cap"])
	for e in enemies:
		if not is_instance_valid(e) or not (e as Node).has_meta("boss_id"):
			continue
		var boss: Dictionary = Data.bosses.get(StringName(String((e as Node).get_meta("boss_id"))), {})
		for h in boss.get("arena_hazards", []):
			if String(h).begins_with(SCALING_HAZARD):
				return CombatConstants.RUIN_STACK_CAP_SILENCE
	return CombatConstants.RUIN_STACK_CAP


## Give `u` this battle's cap.
static func prepare(u: Node, cap: int) -> void:
	var td := TimeDebtComponent.of(u)
	if td != null:
		td.ruin_cap = cap
	var sc := StatusComponent.of(u)
	if sc != null:
		if cap == CombatConstants.RUIN_STACK_CAP:
			sc.cap_overrides.erase(&"ruin")
		else:
			sc.cap_overrides[&"ruin"] = cap


## The battle is over: the stacks clear and the cap returns to 3.
static func clear(u: Node) -> void:
	if not is_instance_valid(u):
		return
	var td := TimeDebtComponent.of(u)
	if td != null:
		td.thaw_ruin(td.ruin_stacks)
		td.ruin_cap = CombatConstants.RUIN_STACK_CAP
	var sc := StatusComponent.of(u)
	if sc != null:
		sc.remove(&"ruin")
		sc.cap_overrides.erase(&"ruin")
