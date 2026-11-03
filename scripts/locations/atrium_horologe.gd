## The Atrium Horologe (Story Bible U0, §9.7; Reference Bible §3.2, plate-00): Porre's gutted clocktower
## in Truce, grown through by Robo. A vertical brass cylinder: moss-garden floor, workbench ring, gate ring,
## and at its centre Robo's torso as the clock pillar. The hub: save, heal, swap, inspect, plant, train,
## choose a gate. Chapter 1 plays out here (beats 1–9) before the Fair. The hall is primitives; the hearth,
## Seed pot, gramophone workbench, plinth, alcove, ladder, doll and the eight gate arches are PixelLab props.
extends Location

const LOFT_Y := 3.2
const FAIR := &"leene_square"
## The memory echoes that leak near the lab once the dummy's shields were stressed (Story Bible Ch1 "Enemies"):
## [encounter, centre, radius]. Each stands clear of dummy_center, where the dummy fight leaves the party.
const LAB_ZONES := [
	[&"atrium_lab_mice", Vector3(-9.0, 0, -3.0), 2.0], [&"atrium_lab_fragment", Vector3(-3.5, 0, -9.5), 1.8],
	[&"atrium_lab_krona_echo", Vector3(-10.5, 0, -0.5), 1.6], [&"atrium_lab_drone", Vector3(3.0, 0, -7.0), 1.8],
]

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
	var stone := SceneKit.named("castle_flagstone", 0.95, Color(0.9, 0.86, 0.78))
	var mossy := SceneKit.named("stone_mossy", 0.95, Color(0.95, 0.95, 0.9))
	var wall := SceneKit.named("castle_wall_block", 0.9, Color(0.85, 0.78, 0.65))
	var wood := SceneKit.named("oak_plank", 0.85)
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
		# the camera-facing third of the ring keeps only its ledge (diorama convention, as _ring_wall):
		# full columns and balconies there stood between the follow camera and the hearth, the pool and the gates
		if sin(a) <= 0.45:
			SceneKit.cylinder(self, 0.45, 8.0, Vector3(cos(a) * 12.6, 4.0, sin(a) * 12.6), wall, "Column%d" % i)
		var ba: float = a + TAU / 24.0
		if sin(ba) <= 0.45:
			var bal := SceneKit.box(self, Vector3(5.5, 0.25, 1.6), Vector3(cos(ba) * 12.4, 4.5, sin(ba) * 12.4), wood, "Balcony%d" % i, false)
			bal.rotation.y = -ba + PI * 0.5
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
	# the Seed of Doan in its garden pot (Nich's prop; the sprout grows above it after the first watering)
	add_prop(&"prp_u0_seed_of_doan_pot", Vector3(5.5, 0.0, 5.5))
	# ---- the workbench ring (north) with the little Bekkler doll on it, the gramophone workbench at six
	# o'clock, Lucca's dummy lab at north-west on its plinth, Robo's rest alcove set into the north wall
	SceneKit.box(self, Vector3(4.0, 0.9, 1.0), Vector3(0.0, 0.45, -9.5), wood, "Workbench")
	SceneKit.box(self, Vector3(1.6, 0.9, 1.0), Vector3(5.0, 0.45, -9.0), wood, "Workbench2")
	add_prop(&"prp_u0_bekkler_doll", Vector3(-1.2, 0.0, -9.4))
	add_prop(&"prp_u0_gramophone_workbench", Vector3(0.0, 0.0, 9.8))
	add_prop(&"prp_u0_dummy_plinth", Vector3(-8.0, 0.0, -8.15))
	add_prop(&"prp_u0_robo_rest_alcove", Vector3(0.0, 0.0, -12.0))
	# the hearth (west), its embers flickering, where the family sits at night. It stands a step in from the
	# gate ring (x -7.9) so gate U2's arch and the west balcony do not hide it from the follow camera.
	add_prop(&"prp_u0_hearth", Vector3(-7.9, 0.0, 0.5))
	SceneKit.omni(self, Vector3(-6.9, 1.0, 0.5), Color(1.0, 0.62, 0.3), 1.8, 6.0, false)
	for bz in [-0.8, 1.8]:
		SceneKit.box(self, Vector3(1.2, 0.45, 0.5), Vector3(-6.0, 0.225, bz), wood, "HearthBench")
	# ---- the loft: a wall of Crono's old Truce house set into the tower, reached by a brass ramp-stair
	SceneKit.box(self, Vector3(6.0, 0.3, 5.0), Vector3(8.0, LOFT_Y - 0.15, -7.0), wood, "LoftFloor")
	var plaster := SceneKit.flat_color(Color(0.86, 0.8, 0.68), Color.BLACK, 0.0, 1.0)
	SceneKit.box(self, Vector3(6.0, 3.0, 0.3), Vector3(8.0, LOFT_Y + 1.5, -9.4), plaster, "LoftWall", false)
	var win_m := SceneKit.flat_color(Color(0.55, 0.65, 0.85), Color(0.6, 0.7, 0.9), 0.8, 0.2)
	SceneKit.box(self, Vector3(1.2, 1.4, 0.1), Vector3(6.8, LOFT_Y + 1.7, -9.2), win_m, "LoftWindow", false)
	SceneKit.box(self, Vector3(1.6, 0.5, 2.2), Vector3(9.8, LOFT_Y + 0.25, -7.5), SceneKit.flat_color(Color(0.5, 0.3, 0.3)), "SeraBed", false)
	SceneKit.box(self, Vector3(1.0, 1.2, 0.6), Vector3(6.0, LOFT_Y + 0.6, -8.5), wood, "CronoChair", false)
	add_prop(&"prp_u0_loft_ladder", Vector3(8.2, LOFT_Y, -9.0))
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
	gates = AtriumGateRing.build(self)  # the ring of eight universe gates
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
	add_marker("hearth", Vector3(-5.4, 0.0, 0.5))
	add_marker("hearth_crono", Vector3(-6.0, 0.0, -0.1))
	add_marker("hearth_marle", Vector3(-6.0, 0.0, 1.3))
	add_marker("glenn", Vector3(-6.2, 0.0, -7.6))
	add_marker("right_gate", Vector3(10.5, 0.0, 3.5))
	# ---- interactables
	var robo := Interactable.make(self, "Robo", Vector3(0, 1.0, 3.4), &"", "Robo", 1.3)
	robo.callback = func(_by: Node) -> void: Story.run(&"atrium_robo")
	Interactable.make(self, "Pool", Vector3(-4.5, 0.8, 6.0), &"atrium_pool", "The pool", 1.0)
	var seed := Interactable.make(self, "SeedPot", Vector3(5.5, 0.8, 4.6), &"", "The Seed of Doan", 1.0)
	seed.callback = Callable(self, "_use_seed")
	Interactable.make(self, "Gramophone", Vector3(0.0, 0.8, 9.2), &"atrium_gramophone", "Gramophone", 1.0)
	Interactable.make(self, "Workbench", Vector3(0.0, 0.8, -8.7), &"atrium_workbench", "Workbench", 1.1)
	var dummy := Interactable.make(self, "Dummy", Vector3(-7.4, 0.8, -6.6), &"", "The 999 Shield Dummy", 1.3)
	dummy.callback = Callable(self, "_use_dummy")
	hearth_interact = Interactable.make(self, "HearthSeat", Vector3(-5.4, 0.8, 0.5), &"", "The hearth", 1.1)
	hearth_interact.callback = Callable(self, "_use_hearth")
	var dummy_actor := add_npc(&"shard_doll_999", "shard_doll_999", Vector3(-8.0, 0.3, -8.0), "s")
	dummy_actor.frozen = true
	# the ink that gathers at the east window (Father Tank)
	_build_window_ink()
	downstairs_trigger = SceneKit.trigger(self, Vector3(5.2, 0.8, 2.6), Vector3(3.0, 2.0, 2.0), "DownstairsTrigger")
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

