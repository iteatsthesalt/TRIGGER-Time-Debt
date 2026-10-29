## One battle on the field: the plane, the coordinator, the HUD, input, telegraphs, hit presentation
## and the dissolve (Combat Laws Bible §2, §4, §17). Created by the Location for each encounter.
class_name BattleScene
extends Node3D

signal finished(victory: bool, summary: Dictionary)

enum Mode { NONE, DECK, TECHS, TARGET, ITEMS, SWAP }

var universe: int = 0
var coordinator: BattleCoordinator
var hud: BattleHUD
var rig: HD2DCameraRig
var plane: MeshInstance3D
var plane_mat: ShaderMaterial
var party: Array[CombatActor] = []
var enemies: Array[CombatActor] = []
var center: Vector3
var mode: int = Mode.NONE
var actor: CombatActor
var current_tech: TechDef
var target_list: Array = []
var target_index: int = 0
var boost: int = 0
var partners: Array = []
var auto: bool = false
var auto_timer: float = 0.0
var telegraphs: Dictionary = {}
var preview_mesh: MeshInstance3D
var config: Dictionary = {}
var _ended: bool = false
var _flash: ColorRect
var boss: BossController
var input_blocked: bool = false
static var _plane_shader: Shader
static var _aoe_shader: Shader


func begin(party_in: Array, enemies_in: Array, c: Vector3, cfg: Dictionary, camera_rig: HD2DCameraRig) -> void:
	center = c
	config = cfg
	rig = camera_rig
	for a in party_in:
		party.append(a)
	for e in enemies_in:
		enemies.append(e)
	for arg in OS.get_cmdline_user_args():
		if arg == "--autobattle":
			auto = true
	if bool(cfg.get("auto", false)):
		auto = true
	_build_plane()
	_place_party()
	coordinator = BattleCoordinator.new()
	coordinator.name = "Coordinator"
	coordinator.universe = universe
	coordinator.knows_tech = _knows_tech
	add_child(coordinator)
	hud = BattleHUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.coordinator = coordinator
	hud.camera = rig.camera if rig else get_viewport().get_camera_3d()
	hud.command_chosen.connect(_on_deck_command)
	var defs: Dictionary = {}
	for e in enemies:
		if e.def != null:
			defs[e.stats.actor_id] = e.def
		hud.ensure_plate(e)
	coordinator.command_requested.connect(_on_command_requested)
	coordinator.strike_resolved.connect(_on_strike)
	coordinator.heal_resolved.connect(_on_heal)
	coordinator.unit_broken.connect(_on_broken)
	coordinator.unit_recovered.connect(_on_recovered)
	coordinator.unit_koed.connect(_on_koed)
	coordinator.unit_revived.connect(_on_revived)
	coordinator.unit_spared.connect(_on_spared)
	coordinator.telegraph_started.connect(_on_telegraph_started)
	coordinator.telegraph_ended.connect(_on_telegraph_ended)
	coordinator.enemy_action_started.connect(_on_enemy_action)
	coordinator.battle_message.connect(hud.show_message)
	coordinator.truth_moment.connect(_on_truth)
	coordinator.battle_ended.connect(_on_battle_ended)
	coordinator.boost_used.connect(_on_boost_used)
	coordinator.sera_phase_changed.connect(_on_sera_phase)
	coordinator.unit_moved.connect(_on_unit_moved)
	coordinator.summon_requested.connect(_on_summon_requested)
	var music: String = String(cfg.get("music", ""))
	if music != "":
		Audio.play_music(StringName(music), 0.6)
	Audio.play_sfx("time/gate_open_u%d" % universe)
	var bench: Array = []
	var hover: Node = null
	var start_cfg := {
		"advantage": String(cfg.get("advantage", "normal")), "universe": universe, "boss": bool(cfg.get("boss", false)),
		"techs": Data.techs, "enemy_defs": defs, "bench": bench, "hover_sera": hover,
		"prometheus": Game.prometheus_core, "parry_frames": Game.parry_frames, "max_bp": Game.max_bp, "max_spend": Game.max_spend,
		"sera_present": Game.sera_in_story != "absent",
	}
	hud.register_units(party, enemies, hover)
	for e in enemies:
		e.face_toward(center + Vector3(0, 0, 4))
	coordinator.flow_speed = float(Game.settings.get("flow_speed", 1.0))
	coordinator.start_battle(party, enemies, center, start_cfg)
	for e in enemies:
		if e.has_meta("boss_id") and boss == null:
			var bdef: BossDef = BossDef.from_dict(Data.bosses.get(StringName(String(e.get_meta("boss_id"))), {}))
			if bdef.phase_count() > 0:
				boss = BossController.new()
				boss.name = "Boss"
				add_child(boss)
				boss.setup(self, coordinator, e, bdef)
	var tw := create_tween()
	tw.tween_property(plane_mat, "shader_parameter/reveal", 1.0, 0.6)


