## The Atrium Horologe (Story Bible U0, §9.7; Reference Bible §3.2, plate-00): Porre's gutted clocktower
## in Truce, grown through by Robo. A vertical brass cylinder: moss-garden floor, workbench ring, gate ring,
## and at its centre Robo's torso as the clock pillar. The hub: save, heal, swap, inspect, plant, train,
## choose a gate. Chapter 1 plays out here (beats 1–9) before the Fair.
extends Location

const GATE_UNIVERSES := [1, 2, 3, 4, 5, 6, 7, 8]
const GATE_COLOURS := {
	1: Color(0.75, 0.33, 0.26), 2: Color(0.77, 0.54, 0.25), 3: Color(0.43, 0.62, 0.64), 4: Color(0.17, 0.3, 0.61),
	5: Color(0.78, 0.23, 0.2), 6: Color(0.0, 0.94, 1.0), 7: Color(0.83, 0.69, 0.22), 8: Color(0.55, 0.49, 1.0),
}
const GATE_LOCATIONS := {1: &"bamboo_grove", 2: &"proto_dome", 3: &"eden_canopy", 4: &"cathedral_nave", 5: &"carnival_midway", 6: &"neo_truce", 7: &"bone_tree_root", 8: &"vaelos_heart"}
const LOFT_Y := 3.2

# Chapter 1 checkpoints, in order.
const CP_ARRIVAL := &"atrium_arrival"
const CP_HUB := &"atrium_hub"
const CP_LOFT := &"ch1_loft"             # Sera wakes; look at her father
const CP_REWIND := &"ch1_rewind"         # the nightmare; press R
const CP_DOWNSTAIRS := &"ch1_downstairs" # walk down; Father Tank at the window
const CP_FREE := &"ch1_hub_free"         # the hub loop: dummy, seed, marks, Glenn
const CP_NIGHT := &"ch1_night"           # after the dummy and a rest: midnight, the hearth
const CP_FAIR := &"ch1_fair_ready"       # the hearth choice is made; the Fair opens

var pillar_face: MeshInstance3D
var hour_hand: MeshInstance3D
var minute_hand: MeshInstance3D
var eye_right: MeshInstance3D
var eye_left: MeshInstance3D
var vines: Array[MeshInstance3D] = []
var pool_water: MeshInstance3D
var gates: Dictionary = {}
var tower_time: float = 7.0  # hours; one real minute is one hour
var midnight_done: bool = false
var ink_path: InkPath
var window_ink: GPUParticles3D
var downstairs_trigger: Area3D
var hearth_interact: Interactable
var glenn_npc: FieldNPC
var _vine_t: float = 0.0
var _focus_hold: float = 0.0
var _idle_time: float = 0.0
var _lotus: MeshInstance3D
var _dummy_pending: bool = false


