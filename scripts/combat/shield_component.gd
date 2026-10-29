## Shield plates, weaknesses and BREAK, evaluated one strike at a time (Combat Laws Bible §5).
## Timers run on battle time: the coordinator calls tick(dt) only while gauges fill.
class_name ShieldComponent
extends Node

signal shield_changed(current: int, max_value: int)
signal weakness_revealed(tag: StringName)
signal broken(breaker: Node)
signal break_recovered
signal plate_fell(index: int)

@export var max_shield: int = 4
@export var weaknesses: Array[StringName] = []
@export var resists: Array[StringName] = []
@export var nullifies_shave: Array[StringName] = []
@export var immune: Array[StringName] = []
@export var absorbs: Array[StringName] = []
## Keyed plates (§5.6): ordered list of {material: StringName, key: StringName, weight: int}.
## When non-empty, these replace the flat max_shield pool.
@export var keyed_plates: Array[Dictionary] = []
## Belief plates (§5.7): the plate displays this number; only max_shield plates are real.
@export var belief_number: int = 0
## Regenerating: after 3.0 s without a shave the unbroken shield refills at 18%/s.
@export var regenerating: bool = false
## Refills once: the first Break of the phase refills instead of ending the phase.
@export var refill_once: bool = false
## Shield-only: takes no HP damage until Broken.
@export var shield_only: bool = false
## Break-immune-until: the coordinator sets break_allowed; at 0 the Break waits.
@export var break_condition: StringName = &""
## Only hits from this actor id can shave (Vaelos Echo: Sera only). Empty = anyone.
@export var only_hit_by: StringName = &""
## A shield owned by another component (shared plates, §5.7).
var shared_owner: ShieldComponent = null

var current_shield: int = -1
var temp_plates: int = 0
var is_broken: bool = false
var break_allowed: bool = true
var pending_break: bool = false
var revealed: Dictionary = {}
var belief_chips: int = 0
var lock_left: float = 0.0
var rebuild_pct: float = 0.0
var resume_left: float = 0.0
var refill_used: bool = false
var since_last_shave: float = 0.0
var break_count: int = 0
## Tags of the hit that Broke this shield last (Break Signature, §5.8).
var break_signature: Array[StringName] = []
## Index of the current keyed plate.
var plate_index: int = 0
var plate_weight_left: int = 0
var _regen_accum: float = 0.0
var _lock_extension_pending: float = 0.0


func _ready() -> void:
	if current_shield < 0:
		reset_shields()


func reset_shields() -> void:
	is_broken = false
	pending_break = false
	lock_left = 0.0
	rebuild_pct = 0.0
	resume_left = 0.0
	since_last_shave = 0.0
	_regen_accum = 0.0
	plate_index = 0
	belief_chips = 0
	if uses_keyed_plates():
		plate_weight_left = int(keyed_plates[0].get("weight", 1))
		current_shield = _keyed_total()
	else:
		current_shield = max_shield
	shield_changed.emit(current_shield, max_total())


func uses_keyed_plates() -> bool:
	return not keyed_plates.is_empty()


func max_total() -> int:
	return _keyed_total() if uses_keyed_plates() else max_shield


func _keyed_total() -> int:
	var n: int = 0
	for p in keyed_plates:
		n += int(p.get("weight", 1))
	return n


func display_number() -> int:
	if belief_number > 0:
		return maxi(0, belief_number - belief_chips - (max_total() - current_shield))
	return current_shield


func current_key() -> StringName:
	if uses_keyed_plates() and plate_index < keyed_plates.size():
		return StringName(keyed_plates[plate_index].get("key", &""))
	return &""


func current_material() -> StringName:
	if uses_keyed_plates() and plate_index < keyed_plates.size():
		return StringName(keyed_plates[plate_index].get("material", &""))
	return &""


func is_revealed(tag: StringName) -> bool:
	return revealed.get(tag, false)


