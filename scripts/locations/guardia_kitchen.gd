## The Guardia Atrium family kitchen and the hall beyond it (Story Bible §6 Prologue beats 2–8).
## West room: hearth, counter, pot, table, Sera's stool, speaking tube, dusty stained glass. The
## Fracture Gate seals the doorway to the east hall, where the Atrium Cradle unfolds from the pantry.
extends Location

const CP_START := &"prologue_kitchen"
const CP_BREAKFAST := &"prologue_breakfast_done"
const CP_GATE := &"prologue_gate_open"
const CP_CRADLE := &"prologue_cradle_done"

var gate_mesh: Node3D
var gate_body: StaticBody3D
var gate_interact: Interactable
var exit_door: Interactable
var bowl: MeshInstance3D
var bowl_ash: MeshInstance3D
var motes: GPUParticles3D
var cradle_trigger: Area3D
var _cradle_started: bool = false


func build() -> void:
	location_id = &"guardia_kitchen"
	universe_id = 0
	field_music = &"mus_u0_guardia_morning"
	ambience = &"amb_u0_castle_interior"
	camera_distance = 13.0
	camera_pitch = 32.0
	map_bounds = Rect2(-9.5, -7.5, 23.5, 12.5)
	var stone := SceneKit.material("res://assets/textures/stone_albedo.png", "res://assets/textures/stone_normal.png", 0.95, Color(0.92, 0.9, 0.88), true)
	var wall := SceneKit.material("res://assets/textures/castle_wall_albedo.png", "res://assets/textures/castle_wall_normal.png", 0.9, Color(0.95, 0.95, 0.95), true)
	var wood := SceneKit.material("res://assets/textures/wood_albedo.png", "res://assets/textures/wood_normal.png", 0.85, Color.WHITE, true)
	var dark_wood := SceneKit.material("res://assets/textures/wood_albedo.png", "res://assets/textures/wood_normal.png", 0.85, Color(0.6, 0.55, 0.5), true)
	# ---- floors
	SceneKit.floor_plane(self, Vector2(10.0, 11.0), Vector3(-4.0, 0.0, -1.0), stone, "KitchenFloor")
	SceneKit.floor_plane(self, Vector2(12.5, 12.0), Vector3(7.25, 0.0, -1.0), stone, "HallFloor")
	# a woven rug under the table
	var rug := SceneKit.flat_color(Color(0.45, 0.3, 0.28), Color.BLACK, 0.0, 1.0)
	SceneKit.box(self, Vector3(4.2, 0.03, 2.6), Vector3(-2.5, 0.015, 0.4), rug, "Rug", false)
	# ---- walls (kitchen)
	SceneKit.box(self, Vector3(10.6, 4.5, 0.6), Vector3(-4.0, 2.25, -6.8), wall, "KitchenBackWall")
	SceneKit.box(self, Vector3(0.6, 4.5, 11.6), Vector3(-9.3, 2.25, -1.0), wall, "KitchenWestWall")
	# camera-facing walls are cut away to a low ledge (the diorama convention); collision stays full height
	SceneKit.box(self, Vector3(3.6, 0.9, 0.6), Vector3(-7.2, 0.45, 4.8), wall, "KitchenSouthWallA")
	SceneKit.box(self, Vector3(3.6, 0.9, 0.6), Vector3(-0.8, 0.45, 4.8), wall, "KitchenSouthWallB")
	var door_dark := SceneKit.flat_color(Color(0.05, 0.05, 0.06), Color.BLACK, 0.0, 1.0)
	SceneKit.box(self, Vector3(1.8, 0.2, 0.3), Vector3(-4.0, 0.1, 4.9), door_dark, "SouthDoorway", false)
	# partition wall between kitchen and hall, with the gate opening at z in [-1.1, 1.1]
	SceneKit.box(self, Vector3(0.6, 4.5, 5.4), Vector3(1.0, 2.25, -4.1), wall, "PartitionN")
	SceneKit.box(self, Vector3(0.6, 4.5, 3.6), Vector3(1.0, 2.25, 3.0), wall, "PartitionS")
	SceneKit.box(self, Vector3(0.6, 1.4, 2.4), Vector3(1.0, 3.8, 0.0), wall, "PartitionLintel")
	# ---- walls (hall)
	SceneKit.box(self, Vector3(12.5, 4.5, 0.6), Vector3(7.25, 2.25, -7.3), wall, "HallBackWall")
	SceneKit.box(self, Vector3(0.6, 4.5, 12.6), Vector3(13.6, 2.25, -1.0), wall, "HallEastWall")
	SceneKit.box(self, Vector3(12.5, 0.9, 0.6), Vector3(7.25, 0.45, 5.3), wall, "HallSouthWall")
	# exit door on the east wall (to the courtyard)
	SceneKit.box(self, Vector3(0.3, 3.2, 2.0), Vector3(13.35, 1.6, 0.0), door_dark, "ExitDoorway", false)
	var brass := SceneKit.flat_color(Color(0.78, 0.6, 0.3), Color.BLACK, 0.0, 0.3, 0.9)
	SceneKit.box(self, Vector3(0.2, 3.4, 0.2), Vector3(13.3, 1.7, -1.1), brass, "ExitJambA", false)
	SceneKit.box(self, Vector3(0.2, 3.4, 0.2), Vector3(13.3, 1.7, 1.1), brass, "ExitJambB", false)
	# ---- stained glass (two tall windows on the kitchen back wall, one in the hall)
	var glass := _stained_glass_material()
	for wx in [-6.5, -2.5]:
		_window(glass, Vector3(wx, 2.4, -6.48), Vector2(1.8, 3.0))
	_window(glass, Vector3(9.0, 2.6, -6.98), Vector2(2.6, 3.2))
	# ---- hearth on the west wall with embers
	var hearth := SceneKit.flat_color(Color(0.22, 0.2, 0.19), Color.BLACK, 0.0, 0.9)
	SceneKit.box(self, Vector3(1.0, 2.4, 2.6), Vector3(-8.5, 1.2, -3.0), hearth, "Hearth")
	SceneKit.box(self, Vector3(1.1, 0.25, 2.8), Vector3(-8.45, 2.5, -3.0), hearth, "HearthMantle", false)
	var ember := SceneKit.flat_color(Color(1.0, 0.45, 0.1), Color(1.0, 0.5, 0.12), 4.0)
	SceneKit.box(self, Vector3(0.3, 0.3, 1.4), Vector3(-8.0, 0.3, -3.0), ember, "Embers", false)
	SceneKit.omni(self, Vector3(-7.3, 1.0, -3.0), Color(1.0, 0.62, 0.3), 2.4, 7.0, true)
	# ---- counter, pots, shelf, speaking tube
	SceneKit.box(self, Vector3(4.2, 0.9, 1.0), Vector3(-5.2, 0.45, -5.7), stone, "Counter")
	var copper := SceneKit.flat_color(Color(0.72, 0.45, 0.28), Color.BLACK, 0.0, 0.35, 0.8)
	SceneKit.cylinder(self, 0.32, 0.36, Vector3(-4.6, 1.08, -5.7), copper, "Pot", false)
	SceneKit.cylinder(self, 0.2, 0.2, Vector3(-3.7, 1.0, -5.7), copper, "Pot2", false)
	SceneKit.cylinder(self, 0.16, 0.26, Vector3(-6.3, 1.03, -5.7), copper, "Pot3", false)
	SceneKit.box(self, Vector3(2.6, 0.08, 0.4), Vector3(-2.0, 2.2, -6.45), wood, "Shelf", false)
	for i in 4:
		SceneKit.cylinder(self, 0.1, 0.18, Vector3(-3.0 + float(i) * 0.6, 2.33, -6.45), copper, "Jar%d" % i, false)
	SceneKit.cylinder(self, 0.08, 2.0, Vector3(-0.2, 1.6, -6.4), brass, "Tube", false)
	SceneKit.cylinder(self, 0.22, 0.2, Vector3(-0.2, 2.7, -6.3), brass, "TubeHorn", false)
	# ---- table, benches, bowls, stool
	SceneKit.box(self, Vector3(3.6, 0.12, 1.4), Vector3(-2.5, 0.84, 0.4), wood, "TableTop")
	for p in [Vector3(-4.1, 0.4, -0.15), Vector3(-0.9, 0.4, -0.15), Vector3(-4.1, 0.4, 0.95), Vector3(-0.9, 0.4, 0.95)]:
		SceneKit.box(self, Vector3(0.14, 0.8, 0.14), p, wood, "Leg", false)
	SceneKit.box(self, Vector3(3.0, 0.08, 0.35), Vector3(-2.5, 0.45, -0.7), dark_wood, "BenchN", false)
	var porcelain := SceneKit.flat_color(Color(0.93, 0.92, 0.88), Color.BLACK, 0.0, 0.4)
	var ash := SceneKit.flat_color(Color(0.45, 0.44, 0.42), Color.BLACK, 0.0, 0.9)
	bowl = SceneKit.cylinder(self, 0.14, 0.08, Vector3(-1.4, 0.94, 0.7), porcelain, "SeraBowl", false)
	bowl_ash = SceneKit.cylinder(self, 0.14, 0.08, Vector3(-1.4, 0.94, 0.7), ash, "SeraBowlAsh", false)
	bowl_ash.visible = false
	SceneKit.cylinder(self, 0.14, 0.08, Vector3(-3.4, 0.94, 0.1), porcelain, "Bowl2", false)
	SceneKit.cylinder(self, 0.22, 0.45, Vector3(-1.4, 0.225, 1.5), wood, "Stool")
	var groove := SceneKit.flat_color(Color(0.05, 0.05, 0.06), Color.BLACK, 0.0, 0.3)
	SceneKit.box(self, Vector3(0.06, 0.46, 0.2), Vector3(-1.18, 0.23, 1.5), groove, "StoolGroove", false)
	# ---- crates and barrels in the hall, the pantry recess where the Cradle waits
	SceneKit.box(self, Vector3(0.7, 0.7, 0.7), Vector3(3.0, 0.35, -6.2), wood, "Crate")
	SceneKit.box(self, Vector3(0.6, 0.6, 0.6), Vector3(3.8, 0.3, -5.6), wood, "Crate2")
	SceneKit.cylinder(self, 0.4, 0.9, Vector3(12.4, 0.45, -6.2), dark_wood, "Barrel")
	SceneKit.cylinder(self, 0.4, 0.9, Vector3(12.4, 0.45, 4.3), dark_wood, "Barrel2")
	var pantry := SceneKit.flat_color(Color(0.1, 0.09, 0.09), Color.BLACK, 0.0, 1.0)
	SceneKit.box(self, Vector3(4.0, 3.6, 0.4), Vector3(8.5, 1.8, -7.0), pantry, "PantryDark", false)
	for i in 3:
		SceneKit.box(self, Vector3(0.9, 0.12, 0.5), Vector3(7.3 + float(i) * 1.2, 1.2 + float(i) * 0.5, -6.9), wood, "PantryShelf%d" % i, false)
	# pillars in the hall
	for px in [4.0, 10.5]:
		for pz in [-4.0, 2.5]:
			SceneKit.cylinder(self, 0.35, 4.5, Vector3(px, 2.25, pz), wall, "Pillar")
	# ---- the Fracture Gate: a brass lattice in the doorway
	_build_gate(brass)
	# ---- lights: the window sun shafts, a cool fill from the hall
	for wx in [-6.5, -2.5]:
		var sun := SpotLight3D.new()
		sun.position = Vector3(wx, 3.8, -4.6)
		sun.rotation_degrees = Vector3(-72, 0, 0)
		sun.light_color = Color(0.72, 0.6, 0.92)
		sun.light_energy = 1.8
		sun.spot_range = 9.0
		sun.spot_angle = 26.0
		sun.spot_angle_attenuation = 1.6
		add_child(sun)
	SceneKit.omni(self, Vector3(7.0, 3.2, -1.0), Color(0.7, 0.75, 0.9), 1.6, 12.0, false)
	SceneKit.omni(self, Vector3(-3.0, 2.8, 1.0), Color(1.0, 0.9, 0.8), 1.0, 8.0, false)
	# ---- markers
	add_marker("start", Vector3(-4.6, 0.0, -4.4))
	add_marker("counter", Vector3(-4.6, 0.0, -4.5))
	add_marker("table_crono", Vector3(-3.4, 0.0, 1.6))
	add_marker("sera_door", Vector3(-4.0, 0.0, 4.2))
	add_marker("sera_seat", Vector3(-1.4, 0.0, 2.2))
	add_marker("sera_fall", Vector3(-1.4, 0.0, 2.4))
	add_marker("marle_door", Vector3(-4.0, 0.0, 4.0))
	add_marker("marle_spot", Vector3(-5.8, 0.0, -3.2))
	add_marker("marle_near", Vector3(-2.6, 0.0, 2.6))
	add_marker("gate", Vector3(0.0, 0.0, 0.0))
	add_marker("hall", Vector3(5.0, 0.0, 0.0))
	add_marker("cradle", Vector3(8.5, 0.0, -4.2))
	add_marker("cradle_center", Vector3(7.5, 0.0, -0.5))
	add_marker("exit", Vector3(12.4, 0.0, 0.0))
	# ---- the dust motes that orbit the way he stirs
	_build_motes()
	# ---- the exit (usable once the Cradle is down)
	exit_door = add_door("ExitDoor", Vector3(12.9, 0.8, 0.0), &"guardia_courtyard", &"start", "Courtyard")
	exit_door.callback = Callable(self, "_use_exit")
	# ---- the Cradle trigger
	cradle_trigger = Area3D.new()
	cradle_trigger.collision_layer = 0
	cradle_trigger.collision_mask = 2
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5.0, 3.0, 11.0)
	cs.shape = box
	cradle_trigger.add_child(cs)
	cradle_trigger.position = Vector3(7.0, 1.0, -1.0)
	cradle_trigger.monitoring = false
	add_child(cradle_trigger)
	cradle_trigger.body_entered.connect(_on_cradle_trigger)