func _knows_tech(a: Node, t: TechDef) -> bool:
	var st := CombatantStats.of(a)
	if st == null:
		return false
	if not Game.knows_tech(st.actor_id, t.id):
		return false
	for f in t.requires_flags:
		if not Flags.has(f):
			return false
	return true


func _build_plane() -> void:
	plane = MeshInstance3D.new()
	plane.name = "BattlePlane"
	var pm := PlaneMesh.new()
	pm.size = Vector2(CombatConstants.PLANE_SIZE, CombatConstants.PLANE_SIZE)
	pm.subdivide_width = CombatConstants.PLANE_SUBDIVIDE
	pm.subdivide_depth = CombatConstants.PLANE_SUBDIVIDE
	plane.mesh = pm
	if _plane_shader == null:
		_plane_shader = load("res://shaders/battle_plane.gdshader")
	plane_mat = ShaderMaterial.new()
	plane_mat.shader = _plane_shader
	plane_mat.set_shader_parameter("reveal", 0.0)
	var g: Dictionary = Universe.grade(universe)
	plane_mat.set_shader_parameter("tint", g.get("paper", Color(0.96, 0.93, 0.86)))
	plane.material_override = plane_mat
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plane.position = center + Vector3(0, 0.03, 0)
	add_child(plane)
	preview_mesh = MeshInstance3D.new()
	preview_mesh.name = "Preview"
	preview_mesh.mesh = ImmediateMesh.new()
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Color(0.25, 0.85, 1.0, 0.9)
	pmat.no_depth_test = true
	pmat.vertex_color_use_as_albedo = false
	preview_mesh.material_override = pmat
	add_child(preview_mesh)


func _place_party() -> void:
	# Enemies keep their positions but never overlap (min 1.3 m apart).
	for i in enemies.size():
		for j in range(i):
			var a: CombatActor = enemies[i]
			var b: CombatActor = enemies[j]
			var d: Vector3 = a.global_position - b.global_position
			d.y = 0.0
			if d.length() < 1.3:
				var push: Vector3 = (d.normalized() if d.length() > 0.01 else Vector3(1, 0, 0)) * (1.3 - d.length()) * 0.5
				a.global_position += push
				b.global_position -= push
	# Party on the near side (toward the camera, +Z), fanned; enemies keep their positions.
	var n: int = party.size()
	for i in n:
		var mid: float = float(n - 1) * 0.5
		var angle: float = PI * 0.5 + (float(i) - mid) * 0.5
		var anchor: Vector3 = center + Vector3(cos(angle), 0.0, sin(angle)) * 4.5
		anchor.y = party[i].global_position.y
		party[i].global_position = anchor
		party[i].frozen = false
		party[i].velocity = Vector3.ZERO
		party[i].sprite.update_from_velocity(Vector3.ZERO)
		party[i].face_toward(center + Vector3(0, 0, -5))
		party[i].sprite.play(&"ready")


# ------------------------------------------------------------------ commands

func _on_command_requested(a: Node) -> void:
	actor = a as CombatActor
	boost = 0
	partners.clear()
	current_tech = null
	Audio.play_sfx("ui/sync_hold_freeze")
	if auto:
		auto_timer = 0.15
		mode = Mode.NONE
		return
	_open_main_deck()


func _open_main_deck() -> void:
	mode = Mode.DECK
	var items: Array = [{"label": "Attack", "cmd": "attack"}]
	var techs: Array[TechDef] = coordinator.available_techs(actor)
	items.append({"label": "Tech", "cmd": "techs", "enabled": not techs.is_empty()})
	items.append({"label": "Guard", "cmd": "guard"})
	items.append({"label": "Sync Hold", "cmd": "sync"})
	items.append({"label": "Item", "cmd": "items", "enabled": not Game.inventory.is_empty()})
	var spareable: bool = false
	for e in coordinator.living_enemies():
		if coordinator.can_spare(e):
			spareable = true
	items.append({"label": "Spare", "cmd": "spare", "enabled": spareable})
	if boss != null and boss.is_sealed() and actor.time_debt != null:
		items.append({"label": "Pay Time Debt (5%% integrity, now %d)" % roundi(Game.crono_integrity), "cmd": "pay_debt"})
	if not coordinator.is_boss_battle:
		items.append({"label": "Withdraw", "cmd": "withdraw"})
	hud.open_deck(actor.stats.display_name, items)


