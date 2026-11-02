## Withdraw on the room's own ground (WalkableGround, WithdrawRules.fall_back, BattleAftermath.regroup): a
## fall-back lands only where the party can stand (Combat Laws Bible §2.1: the plane conforms to the terrain;
## DECISIONS "Withdraw"), the room's walkable edge counts as the plane's edge, and the hand-off stands the leader
## on the floor. A 12 x 12 m test floor and the shipped Chapter 1 Atrium (its lab mice by the south rim).
extends "res://tests/suite_base.gd"

const ATRIUM := "res://scenes/u0/atrium_horologe.tscn"


## Wait (real time, sped up) until the Location has run its end-of-battle hand-off.
func _await_finished(loc: Location, max_s: float = 8.0) -> bool:
	Engine.time_scale = 4.0
	var t: float = 0.0
	while loc.battle != null and t < max_s:
		await get_tree().create_timer(0.05).timeout
		t += 0.05
	await get_tree().process_frame
	Engine.time_scale = 1.0
	return loc.battle == null


func _actor(loc: Location, id: StringName) -> CombatActor:
	return loc.get_actor(id) as CombatActor


func _window_for(c: BattleCoordinator, actor: Node, max_s: float = 60.0) -> bool:
	var t: float = 0.0
	while t < max_s and c.state != BattleCoordinator.State.IDLE:
		var a: Node = _advance_until_window(c, max_s - t)
		if a == null:
			return false
		if a == actor:
			return true
		c.cmd_guard(a)
		t += 0.5
	return false


## World floor (layer 1) within `below` metres under `a`'s feet.
func _floor_under(a: Node3D, below: float = 0.5) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a.global_position + Vector3(0, 0.2, 0), a.global_position - Vector3(0, below, 0), 1)
	return not a.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _physics(seconds: float) -> void:
	for i in roundi(seconds * float(Engine.physics_ticks_per_second)):
		await get_tree().physics_frame


## A 12 x 12 m floor (top at y 0, edges at ±6) with a 1 m crate on the centre line at z -2.
func _small_room() -> Node3D:
	var host := Node3D.new()
	root.add_child(host)
	_track(host)
	var mat := StandardMaterial3D.new()
	SceneKit.floor_plane(host, Vector2(12, 12), Vector3.ZERO, mat)
	SceneKit.box(host, Vector3(1, 1, 1), Vector3(0, 0.5, -2), mat, "Crate")
	await _physics(0.05)
	return host


## The Atrium free to roam (Chapter 1 hub) with the lab zones awake, the hub party [sera, crono] at `start`.
func _atrium_hub() -> Location:
	Game.new_game()
	Game.set_chapter(1)
	Game.location = &"atrium"
	Game.spawn_point = &"loft_bed"
	Game.checkpoint = &"ch1_hub_free"
	var ids: Array[StringName] = [&"sera", &"crono"]
	Game.set_party(ids)
	Flags.set_flag(&"Atrium_Dummy", &"Spared")
	Story.auto_advance_s = 0.01
	Story.auto_choice = 0
	Story.skip_waits = true
	var loc: Location = (load(ATRIUM) as PackedScene).instantiate()
	root.add_child(loc)
	_track(loc)
	get_tree().current_scene = loc  # Story's `call` lands on the current scene
	var t: float = 0.0
	while (Story.is_running() or Router.transitioning) and t < 12.0:
		await get_tree().create_timer(0.05).timeout
		t += 0.05
	loc.place_party(&"start")
	await _physics(0.2)
	return loc


func _story_defaults() -> void:
	Story.auto_advance_s = -1.0
	Story.auto_choice = -1
	Story.skip_waits = false
	get_tree().current_scene = null


# ---------------------------------------------------------------- withdraw on the room's ground

## BATTLE-6 / GAP1-2 (refix): the ground a fall-back may land on: floor under the whole footprint, inside the
## map bounds less 0.6 m, clear of solids; a walk passes over a crate and ends where the floor does.
func test_walkable_ground_is_floor_inside_the_bounds_clear_of_solids() -> void:
	var host: Node3D = await _small_room()
	var g := WalkableGround.new(host)
	check(g.stand_at(Vector3(0, 0, 3)) is Vector3, "open floor holds a body")
	check(g.stand_at(Vector3(0, 0, 7)) == null, "past the floor's edge is the void")
	check(g.stand_at(Vector3(0, 0, 5.9)) == null, "a body hanging over the edge is not on the floor")
	check(g.stand_at(Vector3(0, 0, -2)) == null, "inside the crate is not standable")
	var bounded := WalkableGround.new(host, Rect2(-6, -6, 12, 10))
	check(bounded.stand_at(Vector3(0, 0, 3)) is Vector3 and bounded.stand_at(Vector3(0, 0, 3.8)) == null, "the map bounds less 0.6 m end the ground")
	var w: Dictionary = g.walk(Vector3(0, 0, 3), Vector3(0, 0, 13))
	var to: Vector3 = w["to"]
	check(to.z > 4.5 and to.z <= 5.61, "a walk toward the void stops on the last floor (z %.2f)" % to.z)
	check(float(w["edge_m"]) <= WalkableGround.STEP_M + 0.01, "and says the ground ends just past it")
	var past: Dictionary = g.walk(Vector3(0, 0, 0), Vector3(0, 0, -5))
	check_near((past["to"] as Vector3).z, -5.0, 0.01, "a crate on the way is passed over, as Move passes over it")
	check(float(past["edge_m"]) == INF, "the ground does not end there")