func build() -> void:
	location_id = &"atrium"
	universe_id = 0
	field_music = &"mus_u0_wind_scene_1024"
	ambience = &"amb_u0"
	camera_distance = 16.0
	camera_pitch = 34.0
	map_bounds = Rect2(-13, -13, 26, 26)
	var stone := SceneKit.material("res://assets/textures/stone_albedo.png", "res://assets/textures/stone_normal.png", 0.95, Color(0.9, 0.86, 0.78), true)
	var mossy := SceneKit.material("res://assets/textures/stone_mossy_albedo.png", "res://assets/textures/stone_normal.png", 0.95, Color(0.95, 0.95, 0.9), true)
	var wall := SceneKit.material("res://assets/textures/castle_wall_albedo.png", "res://assets/textures/castle_wall_normal.png", 0.9, Color(0.85, 0.78, 0.65), true)
	var wood := SceneKit.material("res://assets/textures/wood_albedo.png", "res://assets/textures/wood_normal.png", 0.85, Color.WHITE, true)
	var brass := SceneKit.flat_color(Color(0.74, 0.56, 0.28), Color.BLACK, 0.0, 0.35, 0.85)
	var dark_brass := SceneKit.flat_color(Color(0.42, 0.3, 0.16), Color.BLACK, 0.0, 0.5, 0.8)
	var copper := SceneKit.flat_color(Color(0.72, 0.42, 0.25), Color(1.0, 0.45, 0.15), 1.2, 0.4, 0.8)
	var porcelain := SceneKit.flat_color(Color(0.93, 0.92, 0.88), Color.BLACK, 0.0, 0.35)
	# ---- the round hall: floor rings (stone inner, moss garden outer), a perimeter wall and columns
	SceneKit.cylinder(self, 13.5, 0.2, Vector3(0, -0.1, 0), mossy, "GardenFloor")
	SceneKit.cylinder(self, 8.0, 0.24, Vector3(0, -0.1, 0), stone, "StoneFloor", false)
	_ring_wall(13.6, 7.0, wall, 28)
	for i in 12:
		var a: float = float(i) / 12.0 * TAU
		SceneKit.cylinder(self, 0.45, 8.0, Vector3(cos(a) * 12.6, 4.0, sin(a) * 12.6), wall, "Column%d" % i)
		var bal := SceneKit.box(self, Vector3(5.5, 0.25, 1.6), Vector3(cos(a + TAU / 24.0) * 12.4, 4.5, sin(a + TAU / 24.0) * 12.4), wood, "Balcony%d" % i, false)
		bal.rotation.y = -(a + TAU / 24.0) + PI * 0.5
	for i in 7:
		SceneKit.cylinder(self, 0.18 + 0.03 * float(i % 3), 3.0 + 0.6 * float(i), Vector3(11.4, 2.0 + 0.3 * float(i), -3.0 + float(i) * 0.9), brass, "Pipe%d" % i, false)
	# ---- the dais and the pillar (Robo's torso), the clock face, the hands, the copper vines
	SceneKit.cylinder(self, 3.2, 0.5, Vector3(0, 0.25, 0), stone, "Dais")
	SceneKit.cylinder(self, 2.4, 0.4, Vector3(0, 0.7, 0), dark_brass, "DaisStep")
	SceneKit.cylinder(self, 1.3, 7.0, Vector3(0, 4.4, 0), dark_brass, "Pillar")
	for i in 6:
		var a2: float = float(i) / 6.0 * TAU
		var rib := SceneKit.box(self, Vector3(0.18, 3.2, 0.18), Vector3(cos(a2) * 1.75, 3.2, sin(a2) * 1.75), brass, "Rib%d" % i, false)
		rib.rotation.z = 0.18 * cos(a2)
		rib.rotation.x = -0.18 * sin(a2)
	for i in 10:
		var a3: float = float(i) / 10.0 * TAU + 0.3
		var v := SceneKit.cylinder(self, 0.06, 5.5 + float(i % 3) * 0.6, Vector3(cos(a3) * 1.55, 3.6, sin(a3) * 1.55), copper, "Vine%d" % i, false)
		v.rotation.z = 0.12 * sin(a3 * 2.0)
		v.material_override = (copper as StandardMaterial3D).duplicate()
		vines.append(v)
	pillar_face = SceneKit.cylinder(self, 1.6, 0.25, Vector3(0, 7.8, 1.3), porcelain, "ClockFace", false)
	pillar_face.rotation.x = PI * 0.5
	var ink := SceneKit.flat_color(Color(0.1, 0.1, 0.12), Color.BLACK, 0.0, 0.4)
	hour_hand = SceneKit.box(self, Vector3(0.12, 0.9, 0.06), Vector3(0.0, 8.2, 1.46), ink, "HourHand", false)
	minute_hand = SceneKit.box(self, Vector3(0.08, 1.3, 0.06), Vector3(0.0, 8.4, 1.48), ink, "MinuteHand", false)
	var blue := SceneKit.flat_color(Color(0.2, 0.5, 1.0), Color(0.3, 0.6, 1.0), 2.5, 0.2)
	var black := SceneKit.flat_color(Color(0.02, 0.02, 0.03), Color.BLACK, 0.0, 0.2)
	eye_right = SceneKit.cylinder(self, 0.22, 0.1, Vector3(-0.55, 8.1, 1.44), blue, "EyeRight", false)
	eye_right.rotation.x = PI * 0.5
	eye_left = SceneKit.cylinder(self, 0.22, 0.1, Vector3(0.55, 8.1, 1.44), black, "EyeLeft", false)
	eye_left.rotation.x = PI * 0.5
	SceneKit.omni(self, Vector3(0, 7.5, 3.0), Color(0.35, 0.55, 1.0), 2.0, 9.0, false)
	# ---- the pool (a reused U4 well), the garden and the Seed's pot
	SceneKit.cylinder(self, 1.9, 0.6, Vector3(-4.5, 0.3, 4.0), stone, "PoolRim")
	var water := SceneKit.flat_color(Color(0.25, 0.45, 0.6, 0.85), Color(0.2, 0.4, 0.6), 0.6, 0.05)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool_water = SceneKit.cylinder(self, 1.6, 0.1, Vector3(-4.5, 0.58, 4.0), water, "PoolWater", false)
	var terracotta := SceneKit.flat_color(Color(0.6, 0.38, 0.25), Color.BLACK, 0.0, 0.9)
	SceneKit.cylinder(self, 0.5, 0.7, Vector3(5.5, 0.35, 5.5), terracotta, "SeedPot")
	var mercury := SceneKit.flat_color(Color(0.8, 0.82, 0.85), Color(0.6, 0.65, 0.7), 0.5, 0.1, 1.0)
	SceneKit.cylinder(self, 0.18, 0.18, Vector3(5.5, 0.8, 5.5), mercury, "SeedOrb", false)
	# ---- the workbench ring (north), the gramophone at six o'clock, Lucca's dummy lab at north-west
	SceneKit.box(self, Vector3(4.0, 0.9, 1.0), Vector3(0.0, 0.45, -9.5), wood, "Workbench")
	SceneKit.box(self, Vector3(1.6, 0.9, 1.0), Vector3(5.0, 0.45, -9.0), wood, "Workbench2")
	SceneKit.cylinder(self, 0.4, 0.9, Vector3(0.0, 0.45, 9.8), wood, "GramophoneTable")
	var horn := SceneKit.cylinder(self, 0.5, 0.8, Vector3(0.0, 1.45, 9.8), brass, "GramophoneHorn", false)
	horn.rotation.x = -0.9
	SceneKit.box(self, Vector3(1.4, 0.2, 1.4), Vector3(-8.0, 0.1, -8.0), stone, "DummyPlinth")
	# the hearth (west): a brass stove with embers, where the family sits at night
	var hearth_m := SceneKit.flat_color(Color(0.22, 0.2, 0.19), Color.BLACK, 0.0, 0.9)
	SceneKit.box(self, Vector3(1.2, 1.6, 1.8), Vector3(-11.6, 0.8, 1.5), hearth_m, "Hearth")
	var ember := SceneKit.flat_color(Color(1.0, 0.45, 0.1), Color(1.0, 0.5, 0.12), 3.0)
	SceneKit.box(self, Vector3(0.3, 0.4, 1.0), Vector3(-10.95, 0.5, 1.5), ember, "Embers", false)
	SceneKit.omni(self, Vector3(-10.0, 1.0, 1.5), Color(1.0, 0.62, 0.3), 1.8, 6.0, false)
	for bz in [0.2, 2.8]:
		SceneKit.box(self, Vector3(1.2, 0.45, 0.5), Vector3(-9.6, 0.225, bz), wood, "HearthBench")
	# ---- the loft: a wall of Crono's old Truce house set into the tower, reached by a brass ramp-stair
	SceneKit.box(self, Vector3(6.0, 0.3, 5.0), Vector3(8.0, LOFT_Y - 0.15, -7.0), wood, "LoftFloor")
	var plaster := SceneKit.flat_color(Color(0.86, 0.8, 0.68), Color.BLACK, 0.0, 1.0)
	SceneKit.box(self, Vector3(6.0, 3.0, 0.3), Vector3(8.0, LOFT_Y + 1.5, -9.4), plaster, "LoftWall", false)
	var win_m := SceneKit.flat_color(Color(0.55, 0.65, 0.85), Color(0.6, 0.7, 0.9), 0.8, 0.2)
	SceneKit.box(self, Vector3(1.2, 1.4, 0.1), Vector3(6.8, LOFT_Y + 1.7, -9.2), win_m, "LoftWindow", false)
	SceneKit.box(self, Vector3(1.6, 0.5, 2.2), Vector3(9.8, LOFT_Y + 0.25, -7.5), SceneKit.flat_color(Color(0.5, 0.3, 0.3)), "SeraBed", false)
	SceneKit.box(self, Vector3(1.0, 1.2, 0.6), Vector3(6.0, LOFT_Y + 0.6, -8.5), wood, "CronoChair", false)
	SceneKit.box(self, Vector3(0.1, 1.0, 5.0), Vector3(5.0, LOFT_Y + 0.5, -7.0), brass, "LoftRailW", false)
	SceneKit.box(self, Vector3(6.0, 1.0, 0.1), Vector3(8.0, LOFT_Y + 0.5, -4.5), brass, "LoftRailS", false)
	# the ramp (walkable) from (5.2, 0, -1.0) rising to the loft edge at z = -4.5; stair treads over it for the look
	var ramp_len: float = 6.2
	var ramp := SceneKit.box(self, Vector3(1.6, 0.2, ramp_len), Vector3(5.2, LOFT_Y * 0.5 - 0.1, -1.5 - 0.0), dark_brass, "Ramp")
	ramp.rotation.x = atan2(LOFT_Y, ramp_len - 0.6)
	ramp.position = Vector3(5.2, LOFT_Y * 0.5 - 0.1, -1.6)
	for i in 10:
		var t: float = float(i) / 9.0
		SceneKit.box(self, Vector3(1.6, 0.12, 0.6), Vector3(5.2, 0.1 + t * (LOFT_Y - 0.2), 1.3 - t * 5.8), brass, "Tread%d" % i, false)
	# ---- the gate ring
	for u in GATE_UNIVERSES:
		var a4: float = (float(GATE_UNIVERSES.find(u)) + 0.5) / 8.0 * TAU + PI * 0.5
		_build_gate(u, Vector3(cos(a4) * 11.2, 0.0, sin(a4) * 11.2), a4, dark_brass)
	# ---- a shaft of light from the dome
	var dome := SpotLight3D.new()
	dome.position = Vector3(-3.0, 14.0, -2.0)
	dome.rotation_degrees = Vector3(-80, 0, 0)
	dome.light_color = Color(1.0, 0.9, 0.7)
	dome.light_energy = 6.0
	dome.spot_range = 20.0
	dome.spot_angle = 28.0
	dome.shadow_enabled = true
	add_child(dome)
	# ---- markers
	add_marker("start", Vector3(0, 0, 7.0))
	add_marker("arrival", Vector3(0, 0, 10.5))
	add_marker("dais", Vector3(0, 0, 4.2))
	add_marker("pool", Vector3(-4.5, 0, 6.3))
	add_marker("dummy", Vector3(-7.0, 0, -6.0))
	add_marker("dummy_center", Vector3(-6.0, 0, -4.5))
	add_marker("dummy_boss", Vector3(-8.0, 0, -7.2))
	add_marker("seed", Vector3(5.5, 0, 4.2))
	add_marker("loft", Vector3(8.0, LOFT_Y, -6.0))
	add_marker("loft_bed", Vector3(9.4, LOFT_Y, -6.0))
	add_marker("loft_chair", Vector3(6.3, LOFT_Y, -7.6))
	add_marker("loft_window", Vector3(6.8, LOFT_Y, -8.6))
	add_marker("ramp_top", Vector3(5.2, LOFT_Y, -4.6))
	add_marker("ramp_bottom", Vector3(5.2, 0, 1.6))
	add_marker("window_ink", Vector3(9.5, 0, 6.5))
	add_marker("father_tank", Vector3(7.5, 0, 4.0))
	add_marker("workbench", Vector3(0.0, 0.0, -8.3))
	add_marker("hearth", Vector3(-9.0, 0.0, 1.5))
	add_marker("hearth_crono", Vector3(-9.6, 0.0, 0.9))
	add_marker("hearth_marle", Vector3(-9.6, 0.0, 2.3))
	add_marker("glenn", Vector3(-6.2, 0.0, -7.6))
	add_marker("right_gate", Vector3(10.5, 0.0, 3.5))
	# ---- interactables
	var robo := Interactable.make(self, "Robo", Vector3(0, 1.0, 3.4), &"", "Robo", 1.3)
	robo.callback = Callable(self, "_talk_robo")
	Interactable.make(self, "Pool", Vector3(-4.5, 0.8, 6.0), &"atrium_pool", "The pool", 1.0)
	var seed := Interactable.make(self, "SeedPot", Vector3(5.5, 0.8, 4.6), &"", "The Seed of Doan", 1.0)
	seed.callback = Callable(self, "_use_seed")
	Interactable.make(self, "Gramophone", Vector3(0.0, 0.8, 9.2), &"atrium_gramophone", "Gramophone", 1.0)
	Interactable.make(self, "Workbench", Vector3(0.0, 0.8, -8.7), &"atrium_workbench", "Workbench", 1.1)
	var dummy := Interactable.make(self, "Dummy", Vector3(-7.4, 0.8, -6.6), &"", "The 999 Shield Dummy", 1.3)
	dummy.callback = Callable(self, "_use_dummy")
	hearth_interact = Interactable.make(self, "HearthSeat", Vector3(-9.0, 0.8, 1.5), &"", "The hearth", 1.1)
	hearth_interact.callback = Callable(self, "_use_hearth")
	var dummy_actor := add_npc(&"shard_doll_999", "shard_doll_999", Vector3(-8.0, 0.2, -8.0), "s")
	dummy_actor.frozen = true
	# the ink that gathers at the east window (Father Tank)
	_build_window_ink()
	downstairs_trigger = _trigger(Vector3(5.2, 0.8, 2.6), Vector3(3.0, 2.0, 2.0))
	downstairs_trigger.body_entered.connect(_on_downstairs)