func after_ready() -> void:
	var cp: StringName = Game.checkpoint
	if cp == CP_START or cp == &"":
		# Marle and Sera are not in the field party yet; they enter during breakfast.
		if Game.active_party.size() > 1:
			rebuild_party([&"crono"])
		_place_cast_for_breakfast()
		_opening()
	else:
		if cp == CP_GATE or cp == CP_CRADLE:
			_set_gate_open(true)
			_activate_hall()
		if cp == CP_CRADLE:
			_cradle_started = true
			cradle_trigger.monitoring = false
			Flags.add_counter(&"__noop", 0)
		_activate_kitchen_zones()
		for arg in OS.get_cmdline_user_args():
			if arg == "--demo=cradle" and cp == CP_GATE:
				# capture runs: walk straight into the hall so the Cradle wakes
				await get_tree().create_timer(0.4).timeout
				place_party(&"gate")
				party_actors[0].walk_to(get_marker("hall") + Vector3(2.0, 0, 0), 5.0)


# ------------------------------------------------------------------ opening

func _place_cast_for_breakfast() -> void:
	var marle: CombatActor = add_cast(&"marle", get_marker("marle_door"), "n")
	marle.visible = false
	var sera: CombatActor = add_cast(&"sera", get_marker("sera_door"), "n")
	sera.visible = false
	if not party_actors.is_empty():
		party_actors[0].global_position = get_marker("counter")
		party_actors[0].face("n")