## BATTLE-6 / GAP1-2 (refix): in a room smaller than the 28 m plane the fall-back lands on the room's floor, its
## walkable edge counts as the plane's edge, and the ally (not frozen in battle) never falls off it.
func test_withdraw_in_a_small_room_stays_on_the_floor() -> void:
	Game.new_game()
	var host: Node3D = await _small_room()
	var crono := CombatActor.create_party_member(&"crono")
	host.add_child(crono)
	crono.global_position = Vector3(0, 0, 3)  # 3 m from the floor's south edge, 11 m from the plane's
	var e := _enemy(&"mote", 3, Vector3(0, 0, -4), 2, [&"SWORD"])
	var c := _coord()
	c.party_hp_floor = 1
	_start(c, [crono], [e], {"ground": WalkableGround.new(host)})
	check(_window_for(c, crono), "Crono gets a window")
	c.gauges[e] = 85.0
	var r1: Dictionary = c.cmd_withdraw(crono)
	check(bool(r1.get("reached_edge", false)) and not bool(r1.get("withdrew", true)), "he reaches the room's edge at once; an enemy above 80 holds him")
	check(crono.global_position.z > 4.5 and crono.global_position.z <= 5.61, "on the last metre of floor, not 13 m out (z %.2f)" % crono.global_position.z)
	await _physics(0.5)
	check(_floor_under(crono) and crono.global_position.y > -0.5, "still standing on it once the physics has run (y %.2f)" % crono.global_position.y)
	check(_window_for(c, crono), "Crono's next window")
	c.gauges[e] = 0.0
	check(bool(c.cmd_withdraw(crono).get("withdrew", false)), "at the walkable edge the withdraw succeeds")
	var at: Variant = c.last_summary.get("withdraw_at", null)
	check(at is Vector3 and WalkableGround.new(host).stand_at(at) != null, "the withdraw point is ground the party can stand on")
	Game.new_game()


## BATTLE-6 / GAP1-2 (refix), the shipped case: Crono withdrawing from the Atrium's lab mice falls back toward the
## hall's south rim and never past its floor (radius 13.5 m, a ledge at 13.6 m); the hand-off stands Sera, the
## leader, where he broke away, and both are on the floor a second later.
func test_atrium_lab_withdraw_never_leaves_the_hall() -> void:
	var loc: Location = await _atrium_hub()
	var z: EncounterZone = null
	for zone in loc.zones:
		if zone.encounter_id == &"atrium_lab_mice":
			z = zone
	check(z != null, "the lab mice zone is awake")
	if z == null:
		_story_defaults()
		return
	z.active = false
	loc._on_zone_triggered(z, "normal")
	var c: BattleCoordinator = loc.battle.coordinator
	c.auto_tick = false
	c.party_hp_floor = 1
	var crono: CombatActor = _actor(loc, &"crono")
	var sera: CombatActor = _actor(loc, &"sera")
	check(c.ground != null, "the Atrium gives the battle its floor")
	var withdrew: bool = false
	for i in 4:
		if not _window_for(c, crono):
			break
		for e in c.enemies:
			c.gauges[e] = 0.0
		var r: Dictionary = c.cmd_withdraw(crono)
		await _physics(0.5)
		var p: Vector3 = crono.global_position
		check(_floor_under(crono) and p.y > -0.5, "fall-back %d: Crono stands on the hall floor (%.2f, %.2f, %.2f; %.2f m out)" % [i + 1, p.x, p.y, p.z, Vector2(p.x, p.z).length()])
		if bool(r.get("withdrew", false)):
			withdrew = true
			break
	check(withdrew, "Crono withdraws within a few turns")
	check(await _await_finished(loc), "the battle hands back to the field")
	await _physics(1.0)
	var s: Vector3 = sera.global_position
	check(_floor_under(sera) and s.y > -0.5, "Sera, the leader, stands on the hall floor a second after the hand-off (%.2f, %.2f, %.2f)" % [s.x, s.y, s.z])
	check(Vector2(s.x, s.z).length() < 13.5, "inside the hall's 13.5 m floor")
	check(_floor_under(crono) and crono.global_position.y > -0.5, "and so does Crono behind her")
	_story_defaults()
	Game.new_game()
