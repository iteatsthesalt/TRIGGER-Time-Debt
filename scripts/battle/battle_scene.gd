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
## The side of the centre the party stands on (PartyPlacement): +Z, toward the camera, unless the ground says no.
var party_side: Vector3 = Vector3(0, 0, 1)
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
var boss: BossController
var roster := BattleRoster.new()
var input_blocked: bool = false
## Counts the decision windows offered: a command that opens the next one itself (a parked ally gets the floor
## back at once) leaves that window's deck open.
var _window_serial: int = 0
static var _plane_shader: Shader


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
	roster.build(self, party, center)
	var start_cfg := {
		"advantage": String(cfg.get("advantage", "normal")), "universe": universe, "boss": bool(cfg.get("boss", false)),
		"techs": Data.techs, "enemy_defs": defs, "bench": roster.bench, "hover_sera": roster.hover,
		"prometheus": Game.prometheus_core, "parry_frames": Game.parry_frames, "max_bp": Game.max_bp, "max_spend": Game.max_spend,
		"story": bool(cfg.get("story", false)), "ground": cfg.get("ground"),  # party synergy reads who is on the plane (BattleRoster)
	}
	hud.register_units(party, enemies, roster.hover)
	for e in enemies:
		e.face_toward(center + party_side * 4.0)
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
	for f in t.requires_flags:  # "Name:State" flag references (FlagRef)
		if not Flags.holds(String(f)):
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
	plane_mat.set_shader_parameter("tint", CanvasStackEffect.paper_of(universe))  # the one grade table
	plane_mat.render_priority = BattleFx.PLANE_RENDER_PRIORITY  # under every sprite, a faded one included
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


## The enemies pushed apart, the party fanned out on ground it can stand on (PartyPlacement).
func _place_party() -> void:
	PartyPlacement.spread_enemies(enemies)
	party_side = PartyPlacement.place(party, center, config.get("ground") as WalkableGround)


# ------------------------------------------------------------------ commands

func _on_command_requested(a: Node) -> void:
	actor = a as CombatActor
	_window_serial += 1
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
	var items: Array = roster.hover_deck(coordinator, actor) if actor == roster.hover else BattleDeck.main_items(self, actor)
	hud.open_deck(actor.stats.display_name, items)


func _on_deck_command(cmd: String, payload: Dictionary) -> void:
	match cmd:
		"attack":
			current_tech = null
			partners.clear()  # a Dual picked and backed out of leaves no partner on a plain Attack
			_begin_targeting(BattleDeck.targets(coordinator, "attack"))
		"techs":
			mode = Mode.TECHS
			hud.open_deck("Techs", BattleDeck.tech_items(coordinator, actor))
		"tech":
			current_tech = payload["tech"]
			partners = coordinator.partners_for(current_tech, actor) if current_tech.is_coop() else []
			match current_tech.target:
				"self", "party":
					hud.close_deck()
					_execute_tech(null)
				"ally":
					_begin_targeting(BattleDeck.targets(coordinator, "ally"))
				_:
					if current_tech.shape == TechDef.Shape.SELF_AURA:
						hud.close_deck()
						_execute_tech(null)
					else:
						_begin_targeting(BattleDeck.targets(coordinator, "enemy"))
		"guard":
			_run(coordinator.cmd_guard.bind(actor))
		"sync":
			_run(coordinator.cmd_sync_hold.bind(actor))
		"items":
			mode = Mode.ITEMS
			hud.open_deck("Items", BattleDeck.item_items())
		"swap":
			mode = Mode.SWAP
			hud.open_deck("Swap", roster.deck_items(coordinator, actor))
		"swap_in":
			_run(roster.perform.bind(self, actor, payload))
		"item":
			current_tech = null
			set_meta("item", payload["item"])
			_begin_targeting(BattleDeck.targets(coordinator, "item"))
		"spare":
			set_meta("spare", true)
			_begin_targeting(BattleDeck.targets(coordinator, "spare"))
		"withdraw":
			_run(coordinator.cmd_withdraw.bind(actor))
		"pay_debt":
			# The first permanent cost (Prologue): integrity opens the Dollhouse Seal. A free action.
			hud.close_deck()
			SealPayment.pay(self, actor)
			if not auto:
				_open_main_deck()
		"back":
			_open_main_deck()