func _opening() -> void:
	controller.enabled = false
	Router.fade.color.a = 1.0
	await get_tree().process_frame
	await Story.run(&"prologue_wake")
	await Router.fade_in(1.5)
	await Story.run(&"prologue_breakfast")
	# Marle and Sera join the field party (Marle as a guest).
	rebuild_party([&"crono", &"marle", &"sera"])
	Game.checkpoint = CP_BREAKFAST
	_activate_kitchen_zones()
	controller.enabled = true
	Saves.save(0)


## Story calls --------------------------------------------------------------------------------------

## Seven clockwise stirs and a tap on the rim: the preservation ritual Bekkler encoded.
func stir_ritual() -> void:
	var crono: CombatActor = get_actor(&"crono")
	if crono == null:
		return
	crono.global_position = get_marker("counter")
	crono.face("n")
	if motes:
		motes.emitting = true
	for i in 7:
		crono.play_anim("interact", "idle")
		Audio.play_sfx("ui/stir", -6.0, 0.95 + 0.02 * float(i))
		await get_tree().create_timer(0.45 if not Story.skip_waits else 0.01).timeout
	Audio.play_sfx("porcelain/tink")
	crono.play_anim("interact", "idle")
	await get_tree().create_timer(0.5 if not Story.skip_waits else 0.01).timeout
	# the house clock skips a half-second tick
	Audio.play_sfx("time/clock_skip")
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.03, true, false, true).timeout
	Engine.time_scale = 1.0
	crono.face("s")