func _on_deck_command(cmd: String, payload: Dictionary) -> void:
	match cmd:
		"attack":
			current_tech = null
			_begin_targeting(coordinator.living_enemies())
		"techs":
			_open_tech_deck()
		"tech":
			current_tech = payload["tech"]
			partners = coordinator.partners_for(current_tech, actor) if current_tech.is_coop() else []
			match current_tech.target:
				"self", "party":
					hud.close_deck()
					_execute_tech(null)
				"ally":
					_begin_targeting(coordinator.party.filter(func(u: Node) -> bool: return coordinator._alive(u)))
				_:
					if current_tech.shape == TechDef.Shape.SELF_AURA:
						hud.close_deck()
						_execute_tech(null)
					else:
						_begin_targeting(coordinator.living_enemies())
		"guard":
			hud.close_deck()
			coordinator.cmd_guard(actor)
			_after_command()
		"sync":
			hud.close_deck()
			coordinator.cmd_sync_hold(actor)
			_after_command()
		"items":
			_open_item_deck()
		"item":
			current_tech = null
			set_meta("item", payload["item"])
			_begin_targeting(coordinator.party.filter(func(u: Node) -> bool: return CombatantStats.of(u) != null))
		"spare":
			var sp: Array = coordinator.living_enemies().filter(func(e: Node) -> bool: return coordinator.can_spare(e))
			set_meta("spare", true)
			_begin_targeting(sp)
		"withdraw":
			hud.close_deck()
			var r: Dictionary = coordinator.cmd_withdraw(actor)
			if not bool(r.get("ok", false)):
				hud.show_message(String(r.get("error", "")))
				_open_main_deck()
			else:
				_after_command()
		"pay_debt":
			# The first permanent cost (Prologue): 5% of Crono's ceiling opens the Dollhouse Seal. A free action.
			hud.close_deck()
			actor.time_debt.pay_integrity(5.0)
			Game.set_integrity(actor.time_debt.integrity)
			actor.set_porcelain_visuals()
			if boss != null:
				boss.set_sealed(false)
			Flags.add_counter(&"debts_paid", 1)
			Audio.play_sfx("porcelain/crack_small")
			hud.spawn_number(actor.global_position, "−5% ceiling", Color(0.8, 0.85, 1.0), true)
			hud.show_message("Paid. The Seal opens by exactly as much as he gives it.")
			if Flags.has(&"The_Bowl_Still_Whole"):
				_gold_shatter(actor.global_position)
			_open_main_deck()
		"back":
			_open_main_deck()


func _open_tech_deck() -> void:
	mode = Mode.TECHS
	var items: Array = []
	for t in coordinator.available_techs(actor):
		var cost: Dictionary = t.cost_for(actor.stats.actor_id)
		var cost_txt: String = ""
		if cost.has("mp"):
			cost_txt = "%d MP" % int(cost["mp"])
		elif cost.has("strain_pct"):
			cost_txt = "%s%% ceiling" % str(cost["strain_pct"])
		elif cost.has("solidity_pct"):
			cost_txt = "%s%% solidity" % str(cost["solidity_pct"])
		var prefix: String = ""
		if t.tier == TechDef.Tier.DUAL:
			prefix = "[Dual] "
		elif t.tier == TechDef.Tier.TRIPLE:
			prefix = "[Triple] "
		items.append({"label": "%s%s  %s" % [prefix, t.display_name, cost_txt], "cmd": "tech", "payload": {"tech": t}})
	items.append({"label": "Back", "cmd": "back"})
	hud.open_deck("Techs", items)


func _open_item_deck() -> void:
	mode = Mode.ITEMS
	var items: Array = []
	for id in Game.inventory.keys():
		var def: Dictionary = Data.items.get(StringName(id), {})
		if def.is_empty() or def.has("crafting"):
			continue
		items.append({"label": "%s ×%d" % [String(def.get("name", id)), int(Game.inventory[id])], "cmd": "item", "payload": {"item": def}})
	items.append({"label": "Back", "cmd": "back"})
	hud.open_deck("Items", items)


func _begin_targeting(candidates: Array) -> void:
	target_list = candidates
	if target_list.is_empty():
		hud.show_message("No target")
		_open_main_deck()
		return
	target_index = 0
	mode = Mode.TARGET
	hud.close_deck()
	hud.set_targeting(true)
	hud.boost_level = boost
	_refresh_preview()


