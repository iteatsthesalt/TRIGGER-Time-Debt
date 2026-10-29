## Base for every location scene: world environment, camera rig, the party in the field, interaction,
## encounter zones and the hand-off into and out of battle. Subclasses override build() and hooks.
class_name Location
extends Node3D

signal battle_started
signal battle_finished(victory: bool)

@export var location_id: StringName = &""
@export var universe_id: int = 0
@export var field_music: StringName = &""
@export var ambience: StringName = &""
@export var camera_distance: float = 14.0
@export var camera_pitch: float = 30.0
@export var map_bounds: Rect2 = Rect2()

var world: HD2DWorld
var rig: HD2DCameraRig
var key_light: DirectionalLight3D
var controller: PlayerController
var follow: PartyFollow
var party_actors: Array[CombatActor] = []
var npc_actors: Dictionary = {}
var markers: Dictionary = {}
var zones: Array[EncounterZone] = []
var battle: BattleScene
var prompt_label: Label
var _ui_layer: CanvasLayer
var _in_battle: bool = false
var _party_root: Node3D


func _ready() -> void:
	Universe.set_universe(universe_id, true)
	world = HD2DWorld.new()
	world.name = "World"
	world.environment = HD2DWorld.make_environment(universe_id)
	add_child(world)
	key_light = HD2DWorld.add_three_point_lights(self, universe_id != 4 and universe_id != 6)
	_party_root = Node3D.new()
	_party_root.name = "Party"
	add_child(_party_root)
	build()
	_spawn_party()
	rig = HD2DCameraRig.new()
	rig.name = "CameraRig"
	rig.distance = camera_distance
	rig.pitch_degrees = camera_pitch
	rig.map_bounds = map_bounds
	add_child(rig)
	if not party_actors.is_empty():
		rig.target = party_actors[0]
	rig.snap()
	controller = PlayerController.new()
	controller.name = "PlayerController"
	add_child(controller)
	if not party_actors.is_empty():
		controller.attach(party_actors[0])
	controller.interact_requested.connect(_on_interact)
	controller.focus_changed.connect(_on_focus)
	controller.menu_requested.connect(_on_menu)
	follow = PartyFollow.new()
	follow.name = "PartyFollow"
	add_child(follow)
	if not party_actors.is_empty():
		follow.set_party(party_actors[0], party_actors.slice(1))
	_build_ui()
	for z in zones:
		z.spawn(self)
		z.triggered.connect(_on_zone_triggered)
	if field_music != &"":
		Audio.play_music(field_music)
	if ambience != &"":
		Audio.play_ambience(ambience)
	Story.battle_requested.connect(_on_story_battle)
	Story.camera_requested.connect(_on_story_camera)
	_start_after_ready()


## after_ready() runs once the script that brought us here (a "go" command) has finished.
func _start_after_ready() -> void:
	while Story.is_running():
		await get_tree().process_frame
	if is_inside_tree():
		after_ready()


func _exit_tree() -> void:
	if Story.battle_requested.is_connected(_on_story_battle):
		Story.battle_requested.disconnect(_on_story_battle)
	if Story.camera_requested.is_connected(_on_story_camera):
		Story.camera_requested.disconnect(_on_story_camera)


## Override: geometry, markers, interactables, zones, NPCs.
func build() -> void:
	pass


## Override: scripted openings.
func after_ready() -> void:
	pass


func _spawn_party() -> void:
	for id in Game.active_party:
		var a := CombatActor.create_party_member(id)
		_party_root.add_child(a)
		party_actors.append(a)
	_refresh_porcelain()


func place_party(spawn: StringName) -> void:
	var p: Vector3 = get_marker(spawn) if markers.has(spawn) else Vector3.ZERO
	if get_marker(spawn) == null:
		p = Vector3.ZERO
	for i in party_actors.size():
		party_actors[i].global_position = p + Vector3(0, 0.05, 0.9 * float(i))
	if follow:
		follow.snap_behind()
	if rig:
		rig.snap()


func get_actor(id: StringName) -> Node:
	for a in party_actors:
		if a.actor_id == id:
			return a
	return npc_actors.get(id, null)


func get_marker(name: StringName) -> Variant:
	if markers.has(name):
		return (markers[name] as Node3D).global_position
	return null