## Sera's forearm phases into U1 sumi-e; the bowl splits; the ink puddle stays as residue.
func first_chronoslip() -> void:
	var sera: Node = get_actor(&"sera")
	var crono: CombatActor = get_actor(&"crono")
	if sera is CombatActor:
		var s := sera as CombatActor
		s.play_anim("interact", "idle")
		s.sprite.set_tint(Color(0.55, 0.55, 0.58))
		s.sprite.material.set_shader_parameter("canvas_fps", 24.0)
		s.sprite.canvas_fps = 24.0
	Audio.play_sfx("time/chronoslip_u1")
	Audio.set_rtpc("slip", 1.0)
	if world:
		world.set_leak(1, 0.75)
	Universe.leaks[1] = 0.75
	shake(0.25)
	if bowl_ash:
		bowl_ash.visible = true
		bowl_ash.scale = Vector3(0.5, 1.0, 1.0)
		bowl_ash.position.x += 0.08
		bowl.scale = Vector3(0.5, 1.0, 1.0)
		bowl.position.x -= 0.08
	add_ink_puddle(get_marker("sera_seat") + Vector3(0.3, 0.0, -0.2), 1.0)
	if crono:
		crono.walk_to(get_marker("sera_seat") + Vector3(-1.0, 0.0, 0.2), 5.0)
	await get_tree().create_timer(1.2 if not Story.skip_waits else 0.01).timeout
	if crono:
		crono.play_anim("hurt", "idle")
		crono.set_porcelain_visuals()
	await get_tree().create_timer(4.0 if not Story.skip_waits else 0.01).timeout
	if world:
		world.set_leak(1, 0.0)
	Universe.leaks.erase(1)
	Audio.set_rtpc("slip", 0.0)
	if sera is CombatActor:
		var s2 := sera as CombatActor
		s2.sprite.set_tint(Color(0.85, 0.85, 0.88))
		s2.sprite.material.set_shader_parameter("canvas_fps", 60.0)
		s2.sprite.canvas_fps = 60.0