func _current_target() -> Node:
	if target_list.is_empty():
		return null
	return target_list[clampi(target_index, 0, target_list.size() - 1)]


func _refresh_preview() -> void:
	var t: Node = _current_target()
	var im := preview_mesh.mesh as ImmediateMesh
	im.clear_surfaces()
	if t == null:
		return
	var text: String = ""
	if has_meta("item") or has_meta("spare"):
		text = CombatantStats.of(t).display_name
		hud.set_preview(text)
		hud.update_plates({}, _party_blind(), t)
		return
	var previews: Dictionary = coordinator.preview(actor, current_tech, t, coordinator.position_of(t), boost)
	var total_dmg: int = 0
	var hits: int = 0
	for e in previews.keys():
		total_dmg += int(previews[e]["damage"])
		hits += int(previews[e]["hits"])
	var name: String = current_tech.display_name if current_tech != null else "Attack"
	text = "%s  →  %s   %d target%s, %d hit%s, ~%d dmg   [R/T: Boost Lv%d]" % [name, CombatantStats.of(t).display_name, previews.size(), "s" if previews.size() != 1 else "", hits, "s" if hits != 1 else "", total_dmg, boost]
	hud.set_preview(text)
	hud.update_plates(previews, _party_blind(), t)
	# Shape outline on the plane.
	if current_tech != null and current_tech.shape != TechDef.Shape.SINGLE and current_tech.shape != TechDef.Shape.PARTY:
		var params := {"shape": current_tech.shape, "radius": current_tech.radius, "length": current_tech.length, "width": current_tech.width, "scale": current_tech.shape_scale(boost)}
		var pts: PackedVector3Array = TacticalPositioner.preview_points(params, actor.global_position, coordinator.position_of(t))
		if pts.size() >= 2:
			im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
			for p in pts:
				im.surface_add_vertex(Vector3(p.x, center.y + 0.08, p.z))
			im.surface_end()


func _party_blind() -> bool:
	for u in coordinator.party:
		var sc := StatusComponent.of(u)
		if sc != null and (sc.has(&"blind") or sc.has(&"white_noise_blind")):
			return true
	return false


func _confirm_target() -> void:
	var t: Node = _current_target()
	hud.set_targeting(false)
	(preview_mesh.mesh as ImmediateMesh).clear_surfaces()
	if has_meta("spare"):
		remove_meta("spare")
		coordinator.cmd_spare(actor, t)
		_after_command()
		return
	if has_meta("item"):
		var item: Dictionary = get_meta("item")
		remove_meta("item")
		if Game.take_item(StringName(String(item["id"]))):
			coordinator.cmd_item(actor, item, t)
		_after_command()
		return
	if current_tech == null:
		coordinator.cmd_attack(actor, t, boost)
		_after_command()
		return
	_execute_tech(t)


func _execute_tech(t: Node) -> void:
	var aim: Vector3 = coordinator.position_of(t) if t != null else actor.global_position
	actor.sprite.play(&"attack", &"ready")
	var r: Dictionary = coordinator.cmd_tech(actor, current_tech.id, t, aim, boost, partners)
	if not bool(r.get("ok", false)):
		hud.show_message(String(r.get("error", "rejected")))
		_open_main_deck()
		return
	Audio.play_sfx("magic/%s_contact" % String(current_tech.element_tag()).to_lower())
	_after_command()


func _after_command() -> void:
	mode = Mode.NONE
	hud.close_deck()
	hud.set_targeting(false)
	hud.update_plates({}, _party_blind(), null)


## Mid-battle story beats close the deck and swallow input; when they end the open window is re-offered.
func set_input_blocked(on: bool) -> void:
	input_blocked = on
	if on:
		hud.close_deck()
		hud.set_targeting(false)
		(preview_mesh.mesh as ImmediateMesh).clear_surfaces()
		mode = Mode.NONE
	elif coordinator != null and coordinator.state == BattleCoordinator.State.COMMAND_WAIT and coordinator.active_actor != null:
		_on_command_requested(coordinator.active_actor)


func _on_summon_requested(key: StringName, count: int, near: Node) -> void:
	if boss != null:
		return  # the boss controller places its own adds
	var edef: EnemyDef = Data.enemy(key)
	if edef == null:
		return
	for k in count:
		var a: CombatActor = CombatActor.create_enemy(edef, -1, "_sum%d" % (randi() % 10000))
		get_parent().add_child(a)
		var base: Vector3 = coordinator.position_of(near) if near != null else center
		var ang: float = randf() * TAU
		a.global_position = base + Vector3(cos(ang), 0.0, sin(ang)) * (1.6 + 0.4 * float(k))
		enemies.append(a)
		coordinator.add_enemy(a, edef)
		hud.register_enemy(a)


