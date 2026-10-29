## The Atrium Horologe (Story Bible U0, §9.7; Reference Bible §3.2, plate-00): Porre's gutted clocktower
## in Truce, grown through by Robo. A vertical brass cylinder: moss-garden floor, workbench ring, gate ring,
## and at its centre Robo's torso as the clock pillar. The hub: save, heal, swap, inspect, plant, train,
## choose a gate.
extends Location

const GATE_UNIVERSES := [1, 2, 3, 4, 5, 6, 7, 8]
const GATE_COLOURS := {
	1: Color(0.75, 0.33, 0.26), 2: Color(0.77, 0.54, 0.25), 3: Color(0.43, 0.62, 0.64), 4: Color(0.17, 0.3, 0.61),
	5: Color(0.78, 0.23, 0.2), 6: Color(0.0, 0.94, 1.0), 7: Color(0.83, 0.69, 0.22), 8: Color(0.55, 0.49, 1.0),
}
const GATE_LOCATIONS := {1: &"bamboo_grove", 2: &"proto_dome", 3: &"eden_canopy", 4: &"cathedral_nave", 5: &"carnival_midway", 6: &"neo_truce", 7: &"bone_tree_root", 8: &"vaelos_heart"}

var pillar_face: MeshInstance3D
var hour_hand: MeshInstance3D
var minute_hand: MeshInstance3D
var vines: Array[MeshInstance3D] = []
var pool_water: MeshInstance3D
var gates: Dictionary = {}
var tower_time: float = 7.0  # hours; one real minute is one hour
var _vine_t: float = 0.0