## Her eyes roll to gold leaf; Vaelos speaks through her; one frame of rubber-hose; she falls.
func sera_collapses() -> void:
	var sera: Node = get_actor(&"sera")
	if world:
		world.set_leak(7, 0.5)
	await get_tree().create_timer(0.6 if not Story.skip_waits else 0.01).timeout
	if world:
		world.set_leak(7, 0.0)
		world.set_leak(5, 0.9)
	Audio.play_sfx("time/frame_snap")
	await get_tree().create_timer(0.07, true, false, true).timeout
	if world:
		world.set_leak(5, 0.0)
	if sera is CombatActor:
		(sera as CombatActor).play_anim("ko", "ko")
	Audio.play_sfx("porcelain/doll_fall")
	var crono: CombatActor = get_actor(&"crono")
	if crono:
		crono.face_toward(get_marker("sera_seat"))


## Called by the breakfast script after the fall choice: Sera is caught (or the bowl is).
func after_fall(kind: String = "light") -> void:
	var sera: Node = get_actor(&"sera")
	var marle: Node = get_actor(&"marle")
	var crono: CombatActor = get_actor(&"crono")
	if kind == "prismatic" and crono:
		crono.play_anim("attack", "idle")
		_smear_trail(crono.global_position, get_marker("sera_seat"))
		if bowl_ash:
			bowl_ash.visible = false
			bowl.scale = Vector3.ONE
			bowl.position.x += 0.08
		Flags.add_counter(&"gold_fleck_moments", 1)
	if sera is CombatActor:
		(sera as CombatActor).play_anim("revive", "idle")
		(sera as CombatActor).sprite.set_tint(Color.WHITE)
	if marle is CombatActor:
		(marle as CombatActor).walk_to(get_marker("marle_near"), 3.2)
	if crono:
		crono.set_porcelain_visuals()


func _smear_trail(from: Vector3, to: Vector3) -> void:
	for i in 5:
		var ghost := ActorSprite.new()
		var crono: CombatActor = get_actor(&"crono")
		if crono == null:
			return
		ghost.material.set_shader_parameter("sheet", crono.sprite.material.get_shader_parameter("sheet"))
		ghost.material.set_shader_parameter("frame_rect", crono.sprite.material.get_shader_parameter("frame_rect"))
		ghost.material.set_shader_parameter("sheet_px", crono.sprite.material.get_shader_parameter("sheet_px"))
		ghost.mesh = crono.sprite.mesh
		ghost.set_tint(Color(1.0, 0.45, 0.4).lerp(Color(0.4, 0.5, 1.0), float(i) / 4.0))
		ghost.set_opacity(0.55)
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ghost)
		ghost.global_position = from.lerp(to, float(i) / 5.0) + crono.sprite.position
		var tw := create_tween()
		tw.tween_property(ghost, "transparency", 1.0, 0.5 + 0.12 * float(i))
		tw.tween_callback(ghost.queue_free)


