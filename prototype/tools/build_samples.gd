## Regenerates sample Tech .tres files and the combat sandbox scene.
##   godot --headless --path . --script res://tools/build_samples.gd
## Generating through ResourceSaver/PackedScene guarantees the files are valid
## for this Godot version instead of hand-writing serialized text.
extends SceneTree

const DT := CombatTypes.DamageType
const SS := TechResource.SpatialShape


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/techs")
	DirAccess.make_dir_recursive_absolute("res://scenes")
	var techs: Array[TechResource] = [
		_tech(&"cyclone", "Cyclone", 0, [&"crono"], [DT.SWORD], SS.CIRCLE_AROUND_TARGET, false, 1.2, 1.0, 1, 2),
		_tech(&"flame_toss", "Flame Toss", 0, [&"lucca"], [DT.FIRE], SS.LINE_PIERCE, true, 1.1, 1.0, 1, 1),
		_tech(&"slurp_cut", "Slurp Cut", 0, [&"frog"], [DT.SWORD], SS.SINGLE_TARGET, false, 1.4, 1.0, 1, 2),
		_tech(&"fire_whirl", "Fire Whirl", 1, [&"crono", &"lucca"], [DT.SWORD, DT.FIRE],
			SS.CIRCLE_AROUND_TARGET, true, 1.65, 1.25, 2, 4),
		_tech(&"x_strike", "X Strike", 1, [&"crono", &"frog"], [DT.SWORD], SS.LINE_PIERCE, false, 1.8, 1.25, 2, 4),
		_tech(&"delta_force", "Delta Force", 2, [&"crono", &"lucca", &"frog"], [DT.SWORD, DT.FIRE, DT.ICE],
			SS.SELF_AURA, true, 2.2, 1.5, 3, 8),
	]
	for t in techs:
		var path := "res://data/techs/%s.tres" % t.tech_id
		var err := ResourceSaver.save(t, path)
		print("saved %s (%s)" % [path, error_string(err)])
	_build_sandbox(techs)
	quit()


func _tech(id: StringName, label: String, tier: int, actors: Array, tags: Array, shape: int,
		elemental: bool, mult: float, synergy: float, hits: int, mp: int) -> TechResource:
	var t := TechResource.new()
	t.tech_id = id
	t.display_name = label
	t.tier = tier
	var ids: Array[StringName] = []
	for a in actors:
		ids.append(a)
	t.required_actor_ids = ids
	var tg: Array[CombatTypes.DamageType] = []
	for x in tags:
		tg.append(x)
	t.damage_tags = tg
	t.shape_type = shape
	t.uses_elemental_attack = elemental
	t.base_multiplier = mult
	t.synergy_multiplier = synergy
	t.hit_count = hits
	t.mp_cost_per_actor = mp
	return t


func _own(n: Node, owner_node: Node) -> void:
	n.owner = owner_node
	for c in n.get_children():
		_own(c, owner_node)