func build() -> void:
	location_id = &"atrium"
	universe_id = 0
	field_music = &"mus_u0_wind_scene_1024"
	ambience = &"amb_u0_atrium_tower"
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
	# ---- the round hall: floor rings (stone inner, moss garden outer), a low perimeter wall and pillars
	SceneKit.cylinder(self, 13.5, 0.2, Vector3(0, -0.1, 0), mossy, "GardenFloor")
	SceneKit.cylinder(self, 8.0, 0.24, Vector3(0, -0.1, 0), stone, "StoneFloor", false)
	_ring_wall(13.6, 7.0, wall, 28)
	for i in 12:
		var a: float = float(i) / 12.0 * TAU
		SceneKit.cylinder(self, 0.45, 8.0, Vector3(cos(a) * 12.6, 4.0, sin(a) * 12.6), wall, "Column%d" % i)
		# a balcony segment between columns at 4.5 m
		SceneKit.box(self, Vector3(5.5, 0.25, 1.6), Vector3(cos(a + TAU / 24.0) * 12.4, 4.5, sin(a + TAU / 24.0) * 12.4), wood, "Balcony%d" % i, false).rotation.y = -(a + TAU / 24.0) + PI * 0.5
	# organ pipes on the east wall
	for i in 7:
		SceneKit.cylinder(self, 0.18 + 0.03 * float(i % 3), 3.0 + 0.6 * float(i), Vector3(11.4, 2.0 + 0.3 * float(i), -3.0 + float(i) * 0.9), brass, "Pipe%d" % i, false)
	# ---- the dais and the pillar (Robo's torso), the clock face, the hands, the copper vines
	SceneKit.cylinder(self, 3.2, 0.5, Vector3(0, 0.25, 0), stone, "Dais")
	SceneKit.cylinder(self, 2.4, 0.4, Vector3(0, 0.7, 0), dark_brass, "DaisStep")
	SceneKit.cylinder(self, 1.3, 7.0, Vector3(0, 4.4, 0), dark_brass, "Pillar")
	# ribcage arches
	for i in 6:
		var a2: float = float(i) / 6.0 * TAU
		var rib := SceneKit.box(self, Vector3(0.18, 3.2, 0.18), Vector3(cos(a2) * 1.75, 3.2, sin(a2) * 1.75), brass, "Rib%d" % i, false)
		rib.rotation.z = 0.18 * cos(a2)
		rib.rotation.x = -0.18 * sin(a2)
	for i in 10:
		var a3: float = float(i) / 10.0 * TAU + 0.3
		var v := SceneKit.cylinder(self, 0.06, 5.5 + float(i % 3) * 0.6, Vector3(cos(a3) * 1.55, 3.6, sin(a3) * 1.55), copper, "Vine%d" % i, false)
		v.rotation.z = 0.12 * sin(a3 * 2.0)
		vines.append(v)
	# the 10 ft porcelain clock face
	pillar_face = SceneKit.cylinder(self, 1.6, 0.25, Vector3(0, 7.6, 0), porcelain, "ClockFace", false)
	pillar_face.rotation.x = PI * 0.5
	pillar_face.position = Vector3(0, 7.8, 1.3)
	var ink := SceneKit.flat_color(Color(0.1, 0.1, 0.12), Color.BLACK, 0.0, 0.4)
	hour_hand = SceneKit.box(self, Vector3(0.12, 0.9, 0.06), Vector3(0.0, 8.2, 1.46), ink, "HourHand", false)
	minute_hand = SceneKit.box(self, Vector3(0.08, 1.3, 0.06), Vector3(0.0, 8.4, 1.48), ink, "MinuteHand", false)
	# the eyes: right sorrowful blue (hour hand), left empty weeping ink (minute hand)
	var blue := SceneKit.flat_color(Color(0.2, 0.5, 1.0), Color(0.3, 0.6, 1.0), 2.5, 0.2)
	var black := SceneKit.flat_color(Color(0.02, 0.02, 0.03), Color.BLACK, 0.0, 0.2)
	SceneKit.cylinder(self, 0.22, 0.1, Vector3(-0.55, 8.1, 1.44), blue, "EyeRight", false).rotation.x = PI * 0.5
	SceneKit.cylinder(self, 0.22, 0.1, Vector3(0.55, 8.1, 1.44), black, "EyeLeft", false).rotation.x = PI * 0.5
	SceneKit.omni(self, Vector3(0, 7.5, 3.0), Color(0.35, 0.55, 1.0), 2.0, 9.0, false)
	# ---- the pool (a reused U4 well) south-west of the dais, the garden and the Seed's pot
	SceneKit.cylinder(self, 1.9, 0.6, Vector3(-4.5, 0.3, 4.0), stone, "PoolRim")
	var water := SceneKit.flat_color(Color(0.25, 0.45, 0.6, 0.85), Color(0.2, 0.4, 0.6), 0.6, 0.05)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool_water = SceneKit.cylinder(self, 1.6, 0.1, Vector3(-4.5, 0.58, 4.0), water, "PoolWater", false)
	var terracotta := SceneKit.flat_color(Color(0.6, 0.38, 0.25), Color.BLACK, 0.0, 0.9)
	SceneKit.cylinder(self, 0.5, 0.7, Vector3(5.5, 0.35, 5.5), terracotta, "SeedPot")
	var mercury := SceneKit.flat_color(Color(0.8, 0.82, 0.85), Color(0.6, 0.65, 0.7), 0.5, 0.1, 1.0)
	SceneKit.cylinder(self, 0.18, 0.18, Vector3(5.5, 0.8, 5.5), mercury, "SeedOrb", false)
	# ---- the workbench ring (north), the gramophone at six o'clock, Lucca's dummy at north-west
	SceneKit.box(self, Vector3(4.0, 0.9, 1.0), Vector3(0.0, 0.45, -9.5), wood, "Workbench")
	SceneKit.box(self, Vector3(1.6, 0.9, 1.0), Vector3(5.0, 0.45, -9.0), wood, "Workbench2")
	SceneKit.cylinder(self, 0.4, 0.9, Vector3(0.0, 0.45, 9.8), wood, "GramophoneTable")
	var horn := SceneKit.cylinder(self, 0.5, 0.8, Vector3(0.0, 1.45, 9.8), brass, "GramophoneHorn", false)
	horn.rotation.x = -0.9
	SceneKit.box(self, Vector3(1.0, 0.2, 1.0), Vector3(-8.0, 0.1, -8.0), stone, "DummyPlinth")
	# ---- the loft: a wall of Crono's old Truce house set into the tower, reached by a brass stair (north-east)
	SceneKit.box(self, Vector3(6.0, 0.3, 5.0), Vector3(8.0, 4.4, -7.0), wood, "LoftFloor")
	var plaster := SceneKit.flat_color(Color(0.86, 0.8, 0.68), Color.BLACK, 0.0, 1.0)
	SceneKit.box(self, Vector3(6.0, 3.0, 0.3), Vector3(8.0, 6.0, -9.4), plaster, "LoftWall", false)
	SceneKit.box(self, Vector3(1.6, 0.5, 2.2), Vector3(9.8, 4.8, -7.5), SceneKit.flat_color(Color(0.5, 0.3, 0.3)), "SeraBed", false)
	SceneKit.box(self, Vector3(1.0, 1.2, 0.6), Vector3(6.0, 5.1, -8.5), wood, "CronoChair", false)
	for i in 9:
		SceneKit.box(self, Vector3(1.4, 0.2, 0.6), Vector3(5.0, 0.5 + float(i) * 0.5, -3.0 - float(i) * 0.5), brass, "Stair%d" % i)
	# ---- the gate ring: eight arches around the perimeter, each lit in its universe's colour
	for u in GATE_UNIVERSES:
		var a4: float = (float(GATE_UNIVERSES.find(u)) + 0.5) / 8.0 * TAU + PI * 0.5
		var gp := Vector3(cos(a4) * 11.2, 0.0, sin(a4) * 11.2)
		_build_gate(u, gp, a4, dark_brass)
	# ---- light shafts from the dome
	var env_light := SpotLight3D.new()
	env_light.position = Vector3(-3.0, 14.0, -2.0)
	env_light.rotation_degrees = Vector3(-80, 0, 0)
	env_light.light_color = Color(1.0, 0.9, 0.7)
	env_light.light_energy = 8.0
	env_light.spot_range = 20.0
	env_light.spot_angle = 28.0
	env_light.shadow_enabled = true
	add_child(env_light)
	# ---- markers
	add_marker("start", Vector3(0, 0, 7.0))
	add_marker("arrival", Vector3(0, 0, 10.5))
	add_marker("dais", Vector3(0, 0, 4.2))
	add_marker("pool", Vector3(-4.5, 0, 6.3))
	add_marker("dummy", Vector3(-8.0, 0, -6.5))
	add_marker("seed", Vector3(5.5, 0, 4.2))
	add_marker("loft", Vector3(8.0, 4.55, -6.0))
	add_marker("loft_bed", Vector3(9.8, 4.55, -6.2))
	add_marker("loft_chair", Vector3(6.2, 4.55, -7.6))
	add_marker("workbench", Vector3(0.0, 0.0, -8.3))
	add_marker("hearth", Vector3(-7.0, 0.0, 3.0))
	# ---- interactables
	var robo := Interactable.make(self, "Robo", Vector3(0, 1.0, 3.4), &"atrium_robo", "Robo", 1.3)
	robo.callback = Callable(self, "_talk_robo")
	Interactable.make(self, "Pool", Vector3(-4.5, 0.8, 6.0), &"atrium_pool", "The pool", 1.0)
	Interactable.make(self, "SeedPot", Vector3(5.5, 0.8, 4.6), &"atrium_seed", "The Seed of Doan", 1.0)
	Interactable.make(self, "Gramophone", Vector3(0.0, 0.8, 9.2), &"atrium_gramophone", "Gramophone", 1.0)
	Interactable.make(self, "Workbench", Vector3(0.0, 0.8, -8.7), &"atrium_workbench", "Workbench", 1.1)
	var dummy := Interactable.make(self, "Dummy", Vector3(-8.0, 0.8, -7.2), &"atrium_dummy", "The 999 Shield Dummy", 1.2)
	dummy.callback = Callable(self, "_use_dummy")
	# the dummy's body: a placeholder figure until its sheet is drawn
	var dummy_actor := add_npc(&"shard_doll_999", "shard_doll_999", Vector3(-8.0, 0.2, -8.0), "s")
	dummy_actor.frozen = true
	# ---- cast in the hub
	if Game.chapter >= 1:
		add_cast(&"marle", get_marker("hearth"), "e", &"atrium_marle", "Marle")