# ------------------------------------------------------------------ the gate

func _build_gate(brass: Material) -> void:
	gate_mesh = Node3D.new()
	gate_mesh.name = "FractureGate"
	gate_mesh.position = Vector3(1.0, 0.0, 0.0)
	add_child(gate_mesh)
	var dark_brass := SceneKit.flat_color(Color(0.55, 0.42, 0.2), Color(0.9, 0.6, 0.2), 0.25, 0.4, 0.9)
	for i in 5:
		SceneKit.box(gate_mesh, Vector3(0.12, 3.1, 0.08), Vector3(0.0, 1.55, -1.0 + float(i) * 0.5), brass, "Bar%d" % i, false)
	for j in 6:
		SceneKit.box(gate_mesh, Vector3(0.1, 0.08, 2.3), Vector3(0.0, 0.3 + float(j) * 0.52, 0.0), dark_brass, "Rail%d" % j, false)
	# the hand-shaped plate at its centre, palm up
	var plate := SceneKit.flat_color(Color(0.85, 0.7, 0.4), Color(1.0, 0.75, 0.35), 0.6, 0.3, 0.9)
	SceneKit.box(gate_mesh, Vector3(0.16, 0.5, 0.42), Vector3(-0.06, 1.25, 0.0), plate, "HandPlate", false)
	gate_body = StaticBody3D.new()
	gate_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 3.2, 2.4)
	cs.shape = box
	cs.position = Vector3(0.0, 1.6, 0.0)
	gate_body.add_child(cs)
	gate_mesh.add_child(gate_body)
	gate_interact = Interactable.make(self, "FractureGate", Vector3(0.4, 0.9, 0.0), &"", "Fracture Gate", 1.1)
	gate_interact.callback = Callable(self, "_use_gate")


func _use_gate(_by: Node) -> void:
	if Game.checkpoint == CP_START:
		return
	await Story.run(&"prologue_gate")
	open_gate()


## The gate opens by exactly as much as he gives it: a permanent 5% of his ceiling.
func open_gate() -> void:
	if Game.checkpoint == CP_GATE or Game.checkpoint == CP_CRADLE:
		return
	var crono: CombatActor = get_actor(&"crono")
	if crono and crono.time_debt:
		crono.time_debt.pay_integrity(5.0)
		Game.set_integrity(crono.time_debt.integrity)
		crono.set_porcelain_visuals()
		crono.play_anim("interact", "idle")
	else:
		Game.set_integrity(Game.crono_integrity - 5.0)
	if Flags.is_state(&"Prologue_Fall", &"Hold_The_Copy_Together"):
		Flags.add_counter(&"vaelos_whisper_bonus", 15)
		Audio.play_sfx("weapons/katana_slash")
	Flags.add_counter(&"debts_paid", 1)
	shake(0.5)
	Audio.play_sfx("ui/gate_brass_open")
	_set_gate_open(true, true)
	Game.checkpoint = CP_GATE
	_activate_hall()
	Saves.save(0)


func _set_gate_open(open: bool, animate: bool = false) -> void:
	if gate_body:
		gate_body.get_child(0).set_deferred("disabled", open)
	if gate_interact:
		gate_interact.one_shot = open
		gate_interact.used_once = open
	if gate_mesh:
		if animate:
			var tw := create_tween()
			tw.tween_property(gate_mesh, "position:y", 3.4, 1.6).set_trans(Tween.TRANS_SINE)
		else:
			gate_mesh.position.y = 3.4 if open else 0.0


# ------------------------------------------------------------------ encounters and the Cradle

func _activate_kitchen_zones() -> void:
	if zones.any(func(z: EncounterZone) -> bool: return z.encounter_id == &"kitchen_motes"):
		return
	_live_zone(&"kitchen_motes", Vector3(-5.0, 0.0, 1.5), 2.2)


func _activate_hall() -> void:
	if zones.any(func(z: EncounterZone) -> bool: return z.encounter_id == &"kitchen_shardlings"):
		return
	_live_zone(&"kitchen_shardlings", Vector3(4.5, 0.0, 2.5), 2.4)
	_live_zone(&"kitchen_spoons", Vector3(11.0, 0.0, -3.5), 2.4)
	if Game.checkpoint != CP_CRADLE:
		cradle_trigger.set_deferred("monitoring", true)
	else:
		_live_zone(&"kitchen_echo", Vector3(10.5, 0.0, 2.8), 2.0)


