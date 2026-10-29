## Auto-pilot for scenes/combat_sandbox.tscn: plays the battle with a simple
## policy and logs every event. Headless runs quit when the battle ends.
##   godot --headless --path . res://scenes/combat_sandbox.tscn
extends Node3D

## Auto-play battles (always on when running headless). Off = play with the HUD keys.
@export var autoplay: bool = false

var _held_once: Dictionary = {}
var _log_lines: int = 0

@onready var coordinator: HybridBattleCoordinator = $HybridBattleCoordinator


func _is_auto() -> bool:
	return autoplay or DisplayServer.get_name() == "headless"


func _ready() -> void:
	var leader: Node = get_tree().get_first_node_in_group(&"party_leader")
	coordinator.exploration_lock_changed.connect(func(locked):
		for p in get_tree().get_nodes_in_group(&"party"):
			p.input_locked = locked
		_log("exploration %s" % ("locked" if locked else "unlocked")))
	if _is_auto() and leader:
		# Walk the leader into the encounter zone to exercise the real trigger path.
		leader.move_to.call_deferred($EncounterZone_01.global_position)
	coordinator.combat_started.connect(func(c): _log("combat started at %s" % c))
	coordinator.actor_ready_for_command.connect(_on_ready_for_command)
	coordinator.enemy_turn_started.connect(func(e): _log("enemy turn: %s" % e.name))
	coordinator.enemy_broken.connect(func(e, _b): _log("BREAK! %s" % e.name))
	coordinator.enemy_recovered.connect(func(e): _log("%s recovers its shields" % e.name))
	coordinator.tech_executed.connect(func(t, casters, lvl, targets):
		_log("%s (Boost %d) by %s hit %d target(s)" % [t.display_name, lvl, casters.map(func(c): return c.name), targets.size()]))
	coordinator.strike_resolved.connect(func(a, t, dmg, res):
		_log("  %s -> %s: %d dmg x%.1f shave %d" % [a.name, t.name, dmg, res["damage_multiplier"], res["shields_shaved"]]))
	coordinator.combat_ended.connect(_on_combat_ended)


func _on_ready_for_command(actor: Node3D, techs: Array[TechResource]) -> void:
	if not _is_auto():
		return
	# Defer so we never re-enter the coordinator from inside its own signal.
	_decide.call_deferred(actor, techs)


func _decide(actor: Node3D, techs: Array[TechResource]) -> void:
	if coordinator.active_actor != actor:
		return
	var target: Node3D = null
	for e in coordinator.active_enemies:
		if CombatantStats.of(e).is_alive():
			target = e
			break
	if target == null:
		return

	var best: TechResource = null
	for t in techs:
		if t.tier != TechResource.TechTier.SINGLE and (best == null or t.tier > best.tier):
			best = t
	if best:
		var pooled := 0
		for c in coordinator.ready_pool:
			if best.required_actor_ids.has(CombatantStats.of(c).actor_id):
				pooled += c.get_node("BoostComponent").current_bp
		coordinator.execute_tech(best, actor, target, mini(3, pooled))
		return

	if not _held_once.get(actor, false) and coordinator.ready_pool.size() == 1:
		_held_once[actor] = true
		_log("%s: Sync Hold" % actor.name)
		coordinator.command_sync_hold(actor)
		return
	_held_once[actor] = false
	var bp: int = actor.get_node("BoostComponent").current_bp
	coordinator.execute_basic_attack(actor, target, 1 if bp >= 2 else 0)
	_log("%s: attack (bp left %d)" % [actor.name, actor.get_node("BoostComponent").current_bp])


func _on_combat_ended(victory: bool) -> void:
	_log("COMBAT ENDED — %s" % ("VICTORY" if victory else "DEFEAT"))
	if DisplayServer.get_name() == "headless":
		get_tree().create_timer(1.0).timeout.connect(get_tree().quit)


func _log(s: String) -> void:
	_log_lines += 1
	print("[%6.2fs] %s" % [Time.get_ticks_msec() / 1000.0, s])