func add_marker(name: String, pos: Vector3) -> Marker3D:
	var m := SceneKit.marker(self, name, pos)
	markers[StringName(name)] = m
	return m


func add_zone(encounter_id: StringName, pos: Vector3, radius: float = 6.0, boss: bool = false) -> EncounterZone:
	var z := EncounterZone.new()
	z.name = "Zone_" + String(encounter_id)
	z.encounter_id = encounter_id
	z.radius = radius
	z.boss = boss
	z.position = pos
	add_child(z)
	zones.append(z)
	return z


## Place an NPC with a generated or painted sprite; returns the FieldNPC (walk_to/face/play_anim for scripts).
func add_npc(id: StringName, sprite_id: String, pos: Vector3, facing: String = "s", fps: float = 60.0, script: StringName = &"", prompt: String = "Talk", wander: float = 0.0) -> FieldNPC:
	var n: FieldNPC = FieldNPC.make(id, sprite_id, fps)
	n.position = pos
	n.wander_radius = wander
	add_child(n)
	n.sprite.set_facing(StringName(facing))
	npc_actors[id] = n
	if script != &"":
		var it := Interactable.make(n, "Talk", Vector3(0, 0.8, 0), script, prompt, 0.9)
		it.set_meta("npc", n)
	return n


## A cast member standing in the scene before (or without) joining the party: a full CombatActor built
## from data/characters, so the same sprite, porcelain state and cutscene verbs apply.
func add_cast(id: StringName, pos: Vector3, facing: String = "s", script: StringName = &"", prompt: String = "Talk") -> CombatActor:
	var a: CombatActor = CombatActor.create_party_member(id)
	a.name = "Cast_" + String(id)
	a.collision_layer = 1
	add_child(a)
	a.global_position = pos
	a.face(facing)
	npc_actors[id] = a
	if script != &"":
		var it := Interactable.make(a, "Talk", Vector3(0, 0.8, 0), script, prompt, 0.9)
		it.set_meta("npc", a)
	return a


## Replace the field party (after a recruit or a guest joining mid-scene). Cast actors with the same id
## are removed; the new party appears at `at` (a marker name) or where the old leader stood.
func rebuild_party(ids: Array[StringName], at: StringName = &"") -> void:
	var here: Vector3 = party_actors[0].global_position if not party_actors.is_empty() else Vector3.ZERO
	var facing: StringName = party_actors[0].sprite.facing if not party_actors.is_empty() else &"s"
	Game.set_party(ids)
	for a in party_actors:
		a.queue_free()
	party_actors.clear()
	for id in ids:
		if npc_actors.has(id):
			var n: Node = npc_actors[id]
			npc_actors.erase(id)
			n.queue_free()
	_spawn_party()
	var p: Variant = get_marker(at) if at != &"" else null
	var origin: Vector3 = p if p != null else here
	for i in party_actors.size():
		party_actors[i].global_position = origin + Vector3(0, 0.05, 1.1 * float(i))
		party_actors[i].face(String(facing))
	rig.target = party_actors[0]
	controller.attach(party_actors[0])
	follow.set_party(party_actors[0], party_actors.slice(1))
	follow.snap_behind()


## Chronoslip residue (Story Bible, Prologue beat 7): a U1 ink puddle. Inside it the leader moves at
## 24 fps and the whole canvas leans to sumi-e; framerate as lore.
func add_ink_puddle(pos: Vector3, radius: float = 1.2) -> Area3D:
	var area := Area3D.new()
	area.name = "InkPuddle"
	area.collision_layer = 0
	area.collision_mask = 2
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 1.0
	cs.shape = cyl
	area.add_child(cs)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(radius * 2.0, radius * 2.0)
	mi.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.08, 0.1, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.2
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if ResourceLoader.exists("res://assets/textures/ink_puddle.png"):
		mat.albedo_texture = load("res://assets/textures/ink_puddle.png")
		mat.albedo_color = Color(1, 1, 1, 0.92)
	mi.material_override = mat
	mi.position = Vector3(0, 0.02, 0)
	area.add_child(mi)
	area.position = pos
	add_child(area)
	area.body_entered.connect(func(b: Node3D) -> void:
		if b == (party_actors[0] if not party_actors.is_empty() else null):
			_ink_slow(true))
	area.body_exited.connect(func(b: Node3D) -> void:
		if b == (party_actors[0] if not party_actors.is_empty() else null):
			_ink_slow(false))
	return area