func after_ready() -> void:
	var cp: StringName = Game.checkpoint
	_place_cast(cp)
	match cp:
		CP_ARRIVAL:
			await Story.run(&"ch1_arrival")
			await _time_skip_to_loft()
		CP_HUB:
			await _time_skip_to_loft()
		CP_LOFT:
			_begin_loft()
		CP_REWIND:
			_begin_loft(true)
		CP_DOWNSTAIRS:
			downstairs_trigger.set_deferred("monitoring", true)
		CP_FREE, CP_NIGHT, CP_FAIR:
			_free_roam_setup()
	for arg in OS.get_cmdline_user_args():
		if arg == "--demo=dummy":
			await get_tree().create_timer(0.4).timeout
			_use_dummy(null)


# ------------------------------------------------------------------ cast and state placement

func _place_cast(cp: StringName) -> void:
	if cp == CP_LOFT or cp == CP_REWIND:
		if Game.active_party != [&"sera"]:
			Game.set_party([&"sera"])
		var crono := add_cast(&"crono", get_marker("loft_chair"), "e")
		crono.sprite.play(&"hurt")  # asleep sitting up; the hurt frame reads as slumped
		crono.sprite.set_tint(Color(0.85, 0.85, 0.9))
	elif cp == CP_DOWNSTAIRS:
		if Game.active_party != [&"sera"]:
			Game.set_party([&"sera"])
		add_cast(&"crono", get_marker("ramp_bottom") + Vector3(1.5, 0, 0.5), "e")
	if cp == CP_FREE or cp == CP_NIGHT or cp == CP_FAIR or cp == CP_ARRIVAL or cp == CP_HUB:
		add_cast(&"marle", get_marker("hearth_marle"), "w", &"atrium_marle", "Marle")
	if Flags.has(&"Atrium_Dummy") and (cp == CP_FREE or cp == CP_NIGHT or cp == CP_FAIR):
		_spawn_glenn()