func _unhandled_input(event: InputEvent) -> void:
	if _ended or coordinator == null or coordinator.state != BattleCoordinator.State.COMMAND_WAIT or auto or input_blocked or Story.is_running():
		return
	match mode:
		Mode.DECK, Mode.TECHS, Mode.ITEMS:
			if event.is_action_pressed("move_up"):
				hud.deck_move(-1)
			elif event.is_action_pressed("move_down"):
				hud.deck_move(1)
			elif event.is_action_pressed("confirm"):
				hud.deck_confirm()
			elif event.is_action_pressed("cancel") and mode != Mode.DECK:
				_open_main_deck()
			else:
				return
			get_viewport().set_input_as_handled()
		Mode.TARGET:
			if event.is_action_pressed("move_left") or event.is_action_pressed("move_up"):
				target_index = wrapi(target_index - 1, 0, target_list.size())
				_refresh_preview()
			elif event.is_action_pressed("move_right") or event.is_action_pressed("move_down") or event.is_action_pressed("next_target"):
				target_index = wrapi(target_index + 1, 0, target_list.size())
				_refresh_preview()
			elif event.is_action_pressed("boost_up"):
				if coordinator.bank.can_spend(boost + 1):
					boost += 1
					hud.boost_level = boost
					Audio.play_sfx("combat/boost_lv%d" % boost)
					_refresh_preview()
			elif event.is_action_pressed("boost_down"):
				boost = maxi(0, boost - 1)
				hud.boost_level = boost
				_refresh_preview()
			elif event.is_action_pressed("confirm"):
				_confirm_target()
			elif event.is_action_pressed("cancel"):
				if has_meta("item"):
					remove_meta("item")
				if has_meta("spare"):
					remove_meta("spare")
				hud.set_targeting(false)
				(preview_mesh.mesh as ImmediateMesh).clear_surfaces()
				_open_main_deck()
			else:
				return
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _ended or coordinator == null:
		return
	if mode != Mode.TARGET:
		hud.update_plates({}, _party_blind(), null)
	for e in telegraphs.keys():
		if not coordinator.wind_ups.has(e):
			continue
		var wu: Dictionary = coordinator.wind_ups[e]
		var t: float = 1.0 - float(wu["left"]) / maxf(0.01, float(wu["total"]))
		(telegraphs[e].material_override as ShaderMaterial).set_shader_parameter("boost_ratio", t)
	if auto and coordinator.state == BattleCoordinator.State.COMMAND_WAIT and actor != null and not input_blocked and not coordinator.paused:
		auto_timer -= delta
		if auto_timer <= 0.0:
			_auto_act()


func _auto_act() -> void:
	var living: Array = coordinator.living_enemies()
	if living.is_empty():
		return
	if boss != null and boss.is_sealed() and actor.time_debt != null:
		_on_deck_command("pay_debt", {})
		return
	auto_timer = 0.15
	var targetable: Array = living.filter(func(e: Node) -> bool: return not coordinator._untargetable(e))
	if targetable.is_empty():
		coordinator.cmd_guard(actor)
		return
	# heal when someone is low and a healing item is on hand
	var low: Node = null
	for u in coordinator.party:
		var st := CombatantStats.of(u)
		if st != null and st.is_alive() and st.hp_ratio() < 0.35:
			low = u
	if low != null and int(Game.inventory.get(&"tonic", 0)) > 0 and randf() < 0.7:
		if Game.take_item(&"tonic"):
			coordinator.cmd_item(actor, Data.items[&"tonic"], low)
			return
	# focus fire: unbroken targets first, lowest plates first
	targetable.sort_custom(func(a: Node, b: Node) -> bool:
		var sa := ShieldComponent.of(a)
		var sb := ShieldComponent.of(b)
		var ka: int = (1000 if sa != null and sa.is_broken else 0) + (sa.current_shield if sa != null else 0)
		var kb: int = (1000 if sb != null and sb.is_broken else 0) + (sb.current_shield if sb != null else 0)
		return ka < kb)
	var t: Node = targetable[0] if randf() < 0.8 else targetable[randi() % targetable.size()]
	var techs: Array[TechDef] = coordinator.available_techs(actor).filter(func(x: TechDef) -> bool: return x.is_attack and x.target in ["enemy", "point"] and x.effect == &"")
	var b: int = mini(coordinator.bank.bp, randi() % 3)
	if not techs.is_empty() and randf() < 0.6:
		var tech: TechDef = _auto_pick_tech(techs, targetable)
		var r: Dictionary = coordinator.cmd_tech(actor, tech.id, t, coordinator.position_of(t), b, coordinator.partners_for(tech, actor))
		if bool(r.get("ok", false)):
			actor.sprite.play(&"attack", &"ready")
			return
	actor.sprite.play(&"attack", &"ready")
	var r2: Dictionary = coordinator.cmd_attack(actor, t, b)
	if not bool(r2.get("ok", true)):
		coordinator.cmd_guard(actor)