func _begin_targeting(candidates: Array) -> void:
	target_list = candidates
	if target_list.is_empty():
		_clear_aim()
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
	var previews: Dictionary = coordinator.preview(actor, current_tech, t, coordinator.position_of(t), boost, partners)
	hud.set_preview(BattleDeck.preview_text(current_tech, t, previews, boost))
	hud.update_plates(previews, _party_blind(), t)
	# Shape outline on the plane.
	if current_tech != null and current_tech.shape != TechDef.Shape.SINGLE and current_tech.shape != TechDef.Shape.PARTY:
		var params := {"shape": current_tech.shape, "radius": CastReach.radius(current_tech), "length": current_tech.length, "width": current_tech.width, "scale": current_tech.shape_scale(boost)}
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


## Leave the aim: the item/spare marks, the shape outline and the preview line go.
func _clear_aim() -> void:
	for m in [&"item", &"spare"]:
		if has_meta(m):
			remove_meta(m)
	hud.set_targeting(false)
	(preview_mesh.mesh as ImmediateMesh).clear_surfaces()


func _confirm_target() -> void:
	var t: Node = _current_target()
	var item: Dictionary = get_meta("item", {})
	var spare: bool = has_meta("spare")
	_clear_aim()
	if spare:
		_run(coordinator.cmd_spare.bind(actor, t))
	elif not item.is_empty():
		_run(BattleDeck.use_item.bind(coordinator, actor, item, t))
	elif current_tech == null:
		_run(coordinator.cmd_attack.bind(actor, t, boost))
	else:
		_execute_tech(t)


func _execute_tech(t: Node) -> void:
	var aim: Vector3 = coordinator.position_of(t) if t != null else actor.global_position
	var tech: TechDef = current_tech
	var who: CombatActor = actor
	var serial: int = _window_serial
	var r: Dictionary = coordinator.cmd_tech(actor, tech.id, t, aim, boost, partners)
	if bool(r.get("ok", false)):
		who.sprite.play(&"attack", &"ready")
		if tech.element_tag() != &"":
			Audio.play_sfx("magic/%s_contact" % String(tech.element_tag()).to_lower())
	_after_command(r, serial)


## Run one party command and settle the deck on its verdict.
func _run(command: Callable) -> void:
	var serial: int = _window_serial
	_after_command(command.call(), serial)


## A refused command says why and reopens this actor's deck (the window is still open); an accepted one closes
## the deck, unless the command itself opened the next window (`serial` moved on), whose deck is already up.
func _after_command(r: Dictionary, serial: int) -> void:
	hud.set_targeting(false)
	hud.update_plates({}, _party_blind(), null)
	if bool(r.get("ok", false)):
		if serial == _window_serial:
			mode = Mode.NONE
			hud.close_deck()
	elif not _ended and coordinator.state == BattleCoordinator.State.COMMAND_WAIT and coordinator.active_actor == actor:
		hud.show_message(String(r.get("error", "rejected")))
		_open_main_deck()
	else:
		mode = Mode.NONE
		hud.close_deck()


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


## A summon cast by a regular enemy, capped by that enemy's own `max_adds` (EnemySpawner); the boss's own
## summons are its controller's (its file defines the adds and its director may take them over).
func _on_summon_requested(key: StringName, count: int, near: Node) -> void:
	if boss != null and (near == null or near == boss.actor):
		return
	var edef: EnemyDef = Data.enemy(key)
	if edef != null:
		EnemySpawner.spawn(self, edef, near, count, EnemySpawner.cap_of(near))