func _time_skip_to_loft() -> void:
	controller.enabled = false
	await Router.fade_out(1.2)
	await Story.run(&"ch1_time_skip")
	Game.checkpoint = CP_LOFT
	Game.set_party([&"sera"])
	Router.go(&"atrium", &"loft_bed", 0.0)


func _begin_loft(rewind_stage: bool = false) -> void:
	place_party(&"loft_bed")
	rig.distance = 11.0
	rig.snap()
	Saves.save(0)
	if not rewind_stage:
		await Story.run(&"ch1_loft_wake")
		_focus_hold = 0.0
	else:
		await Story.run(&"ch1_rewind_prompt")


func _free_roam_setup() -> void:
	if Game.active_party.size() < 2:
		Game.set_party([&"sera", &"crono"])
		rebuild_party([&"sera", &"crono"], &"start")
	_activate_lab_zones()
	_krona_marks()
	if Game.checkpoint == CP_NIGHT:
		tower_time = 23.4
	if Game.checkpoint == CP_FAIR and not Flags.has(&"Ch1_Fair_Left"):
		await get_tree().create_timer(0.6).timeout
		await Story.run(&"ch1_fair_call")


# ------------------------------------------------------------------ per frame

func _process(delta: float) -> void:
	super._process(delta)
	tower_time = fmod(tower_time + delta / 60.0, 24.0)
	if hour_hand:
		hour_hand.rotation.z = -tower_time / 12.0 * TAU
		hour_hand.position = Vector3(sin(-hour_hand.rotation.z) * 0.45, 7.8 + cos(hour_hand.rotation.z) * 0.45, 1.46)
	if minute_hand:
		minute_hand.rotation.z = -fmod(tower_time, 1.0) * TAU
		minute_hand.position = Vector3(sin(-minute_hand.rotation.z) * 0.65, 7.8 + cos(minute_hand.rotation.z) * 0.65, 1.48)
	_vine_t += delta
	var beat: float = 0.5 + 0.5 * pow(maxf(0.0, sin(_vine_t * 72.0 / 60.0 * TAU)), 6.0)
	for v in vines:
		var m := v.material_override as StandardMaterial3D
		if m:
			m.emission_energy_multiplier = 0.6 + 1.6 * beat
	# Chapter 1 beat 1: hold focus on her father long enough and the crack check plays
	if Game.checkpoint == CP_LOFT and controller and controller.focusing and not Story.is_running():
		_focus_hold += delta
		if _focus_hold >= 1.2:
			_focus_hold = -100.0
			_crack_check()
	# midnight: both eyes shut and the tower inhales
	if (Game.checkpoint == CP_NIGHT or Game.checkpoint == CP_FAIR) and tower_time >= 23.95 and not midnight_done:
		midnight_done = true
		_midnight()
	# standing still for ten seconds makes a gold-black lotus bloom by the right gate
	if controller and controller.leader and controller.leader.velocity.length() < 0.05 and not Story.is_running():
		_idle_time += delta
		if _idle_time > 10.0 and _lotus == null and Game.checkpoint == CP_FREE:
			_bloom_lotus()
	else:
		_idle_time = 0.0