func reveal_all() -> void:
	for w in weaknesses:
		if not revealed.get(w, false):
			revealed[w] = true
			weakness_revealed.emit(w)


func reveal_one() -> StringName:
	for w in weaknesses:
		if not revealed.get(w, false):
			revealed[w] = true
			weakness_revealed.emit(w)
			return w
	return &""


## Weaknesses hidden again by BLIND (the second and later ones show as [?]).
func visible_weaknesses(blind: bool = false) -> Array[StringName]:
	var out: Array[StringName] = []
	var shown: int = 0
	for w in weaknesses:
		if revealed.get(w, false):
			if blind and shown >= 1:
				break
			out.append(w)
			shown += 1
	return out


## Number of distinct carried tags that count toward the shave (§5.3, §9.3).
func count_matching(attack_tags: Array) -> int:
	var seen: Dictionary = {}
	var n: int = 0
	for raw in attack_tags:
		var tag: StringName = StringName(String(raw))
		if seen.has(tag):
			continue
		seen[tag] = true
		if nullifies_shave.has(tag) or immune.has(tag):
			continue
		if weaknesses.has(tag):
			n += 1
	if weaknesses.has(CombatTags.PRISMATIC) and CombatTags.count_elements(attack_tags) >= 3:
		n += 1
	return n


## Would at least one tag make this a weakness hit (for the 2.0x multiplier)?
func hits_weakness(attack_tags: Array) -> bool:
	return count_matching(attack_tags) > 0


## Pure preview of a whole action: total shave and whether it Breaks (§4.6).
## Mirrors apply_strike exactly: the Lv3 bonus lands on the first matching strike.
func preview_action(attack_tags: Array, strikes: int, bonus: int, attacker_id: StringName = &"") -> Dictionary:
	var owner_comp: ShieldComponent = shared_owner if shared_owner != null else self
	if owner_comp.current_shield < 0:
		owner_comp.reset_shields()
	if owner_comp.is_broken:
		return {"shave": 0, "breaks": false, "already_broken": true, "after": 0}
	if only_hit_by != &"" and attacker_id != only_hit_by:
		return {"shave": 0, "breaks": false, "already_broken": false, "after": owner_comp.current_shield}
	var sim: Dictionary = owner_comp._snapshot()
	var total: int = 0
	var bonus_left: int = bonus
	var temp: int = owner_comp.temp_plates
	for i in strikes:
		var r: Dictionary = owner_comp._simulate_strike(sim, attack_tags, bonus_left, temp)
		temp = int(r["temp_after"])
		total += int(r["shaved"])
		if r["matched"]:
			bonus_left = 0
		if int(sim["current"]) <= 0:
			break
	var after: int = int(sim["current"])
	return {"shave": total, "breaks": after <= 0 and owner_comp.break_allowed, "already_broken": false, "after": after}


func _snapshot() -> Dictionary:
	return {"current": current_shield, "plate_index": plate_index, "plate_weight_left": plate_weight_left}