func after_ready() -> void:
	if Game.chapter == 1 and Game.checkpoint == &"atrium_arrival" and not Flags.has(&"Ch1_Arrived"):
		controller.enabled = false
		await get_tree().create_timer(0.5).timeout
		controller.enabled = true
		await Story.run(&"ch1_arrival")


func _process(delta: float) -> void:
	super._process(delta)
	# one real minute is one hour in the tower; the hands turn and the vines pulse at 72 BPM
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


func _ring_wall(radius: float, height: float, mat: Material, segments: int) -> void:
	for i in segments:
		var a: float = float(i) / float(segments) * TAU
		var seg_len: float = TAU * radius / float(segments) + 0.2
		var b := SceneKit.box(self, Vector3(seg_len, height, 0.8), Vector3(cos(a) * radius, height * 0.5, sin(a) * radius), mat, "Wall%d" % i)
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


func _talk_robo(_by: Node) -> void:
	Story.run(&"atrium_robo")


func _use_dummy(_by: Node) -> void:
	Story.run(&"atrium_dummy")


## Rest at the hub: full heal for everyone, Sera's battle debt cleared, the smear reset (never the Debt).
func heal_party() -> void:
	for a in party_actors:
		a.stats.hp = a.stats.max_hp()
		a.stats.mp = a.stats.max_mp
		a.set_porcelain_visuals()
	for id in Game.roster.keys():
		Game.roster[id]["hp_ratio"] = 1.0
	Audio.play_sfx("ui/heal_chime")