func _on_focus(on: bool) -> void:
	super._on_focus(on)
	if not on:
		_focus_hold = 0.0


# ------------------------------------------------------------------ Chapter 1 beats

func _crack_check() -> void:
	await Story.run(&"ch1_crack_check")
	await Story.run(&"ch1_nightmare")
	Game.checkpoint = CP_REWIND
	Saves.save(0)
	await Story.run(&"ch1_rewind_prompt")


func _on_rewind() -> void:
	if Story.is_running():
		return
	var sera: Node = get_actor(&"sera")
	if Game.checkpoint == CP_REWIND:
		var crono: Node = get_actor(&"crono")
		field_rewind(sera, crono)
		Game.checkpoint = CP_DOWNSTAIRS
		await get_tree().create_timer(1.6).timeout
		await Story.run(&"ch1_after_rewind")
		downstairs_trigger.set_deferred("monitoring", true)
		Saves.save(0)
	elif sera != null:
		field_rewind(sera, null)
		prompt_label.text = "Nothing here to rewind. The Debt took its 5% anyway."
		prompt_label.visible = true
		await get_tree().create_timer(2.0).timeout
		prompt_label.visible = false


func _on_downstairs(body: Node3D) -> void:
	if Game.checkpoint != CP_DOWNSTAIRS or party_actors.is_empty() or body != party_actors[0] or Story.is_running():
		return
	downstairs_trigger.set_deferred("monitoring", false)
	var crono: Node = get_actor(&"crono")
	if crono is CombatActor:
		(crono as CombatActor).global_position = get_marker("ramp_bottom") + Vector3(1.5, 0, 0.5)
		(crono as CombatActor).sprite.set_tint(Color.WHITE)
	window_ink.emitting = true
	await Story.run(&"ch1_father_tank")
	window_ink.emitting = false
	rebuild_party([&"sera", &"crono"])
	Game.checkpoint = CP_FREE
	_free_roam_setup()
	Saves.save(0)
	await Story.run(&"ch1_hub_tutorial")