## Who stands where for a checkpoint. Sera alone walks the loft beats: a party that disagrees (a debug boot, an odd
## save) is rebuilt, never left beside the cast, so there is one Crono. Marle stands at the hearth unless she
## walked in with the party (the arrival from the courtyard).
func _place_cast(cp: StringName) -> void:
	if cp == CP_LOFT or cp == CP_REWIND or cp == CP_DOWNSTAIRS:
		if Game.active_party != [&"sera"]:
			rebuild_party([&"sera"])
		var down: bool = cp == CP_DOWNSTAIRS
		var crono := add_cast(&"crono", get_marker("ramp_bottom") + Vector3(1.5, 0, 0.5) if down else get_marker("loft_chair"), "e")
		if not down:
			crono.sprite.play(&"hurt")  # asleep sitting up; the hurt frame reads as slumped
			crono.sprite.set_tint(Color(0.85, 0.85, 0.9))
	if (cp == CP_FREE or cp == CP_NIGHT or cp == CP_FAIR or cp == CP_ARRIVAL or cp == CP_HUB) and get_actor(&"marle") == null:
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
	autosave_at(&"loft_bed")
	if not rewind_stage:
		await Story.run(&"ch1_loft_wake")
		_focus_hold = 0.0
	else:
		await Story.run(&"ch1_rewind_prompt")