func _ink_slow(on: bool) -> void:
	if controller:
		controller.speed = CombatActor.WALK_SPEED * (0.55 if on else 1.0)
	for a in party_actors:
		a.sprite.canvas_fps = 24.0 if on else a.canvas_fps
		a.sprite.material.set_shader_parameter("canvas_fps", 24.0 if on else a.canvas_fps)
		if on:
			a.sprite.set_tint(Color(0.75, 0.75, 0.78))
		else:
			a.sprite.set_tint(Color.WHITE)
	Universe.leaks[1] = 0.6 if on else 0.0
	if world:
		world.set_leak(1, 0.6 if on else 0.0)
	if on:
		Audio.play_sfx("time/ink_puddle_enter")


## A door or exit: an interactable that runs a script (or goes straight to a location) when used.
func add_door(name: String, pos: Vector3, to_location: StringName, spawn: StringName = &"start", prompt: String = "Leave", script: StringName = &"") -> Interactable:
	var it := Interactable.make(self, name, pos, script, prompt, 1.0)
	if script == &"":
		it.callback = func(_by: Node) -> void: Router.go(to_location, spawn)
	return it


func shake(amount: float) -> void:
	if rig:
		rig.shake(amount)


func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 20
	add_child(_ui_layer)
	prompt_label = Label.new()
	prompt_label.add_theme_font_size_override("font_size", 9)
	prompt_label.add_theme_color_override("font_color", Color("#F2EAD7"))
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.offset_top = -40
	prompt_label.offset_bottom = -24
	prompt_label.offset_left = -100
	prompt_label.offset_right = 100
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.visible = false
	_ui_layer.add_child(prompt_label)


func _process(_delta: float) -> void:
	if controller == null or party_actors.is_empty() or _in_battle:
		return
	var target: Node = controller.nearest_interactable() if not Story.is_running() else null
	if target != null and target is Interactable and (target as Interactable).can_use():
		prompt_label.text = "[E]  " + (target as Interactable).prompt
		prompt_label.visible = true
	else:
		prompt_label.visible = false


func _physics_process(_delta: float) -> void:
	if _in_battle or party_actors.is_empty() or Story.is_running():
		return
	var leader: CombatActor = party_actors[0]
	for z in zones:
		if z.check_contact(leader):
			break


func _on_interact(target: Node) -> void:
	if target is Interactable:
		(target as Interactable).use(party_actors[0] if not party_actors.is_empty() else null)


## Porcelain Insight: hold focus and the camera leans in; Crono's cracks read through the watercolour.
func _on_focus(on: bool) -> void:
	if rig:
		rig.set_truth(on)
	var crono: Node = get_actor(&"crono")
	if crono is CombatActor and (crono as CombatActor).sprite:
		var c := crono as CombatActor
		if on:
			var state: int = c.time_debt.crack_state(1.0) if c.time_debt else 0
			c.sprite.set_porcelain(maxi(2, state + 1), 0.8, 0.0)
		else:
			c.set_porcelain_visuals()


func _on_menu() -> void:
	pass


func _refresh_porcelain() -> void:
	for a in party_actors:
		a.set_porcelain_visuals()


# ------------------------------------------------------------------ battle hand-off

func _on_zone_triggered(zone: EncounterZone, advantage: String) -> void:
	var enc: Dictionary = Data.encounters.get(zone.encounter_id, {})
	start_battle(zone.living(), zone.global_position, {"advantage": advantage, "boss": zone.boss, "music": enc.get("music", "")}, zone)