func _unhandled_input(event: InputEvent) -> void:
	if _ended or coordinator == null or auto or input_blocked or Story.blocks_battle_input():
		return
	if coordinator.state == BattleCoordinator.State.TICK:
		# A parked ally may leave the Ready Pool at any time (§3.4): confirm wakes the first one.
		if not coordinator.ready_pool.is_empty() and event.is_action_pressed("confirm") and coordinator.request_command(coordinator.ready_pool[0]):
			get_viewport().set_input_as_handled()
		return
	if coordinator.state != BattleCoordinator.State.COMMAND_WAIT:
		return
	match mode:
		Mode.DECK, Mode.TECHS, Mode.ITEMS, Mode.SWAP:
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
				_clear_aim()
				_open_main_deck()
			else:
				return
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _ended or coordinator == null:
		return
	hud.refresh_plates(_party_blind())
	# A window with no deck up (a path that closed it and opened nothing) gets its deck back: never a soft-lock.
	if not auto and mode == Mode.NONE and not input_blocked and not coordinator.paused and coordinator.active_actor != null \
			and coordinator.state == BattleCoordinator.State.COMMAND_WAIT and not Story.blocks_battle_input():
		_on_command_requested(coordinator.active_actor)
	for e in telegraphs.keys():
		if not coordinator.wind_ups.has(e):
			continue
		var wu: Dictionary = coordinator.wind_ups[e]
		var t: float = 1.0 - float(wu["left"]) / maxf(0.01, float(wu["total"]))
		(telegraphs[e].material_override as ShaderMaterial).set_shader_parameter("boost_ratio", t)
	if auto and coordinator.state == BattleCoordinator.State.COMMAND_WAIT and actor != null and not input_blocked and not coordinator.paused:
		auto_timer -= delta
		if auto_timer <= 0.0:
			AutoBattler.act(self)


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
	elif bool(info.get("sealed", false)):
		hud.spawn_number(pos, "SEALED", BattleHUD.PALE)  # the plates shave, the body takes nothing
	else:
		hud.spawn_number(pos, str(dmg), colour, big)
	if int(info.get("shave", 0)) > 0:
		Audio.play_sfx("combat/shield_chip", 0.0, 1.0 + 0.05 * float(int(info.get("shave", 0))))
	if target is CombatActor:
		var ca := target as CombatActor
		if ca.stats.is_alive() and not coordinator.is_broken(target):  # a Broken body stays locked mid-step (§5.4)
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
	BattleFx.gold_shatter(self, coordinator.position_of(unit))
	BattleFx.flash(hud, Color(1.0, 0.9, 0.6, 0.35), 0.25)
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
		ca.restore_body()  # stops die()'s fade: a revived ally is visible and opaque again
		ca.sprite.play(&"revive", &"ready")


func _on_spared(unit: Node) -> void:
	hud.spawn_number(coordinator.position_of(unit), "spared", Color(0.7, 0.9, 0.8))
	if unit is CombatActor:
		var ca := unit as CombatActor
		var tw := create_tween()
		tw.tween_property(ca.sprite, "transparency", 1.0, 1.0)
		tw.tween_callback(func() -> void: ca.visible = false)
	# the spare's Light lean is paid at victory, by the codex signature (RewardResolver)


func _on_enemy_action(enemy: Node, action: Dictionary) -> void:
	if enemy is CombatActor:
		(enemy as CombatActor).sprite.play(&"attack", &"idle")
	hud.show_message("%s: %s" % [CombatantStats.of(enemy).display_name, String(action.get("name", "attacks"))])


func _on_telegraph_started(enemy: Node, action: Dictionary) -> void:
	_on_telegraph_ended(enemy)  # a new wind-up never orphans an old decal
	telegraphs[enemy] = BattleFx.telegraph(self, action, coordinator.position_of(enemy), center.y + 0.05)
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
		BattleFx.style_bleed(self, a as CombatActor)


## Phased, a gold ghost; un-phased, back to her Debt, not fully solid (CombatActor.apply_body_look reads the phase).
func _on_sera_phase(_phased: bool) -> void:
	var sera: Node = coordinator.unit_by_id(&"sera")
	if sera is CombatActor:
		(sera as CombatActor).apply_body_look()


func _on_unit_moved(unit: Node, _to: Vector3) -> void:
	if unit is CombatActor:
		(unit as CombatActor).sprite.update_from_velocity(Vector3.ZERO)


func _on_battle_ended(victory: bool, summary: Dictionary) -> void:
	if _ended:
		return
	_ended = true
	hud.close_deck()
	hud.set_targeting(false)
	for e in telegraphs.values():
		e.queue_free()
	telegraphs.clear()
	if auto:
		AutoBattler.report(victory)
	BattleEndNotice.announce(hud, party, victory, summary)
	var tw := create_tween()
	tw.tween_interval(1.4 if victory else 1.0)
	tw.tween_property(plane_mat, "shader_parameter/reveal", 0.0, 0.6)
	tw.tween_callback(func() -> void:
		summary["story"] = bool(config.get("story", false))
		for p in party:
			p.frozen = false
			p.apply_body_look()  # the phase ended with the battle (SolidityComponent.end_battle): her Debt's look
			if p.stats.is_alive():
				p.sprite.play(&"idle")
		# reserves still down are recorded at the floor the field party stands up with (BattleAftermath)
		roster.finish(BattleAftermath.floor_ratio(BattleAftermath.outcome(victory, summary), bool(summary["story"])))
		finished.emit(victory, summary))