func _live_zone(id: StringName, pos: Vector3, radius: float) -> void:
	var z: EncounterZone = add_zone(id, pos, radius)
	z.spawn(self)
	z.triggered.connect(_on_zone_triggered)


func _on_cradle_trigger(body: Node3D) -> void:
	if _cradle_started or party_actors.is_empty() or body != party_actors[0] or Story.is_running() or _in_battle:
		return
	_cradle_started = true
	cradle_trigger.set_deferred("monitoring", false)
	controller.enabled = false
	for a in party_actors:
		a.velocity = Vector3.ZERO
	Audio.play_music(&"mus_stings_boss_approach", 0.3)
	await get_tree().create_timer(0.3).timeout
	controller.enabled = true
	await Story.run(&"prologue_cradle_sequence")
	if Game.checkpoint == CP_CRADLE:
		_live_zone(&"kitchen_echo", Vector3(10.5, 0.0, 2.8), 2.0)


func _use_exit(_by: Node) -> void:
	if Game.checkpoint != CP_CRADLE:
		Story.run(&"prologue_exit_locked")
		return
	await Story.run(&"prologue_exit_hook")
	Router.go(&"guardia_courtyard", &"start")


# ------------------------------------------------------------------ dressing

func _window(glass: Material, pos: Vector3, size: Vector2) -> void:
	var win := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	win.mesh = q
	win.material_override = glass
	win.position = pos
	add_child(win)
	var frame := SceneKit.flat_color(Color(0.18, 0.17, 0.16), Color.BLACK, 0.0, 0.7)
	SceneKit.box(self, Vector3(size.x + 0.3, 0.15, 0.2), pos + Vector3(0, size.y * 0.5 + 0.05, 0.02), frame, "WinTop", false)
	SceneKit.box(self, Vector3(size.x + 0.3, 0.15, 0.2), pos + Vector3(0, -size.y * 0.5 - 0.05, 0.02), frame, "WinBottom", false)
	SceneKit.box(self, Vector3(0.15, size.y + 0.2, 0.2), pos + Vector3(-size.x * 0.5 - 0.05, 0, 0.02), frame, "WinL", false)
	SceneKit.box(self, Vector3(0.15, size.y + 0.2, 0.2), pos + Vector3(size.x * 0.5 + 0.05, 0, 0.02), frame, "WinR", false)


func _stained_glass_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
	vec2 uv = UV;
	vec2 g = floor(uv * vec2(4.0, 6.0));
	float h = fract(sin(dot(g, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 a = vec3(0.17, 0.30, 0.61); vec3 b = vec3(0.76, 0.27, 0.43); vec3 c = vec3(0.88, 0.64, 0.23); vec3 d = vec3(0.31, 0.72, 0.69);
	vec3 col = h < 0.25 ? a : (h < 0.5 ? b : (h < 0.75 ? c : d));
	vec2 f = fract(uv * vec2(4.0, 6.0));
	float lead = step(f.x, 0.06) + step(0.94, f.x) + step(f.y, 0.06) + step(0.94, f.y);
	float dust = 0.55 + 0.45 * fract(sin(dot(floor(uv * 40.0), vec2(4.1, 9.7))) * 1234.5);
	col = mix(col * dust, vec3(0.08), clamp(lead, 0.0, 1.0));
	ALBEDO = col * 0.4;
	EMISSION = col * 1.6 * (1.0 - clamp(lead, 0.0, 1.0));
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _build_motes() -> void:
	motes = GPUParticles3D.new()
	motes.name = "DustMotes"
	motes.amount = 40
	motes.lifetime = 6.0
	motes.emitting = true
	motes.position = Vector3(-4.6, 1.4, -5.7)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_radius = 0.45
	pm.emission_ring_inner_radius = 0.3
	pm.emission_ring_height = 0.1
	pm.emission_ring_axis = Vector3(0, 1, 0)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 15.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.15
	pm.gravity = Vector3(0, 0.02, 0)
	pm.orbit_velocity_min = 0.12
	pm.orbit_velocity_max = 0.18
	pm.scale_min = 0.02
	pm.scale_max = 0.05
	pm.color = Color(1.0, 0.92, 0.75, 0.8)
	motes.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.93, 0.78, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.material = mat
	motes.draw_pass_1 = qm
	add_child(motes)