func _on_story_battle(encounter_id: StringName, cmd: Dictionary) -> void:
	var enc: Dictionary = Data.encounters.get(encounter_id, {})
	var enemies: Array[CombatActor] = []
	var idx: int = 0
	var leader_pos: Vector3 = party_actors[0].global_position if not party_actors.is_empty() else Vector3.ZERO
	for ek in enc.get("enemies", []):
		var key: StringName = StringName(String(ek if ek is String else ek.get("key", "")))
		var def: EnemyDef = Data.enemy(key)
		if def == null:
			continue
		var a: CombatActor = CombatActor.create_enemy(def, -1, "_s%d" % idx)
		add_child(a)
		a.global_position = leader_pos + Vector3(4.0 + float(idx % 3) * 1.6, 0.0, -2.0 + float(idx / 3) * 2.0)
		enemies.append(a)
		idx += 1
	var boss_id: String = String(cmd.get("boss_id", ""))
	var music: String = String(enc.get("music", ""))
	if boss_id != "" and Data.bosses.has(StringName(boss_id)):
		var bdef: BossDef = BossDef.from_dict(Data.bosses[StringName(boss_id)])
		var b: CombatActor = BossController.create_boss_actor(bdef)
		if int(cmd.get("boss_hp", 0)) > 0:  # tests and tuning runs
			b.stats.base_max_hp = int(cmd["boss_hp"])
			b.stats.reset_vitals()
		add_child(b)
		var at: Variant = get_marker(StringName(String(cmd.get("at", "")))) if cmd.has("at") else null
		b.global_position = at if at != null else leader_pos + Vector3(5.0, 0.0, -1.0)
		enemies.push_front(b)
		if music == "":
			music = String(cmd.get("music", "mus_boss_%s" % boss_id))
	var center: Vector3 = leader_pos + Vector3(2.5, 0.0, 0.0)
	if cmd.has("center") and get_marker(StringName(String(cmd["center"]))) != null:
		center = get_marker(StringName(String(cmd["center"])))
	start_battle(enemies, center, {"advantage": String(cmd.get("advantage", "normal")), "boss": bool(cmd.get("boss", boss_id != "")), "music": music, "story": true, "boss_id": boss_id}, null)


func start_battle(enemies: Array, center: Vector3, config: Dictionary, zone: EncounterZone) -> void:
	if _in_battle:
		return
	_in_battle = true
	controller.enabled = false
	follow.paused = true
	for a in party_actors:
		a.velocity = Vector3.ZERO
		a.sprite.update_from_velocity(Vector3.ZERO)
	battle = BattleScene.new()
	battle.name = "Battle"
	add_child(battle)
	battle.universe = universe_id
	battle.finished.connect(_on_battle_finished.bind(zone))
	rig.enter_battle(center)
	battle_started.emit()
	battle.begin(party_actors, enemies, center, config, rig)


func _on_battle_finished(victory: bool, summary: Dictionary, zone: EncounterZone) -> void:
	_in_battle = false
	rig.exit_battle()
	rig.set_truth(false)
	controller.enabled = true
	follow.paused = false
	follow.snap_behind()
	if zone != null:
		zone.clear_defeated()
	_write_back_party()
	_refresh_porcelain()
	if field_music != &"":
		Audio.play_music(field_music)
	if battle != null:
		battle.queue_free()
		battle = null
	battle_finished.emit(victory)
	Story.report_battle_result(summary)
	if not victory:
		if bool(summary.get("story", false)):
			_revive_party(0.5)
		else:
			_on_defeat()


func _write_back_party() -> void:
	for a in party_actors:
		var r: Dictionary = Game.roster.get(a.actor_id, {})
		r["level"] = a.stats.level
		r["xp"] = a.stats.xp
		r["hp_ratio"] = a.stats.hp_ratio() if a.stats.is_alive() else 0.3
		if a.time_debt:
			Game.set_integrity(a.time_debt.integrity)
		if a.solidity:
			Game.set_debt(a.solidity.debt)


## Defeat: no Game Over. Sera jumps the party back to the moment before the encounter (§16.1).
func _on_defeat() -> void:
	Audio.tape_stop()
	_revive_party(0.3)
	place_party(Game.spawn_point)


func _revive_party(ratio: float) -> void:
	for a in party_actors:
		if not a.stats.is_alive():
			a.stats.revive(ratio)
		else:
			a.stats.hp = maxi(a.stats.hp, roundi(float(a.stats.max_hp()) * ratio))
		a.visible = true
		a.frozen = false
		a.sprite.set_opacity(1.0)
		a.sprite.set_tint(Color.WHITE)
		a.sprite.play(&"idle")


func _on_story_camera(mode: String, focus: Node) -> void:
	if rig == null:
		return
	match mode:
		"truth":
			rig.set_truth(true)
			if focus is Node3D:
				rig.target = focus
		"explore":
			rig.set_truth(false)
			if not party_actors.is_empty():
				rig.target = party_actors[0]
		"focus":
			if focus is Node3D:
				rig.target = focus
		"shake":
			rig.shake(0.5)