## Scripted: Crono steps between Sera and the window where ink is gathering.
func father_tank_step() -> void:
	var crono: Node = get_actor(&"crono")
	var sera: Node = get_actor(&"sera")
	if crono is CombatActor and sera is CombatActor:
		var s := sera as CombatActor
		var w: Vector3 = get_marker("window_ink")
		var between: Vector3 = s.global_position.lerp(w, 0.45)
		await (crono as CombatActor).walk_to(between, 5.0)
		(crono as CombatActor).face_toward(w)
		s.face_toward(between)


## Scripted: the wrist reveal when Crono looks away (Porcelain Wrist Reveal; the party gains Concerned).
func wrist_reveal() -> void:
	var crono: Node = get_actor(&"crono")
	if crono is CombatActor:
		var c := crono as CombatActor
		c.sprite.set_porcelain(2, 0.8, 0.0)
		rig.set_truth(true)
		Audio.play_sfx("porcelain/tink")
		await get_tree().create_timer(1.6).timeout
		rig.set_truth(false)
		c.set_porcelain_visuals()
	Flags.add_counter(&"concerned", 1)


func _activate_lab_zones() -> void:
	if zones.any(func(z: EncounterZone) -> bool: return z.encounter_id == &"atrium_lab_mice"):
		return
	# memory echoes leak near the dummy lab once its shields have been stressed
	if Flags.has(&"Atrium_Dummy"):
		var z1 := add_zone(&"atrium_lab_mice", Vector3(-9.0, 0, -3.0), 2.0)
		z1.spawn(self)
		z1.triggered.connect(_on_zone_triggered)
		var z2 := add_zone(&"atrium_lab_fragment", Vector3(-3.5, 0, -9.5), 1.8)
		z2.spawn(self)
		z2.triggered.connect(_on_zone_triggered)


func _krona_marks() -> void:
	if ink_path != null or Flags.counter(&"seed_waters") > 0:
		return
	# barefoot indigo prints from the dais to the garden pot: Sera's slips leaking U1 ink
	ink_path = InkPath.make(self, [Vector3(1.5, 0, 3.6), Vector3(3.0, 0, 4.6), Vector3(4.6, 0, 4.9), Vector3(5.4, 0, 4.4)], 30.0)
	ink_path.prismatic = Flags.prismatic > Flags.light and Flags.prismatic > Flags.dark
	if ink_path.prismatic:
		ink_path.life = 15.0