func _build_sandbox(techs: Array[TechResource]) -> void:
	var root := Node3D.new()
	root.name = "EraMapScene"
	root.set_script(load("res://scripts/debug/sandbox_driver.gd"))

	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.11, 0.16)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env_node.environment = env
	root.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = true
	root.add_child(sun)

	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_mesh.mesh = plane
	root.add_child(floor_mesh)

	var rig := HD2DCameraRig.new()
	rig.name = "HD2DCameraRig"
	rig.map_bounds = Rect2(-16, -16, 32, 32)  # keeps the 40 m ground plane filling the frame
	root.add_child(rig)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 32.0
	cam.position = Vector3(0, 9, 14)
	cam.rotation_degrees = Vector3(-32, 0, 0)
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 18.0
	attrs.dof_blur_amount = 0.04  # light tilt-shift while exploring; combat tweens it up
	cam.attributes = attrs
	rig.add_child(cam)

	var coord := HybridBattleCoordinator.new()
	coord.name = "HybridBattleCoordinator"
	coord.all_known_techs = techs
	coord.max_shield_shave_per_action = 3  # DECISIONS.md: shield shave cap
	root.add_child(coord)
	coord.camera_3d = cam
	coord.world_env = env_node
	rig.coordinator = coord

	var party_mgr := Node3D.new()
	party_mgr.name = "PartyManager"
	root.add_child(party_mgr)
	var party_defs := [
		[&"crono", Vector3(-9.0, 0, 0.0), {"patk": 60.0, "eatk": 30.0, "speed": 32.0, "weapon": DT.SWORD}, Color.ROYAL_BLUE],
		[&"lucca", Vector3(-10.0, 0, 1.2), {"patk": 30.0, "eatk": 60.0, "speed": 28.0, "weapon": DT.BOW}, Color.MEDIUM_PURPLE],
		[&"frog", Vector3(-10.0, 0, -1.2), {"patk": 55.0, "eatk": 35.0, "speed": 30.0, "weapon": DT.SWORD}, Color.SEA_GREEN],
	]
	for i in party_defs.size():
		var d: Array = party_defs[i]
		var actor := _actor(d[0], CombatTypes.Team.PARTY, d[1], d[2], d[3])
		party_mgr.add_child(actor)
		actor.add_to_group(&"party", true)
		if i == 0:
			actor.add_to_group(&"party_leader", true)
			actor.set("player_controlled", true)
			rig.target = actor
	var follow := PartyFollow.new()
	follow.name = "PartyFollow"
	follow.coordinator = coord
	party_mgr.add_child(follow)

	var drifter := EnemyWander.new()
	drifter.name = "EnemyWander"
	drifter.coordinator = coord
	root.add_child(drifter)

	var presentation := BattlePresentation.new()
	presentation.name = "BattlePresentation"
	presentation.coordinator = coord
	root.add_child(presentation)

	var decal := AoEDecalVisualizer3D.new()
	decal.name = "AoEDecalVisualizer3D"
	root.add_child(decal)
	var hud_layer := CanvasLayer.new()
	hud_layer.name = "BattleHUDLayer"
	root.add_child(hud_layer)
	var hud := BattleTimelineHUD.new()
	hud.name = "BattleTimelineHUD"
	hud_layer.add_child(hud)
	hud.coordinator = coord
	hud.camera_3d = cam
	hud.decal = decal
	var victory := VictoryScreen.new()
	victory.name = "VictoryScreen"
	victory.coordinator = coord
	hud_layer.add_child(victory)

	var zone := Area3D.new()
	zone.name = "EncounterZone_01"
	zone.set_script(load("res://scripts/world/encounter_zone.gd"))
	zone.collision_layer = 1 << 3
	zone.collision_mask = 1 << 1
	var zshape := CollisionShape3D.new()
	zshape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(14, 3, 10)
	zshape.shape = box
	zone.add_child(zshape)
	var group := Node3D.new()
	group.name = "EnemyGroup"
	zone.add_child(group)
	# Battle layout markers (local to the zone; enemies stand at local x = 1).
	_marker(zone, "CameraPoint", Vector3(-0.5, 0, 0))
	var anchors := Node3D.new()
	anchors.name = "PartyAnchors"
	zone.add_child(anchors)
	for p in [Vector3(-3.5, 0, 0), Vector3(-4.3, 0, 1.8), Vector3(-4.3, 0, -1.8)]:
		_marker(anchors, "Anchor%d" % anchors.get_child_count(), p)
	var wander := Node3D.new()
	wander.name = "WanderNodes"
	zone.add_child(wander)
	for p in [Vector3(1, 0, 0), Vector3(1, 0, 3.3), Vector3(1, 0, -3.3), Vector3(2.5, 0, 1.6), Vector3(2.5, 0, -1.6)]:
		_marker(wander, "Wander%d" % wander.get_child_count(), p)
	zone.position = Vector3(2, 0, 0)
	root.add_child(zone)
	zone.set("coordinator", coord)

	var enemy_defs := [
		[&"ogre", Vector3(3, 0, 0), {"hp": 900, "shields": 6, "weak": [DT.SWORD, DT.FIRE, DT.ICE], "speed": 20.0, "xp": 30, "gold": 60}, Color.FIREBRICK],
		[&"imp_a", Vector3(3, 0, 3.3), {"hp": 220, "shields": 2, "weak": [DT.SWORD, DT.FIRE], "speed": 26.0, "sheet": "imp",
			"xp": 8, "gold": 15},
			Color.DARK_ORANGE],
		[&"imp_b", Vector3(3, 0, -3.3), {"hp": 220, "shields": 2, "weak": [DT.SWORD, DT.FIRE], "speed": 26.0, "sheet": "imp",
			"xp": 8, "gold": 15},
			Color.DARK_ORANGE],
	]
	for d in enemy_defs:
		var e := _actor(d[0], CombatTypes.Team.ENEMY, d[1], d[2], d[3])
		group.add_child(e)
		e.add_to_group(&"enemies", true)

	for c in root.get_children():
		_own(c, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	print("pack sandbox: ", error_string(err))
	print("save sandbox: ", error_string(ResourceSaver.save(packed, "res://scenes/combat_sandbox.tscn")))
	root.free()


func _marker(parent: Node, marker_name: String, pos: Vector3) -> void:
	var m := Marker3D.new()
	m.name = marker_name
	m.position = pos
	parent.add_child(m)


func _actor(id: StringName, team: int, pos: Vector3, o: Dictionary, color: Color) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = String(id)
	body.position = pos
	body.collision_layer = (1 << 1) if team == CombatTypes.Team.PARTY else (1 << 2)
	body.collision_mask = 1

	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.6
	col.shape = cap
	col.position.y = 0.8
	body.add_child(col)

	# Labeled sheet from tools/sprites/make_placeholders.gd; flat quad if it hasn't been generated.
	var sheet_path := "res://assets/sprites/placeholders/%s.png" % o.get("sheet", id)
	if ResourceLoader.exists(sheet_path):
		var spr := ActorSprite.new()
		spr.name = "ActorSprite"
		spr.sheet = load(sheet_path)
		spr.position.y = 0.8
		body.add_child(spr)
	else:
		push_warning("%s missing; run tools/sprites/make_placeholders.gd then --import" % sheet_path)
		var mesh := MeshInstance3D.new()
		mesh.name = "PlaceholderMesh"
		var qm := QuadMesh.new()
		qm.size = Vector2(1.0, 1.6)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		qm.material = mat
		mesh.mesh = qm
		mesh.position.y = 0.8
		body.add_child(mesh)

	var nav := NavigationAgent3D.new()
	nav.name = "NavigationAgent3D"
	body.add_child(nav)

	var st := CombatantStats.new()
	st.name = "CombatantStats"
	st.actor_id = id
	st.team = team
	st.max_hp = o.get("hp", 400)
	st.speed = o.get("speed", 25.0)
	st.physical_attack = o.get("patk", 45.0)
	st.elemental_attack = o.get("eatk", 40.0)
	st.weapon_type = o.get("weapon", DT.AXE)
	st.xp_reward = o.get("xp", 0)
	st.gold_reward = o.get("gold", 0)
	body.add_child(st)

	if team == CombatTypes.Team.PARTY:
		var bc := BoostComponent.new()
		bc.name = "BoostComponent"
		body.add_child(bc)
	else:
		var sh := ShieldComponent.new()
		sh.name = "ShieldComponent"
		sh.max_shields = o.get("shields", 2)
		var w: Array[CombatTypes.DamageType] = []
		for x in o.get("weak", []):
			w.append(x)
		sh.weaknesses = w
		body.add_child(sh)

	body.set_script(load("res://scripts/actors/combat_actor.gd"))
	return body