## Shapes that can catch more than one enemy in a single cast.
const AUTO_MULTI_SHAPES: Array[int] = [
	TechDef.Shape.LINE_PIERCE, TechDef.Shape.CONE, TechDef.Shape.CIRCLE, TechDef.Shape.CROSS,
	TechDef.Shape.DELTA, TechDef.Shape.SPLIT_CONE,
]


## Which of the actor's attack techs the autobattle casts this turn. `techs` are the castable attacks,
## `targetable` the enemies that can be hit right now (the 999 Shard Doll's split puts three up at once).
## With several enemies up it takes the multi-target tech whose tags hit the most weaknesses, so a split
## of dolls sharing a weakness is lined up rather than chipped one at a time; two casts in five stay
## random so fights keep some variety.
func _auto_pick_tech(techs: Array[TechDef], targetable: Array) -> TechDef:
	if targetable.size() < 2 or randf() < 0.4:
		return techs[randi() % techs.size()]
	var best: TechDef = null
	var best_hits: int = 1
	for tech in techs:
		if not AUTO_MULTI_SHAPES.has(tech.shape):
			continue
		var hits: int = 0
		for e in targetable:
			var sh := ShieldComponent.of(e)
			if sh != null and sh.hits_weakness(tech.tags):
				hits += 1
		if hits > best_hits:
			best_hits = hits
			best = tech
	return best if best != null else techs[randi() % techs.size()]


# ------------------------------------------------------------------ presentation

func _on_strike(attacker: Node, target: Node, info: Dictionary) -> void:
	var pos: Vector3 = coordinator.position_of(target)
	var dmg: int = int(info.get("damage", 0))
	if bool(info.get("evaded", false)):
		hud.spawn_number(pos, "miss", BattleHUD.PALE)
		return
	if bool(info.get("parried", false)):
		hud.spawn_number(pos, "PARRY", BattleHUD.GOLD, true)
		Audio.play_sfx("weapons/parry_don")
		return
	if bool(info.get("slip_tax", false)):
		hud.spawn_number(pos, "porcelain −5%", Color(0.8, 0.85, 1.0))
		Audio.play_sfx("porcelain/tink")
		return
	if bool(info.get("shield_only", false)):
		hud.spawn_number(pos, "-%d plate" % int(info.get("shave", 0)), BattleHUD.CYAN)
		return
	var colour: Color = BattleHUD.CREAM
	var big: bool = false
	if bool(info.get("weakness", false)):
		colour = BattleHUD.GOLD
		Audio.play_sfx("combat/weak_bell")
	if bool(info.get("crit", false)):
		big = true
	if bool(info.get("absorbed", false)):
		colour = Color(0.5, 0.9, 0.5)
	if dmg < 0:
		hud.spawn_number(pos, "+%d" % (-dmg), Color(0.5, 0.9, 0.5))
	else:
		hud.spawn_number(pos, str(dmg), colour, big)
	if int(info.get("shave", 0)) > 0:
		Audio.play_sfx("combat/shield_chip", 0.0, 1.0 + 0.05 * float(int(info.get("shave", 0))))
	if target is CombatActor:
		var ca := target as CombatActor
		if ca.stats.is_alive():
			ca.sprite.play(&"hurt", &"ready" if ca.is_party else &"idle")
			if ca.time_debt != null:
				Audio.play_sfx("porcelain/tink")
			ca.set_porcelain_visuals()
	if attacker is CombatActor and attacker != target:
		(attacker as CombatActor).face_toward(pos)


func _on_heal(_source: Node, target: Node, amount: int) -> void:
	if amount > 0:
		hud.spawn_number(coordinator.position_of(target), "+%d" % amount, Color(0.55, 0.9, 0.55))