func _bloom_lotus() -> void:
	var m := SceneKit.flat_color(Color(0.1, 0.08, 0.05), Color(0.9, 0.7, 0.2), 1.5, 0.4)
	_lotus = SceneKit.cylinder(self, 0.25, 0.12, get_marker("right_gate") + Vector3(0, 0.06, 0), m, "Lotus", false)
	_lotus.scale = Vector3(0.1, 1.0, 0.1)
	var tw := create_tween()
	tw.tween_property(_lotus, "scale", Vector3(1.0, 1.0, 1.0), 1.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play_sfx("porcelain/wind_chime_crack")
	Flags.add_counter(&"lotus_seen", 1)


func _use_seed(_by: Node) -> void:
	if Flags.counter(&"seed_waters") == 0 and Game.checkpoint != CP_LOFT:
		await Story.run(&"atrium_seed_first_water")
	else:
		Story.run(&"atrium_seed")


## Scripted: the first watering. The orb becomes a sprout with a tiny gramophone horn.
func water_seed() -> void:
	Flags.add_counter(&"seed_waters", 1)
	var orb: Node = get_node_or_null("SeedOrb")
	if orb:
		orb.queue_free()
	var green := SceneKit.flat_color(Color(0.45, 0.6, 0.3), Color.BLACK, 0.0, 0.9)
	SceneKit.cylinder(self, 0.04, 0.5, Vector3(5.5, 0.95, 5.5), green, "Sprout", false)
	var brass := SceneKit.flat_color(Color(0.74, 0.56, 0.28), Color.BLACK, 0.0, 0.35, 0.85)
	var horn := SceneKit.cylinder(self, 0.12, 0.2, Vector3(5.5, 1.25, 5.4), brass, "SproutHorn", false)
	horn.rotation.x = -0.6
	if ink_path:
		ink_path.active = false
	Audio.play_sfx("ui/gramophone_needle")


func _use_dummy(_by: Node) -> void:
	if Game.checkpoint == CP_LOFT or Game.checkpoint == CP_REWIND or Game.checkpoint == CP_DOWNSTAIRS:
		Story.run(&"atrium_dummy")
		return
	if Flags.has(&"Atrium_Dummy"):
		Story.run(&"atrium_dummy_after")
		return
	if _dummy_pending:
		return
	_dummy_pending = true
	await Story.run(&"ch1_dummy_sequence")
	_dummy_pending = false
	if Flags.has(&"Atrium_Dummy"):
		_activate_lab_zones()
		_spawn_glenn()
		if Flags.is_state(&"Atrium_Dummy", &"Salvaged"):
			_masks_weep_oil()


func _spawn_glenn() -> void:
	if glenn_npc != null:
		return
	glenn_npc = add_npc(&"glenn_marshall", "glenn_marshall", get_marker("glenn"), "w", 60.0, &"", "Glenn")
	var it: Interactable = glenn_npc.get_node_or_null("Talk")
	if it:
		it.callback = func(_by: Node) -> void:
			if Flags.has(&"Glenn_Honour_Checked"):
				Story.run(&"ch1_glenn_after")
			else:
				Story.run(&"ch1_glenn_honour")


func _masks_weep_oil() -> void:
	if eye_right:
		var m := SceneKit.flat_color(Color(0.05, 0.05, 0.06), Color(0.1, 0.1, 0.12), 0.3, 0.2)
		eye_right.material_override = m
	Audio.set_rtpc("hydraulic_hiss", 1.0)


func _talk_robo(_by: Node) -> void:
	Story.run(&"atrium_robo")


## Rest at the hub: full heal for everyone, the smear reset (never the Debt), and the clock runs to night.
func heal_party() -> void:
	for a in party_actors:
		a.stats.hp = a.stats.max_hp()
		a.stats.mp = a.stats.max_mp
		a.set_porcelain_visuals()
	for id in Game.roster.keys():
		Game.roster[id]["hp_ratio"] = 1.0
	Audio.play_sfx("ui/heal_chime")
	if Game.checkpoint == CP_FREE and Flags.has(&"Atrium_Dummy"):
		Game.checkpoint = CP_NIGHT
		tower_time = 23.6
		await Router.fade_out(0.8)
		await get_tree().create_timer(0.4).timeout
		await Router.fade_in(0.8)


func _midnight() -> void:
	Audio.play_sfx("time/tape_stop")
	if eye_right:
		eye_right.visible = false
	if eye_left:
		eye_left.visible = false
	Audio.set_rtpc("vaelos_near", 0.35)
	await Story.run(&"ch1_midnight")
	await get_tree().create_timer(1.0).timeout
	if eye_right:
		eye_right.visible = true
	if eye_left:
		eye_left.visible = true
	# the family sits at the hearth; Crono's hidden prompt lives there now
	var marle: Node = get_actor(&"marle")
	if marle is CombatActor:
		(marle as CombatActor).global_position = get_marker("hearth_marle")
		(marle as CombatActor).face("w")


func _use_hearth(_by: Node) -> void:
	if Game.checkpoint == CP_NIGHT and midnight_done and not Flags.has(&"Crono_Confession"):
		await Story.run(&"ch1_hearth")
		Game.checkpoint = CP_FAIR
		Saves.save(0)
		await get_tree().create_timer(0.5).timeout
		await Story.run(&"ch1_fair_call")
	elif Game.checkpoint == CP_NIGHT:
		Story.run(&"atrium_hearth_night")
	else:
		Story.run(&"atrium_hearth")


## Scripted: the family leaves for Leene Square; Crono alone, chasing.
func leave_for_fair() -> void:
	Flags.set_flag(&"Ch1_Fair_Left", &"set")
	Game.set_party([&"crono"])
	Router.go(&"leene_square", &"start", 1.0)


# ------------------------------------------------------------------ builders

func _ring_wall(radius: float, height: float, mat: Material, segments: int) -> void:
	for i in segments:
		var a: float = float(i) / float(segments) * TAU
		var seg_len: float = TAU * radius / float(segments) + 0.2
		# the camera-facing third of the ring is cut down to a ledge (diorama convention)
		var facing: bool = sin(a) > 0.45
		var h: float = 1.0 if facing else height
		var b := SceneKit.box(self, Vector3(seg_len, h, 0.8), Vector3(cos(a) * radius, h * 0.5, sin(a) * radius), mat, "Wall%d" % i)
		b.rotation.y = -a + PI * 0.5


func _build_gate(u: int, pos: Vector3, angle: float, frame_mat: Material) -> void:
	var holder := Node3D.new()
	holder.name = "Gate%d" % u
	holder.position = pos
	holder.rotation.y = -angle + PI * 0.5
	add_child(holder)
	SceneKit.box(holder, Vector3(0.4, 3.4, 0.4), Vector3(-1.2, 1.7, 0), frame_mat, "JambA", false)
	SceneKit.box(holder, Vector3(0.4, 3.4, 0.4), Vector3(1.2, 1.7, 0), frame_mat, "JambB", false)
	SceneKit.box(holder, Vector3(2.8, 0.4, 0.4), Vector3(0, 3.6, 0), frame_mat, "Lintel", false)
	var unlocked: bool = Flags.has(StringName("Gate_U%d_Open" % u))
	var col: Color = GATE_COLOURS.get(u, Color.WHITE)
	var fill := SceneKit.flat_color(col * (0.9 if unlocked else 0.12), col, 2.0 if unlocked else 0.15, 0.3)
	var panel := SceneKit.box(holder, Vector3(2.0, 3.2, 0.15), Vector3(0, 1.7, 0.1), fill, "Panel", false)
	gates[u] = panel
	var it := Interactable.make(holder, "GateUse", Vector3(0, 0.8, 1.0), &"", "Gate: " + Universe.name_of(u), 1.1)
	it.callback = func(_by: Node) -> void: _use_gate(u)
	if unlocked:
		SceneKit.omni(holder, Vector3(0, 2.0, 1.0), col, 1.5, 6.0, false)


func _use_gate(u: int) -> void:
	if Flags.has(StringName("Gate_U%d_Open" % u)):
		var loc: StringName = GATE_LOCATIONS.get(u, &"")
		if Router.has_location(loc):
			Audio.play_sfx("time/gate_open_u%d" % u)
			Router.go(loc, &"start")
		else:
			Story.run(&"atrium_gate_unbuilt")
	else:
		Story.run(&"atrium_gate_locked")


func _build_window_ink() -> void:
	window_ink = GPUParticles3D.new()
	window_ink.amount = 50
	window_ink.lifetime = 2.2
	window_ink.emitting = false
	window_ink.position = get_marker("window_ink") + Vector3(0, 1.4, 0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.6
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 30.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0, -0.8, 0)
	pm.scale_min = 0.05
	pm.scale_max = 0.14
	pm.color = Color(0.12, 0.1, 0.3, 0.9)
	window_ink.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.12, 0.1, 0.3, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.material = mat
	window_ink.draw_pass_1 = qm
	add_child(window_ink)


func _trigger(pos: Vector3, size: Vector3) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	a.monitoring = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	a.add_child(cs)
	a.position = pos
	add_child(a)
	return a