## Shared logic of preview and apply. `sim` holds current/plate_index/plate_weight_left.
func _simulate_strike(sim: Dictionary, attack_tags: Array, bonus: int, temp: int) -> Dictionary:
	var out := {"shaved": 0, "matched": false, "temp_after": temp}
	var matches: int = 0
	if uses_keyed_plates():
		var key: StringName = &""
		var idx: int = int(sim["plate_index"])
		if idx < keyed_plates.size():
			key = StringName(keyed_plates[idx].get("key", &""))
		var carries_key: bool = false
		for raw in attack_tags:
			if StringName(String(raw)) == key:
				carries_key = true
				break
		if not carries_key:
			return out
		matches = 1
	else:
		matches = count_matching(attack_tags)
		if matches == 0:
			return out
	out["matched"] = true
	var shave: int = matches + maxi(0, bonus)
	# Temporary plates fall first and never Break on their own.
	if temp > 0:
		var t: int = mini(temp, shave)
		out["temp_after"] = temp - t
		shave -= t
		if shave <= 0:
			return out
	if uses_keyed_plates():
		var left: int = shave
		while left > 0 and int(sim["plate_index"]) < keyed_plates.size():
			var w: int = int(sim["plate_weight_left"])
			var take: int = mini(w, left)
			sim["plate_weight_left"] = w - take
			sim["current"] = int(sim["current"]) - take
			out["shaved"] = int(out["shaved"]) + take
			left -= take
			if int(sim["plate_weight_left"]) <= 0:
				sim["plate_index"] = int(sim["plate_index"]) + 1
				if int(sim["plate_index"]) < keyed_plates.size():
					sim["plate_weight_left"] = int(keyed_plates[int(sim["plate_index"])].get("weight", 1))
					# Spill only continues if the hit also carries the next key.
					var next_key: StringName = StringName(keyed_plates[int(sim["plate_index"])].get("key", &""))
					var carries_next: bool = false
					for raw in attack_tags:
						if StringName(String(raw)) == next_key:
							carries_next = true
							break
					if not carries_next:
						break
	else:
		var take2: int = mini(int(sim["current"]), shave)
		sim["current"] = int(sim["current"]) - take2
		out["shaved"] = take2
	return out


## Evaluates ONE strike. bonus is the flat bonus still owed this action (0 after it lands).
## Returns {shaved, hit_weakness, caused_break, matched, chipped_belief}.
func apply_strike(attack_tags: Array, bonus: int, attacker: Node, attacker_id: StringName = &"") -> Dictionary:
	if shared_owner != null:
		return shared_owner.apply_strike(attack_tags, bonus, attacker, attacker_id)
	if current_shield < 0:
		reset_shields()
	var result := {"shaved": 0, "hit_weakness": false, "caused_break": false, "matched": false, "chipped_belief": false}
	_reveal(attack_tags)
	result["hit_weakness"] = hits_weakness(attack_tags)
	if is_broken:
		return result
	if only_hit_by != &"" and attacker_id != only_hit_by:
		return result
	var sim: Dictionary = _snapshot()
	var r: Dictionary = _simulate_strike(sim, attack_tags, bonus, temp_plates)
	temp_plates = int(r["temp_after"])
	if not r["matched"]:
		if belief_number > 0:
			belief_chips += 1
			result["chipped_belief"] = true
		return result
	result["matched"] = true
	var before: int = current_shield
	current_shield = int(sim["current"])
	plate_index = int(sim["plate_index"])
	plate_weight_left = int(sim["plate_weight_left"])
	result["shaved"] = before - current_shield
	if result["shaved"] > 0:
		since_last_shave = 0.0
		_regen_accum = 0.0
		shield_changed.emit(current_shield, max_total())
		if uses_keyed_plates():
			plate_fell.emit(plate_index)
	if current_shield <= 0:
		if break_allowed:
			_do_break(attacker, attack_tags)
			result["caused_break"] = true
		else:
			pending_break = true
	return result


func _do_break(breaker: Node, attack_tags: Array) -> void:
	is_broken = true
	pending_break = false
	current_shield = 0
	break_count += 1
	break_signature = CombatTags.to_names(attack_tags)
	lock_left = CombatConstants.BREAK_LOCK_S + _lock_extension_pending
	_lock_extension_pending = 0.0
	rebuild_pct = 0.0
	resume_left = 0.0
	broken.emit(breaker)


## Called by the coordinator when a break condition becomes true while the shield sits at 0.
func try_release_pending_break(breaker: Node) -> bool:
	if pending_break and break_allowed and not is_broken:
		_do_break(breaker, break_signature)
		return true
	return false


## Force a Break (Salvage rip, scripted beats).
func force_break(breaker: Node, tags: Array = []) -> void:
	if is_broken:
		return
	current_shield = 0
	shield_changed.emit(current_shield, max_total())
	_do_break(breaker, tags)