func _on_broken(unit: Node, _breaker: Node) -> void:
	Audio.play_sfx("combat/break_gong_vinyl")
	hud.spawn_number(coordinator.position_of(unit), "BREAK", BattleHUD.GOLD, true)
	if unit is CombatActor:
		(unit as CombatActor).on_break()
	_gold_shatter(coordinator.position_of(unit))
	_flash_screen(Color(1.0, 0.9, 0.6, 0.35), 0.25)
	if rig:
		rig.shake(0.4)


func _on_recovered(unit: Node) -> void:
	if unit is CombatActor:
		(unit as CombatActor).on_recover()
	Audio.play_sfx("combat/shield_rebuild")


func _on_koed(unit: Node) -> void:
	if unit is CombatActor:
		var ca := unit as CombatActor
		if coordinator.is_broken(unit) and not ca.is_party:
			ca.become_statue()
			Audio.play_sfx("combat/statue_shatter")
		else:
			ca.die()
	hud.update_plates({}, _party_blind(), null)


func _on_revived(unit: Node) -> void:
	if unit is CombatActor:
		var ca := unit as CombatActor
		ca.visible = true
		ca.frozen = false
		ca.sprite.play(&"revive", &"ready")


func _on_spared(unit: Node) -> void:
	hud.spawn_number(coordinator.position_of(unit), "spared", Color(0.7, 0.9, 0.8))
	if unit is CombatActor:
		var ca := unit as CombatActor
		var tw := create_tween()
		tw.tween_property(ca.sprite, "transparency", 1.0, 1.0)
		tw.tween_callback(func() -> void: ca.visible = false)
	Flags.add_lean(universe, "L")


func _on_enemy_action(enemy: Node, action: Dictionary) -> void:
	if enemy is CombatActor:
		(enemy as CombatActor).sprite.play(&"attack", &"idle")
	hud.show_message("%s: %s" % [CombatantStats.of(enemy).display_name, String(action.get("name", "attacks"))])


func _on_telegraph_started(enemy: Node, action: Dictionary) -> void:
	if _aoe_shader == null:
		_aoe_shader = load("res://shaders/aoe_floor_ring.gdshader")
	var shape_name: String = String(action.get("shape", "SINGLE"))
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = _aoe_shader
	var aim: Vector3 = action.get("aim", coordinator.position_of(enemy))
	var origin: Vector3 = coordinator.position_of(enemy)
	match shape_name:
		"CIRCLE":
			var r: float = float(action.get("radius", 1.5))
			pm.size = Vector2(r * 2.0, r * 2.0)
			mat.set_shader_parameter("shape_mode", 0)
			mi.position = Vector3(aim.x, center.y + 0.05, aim.z)
		"LINE_PIERCE", "LINE":
			var l: float = float(action.get("length", 6.0))
			var w: float = float(action.get("width", 1.2))
			pm.size = Vector2(w, l)
			mat.set_shader_parameter("shape_mode", 1)
			var dir: Vector3 = Vector3(aim.x - origin.x, 0.0, aim.z - origin.z).normalized()
			mi.position = Vector3(origin.x, center.y + 0.05, origin.z) + dir * l * 0.5
			mi.rotation.y = atan2(dir.x, dir.z) + PI
		"CONE":
			var l2: float = float(action.get("length", 4.0))
			var r2: float = float(action.get("radius", 2.0))
			pm.size = Vector2(r2 * 2.0, l2)
			mat.set_shader_parameter("shape_mode", 2)
			mat.set_shader_parameter("cone_half_angle", atan2(r2, l2))
			var dir2: Vector3 = Vector3(aim.x - origin.x, 0.0, aim.z - origin.z).normalized()
			mi.position = Vector3(origin.x, center.y + 0.05, origin.z) + dir2 * l2 * 0.5
			mi.rotation.y = atan2(dir2.x, dir2.z) + PI
		_:
			pm.size = Vector2(2.2, 2.2)
			mat.set_shader_parameter("shape_mode", 0)
			mi.position = Vector3(aim.x, center.y + 0.05, aim.z)
	mi.mesh = pm
	mi.material_override = mat
	add_child(mi)
	telegraphs[enemy] = mi
	Audio.play_sfx("combat/telegraph_loop")


func _on_telegraph_ended(enemy: Node) -> void:
	if telegraphs.has(enemy):
		telegraphs[enemy].queue_free()
		telegraphs.erase(enemy)


func _on_truth(kind: StringName) -> void:
	if rig:
		rig.set_truth(true)
		var tw := create_tween()
		tw.tween_interval(1.6)
		tw.tween_callback(func() -> void: if rig: rig.set_truth(false))
	match kind:
		&"phase_out":
			hud.show_message("Sera: \"Don't forget me.\"")
			Audio.play_sfx("time/rewind")
		&"rewind":
			Audio.play_sfx("time/rewind")
		&"galaxy_reveal":
			hud.show_message("The shell opens on stars.")
			Audio.play_sfx("porcelain/crack_large")