func _free_roam_setup() -> void:
	if Game.active_party.size() < 2:
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
		# a dry press rewinds nothing and costs nothing: the Debt prices a Rewind in combat or a gate jump (Story
		# Bible §3.4; DECISIONS "A field Rewind with nothing to rewind is free")
		prompt_label.text = "Nothing here to rewind."
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
	autosave_at(&"ramp_bottom")  # the hub opens where Father Tank stood, never back up in the loft
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
	if not Flags.has(&"Atrium_Dummy") or zones.any(func(z: EncounterZone) -> bool: return z.encounter_id == LAB_ZONES[0][0]):
		return
	for row in LAB_ZONES:
		var z := add_zone(row[0], row[1], row[2])
		z.spawn(self)
		z.triggered.connect(_on_zone_triggered)


func _krona_marks() -> void:
	if ink_path != null or SeedOfDoan.waters() > 0:
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
	if SeedOfDoan.waters() == 0 and SeedOfDoan.can_water() and Game.checkpoint != CP_LOFT:
		await Story.run(&"atrium_seed_first_water")
		if SeedOfDoan.waters() > 0:
			autosave_at(&"seed")  # the watering is kept without ending the day (GAP2-6)
	else:
		Story.run(&"atrium_seed")


## Scripted: the first watering (SeedOfDoan: the count, the Light it pays, the Grown state on the third). A
## sprout with a tiny gramophone horn rises from the rim of the Seed's pot, playing a tune backwards.
func water_seed() -> void:
	SeedOfDoan.water()
	var pot: PropBillboard = get_prop(&"prp_u0_seed_of_doan_pot")
	SeedOfDoan.grow_sprout(self, pot.global_position + Vector3(0.0, pot.footprint.y, 0.0) if pot != null else Vector3(5.5, 1.1, 5.5))
	if ink_path:
		ink_path.active = false
	Audio.play_sfx("time/rewind")


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
	_after_dummy()


## The dummy is spared or salvaged: the lab's echoes leak, Glenn comes to read the record, and the result is
## autosaved where the fight left the party, without moving the story on (GAP2-6: the rest that saves ends the day).
func _after_dummy() -> void:
	if not Flags.has(&"Atrium_Dummy"):
		return
	_activate_lab_zones()
	_spawn_glenn()
	if Flags.is_state(&"Atrium_Dummy", &"Salvaged"):
		_masks_weep_oil()
	autosave_at(&"dummy_center")


func _spawn_glenn() -> void:
	if glenn_npc != null:
		return
	# his Talk is his own, never borrowed from the Atrium's ambient lines (STORY-12)
	glenn_npc = add_npc(&"glenn_marshall", "glenn_marshall", get_marker("glenn"), "w", 60.0, &"", "Glenn", 0.0, _talk_glenn)


## Glenn's honour check once (autosaved: his verdict is kept without a rest), then his after-lines.
func _talk_glenn(_by: Node) -> void:
	if Flags.has(&"Glenn_Honour_Checked"):
		Story.run(&"ch1_glenn_after")
		return
	await Story.run(&"ch1_glenn_honour")
	autosave_at(&"dummy_center")


func _masks_weep_oil() -> void:
	if eye_right:
		var m := SceneKit.flat_color(Color(0.05, 0.05, 0.06), Color(0.1, 0.1, 0.12), 0.3, 0.2)
		eye_right.material_override = m
	Audio.set_rtpc("hydraulic_hiss", 1.0)


## Rest at the hub: full heal for everyone, the smear reset (never the Debt), and the clock runs to night.
func heal_party() -> void:
	for a in party_actors:
		a.stats.hp = a.stats.max_hp()
		a.stats.mp = a.stats.max_mp
		a.set_porcelain_visuals()
	for id in Game.roster.keys():
		Game.roster[id]["hp_ratio"] = 1.0
	Audio.play_sfx("ui/save")
	if Game.checkpoint == CP_FREE or Game.checkpoint == CP_NIGHT or Game.checkpoint == CP_FAIR:
		Game.spawn_point = &"dais"  # the rest's save (atrium_robo) resumes in front of Robo
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
		autosave_at(&"hearth", CP_FAIR)
		await get_tree().create_timer(0.5).timeout
		await Story.run(&"ch1_fair_call")
	elif Game.checkpoint == CP_NIGHT:
		Story.run(&"atrium_hearth_night")
	else:
		Story.run(&"atrium_hearth")


## Scripted: the family leaves for Leene Square; Crono alone, chasing. Nothing is committed unless the Router will
## take him there (its own refusals, checked first): while the square is unbuilt the hub stays as it was, the Fair
## call says so (ch1_fair_call reads Ch1_Fair_Left) and plays again from the CP_FAIR autosave.
func leave_for_fair() -> void:
	if not Router.has_location(FAIR) or Router.transitioning:
		return
	Flags.set_flag(&"Ch1_Fair_Left", &"set")
	Game.set_party([&"crono"])
	Router.go(FAIR, &"start", 1.0)


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