## Sera's HOLD and other extensions add lock time (§5.4).
func extend_lock(seconds: float) -> void:
	if is_broken:
		lock_left += seconds
	else:
		_lock_extension_pending += seconds


## Delay the rebuild (hz_white_noise Lv3): adds to the lock as well.
func delay_rebuild(seconds: float) -> void:
	extend_lock(seconds)


## Advance battle time. Returns true when the Break ended this tick.
func tick(dt: float) -> bool:
	if dt <= 0.0:
		return false
	if is_broken:
		if lock_left > 0.0:
			lock_left -= dt
			if lock_left > 0.0:
				return false
			dt = -lock_left
			lock_left = 0.0
		if rebuild_pct < 100.0:
			rebuild_pct = minf(100.0, rebuild_pct + CombatConstants.SHIELD_REBUILD_PCT_PER_S * dt)
			if rebuild_pct < 100.0:
				return false
			_end_break()
			return true
		return false
	since_last_shave += dt
	if regenerating and current_shield < max_total() and since_last_shave >= CombatConstants.BREAK_LOCK_S:
		_regen_accum += float(max_total()) * (CombatConstants.SHIELD_REBUILD_PCT_PER_S / 100.0) * dt
		var whole: int = int(floor(_regen_accum))
		if whole > 0:
			_regen_accum -= float(whole)
			current_shield = mini(max_total(), current_shield + whole)
			shield_changed.emit(current_shield, max_total())
	return false


func _end_break() -> void:
	is_broken = false
	rebuild_pct = 100.0
	resume_left = CombatConstants.BREAK_RESUME_BLEND_S
	plate_index = 0
	if uses_keyed_plates():
		plate_weight_left = int(keyed_plates[0].get("weight", 1))
	current_shield = max_total()
	since_last_shave = 0.0
	shield_changed.emit(current_shield, max_total())
	break_recovered.emit()


## The 0.4 s blend after the Break during which the body may not act yet.
func tick_resume(dt: float) -> void:
	if resume_left > 0.0:
		resume_left = maxf(0.0, resume_left - dt)


func can_act() -> bool:
	return not is_broken and resume_left <= 0.0


func rebuild_ratio() -> float:
	return rebuild_pct / 100.0 if is_broken else 1.0


func _reveal(attack_tags: Array) -> void:
	for raw in attack_tags:
		var tag: StringName = StringName(String(raw))
		if weaknesses.has(tag) and not revealed.get(tag, false):
			revealed[tag] = true
			weakness_revealed.emit(tag)


## Replace the whole plate configuration (boss phase change).
func configure(cfg: Dictionary) -> void:
	max_shield = int(cfg.get("shield", max_shield))
	weaknesses = CombatTags.to_names(cfg.get("weak", []))
	resists = CombatTags.to_names(cfg.get("resist", []))
	nullifies_shave = CombatTags.to_names(cfg.get("nullify", []))
	immune = CombatTags.to_names(cfg.get("immune", []))
	absorbs = CombatTags.to_names(cfg.get("absorb", []))
	keyed_plates.clear()
	for p in cfg.get("keyed_plates", []):
		keyed_plates.append({
			"material": StringName(String(p.get("material", ""))),
			"key": StringName(String(p.get("key", ""))),
			"weight": int(p.get("weight", 1)),
		})
	belief_number = int(cfg.get("belief_number", 0))
	regenerating = bool(cfg.get("regenerating", false))
	refill_once = bool(cfg.get("refill_once", false))
	shield_only = bool(cfg.get("shield_only", false))
	break_condition = StringName(String(cfg.get("break_condition", "")))
	only_hit_by = StringName(String(cfg.get("only_hit_by", "")))
	refill_used = false
	revealed.clear()
	reset_shields()


static func of(actor: Node) -> ShieldComponent:
	if actor == null:
		return null
	if actor is ShieldComponent:
		return actor as ShieldComponent
	return actor.get_node_or_null("ShieldComponent") as ShieldComponent