func _on_boost_used(a: Node, level: int) -> void:
	Audio.play_sfx("combat/boost_lv%d" % clampi(level, 1, 4))
	if level >= 3 and a is CombatActor:
		_style_bleed(a as CombatActor)


func _on_sera_phase(phased: bool) -> void:
	var sera: Node = coordinator.unit_by_id(&"sera")
	if sera is CombatActor:
		var s := sera as CombatActor
		s.sprite.set_opacity(0.18 if phased else 1.0)
		s.sprite.set_tint(Color(1.0, 0.85, 0.5) if phased else Color.WHITE)


func _on_unit_moved(unit: Node, _to: Vector3) -> void:
	if unit is CombatActor:
		(unit as CombatActor).sprite.update_from_velocity(Vector3.ZERO)


func _gold_shatter(pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 60
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.95
	p.fixed_fps = int(Universe.current_fps())
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 80.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, -9.0, 0)
	pm.scale_min = 0.05
	pm.scale_max = 0.16
	pm.color = Color(1.0, 0.82, 0.35)
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.3)
	mat.emission_energy_multiplier = 2.0
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.material = mat
	p.draw_pass_1 = qm
	p.position = pos + Vector3(0, 1.0, 0)
	add_child(p)
	p.emitting = true
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_callback(p.queue_free)


func _style_bleed(a: CombatActor) -> void:
	# Watercolour afterimages (U0), ink splitting (U1): a few fading ghost copies of the sprite.
	for i in 3:
		var ghost := ActorSprite.new()
		ghost.material.set_shader_parameter("sheet", a.sprite.material.get_shader_parameter("sheet"))
		ghost.material.set_shader_parameter("frame_rect", a.sprite.material.get_shader_parameter("frame_rect"))
		ghost.material.set_shader_parameter("sheet_px", a.sprite.material.get_shader_parameter("sheet_px"))
		ghost.mesh = a.sprite.mesh
		ghost.set_tint(Color(0.7, 0.8, 1.0) if a.home_universe == 0 else Color(0.2, 0.2, 0.3))
		ghost.set_opacity(0.5)
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ghost)
		ghost.global_position = a.sprite.global_position + Vector3(-0.25 * float(i + 1), 0.0, 0.0)
		var tw := create_tween()
		tw.tween_property(ghost, "transparency", 1.0, 0.35 + 0.1 * float(i))
		tw.tween_callback(ghost.queue_free)


func _flash_screen(color: Color, seconds: float) -> void:
	if _flash == null:
		_flash = ColorRect.new()
		_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.root.add_child(_flash)
	if bool(Game.settings.get("reduced_flicker", false)):
		color.a *= 0.3
	_flash.color = color
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, seconds)


func _on_battle_ended(victory: bool, summary: Dictionary) -> void:
	if _ended:
		return
	_ended = true
	hud.close_deck()
	hud.set_targeting(false)
	for e in telegraphs.values():
		e.queue_free()
	telegraphs.clear()
	if victory:
		Audio.play_sfx("music/stings/victory")
		for p in party:
			if p.stats.is_alive():
				p.sprite.play(&"victory", &"idle")
		var xp: Dictionary = summary.get("xp", {})
		var parts: Array = []
		for id in xp.keys():
			var lv: int = int(xp[id]["levels"])
			parts.append("%s +%d XP%s" % [String(id).capitalize(), int(xp[id]["xp"]), (" (Lv up ×%d)" % lv) if lv > 0 else ""])
		if int(summary.get("spared", 0)) > 0:
			parts.append("%d spared" % int(summary.get("spared", 0)))
		hud.show_message("  ".join(PackedStringArray(parts)))
	else:
		hud.show_message("The Debt advances: Crono −%s integrity." % str(summary.get("integrity_lost", 5)))
		Audio.play_sfx("music/stings/defeat")
	var tw := create_tween()
	tw.tween_interval(1.4 if victory else 1.0)
	tw.tween_property(plane_mat, "shader_parameter/reveal", 0.0, 0.6)
	tw.tween_callback(func() -> void:
		summary["story"] = bool(config.get("story", false))
		for p in party:
			p.frozen = false
			p.sprite.set_tint(Color.WHITE)
			p.sprite.set_opacity(1.0)
			if p.stats.is_alive():
				p.sprite.play(&"idle")
		finished.emit(victory, summary))
