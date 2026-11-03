## The allies a battle has beyond the field party (Combat Laws Bible §3.1, §3.6, §4.2): the Bench
## (recruited members who are not in the active party; a Swap brings one in with gauge 50, the first
## Swap of a battle pays +1 BP, a KO'd ally can be swapped out by anyone within 3 m) and Sera as Hover
## Support (she lives on the Turn Bar and throws her daggers from there) when the story has her hovering.
## Both are built from Game's roster, never hard-coded by a scene: `plan()` is the pure rule and takes a
## fake roster in tests. Reserve actors are real CombatActors parked hidden beside the plane; a Swap
## is for the rest of the battle only (the field party is the one you walked in with) and `finish()`
## writes the reserves' HP and XP back to the roster and frees them.
class_name BattleRoster
extends RefCounted

## Values of Game.sera_in_story that put Sera on the Turn Bar (the dialogue command `sera_state`).
const HOVER_STATES: Array[String] = ["hover", "hover_support"]

var bench: Array[CombatActor] = []
var hover: CombatActor = null
var _field: Array[CombatActor] = []
## Every reserve this battle spawned, wherever a Swap has put it since (the bench, or the party in place
## of a field member): finish() writes each one back and frees it.
var _spawned: Array[CombatActor] = []


## Who sits where, from the roster fields: `recruited` and `active` are id lists, `sera_state` is
## Game.sera_in_story. Sera hovers in a hover state, sits on the bench while "with" the party, and is
## nowhere while "taken" or "absent"; everyone else recruited and not active is on the bench.
static func plan(recruited: Array, active: Array, sera_state: String) -> Dictionary:
	var bench_ids: Array[StringName] = []
	var hover_sera: bool = false
	for raw in recruited:
		var id := StringName(String(raw))
		if active.has(id):
			continue
		if id == &"sera":
			if HOVER_STATES.has(sera_state):
				hover_sera = true
			elif sera_state == "with":
				bench_ids.append(id)
			continue
		bench_ids.append(id)
	return {"bench": bench_ids, "hover": hover_sera}


## Spawn the reserves for a battle under `host`, hidden at the plane's near edge.
func build(host: Node3D, party: Array, center: Vector3) -> void:
	var active: Array[StringName] = []
	for a in party:
		_field.append(a)
		active.append(a.actor_id)
	var p: Dictionary = plan(Game.recruited, active, Game.sera_in_story)
	for id in p["bench"]:
		bench.append(_spawn(host, id, center))
	if p["hover"]:
		hover = _spawn(host, &"sera", center)


func _spawn(host: Node3D, id: StringName, center: Vector3) -> CombatActor:
	var a := CombatActor.create_party_member(id)
	a.name = "Reserve_" + String(id)
	host.add_child(a)
	a.global_position = center + Vector3(0.0, 0.0, 7.5)
	_park(a, true)
	_spawned.append(a)
	return a


## Hidden and frozen off the plane, or standing on it.
static func _park(a: CombatActor, parked: bool) -> void:
	a.visible = not parked
	a.frozen = parked
	a.collision_layer = 0 if parked else 2
	a.collision_mask = 0 if parked else 1
	a.velocity = Vector3.ZERO


func can_swap(c: BattleCoordinator) -> bool:
	for b in bench:
		if c._alive(b):
			return true
	return false


## The Swap sub-deck for `actor`'s window: each living bench member, as a trade for the actor and,
## when a KO'd ally lies within 3 m, as a trade for that ally. Either costs the actor's turn (SwapRules).
func deck_items(c: BattleCoordinator, actor: CombatActor) -> Array:
	var items: Array = []
	var koed: Array = []
	for u in c.party:
		if u != actor and not c._alive(u) and c.position_of(actor).distance_to(c.position_of(u)) <= SwapRules.KO_REACH_M:
			koed.append(u)
	for b in bench:
		if not c._alive(b):
			continue
		items.append({"label": "%s in for %s" % [b.stats.display_name, actor.stats.display_name], "cmd": "swap_in", "payload": {"incoming": b}})
		for k in koed:
			items.append({"label": "%s in for %s (KO)" % [b.stats.display_name, CombatantStats.of(k).display_name], "cmd": "swap_in", "payload": {"incoming": b, "koed": k}})
	items.append({"label": "Back", "cmd": "back"})
	return items


## Perform a swap chosen from the sub-deck; returns the coordinator's verdict ({ok, error}).
func perform(scene: BattleScene, actor: CombatActor, payload: Dictionary) -> Dictionary:
	var incoming: CombatActor = payload.get("incoming", null)
	var koed: CombatActor = payload.get("koed", null)
	var outgoing: CombatActor = koed if koed != null else actor
	var r: Dictionary = scene.coordinator.cmd_swap_koed(actor, koed, incoming) if koed != null else scene.coordinator.cmd_swap(actor, incoming)
	if not bool(r.get("ok", false)):
		return r
	_park(incoming, false)
	incoming.face_toward(scene.center - scene.party_side * 5.0)
	incoming.sprite.play(&"ready")
	_park(outgoing, true)
	var i: int = scene.party.find(outgoing)
	if i >= 0:
		scene.party[i] = incoming
	bench.erase(incoming)
	bench.append(outgoing)
	scene.hud.register_units(scene.coordinator.party, scene.enemies, hover)
	Audio.play_sfx("ui/confirm")
	return r


## The hover deck: Sera's Turn-Bar daggers (her `hover_*` techs she knows) and a pass.
func hover_deck(c: BattleCoordinator, actor: CombatActor) -> Array:
	var items: Array = []
	for t in c.available_techs(actor):
		if String(t.effect).begins_with("hover_"):
			items.append({"label": t.display_name, "cmd": "tech", "payload": {"tech": t}})
	items.append({"label": "Wait", "cmd": "guard"})
	return items


## Battle over: the field party stands again where it is, the reserves (benched, hovering or swapped in)
## write back (level, XP, HP ratio, Crono's integrity, Sera's Debt; one still down records `fallen_ratio`)
## and leave.
func finish(fallen_ratio: float = 0.3) -> void:
	for a in _field:
		if is_instance_valid(a):
			_park(a, false)
	for r in _spawned:
		if not is_instance_valid(r) or _field.has(r):
			continue
		BattleAftermath.write_back(r, fallen_ratio)
		r.queue_free()
	_spawned.clear()
	bench.clear()
	hover = null
